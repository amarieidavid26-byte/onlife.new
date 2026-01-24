import Foundation
import Combine
import SwiftUI
import AuthenticationServices
import FirebaseAuth
import CryptoKit

// MARK: - Authentication Provider

enum AuthProvider {
    case apple
    case google
    case email
    case anonymous
}

// MARK: - Authentication View Model

@MainActor
class AuthenticationViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var loadingProvider: AuthProvider?

    // MARK: - Private Properties

    private var currentNonce: String?
    private let authManager = AuthenticationManager.shared

    // MARK: - Apple Sign In

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    await signInWithAppleCredential(appleIDCredential)
                }
            }
        case .failure(let error):
            // Don't show error for user cancellation
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                showError(message: error.localizedDescription)
            }
        }
    }

    private func signInWithAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async {
        guard let nonce = currentNonce else {
            showError(message: "Invalid state: No nonce available")
            return
        }

        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            showError(message: "Unable to fetch identity token")
            return
        }

        isLoading = true
        loadingProvider = .apple

        let firebaseCredential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )

        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)

            // Save user's name if provided (only on first sign in)
            if let fullName = credential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")

                if !displayName.isEmpty {
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try await changeRequest.commitChanges()
                    print("🍎 [Auth] Saved display name: \(displayName)")
                }
            }

            print("✅ [Auth] Apple Sign In successful: \(result.user.uid)")
            HapticManager.shared.notificationOccurred(.success)
        } catch {
            print("❌ [Auth] Apple Sign In failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
        loadingProvider = nil
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        isLoading = true
        loadingProvider = .google

        await authManager.signInWithGoogle()

        if let error = authManager.errorMessage {
            showError(message: error)
        } else {
            HapticManager.shared.notificationOccurred(.success)
        }

        isLoading = false
        loadingProvider = nil
    }

    // MARK: - Anonymous Sign In

    func continueAnonymously() async {
        isLoading = true
        loadingProvider = .anonymous

        await authManager.signInAnonymously()

        if let error = authManager.errorMessage {
            showError(message: error)
        } else {
            HapticManager.shared.notificationOccurred(.success)
        }

        isLoading = false
        loadingProvider = nil
    }

    // MARK: - Error Handling

    private func showError(message: String) {
        errorMessage = message
        showError = true
        HapticManager.shared.notificationOccurred(.error)
    }

    // MARK: - Crypto Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}
