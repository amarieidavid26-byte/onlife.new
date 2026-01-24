import SwiftUI
import PhotosUI
import FirebaseAuth

// MARK: - Profile Setup View

struct ProfileSetupView: View {
    let onComplete: () -> Void
    let onDismiss: () -> Void

    @StateObject private var socialService = SocialService.shared
    @StateObject private var authManager = AuthenticationManager.shared

    @State private var username = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var usernameAvailable: Bool?
    @State private var checkingUsername = false

    private var isFormValid: Bool {
        !username.isEmpty &&
        username.count >= 3 &&
        !displayName.isEmpty &&
        usernameAvailable == true
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    // Header
                    headerSection

                    // Profile Photo
                    photoSection

                    // Form Fields
                    formSection

                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.warning)
                            .padding(.horizontal, Spacing.lg)
                    }

                    // Create Profile Button
                    createButton

                    Spacer(minLength: Spacing.xxl)
                }
                .padding(.top, Spacing.lg)
            }
            .background(OnLifeColors.deepForest.ignoresSafeArea())
            .navigationTitle("Create Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(OnLifeColors.socialTeal)

            Text("Set Up Your Profile")
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)

            Text("Create your flow profile to connect with others and share your journey")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: Spacing.md) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    if let imageData = profileImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(OnLifeColors.cardBackground)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(OnLifeColors.textTertiary)
                            )
                    }

                    // Edit badge
                    Circle()
                        .fill(OnLifeColors.socialTeal)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 35, y: 35)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        profileImageData = data
                    }
                }
            }

            Text("Add Profile Photo")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: Spacing.lg) {
            // Username field
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Username")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textSecondary)

                HStack {
                    Text("@")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textTertiary)

                    TextField("username", text: $username)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: username) { _, newValue in
                            // Sanitize username
                            username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            checkUsernameAvailability()
                        }

                    if checkingUsername {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let available = usernameAvailable {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(available ? OnLifeColors.healthy : OnLifeColors.warning)
                    }
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(OnLifeColors.cardBackground)
                )

                if username.count > 0 && username.count < 3 {
                    Text("Username must be at least 3 characters")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.warning)
                } else if usernameAvailable == false {
                    Text("This username is already taken")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.warning)
                }
            }

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

            // Bio field
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("Bio")
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.textSecondary)

                    Spacer()

                    Text("\(bio.count)/150")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                TextEditor(text: $bio)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .frame(height: 80)
                    .padding(Spacing.sm)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.cardBackground)
                    )
                    .onChange(of: bio) { _, newValue in
                        if newValue.count > 150 {
                            bio = String(newValue.prefix(150))
                        }
                    }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button(action: createProfile) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text("Create Profile")
                        .font(OnLifeFont.button())
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                Capsule()
                    .fill(isFormValid ? OnLifeColors.socialTeal : OnLifeColors.textMuted)
            )
        }
        .disabled(!isFormValid || isLoading)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Actions

    private func checkUsernameAvailability() {
        guard username.count >= 3 else {
            usernameAvailable = nil
            return
        }

        checkingUsername = true

        Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 500_000_000)

            let available = await socialService.isUsernameAvailable(username)
            await MainActor.run {
                usernameAvailable = available
                checkingUsername = false
            }
        }
    }

    private func createProfile() {
        print("🧑‍💼 [ProfileSetup] createProfile() called")

        guard let userId = authManager.currentUser?.uid else {
            print("🧑‍💼 [ProfileSetup] ERROR: No user ID found")
            errorMessage = "Please sign in to create a profile"
            return
        }

        print("🧑‍💼 [ProfileSetup] User ID: \(userId)")
        print("🧑‍💼 [ProfileSetup] Username: \(username), DisplayName: \(displayName)")

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let profile = UserProfile(
                    id: userId,
                    username: username,
                    displayName: displayName,
                    bio: bio
                )

                print("🧑‍💼 [ProfileSetup] Saving profile to Firestore...")
                try await socialService.saveProfile(profile)
                print("🧑‍💼 [ProfileSetup] Profile saved successfully!")

                print("🧑‍💼 [ProfileSetup] Loading current user profile...")
                await socialService.loadCurrentUserProfile()
                print("🧑‍💼 [ProfileSetup] Profile loaded: \(socialService.currentUserProfile?.username ?? "nil")")

                await MainActor.run {
                    isLoading = false
                    HapticManager.shared.notificationOccurred(.success)
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to create profile: \(error.localizedDescription)"
                    HapticManager.shared.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView(
            onComplete: {},
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
