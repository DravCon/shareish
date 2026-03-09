//
//  KeychainHelper.swift
//  Shareish
//

import Foundation
import Security

enum KeychainHelper {
    static let tokenKey = "com.shareish.authToken"

    static func saveToken(_ token: String) {
        guard !token.isEmpty else { return }
        let data = Data(token.utf8)
        let service = Bundle.main.bundleIdentifier ?? "Shareish"
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            UserDefaults.standard.set(token, forKey: "\(tokenKey).fallback")
        }
    }

    static func loadToken() -> String? {
        let service = Bundle.main.bundleIdentifier ?? "Shareish"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8), !token.isEmpty {
            return token
        }
        return UserDefaults.standard.string(forKey: "\(tokenKey).fallback")
    }

    static func deleteToken() {
        let service = Bundle.main.bundleIdentifier ?? "Shareish"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "\(tokenKey).fallback")
    }
}
