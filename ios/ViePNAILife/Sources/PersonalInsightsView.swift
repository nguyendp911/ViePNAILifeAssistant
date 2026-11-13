import SwiftUI

/// V4.4 Personal AI Intelligence: insights are local to the user's Gateway;
/// sending private context to an AI provider requires a new explicit opt-in.
struct PersonalInsightsView: View {
    @EnvironmentObject private var api: Gateway
    @State private var insights: PersonalInsightsResponse?
    @State private var loading = false
    @State private var asking = false
    @State private var errorText = ""
    @State private var question = ""
    @State private var shareTasks = false
    @State private var shareMemories = false
    @State private var shareDocuments = false
    @State private var consent = false
    @State private var response: PersonalAIAnswer?

    private var hasScope: Bool { shareTasks || shareMemories || shareDocuments }
    private var canAsk: Bool {
        !asking && !loading && consent && hasScope &&
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LifeHeading(
                        name: "Personal Intelligence",
                        detail: "Phân tích tiến độ riêng tư và trợ lý AI theo phạm vi bạn cho phép"
                    )
                    if let insight = insights {
                        HStack(spacing: 10) {
                            LifeMetric(title: "Hoàn thành", count: insight.progress.completionPercent, symbol: "chart.bar.fill", tint: LifeTheme.accent)
                            LifeMetric(title: "Đang mở", count: insight.progress.open, symbol: "list.bullet", tint: LifeTheme.cyan)
                            LifeMetric(title: "Quá hạn", count: insight.progress.overdue, symbol: "exclamationmark.circle", tint: .orange)
                        }
                        Text("Tỉ lệ hoàn thành tính theo % số công việc đã ghi nhận; không phải điểm đánh giá năng suất.")
                            .font(.caption).foregroundStyle(.secondary)
                        LifePanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Tiến độ công việc", systemImage: "chart.bar.xaxis")
                                    .font(.headline)
                                ProgressView(value: Double(insight.progress.completionPercent), total: 100)
                                    .tint(LifeTheme.accent)
                                HStack {
                                    Text("\(insight.progress.completed) hoàn thành / \(insight.progress.total) công việc")
                                    Spacer()
                                    Text("\(insight.progress.dueNext7Days) đến hạn trong 7 ngày")
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        LifePanel {
                            VStack(alignment: .leading, spacing: 11) {
                                Label("Ưu tiên đề xuất", systemImage: "sparkles")
                                    .font(.headline)
                                if insight.priorities.isEmpty {
                                    LifeEmptyState(
                                        symbol: "checkmark.seal",
                                        title: "Chưa có việc cần ưu tiên",
                                        detail: "Thêm công việc hoặc xem Weekly Intelligence để sắp xếp thời gian."
                                    )
                                } else {
                                    ForEach(insight.priorities) { priority in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: priority.urgency == "overdue"
                                                  ? "exclamationmark.circle.fill" : "circle.dotted.circle")
                                                .foregroundStyle(priority.urgency == "overdue" ? Color.orange : LifeTheme.accent)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(priority.title).font(.subheadline.weight(.medium))
                                                Text(priority.reason).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                    }
                                }
                            }
                        }
                        LifePanel {
                            VStack(alignment: .leading, spacing: 11) {
                                Label("Xu hướng tập trung", systemImage: "timer")
                                    .font(.headline)
                                if insight.focus.enabled {
                                    HStack(spacing: 10) {
                                        LifeMetric(title: "7 ngày gần đây", count: insight.focus.last7DaysMinutes, symbol: "clock.fill", tint: LifeTheme.cyan)
                                        LifeMetric(title: "7 ngày trước đó", count: insight.focus.previous7DaysMinutes, symbol: "clock", tint: LifeTheme.accent)
                                    }
                                    Text("Đơn vị: phút bạn tự ghi nhận; không theo dõi thời gian sử dụng điện thoại.")
                                        .font(.caption).foregroundStyle(.secondary)
                                    if let hour = insight.focus.preferredHour {
                                        Text("Giờ thường tập trung: " + String(format: "%02d:00", hour))
                                            .font(.subheadline)
                                    }
                                } else {
                                    Text("Nhật ký tập trung đang tắt. Bạn có thể tự bật trong Weekly Intelligence.")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                        LifePanel {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Gợi ý không cần AI", systemImage: "lightbulb")
                                    .font(.headline)
                                ForEach(insight.suggestions, id: \.self) { suggestion in
                                    Label(suggestion, systemImage: "checkmark.circle")
                                        .font(.subheadline)
                                }
                            }
                        }
                    } else if loading {
                        ProgressView("Đang tổng hợp tiến độ...")
                            .frame(maxWidth: .infinity).padding(24)
                    }
                    LifePanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Hỏi AI bằng ngữ cảnh cá nhân", systemImage: "brain.head.profile")
                                .font(.headline)
                            Text("AI chỉ nhận đúng những loại dữ liệu bạn bật cho lần hỏi này. Mặc định không chia sẻ gì.")
                                .font(.caption).foregroundStyle(.secondary)
                            TextField("Ví dụ: Tôi nên ưu tiên việc gì trong tuần này?", text: $question, axis: .vertical)
                                .lineLimit(2...5)
                                .textFieldStyle(.roundedBorder)
                            Toggle("Chia sẻ tối đa 8 công việc đang mở", isOn: $shareTasks)
                                .tint(LifeTheme.accent)
                            Toggle("Chia sẻ tối đa 4 mục bộ nhớ cá nhân", isOn: $shareMemories)
                                .tint(LifeTheme.accent)
                            Toggle("Chia sẻ tối đa 3 đoạn tài liệu liên quan", isOn: $shareDocuments)
                                .tint(LifeTheme.accent)
                            Divider()
                            Toggle(isOn: $consent) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tôi đồng ý gửi dữ liệu đã chọn đến AI")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Tên công việc, bộ nhớ hoặc đoạn tài liệu được gửi đến nhà cung cấp AI cấu hình trên Gateway. Không lưu quyền đồng ý cho lần tiếp theo.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .tint(LifeTheme.accent)
                            Button {
                                Task { await ask() }
                            } label: {
                                HStack {
                                    if asking { ProgressView().tint(.white) }
                                    else { Image(systemName: "arrow.up.circle.fill") }
                                    Text("Hỏi AI theo dữ liệu được chọn")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(LifeTheme.accent)
                            .disabled(!canAsk)
                            Text("ViePN không tự thực hiện hành động. AI có thể trả lời sai; hãy kiểm tra lại thông tin.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let answer = response {
                        LifePanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Phản hồi AI", systemImage: "sparkles").font(.headline)
                                Text(answer.reply).font(.subheadline).textSelection(.enabled)
                                Divider()
                                Text("Đã dùng: \(answer.contextUsed.tasks) việc · \(answer.contextUsed.memories) bộ nhớ · \(answer.contextUsed.documents) trích đoạn")
                                    .font(.caption).foregroundStyle(.secondary)
                                if !answer.citations.isEmpty {
                                    Text("Nguồn tài liệu được dùng").font(.subheadline.bold())
                                    ForEach(answer.citations) { cite in
                                        Text("• \(cite.title) · đoạn \(cite.ordinal)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    if !errorText.isEmpty {
                        LifePanel {
                            Label(errorText, systemImage: "info.circle")
                                .font(.subheadline).foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.horizontal, LifeTheme.horizontal)
                .padding(.vertical, 18)
            }
            .refreshable { await load() }
        }
        .navigationTitle("Personal AI")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: shareTasks) { _, _ in consent = false; response = nil }
        .onChange(of: shareMemories) { _, _ in consent = false; response = nil }
        .onChange(of: shareDocuments) { _, _ in consent = false; response = nil }
        .onChange(of: question) { _, _ in consent = false }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            insights = try await api.getPersonalInsights()
            errorText = ""
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func ask() async {
        guard canAsk else { return }
        asking = true
        defer { asking = false; consent = false }
        response = nil
        errorText = ""
        do {
            response = try await api.askPersonalAI(
                question: question, consent: true,
                includeTasks: shareTasks, includeMemories: shareMemories,
                includeDocuments: shareDocuments
            )
        } catch {
            errorText = error.localizedDescription
        }
    }
}
