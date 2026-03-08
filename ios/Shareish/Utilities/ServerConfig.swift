//
//  ServerConfig.swift
//  Shareish
//

import Foundation

/// Base URL for the API. Default points to Railway.
enum ServerConfig {
    private static let key = "shareish.serverBaseURL"
    private static let `default` = "https://shareish-production.up.railway.app/api/v1"

    /// Stored value is ignored when it looks like a local/dev URL so the hardcoded production default is used.
    private static func isLocalOrDevURL(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.contains("localhost") || lower.contains("127.0.0.1")
            || lower.contains("192.168.") || lower.contains("10.") || lower.range(of: #"172\.(1[6-9]|2\d|3[01])\."#, options: .regularExpression) != nil
    }

    static var baseURL: String {
        get {
            let stored = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let s = stored, !s.isEmpty, !isLocalOrDevURL(s) {
                return s
            }
            return Self.default
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed.isEmpty ? Self.default : trimmed, forKey: key)
        }
    }

    /// Base URL without /api/v1 path (e.g. https://host.up.railway.app) for building image URLs.
    static var origin: String {
        let base = baseURL
        if base.hasSuffix("/api/v1") {
            return String(base.dropLast(8))
        }
        if base.hasSuffix("/api/v1/") {
            return String(base.dropLast(9))
        }
        return base
    }

    /// Returns a loadable URL for an image. Handles full URLs (https://...) or paths (/uploads/...).
    static func imageURL(for urlString: String?) -> URL? {
        guard let s = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if s.lowercased().hasPrefix("http://") || s.lowercased().hasPrefix("https://") {
            return URL(string: s)
        }
        let path = s.hasPrefix("/") ? s : "/" + s
        return URL(string: origin + path)
    }
}
