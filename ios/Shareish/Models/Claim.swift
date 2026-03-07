//
//  Claim.swift
//  Shareish
//

import Foundation

/// Response from POST /claims/{item_id}
struct ClaimResponse: Codable, Sendable {
    let whatsappLink: String
    let claimStatus: String

    enum CodingKeys: String, CodingKey {
        case whatsappLink = "whatsapp_link"
        case claimStatus = "claim_status"
    }
}

/// Claim list item (e.g. for GET /claims/my-items/{id}/claims)
struct Claim: Codable, Identifiable, Sendable {
    let id: UUID
    let itemId: UUID
    let claimantId: UUID?
    let status: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case claimantId = "claimant_id"
        case status
        case createdAt = "created_at"
    }
}
