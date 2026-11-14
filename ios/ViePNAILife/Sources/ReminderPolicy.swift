import Foundation

/// Deterministic and side-effect-free reminder selection, suitable for offline testing.
/// We schedule only future, incomplete tasks with valid ISO-8601 deadlines.
/// iOS may keep a limited number of pending notifications, so retain the soonest 48.
struct ReminderInput {
    let id: String
    let title: String
    let dueAt: String?
    let done: Bool
}

struct PlannedReminder {
    let taskId: String
    let title: String
    let dueAt: Date
    let fireAt: Date
}

enum ReminderPolicy {
    static let supportedLeadMinutes: [Int] = [0, 5, 15, 60, 1440]
    static let maximumPending = 48
    private static let formatter: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter()
        value.formatOptions = [.withInternetDateTime]
        return value
    }()
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter()
        value.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return value
    }()

    static func plan(
        _ tasks: [ReminderInput],
        leadMinutes: Int,
        now: Date = Date(),
        limit: Int = maximumPending
    ) -> [PlannedReminder] {
        guard supportedLeadMinutes.contains(leadMinutes), limit > 0 else { return [] }
        let leadSeconds = TimeInterval(leadMinutes) * 60
        let future = now.addingTimeInterval(1)
        var seen = Set<String>()
        let candidates: [PlannedReminder] = tasks.compactMap { task in
            guard !task.done, !task.id.isEmpty, !seen.contains(task.id),
                  let raw = task.dueAt,
                  let due = fractionalFormatter.date(from: raw) ?? formatter.date(from: raw)
            else { return nil }
            let fire = due.addingTimeInterval(-leadSeconds)
            guard fire > future else { return nil }
            seen.insert(task.id)
            return PlannedReminder(taskId: task.id, title: task.title, dueAt: due, fireAt: fire)
        }
        return Array(candidates.sorted {
            if $0.fireAt != $1.fireAt { return $0.fireAt < $1.fireAt }
            return $0.taskId < $1.taskId
        }.prefix(min(limit, maximumPending)))
    }
}
