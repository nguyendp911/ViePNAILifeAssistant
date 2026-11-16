import SwiftUI

/// Enter Gemini / OpenAI keys and a Google OAuth client ID directly on the iPhone.
/// Everything is stored in the device Keychain; nothing is bundled in the IPA or sent to a Gateway.
struct LocalAISettingsView: View {
    @EnvironmentObject private var api: Gateway
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var geminiKey = ""
    @State private var openAIKey = ""
    @State private var geminiModel = LocalAI.model("gemini")
    @State private var openAIModel = LocalAI.model("openai")
    @State private var geminiSaved = LocalAI.hasGeminiKey
    @State private var openAISaved = LocalAI.hasOpenAIKey
    @State private var clientID = KeychainStore.load(.googleClientID)
    @State private var googleConnected = LocalGoogle.isConnected
    @State private var mail: [GmailSummary] = []
    @State private var events: [CalendarSummary] = []
    @State private var notice = ""
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                SecureField(geminiSaved ? "Đã lưu – nhập khóa mới để thay" : "Dán Gemini API key", text: $geminiKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Model", text: $geminiModel)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Link("Lấy khóa tại aistudio.google.com/apikey", destination: URL(string: "https://aistudio.google.com/apikey")!)
                    .font(.footnote)
                HStack {
                    Button("Lưu") { saveGemini() }
                        .disabled(geminiKey.trimmingCharacters(in: .whitespaces).isEmpty && !geminiSaved)
                    if geminiSaved {
                        Spacer()
                        Button("Thử") { Task { await test("gemini") } }.disabled(busy)
                        Button("Xóa khóa", role: .destructive) { removeGemini() }
                    }
                }.buttonStyle(.bordered)
            } header: { Label("Google Gemini", systemImage: "sparkles") }

            Section {
                SecureField(openAISaved ? "Đã lưu – nhập khóa mới để thay" : "Dán OpenAI API key", text: $openAIKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Model", text: $openAIModel)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Link("Lấy khóa tại platform.openai.com/api-keys", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.footnote)
                HStack {
                    Button("Lưu") { saveOpenAI() }
                        .disabled(openAIKey.trimmingCharacters(in: .whitespaces).isEmpty && !openAISaved)
                    if openAISaved {
                        Spacer()
                        Button("Thử") { Task { await test("openai") } }.disabled(busy)
                        Button("Xóa khóa", role: .destructive) { removeOpenAI() }
                    }
                }.buttonStyle(.bordered)
            } header: { Label("OpenAI", systemImage: "bubble.left.and.text.bubble.right") } footer: {
                Text("Khóa lưu trong Keychain của iPhone (chỉ máy này), không nằm trong IPA và không gửi lên máy chủ nào ngoài Google/OpenAI khi bạn nhắn tin. Nếu đã cấu hình Gateway và đăng nhập, app ưu tiên Gateway.")
            }

            Section {
                TextField("xxxx.apps.googleusercontent.com", text: $clientID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if googleConnected {
                    Label("Đã kết nối Google (chỉ đọc)", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    Button("Xem Gmail gần đây") { Task { await loadMail() } }.disabled(busy)
                    Button("Xem lịch sắp tới") { Task { await loadEvents() } }.disabled(busy)
                    Button("Ngắt kết nối Google", role: .destructive) { Task { await disconnect() } }
                } else {
                    Button("Kết nối tài khoản Google") { Task { await connect() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(clientID.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                }
                ForEach(mail) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.subject).font(.subheadline.bold())
                        Text(item.from).font(.caption).foregroundStyle(.secondary)
                        Text(item.snippet).font(.footnote).lineLimit(2)
                    }
                }
                ForEach(events) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.summary).font(.subheadline.bold())
                        Text(item.start).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: { Label("Google (Gmail & Calendar)", systemImage: "g.circle") } footer: {
                Text("Cần OAuth Client ID loại iOS: Google Cloud Console → APIs & Services → bật Gmail API và Google Calendar API → Credentials → Create OAuth client ID → iOS, Bundle ID com.viepn.ailife. Nếu app ở chế độ Testing, thêm email của bạn vào Test users. Quyền chỉ đọc; token lưu trong Keychain.")
            }

            if !notice.isEmpty { Section { Text(notice).font(.footnote) } }
        }
        .navigationTitle("Khóa AI & Google")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func announce(_ text: String) {
        notice = text
        api.localAIRevision += 1
    }

    private func saveGemini() {
        if !geminiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            guard KeychainStore.save(geminiKey, for: .gemini) else { notice = "Không lưu được khóa vào Keychain."; return }
            geminiKey = ""
        }
        LocalAI.setModel(geminiModel, kind: "gemini")
        geminiSaved = LocalAI.hasGeminiKey
        announce("Đã lưu cấu hình Gemini.")
    }

    private func saveOpenAI() {
        if !openAIKey.trimmingCharacters(in: .whitespaces).isEmpty {
            guard KeychainStore.save(openAIKey, for: .openai) else { notice = "Không lưu được khóa vào Keychain."; return }
            openAIKey = ""
        }
        LocalAI.setModel(openAIModel, kind: "openai")
        openAISaved = LocalAI.hasOpenAIKey
        announce("Đã lưu cấu hình OpenAI.")
    }

    private func removeGemini() {
        KeychainStore.save("", for: .gemini)
        geminiSaved = false
        announce("Đã xóa khóa Gemini.")
    }

    private func removeOpenAI() {
        KeychainStore.save("", for: .openai)
        openAISaved = false
        announce("Đã xóa khóa OpenAI.")
    }

    private func test(_ provider: String) async {
        busy = true; defer { busy = false }
        do {
            let reply = try await LocalAI.chat("Trả lời đúng một từ: OK", history: [], providerId: provider, model: nil)
            notice = "Kết nối thành công (\(reply.model ?? provider)): " + String(reply.reply.prefix(80))
        } catch { notice = error.localizedDescription }
    }

    private func connect() async {
        busy = true; defer { busy = false }
        do {
            let id = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
            let request = try LocalGoogle.begin(clientID: id)
            KeychainStore.save(id, for: .googleClientID)
            let callback = try await webAuth.authenticate(using: request.url, callbackURLScheme: request.scheme)
            try await LocalGoogle.finish(callback: callback, request: request, clientID: id)
            googleConnected = LocalGoogle.isConnected
            notice = "Đã kết nối Google."
        } catch { notice = "Kết nối Google không thành công: " + error.localizedDescription }
    }

    private func disconnect() async {
        await LocalGoogle.disconnect()
        googleConnected = false
        mail = []; events = []
        notice = "Đã ngắt kết nối và xóa token Google khỏi máy."
    }

    private func loadMail() async {
        busy = true; defer { busy = false }
        do { mail = try await LocalGoogle.gmail(); events = []; notice = mail.isEmpty ? "Hộp thư đến trống." : "Đã lấy email gần đây." }
        catch { notice = error.localizedDescription }
    }

    private func loadEvents() async {
        busy = true; defer { busy = false }
        do { events = try await LocalGoogle.calendar(); mail = []; notice = events.isEmpty ? "Không có sự kiện sắp tới." : "Đã lấy sự kiện sắp tới." }
        catch { notice = error.localizedDescription }
    }
}
