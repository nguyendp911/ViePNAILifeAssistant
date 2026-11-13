import Foundation
@MainActor final class Gateway: ObservableObject {
    @Published var baseURL = UserDefaults.standard.string(forKey:"viepn.base_url") ?? ""
    @Published var token = SecureToken.load()
    @Published var status = ""
    @Published var accountName = ""
    @Published var tasks:[TaskItem] = []
    @Published var memories:[MemoryItem] = []
    @Published var actions:[ActionItem] = []
    @Published var workflows:[WorkflowItem] = []
    @Published var notes:[NoteItem] = []
    @Published var profiles:[PersonalProfile] = []
    @Published var automations:[ScheduledAutomation] = []
    @Published var approvals:[PendingApproval] = []
    @Published var skills:[SkillInfo] = []
    @Published var knowledgeDocs:[KnowledgeDoc] = []
    @Published var dailyBriefing: DailyBriefing?
    @Published var dailyBriefingStatus = ""
    @Published var focusHistoryStatus: FocusHistoryStatus?
    struct AuthResponse: Decodable {
        struct Account: Decodable { let id:String; let displayName:String }
        let account:Account
        let token:String
        let expiresAt:String
    }
    func authenticate(username:String,password:String,register:Bool,displayName:String="") async {
        do {
            let raw = baseURL.trimmingCharacters(in:.whitespacesAndNewlines)
            guard let url=URL(string:raw + (register ? "/v1/auth/register":"/v1/auth/login")),url.scheme=="https",url.host != nil else {
                throw APIError.text("Cần cấu hình HTTPS Gateway trước.")
            }
            var request=URLRequest(url:url)
            request.httpMethod="POST"
            request.timeoutInterval=20
            request.setValue("application/json",forHTTPHeaderField:"Content-Type")
            request.httpBody=try JSONSerialization.data(withJSONObject:["username":username,"password":password,"displayName":displayName])
            let (data,response)=try await URLSession.shared.data(for:request)
            guard let http=response as? HTTPURLResponse,(200...299).contains(http.statusCode) else {
                throw APIError.text("Không đăng nhập được. Kiểm tra tài khoản hoặc máy chủ.")
            }
            let auth=try JSONDecoder().decode(AuthResponse.self,from:data)
            token=auth.token
            saveSettings()
            accountName=auth.account.displayName
            status="Đăng nhập thành công. Phiên hết hạn: " + auth.expiresAt
            await refresh()
        } catch { status="Lỗi tài khoản: " + error.localizedDescription }
    }
    func logout() async {
        if !token.isEmpty {let _:DeleteResult? = try? await call("/v1/auth/logout",method:"POST")}
        token=""
        saveSettings()
        status="Đã đăng xuất và xóa token khỏi Keychain."
    }
    func checkConnection() async {
        do {
            let raw = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: raw + "/health"), url.scheme == "https", url.host != nil else {
                throw APIError.text("Cần URL HTTPS hợp lệ để kiểm tra kết nối.")
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw APIError.text("Máy chủ không phản hồi hợp lệ.")
            }
            status = "Gateway phản hồi. Kiểm tra token bằng Đồng bộ dữ liệu."
        } catch { status = "Không kết nối được: " + error.localizedDescription }
    }
    func saveSettings() {
        UserDefaults.standard.set(baseURL.trimmingCharacters(in:.whitespacesAndNewlines),forKey:"viepn.base_url")
        tasks=[]; memories=[]; actions=[]; workflows=[]; notes=[]
        profiles=[]; automations=[]; approvals=[]; skills=[]; knowledgeDocs=[]; accountName=""
        dailyBriefing=nil; dailyBriefingStatus=""
        focusHistoryStatus=nil
        status=SecureToken.save(token) ? "Đã lưu cấu hình. Hãy đồng bộ tài khoản mới." : "Không thể lưu token an toàn."
    }
    private func call<T:Decodable>(_ path:String, method:String="GET", body:Any?=nil) async throws -> T {
        guard let url=URL(string:baseURL+path),url.scheme=="https",url.host != nil else {throw APIError.text("Cần cấu hình URL HTTPS hợp lệ.")}
        guard !token.isEmpty else {throw APIError.text("Chưa nhập token truy cập.")}
        var request=URLRequest(url:url)
        request.httpMethod=method
        request.timeoutInterval=35
        request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")
        if let body { request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.httpBody=try JSONSerialization.data(withJSONObject:body) }
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse,(200...299).contains(http.statusCode) else {throw APIError.text("Máy chủ từ chối yêu cầu. Kiểm tra token hoặc API.")}
        return try JSONDecoder().decode(T.self,from:data)
    }
    @Published var serverRevision: Int = 0
    func fetchSnapshot() async throws -> DeviceSyncSnapshot {
        try await call("/v1/sync")
    }
    func synchronizeSnapshot() async {
        do {
            let snapshot = try await fetchSnapshot()
            tasks=snapshot.tasks
            memories=snapshot.memories
            actions=snapshot.actions
            workflows=snapshot.workflows
            notes=snapshot.notes
            profiles=snapshot.profiles
            automations=snapshot.automations
            knowledgeDocs=snapshot.documents
            serverRevision=snapshot.revision
            status="Đã nhận bản dữ liệu #\(snapshot.revision) lúc \(snapshot.updatedAt)"
        } catch {
            status="Không thể đồng bộ: "+error.localizedDescription
        }
    }
    func semanticStatus() async throws -> SemanticStatus {
        try await call("/v1/semantic/status")
    }
    func indexSemanticDocuments() async throws -> SemanticIndexResult {
        try await call("/v1/semantic/index",method:"POST")
    }
    func semanticSearch(_ query:String) async throws -> SemanticSearchResult {
        try await call("/v1/semantic/search",method:"POST",body:["query":query])
    }
    func retryFailedWorkflow(_ workflowId:String, stepId:String) async {
        do {
            let _: WorkflowItem = try await call("/v1/workflows/"+workflowId+"/steps/"+stepId+"/retry", method:"POST")
            await refresh()
        } catch {status=error.localizedDescription}
    }
    func googleStatus() async throws -> GoogleConnectionState {
        try await call("/v1/integrations/google")
    }
    func googleStart(service: String) async throws -> GoogleAuthorization {
        try await call("/v1/integrations/google/start", method: "POST", body: ["service": service])
    }
    func googleDisconnect(service: String) async throws {
        let _: GoogleDisconnectResult = try await call("/v1/integrations/google/disconnect", method: "POST", body: ["service": service])
    }
    func gmailSummaries() async throws -> [GmailSummary] {
        let result: Items<GmailSummary> = try await call("/v1/integrations/google/gmail")
        return result.items
    }
    func calendarEvents() async throws -> [CalendarSummary] {
        let result: Items<CalendarSummary> = try await call("/v1/integrations/google/calendar")
        return result.items
    }
    func loadIdentity() async {
        do {
            let account:GatewayIdentity=try await call("/v1/me")
            accountName=account.displayName
        } catch { accountName="" }
    }
    /// V4.2: plans are preview-only. Any optional external AI/Calendar access
    /// requires explicit switches in the iPhone interface.
    func previewDailyPlan(
        startTime: String, endTime: String, focusMinutes: Int,
        breakMinutes: Int, maxTasks: Int,
        includeCalendar: Bool, useAI: Bool
    ) async throws -> DailyPlanPreview {
        let payload: [String: Any] = [
            "offsetMinutes": TimeZone.current.secondsFromGMT() / 60,
            "startTime": startTime,
            "endTime": endTime,
            "focusMinutes": focusMinutes,
            "breakMinutes": breakMinutes,
            "maxTasks": maxTasks,
            "includeCalendar": includeCalendar,
            "useAI": useAI
        ]
        return try await call("/v1/daily-plan/preview", method: "POST", body: payload)
    }

    /// Queue a note proposal for the existing Action Center. This does not
    /// create the note until the user separately approves its workflow step.
    func submitDailyPlanForApproval(_ plan: DailyPlanPreview) async -> Bool {
        guard !plan.slots.isEmpty else {
            status = "Kế hoạch trống, chưa có nội dung để lưu."
            return false
        }
        let title = "Kế hoạch \(plan.localDate)"
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let display = DateFormatter()
        display.locale = Locale(identifier: "vi_VN")
        display.timeZone = TimeZone.current
        display.dateFormat = "HH:mm"
        func shortTime(_ input: String) -> String {
            guard let date = parser.date(from: input) else { return input }
            return display.string(from: date)
        }
        var lines = ["\(title) – bản nháp chưa thực hiện", ""]
        for (index, slot) in plan.slots.enumerated() {
            lines.append("\(index + 1). \(shortTime(slot.startAt))–\(shortTime(slot.endAt)): \(slot.title)")
            lines.append("   Ưu tiên: \(slot.reason); ước tính \(slot.estimatedMinutes) phút")
        }
        if plan.unscheduledCount > 0 {
            lines.append("")
            lines.append("Chưa xếp được \(plan.unscheduledCount) công việc. Xem lại khung giờ hoặc thời lượng.")
        }
        if let advice = plan.ai?.text, !advice.isEmpty {
            lines.append("")
            lines.append("Gợi ý AI (cần kiểm tra):")
            lines.append(advice)
        }
        do {
            let content = lines.joined(separator: "\n")
            guard content.count <= 12000 else { throw APIError.text("Kế hoạch vượt giới hạn ghi chú.") }
            let step: [String: Any] = [
                "kind": "create_note",
                "payload": ["title": title, "content": content]
            ]
            let _: WorkflowItem = try await call(
                "/v1/workflows", method: "POST",
                body: ["title": title, "steps": [step]]
            )
            await refresh()
            status = "Đã gửi bản nháp đến Action Center. Hãy phê duyệt riêng để lưu ghi chú."
            return true
        } catch {
            status = error.localizedDescription
            return false
        }
    }

    // V4.3: weekly schedule is a read-only preview; never writes to Calendar.
    func previewWeeklyPlan(
        weekOffset: Int, workdays: [Int], startTime: String,
        endTime: String, focusMinutes: Int, breakMinutes: Int,
        maxTasksPerDay: Int, useHabits: Bool
    ) async throws -> WeeklyPlanPreview {
        let payload: [String: Any] = [
            "offsetMinutes": TimeZone.current.secondsFromGMT() / 60,
            "weekOffset": weekOffset, "workdays": workdays,
            "startTime": startTime, "endTime": endTime,
            "focusMinutes": focusMinutes, "breakMinutes": breakMinutes,
            "maxTasksPerDay": maxTasksPerDay, "useHabits": useHabits
        ]
        return try await call("/v1/weekly-plan/preview", method: "POST", body: payload)
    }
    func loadFocusHistory() async throws {
        focusHistoryStatus = try await call("/v1/focus-history")
    }
    func changeFocusConsent(_ enabled: Bool) async throws {
        focusHistoryStatus = try await call("/v1/focus-history/consent", method: "POST", body: ["enabled": enabled])
    }
    func recordFocusSession(_ minutes: Int) async throws {
        let hour = Calendar.current.component(.hour, from: Date())
        let payload: [String: Any] = [
            "minutes": minutes,
            "offsetMinutes": TimeZone.current.secondsFromGMT() / 60,
            "hour": hour
        ]
        focusHistoryStatus = try await call("/v1/focus-history/record", method: "POST", body: payload)
    }
    // Queue a note for separate approval; no change to Calendar or tasks.
    func sendWeeklyPlanForApproval(_ plan: WeeklyPlanPreview) async -> Bool {
        guard plan.scheduledCount > 0 else {
            status = "Chưa có công việc được xếp để lưu thành ghi chú."
            return false
        }
        let title = "Kế hoạch tuần \(plan.weekStart)"
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let display = DateFormatter()
        display.locale = Locale(identifier: "vi_VN")
        display.timeZone = TimeZone.current
        display.dateFormat = "HH:mm"
        func short(_ value: String) -> String {
            guard let date = format.date(from: value) else { return value }
            return display.string(from: date)
        }
        var lines = ["\(title) – chỉ là dự kiến, chưa thực hiện", ""]
        for day in plan.days where !day.slots.isEmpty {
            lines.append(day.date + ":")
            for slot in day.slots {
                let warning = slot.deadlineAtRisk ? " [CẢNH BÁO: QUÁ HẠN]" : ""
                lines.append("  \(short(slot.startAt))–\(short(slot.endAt)) \(slot.title)\(warning)")
            }
        }
        lines.append("")
        lines.append("Chưa xếp: \(plan.unscheduledCount) | Nguy cơ trễ hạn: \(plan.atRiskCount)")
        do {
            let content = lines.joined(separator: "\n")
            guard content.count <= 12000 else { throw APIError.text("Kế hoạch vượt giới hạn ghi chú.") }
            let step: [String: Any] = [
                "kind": "create_note",
                "payload": ["title": title, "content": content]
            ]
            let _: WorkflowItem = try await call(
                "/v1/workflows", method: "POST",
                body: ["title": title, "steps": [step]]
            )
            await refresh()
            status = "Kế hoạch đã chờ duyệt trong Action Center; chưa được lưu thành ghi chú."
            return true
        } catch {
            status = error.localizedDescription
            return false
        }
    }

    // V4.4: insights are calculated privately on the authenticated Gateway.
    func getPersonalInsights() async throws -> PersonalInsightsResponse {
        let offset = TimeZone.current.secondsFromGMT() / 60
        return try await call("/v1/insights?offsetMinutes=\(offset)")
    }
    // A fresh, explicit consent flag is required for every personal AI request.
    func askPersonalAI(
        question: String,
        consent: Bool,
        includeTasks: Bool,
        includeMemories: Bool,
        includeDocuments: Bool
    ) async throws -> PersonalAIAnswer {
        let request: [String: Any] = [
            "question": question,
            "consent": consent,
            "includeTasks": includeTasks,
            "includeMemories": includeMemories,
            "includeDocuments": includeDocuments
        ]
        return try await call("/v1/ai/personal-ask", method: "POST", body: request)
    }

    func loadDailyBriefing() async {
        do {
            let offset = TimeZone.current.secondsFromGMT() / 60
            let result: DailyBriefing = try await call("/v1/briefing?offsetMinutes=\(offset)")
            dailyBriefing = result
            dailyBriefingStatus = ""
        } catch {
            dailyBriefing = nil
            dailyBriefingStatus = error.localizedDescription
        }
    }
    func chat(_ message:String) async throws -> ChatReply { try await call("/v1/chat",method:"POST",body:["message":message]) }
    func refresh() async {
        do {
            let t:Items<TaskItem> = try await call("/v1/tasks")
            let m:Items<MemoryItem> = try await call("/v1/memories")
            let a:Items<ActionItem> = try await call("/v1/actions")
            let w:Items<WorkflowItem> = try await call("/v1/workflows")
            let n:Items<NoteItem> = try await call("/v1/notes")
            tasks=t.items;memories=m.items;actions=a.items;workflows=w.items;notes=n.items
            let p:Items<PersonalProfile> = try await call("/v1/profiles")
            let au:Items<ScheduledAutomation> = try await call("/v1/automations")
            let ap:Items<PendingApproval> = try await call("/v1/approvals")
            let sk:Items<SkillInfo> = try await call("/v1/skills")
            profiles=p.items;automations=au.items;approvals=ap.items;skills=sk.items
            let docs:Items<KnowledgeDoc> = try await call("/v1/documents")
            knowledgeDocs=docs.items
            await loadIdentity()
            status="Đã đồng bộ."
        } catch {status=error.localizedDescription}
    }
    func previewWorkflow(title:String,note:String,task:String) async throws -> PlanPreviewItem {
        let payload:[String:Any] = ["title":title,"note":note,"task":task]
        return try await call("/v1/workflows/preview",method:"POST",body:payload)
    }
    func previewAIWorkflow(_ request:String) async throws -> PlanPreviewItem {
        try await call("/v1/workflows/ai-preview",method:"POST",body:["request":request])
    }
    func createWorkflow(from preview:PlanPreviewItem) async {
        do {
            let steps:[[String:Any]]=preview.steps.map { step in
                let payload:[String:Any]=step.payload.mapValues { $0.stringValue as Any? ?? NSNull() }
                return ["kind":step.kind,"payload":payload]
            }
            let _:WorkflowItem=try await call("/v1/workflows",method:"POST",body:["title":preview.title,"steps":steps])
            await refresh()
        } catch {status=error.localizedDescription}
    }
    func setTaskDone(_ item:TaskItem,done:Bool) async {
        do {
            let _:TaskItem=try await call("/v1/tasks/"+item.id,method:"PATCH",body:["done":done])
            await refresh()
        } catch {status=error.localizedDescription}
    }
    func exportPersonalData() async throws -> URL {
        let export:PersonalExport = try await call("/v1/export")
        let encoder=JSONEncoder()
        encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        let data=try encoder.encode(export)
        let filename="ViePN-AI-Life-Export-"+String(Int(Date().timeIntervalSince1970))+".json"
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to:url,options:.atomic)
        return url
    }
    func addKnowledgeDocument(title:String,content:String) async throws {
        let _:KnowledgeDoc=try await call("/v1/documents",method:"POST",body:["title":title,"content":content])
        await refresh()
    }
    func removeKnowledgeDocument(_ id:String) async {
        do {
            let _:DeleteResult=try await call("/v1/documents/"+id,method:"DELETE")
            await refresh()
        } catch { status=error.localizedDescription }
    }
    func answerFromDocuments(question:String,useAI:Bool=false) async throws -> KnowledgeAnswer {
        try await call("/v1/knowledge/ask",method:"POST",body:["question":question,"useAI":useAI])
    }
    func createProfile(name:String,style:String) async {
        do {let _:PersonalProfile=try await call("/v1/profiles",method:"POST",body:["name":name,"style":style]);await refresh()}
        catch {status=error.localizedDescription}
    }
    func deleteProfile(_ id:String) async {
        do {let _:DeleteResult=try await call("/v1/profiles/"+id,method:"DELETE");await refresh()}
        catch {status=error.localizedDescription}
    }
    func draftReply(_ message:String,profileId:String?) async throws -> ChatReply {
        var obj:[String:Any] = ["message":message]
        if let profileId {obj["profileId"]=profileId}
        return try await call("/v1/replies/draft",method:"POST",body:obj)
    }
    func createAutomation(title:String,interval:Int,skill:String,content:String) async {
        let payload:[String:String] = skill == "create_task" ? ["title":content] : ["title":title,"content":content]
        do {let _:ScheduledAutomation=try await call("/v1/automations",method:"POST",body:["title":title,"intervalMinutes":interval,"skill":skill,"payload":payload,"enabled":false]);await refresh()}
        catch {status=error.localizedDescription}
    }
    func toggleAutomation(_ item:ScheduledAutomation) async {
        do {let _:ScheduledAutomation=try await call("/v1/automations/"+item.id+(item.enabled ? "/disable":"/enable"),method:"POST");await refresh()}
        catch {status=error.localizedDescription}
    }
    func checkAutomations() async {
        do {let _:TickResult=try await call("/v1/automations/tick",method:"POST");await refresh()}
        catch {status=error.localizedDescription}
    }
    func decideApproval(_ item:PendingApproval,approved:Bool) async {
        do {let _:PendingApproval=try await call("/v1/approvals/"+item.id+(approved ? "/approve":"/reject"),method:"POST");await refresh()}
        catch {status=error.localizedDescription}
    }
    func createWorkflow(title:String,note:String,task:String) async {
        do {
            let steps: [[String:Any]] = [
                ["kind":"create_note","payload":["title":title,"content":note]],
                ["kind":"create_task","payload":["title":task,"dueAt":NSNull()]]
            ]
            let _:WorkflowItem = try await call("/v1/workflows",method:"POST",body:["title":title,"steps":steps])
            await refresh()
        } catch {status=error.localizedDescription}
    }
    func decideWorkflow(_ workflow:WorkflowItem,approved:Bool) async {
        guard workflow.currentStep < workflow.steps.count else {return}
        let step=workflow.steps[workflow.currentStep]
        do {
            let path="/v1/workflows/"+workflow.id+"/steps/"+step.id+(approved ? "/approve":"/reject")
            let _:WorkflowItem = try await call(path,method:"POST")
            await refresh()
        } catch {status=error.localizedDescription}
    }
    /// Import requires deliberate user confirmation in the inbox, then Action Center approval.
    func importSharedNote(_ text:String) async -> Bool {
        guard text.count <= 8000, !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {
            status = "Nội dung chia sẻ không hợp lệ."; return false
        }
        do {
            let step: [String:Any] = ["kind":"create_note","payload":["title":"Nội dung chia sẻ","content":text]]
            let _: WorkflowItem = try await call("/v1/workflows", method:"POST", body:["title":"Nhập từ Share Sheet", "steps":[step]])
            await refresh()
            status = "Đã tạo yêu cầu. Vào Actions để phê duyệt tạo ghi chú."
            return true
        } catch {
            status = error.localizedDescription
            return false
        }
    }
    func createTask(title:String,dueAt:String?=nil) async {
        do {
            let _:TaskItem=try await call("/v1/tasks",method:"POST",body:["title":title,"dueAt":dueAt as Any? ?? NSNull()])
            await refresh()
        } catch {status=error.localizedDescription}
    }
    func createMemory(_ value:String) async {
        do {
            let _:MemoryItem=try await call("/v1/memories",method:"POST",body:["text":value,"consent":true])
            await refresh()
        }catch {status=error.localizedDescription}
    }
    func deleteMemory(_ id:String) async {
        do {
            let _:DeleteResult=try await call("/v1/memories/"+id,method:"DELETE")
            await refresh()
        }catch{status=error.localizedDescription}
    }
    func proposeAction(kind:String,value:String) async {
        do {
            let payload: [String:Any]=kind=="create_task" ? ["title":value,"dueAt":NSNull()] : ["text":value]
            let _:ActionItem=try await call("/v1/actions/plan",method:"POST",body:["kind":kind,"payload":payload])
            await refresh()
        }catch {status=error.localizedDescription}
    }
    func resolve(_ item:ActionItem,approved:Bool) async {
        do {
            let _:ActionItem=try await call("/v1/actions/"+item.id+(approved ? "/approve":"/reject"),method:"POST")
            await refresh()
        } catch {status=error.localizedDescription}
    }
}
struct DeleteResult:Codable {let deleted:Bool}
enum APIError:LocalizedError {case text(String);var errorDescription:String?{if case .text(let s)=self{return s};return nil}}
