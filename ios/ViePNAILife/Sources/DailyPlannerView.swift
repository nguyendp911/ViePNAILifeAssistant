import SwiftUI

/// V4.2: the daily schedule is a preview; no events or actions are executed here.
/// Google Calendar and the AI provider are opt-in for EACH preview.
struct DailyPlannerView: View {
    @EnvironmentObject private var api: Gateway
    @State private var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var endTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: .now) ?? .now
    @State private var focusMinutes = 25
    @State private var breakMinutes = 5
    @State private var maxTasks = 8
    @State private var includeCalendar = false
    @State private var useAI = false
    @State private var loading = false
    @State private var submitting = false
    @State private var preview: DailyPlanPreview?
    @State private var feedback = ""
    @State private var submitted = false

    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LifeHeading(name: "AI Daily Assistant", detail: "Tạo lịch tập trung cá nhân – bạn luôn quyết định")
                    LifePanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Thiết lập ngày làm việc", systemImage: "clock.badge.checkmark")
                                .font(.headline)
                            DatePicker("Bắt đầu", selection: $startTime, displayedComponents: .hourAndMinute)
                            DatePicker("Kết thúc", selection: $endTime, displayedComponents: .hourAndMinute)
                            Divider()
                            HStack {
                                Text("Tập trung")
                                Spacer()
                                Picker("Tập trung", selection: $focusMinutes) {
                                    Text("15 phút").tag(15)
                                    Text("25 phút").tag(25)
                                    Text("45 phút").tag(45)
                                    Text("60 phút").tag(60)
                                    Text("90 phút").tag(90)
                                }.labelsHidden()
                            }
                            HStack {
                                Text("Nghỉ giữa phiên")
                                Spacer()
                                Picker("Nghỉ", selection: $breakMinutes) {
                                    Text("Không").tag(0)
                                    Text("5 phút").tag(5)
                                    Text("10 phút").tag(10)
                                    Text("15 phút").tag(15)
                                    Text("30 phút").tag(30)
                                }.labelsHidden()
                            }
                            Stepper("Tối đa \(maxTasks) công việc", value: $maxTasks, in: 1...12)
                            Divider()
                            Toggle(isOn: $includeCalendar) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Tránh giờ bận Google Calendar")
                                    Text("Chỉ truy cập lịch nếu bạn đã kết nối và bật lựa chọn này.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }.tint(LifeTheme.accent)
                            Toggle(isOn: $useAI) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("AI góp ý cho bản kế hoạch")
                                    Text("Khi bật, tên công việc và giờ đề xuất sẽ được gửi đến AI Gateway.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }.tint(LifeTheme.accent)
                            Button {
                                Task { await generate() }
                            } label: {
                                HStack {
                                    if loading { ProgressView().tint(.white) }
                                    else { Image(systemName: "sparkles") }
                                    Text("Tạo bản xem trước").fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(LifeTheme.accent)
                            .disabled(loading || submitting)
                        }
                    }
                    if !feedback.isEmpty {
                        LifePanel {
                            Label(feedback, systemImage: submitted ? "checkmark.circle.fill" : "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(submitted ? Color.green : Color.secondary)
                        }
                    }
                    if let plan = preview {
                        LifeHeading(name: "Bản nháp \(plan.localDate)", detail: "Chưa tạo lịch, chưa thực thi công việc")
                        HStack(spacing: 10) {
                            LifeMetric(title: "Đã xếp", count: plan.slots.count, symbol: "list.number", tint: LifeTheme.accent)
                            LifeMetric(title: "Chưa xếp", count: plan.unscheduledCount, symbol: "clock", tint: .orange)
                        }
                        if plan.calendarUsed {
                            Label("Đã tránh \(plan.busyTimes.count) khoảng bận trong Calendar", systemImage: "calendar.badge.checkmark")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if plan.slots.isEmpty {
                            LifePanel {
                                LifeEmptyState(symbol: "calendar.badge.exclamationmark", title: "Chưa có phiên phù hợp", detail: "Thử tăng khung giờ hoặc giảm thời lượng tập trung.")
                            }
                        }
                        ForEach(Array(plan.slots.enumerated()), id: \.element.id) { index, slot in
                            LifePanel {
                                HStack(alignment: .top, spacing: 13) {
                                    Text("\(index + 1)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 33, height: 33)
                                        .background(LifeTheme.accent, in: Circle())
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(slot.title).font(.headline)
                                        Text("\(shortTime(slot.startAt)) – \(shortTime(slot.endAt)) · \(slot.estimatedMinutes) phút")
                                            .font(.subheadline).foregroundStyle(LifeTheme.cyan)
                                        Text(slot.reason).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        if let advice = plan.ai, advice.configured && !advice.text.isEmpty {
                            LifePanel {
                                VStack(alignment: .leading, spacing: 9) {
                                    Label("Gợi ý AI · chỉ tham khảo", systemImage: "brain.head.profile")
                                        .font(.headline)
                                    Text(advice.text).font(.subheadline).textSelection(.enabled)
                                }
                            }
                        }
                        if plan.unscheduledCount > 0 {
                            Text("Còn \(plan.unscheduledCount) công việc chưa xếp được. Bạn có thể điều chỉnh cài đặt và tạo lại bản nháp.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text(plan.notice).font(.caption).foregroundStyle(.secondary)
                        Button {
                            Task { await sendToApproval(plan) }
                        } label: {
                            HStack {
                                if submitting { ProgressView().tint(.white) }
                                else { Image(systemName: "hand.raised.fill") }
                                Text("Gửi bản nháp đến Action Center").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(LifeTheme.accent)
                        .disabled(plan.slots.isEmpty || loading || submitting || submitted)
                        Text("Chỉ tạo yêu cầu phê duyệt ghi chú. Bạn phải duyệt trong Action Center trước khi lưu.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, LifeTheme.horizontal)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Daily Planner")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func timeText(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 9, comps.minute ?? 0)
    }

    private func shortTime(_ value: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fmt.date(from: value) else { return value }
        return date.formatted(.dateTime.hour().minute())
    }

    private func generate() async {
        loading = true
        feedback = ""
        submitted = false
        preview = nil
        defer { loading = false }
        do {
            preview = try await api.previewDailyPlan(
                startTime: timeText(startTime),
                endTime: timeText(endTime),
                focusMinutes: focusMinutes,
                breakMinutes: breakMinutes,
                maxTasks: maxTasks,
                includeCalendar: includeCalendar,
                useAI: useAI
            )
        } catch {
            feedback = error.localizedDescription
        }
    }

    private func sendToApproval(_ plan: DailyPlanPreview) async {
        submitting = true
        defer { submitting = false }
        submitted = await api.submitDailyPlanForApproval(plan)
        feedback = api.status
    }
}
