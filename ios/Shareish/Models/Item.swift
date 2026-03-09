//
//  Item.swift
//  Shareish
//

import Foundation

enum ItemCategory: String, Codable, CaseIterable, Sendable {
    case electronics = "Electronics"
    case furniture = "Furniture"
    case kids = "Kids"
    case clothing = "Clothing"
    case books = "Books"
    case outdoor = "Outdoor"
    case other = "Other"

    var displayName: String { rawValue }
}

enum ItemCondition: String, Codable, CaseIterable, Sendable {
    case likeNew = "Like New"
    case good = "Good"
    case fair = "Fair"
    case used = "Used"
    case other = "Other"

    var displayName: String { rawValue }
}

enum ItemStatus: String, Codable, Sendable {
    case available = "available"
    case taken = "taken"
    case reserved = "reserved"
}

struct Item: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String?
    let category: String
    let condition: String?
    let tags: [String]
    let imageUrls: [String]
    let status: String
    let owner: User
    let createdAt: Date
    /// When set, the server inlined the first image (avoids a separate request that may 404).
    let firstImageBase64: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case category
        case condition
        case tags
        case imageUrls
        case status
        case owner
        case createdAt
        case firstImageBase64
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try c.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: idString) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Invalid UUID: \(idString)")
        }
        id = uuid
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        category = try c.decode(String.self, forKey: .category)
        condition = try c.decodeIfPresent(String.self, forKey: .condition)
        // Backend sends array of strings; be lenient if missing or wrong type
        tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        imageUrls = (try? c.decodeIfPresent([String].self, forKey: .imageUrls)) ?? []
        firstImageBase64 = try? c.decodeIfPresent(String.self, forKey: .firstImageBase64)
        status = try c.decode(String.self, forKey: .status)
        owner = try c.decode(User.self, forKey: .owner)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(condition, forKey: .condition)
        try c.encode(tags, forKey: .tags)
        try c.encode(imageUrls, forKey: .imageUrls)
        try c.encodeIfPresent(firstImageBase64, forKey: .firstImageBase64)
        try c.encode(status, forKey: .status)
        try c.encode(owner, forKey: .owner)
        try c.encode(createdAt, forKey: .createdAt)
    }
}
