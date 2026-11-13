import Foundation

@main
struct SharedDraftStoreSmoke {
    static func main() {
        SharedDraftStore.clear()
        assert(SharedDraftStore.read().isEmpty)
        SharedDraftStore.enqueue("  Xin chào Việt Nam  ")
        let drafts = SharedDraftStore.read()
        assert(drafts.count == 1)
        assert(drafts.first?.text == "Xin chào Việt Nam")
        if let draft = drafts.first { SharedDraftStore.remove(id: draft.id) }
        assert(SharedDraftStore.read().isEmpty)
        print("SharedDraftStore smoke test passed")
    }
}
