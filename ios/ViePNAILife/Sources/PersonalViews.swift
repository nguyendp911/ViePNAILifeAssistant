import SwiftUI

struct PersonalIntelligenceView: View {
    @EnvironmentObject var api:Gateway
    @State private var name=""
    @State private var style=""
    @State private var message=""
    @State private var profileId=""
    @State private var draft=""
    @State private var thinking=false
    @State private var search=""
    var body:some View {
        Form {
            Section("Hồ sơ giao tiếp – người dùng chủ động chọn") {
                TextField("Tên hồ sơ",text:$name)
                TextField("Phong cách giao tiếp",text:$style)
                Button("Tạo hồ sơ") {Task {await api.createProfile(name:name,style:style);name="";style=""}}.disabled(name.isEmpty || style.isEmpty)
                ForEach(api.profiles){p in
                    VStack(alignment:.leading,spacing:5){Text(p.name).bold();Text(p.style).font(.footnote).foregroundStyle(.secondary)
                        Button("Dùng hồ sơ") {profileId=p.id}.buttonStyle(.bordered)
                        Button("Xóa",role:.destructive){Task {await api.deleteProfile(p.id)}}
                    }
                }
            }
            Section("AI soạn bản nháp – không tự gửi") {
                TextField("Nội dung cần trả lời",text:$message,axis:.vertical)
                Button("Soạn bản nháp") {Task {thinking=true;defer{thinking=false};do {draft=try await api.draftReply(message,profileId:profileId).reply}catch{draft=error.localizedDescription}}}.disabled(message.isEmpty||thinking)
                if !draft.isEmpty {Text(draft).textSelection(.enabled);ShareLink("Chia sẻ bản nháp",item:draft)}
            }
            Section("Tìm trong bộ nhớ đã đồng ý lưu") {
                TextField("Tìm nội dung",text:$search)
                ForEach(api.memories.filter{search.isEmpty || $0.text.localizedCaseInsensitiveContains(search)}){m in Text(m.text).font(.footnote)}
            }
        }.navigationTitle("Cá nhân hóa").task{await api.refresh()}
    }
}
struct SkillsAutomationView:View {
    @EnvironmentObject var api:Gateway
    @State private var title=""
    @State private var content=""
    @State private var interval=1440
    @State private var skill="create_task"
    var body:some View {
        Form {
            Section("Kỹ năng có sẵn") {
                ForEach(api.skills){item in
                    HStack {Text(item.title);Spacer();if item.requiresApproval {Label("Cần duyệt",systemImage:"checkmark.shield").font(.caption)}}
                }
            }
            Section("Tác vụ định kỳ – tắt mặc định") {
                TextField("Tên quy trình",text:$title)
                TextField("Nội dung",text:$content,axis:.vertical)
                Picker("Kỹ năng",selection:$skill){Text("Tạo công việc").tag("create_task");Text("Tạo ghi chú").tag("create_note")}
                Picker("Chu kỳ",selection:$interval){Text("Mỗi giờ").tag(60);Text("Mỗi ngày").tag(1440);Text("Mỗi tuần").tag(10080)}
                Button("Tạo lịch (đang tắt)"){Task{await api.createAutomation(title:title,interval:interval,skill:skill,content:content);title="";content=""}}.disabled(title.isEmpty||content.isEmpty)
                ForEach(api.automations){a in
                    VStack(alignment:.leading,spacing:4){Text(a.title).font(.headline);Text("Tiếp theo: \(a.nextRunAt)").font(.caption).foregroundStyle(.secondary)
                        Button(a.enabled ? "Tắt lịch":"Bật lịch") {Task{await api.toggleAutomation(a)}}.buttonStyle(.bordered)
                    }
                }
                Button("Kiểm tra các lịch đến hạn") {Task{await api.checkAutomations()}}
            }
            Section("Hành động định kỳ chờ duyệt") {
                ForEach(api.approvals.filter{$0.status=="awaiting_approval"}){item in
                    VStack(alignment:.leading,spacing:7) {
                        Text(item.title).bold()
                        Text(item.result.kind).font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Chấp nhận") {Task{await api.decideApproval(item,approved:true)}}.buttonStyle(.borderedProminent)
                            Button("Từ chối",role:.destructive) {Task{await api.decideApproval(item,approved:false)}}.buttonStyle(.bordered)
                        }
                    }
                }
            }
        }.navigationTitle("Skills & Automation").task{await api.refresh()}
    }
}
