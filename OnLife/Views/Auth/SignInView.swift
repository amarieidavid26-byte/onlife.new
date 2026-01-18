import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var displayName = ""
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var showPasswordResetSent = false

    var body: some View {
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
                    // Logo and Welcome
                    headerSection
                        .padding(.top, Spacing.xxxl)

                    // Sign In Options
                    VStack(spacing: Spacing.lg) {
                        // Apple Sign In Button
                        appleSignInButton

                        // Google Sign In Button
                        googleSignInButton

                        // Divider
                        dividerWithText("or continue with email")

                        // Email/Password Form
                        emailPasswordForm

                        // Forgot Password
                        if !isCreatingAccount {
                            Button {
                                forgotPasswordEmail = email
                                showForgotPassword = true
                            } label: {
                                Text("Forgot password?")
                                    .font(OnLifeFont.bodySmall())
                                    .foregroundColor(OnLifeColors.sage)
                            }
                        }

                        // Submit Button
                        submitButton

                        // Toggle Create/Sign In
                        toggleModeButton
                    }
                    .padding(.horizontal, Spacing.lg)

                    // Skip (Anonymous)
                    skipButton
                        .padding(.top, Spacing.lg)

                    Spacer(minLength: Spacing.xxxl)
                }
            }

            // Loading Overlay
            if authManager.isLoading {
                loadingOverlay
            }
        }
        .alert("Reset Password", isPresented: $showForgotPassword) {
            TextField("Email", text: $forgotPasswordEmail)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
            Button("Cancel", role: .cancel) { }
            Button("Send Reset Link") {
                Task {
                    await authManager.resetPassword(email: forgotPasswordEmail)
                    showPasswordResetSent = true
                }
            }
        } message: {
            Text("Enter your email address and we'll send you a link to reset your password.")
        }
        .alert("Email Sent", isPresented: $showPasswordResetSent) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Check your email for a password reset link.")
        }
        .alert("Error", isPresented: .init(
            get: { authManager.errorMessage != nil },
            set: { if !$0 { authManager.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            // App Icon/Logo
            ZStack {
                Circle()
                    .fill(OnLifeColors.sage.opacity(0.2))
                    .frame(width: 100, height: 100)

                Text("🌱")
                    .font(.system(size: 50))
            }

            Text("Welcome to OnLife")
                .font(OnLifeFont.display())
                .foregroundColor(OnLifeColors.textPrimary)

            Text("Focus deeply. Grow mindfully.")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
        }
    }

    // MARK: - Apple Sign In Button

    private var appleSignInButton: some View {
        Button {
            authManager.signInWithApple()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20, weight: .semibold))
                Text("Continue with Apple")
                    .font(OnLifeFont.button())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.black)
            .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: - Google Sign In Button

    private var googleSignInButton: some View {
        Button {
            Task {
                await authManager.signInWithGoogle()
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("Continue with Google")
                    .font(OnLifeFont.button())
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: - Email/Password Form

    private var emailPasswordForm: some View {
        VStack(spacing: Spacing.md) {
            if isCreatingAccount {
                // Name field for account creation
                TextField("Name", text: $displayName)
                    .textContentType(.name)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.cardBackground)
                    )
            }

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(OnLifeColors.cardBackground)
                )

            SecureField("Password", text: $password)
                .textContentType(isCreatingAccount ? .newPassword : .password)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(OnLifeColors.cardBackground)
                )
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            Task {
                if isCreatingAccount {
                    await authManager.createAccount(
                        email: email,
                        password: password,
                        displayName: displayName.isEmpty ? nil : displayName
                    )
                } else {
                    await authManager.signInWithEmail(email: email, password: password)
                }
            }
        } label: {
            Text(isCreatingAccount ? "Create Account" : "Sign In")
                .font(OnLifeFont.button())
                .foregroundColor(OnLifeColors.deepForest)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(OnLifeColors.sage)
                .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(PressableCardStyle())
        .disabled(email.isEmpty || password.isEmpty || (isCreatingAccount && password.count < 6))
        .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
    }

    // MARK: - Toggle Mode Button

    private var toggleModeButton: some View {
        Button {
            withAnimation {
                isCreatingAccount.toggle()
                // Clear password when switching modes
                password = ""
            }
        } label: {
            HStack(spacing: 4) {
                Text(isCreatingAccount ? "Already have an account?" : "Don't have an account?")
                    .foregroundColor(OnLifeColors.textSecondary)
                Text(isCreatingAccount ? "Sign In" : "Create one")
                    .foregroundColor(OnLifeColors.sage)
                    .fontWeight(.semibold)
            }
            .font(OnLifeFont.body())
        }
    }

    // MARK: - Skip Button

    private var skipButton: some View {
        Button {
            Task {
                await authManager.signInAnonymously()
            }
        } label: {
            Text("Skip for now")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textTertiary)
                .underline()
        }
    }

    // MARK: - Divider

    private func dividerWithText(_ text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Rectangle()
                .fill(OnLifeColors.textTertiary.opacity(0.3))
                .frame(height: 1)

            Text(text)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)

            Rectangle()
                .fill(OnLifeColors.textTertiary.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.sage))
                    .scaleEffect(1.5)

                Text("Signing in...")
                    .font(OnLifeFont.body())
                    .foregroundColor(.white)
            }
            .padding(Spacing.xl)
            .background(OnLifeColors.cardBackground)
            .cornerRadius(CornerRadius.large)
        }
    }
}

#Preview {
    SignInView()
}
