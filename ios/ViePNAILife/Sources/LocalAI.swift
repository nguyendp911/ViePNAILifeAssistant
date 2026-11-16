import Foundation
import Security

// Standalone mode: API keys are entered in the app and stored only in the iPhone Keychain
// (this-device-only, never in the IPA, never uploaded to a Gateway). Chat calls the provider
// directly over HTTPS when no Gateway is configured.

enum LocalKey: String {
    case gemini = "viepn.local.gemini.key"
    case openai = "viepn.local.openai.key"
    case googleClientID = "viepn.local.google.clientid"
    case googleRefresh = "viepn.local.google.refresh"
}

enum KeychainStore {
    private static let service = "com.viepn.ailife.local"

    private static func base(_ key: LocalKey) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key.rawValue]
    }

    static func load(_ key: LocalKey) -> String {
        var query = base(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Saving an empty value deletes the entry.
    @discardableResult
    static func save(_ value: String, for key: LocalKey) -> Bool {
        SecItemDelete(base(key) as CFDictionary)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        var query = base(key)
        query[kSecValueData as String] = Data(trimmed.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
}

enum LocalAI {
    static let geminiSuggestions = ["gemini-2.5-flash", "gemini-2.5-pro"]
    static let openAISuggestions = ["gpt-4o-mini", "gpt-4o"]
    private static let systemPrompt = "Bạn là trợ lý cá nhân của ứng dụng ViePN AI Life. Trả lời bằng tiếng Việt, ngắn gọn, rõ ràng, trừ khi người dùng viết bằng ngôn ngữ khác."

    static var hasGeminiKey: Bool { !KeychainStore.load(.gemini).isEmpty }
    static var hasOpenAIKey: Bool { !KeychainStore.load(.openai).isEmpty }
    static var hasKeys: Bool { hasGeminiKey || hasOpenAIKey }

    static func model(_ kind: String) -> String {
        let saved = (UserDefaults.standard.string(forKey: "viepn.local." + kind + ".model") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !saved.isEmpty { return saved }
        return kind == "gemini" ? geminiSuggestions[0] : openAISuggestions[0]
    }

    static func setModel(_ value: String, kind: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "viepn.local." + kind + ".model"
        if trimmed.isEmpty { UserDefaults.standard.removeObject(forKey: key) }
        else { UserDefaults.standard.set(trimmed, forKey: key) }
    }

    private static func modelList(kind: String, suggestions: [String]) -> [String] {
        let chosen = model(kind)
        return [chosen] + suggestions.filter { $0 != chosen }
    }

    static func providers() -> ChatProvidersResponse {
        var items: [ChatModelOption] = []
        if hasGeminiKey {
            items.append(ChatModelOption(
                id: "gemini", name: "Google Gemini", kind: "gemini",
                models: modelList(kind: "gemini", suggestions: geminiSuggestions),
                defaultModel: model("gemini")))
        }
        if hasOpenAIKey {
            items.append(ChatModelOption(
                id: "openai", name: "OpenAI", kind: "openai",
                models: modelList(kind: "openai", suggestions: openAISuggestions),
                defaultModel: model("openai")))
        }
        return ChatProvidersResponse(items: items, configured: !items.isEmpty)
    }

    static func chat(
        _ message: String, history: [ChatLine], providerId: String?, model requested: String?
    ) async throws -> ChatReply {
        let id = providerId ?? ""
        let useGemini = id == "gemini" || (id.isEmpty && hasGeminiKey)
        let turns = history.suffix(12).map { line -> (user: Bool, text: String) in
            (line.user, String(line.text.prefix(3000)))
        }
        if useGemini {
            let key = KeychainStore.load(.gemini)
            guard !key.isEmpty else { throw APIError.text("Chưa nhập khóa Gemini.") }
            let chosen = (requested ?? "").isEmpty ? model("gemini") : requested!
            return try await gemini(message, turns: turns, key: key, model: chosen)
        }
        let key = KeychainStore.load(.openai)
        guard !key.isEmpty else { throw APIError.text("Chưa nhập khóa OpenAI hoặc Gemini.") }
        let chosen = (requested ?? "").isEmpty ? model("openai") : requested!
        return try await openAI(message, turns: turns, key: key, model: chosen)
    }

    private static func validModelName(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 80 && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }
    }

    private static func gemini(
        _ message: String, turns: [(user: Bool, text: String)], key: String, model: String
    ) async throws -> ChatReply {
        guard validModelName(model),
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")
        else { throw APIError.text("Tên model Gemini không hợp lệ.") }
        var contents: [[String: Any]] = turns.map { turn in
            ["role": turn.user ? "user" : "model", "parts": [["text": turn.text]]]
        }
        contents.append(["role": "user", "parts": [["text": message]]])
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "contents": contents
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await perform(request, provider: "Gemini")
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = object["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw APIError.text("Gemini không trả về nội dung (có thể bị bộ lọc an toàn chặn).")
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw APIError.text("Gemini trả về câu trả lời rỗng.") }
        return ChatReply(reply: text, configured: true, provider: "gemini", model: model)
    }

    private static func openAI(
        _ message: String, turns: [(user: Bool, text: String)], key: String, model: String
    ) async throws -> ChatReply {
        guard validModelName(model), let url = URL(string: "https://api.openai.com/v1/chat/completions")
        else { throw APIError.text("Tên model OpenAI không hợp lệ.") }
        var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for turn in turns { messages.append(["role": turn.user ? "user" : "assistant", "content": turn.text]) }
        messages.append(["role": "user", "content": message])
        let body: [String: Any] = ["model": model, "messages": messages]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await perform(request, provider: "OpenAI")
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let reply = choices.first?["message"] as? [String: Any],
              let text = reply["content"] as? String, !text.isEmpty else {
            throw APIError.text("OpenAI không trả về nội dung.")
        }
        return ChatReply(reply: text, configured: true, provider: "openai", model: model)
    }

    private static func perform(_ request: URLRequest, provider: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.text(provider + " không phản hồi hợp lệ.") }
        guard (200...299).contains(http.statusCode) else {
            var detail = ""
            if let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let error = object["error"] as? [String: Any],
               let message = error["message"] as? String { detail = String(message.prefix(200)) }
            var hint = ""
            if http.statusCode == 400 || http.statusCode == 401 || http.statusCode == 403 {
                hint = " Kiểm tra lại khóa API và tên model."
            }
            throw APIError.text("\(provider) lỗi \(http.statusCode): \(detail)\(hint)")
        }
        return data
    }
}
