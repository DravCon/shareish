//
//  ItemCardView.swift
//  Shareish
//

import SwiftUI

struct ItemCardView: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let urlString = item.imageUrls.first,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(.quaternary)
                            .overlay { ProgressView() }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 160)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(height: 160)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            Text(item.title)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(item.category)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
                if let cond = item.condition {
                    Text(cond)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text(item.owner.displayName ?? item.owner.phoneNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
