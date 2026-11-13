import SwiftUI

/// Weekly planning is deterministic and preview-only.
/// Focus history is manually reported with explicit consent, not background tracking.
struct WeeklyPlannerView: View {
    @EnvironmentObject private var api: Gateway
    @State private var weekOffset = 1
    @State private var startHour = 9
    @State private var endHour = 17
    @State private var focusMinutes = 25
    @State private var breakMinutes = 5
    @State private var maxTasksPerDay = 5
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5]
    @State private var useHabits = false
    @State private var loggedMinutes = 25
    @State private var loading = false
    @State private var submitting = false
    @State private var preview: WeeklyPlanPreview?
    @State private var message = ""
    @State private var submitted = false
    @State private var askingToErase = false
    @State private var askingToSubmit = false

    private let weekdayNames = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
    private var valid: Bool { endHour > startHour && endHour-startHour <= 12 && !selectedDays.isEmpty }

    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LifeHeading(name: "Weekly Intelligence", detail: "Lịch tuần, mức ưu tiên và thói quen tập trung")
                    LifePanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Thiết lập kế hoạch tuần", systemImage: "calendar")
                                .font(.headline)
                            Picker("Tuần", selection: $weekOffset) {
                                Text("Tuần này").tag(0)
                                Text("Tuần sau").tag(1)
                            }
                            .pickerStyle(.segmented)
                            HStack {
                                Picker("Bắt đầu", selection: $startHour) {
                                    ForEach(6..<22, id: \.self) { hour in
                                        Text(String(format: "%02d:00", hour)).tag(hour)
                                    }
                                }
                                Spacer()
                                Picker("Kết thúc", selection: $endHour) {
                                    ForEach(7..<24, id: \.self) { hour in
                                        Text(String(format: "%02d:00", hour)).tag(hour)
                                    }
                                }
                            }
                            HStack(spacing: 5) {
                                ForEach(1...7, id: \.self) { day in
                                    Button {
                                        if selectedDays.contains(day) {
                                            if selectedDays.count > 1 { selectedDays.remove(day) }
                                        } else {
                                            selectedDays.insert(day)
                                        }
                                    } label: {
                                        Text(weekdayNames[day-1])
                                            .font(.caption.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 11)
                                            .background(
                                                selectedDays.contains(day) ? LifeTheme.accent : Color.primary.opacity(0.07),
                                                in: RoundedRectangle(cornerRadius: 10)
                                            )
                                            .foregroundStyle(selectedDays.contains(day) ? Color.white : Color.primary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Chọn ngày " + weekdayNames[day-1])
                                }
                            }
                            Picker("Thời lượng phiên", selection: $focusMinutes) {
                                Text("25 phút").tag(25)
                                Text("45 phút").tag(45)
                                Text("60 phút").tag(60)
                                Text("90 phút").tag(90)
                            }
                            .pickerStyle(.segmented)
                            HStack {
                                Picker("Nghỉ giữa phiên", selection: $breakMinutes) {
                                    Text("0p").tag(0)
                                    Text("5p").tag(5)
                                    Text("10p").tag(10)
                                    Text("15p").tag(15)
                                }
                                Spacer()
                                Picker("Mỗi ngày", selection: $maxTasksPerDay) {
                                    Text("2 việc").tag(2)
                                    Text("4 việc").tag(4)
                                    Text("5 việc").tag(5)
                                    Text("8 việc").tag(8)
                                }
                            }
                            Toggle("Gợi ý giờ dựa vào thói quen đã lưu", isOn: $useHabits)
                                .tint(LifeTheme.accent)
                                .disabled(api.focusHistoryStatus?.enabled != true)
                            Text("Chỉ phân tích dữ liệu bạn tự ghi nhận. Không gửi lịch sử tập trung đến AI.")
                                .font(.caption).foregroundStyle(.secondary)
                            if !valid {
                                Label("Cần ít nhất một ngày làm việc và khung giờ tối đa 12 tiếng.", systemImage: "exclamationmark.triangle")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            Button {
                                Task { await makePreview() }
                            } label: {
                                HStack {
                                    if loading { ProgressView().tint(.white) }
                                    else { Image(systemName: "sparkles") }
                                    Text("Đề xuất kế hoạch tuần")
                                        .fontWeight(.semibold)
                                }.frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(LifeTheme.accent)
                            .disabled(!valid || loading || submitting)
                        }
                    }
                    focusPanel
                    if !message.isEmpty {
                        LifePanel {
                            Label(message, systemImage: submitted ? "checkmark.circle.fill" : "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(submitted ? Color.green : Color.secondary)
                        }
                    }
                    if let plan = preview {
                        LifeHeading(name: "Tuần \(plan.weekStart) – \(plan.weekEnd)", detail: "Bản nháp, chưa thực hiện hay thay đổi thời hạn")
                        HStack(spacing: 10) {
                            LifeMetric(title: "Đã xếp", count: plan.scheduledCount, symbol: "calendar.badge.checkmark", tint: LifeTheme.accent)
                            LifeMetric(title: "Chưa xếp", count: plan.unscheduledCount, symbol: "list.bullet", tint: LifeTheme.cyan)
                            LifeMetric(title: "Cảnh báo", count: plan.atRiskCount, symbol: "exclamationmark.triangle", tint: .orange)
                        }
                        if let hour = plan.habitSuggestedHour, plan.settings.useHabits {
                            Label("Giờ tập trung thường chọn: \(String(format: "%02d:00", hour))", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(plan.days) { day in
                            if !day.slots.isEmpty {
                                LifePanel {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("\(weekdayNames[day.weekday-1]) · \(day.date)")
                                            .font(.headline)
                                        ForEach(day.slots) { slot in
                                            HStack(alignment: .top, spacing: 10) {
                                                Image(systemName: slot.deadlineAtRisk ? "exclamationmark.circle.fill" : "circle.dotted.circle")
                                                    .foregroundStyle(slot.deadlineAtRisk ? Color.orange : LifeTheme.accent)
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(slot.title).font(.subheadline.weight(.medium))
                                                    Text("\(displayTime(slot.startAt)) – \(displayTime(slot.endAt)) · \(slot.reason)")
                                                        .font(.caption).foregroundStyle(.secondary)
                                                    if slot.deadlineAtRisk {
                                                        Text("Nguy cơ vượt hạn: cần kiểm tra lại")
                                                            .font(.caption).foregroundStyle(.orange)
                                                    }
                                                }
                                                Spacer(minLength: 0)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                            }
                        }
                        if plan.scheduledCount == 0 {
                            LifePanel {
                                LifeEmptyState(symbol: "calendar.badge.exclamationmark", title: "Chưa xếp được công việc", detail: "Thử chọn tuần sau, thêm ngày hoặc mở rộng giờ làm.")
                            }
                        }
                        Text(plan.notice).font(.caption).foregroundStyle(.secondary)
                        Button {
                            askingToSubmit = true
                        } label: {
                            Label("Gửi đề xuất đến Action Center", systemImage: "checkmark.shield")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(LifeTheme.accent)
                        .disabled(plan.scheduledCount == 0 || submitting || submitted)
                        Text("Chỉ tạo một ghi chú chờ phê duyệt; bạn cần xác nhận thêm trong Action Center.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, LifeTheme.horizontal)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Kế hoạch tuần")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshFocus() }
        .confirmationDialog("Tắt và xóa vĩnh viễn toàn bộ lịch sử tập trung?", isPresented: $askingToErase) {
            Button("Tắt và xóa lịch sử", role: .destructive) { Task { await consent(false) } }
        } message: {
            Text("Dữ liệu về số phút, số phiên và giờ tập trung sẽ bị xóa khỏi tài khoản.")
        }
        .confirmationDialog("Gửi bản nháp kế hoạch tuần để phê duyệt?", isPresented: $askingToSubmit) {
            Button("Gửi đến Action Center") { Task { await submitPlan() } }
        } message: {
            Text("Chỉ tạo yêu cầu lưu ghi chú. Không sửa lịch Google hay tự thực hiện công việc.")
        }
    }

    private var focusPanel: some View {
        LifePanel {
            VStack(alignment: .leading, spacing: 11) {
                Label("Nhật ký tập trung tự nguyện", systemImage: "timer")
                    .font(.headline)
                if let data = api.focusHistoryStatus {
                    if data.enabled {
                        HStack(spacing: 10) {
                            LifeMetric(title: "Số phiên", count: data.insights.sessions, symbol: "checkmark.circle", tint: LifeTheme.accent)
                            LifeMetric(title: "Tổng phút", count: data.insights.totalMinutes, symbol: "clock", tint: LifeTheme.cyan)
                        }
                        HStack {
                            Picker("Thời lượng đã hoàn thành", selection: $loggedMinutes) {
                                Text("25 phút").tag(25)
                                Text("45 phút").tag(45)
                                Text("60 phút").tag(60)
                                Text("90 phút").tag(90)
                            }
                            Button("Ghi nhận") { Task { await recordSession() } }
                                .buttonStyle(.borderedProminent).tint(LifeTheme.accent)
                        }
                        Text("Chỉ nhấn Ghi nhận sau một phiên bạn thực sự hoàn thành. Không theo dõi nền hoặc nội dung ứng dụng.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Tắt và xóa toàn bộ lịch sử", role: .destructive) {
                            askingToErase = true
                        }
                        .font(.subheadline)
                    } else {
                        Text("Mặc định tắt. Bạn có thể bật ghi nhận thủ công để ViePN đề xuất giờ tập trung phù hợp, và xóa dữ liệu bất cứ lúc nào.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Bật ghi nhận phiên tập trung") { Task { await consent(true) } }
                            .buttonStyle(.bordered)
                    }
                } else {
                    ProgressView("Đang tải trạng thái dữ liệu...")
                }
            }
        }
    }

    private func displayTime(_ value: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let time = parser.date(from: value) else { return value }
        return time.formatted(.dateTime.hour().minute())
    }
    private func hh(_ value: Int) -> String { String(format: "%02d:00", value) }

    private func refreshFocus() async {
        do { try await api.loadFocusHistory() }
        catch { message = error.localizedDescription }
    }
    private func consent(_ enabled: Bool) async {
        do {
            try await api.changeFocusConsent(enabled)
            if !enabled { useHabits = false }
            message = enabled ? "Đã bật ghi nhận thủ công." : "Đã tắt và xóa toàn bộ lịch sử tập trung."
        } catch { message = error.localizedDescription }
    }
    private func recordSession() async {
        do {
            try await api.recordFocusSession(loggedMinutes)
            message = "Đã ghi nhận \(loggedMinutes) phút tập trung do bạn xác nhận."
        } catch { message = error.localizedDescription }
    }
    private func makePreview() async {
        guard valid else { return }
        loading = true
        preview = nil
        message = ""
        submitted = false
        defer { loading = false }
        do {
            preview = try await api.previewWeeklyPlan(
                weekOffset: weekOffset, workdays: selectedDays.sorted(),
                startTime: hh(startHour), endTime: hh(endHour),
                focusMinutes: focusMinutes, breakMinutes: breakMinutes,
                maxTasksPerDay: maxTasksPerDay, useHabits: useHabits
            )
        } catch { message = error.localizedDescription }
    }
    private func submitPlan() async {
        guard let preview else { return }
        submitting = true
        defer { submitting = false }
        submitted = await api.sendWeeklyPlanForApproval(preview)
        message = api.status
    }
}
