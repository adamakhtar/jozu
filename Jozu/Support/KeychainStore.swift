import Foundation
import Security

enum KeychainStore {
    private static let service = "app.jozu"

    static func get(_ account: String) -> String? {
        if let value = keychainGet(account) { return value }
        return fileGet(account)
    }

    static func set(_ account: String, _ value: String) {
        if value.isEmpty {
            keychainDelete(account)
            fileDelete(account)
            return
        }

        if keychainSet(account, value) {
            fileDelete(account)
            return
        }

        fileSet(account, value)
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    private static func keychainGet(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private static func keychainSet(_ account: String, _ value: String) -> Bool {
        let data = Data(value.utf8)
        let query = baseQuery(account)
        let update: [String: Any] = [kSecValueData as String: data]
        let updated = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updated == errSecSuccess { return true }
        guard updated == errSecItemNotFound else { return false }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    private static func keychainDelete(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }

    private static func fileURL(_ account: String) -> URL? {
        let fm = FileManager.default
        guard let root = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return root.appendingPathComponent("jozu-\(account)", isDirectory: false)
    }

    private static func fileGet(_ account: String) -> String? {
        guard let url = fileURL(account),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func fileSet(_ account: String, _ value: String) {
        guard let url = fileURL(account) else { return }
        try? Data(value.utf8).write(to: url, options: [.atomic])
    }

    private static func fileDelete(_ account: String) {
        guard let url = fileURL(account) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
