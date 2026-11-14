import SwiftUI

/// Native, opt-in iPhone reminder controls. Notifications are managed by iOS,
/// not by server-side polling or an always-running assistant.
struct TaskRemindersView: View {
    @EnvironmentObject private var api: Gateway
    @EnvironmentObject private var reminders: TaskReminderManager
    @State private var lead = 15
    @State private var showNames = false
    @State private var busy = false
    @State private var askToDisable = false
    @State private var errorText = ""

    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LifeHeading(name: "Smart Reminders", detail: "Nhắc việc đúng hạn trên iPhone, kể cả khi ứng dụng đóng")
                    LifePanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Quyền thông báo", systemImage: "bell.badge")
                                .font(.headline)
                            HStack {
                                Text(reminders.permissionDescription)
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                if reminders.enabled {
                                    Label("Đã bật", systemImage: "checkmark.circle.fill")
                                        .font(.caption.bold()).foregroundStyle(.green)
                                } else {
                                    Text("Đang tắt").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Text("Chỉ bật khi bạn xác nhận yêu cầu cấp quyền của iOS. Không gửi nội dung công việc đến máy chủ thông báo hoặc dịch vụ AI.")
                                .font(.caption).foregroundStyle(.secondary)
                            if reminders.enabled {
                                Button {
                                    askToDisable = true
                                } label: {
                                    Label("Tắt và xóa tất cả lịch nhắc", systemImage: "bell.slash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(busy)
                            } else {
                                Button {
                                    Task { await turnOn() }
                                } label: {
                                    HStack {
                                        if busy { ProgressView().tint(.white) }
                                        else { Image(systemName: "bell.badge.fill") }
                                        Text("Bật nhắc việc trên iPhone")
                                    }
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(LifeTheme.accent)
                                .disabled(busy)
                            }
                        }
                    }
                    LifePanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Cài đặt nhắc hạn", systemImage: "slider.horizontal.3")
                                .font(.headline)
                            Picker("Thời điểm nhắc", selection: $lead) {
                                Text("Đúng giờ đến hạn").tag(0)
                                Text("Trước 5 phút").tag(5)
                                Text("Trước 15 phút").tag(15)
                                Text("Trước 1 giờ").tag(60)
                                Text("Trước 1 ngày").tag(1440)
                            }
                            .pickerStyle(.menu)
                            Toggle(isOn: $showNames) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Hiển thị tên công việc trong thông báo")
                                    Text("Mặc định ẩn tên để hạn chế lộ thông tin trên màn hình khóa.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .tint(LifeTheme.accent)
                            Text("Chỉ nhắc công việc chưa hoàn thành có thời hạn hợp lệ trong tương lai. Tối đa 48 thông báo chờ, ưu tiên việc gần hạn nhất.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    LifePanel {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Label("Lịch đã tạo trên thiết bị", systemImage: "calendar.badge.clock")
                                    .font(.headline)
                                Spacer()
                                Text(String(reminders.pendingCount))
                                    .font(.title3.bold())
                                    .monospacedDigit()
                            }
                            if reminders.nextReminders.isEmpty {
                                LifeEmptyState(
                                    symbol: "bell.slash.circle",
                                    title: "Chưa có lịch nhắc",
                                    detail: "Bật quyền và thêm thời hạn cho công việc để lên lịch."
                                )
                            } else {
                                ForEach(reminders.nextReminders.prefix(12), id: \.taskId) { reminder in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "clock")
                                            .foregroundStyle(LifeTheme.accent)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(reminder.title)
                                                .font(.subheadline.weight(.medium))
                                            Text(reminder.fireAt.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 3)
                                }
                                if reminders.pendingCount > 12 {
                                    Text("Hiển thị 12 lịch gần nhất trong tổng số \(reminders.pendingCount).")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Button {
                                Task { await sync() }
                            } label: {
                                Label("Đồng bộ lại lịch nhắc", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(busy || !reminders.enabled)
                        }
                    }
                    if !reminders.message.isEmpty {
                        LifePanel {
                            Label(reminders.message, systemImage: "info.circle")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if !errorText.isEmpty {
                        LifePanel {
                            Label(errorText, systemImage: "exclamationmark.triangle")
                                .font(.subheadline).foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.horizontal, LifeTheme.horizontal)
                .padding(.vertical, 18)
            }
            .refreshable { await sync() }
        }
        .navigationTitle("Smart Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reminders.ensureAccount(token: api.token, baseURL: api.baseURL)
            lead = reminders.leadMinutes
            showNames = reminders.showTaskTitle
            await reminders.refreshPermissionStatus()
            if reminders.enabled { await sync() }
        }
        .onChange(of: lead) { _, value in
            Task {
                await reminders.setPreferences(
                    leadMinutes: value, showTaskTitle: showNames,
                    tasks: api.tasks, token: api.token, baseURL: api.baseURL
                )
            }
        }
        .onChange(of: showNames) { _, value in
            Task {
                await reminders.setPreferences(
                    leadMinutes: lead, showTaskTitle: value,
                    tasks: api.tasks, token: api.token, baseURL: api.baseURL
                )
            }
        }
        .confirmationDialog(
            "Tắt thông báo và xóa toàn bộ lịch nhắc công việc trên iPhone?",
            isPresented: $askToDisable,
            titleVisibility: .visible
        ) {
            Button("Tắt và xóa lịch nhắc", role: .destructive) {
                Task { await reminders.disable() }
            }
        } message: {
            Text("Không xóa công việc trên Gateway; chỉ hủy các thông báo của ViePN trên thiết bị.")
        }
    }

    private func sync() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        await api.refresh()
        guard api.status == "Đã đồng bộ." else {
            errorText = "Chưa đồng bộ được dữ liệu tài khoản. Không thay đổi lịch nhắc hiện có."
            return
        }
        errorText = ""
        await reminders.reschedule(tasks: api.tasks, token: api.token, baseURL: api.baseURL)
    }

    private func turnOn() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        await api.refresh()
        guard api.status == "Đã đồng bộ." else {
            errorText = "Chưa thể xác minh danh sách công việc. Hãy kiểm tra kết nối Gateway trước khi bật."
            return
        }
        errorText = ""
        await reminders.enable(token: api.token, baseURL: api.baseURL, tasks: api.tasks)
    }
}
