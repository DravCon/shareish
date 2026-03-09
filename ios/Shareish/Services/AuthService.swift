//
//  AuthService.swift
//  Shareish
//

import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseCore
#endif

#if canImport(UIKit)
import UIKit
#endif

enum AuthServiceError: Error, LocalizedError {
    case noVerificationID
    case noIDToken
    case signInFailed(Error)
    case firebaseNotLinked
    case firebaseNotConfigured

    var errorDescription: String? {
        switch self {
        case .noVerificationID: return "Verification ID not received"
        case .noIDToken: return "Could not get ID token"
        case .signInFailed(let e): return e.localizedDescription
        case .firebaseNotLinked: return "Firebase is not linked. Add Firebase SDK via SPM."
        case .firebaseNotConfigured: return "Firebase is not configured. Add a valid GoogleService-Info.plist from Firebase Console, or use Dev Login to test without Firebase."
        }
    }
}

#if canImport(FirebaseAuth)
private func ensureFirebaseConfigured() throws {
    guard FirebaseApp.app() != nil else {
        throw AuthServiceError.firebaseNotConfigured
    }
}
#endif

#if canImport(FirebaseAuth) && canImport(UIKit)
/// Presents Firebase reCAPTCHA / Safari UI when needed for Phone Auth.
private final class FirebaseAuthUIDelegate: NSObject, AuthUIDelegate {
    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = scene?.windows.first { $0.isKeyWindow }
        let root = base ?? window?.rootViewController
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController ?? nav)
        }
        if let tab = root as? UITabBarController {
            return topViewController(base: tab.selectedViewController ?? tab)
        }
        return root
    }

    func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
        guard let top = Self.topViewController() else {
            completion?()
            return
        }
        top.present(viewController, animated: animated, completion: completion)
    }

    func dismiss(animated: Bool, completion: (() -> Void)?) {
        guard let top = Self.topViewController() else {
            completion?()
            return
        }
        if top.presentedViewController != nil {
            top.dismiss(animated: animated, completion: completion)
        } else {
            completion?()
        }
    }
}
#endif

final class AuthService {
    static let shared = AuthService()

    #if canImport(FirebaseAuth) && canImport(UIKit)
    /// Created on first use so we don't load Firebase Auth types at app launch (avoids crash when Firebase isn't configured).
    private lazy var uiDelegate = FirebaseAuthUIDelegate()
    #endif

    #if canImport(FirebaseAuth)
    var currentFirebaseUser: FirebaseAuth.User? {
        guard FirebaseApp.app() != nil else { return nil }
        return Auth.auth().currentUser
    }
    #else
    var currentFirebaseUser: Any? { nil }
    #endif

    func verifyPhoneNumber(_ phoneNumber: String) async throws -> String {
        #if canImport(FirebaseAuth)
        try ensureFirebaseConfigured()
        let auth = Auth.auth()
        #if canImport(UIKit)
        let delegate = uiDelegate
        #else
        let delegate: AuthUIDelegate? = nil
        #endif
        return try await withCheckedThrowingContinuation { continuation in
            PhoneAuthProvider.provider(auth: auth).verifyPhoneNumber(phoneNumber, uiDelegate: delegate) { verificationID, error in
                // Ensure we resume on main so @Published updates in AuthViewModel are visible
                let resume: () -> Void = {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let verificationID = verificationID else {
                        continuation.resume(throwing: AuthServiceError.noVerificationID)
                        return
                    }
                    continuation.resume(returning: verificationID)
                }
                if Thread.isMainThread {
                    resume()
                } else {
                    DispatchQueue.main.async { resume() }
                }
            }
        }
        #else
        throw AuthServiceError.firebaseNotLinked
        #endif
    }

    func signIn(verificationID: String, verificationCode: String) async throws {
        #if canImport(FirebaseAuth)
        try ensureFirebaseConfigured()
        let auth = Auth.auth()
        let credential = PhoneAuthProvider.provider(auth: auth).credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        try await auth.signIn(with: credential)
        #else
        throw AuthServiceError.firebaseNotLinked
        #endif
    }

    func idToken() async throws -> String {
        #if canImport(FirebaseAuth)
        try ensureFirebaseConfigured()
        guard let firebaseUser = Auth.auth().currentUser else { throw AuthServiceError.noIDToken }
        return try await firebaseUser.getIDToken()
        #else
        throw AuthServiceError.firebaseNotLinked
        #endif
    }

    func signOut() throws {
        #if canImport(FirebaseAuth)
        if FirebaseApp.app() != nil {
            try? Auth.auth().signOut()
        }
        #endif
    }
}
