import SwiftUI
import FirebaseAuth

// MARK: - Social Tab View

struct SocialTabView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var socialService = SocialService.shared
    @State private var showingPhilosophyMoment: PhilosophyMoment?
    @State private var selectedSection: SocialSection = .friends
    @State private var selectedProtocol: FlowProtocol?
    @State private var showingProfileSetup = false

    enum SocialSection: String, CaseIterable {
        case friends = "Friends"
        case protocols = "Protocols"
        case profile = "Profile"
    }

    private var currentUserId: String {
        authManager.currentUser?.uid ?? ""
    }

    private var currentUsername: String {
        socialService.currentUserProfile?.username ?? "user"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Section picker
                sectionPicker

                // Content based on section
                switch selectedSection {
                case .friends:
                    FriendsListView(
                        currentUserId: currentUserId,
                        currentUsername: currentUsername,
                        onPhilosophyTap: { moment in
                            showingPhilosophyMoment = moment
                        }
                    )
                case .protocols:
                    ProtocolLibraryView(
                        userProfile: socialService.currentUserProfile,
                        onProtocolSelect: { flowProtocol in
                            selectedProtocol = flowProtocol
                        },
                        onPhilosophyTap: { moment in
                            showingPhilosophyMoment = moment
                        }
                    )
                case .profile:
                    if let profile = socialService.currentUserProfile {
                        ProfileView(
                            profile: profile,
                            isCurrentUser: true
                        )
                    } else {
                        profilePlaceholder
                    }
                }
            }
            .background(OnLifeColors.deepForest.ignoresSafeArea())
            .navigationTitle(selectedSection.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OnLifeColors.deepForest, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(item: $showingPhilosophyMoment) { moment in
            PhilosophyMomentSheet(moment: moment)
        }
        .sheet(item: $selectedProtocol) { flowProtocol in
            NavigationView {
                ProtocolDetailView(
                    flowProtocol: flowProtocol,
                    currentUserProfile: socialService.currentUserProfile,
                    onTryProtocol: {
                        selectedProtocol = nil
                    },
                    onFork: {
                        // Handle fork
                    },
                    onSave: {
                        // Handle save
                    },
                    onPhilosophyTap: { moment in
                        showingPhilosophyMoment = moment
                    },
                    onDismiss: {
                        selectedProtocol = nil
                    }
                )
            }
        }
        .task {
            // Load current user profile if needed
            if socialService.currentUserProfile == nil, !currentUserId.isEmpty {
                await socialService.loadCurrentUserProfile()
            }
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(SocialSection.allCases, id: \.self) { section in
                sectionButton(section)
            }
        }
        .padding(Spacing.xs)
        .background(OnLifeColors.cardBackground)
    }

    private func sectionButton(_ section: SocialSection) -> some View {
        Button(action: {
            withAnimation(.spring(duration: 0.2)) {
                selectedSection = section
            }
            HapticManager.shared.impact(style: .light)
        }) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: sectionIcon(section))
                    .font(.system(size: 14))

                Text(section.rawValue)
                    .font(OnLifeFont.label())
            }
            .foregroundColor(selectedSection == section ? OnLifeColors.textPrimary : OnLifeColors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .fill(selectedSection == section ? OnLifeColors.socialTeal : Color.clear)
            )
        }
    }

    private func sectionIcon(_ section: SocialSection) -> String {
        switch section {
        case .friends: return "person.2.fill"
        case .protocols: return "list.bullet.rectangle"
        case .profile: return "person.crop.circle.fill"
        }
    }

    // MARK: - Profile Placeholder

    private var profilePlaceholder: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(OnLifeColors.socialTeal)

            VStack(spacing: Spacing.sm) {
                Text("Create Your Profile")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Set up your flow profile to connect with others and share your journey")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            Button(action: {
                print("🧑‍💼 [Social] Set Up Profile button tapped")
                showingProfileSetup = true
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16))

                    Text("Set Up Profile")
                        .font(OnLifeFont.button())
                }
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.xxl)
                .padding(.vertical, Spacing.md)
                .background(
                    Capsule()
                        .fill(OnLifeColors.socialTeal)
                )
            }
            .padding(.top, Spacing.md)

            Spacer()
        }
        .sheet(isPresented: $showingProfileSetup) {
            ProfileSetupView(
                onComplete: {
                    print("🧑‍💼 [Social] Profile setup completed!")
                    showingProfileSetup = false
                },
                onDismiss: {
                    print("🧑‍💼 [Social] Profile setup dismissed")
                    showingProfileSetup = false
                }
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SocialTabView_Previews: PreviewProvider {
    static var previews: some View {
        SocialTabView()
            .preferredColorScheme(.dark)
    }
}
#endif
