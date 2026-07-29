import Foundation
import Security

enum KeychainSessionError: LocalizedError {
    case encodingFailed
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "The secure session could not be encoded."
        case let .keychain(status):
            "Keychain operation failed with status \(status)."
        }
    }
}

final class KeychainSessionStore {
    private let service = "com.cinavault.premium.ios.session"
    private let account = "active-account-session"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func save(_ session: RemoteSession) throws {
        let data: Data
        do {
            data = try encoder.encode(session)
        } catch {
            throw KeychainSessionError.encodingFailed
        }

        clear()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainSessionError.keychain(status)
        }
    }

    func load() -> RemoteSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return try? decoder.decode(RemoteSession.self, from: data)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
