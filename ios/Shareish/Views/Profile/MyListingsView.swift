//
//  MyListingsView.swift
//  Shareish
//

import SwiftUI

struct MyListingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var items: [Item] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    ContentUnavailableView(
                        "No listings yet",
                        systemImage: "list.bullet",
                        description: Text("Items you list will appear here.")
                    )
                } else {
                    List(items) { item in
                        NavigationLink(value: item.id) {
                            ItemCardView(item: item)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My listings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") {
                        authViewModel.signOut()
                    }
                }
            }
            .onAppear {
                Task { await loadMyListings() }
            }
            .navigationDestination(for: UUID.self) { id in
                ItemDetailView(itemId: id)
            }
            .overlay {
                if let message = errorMessage {
                    VStack {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                        Spacer()
                    }
                }
            }
        }
    }

    private func loadMyListings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await APIClient.shared.get("/items/feed")
            // Backend may not have "my items" endpoint; filter by current user when we have auth
            // For now show feed; Phase 3/4 will add auth and filter or dedicated endpoint
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }
    }
}
