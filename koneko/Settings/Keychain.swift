import Foundation
import Security

/// Stores the AI API keys in the Keychain (never in UserDefaults or the repo), one per service.
///
/// On macOS the modern "data protection" keychain needs a signed app with a proper
/// application identifier. When that isn't available (e.g. a local debug build), writes
/// fail with errSecMissingEntitlement, so we fall back to the classic login keychain.
enum Keychain {
    private static let account = "api-key"

    private static func service(for provider: AIProvider) -> String {
        switch provider {
        case .openRouter: "koneko.openrouter"
        case .claude: "koneko.claude"
        }
    }

    private static func query(for provider: AIProvider, dataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: provider),
            kSecAttrAccount as String: account,
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    static func apiKey(for provider: AIProvider) -> String? {
        read(for: provider, dataProtection: true) ?? read(for: provider, dataProtection: false)
    }

    /// Saves (or, for an empty string, removes) the key. Returns an error message on failure.
    @discardableResult
    static func setAPIKey(_ key: String, for provider: AIProvider) -> String? {
        SecItemDelete(query(for: provider, dataProtection: true) as CFDictionary)
        SecItemDelete(query(for: provider, dataProtection: false) as CFDictionary)
        guard !key.isEmpty else { return nil }

        var status = add(key, for: provider, dataProtection: true)
        if status == errSecMissingEntitlement {
            status = add(key, for: provider, dataProtection: false)
        }
        guard status == errSecSuccess else {
            let reason = SecCopyErrorMessageString(status, nil) as String? ?? "unknown error"
            return "Couldn't save the key in the Keychain (\(status): \(reason))."
        }
        return nil
    }

    private static func read(for provider: AIProvider, dataProtection: Bool) -> String? {
        var query = query(for: provider, dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func add(_ key: String, for provider: AIProvider, dataProtection: Bool) -> OSStatus {
        var query = query(for: provider, dataProtection: dataProtection)
        query[kSecValueData as String] = Data(key.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil)
    }
}
