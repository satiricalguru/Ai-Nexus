import Foundation
import Security

/// Errors that can be thrown by the keychain helper.
enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
    case unableToConvertData
}

/// Simple wrapper for storing plain-text strings in the iOS/macOS Keychain.
/// On macOS every query MUST include kSecAttrService; without it the Security
/// framework cannot scope the item and returns an access-denied error.
final class KeychainService {

    // A stable service name that scopes all items to this app.
    private static let service = "com.jatinpandey.Ai-Nexus"

    /// Save a string value.
    static func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unableToConvertData
        }

        // Delete any existing entry first (update-by-delete is safer cross-platform).
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass          as String: kSecClassGenericPassword,
            kSecAttrService    as String: service,   // ← required on macOS
            kSecAttrAccount    as String: key,
            kSecValueData      as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain Save error for \(key): OSStatus \(status). Check entitlements.")
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Load a string value. Returns nil if not found.
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: service,      // ← required on macOS
            kSecAttrAccount as String: key,
            kSecReturnData  as String: true,
            kSecMatchLimit  as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status != errSecSuccess && status != errSecItemNotFound {
            print("Keychain Load error for \(key): OSStatus \(status). Check entitlements.")
        }

        guard status == errSecSuccess,
              let data   = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }

        return string
    }

    /// Delete an item.
    static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: service,      // ← required on macOS
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Keychain Delete error for \(key): OSStatus \(status). Check entitlements.")
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
