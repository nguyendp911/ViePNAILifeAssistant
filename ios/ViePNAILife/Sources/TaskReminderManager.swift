import Foundation
import Combine
import CryptoKit
import UserNotifications

/// Local-only notifications for explicitly opted-in work deadlines.
///
/// The system owns delivery of scheduled notifications, even while the app is closed.
/// No background scheduler, server polling, push token, AI call or contact access.
/// A change of gateway account revokes the prior account's pending reminders.
@MainActor
final class TaskReminderManager: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var leadMinutes: Int
    @Published private(set) var showTaskTitle: Bool
    @Published private(set) var pendingCount = 0
    @Published private(set) var nextReminders: [PlannedReminder] = []
    @Published private(set) var permissionDescription = "Chưa kiểm tra quyền thông báo"
    @Published var message = ""

    private static let prefix = "viepn.task.reminder."
    private static let identityKey = "viepn.reminders.accountFingerprint"
    private static let enabledKey = "viepn.reminders.enabled"
    private static let leadKey = "viepn.reminders.leadMinutes"
    private static let titleKey = "viepn.reminders.showTaskTitle"
    private let defaults = UserDefaults.standard
    private let center = UNUserNotificationCenter.current()

    init() {
        let prefs = UserDefaults.standard
        enabled = prefs.bool(forKey: Self.enabledKey)
        let savedLead = prefs.object(forKey: Self.leadKey) as? Int ?? 15
        leadMinutes = ReminderPolicy.supportedLeadMinutes.contains(savedLead) ? savedLead : 15
        showTaskTitle = prefs.bool(forKey: Self.titleKey)
    }

    private func fingerprint(token: String, baseURL: String) -> String {
        guard !token.isEmpty, !baseURL.isEmpty else { return "" }
        let source = Data((baseURL.trimmingCharacters(in: .whitespacesAndNewlines) + "|" + token).utf8)
        let digest = SHA256.hash(data: source)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func cancelOwnNotifications(removeDelivered: Bool) async {
        let requests = await center.pendingNotificationRequests()
        let ids = requests.map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        if removeDelivered {
            let delivered = await center.deliveredNotifications()
            let visibleIDs = delivered.map { $0.request.identifier }.filter { $0.hasPrefix(Self.prefix) }
            if !visibleIDs.isEmpty { center.removeDeliveredNotifications(withIdentifiers: visibleIDs) }
        }
        pendingCount = 0
        nextReminders = []
    }

    /// Called on launch, gateway URL change, login and logout.
    /// We do not retain preferences across different authenticated accounts.
    func ensureAccount(token: String, baseURL: String) async {
        let current = fingerprint(token: token, baseURL: baseURL)
        let previous = defaults.string(forKey: Self.identityKey) ?? ""
        guard current != previous else { return }
        await cancelOwnNotifications(removeDelivered: true)
        defaults.set(current, forKey: Self.identityKey)
        defaults.set(false, forKey: Self.enabledKey)
        defaults.set(15, forKey: Self.leadKey)
        defaults.set(false, forKey: Self.titleKey)
        enabled = false
        leadMinutes = 15
        showTaskTitle = false
        message = current.isEmpty
            ? "Đã tắt và xóa lịch nhắc trên thiết bị khi đăng xuất."
            : "Đã đổi tài khoản Gateway. Thông báo mặc định tắt cho tài khoản mới."
    }

    func refreshPermissionStatus() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: permissionDescription = "Đã cho phép"
        case .provisional: permissionDescription = "Thông báo tạm thời"
        case .ephemeral: permissionDescription = "Quyền tạm thời"
        case .denied: permissionDescription = "Bị từ chối trong Cài đặt iOS"
        case .notDetermined: permissionDescription = "Chưa yêu cầu"
        @unknown default: permissionDescription = "Không xác định"
        }
    }

    func enable(token: String, baseURL: String, tasks: [TaskItem]) async {
        await ensureAccount(token: token, baseURL: baseURL)
        guard !token.isEmpty, !baseURL.isEmpty else {
            message = "Cần đăng nhập Gateway trước khi bật thông báo."
            return
        }
        do {
            let allowed = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshPermissionStatus()
            guard allowed else {
                message = "iOS chưa cho phép thông báo. Vào Cài đặt → ViePN AI Life → Thông báo để bật."
                return
            }
            enabled = true
            defaults.set(true, forKey: Self.enabledKey)
            await reschedule(tasks: tasks, token: token, baseURL: baseURL)
        } catch {
            message = "Không cấp được quyền thông báo: " + error.localizedDescription
        }
    }

    func disable() async {
        enabled = false
        defaults.set(false, forKey: Self.enabledKey)
        await cancelOwnNotifications(removeDelivered: true)
        message = "Đã tắt và xóa toàn bộ thông báo công việc của ViePN."
    }

    func setPreferences(
        leadMinutes newLead: Int,
        showTaskTitle newShowTitle: Bool,
        tasks: [TaskItem],
        token: String,
        baseURL: String
    ) async {
        guard ReminderPolicy.supportedLeadMinutes.contains(newLead) else { return }
        await ensureAccount(token: token, baseURL: baseURL)
        leadMinutes = newLead
        showTaskTitle = newShowTitle
        defaults.set(newLead, forKey: Self.leadKey)
        defaults.set(newShowTitle, forKey: Self.titleKey)
        if enabled { await reschedule(tasks: tasks, token: token, baseURL: baseURL) }
    }

    /// Invoke after a SUCCESSFUL account sync, not before API data is verified.
    func reschedule(tasks: [TaskItem], token: String, baseURL: String) async {
        await ensureAccount(token: token, baseURL: baseURL)
        guard enabled else { return }
        let settings = await center.notificationSettings()
        await refreshPermissionStatus()
        let authorized: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: authorized = true
        default: authorized = false
        }
        guard authorized else {
            await cancelOwnNotifications(removeDelivered: false)
            message = "Không thể lập lịch: hãy bật quyền thông báo cho ViePN trong Cài đặt iOS."
            return
        }
        let input = tasks.map {
            ReminderInput(id: $0.id, title: $0.title, dueAt: $0.dueAt, done: $0.done)
        }
        let plan = ReminderPolicy.plan(input, leadMinutes: leadMinutes)
        // Only remove ViePN's reminder IDs, never the app's other local notifications.
        await cancelOwnNotifications(removeDelivered: false)
        var created: [PlannedReminder] = []
        for entry in plan {
            let interval = entry.fireAt.timeIntervalSinceNow
            guard interval > 1 else { continue }
            let content = UNMutableNotificationContent()
            content.title = "ViePN AI Life · Nhắc công việc"
            content.body = showTaskTitle ? String(entry.title.prefix(180)) : "Bạn có một công việc sắp đến hạn."
            content.sound = .default
            content.userInfo = ["taskId": entry.taskId]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.prefix + entry.taskId,
                content: content, trigger: trigger
            )
            do {
                try await center.add(request)
                created.append(entry)
            } catch {
                message = "Một số thông báo không lập lịch được: " + error.localizedDescription
            }
        }
        nextReminders = created
        pendingCount = created.count
        if message.isEmpty || !message.contains("không lập lịch") {
            message = "Đã lập lịch " + String(created.count) + " nhắc việc trên iPhone."
        }
    }
}
