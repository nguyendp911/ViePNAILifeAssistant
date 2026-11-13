import SwiftUI

struct SharedInboxView: View {
    @EnvironmentObject private var api: Gateway
    @State private var drafts: [SharedDraft] = []
    @State private var selected: SharedDraft?
    @State private var editable = ""
    @State private var isSaving = false
    var body: some View {
        List {
            Section {
                Text("Nội dung chia sẻ chỉ được lưu tạm trên thiết bị. Không gửi lên Gateway trước khi bạn xác nhận.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if drafts.isEmpty {
                ContentUnavailableView("Chưa có nội dung", systemImage: "square.and.arrow.down",
                                       description: Text("Từ Safari hoặc ứng dụng khác, chọn Chia sẻ → ViePN AI Life."))
            }
            ForEach(drafts) { draft in
                Button {
                    selected = draft
                    editable = draft.text
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(draft.text).lineLimit(3).foregroundStyle(.primary)
                        Text(draft.capturedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.onDelete { offsets in
                for offset in offsets { SharedDraftStore.remove(id: drafts[offset].id) }
                reload()
            }
        }
        .navigationTitle("Nội dung đã chia sẻ")
        .toolbar { Button("Làm mới") { reload() } }
        .onAppear(perform: reload)
        .sheet(item: $selected) { draft in
            NavigationStack {
                VStack(spacing: 15) {
                    TextEditor(text: $editable).padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.3)))
                    Text("Chọn gửi để tạo yêu cầu. Bạn còn phải phê duyệt tại Actions trước khi ghi chú được tạo.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Gửi yêu cầu tạo ghi chú") {
                        Task {
                            isSaving = true
                            let successful = await api.importSharedNote(editable)
                            isSaving = false
                            if successful { SharedDraftStore.remove(id: draft.id); selected = nil; reload() }
                        }
                    }.buttonStyle(.borderedProminent).disabled(isSaving || editable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if !api.status.isEmpty { Text(api.status).font(.caption) }
                }.padding()
                .navigationTitle("Kiểm tra trước khi nhập")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Đóng") { selected = nil } } }
            }
        }
    }
    private func reload() { drafts = SharedDraftStore.read() }
}
