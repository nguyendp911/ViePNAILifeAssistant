import SwiftUI

struct GoogleConnectionState: Decodable {
    let configured: Bool
    let connections: ConnectionFlags
}
struct ConnectionFlags: Decodable { let gmail: Bool; let calendar: Bool }
struct GoogleAuthorization: Decodable { let authorizationURL: String }
struct GoogleDisconnectResult: Decodable { let disconnected: Bool }
struct GmailSummary: Decodable, Identifiable {
    let id: String
    let subject: String
    let from: String
    let date: String
    let snippet: String
}
struct CalendarSummary: Decodable, Identifiable {
    let id: String
    let summary: String
    let start: String
    let end: String
}

struct GoogleConnectionsView: View {
    @EnvironmentObject private var api: Gateway
    @Environment(\.openURL) private var openURL
    @State private var status: GoogleConnectionState?
    @State private var mail: [GmailSummary] = []
    @State private var events: [CalendarSummary] = []
    @State private var message = ""
    @State private var working = false
    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    LifeHeading(name: "Dịch vụ Google", detail: "Kết nối tài khoản với quyền chỉ đọc")
                    if let status {
                        if !status.configured {
                            LifePanel { Label("Gateway chưa cấu hình Google OAuth.", systemImage: "exclamationmark.triangle") }
                        }
                        service(name: "Gmail", code: "gmail", connected: status.connections.gmail, symbol: "envelope")
                        service(name: "Google Calendar", code: "calendar", connected: status.connections.calendar, symbol: "calendar")
                    } else {
                        ProgressView("Đang kiểm tra kết nối...")
                    }
                    if !mail.isEmpty {
                        Text("Email gần đây").font(.headline)
                        ForEach(mail) { item in
                            LifePanel {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.subject).font(.headline)
                                    Text(item.from).font(.caption).foregroundStyle(.secondary)
                                    Text(item.snippet).font(.subheadline).lineLimit(3)
                                }
                            }
                        }
                    }
                    if !events.isEmpty {
                        Text("Sự kiện sắp tới").font(.headline)
                        ForEach(events) { item in
                            LifePanel {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.summary).font(.headline)
                                    Text(item.start).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Text("Quyền chỉ đọc. ViePN không tự gửi email, xóa email hay thay đổi lịch. Token được bảo vệ tại Gateway.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !message.isEmpty { Text(message).font(.footnote).foregroundStyle(.secondary) }
                }.padding(LifeTheme.horizontal)
            }
        }
        .navigationTitle("Connected Services")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }
    private func service(name: String, code: String, connected: Bool, symbol: String) -> some View {
        LifePanel {
            VStack(alignment: .leading, spacing: 9) {
                Label(name, systemImage: symbol).font(.headline)
                Text(connected ? "Đã kết nối" : "Chưa kết nối").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    if connected {
                        Button("Xem dữ liệu") { Task { await list(code) } }.buttonStyle(.borderedProminent)
                        Button("Ngắt kết nối", role: .destructive) { Task { await disconnect(code) } }.buttonStyle(.bordered)
                    } else {
                        Button("Kết nối") { Task { await connect(code) } }
                            .buttonStyle(.borderedProminent).disabled(status?.configured != true || working)
                    }
                }
            }
        }
    }
    private func load() async {
        do { status = try await api.googleStatus() }
        catch { message = error.localizedDescription }
    }
    private func connect(_ code: String) async {
        working = true; defer { working = false }
        do {
            let response = try await api.googleStart(service: code)
            guard let url = URL(string: response.authorizationURL), url.scheme == "https",
                  url.host == "accounts.google.com" else { throw APIError.text("URL OAuth không hợp lệ") }
            openURL(url)
            message = "Sau khi xác nhận trên Google, quay lại đây và nhấn làm mới."
        } catch { message = error.localizedDescription }
    }
    private func disconnect(_ code: String) async {
        do { try await api.googleDisconnect(service: code); await load(); mail=[];events=[] }
        catch { message = error.localizedDescription }
    }
    private func list(_ code: String) async {
        do {
            if code == "gmail" { mail = try await api.gmailSummaries() }
            else { events = try await api.calendarEvents() }
            message = "Đã lấy dữ liệu gần đây."
        } catch { message = error.localizedDescription }
    }
}
