import Foundation
import Security
import LocalAuthentication

enum SecureToken {
    private static let account = "viepn.gateway.token"
    private static let service = "com.viepn.ailife"
    static func save(_ text: String) -> Bool {
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account]
        SecItemDelete(query as CFDictionary)
        var q=query
        q[kSecValueData as String]=Data(text.utf8)
        q[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(q as CFDictionary,nil) == errSecSuccess
    }
    static func load() -> String {
        let q:[String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary,&item)==errSecSuccess,let data=item as? Data else{return ""}
        return String(decoding:data,as:UTF8.self)
    }
}
@MainActor final class PrivacyLock: ObservableObject {
    @Published var unlocked = false
    func unlock() async {
        let context=LAContext()
        var error:NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { unlocked=false; return }
        do {unlocked = try await context.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"Mở khóa ViePN AI Life")}
        catch {unlocked=false}
    }
}
