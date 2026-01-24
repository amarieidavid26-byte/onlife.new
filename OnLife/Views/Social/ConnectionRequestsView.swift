import SwiftUI

// MARK: - Connection Requests View

struct ConnectionRequestsView: View {
    let currentUserId: String
    let onPhilosophyTap: (PhilosophyMoment) -> Void

    @StateObject private var socialService = SocialService.shared
    @State private var selectedRequest: ConnectionRequest?
    @State private var showingDeclineConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Incoming requests
                if !incomingRequests.isEmpty {
                    incomingSection
                }

                // Outgoing requests
                if !outgoingRequests.isEmpty {
                    outgoingSection
                }

                // Empty state
                if incomingRequests.isEmpty && outgoingRequests.isEmpty {
                    emptyStateView
                }
            }
            .padding(Spacing.lg)
        }
        .background(OnLifeColors.deepForest.ignoresSafeArea())
        .navigationTitle("Connection Requests")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await socialService.loadPendingRequests()
        }
        .confirmationDialog(
            "Decline Request",
            isPresented: $showingDeclineConfirm,
            titleVisibility: .visible
        ) {
            Button("Decline", role: .destructive) {
                if let request = selectedRequest {
                    Task {
                        try? await socialService.respondToRequest(request.id, accept: false)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to decline this connection request?")
        }
    }

    // MARK: - Data

    private var incomingRequests: [ConnectionRequest] {
        socialService.pendingRequests.filter { $0.toUserId == currentUserId }
    }

    private var outgoingRequests: [ConnectionRequest] {
        socialService.pendingRequests.filter { $0.fromUserId == currentUserId }
    }

    // MARK: - Incoming Section

    private var incomingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Incoming")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                // Count badge
                Text("\(incomingRequests.count)")
                    .font(OnLifeFont.labelSmall())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(OnLifeColors.socialTeal)
                    )

                Spacer()
            }

            ForEach(incomingRequests) { request in
                IncomingRequestCard(
                    request: request,
                    onAccept: { _ in
                        Task {
                            try? await socialService.respondToRequest(request.id, accept: true)
                        }
                    },
                    onDecline: {
                        selectedRequest = request
                        showingDeclineConfirm = true
                    },
                    onPhilosophyTap: onPhilosophyTap
                )
            }
        }
    }

    // MARK: - Outgoing Section

    private var outgoingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Sent")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("\(outgoingRequests.count)")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)

                Spacer()
            }

            ForEach(outgoingRequests) { request in
                OutgoingRequestCard(
                    request: request,
                    onCancel: {
                        Task {
                            try? await socialService.cancelRequest(request.id)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(OnLifeColors.textMuted)

            VStack(spacing: Spacing.sm) {
                Text("No pending requests")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Connection requests will appear here")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }
}

// MARK: - Incoming Request Card

struct IncomingRequestCard: View {
    let request: ConnectionRequest
    let onAccept: (ConnectionLevel) -> Void
    let onDecline: () -> Void
    let onPhilosophyTap: (PhilosophyMoment) -> Void

    @State private var showingLevelOptions = false
    @State private var senderProfile: UserProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // User info row
            HStack(spacing: Spacing.md) {
                if let profile = senderProfile {
                    UserAvatarView(profile: profile, size: 50)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.displayName)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textPrimary)

                        Text("@\(profile.username)")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)

                        // Mini flow portrait
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: profile.chronotype.icon)
                                .font(.system(size: 10))

                            Text("\(profile.chronotype.rawValue)")
                                .font(OnLifeFont.caption())

                            Text("•")

                            HStack(spacing: 2) {
                                Image(systemName: profile.thirtyDayTrajectory >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 8))

                                Text("\(Int(abs(profile.thirtyDayTrajectory)))%")
                                    .font(OnLifeFont.caption())
                            }
                            .foregroundColor(profile.thirtyDayTrajectory >= 0 ? OnLifeColors.socialTeal : OnLifeColors.warning)
                        }
                        .foregroundColor(OnLifeColors.textTertiary)
                    }
                } else {
                    // Loading placeholder
                    Circle()
                        .fill(OnLifeColors.cardBackgroundElevated)
                        .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(OnLifeColors.cardBackgroundElevated)
                            .frame(width: 120, height: 16)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(OnLifeColors.cardBackgroundElevated)
                            .frame(width: 80, height: 12)
                    }
                }

                Spacer()

                // Requested level badge
                requestedLevelBadge
            }

            // Message (if any)
            if let message = request.message, !message.isEmpty {
                Text("\"\(message)\"")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .italic()
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            .fill(OnLifeColors.cardBackgroundElevated)
                    )
            }

            // Action buttons
            HStack(spacing: Spacing.md) {
                // Decline button
                Button(action: onDecline) {
                    Text("Decline")
                        .font(OnLifeFont.button())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                .stroke(OnLifeColors.textMuted, lineWidth: 1)
                        )
                }

                // Accept button
                Button(action: {
                    showingLevelOptions = true
                    HapticManager.shared.impact(style: .medium)
                }) {
                    Text("Accept")
                        .font(OnLifeFont.button())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                .fill(OnLifeColors.socialTeal)
                        )
                }
            }

            // Time ago
            Text(timeAgo(request.createdAt))
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textMuted)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .task {
            senderProfile = await SocialService.shared.fetchProfile(userId: request.fromUserId)
        }
        .sheet(isPresented: $showingLevelOptions) {
            ConnectionLevelPicker(
                requestedLevel: request.requestedLevel,
                onSelect: { level in
                    onAccept(level)
                    showingLevelOptions = false
                },
                onCancel: { showingLevelOptions = false },
                onPhilosophyTap: onPhilosophyTap
            )
            .presentationDetents([.medium])
        }
    }

    private var requestedLevelBadge: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: request.requestedLevel.icon)
                .font(.system(size: 10))

            Text("as \(request.requestedLevel.rawValue)")
                .font(OnLifeFont.labelSmall())
        }
        .foregroundColor(levelColor(request.requestedLevel))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(levelColor(request.requestedLevel).opacity(0.15))
        )
    }

    private func levelColor(_ level: ConnectionLevel) -> Color {
        switch level {
        case .observer: return OnLifeColors.textTertiary
        case .friend: return OnLifeColors.socialTeal
        case .flowPartner: return OnLifeColors.amber
        case .mentor, .mentee: return Color(hex: "7B68EE")
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Outgoing Request Card

struct OutgoingRequestCard: View {
    let request: ConnectionRequest
    let onCancel: () -> Void

    @State private var recipientProfile: UserProfile?

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let profile = recipientProfile {
                UserAvatarView(profile: profile, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))

                        Text("Pending • \(timeAgo(request.createdAt))")
                            .font(OnLifeFont.caption())
                    }
                    .foregroundColor(OnLifeColors.textTertiary)
                }
            } else {
                Circle()
                    .fill(OnLifeColors.cardBackgroundElevated)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.cardBackgroundElevated)
                        .frame(width: 100, height: 14)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.cardBackgroundElevated)
                        .frame(width: 60, height: 10)
                }
            }

            Spacer()

            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.error)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .task {
            recipientProfile = await SocialService.shared.fetchProfile(userId: request.toUserId)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Connection Level Picker

struct ConnectionLevelPicker: View {
    let requestedLevel: ConnectionLevel
    let onSelect: (ConnectionLevel) -> Void
    let onCancel: () -> Void
    let onPhilosophyTap: (PhilosophyMoment) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.lg) {
                // Header
                VStack(spacing: Spacing.sm) {
                    Text("Choose Connection Level")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    HStack(spacing: Spacing.xs) {
                        Text("They requested:")
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textTertiary)

                        Text(requestedLevel.rawValue)
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(levelColor(requestedLevel))
                    }
                }

                // Level options
                VStack(spacing: Spacing.md) {
                    ForEach([ConnectionLevel.observer, .friend, .flowPartner], id: \.self) { level in
                        levelOptionCard(level)
                    }
                }

                // Philosophy link
                Button(action: {
                    onPhilosophyTap(PhilosophyMomentsLibrary.dunbarNumber)
                }) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(OnLifeColors.amber)

                        Text("Why we have connection limits")
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(Spacing.lg)
            .background(OnLifeColors.deepForest.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(OnLifeColors.textSecondary)
                }
            }
        }
    }

    private func levelOptionCard(_ level: ConnectionLevel) -> some View {
        Button(action: {
            onSelect(level)
            HapticManager.shared.impact(style: .medium)
        }) {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(levelColor(level).opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: level.icon)
                        .font(.system(size: 18))
                        .foregroundColor(levelColor(level))
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(level.rawValue)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textPrimary)

                        if level == requestedLevel {
                            Text("Requested")
                                .font(OnLifeFont.labelSmall())
                                .foregroundColor(OnLifeColors.socialTeal)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(OnLifeColors.socialTeal.opacity(0.15))
                                )
                        }
                    }

                    Text(levelDescription(level))
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                        .lineLimit(2)
                }

                Spacer()

                // Limit indicator
                if level.maxAllowed != nil {
                    Text("Limited")
                        .font(OnLifeFont.labelSmall())
                        .foregroundColor(OnLifeColors.warning)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(OnLifeColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(level == requestedLevel ? levelColor(level).opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
        }
    }

    private func levelColor(_ level: ConnectionLevel) -> Color {
        switch level {
        case .observer: return OnLifeColors.textTertiary
        case .friend: return OnLifeColors.socialTeal
        case .flowPartner: return OnLifeColors.amber
        case .mentor, .mentee: return Color(hex: "7B68EE")
        }
    }

    private func levelDescription(_ level: ConnectionLevel) -> String {
        switch level {
        case .observer: return "See their public progress. No limit."
        case .friend: return "See detailed stats and compare. Limit: 150"
        case .flowPartner: return "Deep sharing, co-working, mentorship. Limit: 5"
        case .mentor: return "Guide and be guided. Limit: 2"
        case .mentee: return "Be guided by a mentor. Limit: 10"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ConnectionRequestsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConnectionRequestsView(
                currentUserId: "me",
                onPhilosophyTap: { _ in }
            )
        }
        .preferredColorScheme(.dark)
    }
}
#endif
