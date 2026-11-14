import Foundation

@main
struct ReminderPolicyTests {
    static func main() {
        let base = ISO8601DateFormatter().date(from: "2026-11-14T06:00:00Z")!
        func task(_ id: String, _ due: String?, _ done: Bool = false) -> ReminderInput {
            ReminderInput(id: id, title: "Việc " + id, dueAt: due, done: done)
        }
        let input = [
            task("done", "2026-11-15T06:00:00Z", true),
            task("expired", "2026-11-14T05:00:00Z"),
            task("now", "2026-11-14T06:10:00Z"),
            task("first", "2026-11-14T06:20:00Z"),
            task("second", "2026-11-14T07:20:00Z"),
            task("invalid", "tomorrow"),
            task("first", "2026-11-14T06:40:00Z"),
            task("fraction", "2026-11-14T06:30:00.000Z"),
        ]
        let plan = ReminderPolicy.plan(input, leadMinutes: 15, now: base)
        precondition(plan.map(\.taskId) == ["first", "fraction", "second"],
                     "Expected soonest future tasks, no duplicate, incomplete only")
        precondition(plan[0].fireAt == ISO8601DateFormatter().date(from: "2026-11-14T06:05:00Z")!)
        precondition(ReminderPolicy.plan(input, leadMinutes: 17, now: base).isEmpty)
        let sameTime = [
            task("z", "2026-11-14T08:00:00Z"),
            task("a", "2026-11-14T08:00:00Z")
        ]
        precondition(ReminderPolicy.plan(sameTime, leadMinutes: 0, now: base).map(\.taskId) == ["a", "z"])
        let many = (0..<80).map { task("id" + String($0), "2026-11-15T08:00:00Z") }
        precondition(ReminderPolicy.plan(many, leadMinutes: 60, now: base).count == 48,
                     "Never exceed the OS pending notification safety cap")
        precondition(ReminderPolicy.plan(many, leadMinutes: 60, now: base, limit: 3).count == 3)
        precondition(ReminderPolicy.plan([], leadMinutes: 15, now: base).isEmpty)
        print("REMINDER_POLICY_TESTS_PASS: deadlines, privacy cap, ordering, de-duplication, invalid input")
    }
}
