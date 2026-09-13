import Foundation
import Security

/// Where the sign-in token lives.
///
/// `docs/security.md` in the foundation says an identifier that proves who
/// somebody is goes in the Keychain, never in `UserDefaults` — which is a plist
/// in the app's container, readable from a backup.
enum Keychain {
    static func save(_ value: String, for account: String) {
        guard let data = value.data(using: .utf8) else { return }
        // Delete first: SecItemAdd fails rather than replaces, and an update
        // path that silently does nothing is how somebody gets signed out on
        // their second launch.
        remove(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Readable only on this device, only while unlocked, and never
            // restored onto a different phone from a backup.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
