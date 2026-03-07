//
//  ItemDetailView.swift
//  Shareish
//

import SwiftUI

struct ItemDetailView: View {
    let itemId: UUID
    @State private var item: Item?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @StateObject private var claimViewModel = ClaimViewModel()

    var body: some View {
        Group {
            if isLoading && item == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let item = item {
                detailContent(item: item)
            } else {
                ContentUnavailableView("Item not found", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle(item?.title ?? "Item")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await loadItem() }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
    }

    @ViewBuilder
    private func detailContent(item: Item) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !item.imageUrls.isEmpty {
                    TabView {
                        ForEach(Array(item.imageUrls.enumerated()), id: \.offset) { _, urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                    case .failure:
                                        Rectangle()
                                            .fill(.quaternary)
                                            .overlay { Image(systemName: "photo") }
                                    default:
                                        ProgressView()
                                    }
                                }
                                .frame(height: 280)
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 280)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(Capsule())
                        if let cond = item.condition {
                            Text(cond)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let desc = item.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                    }

                    if !item.tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary.opacity(0.7))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Text("Listed by \(item.owner.displayName ?? item.owner.phoneNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Spacer(minLength: 80)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if item.status == "available" {
                Button("I want this") {
                    Task { await claimItem(item.id) }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
                .disabled(claimViewModel.isClaiming)
            }
        }
    }

    private func loadItem() async {
        isLoading = true
        defer { isLoading = false }
        do {
            item = try await APIClient.shared.get("/items/\(itemId.uuidString)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func claimItem(_ id: UUID) async {
        await claimViewModel.claim(itemId: id)
        if let link = claimViewModel.whatsappLink {
            WhatsAppHelper.open(link)
        }
        if claimViewModel.errorMessage != nil {
            errorMessage = claimViewModel.errorMessage
        }
    }
}

/// Simple flow layout for tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, point) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var positions: [CGPoint] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        let totalHeight = y + rowHeight
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
