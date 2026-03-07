//
//  AIIdentification.swift
//  Shareish
//

import Foundation

/// Response from POST /items/upload/identify (Claude Vision).
struct AIIdentification: Codable, Sendable {
    let title: String
    let description: String
    let category: String
    let condition: String
    let tags: [String]
    let confidence: Double
}
