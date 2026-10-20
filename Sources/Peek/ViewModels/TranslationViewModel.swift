import AppKit
import Combine
import SwiftUI

/// 面板的视图模型，串起「呼出 → 粘贴 → 翻译 → 复制」主流程。
@MainActor
final class TranslationViewModel: ObservableObject {

    @Published var inputText: String = ""
    @Published var copiedFlash: Bool = false
    @Published private(set) var lastAction: Action?

    enum Action: Equatable {
        case copied
        case autoCopied
    }

    private let translator: Translator
    private let settings: SettingsStore
    private var cancellables = Set<AnyCancellable>()

    var output: TranslationOutput? { translator.output }
    var isTranslating: Bool { translator.isTranslating }
    var errorMessage: String? { translator.errorMessage }

    init(translator: Translator, settings: SettingsStore) {
        self.translator = translator
        self.settings = settings
        // 面板只观察 viewModel；翻译状态在 translator 上，必须转发否则 UI 会卡在「翻译中…」
        translator.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - 呼出

    /// 热键触发：读取剪贴板 → 填充输入框 → 自动翻译
    func onHotkeyTriggered() {
        loadClipboardIfNeeded()
        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            translator.translate(inputText)
        }
    }

    /// 演示模式：直接填入文本并翻译，不读剪贴板
    func demoTranslate(_ text: String) {
        inputText = text
        translator.translate(text)
    }

    private func loadClipboardIfNeeded() {
        guard settings.autoPasteClipboard else {
            if !settings.keepLastInput {
                inputText = ""
            }
            return
        }

        guard let text = ClipboardService.currentText(),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if !settings.keepLastInput { inputText = "" }
            return
        }

        // 避免重复翻译同样的内容
        if text != inputText {
            inputText = text
        } else if settings.keepLastInput {
            return
        }
    }

    // MARK: - 剪贴板监听（面板打开期间）

    private var clipboardTimer: Timer?
    /// 上次看到的剪贴板 changeCount；自己写入译文时也同步更新，避免自触发
    private var lastChangeCount: Int = 0

    /// 面板打开时开始监听；macOS 无剪贴板通知，按同行做法轮询 changeCount（仅面板可见期间，成本可忽略）
    func startWatchingClipboard() {
        stopWatchingClipboard()
        lastChangeCount = ClipboardService.changeCount
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboardChanged()
            }
        }
    }

    func stopWatchingClipboard() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }

    private func checkClipboardChanged() {
        guard settings.watchClipboard else { return }
        let count = ClipboardService.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        guard let text = ClipboardService.currentText(),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text != inputText else { return }

        inputText = text
        translator.translate(text)
    }

    // MARK: - 翻译

    func translate() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            translator.clear()
            return
        }
        translator.translate(inputText)
    }

    /// 监听输出变化，必要时自动复制
    func startObserving() {
        translator.$output
            .receive(on: RunLoop.main)
            .sink { [weak self] output in
                guard let self, let output, output.hasContent else { return }
                if self.settings.autoCopyResult {
                    self.copyResult(output)
                    self.lastAction = .autoCopied
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 复制

    /// 复制译文到剪贴板
    func copyResult(_ output: TranslationOutput? = nil) {
        guard let text = (output ?? translator.output)?.translated,
              !text.isEmpty else { return }

        // 若译文与输入完全一致（如单词音标查询），不写剪贴板避免污染
        guard text != inputText else {
            flashCopied()
            return
        }

        ClipboardService.write(text)
        lastChangeCount = ClipboardService.changeCount
        flashCopied()
        lastAction = .copied
    }

    /// 关闭面板：取消进行中的翻译。开启自动复制时译文保留在剪贴板，不做还原
    func onHide() {
        translator.cancel()
    }

    func clear() {
        inputText = ""
        translator.clear()
    }

    private func flashCopied() {
        copiedFlash = true
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            copiedFlash = false
        }
    }

    /// 当前输入对应的方向描述，如"英 → 中"
    var directionText: String {
        guard let detected = LanguageDetector.detect(inputText) else { return "自动识别" }
        return "\(detected.badge) → \(detected.counterpart.badge)"
    }

    /// 输入是否是单词（决定UI 是否突出显示词典信息）
    var isWordInput: Bool {
        LanguageDetector.looksLikeSingleWord(inputText)
    }
}