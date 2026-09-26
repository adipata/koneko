import Foundation
import Security

/// Stores the OpenRouter API key in the Keychain (never in UserDefaults or the repo).
///
/// On macOS the modern "data protection" keychain needs a signed app with a proper
/// application identifier. When that isn't available (e.g. a local debug build), writes
/// fail with errSecMissingEntitlement, so we fall back to the classic login keychain.
enum Keychain {
    private static let service = "koneko.openrouter"
    private static let account = "api-key"

    private static func query(dataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    static var apiKey: String? {
        read(dataProtection: true) ?? read(dataProtection: false)
    }

    /// Saves (or, for an empty string, removes) the key. Returns an error message on failure.
    @discardableResult
    static func setAPIKey(_ key: String) -> String? {
        SecItemDelete(query(dataProtection: true) as CFDictionary)
        SecItemDelete(query(dataProtection: false) as CFDictionary)
        guard !key.isEmpty else { return nil }

        var status = add(key, dataProtection: true)
        if status == errSecMissingEntitlement {
            status = add(key, dataProtection: false)
        }
        guard status == errSecSuccess else {
            let reason = SecCopyErrorMessageString(status, nil) as String? ?? "unknown error"
            return "Couldn't save the key in the Keychain (\(status): \(reason))."
        }
        return nil
    }

    private static func read(dataProtection: Bool) -> String? {
        var query = query(dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func add(_ key: String, dataProtection: Bool) -> OSStatus {
        var query = query(dataProtection: dataProtection)
        query[kSecValueData as String] = Data(key.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil)
    }
}
