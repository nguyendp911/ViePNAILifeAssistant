import UIKit
import UniformTypeIdentifiers

/// Non-interactive capture stage. User must explicitly import a draft in the main app.
final class ShareViewController: UIViewController {
    private let group = "group.com.viepn.ailife"
    private let key = "shared.drafts.v1"
    private var didFinish = false
    private struct SharedDraft: Codable {
        let id: UUID
        let text: String
        let capturedAt: Date
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await collectAndFinish() }
    }
    private func collectAndFinish() async {
        var collected: [String] = []
        for item in extensionContext?.inputItems.compactMap({ $0 as? NSExtensionItem }) ?? [] {
            if let description = item.attributedContentText?.string { collected.append(description) }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let value = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                        if let text = value as? String { collected.append(text) }
                        else if let url = value as? URL, url.isFileURL,
                                let text = try? String(contentsOf: url, encoding: .utf8) { collected.append(text) }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                          let value = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                          let url = value as? URL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    collected.append(url.absoluteString)
                }
            }
        }
        let text = String(collected.joined(separator: "\n").prefix(8000)).trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, let defaults = UserDefaults(suiteName: group) {
            var items: [SharedDraft] = []
            if let data = defaults.data(forKey: key) {
                items = (try? JSONDecoder().decode([SharedDraft].self, from: data)) ?? []
            }
            items = items.filter { $0.capturedAt > Date().addingTimeInterval(-7 * 86400) }
            items.append(SharedDraft(id: UUID(), text: text, capturedAt: Date()))
            if let data = try? JSONEncoder().encode(Array(items.suffix(20))) { defaults.set(data, forKey: key) }
        }
        if !didFinish {
            didFinish = true
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
