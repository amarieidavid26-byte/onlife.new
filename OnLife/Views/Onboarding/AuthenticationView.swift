import SwiftUI
import AuthenticationServices

// MARK: - Authentication View

/// The first screen users see - allows them to choose authentication method
/// before proceeding to onboarding
struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @State private var showingEmailSignIn = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [OnLifeColors.deepForest, OnLifeColors.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo and Welcome
                welcomeSection

                Spacer()

                // Authentication Options
                authOptionsSection

                // Skip option
                skipSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $showingEmailSignIn) {
            EmailSignInView()
        }
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(spacing: Spacing.lg) {
            // App icon/logo
            ZStack {
                Circle()
                    .fill(OnLifeColors.sage.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 56))
                    .foregroundColor(OnLifeColors.sage)
            }

            VStack(spacing: Spacing.sm) {
                Text("Welcome to OnLife")
                    .font(OnLifeFont.display())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Your personal flow state garden")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Benefits of signing in
            VStack(alignment: .leading, spacing: Spacing.sm) {
                benefitRow(icon: "icloud.fill", text: "Sync your gardens across devices")
                benefitRow(icon: "person.2.fill", text: "Connect with friends")
                benefitRow(icon: "arrow.clockwise.circle.fill", text: "Restore your data anytime")
            }
            .padding(.top, Spacing.md)
        }
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
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Auth Options Section

    private var authOptionsSection: some View {
        VStack(spacing: Spacing.md) {
            // Sign in with Apple
            SignInWithAppleButton(.signIn, onRequest: viewModel.configureAppleRequest) { result in
                viewModel.handleAppleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .cornerRadius(CornerRadius.medium)
            .disabled(viewModel.isLoading)

            // Sign in with Google
            Button(action: {
                Task {
                    await viewModel.signInWithGoogle()
                }
            }) {
                HStack(spacing: Spacing.sm) {
                    if viewModel.isLoading && viewModel.loadingProvider == .google {
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

                    Text("Sign in with Google")
                        .font(OnLifeFont.button())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(CornerRadius.medium)
            }
            .disabled(viewModel.isLoading)

            // Sign in with Email
            Button(action: {
                showingEmailSignIn = true
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 16))

                    Text("Sign in with Email")
                        .font(OnLifeFont.button())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(OnLifeColors.cardBackground)
                .foregroundColor(OnLifeColors.textPrimary)
                .cornerRadius(CornerRadius.medium)
            }
            .disabled(viewModel.isLoading)
        }
    }

    // MARK: - Skip Section

    private var skipSection: some View {
        VStack(spacing: Spacing.sm) {
            Button(action: {
                Task {
                    await viewModel.continueAnonymously()
                }
            }) {
                HStack(spacing: Spacing.xs) {
                    if viewModel.isLoading && viewModel.loadingProvider == .anonymous {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.textTertiary))
                            .scaleEffect(0.8)
                    }

                    Text("Continue without signing in")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }
            .disabled(viewModel.isLoading)
            .padding(.top, Spacing.lg)

            Text("You can sign in later in Settings")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textMuted)
        }
    }
}

// MARK: - Email Sign In View

struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var displayName = ""
    @State private var showingForgotPassword = false

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6 &&
        (!isSignUp || !displayName.isEmpty)
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

                            Text(isSignUp ? "Create Account" : "Sign In")
                                .font(OnLifeFont.heading2())
                                .foregroundColor(OnLifeColors.textPrimary)
                        }
                        .padding(.top, Spacing.xl)

                        // Form
                        VStack(spacing: Spacing.md) {
                            if isSignUp {
                                // Display Name field
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text("Display Name")
                                        .font(OnLifeFont.label())
                                        .foregroundColor(OnLifeColors.textSecondary)

                                    TextField("Your name", text: $displayName)
                                        .font(OnLifeFont.body())
                                        .foregroundColor(OnLifeColors.textPrimary)
                                        .padding(Spacing.md)
                                        .background(
                                            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                                .fill(OnLifeColors.cardBackground)
                                        )
                                }
                            }

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
                                    .textContentType(isSignUp ? .newPassword : .password)
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
                        }
                        .padding(.horizontal, Spacing.lg)

                        // Error message
                        if let error = authManager.errorMessage {
                            Text(error)
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.warning)
                                .padding(.horizontal, Spacing.lg)
                        }

                        // Submit button
                        Button(action: submit) {
                            HStack(spacing: Spacing.sm) {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
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
                        .disabled(!isFormValid || authManager.isLoading)
                        .padding(.horizontal, Spacing.lg)

                        // Toggle sign up/sign in
                        Button(action: {
                            withAnimation(.spring(duration: 0.2)) {
                                isSignUp.toggle()
                            }
                        }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(OnLifeFont.bodySmall())
                                .foregroundColor(OnLifeColors.sage)
                        }

                        // Forgot password
                        if !isSignUp {
                            Button(action: {
                                showingForgotPassword = true
                            }) {
                                Text("Forgot password?")
                                    .font(OnLifeFont.caption())
                                    .foregroundColor(OnLifeColors.textTertiary)
                            }
                        }

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
            .alert("Reset Password", isPresented: $showingForgotPassword) {
                TextField("Email", text: $email)
                Button("Cancel", role: .cancel) {}
                Button("Send Reset Link") {
                    Task {
                        await authManager.resetPassword(email: email)
                    }
                }
            } message: {
                Text("Enter your email to receive a password reset link.")
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    dismiss()
                }
            }
        }
    }

    private func submit() {
        Task {
            if isSignUp {
                await authManager.createAccount(email: email, password: password, displayName: displayName)
            } else {
                await authManager.signInWithEmail(email: email, password: password)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
            .preferredColorScheme(.dark)
    }
}
#endif
