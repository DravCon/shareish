//
//  UploadViewModel.swift
//  Shareish
//

import Foundation
import UIKit

@MainActor
final class UploadViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var identification: AIIdentification?
    @Published var isIdentifying = false
    @Published var isCreating = false
    @Published var errorMessage: String?
    @Published var createdItem: Item?
    @Published var imageDataForUpload: Data?

    private let client = APIClient.shared
    private let maxImageDimension: CGFloat = 1024
    private let jpegQuality: CGFloat = 0.7

    func compressImage(_ image: UIImage) -> Data? {
        let size = image.size
        let ratio = min(maxImageDimension / size.width, maxImageDimension / size.height, 1)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized?.jpegData(compressionQuality: jpegQuality)
    }

    func identifyImage() async {
        guard let image = selectedImage,
              let data = compressImage(image) else {
            errorMessage = "No image selected"
            return
        }
        isIdentifying = true
        errorMessage = nil
        imageDataForUpload = data
        defer { isIdentifying = false }

        do {
            let result = try await client.uploadImage("/items/upload/identify", imageData: data)
            identification = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createItem(title: String, description: String, category: String, condition: String, tags: [String], imageUrl: String?) async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        struct CreateItemBody: Encodable {
            let title: String
            let description: String
            let category: String
            let condition: String
            let tags: [String]
            let imageUrls: [String]
        }
        let imageUrls = imageUrl.map { [$0] } ?? []
        let body = CreateItemBody(
            title: title,
            description: description,
            category: category,
            condition: condition,
            tags: tags,
            imageUrls: imageUrls
        )

        do {
            let item: Item = try await client.post("/items/", body: body)
            createdItem = item
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        selectedImage = nil
        identification = nil
        imageDataForUpload = nil
        createdItem = nil
        errorMessage = nil
    }
}
