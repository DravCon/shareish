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
        // Only configure if we have a real Firebase plist (avoids crash with placeholder plist)
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) as? [String: Any],
           let projectId = plist["PROJECT_ID"] as? String,
           !projectId.isEmpty,
           !projectId.contains("your-firebase") {
            FirebaseApp.configure()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
