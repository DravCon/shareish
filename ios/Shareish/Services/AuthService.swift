//
//  AuthService.swift
//  Shareish
//

import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseCore
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

final class AuthService {
    static let shared = AuthService()

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
        return try await withCheckedThrowingContinuation { continuation in
            PhoneAuthProvider.provider(auth: auth).verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
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
