import SwiftUI

// MARK: - Friends List View

struct FriendsListView: View {
    let currentUserId: String
    let currentUsername: String
    let onPhilosophyTap: (PhilosophyMoment) -> Void

    @StateObject private var socialService = SocialService.shared
    @State private var selectedFilter: ConnectionLevel?
    @State private var showingAddFriend = false
    @State private var showingRequests = false
    @State private var selectedProfile: UserProfile?
    @State private var showingLimitAlert = false
    @State private var limitAlertLevel: ConnectionLevel?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Connection slots overview
                connectionSlotsCard

                // Pending requests banner
                if hasPendingRequests {
                    pendingRequestsBanner
                }

                // Filter pills
                filterPills

                // Friends list
                if filteredConnections.isEmpty {
                    emptyStateView
                } else {
                    friendsList
                }
            }
            .padding(Spacing.lg)
        }
        .background(OnLifeColors.deepForest.ignoresSafeArea())
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddFriend = true }) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(OnLifeColors.socialTeal)
                }
            }
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView(
                currentUserId: currentUserId,
                currentUsername: currentUsername,
                onPhilosophyTap: onPhilosophyTap,
                onDismiss: { showingAddFriend = false }
            )
        }
        .sheet(isPresented: $showingRequests) {
            NavigationView {
                ConnectionRequestsView(
                    currentUserId: currentUserId,
                    onPhilosophyTap: onPhilosophyTap
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingRequests = false
                        }
                        .foregroundColor(OnLifeColors.socialTeal)
                    }
                }
            }
        }
        .sheet(item: $selectedProfile) { profile in
            // Profile detail view
            Text("Profile: \(profile.username)")
        }
        .alert("Connection Limit Reached", isPresented: $showingLimitAlert) {
            Button("Learn More") {
                onPhilosophyTap(PhilosophyMomentsLibrary.dunbarNumber)
            }
            Button("OK", role: .cancel) {}
        } message: {
            if let level = limitAlertLevel {
                Text(limitAlertMessage(for: level))
            }
        }
        .task {
            await socialService.fetchConnections(for: currentUserId)
            await socialService.fetchConnectionRequests(for: currentUserId)
        }
    }

    // MARK: - Data

    private var hasPendingRequests: Bool {
        !socialService.pendingRequests.filter { $0.toUserId == currentUserId }.isEmpty
    }

    private var pendingRequestCount: Int {
        socialService.pendingRequests.filter { $0.toUserId == currentUserId }.count
    }

    private var filteredConnections: [Connection] {
        if let filter = selectedFilter {
            return socialService.connections.filter { $0.level == filter }
        }
        return socialService.connections
    }

    // MARK: - Connection Slots Card

    private var connectionSlotsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Connection Slots")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                PhilosophyButton {
                    onPhilosophyTap(PhilosophyMomentsLibrary.dunbarNumber)
                }

                Spacer()
            }

            // Slots grid
            HStack(spacing: Spacing.md) {
                slotIndicator(
                    level: .flowPartner,
                    used: connectionCount(for: .flowPartner),
                    limit: ConnectionLevel.flowPartner.limit ?? 5
                )

                slotIndicator(
                    level: .mentor,
                    used: connectionCount(for: .mentor),
                    limit: ConnectionLevel.mentor.limit ?? 2
                )

                slotIndicator(
                    level: .friend,
                    used: connectionCount(for: .friend),
                    limit: ConnectionLevel.friend.limit ?? 150
                )
            }

            // Observer count (no limit)
            HStack(spacing: Spacing.sm) {
                Image(systemName: "eye")
                    .font(.system(size: 12))

                Text("\(connectionCount(for: .observer)) Observers")
                    .font(OnLifeFont.caption())

                Text("(no limit)")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textMuted)
            }
            .foregroundColor(OnLifeColors.textTertiary)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func slotIndicator(level: ConnectionLevel, used: Int, limit: Int) -> some View {
        let isFull = used >= limit
        let color = levelColor(level)

        return VStack(spacing: Spacing.xs) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: CGFloat(used) / CGFloat(limit))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(used)")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("/\(limit)")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }
            .frame(width: 60, height: 60)

            // Label
            HStack(spacing: 2) {
                Image(systemName: level.icon)
                    .font(.system(size: 10))

                Text(level.rawValue)
                    .font(OnLifeFont.labelSmall())
            }
            .foregroundColor(color)

            // Status
            if isFull {
                Text("Full")
                    .font(OnLifeFont.labelSmall())
                    .foregroundColor(OnLifeColors.warning)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func connectionCount(for level: ConnectionLevel) -> Int {
        socialService.connections.filter { $0.level == level }.count
    }

    // MARK: - Pending Requests Banner

    private var pendingRequestsBanner: some View {
        Button(action: { showingRequests = true }) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(OnLifeColors.socialTeal.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 18))
                        .foregroundColor(OnLifeColors.socialTeal)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pendingRequestCount) pending request\(pendingRequestCount == 1 ? "" : "s")")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Tap to review")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(OnLifeColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(OnLifeColors.socialTeal.opacity(0.5), lineWidth: 2)
                    )
            )
        }
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                // All
                filterPill(nil, label: "All", count: socialService.connections.count)

                // By level
                ForEach([ConnectionLevel.flowPartner, .mentor, .friend, .observer], id: \.self) { level in
                    filterPill(level, label: level.rawValue, count: connectionCount(for: level))
                }
            }
        }
    }

    private func filterPill(_ level: ConnectionLevel?, label: String, count: Int) -> some View {
        let isSelected = selectedFilter == level

        return Button(action: {
            withAnimation(.spring(duration: 0.2)) {
                selectedFilter = level
            }
            HapticManager.shared.impact(style: .light)
        }) {
            HStack(spacing: Spacing.xs) {
                if let level = level {
                    Image(systemName: level.icon)
                        .font(.system(size: 10))
                }

                Text(label)
                    .font(OnLifeFont.label())

                Text("\(count)")
                    .font(OnLifeFont.labelSmall())
                    .foregroundColor(isSelected ? OnLifeColors.textPrimary.opacity(0.7) : OnLifeColors.textMuted)
            }
            .foregroundColor(isSelected ? OnLifeColors.textPrimary : OnLifeColors.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? (level != nil ? levelColor(level!) : OnLifeColors.socialTeal) : OnLifeColors.cardBackground)
            )
        }
    }

    // MARK: - Friends List

    private var friendsList: some View {
        LazyVStack(spacing: Spacing.md) {
            ForEach(filteredConnections) { connection in
                FriendRow(
                    connection: connection,
                    onTap: {
                        // Fetch profile and show detail
                        Task {
                            if let profile = await socialService.fetchProfile(userId: connection.connectedUserId) {
                                selectedProfile = profile
                            }
                        }
                    },
                    onCompare: {
                        // Navigate to comparison view
                    },
                    onChangeLevel: { newLevel in
                        handleLevelChange(connection: connection, newLevel: newLevel)
                    },
                    onRemove: {
                        Task {
                            try? await socialService.removeConnection(connection.id)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: selectedFilter != nil ? "person.2.slash" : "person.3")
                .font(.system(size: 48))
                .foregroundColor(OnLifeColors.textMuted)

            VStack(spacing: Spacing.sm) {
                Text(selectedFilter != nil ? "No \(selectedFilter!.rawValue)s yet" : "No connections yet")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(selectedFilter != nil
                     ? "Upgrade existing connections or add new friends"
                     : "Start building your flow community")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showingAddFriend = true }) {
                Text("Add Friends")
                    .font(OnLifeFont.button())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(
                        Capsule()
                            .fill(OnLifeColors.socialTeal)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }

    // MARK: - Helpers

    private func levelColor(_ level: ConnectionLevel) -> Color {
        switch level {
        case .observer: return OnLifeColors.textTertiary
        case .friend: return OnLifeColors.socialTeal
        case .flowPartner: return OnLifeColors.amber
        case .mentor: return Color(hex: "7B68EE")
        }
    }

    private func handleLevelChange(connection: Connection, newLevel: ConnectionLevel) {
        // Check if we're at the limit for the new level
        if let limit = newLevel.limit {
            let currentCount = connectionCount(for: newLevel)
            if currentCount >= limit {
                limitAlertLevel = newLevel
                showingLimitAlert = true
                return
            }
        }

        Task {
            try? await socialService.updateConnectionLevel(connection.id, newLevel: newLevel)
        }
    }

    private func limitAlertMessage(for level: ConnectionLevel) -> String {
        switch level {
        case .flowPartner:
            return "You've reached the limit of 5 Flow Partners. Research shows we can only maintain about 5 truly close relationships. Consider your existing partners carefully."
        case .mentor:
            return "You've reached the limit of 2 Mentors. Deep mentorship requires significant time investment from both sides."
        case .friend:
            return "You've reached the limit of 150 Friends. This is based on Dunbar's number - the cognitive limit on meaningful social relationships."
        default:
            return "You've reached the limit for this connection type."
        }
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let connection: Connection
    let onTap: () -> Void
    let onCompare: () -> Void
    let onChangeLevel: (ConnectionLevel) -> Void
    let onRemove: () -> Void

    @State private var profile: UserProfile?
    @State private var showingOptions = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Avatar
                if let profile = profile {
                    UserAvatarView(profile: profile, size: 50, showBadge: true)
                } else {
                    Circle()
                        .fill(OnLifeColors.cardBackgroundElevated)
                        .frame(width: 50, height: 50)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    if let profile = profile {
                        Text(profile.displayName ?? profile.username)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textPrimary)

                        // Mini trajectory
                        HStack(spacing: Spacing.sm) {
                            HStack(spacing: 2) {
                                Image(systemName: profile.thirtyDayTrajectory >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 10))

                                Text("\(Int(abs(profile.thirtyDayTrajectory)))%")
                                    .font(OnLifeFont.caption())
                            }
                            .foregroundColor(profile.thirtyDayTrajectory >= 0 ? OnLifeColors.socialTeal : OnLifeColors.warning)

                            Text("•")
                                .foregroundColor(OnLifeColors.textMuted)

                            Text("\(profile.gardenAgeDays)d garden")
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textTertiary)
                        }
                    } else {
                        Text("Loading...")
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                }

                Spacer()

                // Level badge
                levelBadge(connection.level)

                // More options
                Button(action: { showingOptions = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(OnLifeColors.textTertiary)
                        .padding(Spacing.sm)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .task {
            profile = await SocialService.shared.fetchProfile(userId: connection.connectedUserId)
        }
        .confirmationDialog("Connection Options", isPresented: $showingOptions) {
            Button("Compare Progress") {
                onCompare()
            }

            if connection.level != .flowPartner {
                Button("Upgrade to Flow Partner") {
                    onChangeLevel(.flowPartner)
                }
            }

            if connection.level != .friend && connection.level != .flowPartner {
                Button("Add as Friend") {
                    onChangeLevel(.friend)
                }
            }

            Button("Remove Connection", role: .destructive) {
                onRemove()
            }

            Button("Cancel", role: .cancel) {}
        }
    }

    private func levelBadge(_ level: ConnectionLevel) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: level.icon)
                .font(.system(size: 10))
        }
        .foregroundColor(levelColor(level))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(levelColor(level).opacity(0.15))
        )
    }

    private func levelColor(_ level: ConnectionLevel) -> Color {
        switch level {
        case .observer: return OnLifeColors.textTertiary
        case .friend: return OnLifeColors.socialTeal
        case .flowPartner: return OnLifeColors.amber
        case .mentor: return Color(hex: "7B68EE")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FriendsListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FriendsListView(
                currentUserId: "me",
                currentUsername: "flowmaster",
                onPhilosophyTap: { _ in }
            )
        }
        .preferredColorScheme(.dark)
    }
}
#endif
