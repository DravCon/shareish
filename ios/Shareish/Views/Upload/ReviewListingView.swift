//
//  ReviewListingView.swift
//  Shareish
//

import SwiftUI

struct ReviewListingView: View {
    @ObservedObject var viewModel: UploadViewModel
    let identification: AIIdentification
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: String = ""
    @State private var condition: String = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""

    var body: some View {
        NavigationStack {
            reviewForm
                .navigationTitle("Review listing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .onAppear { populateFromIdentification() }
                .overlay { creatingOverlay }
                .onChange(of: viewModel.createdItem != nil) { _, isCreated in
                    if isCreated { dismiss() }
                }
                .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                    Button("OK") { viewModel.errorMessage = nil }
                } message: {
                    if let msg = viewModel.errorMessage {
                        Text(msg)
                    }
                }
        }
    }

    private var reviewForm: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $title)
            }
            Section("Description") {
                TextEditor(text: $description)
                    .frame(minHeight: 80)
            }
            Section("Category") {
                Picker("Category", selection: $category) {
                    ForEach(ItemCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(cat.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            Section("Condition") {
                Picker("Condition", selection: $condition) {
                    ForEach(ItemCondition.allCases, id: \.self) { cond in
                        Text(cond.displayName).tag(cond.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            Section("Tags") {
                tagsSectionContent
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Looks good!") {
                Task { await submitListing() }
            }
            .disabled(viewModel.isCreating || title.isEmpty)
        }
    }

    @ViewBuilder
    private var tagsSectionContent: some View {
        HStack {
            TextField("Add tag", text: $newTag)
                .onSubmit { addTag() }
            Button("Add") { addTag() }
        }
        ForEach(tags, id: \.self) { tag in
            HStack {
                Text(tag)
                Spacer()
                Button(role: .destructive) {
                    tags.removeAll { $0 == tag }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
            }
        }
    }

    @ViewBuilder
    private var creatingOverlay: some View {
        if viewModel.isCreating {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Creating…")
                    .padding(24)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func populateFromIdentification() {
        if title.isEmpty {
            title = identification.title
            description = identification.description
            category = identification.category
            condition = identification.condition
            tags = identification.tags
        }
    }

    private func addTag() {
        let t = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !tags.contains(t) else { return }
        tags.append(t)
        newTag = ""
    }

    private func submitListing() async {
        await viewModel.createItem(
            title: title,
            description: description,
            category: category.isEmpty ? ItemCategory.other.rawValue : category,
            condition: condition.isEmpty ? ItemCondition.used.rawValue : condition,
            tags: tags,
            imageUrl: nil
        )
    }
}

