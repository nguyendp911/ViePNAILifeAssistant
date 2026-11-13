import SwiftUI

/// V4.2 – a native, premium workday planner. Planning does not commit changes.
/// Optional Google Calendar and model access are controlled by explicit toggles.
struct DailyPlanView: View {
    @EnvironmentObject private var api: Gateway
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: LifeTab

    @State private var startHour = 9
    @State private var endHour = 17
    @State private var focusMinutes = 25
    @State private var breakMinutes = 5
    @State private var maxTasks = 8
    @State private var includeCalendar = false
    @State private var useAI = false
    @State private var loading = false
    @State private var preview: DailyPlanPreview?
    @State private var errorText = ""
    @State private var askingToSave = false
    @State private var sentToApproval = false

    private var validWindow: Bool { endHour > startHour && endHour - startHour <= 12 }
    private func localTime(_ input: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: input) else { return input }
        return date.formatted(.dateTime.hour().minute())
    }
    private func hourText(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }

    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    LifeHeading(
                        name: "AI Daily Assistant",
                        detail: "Lên lịch làm việc phù hợp với thời gian của bạn"
                    )
                    LifePanel {
                        VStack(alignment: .leading, spacing: 13) {
                            Label("Thiết lập ngày làm việc", systemImage: "slider.horizontal.3")
                                .font(.headline)
                            HStack {
                                Picker("Bắt đầu", selection: $startHour) {
                                    ForEach(6..<22, id: \.self) { hour in
                                        Text(hourText(hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                                Spacer()
                                Picker("Kết thúc", selection: $endHour) {
                                    ForEach(7..<24, id: \.self) { hour in
                                        Text(hourText(hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            if !validWindow {
                                Text("Khung giờ cần lớn hơn 0 và không vượt 12 tiếng.")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            Picker("Phiên tập trung", selection: $focusMinutes) {
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
                                }.pickerStyle(.menu)
                                Spacer()
                                Picker("Tối đa", selection: $maxTasks) {
                                    Text("4 việc").tag(4)
                                    Text("8 việc").tag(8)
                                    Text("12 việc").tag(12)
                                }.pickerStyle(.menu)
                            }
                            Toggle(isOn: $includeCalendar) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Tránh trùng lịch Google")
                                    Text("Chỉ đọc khoảng thời gian bận khi bạn yêu cầu")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .tint(LifeTheme.accent)
                            Toggle(isOn: $useAI) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Nhận lời khuyên từ AI")
                                    Text("Gửi tên công việc và khung giờ đến nhà cung cấp AI đã cấu hình")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .tint(LifeTheme.accent)
                            Button {
                                generate()
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Tạo bản nháp kế hoạch")
                                    Spacer()
                                    if loading { ProgressView().tint(.white) }
                                }
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(LifeTheme.accent)
                            .disabled(loading || !validWindow)
                        }
                    }
                    if !errorText.isEmpty {
                        LifePanel {
                            Label(errorText, systemImage: "exclamationmark.triangle")
                                .font(.subheadline).foregroundStyle(.orange)
                        }
                    }
                    if let plan = preview {
                        LifePanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Lịch tập trung – " + plan.localDate, systemImage: "calendar.badge.clock")
                                    .font(.headline)
                                HStack(spacing: 10) {
                                    miniMetric("Đã xếp", plan.slots.count, "checkmark.circle")
                                    miniMetric("Chưa xếp", plan.unscheduledCount, "list.bullet")
                                    miniMetric("Khoảng bận", plan.busyTimes.count, "calendar")
                                }
                                if plan.slots.isEmpty {
                                    LifeEmptyState(
                                        symbol: "calendar.badge.exclamationmark",
                                        title: "Chưa thể xếp lịch",
                                        detail: "Bạn có thể tăng khung giờ hoặc giảm thời lượng mỗi phiên."
                                    )
                                } else {
                                    ForEach(Array(plan.slots.enumerated()), id: \.element.id) { number, slot in
                                        HStack(alignment: .top, spacing: 12) {
                                            Text(String(number + 1))
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.white)
                                                .frame(width: 30, height: 30)
                                                .background(LifeTheme.accent, in: Circle())
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(slot.title).font(.subheadline.bold())
                                                Text(localTime(slot.startAt) + " – " + localTime(slot.endAt))
                                                    .font(.subheadline).foregroundStyle(LifeTheme.cyan)
                                                Text(slot.reason)
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.vertical, 6)
                                    }
                                }
                                if plan.unscheduledCount > 0 {
                                    Text("Có \(plan.unscheduledCount) việc chưa có khung giờ. Không công việc nào bị xóa hoặc đánh dấu hoàn thành.")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                if let advice = plan.ai?.text, !advice.isEmpty {
                                    Divider()
                                    Label("Gợi ý AI", systemImage: "brain.head.profile")
                                        .font(.headline)
                                    Text(advice).font(.subheadline).textSelection(.enabled)
                                    Text("Nội dung AI có thể sai; hãy xem lại trước khi sử dụng.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Divider()
                                Text(plan.notice)
                                    .font(.caption).foregroundStyle(.secondary)
                                if !plan.slots.isEmpty {
                                    Button {
                                        askingToSave = true
                                    } label: {
                                        Label("Gửi kế hoạch đến Action Center", systemImage: "checkmark.shield")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent).tint(LifeTheme.accent)
                                    .disabled(loading || sentToApproval)
                                    if sentToApproval {
                                        Button("Mở Action Center") {
                                            selectedTab = .actions
                                            dismiss()
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                    } else if !loading {
                        LifeEmptyState(
                            symbol: "calendar.badge.plus",
                            title: "Kế hoạch sẽ xuất hiện tại đây",
                            detail: "Chọn giờ và nhấn Tạo bản nháp. Không có thay đổi nào được lưu tự động."
                        )
                    }
                }
                .padding(.horizontal, LifeTheme.horizontal)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Lập kế hoạch")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Gửi đề xuất tạo ghi chú kế hoạch?",
            isPresented: $askingToSave,
            titleVisibility: .visible
        ) {
            Button("Gửi để phê duyệt") { submitForApproval() }
        } message: {
            Text("ViePN chỉ tạo yêu cầu chờ duyệt. Ghi chú sẽ được lưu sau khi bạn xác nhận trong Action Center.")
        }
    }

    private func miniMetric(_ label: String, _ value: Int, _ symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(LifeTheme.accent)
            Text("\(value) \(label)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func generate() {
        guard validWindow else { return }
        loading = true
        preview = nil
        errorText = ""
        sentToApproval = false
        Task {
            defer { loading = false }
            do {
                preview = try await api.previewDailyPlan(
                    startTime: hourText(startHour), endTime: hourText(endHour),
                    focusMinutes: focusMinutes, breakMinutes: breakMinutes,
                    maxTasks: maxTasks,
                    includeCalendar: includeCalendar, useAI: useAI
                )
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func submitForApproval() {
        guard let preview else { return }
        loading = true
        Task {
            let success = await api.submitDailyPlanForApproval(preview)
            loading = false
            sentToApproval = success
            if !success { errorText = api.status }
        }
    }
}
