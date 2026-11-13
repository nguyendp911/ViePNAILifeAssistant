import Foundation

/// Extension and host share only *draft text*, never credentials.
struct SharedDraft: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let capturedAt: Date
}

enum SharedDraftStore {
    static let suite = "group.com.viepn.ailife"
    static let key = "shared.drafts.v1"

    static func read() -> [SharedDraft] {
        guard let defaults = UserDefaults(suiteName: suite),
              let data = defaults.data(forKey: key),
              let drafts = try? JSONDecoder().decode([SharedDraft].self, from: data) else { return [] }
        // Expire stale drafts after 7 days rather than retaining indefinite private content.
        return drafts.filter { $0.capturedAt > Date().addingTimeInterval(-7 * 86400) }
    }

    static func save(_ drafts: [SharedDraft]) {
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        let limited = Array(drafts.suffix(20))
        if let encoded = try? JSONEncoder().encode(limited) { defaults.set(encoded, forKey: key) }
    }

    static func enqueue(_ text: String) {
        let cleaned = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(8000))
        guard !cleaned.isEmpty else { return }
        var drafts = read()
        drafts.append(SharedDraft(id: UUID(), text: cleaned, capturedAt: Date()))
        save(drafts)
    }

    static func remove(id: UUID) { save(read().filter { $0.id != id }) }
    static func clear() { save([]) }
}
