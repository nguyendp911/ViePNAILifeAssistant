import SwiftUI

private struct EditableSubtask: Identifiable {
    let id: UUID
    let savedID: String?
    var title: String
    var done: Bool
    init(savedID: String? = nil, title: String = "", done: Bool = false) {
        self.id = UUID()
        self.savedID = savedID
        self.title = title
        self.done = done
    }
}

/// V4.7: complete task editing with explicit user-supplied date, labels and subtasks.
/// All changes are validated on the authenticated Gateway and then re-synced.
struct TaskEditorView: View {
    @EnvironmentObject private var api: Gateway
    @Environment(\.dismiss) private var dismiss
    private let task: TaskItem?
    @State private var title: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var priority: String
    @State private var recurrence: String
    @State private var labelText: String
    @State private var subtasks: [EditableSubtask]
    @State private var saving = false
    @State private var errorText = ""

    init(task: TaskItem? = nil, suggestedTitle: String = "") {
        self.task = task
        _title = State(initialValue: task?.title ?? suggestedTitle)
        _hasDeadline = State(initialValue: task?.dueAt != nil)
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let simple = ISO8601DateFormatter()
        _deadline = State(initialValue: task?.dueAt.flatMap {
            format.date(from: $0) ?? simple.date(from: $0)
        } ?? Date().addingTimeInterval(3600))
        _priority = State(initialValue: task?.priority ?? "normal")
        _recurrence = State(initialValue: task?.recurrence ?? "none")
        _labelText = State(initialValue: (task?.labels ?? []).joined(separator: ", "))
        _subtasks = State(initialValue: (task?.subtasks ?? []).map {
            EditableSubtask(savedID: $0.id, title: $0.title, done: $0.done)
        })
    }

