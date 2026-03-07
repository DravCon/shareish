//
//  ServerConfig.swift
//  Shareish
//

import Foundation

/// Base URL for the API (e.g. http://localhost:8000/api/v1). On a physical device, use your Mac's IP instead of localhost.
enum ServerConfig {
    private static let key = "shareish.serverBaseURL"
    private static let `default` = "http://localhost:8000/api/v1"

    static var baseURL: String {
        get {
            UserDefaults.standard.string(forKey: key) ?? Self.default
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed.isEmpty ? Self.default : trimmed, forKey: key)
        }
    }
}
