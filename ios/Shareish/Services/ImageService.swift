//
//  ImageService.swift
//  Shareish
//

import Foundation

/// Image upload to backend. Currently the identify endpoint (APIClient.uploadImage) accepts the photo
/// and returns AI metadata. If the backend returns an image URL from that call, use it when creating the item.
/// If the backend adds a separate "upload image only" endpoint that returns a URL, add a method here.
enum ImageService {
    // Reserve for future: uploadImage(data:) -> URL when backend supports it
}
