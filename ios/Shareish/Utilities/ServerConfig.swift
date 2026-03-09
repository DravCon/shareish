//
//  ServerConfig.swift
//  Shareish
//

import Foundation

/// Base URL for the API. Default is your Railway backend; change the URL below if your deployment is different.
enum ServerConfig {
    private static let key = "shareish.serverBaseURL"
    /// Hardcoded Railway URL so the app connects without editing on the login screen.
    private static let `default` = "https://shareish-production.up.railway.app/api/v1"

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
