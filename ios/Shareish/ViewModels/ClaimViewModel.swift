//
//  ClaimViewModel.swift
//  Shareish
//

import Foundation

@MainActor
final class ClaimViewModel: ObservableObject {
    @Published var isClaiming = false
    @Published var whatsappLink: String?
    @Published var errorMessage: String?

    private let client = APIClient.shared

    func claim(itemId: UUID) async {
        isClaiming = true
        whatsappLink = nil
        errorMessage = nil
        defer { isClaiming = false }

        do {
            let response: ClaimResponse = try await client.post("/claims/\(itemId.uuidString)", body: EmptyBody())
            whatsappLink = response.whatsappLink
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EmptyBody: Encodable {}
