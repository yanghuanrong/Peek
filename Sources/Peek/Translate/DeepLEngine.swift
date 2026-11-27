import Foundation

/// DeepL 翻译引擎（官方 API，需免费 API Key）。
/// Free Key 以 `:fx` 结尾走 api-free.deepl.com，Pro Key 走 api.deepl.com。
/// 免费额度 500K 字符/月，质量与稳定性远好于免密钥接口。
struct DeepLEngine: TranslationEngine {

    let id = "deepl"
    let displayName = "DeepL"
    let requiresKey = true
    var strength: EngineStrength { .sentence }

    var apiKey: String

    func translate(_ text: String, from: Language, to: Language) async throws -> TranslationOutput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EngineError(message: "输入为空") }
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else {
            throw EngineError(message: "未配置 DeepL API Key，请在设置中填写")
        }

        // Free Key 以 :fx 结尾，端点不同；官方单次请求上限约 128KB，正常文本不会超
        let host = key.hasSuffix(":fx") ? "api-free.deepl.com" : "api.deepl.com"
        guard let url = URL(string: "https://\(host)/v2/translate") else {
            throw EngineError(message: "URL 构造失败")
        }

        let targetCode = to == .chinese ? "ZH" : "EN"
        let body: [String: Any] = [
            "text": [trimmed],
            "target_lang": targetCode
        ]

        let json = try await HTTPClient.postJSON(
            url: url,
            body: body,
            headers: ["Authorization": "DeepL-Auth-Key \(key)"]
        )

        guard let root = json as? [String: Any],
              let translations = root["translations"] as? [[String: Any]],
              let translated = translations.first?["text"] as? String,
              !translated.isEmpty else {
            throw EngineError(message: "DeepL 返回格式异常")
        }

        var output = TranslationOutput()
        output.engineName = displayName
        output.detected = from
        output.translated = translated
        return output
    }
}
