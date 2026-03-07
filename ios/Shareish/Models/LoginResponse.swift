//
//  LoginResponse.swift
//  Shareish
//

import Foundation

struct LoginResponse: Codable {
    let token: String
    let user: User?

    enum CodingKeys: String, CodingKey {
        case token
        case user
    }
}
