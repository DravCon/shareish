//
//  ContentView.swift
//  Shareish
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var uploadViewModel = UploadViewModel()

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                mainTabs
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
        .onAppear {
            Task { await authViewModel.loadStoredAuth() }
        }
        .onChange(of: authViewModel.isAuthenticated) { _, _ in }
    }

    private var mainTabs: some View {
        TabView {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "square.grid.2x2")
                }

            CameraView(viewModel: uploadViewModel)
                .tabItem {
                    Label("Give away", systemImage: "camera.fill")
                }

            MyListingsView(authViewModel: authViewModel)
                .tabItem {
                    Label("My listings", systemImage: "list.bullet")
                }
        }
    }
}
