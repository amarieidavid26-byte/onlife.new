import SwiftUI
import AuthenticationServices
import FirebaseAuth
import CryptoKit
import GoogleSignIn
import FirebaseCore

// MARK: - Upgrade Account View

/// Allows anonymous users to upgrade their account to a permanent one
/// by linking with Apple, Google, or Email credentials
struct UpgradeAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager.shared

    @State private var isLoading = false
    @State private var loadingProvider: String?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingEmailUpgrade = false
    @State private var currentNonce: String?

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [OnLifeColors.deepForest, OnLifeColors.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Header
                        headerSection

                        // Benefits
                        benefitsSection

                        // Upgrade Options
                        upgradeOptionsSection

                        Spacer(minLength: Spacing.xxl)
                    }
                    .padding(.top, Spacing.lg)
                }
            }
            .navigationTitle("Upgrade Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingEmailUpgrade) {
                EmailUpgradeView(onSuccess: {
                    dismiss()
                })
            }
            .onChange(of: authManager.currentUser?.isAnonymous) { _, isAnonymous in
                if isAnonymous == false {
                    HapticManager.shared.notificationOccurred(.success)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(OnLifeColors.sage.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(OnLifeColors.sage)
            }

            VStack(spacing: Spacing.sm) {
                Text("Keep Your Progress")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Link your account to save your gardens and enable social features")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }
        }
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("BENEFITS")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .tracking(1.2)

            VStack(spacing: Spacing.sm) {
                benefitRow(icon: "icloud.fill", text: "Your data syncs across all devices")
                benefitRow(icon: "arrow.clockwise.circle.fill", text: "Restore your gardens if you reinstall")
                benefitRow(icon: "person.2.fill", text: "Connect with friends and share protocols")
                benefitRow(icon: "shield.fill", text: "Your data is securely backed up")
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
        }
        .padding(.horizontal, Spacing.lg)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(OnLifeColors.sage)
                .frame(width: 24)

            Text(text)
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textSecondary)

            Spacer()
        }
    }

    // MARK: - Upgrade Options Section

    private var upgradeOptionsSection: some View {
        VStack(spacing: Spacing.md) {
            // Sign in with Apple
            SignInWithAppleButton(.continue, onRequest: configureAppleRequest) { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .cornerRadius(CornerRadius.medium)
            .disabled(isLoading)

            // Sign in with Google
            Button(action: linkWithGoogle) {
                HStack(spacing: Spacing.sm) {
                    if isLoading && loadingProvider == "google" {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.textPrimary))
                    } else {
                        // Google "G" logo using text
                        Text("G")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .yellow, .green, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    Text("Continue with Google")
                        .font(OnLifeFont.button())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(CornerRadius.medium)
            }
            .disabled(isLoading)

            // Sign in with Email
            Button(action: {
                showingEmailUpgrade = true
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 16))

                    Text("Continue with Email")
                        .font(OnLifeFont.button())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(OnLifeColors.cardBackground)
                .foregroundColor(OnLifeColors.textPrimary)
                .cornerRadius(CornerRadius.medium)
            }
            .disabled(isLoading)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Apple Sign In

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    await linkWithApple(credential: appleIDCredential)
                }
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                showError(message: error.localizedDescription)
            }
        }
    }

    private func linkWithApple(credential: ASAuthorizationAppleIDCredential) async {
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
        loadingProvider = "apple"

        let firebaseCredential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )

        do {
            guard let user = Auth.auth().currentUser else {
                throw NSError(domain: "UpgradeAccount", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
            }

            let result = try await user.link(with: firebaseCredential)

            // Save user's name if provided
            if let fullName = credential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")

                if !displayName.isEmpty {
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try await changeRequest.commitChanges()
                }
            }

            print("✅ [UpgradeAccount] Linked with Apple successfully")
        } catch let error as NSError {
            if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                showError(message: "This Apple ID is already linked to another account.")
            } else {
                showError(message: error.localizedDescription)
            }
        }

        isLoading = false
        loadingProvider = nil
    }

    // MARK: - Google Sign In

    private func linkWithGoogle() {
        Task {
            isLoading = true
            loadingProvider = "google"

            guard let clientID = FirebaseApp.app()?.options.clientID else {
                showError(message: "Firebase not configured")
                isLoading = false
                loadingProvider = nil
                return
            }

            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                showError(message: "Unable to get root view controller")
                isLoading = false
                loadingProvider = nil
                return
            }

            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

                guard let idToken = result.user.idToken?.tokenString else {
                    showError(message: "Unable to get Google ID token")
                    isLoading = false
                    loadingProvider = nil
                    return
                }

                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )

                guard let user = Auth.auth().currentUser else {
                    throw NSError(domain: "UpgradeAccount", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
                }

                _ = try await user.link(with: credential)
                print("✅ [UpgradeAccount] Linked with Google successfully")
            } catch let error as NSError {
                if error.code == GIDSignInError.canceled.rawValue {
                    // User cancelled, don't show error
                } else if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                    showError(message: "This Google account is already linked to another account.")
                } else {
                    showError(message: error.localizedDescription)
                }
            }

            isLoading = false
            loadingProvider = nil
        }
    }

    // MARK: - Helpers

    private func showError(message: String) {
        errorMessage = message
        showError = true
        HapticManager.shared.notificationOccurred(.error)
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Email Upgrade View

struct EmailUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    let onSuccess: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6 && password == confirmPassword
    }

    var body: some View {
        NavigationView {
            ZStack {
                OnLifeColors.deepForest.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Header
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 48))
                                .foregroundColor(OnLifeColors.sage)

                            Text("Link Email")
                                .font(OnLifeFont.heading2())
                                .foregroundColor(OnLifeColors.textPrimary)
                        }
                        .padding(.top, Spacing.xl)

                        // Form
                        VStack(spacing: Spacing.md) {
                            // Email field
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Email")
                                    .font(OnLifeFont.label())
                                    .foregroundColor(OnLifeColors.textSecondary)

                                TextField("your@email.com", text: $email)
                                    .font(OnLifeFont.body())
                                    .foregroundColor(OnLifeColors.textPrimary)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding(Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                            .fill(OnLifeColors.cardBackground)
                                    )
                            }

                            // Password field
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Password")
                                    .font(OnLifeFont.label())
                                    .foregroundColor(OnLifeColors.textSecondary)

                                SecureField("••••••••", text: $password)
                                    .font(OnLifeFont.body())
                                    .foregroundColor(OnLifeColors.textPrimary)
                                    .textContentType(.newPassword)
                                    .padding(Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                            .fill(OnLifeColors.cardBackground)
                                    )

                                if password.count > 0 && password.count < 6 {
                                    Text("Password must be at least 6 characters")
                                        .font(OnLifeFont.caption())
                                        .foregroundColor(OnLifeColors.warning)
                                }
                            }

                            // Confirm Password field
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Confirm Password")
                                    .font(OnLifeFont.label())
                                    .foregroundColor(OnLifeColors.textSecondary)

                                SecureField("••••••••", text: $confirmPassword)
                                    .font(OnLifeFont.body())
                                    .foregroundColor(OnLifeColors.textPrimary)
                                    .textContentType(.newPassword)
                                    .padding(Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                            .fill(OnLifeColors.cardBackground)
                                    )

                                if !confirmPassword.isEmpty && password != confirmPassword {
                                    Text("Passwords don't match")
                                        .font(OnLifeFont.caption())
                                        .foregroundColor(OnLifeColors.warning)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)

                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.warning)
                                .padding(.horizontal, Spacing.lg)
                        }

                        // Submit button
                        Button(action: linkWithEmail) {
                            HStack(spacing: Spacing.sm) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                } else {
                                    Text("Link Email")
                                        .font(OnLifeFont.button())
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                Capsule()
                                    .fill(isFormValid ? OnLifeColors.sage : OnLifeColors.textMuted)
                            )
                        }
                        .disabled(!isFormValid || isLoading)
                        .padding(.horizontal, Spacing.lg)

                        Spacer(minLength: Spacing.xxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }
            }
        }
    }

    private func linkWithEmail() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let user = Auth.auth().currentUser else {
                    throw NSError(domain: "EmailUpgrade", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
                }

                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                _ = try await user.link(with: credential)

                print("✅ [UpgradeAccount] Linked with email successfully")
                HapticManager.shared.notificationOccurred(.success)

                await MainActor.run {
                    dismiss()
                    onSuccess()
                }
            } catch let error as NSError {
                await MainActor.run {
                    if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                        errorMessage = "This email is already linked to another account."
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    HapticManager.shared.notificationOccurred(.error)
                }
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct UpgradeAccountView_Previews: PreviewProvider {
    static var previews: some View {
        UpgradeAccountView()
            .preferredColorScheme(.dark)
    }
}
#endif
