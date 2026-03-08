//
//  ImageUploadResponse.swift
//  Shareish
//

import Foundation

/// Response from POST /items/upload (image upload for listing).
struct ImageUploadResponse: Codable {
    let url: String
}
