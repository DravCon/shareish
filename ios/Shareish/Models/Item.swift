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

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case category
        case condition
        case tags
        case imageUrls = "image_urls"
        case status
        case owner
        case createdAt = "created_at"
    }
}
