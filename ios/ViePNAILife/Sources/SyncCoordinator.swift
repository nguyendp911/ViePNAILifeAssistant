import Foundation
import SwiftUI

/// Foreground sync with simple throttling. iOS cannot guarantee exact background timing.
@MainActor
final class SyncCoordinator: ObservableObject {
    @Published private(set) var lastSync: Date?
    @Published private(set) var syncing = false
    @Published private(set) var lastError = ""
    private var signature = ""
    func refreshIfNeeded(gateway: Gateway, force: Bool = false) async {
        let newSignature = gateway.baseURL + "|" + gateway.token
        guard !gateway.token.isEmpty, !gateway.baseURL.isEmpty else { return }
        if !force, signature == newSignature, let lastSync, Date().timeIntervalSince(lastSync) < 60 { return }
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        signature = newSignature
        await gateway.synchronizeSnapshot()
        if gateway.status.hasPrefix("Đã nhận bản dữ liệu") { lastSync = Date(); lastError = "" }
        else { lastError = gateway.status }
    }
    func reset() { lastSync = nil; signature = ""; lastError = "" }
}
