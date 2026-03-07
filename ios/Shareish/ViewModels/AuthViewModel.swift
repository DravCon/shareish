//
//  AuthViewModel.swift
//  Shareish
//

import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var phoneNumber: String = "+91"
    @Published var verificationID: String?
    @Published var verificationCode: String = ""
    @Published var isSendingOTP = false
    @Published var isVerifying = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    @Published var isDevLoggingIn = false

    private let authService = AuthService.shared
    private let client = APIClient.shared

    var isOTPSent: Bool { verificationID != nil }

    /// Log in without Firebase by calling backend's dev-login (for testing).
    func devLogin() async {
        isDevLoggingIn = true
        errorMessage = nil
        defer { isDevLoggingIn = false }

        do {
            let response: LoginResponse = try await client.post("/auth/dev-login", body: DevLoginBody())
            KeychainHelper.saveToken(response.token)
            await client.setAuthToken(response.token)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private struct DevLoginBody: Encodable {}

    func loadStoredAuth() async {
        guard let token = KeychainHelper.loadToken(), !token.isEmpty else { return }
        await client.setAuthToken(token)
        isAuthenticated = true
    }

    func sendOTP() async {
        isSendingOTP = true
        errorMessage = nil
        defer { isSendingOTP = false }

        do {
            let id = try await authService.verifyPhoneNumber(phoneNumber)
            verificationID = id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyOTP() async {
        guard let vid = verificationID else {
            errorMessage = "Please request a code first"
            return
        }
        isVerifying = true
        errorMessage = nil
        defer { isVerifying = false }

        do {
            try await authService.signIn(verificationID: vid, verificationCode: verificationCode)
            let idToken = try await authService.idToken()

            struct LoginBody: Encodable {
                let idToken: String
                enum CodingKeys: String, CodingKey {
                    case idToken = "id_token"
                }
            }
            let response: LoginResponse = try await client.post("/auth/login", body: LoginBody(idToken: idToken))
            KeychainHelper.saveToken(response.token)
            await client.setAuthToken(response.token)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        try? authService.signOut()
        KeychainHelper.deleteToken()
        Task {
            await client.setAuthToken(nil)
        }
        verificationID = nil
        verificationCode = ""
        isAuthenticated = false
    }
}
