import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import CryptoKit
import GoogleSignIn

// MARK: - Authentication Manager
/// Handles all authentication methods: Apple, Email/Password, Anonymous

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()

    // MARK: - Published Properties

    @Published var isAuthenticated: Bool = false
    @Published var currentUser: FirebaseAuth.User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var currentNonce: String?
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // MARK: - Initialization

    override init() {
        super.init()
        setupAuthStateListener()
    }

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil

                if let user = user {
                    print("🔐 [Auth] User signed in: \(user.uid)")
                    print("   Provider: \(user.providerData.first?.providerID ?? "unknown")")
                    print("   Anonymous: \(user.isAnonymous)")
                    print("   Email: \(user.email ?? "none")")
                } else {
                    print("🔐 [Auth] User signed out")
                }
            }
        }
    }

    // MARK: - Apple Sign In

    /// Start Apple Sign In flow
    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.performRequests()

        isLoading = true
        errorMessage = nil
        print("🍎 [Auth] Starting Apple Sign In...")
    }

    /// Handle Apple Sign In credential
    private func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) async {
        guard let nonce = currentNonce else {
            errorMessage = "Invalid state: No nonce available"
            isLoading = false
            return
        }

        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to fetch identity token"
            isLoading = false
            return
        }

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
            isLoading = false
        } catch {
            print("❌ [Auth] Apple Sign In failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Google Sign In

    /// Start Google Sign In flow
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase not configured"
            isLoading = false
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to get root view controller"
            isLoading = false
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Unable to get Google ID token"
                isLoading = false
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ [Auth] Google Sign In successful: \(authResult.user.uid)")
            isLoading = false
        } catch {
            print("❌ [Auth] Google Sign In failed: \(error.localizedDescription)")

            // Don't show error for user cancellation
            if (error as NSError).code != GIDSignInError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Email/Password Sign In

    /// Sign in with email and password
    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ [Auth] Email Sign In successful: \(result.user.uid)")
            isLoading = false
        } catch {
            print("❌ [Auth] Email Sign In failed: \(error.localizedDescription)")
            errorMessage = mapFirebaseError(error)
            isLoading = false
        }
    }

    /// Create new account with email and password
    func createAccount(email: String, password: String, displayName: String? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Set display name if provided
            if let displayName = displayName, !displayName.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }

            print("✅ [Auth] Account created: \(result.user.uid)")
            isLoading = false
        } catch {
            print("❌ [Auth] Account creation failed: \(error.localizedDescription)")
            errorMessage = mapFirebaseError(error)
            isLoading = false
        }
    }

    /// Send password reset email
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("✅ [Auth] Password reset email sent to: \(email)")
            isLoading = false
        } catch {
            print("❌ [Auth] Password reset failed: \(error.localizedDescription)")
            errorMessage = mapFirebaseError(error)
            isLoading = false
        }
    }

    // MARK: - Anonymous Sign In

    /// Sign in anonymously
    func signInAnonymously() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await Auth.auth().signInAnonymously()
            print("✅ [Auth] Anonymous Sign In successful: \(result.user.uid)")
            isLoading = false
        } catch {
            print("❌ [Auth] Anonymous Sign In failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Sign Out

    /// Sign out current user
    func signOut() {
        do {
            try Auth.auth().signOut()
            print("✅ [Auth] Signed out")
        } catch {
            print("❌ [Auth] Sign out failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Account Management

    /// Delete current user account
    func deleteAccount() async {
        guard let user = currentUser else {
            errorMessage = "No user signed in"
            return
        }

        isLoading = true

        do {
            // Delete Firestore data first
            try await FirebaseManager.shared.deleteUserData(userId: user.uid)

            // Delete auth account
            try await user.delete()
            print("✅ [Auth] Account deleted")
            isLoading = false
        } catch {
            print("❌ [Auth] Account deletion failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Link anonymous account to Apple
    func linkWithApple() {
        guard currentUser?.isAnonymous == true else {
            errorMessage = "Can only link anonymous accounts"
            return
        }

        // Same flow as sign in, but we'll link instead
        signInWithApple()
    }

    // MARK: - Helper Methods

    /// Map Firebase errors to user-friendly messages
    private func mapFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError

        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return "Incorrect password. Please try again."
        case AuthErrorCode.invalidEmail.rawValue:
            return "Please enter a valid email address."
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "This email is already registered. Try signing in instead."
        case AuthErrorCode.weakPassword.rawValue:
            return "Password must be at least 6 characters."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email. Create one?"
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many attempts. Please try again later."
        default:
            return error.localizedDescription
        }
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

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            Task { @MainActor in
                await handleAppleSignIn(credential: appleIDCredential)
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        Task { @MainActor in
            print("❌ [Auth] Apple Sign In error: \(error.localizedDescription)")

            // Don't show error for user cancellation
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
