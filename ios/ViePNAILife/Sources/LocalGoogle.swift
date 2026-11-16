import Foundation
import CryptoKit

// On-device Google sign-in (OAuth 2.0 for iOS apps with PKCE, no client secret).
// Read-only Gmail + Calendar. The refresh token lives only in the iPhone Keychain.
enum LocalGoogle {
    static let scopes = "https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/calendar.readonly"
    private static let clientSuffix = ".apps.googleusercontent.com"

    struct AuthRequest {
        let url: URL
        let verifier: String
        let scheme: String
        let redirect: String
        let state: String
    }

    private final class TokenCache: @unchecked Sendable {
        let lock = NSLock()
        var value = ""
        var expires = Date.distantPast
    }
    private static let cache = TokenCache()

    static var isConnected: Bool { !KeychainStore.load(.googleRefresh).isEmpty }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func randomString(bytes: Int) -> String {
        base64URL(Data((0..<bytes).map { _ in UInt8.random(in: 0...255) }))
    }

    private static func formEncode(_ params: [String: String]) -> Data {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+")
        let text = params.map { key, value in
            key + "=" + (value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
        }.joined(separator: "&")
        return Data(text.utf8)
    }

    static func begin(clientID rawID: String) throws -> AuthRequest {
        let clientID = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clientID.hasSuffix(clientSuffix), clientID.count > clientSuffix.count else {
            throw APIError.text("Client ID phải có dạng xxxx.apps.googleusercontent.com (loại iOS).")
        }
        let prefix = String(clientID.dropLast(clientSuffix.count))
        let scheme = "com.googleusercontent.apps." + prefix
        let redirect = scheme + ":/oauth2redirect"
        let verifier = randomString(bytes: 48)
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = randomString(bytes: 16)
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        guard let url = components.url else { throw APIError.text("Không tạo được URL đăng nhập Google.") }
        return AuthRequest(url: url, verifier: verifier, scheme: scheme, redirect: redirect, state: state)
    }

    static func finish(callback: URL, request: AuthRequest, clientID rawID: String) async throws {
        let clientID = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first(where: { $0.name == name })?.value }
        if let error = value("error") { throw APIError.text("Google từ chối: " + error) }
        guard value("state") == request.state, let code = value("code") else {
            throw APIError.text("Phản hồi đăng nhập Google không hợp lệ.")
        }
        let result = try await tokenCall([
            "client_id": clientID, "code": code, "code_verifier": request.verifier,
            "grant_type": "authorization_code", "redirect_uri": request.redirect
        ])
        guard let refresh = result["refresh_token"] as? String, !refresh.isEmpty else {
            throw APIError.text("Google không cấp refresh token. Thử kết nối lại.")
        }
        KeychainStore.save(refresh, for: .googleRefresh)
        store(result)
    }

    static func disconnect() async {
        let refresh = KeychainStore.load(.googleRefresh)
        KeychainStore.save("", for: .googleRefresh)
        clearCache()
        guard !refresh.isEmpty, let url = URL(string: "https://oauth2.googleapis.com/revoke") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode(["token": refresh])
        _ = try? await URLSession.shared.data(for: request)
    }

    private static func clearCache() {
        cache.lock.lock()
        cache.value = ""
        cache.expires = .distantPast
        cache.lock.unlock()
    }

    private static func cachedToken() -> String? {
        cache.lock.lock()
        defer { cache.lock.unlock() }
        return cache.expires.timeIntervalSinceNow > 60 && !cache.value.isEmpty ? cache.value : nil
    }

    private static func store(_ result: [String: Any]) {
        guard let token = result["access_token"] as? String else { return }
        let seconds = (result["expires_in"] as? Double) ?? 3000
        cache.lock.lock()
        cache.value = token
        cache.expires = Date().addingTimeInterval(seconds)
        cache.lock.unlock()
    }

    private static func tokenCall(_ params: [String: String]) async throws -> [String: Any] {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { throw APIError.text("URL không hợp lệ.") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode(params)
        let (data, response) = try await URLSession.shared.data(for: request)
        let object = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let detail = (object["error_description"] as? String) ?? (object["error"] as? String) ?? ""
            throw APIError.text("Đăng nhập Google thất bại. " + detail)
        }
        return object
    }

    private static func accessToken() async throws -> String {
        if let cached = cachedToken() { return cached }
        let refresh = KeychainStore.load(.googleRefresh)
        let clientID = KeychainStore.load(.googleClientID)
        guard !refresh.isEmpty, !clientID.isEmpty else { throw APIError.text("Chưa kết nối Google.") }
        let result = try await tokenCall([
            "client_id": clientID, "refresh_token": refresh, "grant_type": "refresh_token"
        ])
        store(result)
        guard let token = result["access_token"] as? String else { throw APIError.text("Không làm mới được phiên Google.") }
        return token
    }

    private static func get(_ url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let token = try await accessToken()
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.text("Google API từ chối yêu cầu. Kiểm tra đã bật Gmail API / Calendar API và thêm bạn làm người dùng thử.")
        }
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
    }

    static func gmail() async throws -> [GmailSummary] {
        var list = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        list.queryItems = [URLQueryItem(name: "maxResults", value: "5"), URLQueryItem(name: "labelIds", value: "INBOX")]
        guard let listURL = list.url else { return [] }
        let listing = try await get(listURL)
        let ids = (listing["messages"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        var result: [GmailSummary] = []
        for id in ids {
            var detail = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/" + id)!
            detail.queryItems = [
                URLQueryItem(name: "format", value: "metadata"),
                URLQueryItem(name: "metadataHeaders", value: "Subject"),
                URLQueryItem(name: "metadataHeaders", value: "From"),
                URLQueryItem(name: "metadataHeaders", value: "Date")
            ]
            guard let detailURL = detail.url else { continue }
            let message = try await get(detailURL)
            let payload = message["payload"] as? [String: Any]
            let headers = payload?["headers"] as? [[String: Any]] ?? []
            func header(_ name: String) -> String {
                headers.first(where: { ($0["name"] as? String)?.lowercased() == name.lowercased() })?["value"] as? String ?? ""
            }
            result.append(GmailSummary(
                id: id, subject: header("Subject").isEmpty ? "(Không có tiêu đề)" : header("Subject"),
                from: header("From"), date: header("Date"),
                snippet: message["snippet"] as? String ?? ""))
        }
        return result
    }

    static func calendar() async throws -> [CalendarSummary] {
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: ISO8601DateFormatter().string(from: Date())),
            URLQueryItem(name: "maxResults", value: "10"),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]
        guard let url = components.url else { return [] }
        let response = try await get(url)
        let items = response["items"] as? [[String: Any]] ?? []
        func when(_ object: [String: Any]?) -> String {
            (object?["dateTime"] as? String) ?? (object?["date"] as? String) ?? ""
        }
        return items.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return CalendarSummary(
                id: id, summary: item["summary"] as? String ?? "(Không có tiêu đề)",
                start: when(item["start"] as? [String: Any]), end: when(item["end"] as? [String: Any]))
        }
    }
}
