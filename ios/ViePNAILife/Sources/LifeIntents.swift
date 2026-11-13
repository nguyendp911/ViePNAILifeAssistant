import AppIntents

/// This shortcut opens the app; it never executes a privileged action unattended.
@available(iOS 17.0, *)
struct OpenViePNIntent: AppIntent {
    static var title: LocalizedStringResource = "Mở ViePN AI Life"
    static var description = IntentDescription("Mở trợ lý ViePN để xem và duyệt công việc.")
    static var openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult { .result() }
}

@available(iOS 17.0, *)
struct ViePNAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenViePNIntent(), phrases: ["Mở trợ lý với \(.applicationName)", "Bắt đầu với \(.applicationName)"], shortTitle: "Mở trợ lý", systemImageName: "sparkles")
    }
}
