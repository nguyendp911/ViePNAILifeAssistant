import SwiftUI

/// V4.1 Smart Day: private, read-only daily briefing computed by the user's Gateway.
/// No external AI requests, auto-approvals, background tracking or notifications.
struct DailyBriefingView: View {
    @EnvironmentObject private var api: Gateway
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: LifeTab

    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LifeHeading(name: "Tổng quan hôm nay", detail: "Dữ liệu của tài khoản hiện tại · không gửi đến AI")
                    NavigationLink {
                        DailyPlannerView()
                    } label: {
                        LifePanel {
                            HStack(spacing: 13) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.title2)
                                    .foregroundStyle(LifeTheme.cyan)
                                    .frame(width: 44, height: 44)
                                    .background(LifeTheme.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Lập kế hoạch tập trung").font(.headline)
                                    Text("Xếp giờ làm việc, tránh lịch bận và nhận gợi ý AI tùy chọn")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        DailyPlanView(selectedTab: $selectedTab)
                    } label: {
                        Label("Lập lịch tập trung với AI Daily Assistant", systemImage: "sparkles.rectangle.stack")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LifeTheme.accent)
                    if let briefing = api.dailyBriefing {
                        HStack(spacing: 9) {
                            LifeMetric(title: "Đến hạn", count: briefing.summary.dueToday, symbol: "calendar", tint: LifeTheme.cyan)
                            LifeMetric(title: "Quá hạn", count: briefing.summary.overdue, symbol: "exclamationmark.circle", tint: .orange)
                            LifeMetric(title: "Chờ duyệt", count: briefing.summary.pendingApprovals, symbol: "hand.raised", tint: LifeTheme.accent)
                        }
                        LifePanel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("Ưu tiên công việc", systemImage: "checklist")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(briefing.summary.openTasks) chưa xong")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if briefing.priorities.isEmpty {
                                    LifeEmptyState(symbol: "checkmark.seal", title: "Đã hoàn tất", detail: "Không có công việc đang mở.")
                                } else {
                                    ForEach(briefing.priorities) { item in
                                        HStack(alignment: .center, spacing: 12) {
                                            Button {
                                                Task {
                                                    if let task = api.tasks.first(where: { $0.id == item.id }) {
                                                        await api.setTaskDone(task, done: true)
                                                        await api.loadDailyBriefing()
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "circle")
                                                    .font(.title3).foregroundStyle(LifeTheme.accent)
                                            }
                                            .accessibilityLabel("Hoàn thành " + item.title)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.title).font(.subheadline.weight(.medium))
                                                Text(kindLabel(item.kind))
                                                    .font(.caption)
                                                    .foregroundStyle(item.kind == "overdue" ? Color.orange : Color.secondary)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.vertical, 5)
                                    }
                                    if briefing.summary.openTasks > briefing.priorities.count {
                                        Text("Hiển thị 12 công việc ưu tiên đầu tiên.")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        LifePanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Hành động cần bạn phê duyệt", systemImage: "hand.raised.fill")
                                    .font(.headline)
                                HStack {
                                    metric("Thao tác", briefing.approvals.actions)
                                    Spacer()
                                    metric("Quy trình", briefing.approvals.workflows)
                                    Spacer()
                                    metric("Lịch", briefing.approvals.automations)
                                }
                                if briefing.approvals.total > 0 {
                                    Button("Mở Action Center") {
                                        selectedTab = .actions
                                        dismiss()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(LifeTheme.accent)
                                } else {
                                    Text("Không có yêu cầu nào đang chờ.")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                        LifePanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Lịch tự động trong 48 giờ", systemImage: "clock.arrow.circlepath")
                                    .font(.headline)
                                if briefing.upcomingAutomations.isEmpty {
                                    Text("Chưa có lịch tự động nào sắp đến hạn.")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                } else {
                                    ForEach(briefing.upcomingAutomations) { item in
                                        HStack {
                                            Image(systemName: "clock").foregroundStyle(LifeTheme.cyan)
                                            Text(item.title).font(.subheadline)
                                            Spacer()
                                        }
                                        .padding(.vertical, 3)
                                    }
                                    if briefing.summary.scheduledSoon > briefing.upcomingAutomations.count {
                                        Text("Còn \(briefing.summary.scheduledSoon - briefing.upcomingAutomations.count) lịch khác.")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Text("ViePN chỉ nhắc bạn xem xét, không tự thực hiện các hành động.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text("Cập nhật lúc " + briefing.generatedAt)
                            .font(.caption2).foregroundStyle(.secondary)
                    } else if !api.dailyBriefingStatus.isEmpty {
                        LifeEmptyState(symbol: "wifi.exclamationmark", title: "Chưa lấy được bản tin", detail: api.dailyBriefingStatus)
                        Button("Thử lại") { Task { await api.loadDailyBriefing() } }
                            .buttonStyle(.bordered)
                    } else {
                        ProgressView("Đang tổng hợp...")
                            .frame(maxWidth: .infinity).padding(.vertical, 36)
                    }
                }
                .padding(.horizontal, LifeTheme.horizontal)
                .padding(.vertical, 20)
            }
            .refreshable { await api.loadDailyBriefing() }
        }
        .navigationTitle("Smart Day")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Đóng") { dismiss() }
            }
        }
        .task { await api.loadDailyBriefing() }
    }

    private func metric(_ title: String, _ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(count.formatted()).font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "overdue": return "Đã quá hạn"
        case "today": return "Đến hạn hôm nay"
        case "upcoming": return "Đến hạn ngày mai"
        default: return "Chưa đặt thời hạn"
        }
    }
}
