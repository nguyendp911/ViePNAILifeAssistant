import SwiftUI

struct ActionCenterView: View {
    @EnvironmentObject private var api: Gateway
    private var pending: [WorkflowItem] { api.workflows.filter { $0.status == "awaiting_approval" } }
    private var standalone: [ActionItem] { api.actions.filter { $0.status == "awaiting_approval" } }
    private var scheduled: [PendingApproval] { api.approvals.filter { $0.status == "awaiting_approval" } }
    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    LifeHeading(name: "Action Center", detail: "Mọi hành động quan trọng đều do bạn kiểm soát")
                    LifePanel {
                        HStack(spacing: 14) {
                            Image(systemName: "hand.raised.circle.fill").font(.system(size: 37)).foregroundStyle(LifeTheme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(pending.count + standalone.count + scheduled.count) yêu cầu chờ duyệt")
                                    .font(.headline)
                                Text("Không tự động gửi, xóa hoặc thay đổi dữ liệu khi chưa được phép.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    NavigationLink {
                        ActionsView()
                    } label: {
                        LifeShortcutRow(title: "Tạo quy trình mới", detail: "AI lập kế hoạch và xem trước từng bước", icon: "flowchart")
                    }.buttonStyle(.plain)
                    NavigationLink {
                        SkillsAutomationView()
                    } label: {
                        LifeShortcutRow(title: "Skills & Automation", detail: "Lịch định kỳ và tác vụ chờ xác nhận", icon: "clock.arrow.circlepath")
                    }.buttonStyle(.plain)
                    Text("Cần phê duyệt").font(.title3.bold())
                    if pending.isEmpty && standalone.isEmpty && scheduled.isEmpty {
                        LifePanel { LifeEmptyState(symbol: "checkmark.shield.fill", title: "Không có yêu cầu đang chờ", detail: "Các quy trình cần xác nhận sẽ hiển thị tại đây.") }
                    }
                    ForEach(pending) { flow in
                        LifePanel {
                            VStack(alignment: .leading, spacing: 11) {
                                Label("Quy trình · Bước \(flow.currentStep + 1)/\(flow.steps.count)", systemImage: "square.stack")
                                    .font(.caption.bold()).foregroundStyle(LifeTheme.accent)
                                Text(flow.title).font(.headline)
                                if flow.currentStep < flow.steps.count {
                                    let step = flow.steps[flow.currentStep]
                                    Text(step.payload["title"]?.stringValue ?? step.payload["text"]?.stringValue ?? step.payload["content"]?.stringValue ?? "")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    approvalButtons { await api.decideWorkflow(flow, approved: true) } reject: { await api.decideWorkflow(flow, approved: false) }
                                }
                            }
                        }
                    }
                    ForEach(api.workflows.filter { $0.status == "failed" }) { flow in
                        LifePanel {
                            VStack(alignment:.leading,spacing:9) {
                                Label("Quy trình lỗi – không tự chạy lại",systemImage:"exclamationmark.triangle")
                                    .foregroundStyle(.orange).font(.caption.bold())
                                Text(flow.title).font(.headline)
                                if flow.currentStep < flow.steps.count {
                                    let step=flow.steps[flow.currentStep]
                                    Text("Bước \(flow.currentStep+1) · \(step.kind)").font(.caption)
                                    Button("Mở lại để phê duyệt") {
                                        Task {await api.retryFailedWorkflow(flow.id,stepId:step.id)}
                                    }.buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    ForEach(standalone) { action in
                        LifePanel {
                            VStack(alignment: .leading, spacing: 11) {
                                Label(action.kind, systemImage: "checkmark.shield").font(.caption.bold()).foregroundStyle(LifeTheme.accent)
                                Text(action.payload["title"]?.stringValue ?? action.payload["text"]?.stringValue ?? "")
                                    .font(.subheadline)
                                approvalButtons { await api.resolve(action, approved: true) } reject: { await api.resolve(action, approved: false) }
                            }
                        }
                    }
                    ForEach(scheduled) { item in
                        LifePanel {
                            VStack(alignment: .leading, spacing: 11) {
                                Label("Lịch tự động", systemImage: "calendar.badge.clock").font(.caption.bold()).foregroundStyle(.orange)
                                Text(item.title).font(.headline)
                                approvalButtons { await api.decideApproval(item, approved: true) } reject: { await api.decideApproval(item, approved: false) }
                            }
                        }
                    }
                }.padding(LifeTheme.horizontal)
            }.refreshable { await api.refresh() }
        }
        .navigationTitle("Actions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await api.refresh() }
    }
    private func approvalButtons(approve: @escaping () async -> Void, reject: @escaping () async -> Void) -> some View {
        HStack {
            Button("Phê duyệt") { Task { await approve() } }
                .buttonStyle(.borderedProminent).tint(LifeTheme.accent)
            Button("Từ chối", role: .destructive) { Task { await reject() } }
                .buttonStyle(.bordered)
        }
    }
}

struct LifeShortcutRow: View {
    let title: String
    let detail: String
    let icon: String
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.title3).foregroundStyle(LifeTheme.accent)
                .frame(width: 45, height: 45).background(LifeTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 5)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }.padding(15)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ProfileHubView: View {
    @EnvironmentObject private var api: Gateway
    @EnvironmentObject private var privacy: PrivacyLock
    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 56)).foregroundStyle(LifeTheme.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Tài khoản cá nhân").font(.title2.bold())
                            Text("Dữ liệu và quyền riêng tư trong tầm kiểm soát")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.bottom, 6)
                    NavigationLink { SettingsView() } label: {
                        LifeShortcutRow(title: "Security Center", detail: "Gateway, token, khóa ứng dụng, xuất dữ liệu", icon: "lock.shield")
                    }.buttonStyle(.plain)
                    NavigationLink { PersonalIntelligenceView() } label: {
                        LifeShortcutRow(title: "AI Memory & Hồ sơ", detail: "Thông tin cho phép ghi nhớ và phong cách", icon: "brain.head.profile")
                    }.buttonStyle(.plain)
                    NavigationLink { SkillsAutomationView() } label: {
                        LifeShortcutRow(title: "Skills & Automation", detail: "Quản lý lịch tự động và kỹ năng", icon: "square.grid.2x2")
                    }.buttonStyle(.plain)
                    NavigationLink { GoogleConnectionsView() } label: {
                        LifeShortcutRow(title: "Connected Services", detail: "Gmail & Google Calendar với quyền chỉ đọc", icon: "link.circle")
                    }.buttonStyle(.plain)
                    NavigationLink { LocalReminderView() } label: {
                        LifeShortcutRow(title: "Thông báo & Lịch nhắc", detail: "Nhắc việc trực tiếp trên iPhone", icon: "bell.badge")
                    }.buttonStyle(.plain)
                    LifePanel {
                        VStack(alignment: .leading, spacing: 9) {
                            Label("Bảo vệ dữ liệu", systemImage: "checkmark.shield.fill")
                                .font(.headline).foregroundStyle(LifeTheme.accent)
                            Text("API key của nhà cung cấp AI nằm trên máy chủ. Gateway token được lưu bằng iOS Keychain. Không tự động thực hiện hành động nhạy cảm.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button("Khóa ứng dụng") { privacy.unlocked = false }
                                .buttonStyle(.bordered).tint(LifeTheme.accent)
                        }
                    }
                    Text("ViePN AI Life · Engineering Preview").font(.caption).foregroundStyle(.tertiary)
                }.padding(LifeTheme.horizontal)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}
