import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@main struct ViePNAILifeApp: App {
    @StateObject private var gateway = Gateway()
    @StateObject private var privacy = PrivacyLock()
    var body: some Scene {
        WindowGroup {
            Group {
                if privacy.unlocked {
                    ContentView().environmentObject(gateway).environmentObject(privacy)
                } else {
                    ZStack {
                        LifeBackdrop()
                        VStack(spacing: 20) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 62, weight: .light))
                                .foregroundStyle(LifeTheme.accent)
                            Text("ViePN AI Life").font(.largeTitle.bold())
                            Text("Trợ lý AI riêng tư của bạn").foregroundStyle(.secondary)
                            Button("Mở khóa bằng thiết bị") { Task { await privacy.unlock() } }
                                .buttonStyle(.borderedProminent).tint(LifeTheme.accent)
                        }.padding(24)
                    }
                    .task { await privacy.unlock() }
                }
            }
        }
    }
}

enum LifeTab: Hashable { case home, ai, actions, library, profile }

struct ContentView: View {
    @EnvironmentObject private var api: Gateway
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sync = SyncCoordinator()
    @State private var tab: LifeTab = .home
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { DashboardView(selectedTab: $tab) }
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(LifeTab.home)
            NavigationStack { ChatView() }
                .tabItem { Label("AI", systemImage: "sparkles") }.tag(LifeTab.ai)
            NavigationStack { ActionCenterView() }
                .tabItem { Label("Actions", systemImage: "checkmark.shield") }.tag(LifeTab.actions)
            NavigationStack { LibraryView() }
                .tabItem { Label("Library", systemImage: "square.stack.3d.up") }.tag(LifeTab.library)
            NavigationStack { ProfileHubView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(LifeTab.profile)
        }
        .tint(LifeTheme.accent)
        .task { await sync.refreshIfNeeded(gateway: api) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await sync.refreshIfNeeded(gateway: api) } }
        }
        .onChange(of: api.token) { _, _ in sync.reset() }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var api: Gateway
    @Binding var selectedTab: LifeTab
    @State private var taskTitle = ""
    @State private var showingSmartDay = false
    private var pendingCount: Int {
        api.actions.filter { $0.status == "awaiting_approval" }.count +
        api.workflows.filter { $0.status == "awaiting_approval" }.count +
        api.approvals.filter { $0.status == "awaiting_approval" }.count
    }
    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 21) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Xin chào 👋").font(.largeTitle.bold())
                        }
                        Spacer()
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(LifeTheme.accent)
                            .padding(12)
                            .background(.regularMaterial, in: Circle())
                    }
                    hero
                    HStack(spacing: 10) {
                        LifeMetric(title: "Công việc", count: api.tasks.filter { !$0.done }.count, symbol: "checklist", tint: LifeTheme.accent)
                        LifeMetric(title: "Bộ nhớ", count: api.memories.count, symbol: "brain", tint: LifeTheme.cyan)
                        LifeMetric(title: "Chờ duyệt", count: pendingCount, symbol: "hand.raised", tint: .orange)
                    }
                    Button {
                        showingSmartDay = true
                    } label: {
                        LifePanel {
                            HStack(spacing: 14) {
                                Image(systemName: "sun.max.fill")
                                    .font(.title2).foregroundStyle(LifeTheme.cyan)
                                    .frame(width: 44, height: 44)
                                    .background(LifeTheme.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Smart Day · Bản tin hôm nay").font(.headline)
                                    if let summary = api.dailyBriefing?.summary {
                                        Text("\(summary.dueToday) đến hạn · \(summary.overdue) quá hạn · \(summary.pendingApprovals) chờ duyệt")
                                            .font(.caption).foregroundStyle(.secondary)
                                    } else {
                                        Text("Công việc, ưu tiên và hành động cần xem")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 5)
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        DailyPlannerView()
                    } label: {
                        LifePanel {
                            HStack(spacing: 14) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.title2).foregroundStyle(LifeTheme.accent)
                                    .frame(width: 44, height: 44)
                                    .background(LifeTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("AI Daily Assistant").font(.headline)
                                    Text("Đề xuất lịch tập trung · Tránh trùng lịch")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 5)
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    LifeHeading(name: "Truy cập nhanh", detail: "Một chạm để bắt đầu công việc")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        LifeShortcut(title: "Trợ lý AI", subtitle: "Trò chuyện & giọng nói", symbol: "waveform", tint: LifeTheme.accent) { selectedTab = .ai }
                        LifeShortcut(title: "Tài liệu", subtitle: "OCR & PDF", symbol: "doc.text.viewfinder", tint: LifeTheme.cyan) { selectedTab = .library }
                        LifeShortcut(title: "Quy trình", subtitle: "Xem & phê duyệt", symbol: "flowchart", tint: .orange) { selectedTab = .actions }
                        LifeShortcut(title: "Bộ nhớ", subtitle: "Tra cứu thông tin", symbol: "brain.head.profile", tint: .mint) { selectedTab = .library }
                    }
                    LifeHeading(name: "Smart Planner", detail: "Việc quan trọng cần làm")
                    LifePanel {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                TextField("Thêm việc cần làm...", text: $taskTitle)
                                    .textInputAutocapitalization(.sentences)
                                    .submitLabel(.done)
                                    .onSubmit(addTask)
                                Button(action: addTask) {
                                    Image(systemName: "plus").font(.headline).padding(10)
                                }
                                .buttonStyle(.borderedProminent).tint(LifeTheme.accent)
                                .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            ForEach(api.tasks.prefix(6)) { item in
                                HStack(spacing: 12) {
                                    Button { Task { await api.setTaskDone(item, done: !item.done) } } label: {
                                        Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                            .font(.title3).foregroundStyle(LifeTheme.accent)
                                    }
                                    .accessibilityLabel(item.done ? "Đánh dấu chưa hoàn thành" : "Đánh dấu hoàn thành")
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title).strikethrough(item.done).font(.subheadline)
                                        if let due = item.dueAt { Text(due).font(.caption2).foregroundStyle(.secondary) }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 5)
                            }
                            if api.tasks.isEmpty {
                                LifeEmptyState(symbol: "checklist", title: "Chưa có công việc", detail: "Ghi lại việc cần làm hoặc nhờ AI lập kế hoạch.")
                            }
                        }
                    }
                    if pendingCount > 0 {
                        Button { selectedTab = .actions } label: {
                            Label("Bạn có \(pendingCount) hành động chờ xác nhận", systemImage: "hand.raised.fill")
                                .font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.bordered).tint(.orange)
                    }
                    if !api.status.isEmpty { Text(api.status).font(.caption).foregroundStyle(.secondary) }
                }
                .padding(.horizontal, LifeTheme.horizontal)
                .padding(.vertical, 18)
            }
            .refreshable { await api.refresh(); await api.loadDailyBriefing() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSmartDay) {
            NavigationStack { DailyBriefingView(selectedTab: $selectedTab) }
                .environmentObject(api)
        }
        .task {
            await api.refresh()
            await api.loadDailyBriefing()
        }
    }
    private var hero: some View {
        Button { selectedTab = .ai } label: {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 25)
                    .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.20, blue: 0.63), Color(red: 0.12, green: 0.39, blue: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(.white.opacity(0.07)).frame(width: 165, height: 165).offset(x: 235, y: -35)
                VStack(alignment: .leading, spacing: 12) {
                    Label("VIEPN INTELLIGENCE", systemImage: "sparkles")
                        .font(.caption.bold()).tracking(1.3).foregroundStyle(.white.opacity(0.85))
                    Text("Bạn muốn hoàn thành\nđiều gì hôm nay?")
                        .font(.title2.bold()).foregroundStyle(.white).multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        Text("Bắt đầu với AI").font(.subheadline.bold())
                        Image(systemName: "arrow.up.right")
                    }.foregroundStyle(.white)
                }.padding(22)
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 25))
        }.buttonStyle(.plain)
        .accessibilityLabel("Mở AI Assistant")
    }
    private func addTask() {
        let title = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        taskTitle = ""
        Task { await api.createTask(title: title) }
    }
}

