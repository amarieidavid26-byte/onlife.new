import SwiftUI

// MARK: - Profile View

struct ProfileView: View {
    let profile: UserProfile
    let isCurrentUser: Bool

    @StateObject private var socialService = SocialService.shared
    @State private var showingPhilosophyMoment: PhilosophyMoment?
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var connectionLevel: ConnectionLevel?

    init(profile: UserProfile, isCurrentUser: Bool = false) {
        self.profile = profile
        self.isCurrentUser = isCurrentUser
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                // Profile Header
                profileHeader

                // Flow Portrait Card
                FlowPortraitCard(
                    profile: profile,
                    onPhilosophyTap: { moment in
                        showingPhilosophyMoment = moment
                    }
                )

                // Skill Badges Section
                if !profile.skillBadges.isEmpty {
                    skillBadgesSection
                }

                // Current Focus Section
                if let intention = profile.currentIntention, !intention.isEmpty {
                    currentFocusSection(intention: intention)
                }

                // Connection Actions (if viewing someone else's profile)
                if !isCurrentUser {
                    connectionActionsSection
                }

                // Stats Grid
                statsGridSection

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .background(OnLifeColors.deepForest.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isCurrentUser {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingEditProfile = true }) {
                            Label("Edit Profile", systemImage: "pencil")
                        }
                        Button(action: { showingSettings = true }) {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(OnLifeColors.textPrimary)
                    }
                }
            }
        }
        .sheet(item: $showingPhilosophyMoment) { moment in
            PhilosophyMomentSheet(moment: moment)
        }
        .task {
            if !isCurrentUser {
                connectionLevel = await socialService.getConnectionLevel(with: profile.id)
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(OnLifeColors.cardBackground)
                    .frame(width: 100, height: 100)

                if let imageURL = profile.profileImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            // Name and Username
            VStack(spacing: Spacing.xs) {
                Text(profile.displayName)
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("@\(profile.username)")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            // Bio
            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            // Experience Level Badge
            HStack(spacing: Spacing.xs) {
                Image(systemName: profile.experienceLevel.icon)
                    .font(.system(size: 12))

                Text(profile.experienceLevelDescription)
                    .font(OnLifeFont.labelSmall())
            }
            .foregroundColor(OnLifeColors.socialTeal)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(OnLifeColors.socialTeal.opacity(0.15))
            )
        }
    }

    // MARK: - Skill Badges Section

    private var skillBadgesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header with philosophy button
            HStack {
                Text("Skills Learned")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                PhilosophyButton {
                    showingPhilosophyMoment = PhilosophyMomentsLibrary.skillsNotHours
                }

                Spacer()
            }

            // Badges Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.md) {
                ForEach(profile.skillBadges) { badge in
                    SkillBadgeView(badge: badge) { moment in
                        showingPhilosophyMoment = moment
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Current Focus Section

    private func currentFocusSection(intention: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Current Focus")
                .font(OnLifeFont.label())
                .foregroundColor(OnLifeColors.textTertiary)

            Text("\"\(intention)\"")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)
                .italic()

            if let protocolId = profile.currentProtocolId, !protocolId.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))

                    Text("Using a shared protocol")
                        .font(OnLifeFont.bodySmall())

                    Spacer()

                    Text("View")
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.socialTeal)
                }
                .foregroundColor(OnLifeColors.textTertiary)
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Connection Actions

    private var connectionActionsSection: some View {
        VStack(spacing: Spacing.md) {
            if let level = connectionLevel {
                // Already connected
                HStack(spacing: Spacing.sm) {
                    Image(systemName: level.icon)
                    Text(level.displayName)
                }
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.socialTeal)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(OnLifeColors.socialTeal, lineWidth: 1)
                )
            } else {
                // Not connected - show connect button
                Button(action: sendConnectionRequest) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "person.badge.plus")
                        Text("Connect")
                    }
                    .font(OnLifeFont.button())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.socialTeal)
                    )
                }
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGridSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Garden Stats")
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.md) {
                StatCard(
                    icon: "leaf.fill",
                    value: "\(profile.totalPlantsGrown)",
                    label: "Plants Grown",
                    color: OnLifeColors.healthy
                )

                StatCard(
                    icon: "sparkles",
                    value: "\(profile.speciesUnlocked)",
                    label: "Species Unlocked",
                    color: OnLifeColors.amber
                )

                StatCard(
                    icon: "calendar",
                    value: "\(profile.gardenAgeDays)",
                    label: "Garden Age (days)",
                    color: OnLifeColors.sage
                )

                StatCard(
                    icon: "person.2.fill",
                    value: "\(profile.connectionCounts.total)",
                    label: "Connections",
                    color: OnLifeColors.socialTeal
                )
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Actions

    private func sendConnectionRequest() {
        Task {
            do {
                try await socialService.sendConnectionRequest(
                    toUserId: profile.id,
                    level: .friend,
                    message: nil
                )
                HapticManager.shared.notificationOccurred(.success)
            } catch {
                HapticManager.shared.notificationOccurred(.error)
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackgroundElevated)
        )
    }
}

// MARK: - Philosophy Button

struct PhilosophyButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            action()
        }) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundColor(OnLifeColors.amber)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView(
                profile: UserProfile(
                    id: "preview",
                    username: "sarahflows",
                    displayName: "Sarah Chen",
                    bio: "Learning to focus in a noisy world",
                    chronotype: .nightOwl,
                    peakFlowWindows: [TimeWindow(startHour: 22, endHour: 2)],
                    masteryDurationDays: 120,
                    gardenAgeDays: 120,
                    thirtyDayTrajectory: 34,
                    consistencyPercentile: 85,
                    totalPlantsGrown: 47,
                    speciesUnlocked: 12,
                    connectionCounts: ConnectionCounts(observers: 10, friends: 25, flowPartners: 3),
                    skillBadges: [
                        SkillBadge(
                            id: "1",
                            name: "Flow Initiation",
                            description: "Can enter flow within 5 minutes",
                            icon: "bolt.fill",
                            earnedDate: Date(),
                            category: .initiation
                        ),
                        SkillBadge(
                            id: "2",
                            name: "Extended Flow",
                            description: "Maintained 2hr+ sessions",
                            icon: "clock.fill",
                            earnedDate: Date(),
                            category: .depth
                        )
                    ]
                ),
                isCurrentUser: true
            )
        }
        .preferredColorScheme(.dark)
    }
}
#endif
