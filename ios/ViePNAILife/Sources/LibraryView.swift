import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var api: Gateway
    @State private var selectedSection = 0
    var body: some View {
        VStack(spacing: 0) {
            Picker("Thư viện", selection: $selectedSection) {
                Text("Tài liệu").tag(0)
                Text("Ghi chú").tag(1)
                Text("Bộ nhớ").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.vertical, 10)
            NavigationLink {
                KnowledgeView()
            } label: {
                Label("Kho tri thức AI – hỏi đáp có nguồn", systemImage: "books.vertical")
                    .font(.subheadline.bold()).padding(.horizontal, 16).padding(.bottom, 8)
            }
            NavigationLink {
                SharedInboxView()
            } label: {
                Label("Nội dung chia sẻ từ ứng dụng khác", systemImage: "square.and.arrow.down")
                    .font(.subheadline.bold()).padding(.horizontal, 16).padding(.bottom, 8)
            }
            Group {
                switch selectedSection {
                case 1: notes
                case 2: memories
                default: DocumentsView()
                }
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .task { await api.refresh() }
    }
    private var notes: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                LazyVStack(spacing: 12) {
                    if api.notes.isEmpty {
                        LifeEmptyState(symbol: "note.text", title: "Chưa có ghi chú", detail: "Tạo ghi chú qua Action Engine để xuất hiện tại đây.")
                    }
                    ForEach(api.notes) { item in
                        LifePanel {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(item.title).font(.headline)
                                Text(item.content).font(.subheadline).foregroundStyle(.secondary).lineLimit(8)
                                Text(item.createdAt).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }.padding(16)
            }
        }
    }
    private var memories: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                LazyVStack(spacing: 12) {
                    Label("Chỉ lưu thông tin bạn đã đồng ý", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                    if api.memories.isEmpty {
                        LifeEmptyState(symbol: "brain", title: "Chưa có bộ nhớ", detail: "Bạn kiểm soát thông tin được AI ghi nhớ trong phần Profile.")
                    }
                    ForEach(api.memories) { item in
                        LifePanel {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "brain.head.profile").foregroundStyle(LifeTheme.accent)
                                Text(item.text).font(.subheadline)
                                Spacer(minLength: 2)
                                Button(role: .destructive) { Task { await api.deleteMemory(item.id) } } label: {
                                    Image(systemName: "trash")
                                }.accessibilityLabel("Xóa bộ nhớ")
                            }
                        }
                    }
                }.padding(16)
            }
        }
    }
}
