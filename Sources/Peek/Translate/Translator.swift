import Foundation
import Combine

/// 翻译调度层：自动判定方向、选择引擎、失败降级、结果合并。
final class Translator: ObservableObject {

    /// 用户可手动选择的引擎
    enum EngineChoice: String, CaseIterable, Identifiable {
        case auto
        case youdao
        case google
        case mymemory
        case deepl

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .auto: return "自动（推荐）"
            case .youdao: return "有道词典"
            case .google: return "谷歌翻译"
            case .mymemory: return "MyMemory"
            case .deepl: return "DeepL"
            }
        }

        var detail: String {
            switch self {
            case .auto: return "单词走词典，整句走整句引擎，失败自动切换"
            case .youdao: return "免密钥 · 释义音标例句齐全"
            case .google: return "免密钥 · 整句质量最好，需系统代理"
            case .mymemory: return "免密钥 · 长句翻译稳定"
            case .deepl: return "官方 API · 500K 字符/月免费，需在高级设置填 Key"
            }
        }
    }

    @MainActor @Published private(set) var isTranslating = false
    @MainActor @Published private(set) var output: TranslationOutput?
    @MainActor @Published private(set) var errorMessage: String?
    /// 最近一次翻译是否命中缓存
    @MainActor @Published private(set) var servedFromCache = false

    private var settings: SettingsStore
    private var task: Task<Void, Never>?

    // 简单缓存，避免连续重复请求
    private var cache: [String: TranslationOutput] = [:]
    private let cacheLimit = 64

    init(settings: SettingsStore) {
        self.settings = settings
    }

    // MARK: - 对外入口

    /// 翻译文本。会自动识别语言方向。
    @MainActor
    func translate(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        task?.cancel()

        guard !trimmed.isEmpty else {
            output = nil
            errorMessage = nil
            isTranslating = false
            return
        }

        guard let source = LanguageDetector.detect(trimmed) else {
            output = nil
            errorMessage = "没有检测到可翻译的中英文内容"
            isTranslating = false
            return
        }

        let target = source.counterpart
        let cacheKey = "\(source.code)->\(target.code):\(settings.engine.rawValue):\(trimmed)"

        if let cached = cache[cacheKey] {
            output = cached
            servedFromCache = true
            errorMessage = nil
            isTranslating = false
            return
        }

        servedFromCache = false
        isTranslating = true
        errorMessage = nil
        output = nil

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.performTranslate(
                    text: trimmed, source: source, target: target
                )
                guard !Task.isCancelled else { return }
                self.store(result, forKey: cacheKey)
                self.output = result
                self.isTranslating = false
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                self.isTranslating = false
            }
        }
    }

    /// 取消进行中的翻译
    @MainActor
    func cancel() {
        task?.cancel()
        task = nil
        isTranslating = false
    }

    @MainActor
    func clear() {
        cancel()
        output = nil
        errorMessage = nil
    }

    // MARK: - 引擎调度

    private func performTranslate(
        text: String,
        source: Language,
        target: Language
    ) async throws -> TranslationOutput {
        let engines = engineChain(for: text)
        guard !engines.isEmpty else {
            throw EngineError(message: "没有可用引擎，请检查设置")
        }

        var lastError: Error = EngineError(message: "翻译失败")

        for (index, engine) in engines.enumerated() {
            if Task.isCancelled { throw CancellationError() }
            do {
                var result = try await engine.translate(text, from: source, to: target)
                result.detected = result.detected ?? source

                // 单词模式下补全译文：词典引擎可能只给释义没给译文
                if result.translated.isEmpty, !result.entries.isEmpty {
                    result.translated = synthesizeTranslation(from: result, target: target)
                }
                return result
            } catch {
                lastError = error
                // 只有一个引擎时直接抛出；有多个则继续降级
                if index == engines.count - 1 {
                    break
                }
            }
        }
        throw lastError
    }

    /// 根据引擎选择与输入类型，构建有序的引擎链
    private func engineChain(for text: String) -> [any TranslationEngine] {
        let isWord = LanguageDetector.looksLikeSingleWord(text)
        let choice = settings.engine
        let deepL = { DeepLEngine(apiKey: self.settings.deeplAPIKey) }
        let hasDeepL = !settings.deeplAPIKey.trimmingCharacters(in: .whitespaces).isEmpty

        switch choice {
        case .youdao:
            return [YoudaoEngine()]
        case .google:
            return [GoogleEngine()]
        case .mymemory:
            return [MyMemoryEngine()]
        case .deepl:
            return [deepL()]
        case .auto:
            var chain: [any TranslationEngine] = []
            // 单词优先词典引擎；整句优先官方 DeepL（已配 Key），谷歌次之，MyMemory 兑底
            if isWord {
                chain.append(YoudaoEngine())
                if hasDeepL { chain.append(deepL()) }
                chain.append(GoogleEngine())
                chain.append(MyMemoryEngine())
            } else {
                if hasDeepL { chain.append(deepL()) }
                chain.append(GoogleEngine())
                chain.append(MyMemoryEngine())
                chain.append(YoudaoEngine())
            }
            return chain
        }
    }

    /// 词典结果没有独立译文时，用释义拼一个可读的译文
    private func synthesizeTranslation(
        from result: TranslationOutput,
        target: Language
    ) -> String {
        let parts = result.groupedEntries.prefix(3).map { group in
            let pos = group.partOfSpeech.map { "\($0) " } ?? ""
            let def = group.definitions.first?.definition ?? ""
            return (pos + def).trimmingCharacters(in: .whitespaces)
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - 缓存

    @MainActor
    private func store(_ output: TranslationOutput, forKey key: String) {
        cache[key] = output
        if cache.count > cacheLimit {
            // 简单淘汰最早插入的
            if let first = cache.keys.first {
                cache.removeValue(forKey: first)
            }
        }
    }

    @MainActor
    func clearCache() {
        cache.removeAll()
    }
}