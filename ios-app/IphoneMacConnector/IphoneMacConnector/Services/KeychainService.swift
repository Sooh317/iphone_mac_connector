import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let service = "com.iphone-mac-connector.app"
    private let tokenAccount = "auth-token"

    private init() {}

    /// Save token to Keychain
    func saveToken(_ token: String) {
        guard let tokenData = token.data(using: .utf8) else {
            print("KeychainService: Failed to convert token to data")
            return
        }

        // Delete existing item first
        deleteToken()

        // Create new keychain item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("KeychainService: Token saved successfully")
        } else {
            print("KeychainService: Failed to save token with status: \(status)")
        }
    }

    /// Retrieve token from Keychain
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            if let tokenData = result as? Data,
               let token = String(data: tokenData, encoding: .utf8) {
                return token
            }
        } else if status != errSecItemNotFound {
            print("KeychainService: Failed to retrieve token with status: \(status)")
        }

        return nil
    }

    /// Delete token from Keychain
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            print("KeychainService: Token deleted successfully")
        } else if status != errSecItemNotFound {
            print("KeychainService: Failed to delete token with status: \(status)")
        }
    }

    /// Update existing token
    func updateToken(_ token: String) {
        guard let tokenData = token.data(using: .utf8) else {
            print("KeychainService: Failed to convert token to data")
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: tokenData
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecSuccess {
            print("KeychainService: Token updated successfully")
        } else if status == errSecItemNotFound {
            // Item doesn't exist, create it
            saveToken(token)
        } else {
            print("KeychainService: Failed to update token with status: \(status)")
        }
    }
}
