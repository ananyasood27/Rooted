import Foundation
import Security
import CryptoKit

/// The login account. EcoGarden has no server, so there is exactly one account and it
/// lives on this device: the username plus a salted hash of the password, kept in the
/// Keychain (the system's encrypted store for secrets). The password itself is never saved.
///
/// This is enough to keep a shared phone's garden private. It is not what an app with
/// online accounts should do — that needs a server checking passwords, not the phone.
enum AccountStore {
    struct Account: Codable {
        var username: String
        var salt: Data
        var passwordHash: Data
    }

    private static let service = "ananya.EcoGarden.account"
    private static let key = "account"

    /// What identifies our one Keychain entry.
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

    /// Saves a new account, replacing any old one. Returns false if the Keychain refuses.
    @discardableResult
    static func create(username: String, password: String) -> Bool {
        // A random salt means two people with the same password get different hashes.
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let account = Account(username: username, salt: salt, passwordHash: hash(password, salt: salt))
        guard let data = try? JSONEncoder().encode(account) else { return false }

        delete()
        var item = query
        item[kSecValueData as String] = data
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    /// True if these match the saved account. Usernames ignore capitalisation; passwords don't.
    static func verify(username: String, password: String) -> Bool {
        guard let account = load() else { return false }
        return account.username.lowercased() == username.lowercased()
            && account.passwordHash == hash(password, salt: account.salt)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }

    /// Hashing is one-way, so the saved value can't be turned back into the password.
    /// Repeating it many times makes guessing passwords slow for anyone who copies the hash.
    private static func hash(_ password: String, salt: Data) -> Data {
        var digest = Data(SHA256.hash(data: salt + Data(password.utf8)))
        for _ in 0..<10_000 {
            digest = Data(SHA256.hash(data: digest + salt))
        }
        return digest
    }
}
