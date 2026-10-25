import Foundation
import Security
import CryptoKit

// One account saved on the phone. The password is never stored, only a salted hash in the Keychain.
enum AccountStore {
    struct Account: Codable {
        var username: String
        var salt: Data
        var passwordHash: Data
    }

    private static let service = "ananya.EcoGarden.account"
    private static let key = "account"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    static func load() -> Account? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Account.self, from: data)
    }

    @discardableResult
    static func create(username: String, password: String) -> Bool {
        // random salt so the same password doesn't always give the same hash
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let account = Account(username: username, salt: salt, passwordHash: hash(password, salt: salt))
        guard let data = try? JSONEncoder().encode(account) else { return false }

        delete()
        var item = query
        item[kSecValueData as String] = data
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    // Username match ignores case.
    static func verify(username: String, password: String) -> Bool {
        guard let account = load() else { return false }
        return account.username.lowercased() == username.lowercased()
            && account.passwordHash == hash(password, salt: account.salt)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }

    // Salted SHA-256, repeated to slow down guessing.
    private static func hash(_ password: String, salt: Data) -> Data {
        var digest = Data(SHA256.hash(data: salt + Data(password.utf8)))
        for _ in 0..<10_000 {
            digest = Data(SHA256.hash(data: digest + salt))
        }
        return digest
    }
}