struct ChatView: View {
    @EnvironmentObject private var api: Gateway
    @StateObject private var voice = VoiceInput()
    @State private var message = ""
    @State private var lines: [ChatLine] = []
    @State private var busy = false
    private let suggestions = ["Lập kế hoạch ngày hôm nay", "Tóm tắt một tài liệu", "Gợi ý việc cần ưu tiên"]
    var body: some View {
        ZStack {
            LifeBackdrop()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if lines.isEmpty {
                                VStack(spacing: 14) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 38, weight: .light))
                                        .foregroundStyle(LifeTheme.accent)
                                        .padding(26)
                                        .background(LifeTheme.accent.opacity(0.1), in: Circle())
                                    Text("Tôi có thể giúp gì?").font(.title2.bold())
                                    Text("Hỏi đáp, lập kế hoạch, viết nội dung hoặc phân tích thông tin bạn chia sẻ.")
                                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                                    ForEach(suggestions, id: \.self) { suggestion in
                                        Button { message = suggestion } label: {
                                            HStack { Image(systemName: "sparkle"); Text(suggestion); Spacer(); Image(systemName: "arrow.up.left") }
                                                .font(.subheadline).padding(13)
                                        }.buttonStyle(.bordered).tint(LifeTheme.accent)
                                    }
                                }.frame(maxWidth: .infinity).padding(.top, 65)
                            }
                            ForEach(lines) { line in
                                HStack(alignment: .bottom) {
                                    if line.user { Spacer(minLength: 48) }
                                    if !line.user { Image(systemName: "sparkles").foregroundStyle(LifeTheme.accent).padding(.bottom, 7) }
                                    Text(line.text)
                                        .textSelection(.enabled)
                                        .padding(.horizontal, 15).padding(.vertical, 12)
                                        .background(line.user ? LifeTheme.accent.opacity(0.18) : Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
                                    if !line.user { Spacer(minLength: 38) }
                                }.id(line.id)
                            }
                        }
                        .padding(17)
                    }
                    .onChange(of: lines.count) { _,_ in
                        if let id = lines.last?.id { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) } }
                    }
                }
                if busy { ProgressView("Đang suy nghĩ...").font(.caption).padding(9) }
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Nhập yêu cầu cho AI...", text: $message, axis: .vertical)
                        .lineLimit(1...5).padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17))
                    Button {
                        if voice.listening { voice.stop(); message = voice.transcript }
                        else { Task { await voice.start() } }
                    } label: {
                        Image(systemName: voice.listening ? "stop.circle.fill" : "mic.fill")
                            .font(.title3).frame(width: 44, height: 44)
                    }.buttonStyle(.bordered).tint(voice.listening ? .red : LifeTheme.accent)
                        .accessibilityLabel(voice.listening ? "Dừng nhập giọng nói" : "Nhập bằng giọng nói")
                    Button { Task { await send() } } label: {
                        Image(systemName: "arrow.up").font(.headline).frame(width: 44, height: 44)
                    }.buttonStyle(.borderedProminent).tint(LifeTheme.accent)
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(.regularMaterial)
                if !voice.errorMessage.isEmpty { Text(voice.errorMessage).font(.caption).foregroundStyle(.red).padding(.bottom, 5) }
            }
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button {
                do { try ChatHistory.clear(token: api.token, baseURL: api.baseURL); lines.removeAll() }
                catch { api.status = error.localizedDescription }
            } label: { Image(systemName: "square.and.pencil") }
                .accessibilityLabel("Tạo cuộc hội thoại mới")
        }}
        .onAppear { lines = ChatHistory.load(token: api.token, baseURL: api.baseURL) }
        .onChange(of: api.token) { _,_ in lines = ChatHistory.load(token: api.token, baseURL: api.baseURL) }
        .onChange(of: api.baseURL) { _,_ in lines = ChatHistory.load(token: api.token, baseURL: api.baseURL) }
        .onChange(of: voice.transcript) { _, text in if voice.listening { message = text } }
    }
    private func send() async {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let sessionToken = api.token
        let sessionURL = api.baseURL
        message = ""; lines.append(ChatLine(user: true, text: text)); persistChat(); busy = true
        defer { busy = false }
        do {
            let response = try await api.chat(text)
            guard sessionToken == api.token && sessionURL == api.baseURL else { return }
            lines.append(ChatLine(user: false, text: response.reply))
        } catch {
            guard sessionToken == api.token && sessionURL == api.baseURL else { return }
            lines.append(ChatLine(user: false, text: "Không thể kết nối: " + error.localizedDescription))
        }
        persistChat()
    }
    private func persistChat() {
        do { try ChatHistory.save(lines, token: api.token, baseURL: api.baseURL) } catch { api.status = "Không lưu được lịch sử: " + error.localizedDescription }
    }
}
struct ActionsView:View {
    @EnvironmentObject var api:Gateway
    @State private var value=""
    @State private var type="create_task"
    @State private var workflowTitle=""
    @State private var workflowNote=""
    @State private var workflowTask=""
    @State private var preview:PlanPreviewItem?
    @State private var aiRequest=""
    @State private var previewError=""
    var body:some View{
        Form{
            Section("Quy trình 2 bước – duyệt từng bước") {
                TextField("Tên quy trình / tiêu đề ghi chú",text:$workflowTitle)
                TextField("Nội dung ghi chú",text:$workflowNote,axis:.vertical)
                TextField("Việc cần làm tiếp theo",text:$workflowTask)
                Button("Xem trước quy trình") {
                    preview=nil;previewError=""
                    Task {
                        do {preview=try await api.previewWorkflow(title:workflowTitle,note:workflowNote,task:workflowTask)}
                        catch {previewError=error.localizedDescription}
                    }
                }.disabled(workflowTitle.isEmpty || (workflowNote.isEmpty && workflowTask.isEmpty))
                if let preview {
                    Text("Bản xem trước – không thực hiện tự động").font(.subheadline.bold())
                    ForEach(Array(preview.steps.enumerated()),id:\.offset){index,step in
                        VStack(alignment:.leading){Text("Bước \(index+1): \(step.kind)").font(.subheadline.bold())
                            Text(step.payload["title"]?.stringValue ?? step.payload["content"]?.stringValue ?? "")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("Tạo quy trình chờ duyệt") {
                        self.preview=nil
                        Task{await api.createWorkflow(from:preview)}
                    }.buttonStyle(.borderedProminent)
                }
                if !previewError.isEmpty {Text(previewError).foregroundStyle(.red).font(.footnote)}
            }
            Section("AI đề xuất kế hoạch – cần AI Gateway") {
                TextField("Ví dụ: Lập danh sách việc chuẩn bị cuộc họp",text:$aiRequest,axis:.vertical)
                Button("AI lập bản xem trước") {
                    preview=nil;previewError=""
                    Task {do {preview=try await api.previewAIWorkflow(aiRequest)}
                        catch {previewError=error.localizedDescription}}
                }.disabled(aiRequest.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                if let preview, preview.origin=="ai_generated" {
                    Text("AI đề xuất: \(preview.title)").font(.headline)
                    ForEach(Array(preview.steps.enumerated()),id:\.offset){index,step in
                        VStack(alignment:.leading,spacing:4) {
                            Text("Bước \(index+1): \(step.kind)").font(.subheadline.bold())
                            Text(step.payload["title"]?.stringValue ?? step.payload["content"]?.stringValue ?? "")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("Tạo quy trình chờ phê duyệt") {Task{await api.createWorkflow(from:preview)} }
                        .buttonStyle(.borderedProminent)
                }
                Text("AI chỉ tạo kế hoạch nháp. Mỗi bước cần bạn duyệt trước khi lưu.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Quy trình đang chờ") {
                ForEach(api.workflows.filter{$0.status=="awaiting_approval"}) {flow in
                    VStack(alignment:.leading,spacing:8) {
                        Text(flow.title).font(.headline)
                        if flow.currentStep < flow.steps.count {
                            let step=flow.steps[flow.currentStep]
                            Text("Bước \(flow.currentStep+1)/\(flow.steps.count): \(step.kind)")
                            Text(step.payload["title"]?.stringValue ?? step.payload["text"]?.stringValue ?? step.payload["content"]?.stringValue ?? "")
                                .font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Button("Duyệt bước") {Task{await api.decideWorkflow(flow,approved:true)}}.buttonStyle(.borderedProminent)
                                Button("Từ chối",role:.destructive) {Task{await api.decideWorkflow(flow,approved:false)}}.buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            Section("Tạo đề xuất hành động"){
                Picker("Loại",selection:$type){Text("Tạo việc").tag("create_task");Text("Lưu bộ nhớ").tag("save_memory")}
                TextField(type=="create_task" ? "Nội dung công việc":"Thông tin cần ghi nhớ",text:$value,axis:.vertical)
                Button("Tạo đề xuất – chưa thực thi") {let v=value;value="";Task{await api.proposeAction(kind:type,value:v)}}.disabled(value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            }
            Section("Chờ xác nhận"){
                ForEach(api.actions.filter{$0.status=="awaiting_approval"}){a in
                    VStack(alignment:.leading,spacing:10){Text(a.kind=="create_task" ? "Tạo công việc":"Lưu bộ nhớ").font(.headline)
                        Text(a.payload["title"]?.stringValue ?? a.payload["text"]?.stringValue ?? "").foregroundStyle(.secondary)
                        HStack{Button("Chấp nhận"){Task{await api.resolve(a,approved:true)}}.buttonStyle(.borderedProminent);Button("Từ chối",role:.destructive){Task{await api.resolve(a,approved:false)}}.buttonStyle(.bordered)}
                    }
                }
                if !api.actions.contains(where:{$0.status=="awaiting_approval"}){Text("Không có hành động chờ duyệt.").foregroundStyle(.secondary)}
            }
            Section("Nhật ký") {ForEach(api.actions){a in HStack{Text(a.kind).font(.caption);Spacer();Text(a.status).font(.caption).foregroundStyle(.secondary)}}}
        }.navigationTitle("Action Engine").refreshable{await api.refresh()}
    }
}
struct DocumentsView:View {
    @EnvironmentObject var api:Gateway
    @State private var selection:PhotosPickerItem?
    @State private var recognized=""
    @State private var busy=false
    @State private var importPDF=false
    @State private var exportedPDF:URL?
    @State private var documentError=""
    var body:some View{
        Form{
            Section("AI Document Studio") {
                Text("Nhận dạng chữ từ ảnh trên thiết bị bằng Apple Vision. Không tự động gửi ảnh lên máy chủ.").font(.footnote).foregroundStyle(.secondary)
                PhotosPicker(selection:$selection,matching:.images){Label("Chọn ảnh để OCR",systemImage:"photo")}
                Button {importPDF=true} label:{Label("Nhập PDF có văn bản",systemImage:"doc.richtext")}
                Button { do {exportedPDF=try DocumentTools.createPDF(title:"ViePN AI Life – Báo cáo",text:recognized)} catch {documentError=error.localizedDescription} } label:{Label("Tạo PDF báo cáo",systemImage:"doc.badge.arrow.up")}.disabled(recognized.isEmpty)
                if let url=exportedPDF {ShareLink(item:url){Label("Chia sẻ PDF",systemImage:"square.and.arrow.up")}}
                if !documentError.isEmpty {Text(documentError).font(.caption).foregroundStyle(.red)}
                if busy {ProgressView("Đang nhận dạng...")}
                TextEditor(text:$recognized).frame(minHeight:220)
                ShareLink(item:recognized){Label("Chia sẻ văn bản",systemImage:"square.and.arrow.up")}.disabled(recognized.isEmpty)
                Button("Nhờ AI tóm tắt") {Task {await summarize()}}.disabled(recognized.isEmpty)
            }
            Section("Lưu ý") {Text("V1.5 đọc PDF có lớp văn bản và xuất PDF ngoại tuyến. PDF scan cần OCR ảnh, Word chưa hỗ trợ.").font(.footnote)}
        }.navigationTitle("Tài liệu").fileImporter(isPresented:$importPDF,allowedContentTypes:[.pdf]) {result in
            switch result {
            case .success(let url):
                let access=url.startAccessingSecurityScopedResource()
                defer {if access {url.stopAccessingSecurityScopedResource()}}
                do {recognized=try DocumentTools.extractPDF(Data(contentsOf:url))}
                catch {documentError=error.localizedDescription}
            case .failure(let error):documentError=error.localizedDescription
            }
        }.onChange(of:selection){_,item in Task {guard let data=try? await item?.loadTransferable(type:Data.self) else{return};busy=true;defer{busy=false};do{recognized=try await OCR.recognize(data)}catch{recognized=error.localizedDescription}}}
    }
    private func summarize() async {
        busy=true;defer{busy=false}
        do{let response=try await api.chat("Tóm tắt ngắn gọn văn bản sau:\n"+String(recognized.prefix(4500)));recognized += "\n\n--- Tóm tắt AI ---\n"+response.reply}
        catch{api.status=error.localizedDescription}
    }
}
struct SettingsView:View {
    @EnvironmentObject var api:Gateway
    @EnvironmentObject var privacy:PrivacyLock
    @State private var memoryText=""
    @State private var loginName=""
    @State private var loginPassword=""
    @State private var registrationName=""
    @State private var exportedData:URL?
    @State private var exportError=""
    var body:some View{
        Form{
            Section("AI Gateway – cấu hình riêng"){
                TextField("https://gateway.example.com",text:$api.baseURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                SecureField("Access token",text:$api.token)
                Button("Lưu cấu hình") {api.saveSettings()}
                Button("Kiểm tra kết nối HTTPS") { Task { await api.checkConnection() } }
                Text("Chỉ kết nối HTTPS; không lưu API key AI trong IPA.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Tài khoản V3.3 – PostgreSQL") {
                TextField("Tên đăng nhập",text:$loginName).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Mật khẩu (ít nhất 12 byte)",text:$loginPassword)
                TextField("Tên hiển thị khi đăng ký",text:$registrationName)
                HStack {
                    Button("Đăng nhập") {let u=loginName,p=loginPassword; loginPassword="";Task {await api.authenticate(username:u,password:p,register:false)}}
                    Spacer()
                    Button("Đăng ký") {let u=loginName,p=loginPassword,n=registrationName;loginPassword="";Task {await api.authenticate(username:u,password:p,register:true,displayName:n)}}
                }.disabled(loginName.isEmpty || loginPassword.isEmpty)
                Button("Đăng xuất",role:.destructive) {Task {await api.logout()}}
                    .disabled(api.token.isEmpty)
                Text("Chức năng tài khoản yêu cầu Gateway đã bật PostgreSQL. Phiên hết hạn sau 7 ngày; khi hết hạn cần đăng nhập lại.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("AI Memory – có sự đồng ý"){
                TextField("Thông tin muốn AI ghi nhớ",text:$memoryText,axis:.vertical)
                Button("Tôi đồng ý lưu thông tin này") {let v=memoryText;memoryText="";Task {await api.createMemory(v)}}.disabled(memoryText.trimmingCharacters(in:.whitespaces).isEmpty)
                ForEach(api.memories){m in HStack{Text(m.text);Spacer();Button(role:.destructive){Task{await api.deleteMemory(m.id)}} label:{Image(systemName:"trash")}}}
            }
            Section("Tiện ích mở rộng") {
                NavigationLink("Cá nhân hóa và bộ nhớ") {PersonalIntelligenceView()}
                NavigationLink("Skills & Automation") {SkillsAutomationView()}
                NavigationLink("Nhắc việc trên iPhone") {LocalReminderView()}
            }
            Section("Xuất dữ liệu cá nhân") {
                Text("Tạo bản sao JSON gồm công việc, bộ nhớ, ghi chú, hồ sơ và quy trình. Không bao gồm token hoặc API key.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Chuẩn bị bản xuất") {Task {
                    do {exportedData=try await api.exportPersonalData();exportError=""}
                    catch {exportError=error.localizedDescription}
                }}
                if let exportedData {ShareLink("Lưu / chia sẻ dữ liệu",item:exportedData)}
                if !exportError.isEmpty {Text(exportError).font(.caption).foregroundStyle(.red)}
            }
            Section("Security Center"){
                Button("Khóa ứng dụng") {privacy.unlocked=false}
                Text("Token lưu trong Keychain. Hành động được thực thi sau khi người dùng xác nhận.").font(.footnote).foregroundStyle(.secondary)
            }
            if !api.status.isEmpty {Section("Trạng thái"){Text(api.status).font(.footnote)}}
        }.navigationTitle("Cài đặt").task {await api.refresh()}
    }
}