    var body: some View {
        Form {
            Section("Thông tin công việc") {
                TextField("Tên công việc", text: $title, axis: .vertical)
                    .lineLimit(1...3)
                Picker("Mức ưu tiên", selection: $priority) {
                    Text("Thấp").tag("low")
                    Text("Bình thường").tag("normal")
                    Text("Cao").tag("high")
                    Text("Khẩn cấp").tag("urgent")
                }
                Toggle("Có hạn hoàn thành", isOn: $hasDeadline)
                    .tint(LifeTheme.accent)
                if hasDeadline {
                    DatePicker("Ngày và giờ", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                }
                Picker("Lặp lại", selection: $recurrence) {
                    Text("Không lặp").tag("none")
                    Text("Hằng ngày").tag("daily")
                    Text("Hằng tuần").tag("weekly")
                    Text("Hằng tháng").tag("monthly")
                }
                Text("Khi hoàn thành việc lặp lại, hệ thống sẽ tạo công việc tiếp theo với hạn mới. Không tự tạo trước khi hoàn thành.")
                    .font(.caption).foregroundStyle(.secondary)
                if recurrence != "none" && !hasDeadline {
                    Label("Công việc lặp lại cần có ngày giờ đến hạn.", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                TextField("Nhãn, cách nhau bằng dấu phẩy", text: $labelText)
                    .textInputAutocapitalization(.sentences)
                Text("Tối đa 8 nhãn, mỗi nhãn 32 ký tự.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                ForEach($subtasks) { $step in
                    HStack(spacing: 10) {
                        Button {
                            step.done.toggle()
                        } label: {
                            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(step.done ? Color.green : LifeTheme.accent)
                        }
                        .buttonStyle(.plain)
                        TextField("Nội dung công việc con", text: $step.title)
                            .font(.subheadline)
                        Button(role: .destructive) {
                            subtasks.removeAll { $0.id == step.id }
                        } label: {
                            Image(systemName: "trash").font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    subtasks.append(EditableSubtask())
                } label: {
                    Label("Thêm công việc con", systemImage: "plus.circle")
                }
                .disabled(subtasks.count >= 20)
                Text("Hoàn thành tất cả công việc con trước khi đánh dấu hoàn thành công việc chính.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Công việc con (\(subtasks.count)/20)")
            }
            if !errorText.isEmpty {
                Section {
                    Label(errorText, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle(task == nil ? "Tạo công việc" : "Sửa công việc")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Hủy") { dismiss() }
                    .disabled(saving)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    if saving { ProgressView() }
                    else { Text("Lưu").fontWeight(.semibold) }
                }
                .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          (recurrence != "none" && !hasDeadline))
            }
        }
        .interactiveDismissDisabled(saving)
    }

    private func save() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        let labels = labelText.split(separator: ",", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard labels.count <= 8 && labels.allSatisfy({ $0.count <= 32 }) else {
            errorText = "Tối đa 8 nhãn, mỗi nhãn không quá 32 ký tự."
            return
        }
        guard subtasks.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.title.count <= 120 }) else {
            errorText = "Mỗi công việc con phải có tên từ 1 đến 120 ký tự."
            return
        }
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime]
        var payload: [String: Any] = [
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "dueAt": hasDeadline ? format.string(from: deadline) as Any : NSNull(),
            "priority": priority,
            "recurrence": recurrence,
            "labels": labels,
            "subtasks": subtasks.map { step -> [String: Any] in
                var value: [String: Any] = [
                    "title": step.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    "done": step.done
                ]
                if let savedID = step.savedID { value["id"] = savedID }
                return value
            }
        ]
        // Do not send the completion field through the editor: it has separate approval semantics.
        payload.removeValue(forKey: "done")
        do {
            if let task {
                try await api.updateManagedTask(task.id, details: payload)
            } else {
                try await api.createManagedTask(payload)
            }
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// V4.7 centralized task manager; legacy Home quick-add and planners still work.
struct TaskManagerView: View {
    @EnvironmentObject private var api: Gateway
    @State private var filter = "open"
    @State private var query = ""
    @State private var newTask = false
    @State private var editing: TaskItem?
    @State private var deleteTarget: TaskItem?
    @State private var confirmDelete = false
    @State private var errorText = ""
    @State private var busy = false

    private var filtered: [TaskItem] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        func due(_ task: TaskItem) -> Date? {
            guard let raw = task.dueAt else { return nil }
            let format = ISO8601DateFormatter()
            format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return format.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        }
        let weight: [String: Int] = ["urgent": 0, "high": 1, "normal": 2, "low": 3]
        return api.tasks.filter { task in
            let matches = query.isEmpty || task.title.localizedCaseInsensitiveContains(query) ||
                          (task.labels ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
            let at = due(task)
            let byStatus: Bool
            switch filter {
            case "today": byStatus = !task.done && at != nil && at! >= start && at! < end
            case "overdue": byStatus = !task.done && at != nil && at! < start
            case "done": byStatus = task.done
            case "all": byStatus = true
            default: byStatus = !task.done
            }
            return matches && byStatus
        }.sorted { left, right in
            if left.done != right.done { return !left.done }
            let p1 = weight[left.priority ?? "normal"] ?? 2
            let p2 = weight[right.priority ?? "normal"] ?? 2
            if p1 != p2 { return p1 < p2 }
            let d1 = due(left) ?? .distantFuture
            let d2 = due(right) ?? .distantFuture
            if d1 != d2 { return d1 < d2 }
            return left.createdAt < right.createdAt
        }
    }

    var body: some View {
        ZStack {
            LifeBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    LifeHeading(name: "Task Manager 2.0", detail: "Quản lý công việc, hạn chót, nhãn và lặp lại")
                    LifePanel {
                        VStack(spacing: 12) {
                            TextField("Tìm tên công việc hoặc nhãn", text: $query)
                                .textFieldStyle(.roundedBorder)
                            Picker("Bộ lọc", selection: $filter) {
                                Text("Đang làm").tag("open")
                                Text("Hôm nay").tag("today")
                                Text("Quá hạn").tag("overdue")
                                Text("Đã xong").tag("done")
                                Text("Tất cả").tag("all")
                            }
                            .pickerStyle(.menu)
                            HStack {
                                Text("\(filtered.count) công việc")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    newTask = true
                                } label: {
                                    Label("Tạo công việc", systemImage: "plus")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(LifeTheme.accent)
                            }
                        }
                    }
                    if !errorText.isEmpty {
                        LifePanel {
                            Label(errorText, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if filtered.isEmpty {
                        LifePanel {
                            LifeEmptyState(symbol: "list.bullet.clipboard", title: "Không tìm thấy công việc", detail: "Thử bộ lọc khác hoặc tạo công việc mới.")
                        }
                    }
                    ForEach(filtered) { item in
                        LifePanel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 12) {
                                    Button {
                                        Task { await toggle(item) }
                                    } label: {
                                        Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .foregroundStyle(item.done ? Color.green : LifeTheme.accent)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(busy)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.title)
                                            .font(.headline)
                                            .strikethrough(item.done)
                                        HStack(spacing: 8) {
                                            Text(priorityName(item.priority))
                                                .foregroundStyle(item.priority == "urgent" ? Color.orange : LifeTheme.accent)
                                            if let dueAt = item.dueAt {
                                                Text(shortDate(dueAt))
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let cycle = item.recurrence, cycle != "none" {
                                                Image(systemName: "repeat")
                                                    .accessibilityLabel("Có lịch lặp")
                                            }
                                        }
                                        .font(.caption)
                                        if let labels = item.labels, !labels.isEmpty {
                                            Text(labels.map { "#" + $0 }.joined(separator: " · "))
                                                .font(.caption).foregroundStyle(LifeTheme.cyan)
                                        }
                                        if let subtasks = item.subtasks, !subtasks.isEmpty {
                                            Text("\(subtasks.filter { $0.done }.count)/\(subtasks.count) công việc con")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                HStack(spacing: 10) {
                                    Button {
                                        editing = item
                                    } label: {
                                        Label("Chỉnh sửa", systemImage: "pencil")
                                    }
                                    .buttonStyle(.bordered)
                                    Button(role: .destructive) {
                                        deleteTarget = item
                                        confirmDelete = true
                                    } label: {
                                        Label("Xóa", systemImage: "trash")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(busy)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
                .padding(.horizontal, LifeTheme.horizontal)
                .padding(.vertical, 16)
            }
            .refreshable { await api.refresh() }
        }
        .navigationTitle("Công việc")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $newTask) {
            NavigationStack { TaskEditorView() }
                .environmentObject(api)
        }
        .sheet(item: $editing) { item in
            NavigationStack { TaskEditorView(task: item) }
                .environmentObject(api)
        }
        .confirmationDialog("Xóa công việc vĩnh viễn?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Xóa công việc", role: .destructive) {
                Task { await removeSelected() }
            }
        } message: {
            Text("Hành động này không xóa các lần lặp đã được tạo riêng. Không thể hoàn tác.")
        }
        .task { await api.refresh() }
    }

    private func toggle(_ item: TaskItem) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if !item.done && (item.subtasks ?? []).contains(where: { !$0.done }) {
            errorText = "Hãy hoàn thành các công việc con trước khi đánh dấu công việc chính đã xong."
            return
        }
        await api.setTaskDone(item, done: !item.done)
        errorText = api.status.hasPrefix("Máy chủ") ? api.status : ""
    }

    private func removeSelected() async {
        guard let item = deleteTarget, !busy else { return }
        busy = true
        defer { busy = false; deleteTarget = nil }
        do {
            try await api.deleteManagedTask(item.id)
            errorText = ""
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func priorityName(_ priority: String?) -> String {
        switch priority {
        case "urgent": return "Khẩn cấp"
        case "high": return "Ưu tiên cao"
        case "low": return "Ưu tiên thấp"
        default: return "Bình thường"
        }
    }

    private func shortDate(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else { return raw }
        return date.formatted(.dateTime.day().month().year().hour().minute())
    }
}
