//
//  FeedViewModel.swift
//  Shareish
//

import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategory: String?

    private let client = APIClient.shared

    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var query: [String: String]?
        if let cat = selectedCategory, !cat.isEmpty {
            query = ["category": cat]
        }

        do {
            items = try await client.get("/items/feed", query: query)
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }
    }
}
