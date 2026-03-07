//
//  User.swift
//  Shareish
//

import Foundation

struct User: Codable, Identifiable, Sendable {
    let id: UUID
    let phoneNumber: String
    var displayName: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case phoneNumber
        case displayName
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try c.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: idString) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Invalid UUID string: \(idString)")
        }
        id = uuid
        phoneNumber = try c.decode(String.self, forKey: .phoneNumber)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    init(id: UUID, phoneNumber: String, displayName: String? = nil, createdAt: Date? = nil) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.createdAt = createdAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString, forKey: .id)
        try c.encode(phoneNumber, forKey: .phoneNumber)
        try c.encodeIfPresent(displayName, forKey: .displayName)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}
