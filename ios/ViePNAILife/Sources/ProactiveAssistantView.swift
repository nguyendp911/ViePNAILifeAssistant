import SwiftUI

/// V4.5 proactive recommendations, never a background or autonomous agent.
/// Task proposals require a second explicit approval in Action Center.
struct ProactiveAssistantView: View {
    @EnvironmentObject private var api: Gateway
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: LifeTab
    @State private var loading = false
    @State private var busyId = ""
    @State private var message = ""

    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LifeHeading(
                        name: "Proactive Assistant",
                        detail: "Đề xuất việc cần chú ý, bạn quyết định từng hành động"
                    )
                    LifePanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Kiểm soát hoàn toàn", systemImage: "shield.checkered")
                                .font(.headline)
                            Text("ViePN chỉ phân tích khi bạn mở hoặc làm mới màn hình. Không gửi dữ liệu sang AI, không chạy tác vụ nền và không tự phê duyệt.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if let feed = api.proactiveFeed {
                                HStack(spacing: 10) {
                                    LifeMetric(title: "Cần xem", count: feed.items.count, symbol: "bell.badge", tint: LifeTheme.accent)
                                    LifeMetric(title: "Đã tạm ẩn", count: feed.hiddenCount, symbol: "bell.slash", tint: LifeTheme.cyan)
                                }
                                if feed.hiddenCount > 0 {
                                    Button("Hiện lại tất cả gợi ý") {
                                        Task { await restore() }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(loading || !busyId.isEmpty)
                                }
                            }
                        }
                    }
                    if !message.isEmpty {
                        LifePanel {
                            Label(message, systemImage: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let feed = api.proactiveFeed {
                        if feed.items.isEmpty {
                            LifePanel {
                                LifeEmptyState(
                                    symbol: "checkmark.seal",
                                    title: "Không có việc cấp bách",
                                    detail: "Các gợi ý cần chú ý đã được xử lý hoặc tạm ẩn."
                                )
                            }
                        }
                        ForEach(feed.items) { suggestion in
                            LifePanel {
                                VStack(alignment: .leading, spacing: 13) {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: symbol(suggestion.level))
                                            .font(.title3)
                                            .foregroundStyle(levelColor(suggestion.level))
                                            .frame(width: 36, height: 36)
                                            .background(levelColor(suggestion.level).opacity(0.10),
                                                        in: RoundedRectangle(cornerRadius: 10))
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(suggestion.title).font(.headline)
                                            Text(suggestion.detail)
                                                .font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    if suggestion.action == "tasks" {
                                        HStack(spacing: 10) {
                                            NavigationLink {
                                                DailyBriefingView(selectedTab: $selectedTab)
                                            } label: {
                                                Label("Xem việc", systemImage: "checklist")
                                            }
                                            .buttonStyle(.bordered)
                                            Button {
                                                Task { await queue(suggestion.id) }
                                            } label: {
                                                Label("Soạn đề xuất", systemImage: "hand.raised")
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(LifeTheme.accent)
                                            .disabled(!busyId.isEmpty)
                                        }
                                    } else if suggestion.action == "approvals" {
                                        Button {
                                            selectedTab = .actions
                                            dismiss()
                                        } label: {
                                            Label("Mở Action Center", systemImage: "hand.raised.fill")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(LifeTheme.accent)
                                    } else if suggestion.action == "planner" {
                                        NavigationLink {
                                            WeeklyPlannerView()
                                        } label: {
                                            Label("Lập kế hoạch tuần", systemImage: "calendar")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(LifeTheme.accent)
                                    }
                                    HStack(spacing: 10) {
                                        Button("Nhắc lại sau 4 giờ") {
                                            Task { await snooze(suggestion.id, hours: 4) }
                                        }
                                        .buttonStyle(.bordered)
                                        Button("Ẩn 7 ngày") {
                                            Task { await snooze(suggestion.id, hours: 168) }
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    .font(.caption)
                                    .disabled(!busyId.isEmpty)
                                }
                            }
                        }
                        Text(feed.notice)
                            .font(.caption).foregroundStyle(.secondary)
                    } else if loading {
                        ProgressView("Đang tổng hợp các việc cần chú ý...")
                            .frame(maxWidth: .infinity).padding(.vertical, 35)
                    } else {
                        LifeEmptyState(
                            symbol: "wifi.exclamationmark",
                            title: "Chưa lấy được gợi ý",
                            detail: "Hãy kiểm tra kết nối đến Gateway."
                        )
                    }
                }
                .padding(.horizontal, LifeTheme.horizontal)
                .padding(.vertical, 18)
            }
            .refreshable { await load() }
        }
        .navigationTitle("Proactive Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func symbol(_ level: String) -> String {
        switch level {
        case "critical": return "exclamationmark.triangle.fill"
        case "important": return "bell.badge.fill"
        default: return "lightbulb.fill"
        }
    }
    private func levelColor(_ level: String) -> Color {
        switch level {
        case "critical": return .orange
        case "important": return LifeTheme.accent
        default: return LifeTheme.cyan
        }
    }
    private func load() async {
        loading = true
        defer { loading = false }
        do {
            try await api.loadProactiveFeed()
            message = ""
        } catch {
            message = error.localizedDescription
        }
    }
    private func snooze(_ id: String, hours: Int) async {
        guard busyId.isEmpty else { return }
        busyId = id
        defer { busyId = "" }
        do {
            try await api.snoozeProactive(id, hours: hours)
            message = "Đã tạm ẩn gợi ý trong \(hours == 4 ? "4 giờ" : "7 ngày")."
        } catch {
            message = error.localizedDescription
        }
    }
    private func restore() async {
        guard busyId.isEmpty else { return }
        busyId = "restore"
        defer { busyId = "" }
        do {
            try await api.restoreProactive()
            message = "Đã khôi phục các gợi ý đang còn phù hợp."
        } catch {
            message = error.localizedDescription
        }
    }
    private func queue(_ id: String) async {
        guard busyId.isEmpty else { return }
        busyId = id
        defer { busyId = "" }
        do {
            try await api.queueProactiveProposal(id)
            message = "Đã tạo bản nháp trong Action Center. Chỉ khi bạn phê duyệt, ghi chú mới được lưu."
        } catch {
            message = error.localizedDescription
        }
    }
}
