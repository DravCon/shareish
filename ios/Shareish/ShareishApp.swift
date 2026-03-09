//
//  ShareishApp.swift
//  Shareish
//

import SwiftUI

@main
struct ShareishApp: App {
    var body: some Scene {
        WindowGroup {
            // Defer ContentView until after first frame so Firebase/linked code isn't
            // triggered during initial layout (avoids launch crashes when plist is placeholder).
            AppRootView()
        }
    }
}

/// Shows ContentView only after the first frame. Keeps launch path minimal.
private struct AppRootView: View {
    @State private var ready = false

    var body: some View {
        Group {
            if ready {
                ContentView()
            } else {
                Color.clear
            }
        }
        .onAppear {
            // Dispatch to next run loop so window is fully up before creating ContentView/AuthViewModel
            DispatchQueue.main.async {
                ready = true
            }
        }
    }
}
