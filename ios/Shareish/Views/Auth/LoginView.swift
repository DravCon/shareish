//
//  LoginView.swift
//  Shareish
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var serverURL: String = ServerConfig.baseURL

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if viewModel.isOTPSent {
                    otpSection
                } else {
                    phoneSection
                }

                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                serverURLSection
            }
            .padding(32)
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            serverURL = ServerConfig.baseURL
        }
    }

    private var phoneSection: some View {
        Group {
            Text("Enter your phone number")
                .font(.headline)
            TextField("Phone", text: $viewModel.phoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding()
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("Use a test number from Firebase Console (Phone → Phone numbers for testing) to get a fixed code without SMS.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Send OTP") {
                Task { await viewModel.sendOTP() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.phoneNumber.count < 10 || viewModel.isSendingOTP)

            Text("or")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Dev login (no Firebase)") {
                Task { await viewModel.devLogin() }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isDevLoggingIn)
        }
    }

    private var serverURLSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Server (use your Mac's IP on device)")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("http://localhost:8000/api/v1", text: $serverURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.caption)
                .padding(8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: serverURL) { _, newValue in
                    ServerConfig.baseURL = newValue
                }
        }
    }

    private var otpSection: some View {
        Group {
            Text("Enter the 6-digit code")
                .font(.headline)
            TextField("000000", text: $viewModel.verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title2)
                .padding()
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Button("Verify") {
                Task { await viewModel.verifyOTP() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.verificationCode.count != 6 || viewModel.isVerifying)
            Button("Change number") {
                viewModel.verificationID = nil
                viewModel.verificationCode = ""
            }
            .buttonStyle(.bordered)
        }
    }
}
