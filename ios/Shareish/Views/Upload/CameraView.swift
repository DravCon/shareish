//
//  CameraView.swift
//  Shareish
//

import SwiftUI

struct CameraView: View {
    @ObservedObject var viewModel: UploadViewModel
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showReview = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if viewModel.isIdentifying {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Identifying item…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else if viewModel.identification != nil {
                        Button("Review listing") {
                            showReview = true
                        }
                        .buttonStyle(.borderedProminent)
                    } else if viewModel.errorMessage == nil {
                        Button("Identify with AI") {
                            Task { await viewModel.identifyImage() }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if viewModel.errorMessage != nil {
                        Text(viewModel.errorMessage ?? "")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 12) {
                        Button("Take new photo") {
                            viewModel.reset()
                            showCamera = true
                        }
                        .buttonStyle(.bordered)
                        Button("Choose from library") {
                            viewModel.reset()
                            showImagePicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Add a photo of the item you want to give away")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take photo", systemImage: "camera.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Choose from library") {
                            showImagePicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
            .navigationTitle("List an item")
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(image: Binding(
                    get: { viewModel.selectedImage },
                    set: { viewModel.selectedImage = $0 }
                ))
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView(image: Binding(
                    get: { viewModel.selectedImage },
                    set: { viewModel.selectedImage = $0 }
                ))
            }
            .sheet(isPresented: $showReview) {
                if let identification = viewModel.identification {
                    ReviewListingView(
                        viewModel: viewModel,
                        identification: identification
                    )
                }
            }
        }
    }
}
