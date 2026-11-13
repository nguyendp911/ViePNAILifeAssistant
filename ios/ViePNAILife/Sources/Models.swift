import Foundation
struct ChatReply: Codable { let reply: String; let configured: Bool }
struct TaskItem: Codable, Identifiable {
    let id: String
    let title: String
    let dueAt: String?
    let done: Bool
    let createdAt: String
}
struct MemoryItem: Codable, Identifiable {
    let id: String
    let text: String
    let createdAt: String
}
struct ActionItem: Codable, Identifiable {
    let id: String
    let kind: String
    let payload: [String: StringValue]
    let status: String
    let createdAt: String
}
struct StringValue: Codable {
    let stringValue: String?
    init(_ value: String?) { stringValue = value }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { stringValue = nil }
        else { stringValue = try? container.decode(String.self) }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let stringValue { try container.encode(stringValue) } else { try container.encodeNil() }
    }
}
struct Items<T: Codable>: Codable { let items: [T] }
struct ChatLine: Codable, Identifiable {
    let id: UUID
    let user: Bool
    let text: String
    init(id: UUID = UUID(), user: Bool, text: String) {
        self.id = id; self.user = user; self.text = text
    }
}

struct WorkflowStepItem: Codable, Identifiable {
    let id: String
    let kind: String
    let payload: [String: StringValue]
    let status: String
    let executedAt: String?
    let resultId: String?
}
struct WorkflowEvent: Codable {
    let at: String
    let event: String
    let stepId: String?
}
struct WorkflowItem: Codable, Identifiable {
    let id: String
    let title: String
    let createdAt: String
    let status: String
    let currentStep: Int
    let steps: [WorkflowStepItem]
    let history: [WorkflowEvent]
}
struct NoteItem: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let createdAt: String
}

struct PersonalProfile: Codable, Identifiable {let id:String;let name:String;let style:String;let createdAt:String}
struct ScheduledAutomation: Codable, Identifiable {let id:String;let title:String;let intervalMinutes:Int;let nextRunAt:String;let enabled:Bool;let skill:String;let payload:[String:String];let lastRunAt:String?;let lastResult:String?}
struct PendingApproval: Codable, Identifiable {let id:String;let automationId:String;let title:String;let result:ApprovalResult;let createdAt:String;let status:String;let resultId:String?}
struct ApprovalResult: Codable {let kind:String;let payload:[String:StringValue]}
struct SkillInfo: Codable,Identifiable {let id:String;let title:String;let requiresApproval:Bool}
struct TickResult: Codable {let created:Int}

struct PlanPreviewItem: Codable {
    let title: String
    let steps: [PlanStepDraft]
    let requiresApproval: Bool
    let executed: Bool
    let origin: String
}
struct PlanStepDraft: Codable {
    let kind: String
    let payload: [String:StringValue]
}
struct PersonalExport: Codable {
    let schemaVersion: Int
    let exportedAt: String
    let tasks: [TaskItem]
    let memories: [MemoryItem]
    let notes: [NoteItem]
    let profiles: [PersonalProfile]
    let automations: [ScheduledAutomation]
    let workflows: [WorkflowItem]
}

struct GatewayIdentity: Codable { let id: String; let displayName: String }


struct KnowledgeDoc: Codable, Identifiable {
    let id: String
    let title: String
    let createdAt: String
    let chunkCount: Int
}
struct KnowledgeCitation: Codable, Identifiable {
    let id: String
    let documentId: String
    let title: String
    let ordinal: Int
    let excerpt: String
    let score: Double
}
struct KnowledgeAnswer: Codable {
    let answer: String
    let citations: [KnowledgeCitation]
    let mode: String
    let configured: Bool
}

// V4: server-side revision state; no destructive client-side merge.
struct DeviceSyncSnapshot: Codable {
    let schemaVersion: Int
    let revision: Int
    let updatedAt: String
    let tasks: [TaskItem]
    let memories: [MemoryItem]
    let actions: [ActionItem]
    let workflows: [WorkflowItem]
    let notes: [NoteItem]
    let profiles: [PersonalProfile]
    let automations: [ScheduledAutomation]
    let documents: [KnowledgeDoc]
}
struct SemanticStatus: Codable {
    let configured: Bool
    let model: String?
    let indexed: Int
    let total: Int
}
struct SemanticIndexResult: Codable { let indexed: Int; let remaining: Int }
struct SemanticSearchResult: Codable {
    let mode: String
    let items: [KnowledgeCitation]
}
