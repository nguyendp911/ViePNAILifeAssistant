import Foundation
import CryptoKit

/// Separate on-device chat histories by Gateway URL and credential fingerprint.
/// Never store raw credentials in paths or chat files.
enum ChatHistory {
    private static func file(token: String, baseURL: String) throws -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digest = SHA256.hash(data: Data((normalized + "\u{0}" + token).utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("chat-" + name + ".json")
    }
    static func load(token: String, baseURL: String) -> [ChatLine] {
        guard let url = try? file(token: token, baseURL: baseURL),
              let data = try? Data(contentsOf: url),
              let lines = try? JSONDecoder().decode([ChatLine].self, from: data) else { return [] }
        return Array(lines.suffix(100))
    }
    static func save(_ messages: [ChatLine], token: String, baseURL: String) throws {
        let url = try file(token: token, baseURL: baseURL)
        let data = try JSONEncoder().encode(Array(messages.suffix(100)))
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }
    /// Enforce both server-side context quotas on-device. Only chat turns, never notes/memory/docs.
    static func recentContext(_ messages: [ChatLine]) -> [ChatLine] {
        var selected: [ChatLine] = []
        var total = 0
        for line in messages.reversed() {
            let trimmed = String(line.text.prefix(3000))
            guard !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if selected.count >= 12 || total + trimmed.count > 12000 { break }
            selected.append(ChatLine(id: line.id, user: line.user, text: trimmed))
            total += trimmed.count
        }
        return selected.reversed()
    }
    static func clear(token: String, baseURL: String) throws {
        let url = try file(token: token, baseURL: baseURL)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
