import AppKit

/// 输入内容发音：基于系统 NSSpeechSynthesizer，无网络、无依赖。
/// 中文用中文语音、英文用英文语音；朗读中再次调用则停止。
final class Speaker: NSObject, ObservableObject, NSSpeechSynthesizerDelegate {

    @Published private(set) var isSpeaking = false
    private let synthesizer = NSSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// 朗读文本；正在朗读时调用则停止。
    func speakOrStop(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if isSpeaking {
            synthesizer.stopSpeaking()
            return
        }

        let language = LanguageDetector.detect(text) ?? .english
        if let voice = Self.bestVoice(for: language) {
            synthesizer.setVoice(NSSpeechSynthesizer.VoiceName(rawValue: voice))
        }
        synthesizer.startSpeaking(text)
        isSpeaking = true
    }

    /// 按语言挑选系统语音：优先增强/premium 音色，其次 compact。
    private static func bestVoice(for language: Language) -> String? {
        let prefix = language == .chinese ? ".zh-" : ".en-"
        let voices = NSSpeechSynthesizer.availableVoices
            .map { $0.rawValue }
            .filter { $0.contains(prefix) }
        return voices.first { $0.contains(".enhanced.") || $0.contains(".premium.") }
            ?? voices.first
    }

    // MARK: - NSSpeechSynthesizerDelegate

    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
}
