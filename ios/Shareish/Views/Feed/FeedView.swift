//
//  FeedView.swift
//  Shareish
//

import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedItemId: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView("Loading feed…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            Button {
                                selectedItemId = item.id
                            } label: {
                                ItemCardView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.loadFeed()
                    }
                }
            }
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    categoryMenu
                }
            }
            .onAppear {
                Task { await viewModel.loadFeed() }
            }
            .navigationDestination(item: $selectedItemId) { id in
                ItemDetailView(itemId: id)
            }
            .overlay {
                if let message = viewModel.errorMessage {
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

    private var categoryMenu: some View {
        Menu {
            Button("All") {
                viewModel.selectedCategory = nil
                Task { await viewModel.loadFeed() }
            }
            ForEach(ItemCategory.allCases, id: \.self) { category in
                Button(category.displayName) {
                    viewModel.selectedCategory = category.rawValue
                    Task { await viewModel.loadFeed() }
                }
            }
        } label: {
            Label("Category", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

