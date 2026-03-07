//
//  ShareishApp.swift
//  Shareish
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct ShareishApp: App {
    init() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
