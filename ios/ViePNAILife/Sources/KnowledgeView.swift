import SwiftUI
import UniformTypeIdentifiers

struct KnowledgeView: View {
    @EnvironmentObject private var api: Gateway
    @State private var title = ""
    @State private var content = ""
    @State private var question = ""
    @State private var result: KnowledgeAnswer?
    @State private var errorMessage = ""
    @State private var picker = false
    @State private var busy = false
    @State private var showImport = false
    @State private var useAI = false
    @State private var semanticStatus: SemanticStatus?
    @State private var semanticResult: SemanticSearchResult?
    @State private var showSemanticWarning = false
    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LifePanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Hỏi đáp tài liệu", systemImage: "books.vertical.fill").font(.headline)
                            Text("Dữ liệu chỉ được tải lên khi bạn bấm Lưu tài liệu. Trích dẫn nguồn theo từng đoạn.")
                                .font(.footnote).foregroundStyle(.secondary)
                            TextField("Câu hỏi về tài liệu", text: $question, axis: .vertical).lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)
                            Toggle("Nhờ AI tổng hợp dựa trên nguồn", isOn: $useAI)
                                .font(.subheadline)
                            Button {
                                Task {
                                    busy = true
                                    defer { busy = false }
                                    do { result = try await api.answerFromDocuments(question: question, useAI: useAI) }
                                    catch { errorMessage = error.localizedDescription }
                                }
                            } label: { Label("Tìm câu trả lời",systemImage:"magnifyingglass") }
                                .disabled(busy || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .buttonStyle(.borderedProminent)
                            if let result {
                                Text(result.answer).font(.body).textSelection(.enabled)
                                Text(result.mode == "ai-grounded" ? "Bản tổng hợp AI – cần kiểm tra trích dẫn" : "Các trích đoạn trích xuất trực tiếp")
                                    .font(.caption).foregroundStyle(.secondary)
                                ForEach(result.citations.indices, id: \.self) { index in
                                    let item = result.citations[index]
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("[\(index + 1)] \(item.title) · Đoạn \(item.ordinal)").font(.subheadline.bold())
                                        Text(item.excerpt).font(.caption).textSelection(.enabled)
                                    }.padding(10).frame(maxWidth: .infinity,alignment: .leading)
                                        .background(.thinMaterial,in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    LifePanel {
                        VStack(alignment:.leading,spacing:10) {
                            Label("Tìm kiếm theo ngữ nghĩa",systemImage:"brain.head.profile").font(.headline)
                            Text("Chỉ số hóa khi bạn bấm nút bên dưới. Nội dung tài liệu có thể được chuyển đến nhà cung cấp embeddings do Gateway cấu hình.")
                                .font(.caption).foregroundStyle(.secondary)
                            if let semanticStatus {
                                Text(semanticStatus.configured ? "Đã cấu hình: \(semanticStatus.indexed)/\(semanticStatus.total) đoạn" : "Chưa cấu hình embeddings; dùng tìm kiếm từ khóa")
                                    .font(.caption)
                            }
                            HStack {
                                Button("Kiểm tra") {
                                    Task {do {semanticStatus=try await api.semanticStatus()} catch {errorMessage=error.localizedDescription}}
                                }.buttonStyle(.bordered)
                                Button("Lập chỉ mục") {showSemanticWarning=true}
                                    .disabled(busy || semanticStatus?.configured != true)
                                    .buttonStyle(.borderedProminent)
                            }
                            Button("Tìm ngữ nghĩa câu hỏi") {
                                Task {
                                    busy=true; defer {busy=false}
                                    do {semanticResult=try await api.semanticSearch(question)}
                                    catch {errorMessage=error.localizedDescription}
                                }
                            }.disabled(busy || question.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                            if let semanticResult {
                                Text(semanticResult.mode == "hybrid-vector" ? "Kết quả kết hợp vector và từ khóa" : "Chế độ từ khóa")
                                    .font(.caption).foregroundStyle(.secondary)
                                ForEach(semanticResult.items) { item in
                                    VStack(alignment:.leading,spacing:3) {
                                        Text(item.title+" · Đoạn \(item.ordinal)").font(.subheadline.bold())
                                        Text(item.excerpt).font(.caption).textSelection(.enabled)
                                    }.padding(8).background(.thinMaterial,in:RoundedRectangle(cornerRadius:8))
                                }
                            }
                        }
                    }
                    LifePanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Thêm tài liệu").font(.headline)
                            Button { picker=true } label: { Label("Chọn PDF hoặc TXT",systemImage:"doc.badge.plus") }
                                .buttonStyle(.bordered)
                            TextField("Tên tài liệu",text:$title).textFieldStyle(.roundedBorder)
                            TextEditor(text:$content).frame(minHeight: 130)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.25)))
                            Text("Tối đa 120.000 ký tự. PDF cần có lớp văn bản; nội dung OCR có thể dán vào đây.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button {
                                Task {
                                    busy = true
                                    defer { busy = false }
                                    do {
                                        try await api.addKnowledgeDocument(title:title, content:content)
                                        title="";content="";errorMessage="Đã lưu tài liệu."
                                    } catch {errorMessage=error.localizedDescription}
                                }
                            } label: { Label("Lưu tài liệu lên tài khoản",systemImage:"square.and.arrow.up") }
                                .disabled(busy || title.isEmpty || content.isEmpty)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    Text("Tài liệu đã lưu (\(api.knowledgeDocs.count))").font(.headline)
                    ForEach(api.knowledgeDocs) { doc in
                        LifePanel {
                            HStack {
                                VStack(alignment:.leading,spacing:4) {
                                    Text(doc.title).font(.subheadline.bold())
                                    Text("\(doc.chunkCount) đoạn · \(doc.createdAt)").font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role:.destructive) { Task { await api.removeKnowledgeDocument(doc.id) } } label: {
                                    Image(systemName:"trash")
                                }.accessibilityLabel("Xóa tài liệu \(doc.title)")
                            }
                        }
                    }
                    if !errorMessage.isEmpty { Text(errorMessage).font(.footnote).foregroundStyle(.secondary) }
                }.padding(16)
            }
        }
        .navigationTitle("Tài liệu AI")
        .alert("Cho phép tạo embeddings?",isPresented:$showSemanticWarning) {
            Button("Hủy",role:.cancel) {}
            Button("Đồng ý") {
                Task {
                    busy=true; defer {busy=false}
                    do {
                        let indexed=try await api.indexSemanticDocuments()
                        errorMessage="Đã chỉ mục \(indexed.indexed) đoạn; còn \(indexed.remaining)."
                        semanticStatus=try await api.semanticStatus()
                    } catch {errorMessage=error.localizedDescription}
                }
            }
        } message: {
            Text("Nội dung tài liệu đã lưu sẽ được gửi tới nhà cung cấp mô hình embeddings do máy chủ cấu hình. Chỉ tiếp tục nếu bạn đồng ý.")
        }
        .fileImporter(isPresented:$picker, allowedContentTypes:[.pdf,.plainText]) { selection in
            do {
                let file=try selection.get()
                let hasAccess=file.startAccessingSecurityScopedResource()
                defer {if hasAccess {file.stopAccessingSecurityScopedResource()}}
                let data=try Data(contentsOf:file)
                let extracted:String
                if file.pathExtension.lowercased()=="pdf" {extracted=try DocumentTools.extractPDF(data)}
                else {guard let text=String(data:data,encoding:.utf8) else {throw APIError.text("File không phải UTF-8")};extracted=text}
                guard extracted.count<=120000 else {throw APIError.text("Tài liệu quá dài (120.000 ký tự).")}
                title=file.deletingPathExtension().lastPathComponent
                content=extracted
                errorMessage="Đã đọc tài liệu trên thiết bị. Bấm Lưu để tải lên tài khoản."
            } catch {errorMessage=error.localizedDescription}
        }
    }
}
