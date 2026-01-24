import SwiftUI

// MARK: - User Search Result Card

struct UserSearchResultCard: View {
    let profile: UserProfile
    let existingConnection: Connection?
    let pendingRequest: ConnectionRequest?
    let onConnect: (ConnectionLevel) -> Void
    let onViewProfile: () -> Void

    @State private var showingConnectionOptions = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            UserAvatarView(
                profile: profile,
                size: 50
            )

            // User info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(profile.displayName)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    // Verified badge for high consistency users
                    if profile.consistencyPercentile >= 90 {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(OnLifeColors.socialTeal)
                    }
                }

                Text("@\(profile.username)")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)

                // Mini stats
                HStack(spacing: Spacing.sm) {
                    miniStat(icon: profile.chronotype.sfSymbol, value: profile.chronotype.shortName)

                    if profile.thirtyDayTrajectory != 0 {
                        miniStat(
                            icon: profile.thirtyDayTrajectory >= 0 ? "arrow.up.right" : "arrow.down.right",
                            value: "\(profile.thirtyDayTrajectory >= 0 ? "+" : "")\(Int(profile.thirtyDayTrajectory))%"
                        )
                    }
                }
            }

            Spacer()

            // Action button
            connectionActionButton
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .onTapGesture {
            onViewProfile()
        }
        .confirmationDialog(
            "Connect with \(profile.displayName)",
            isPresented: $showingConnectionOptions,
            titleVisibility: .visible
        ) {
            Button("Add as Observer") {
                onConnect(.observer)
            }

            Button("Add as Friend") {
                onConnect(.friend)
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how you'd like to connect")
        }
    }

    // MARK: - Mini Stat

    private func miniStat(icon: String, value: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))

            Text(value)
                .font(OnLifeFont.labelSmall())
        }
        .foregroundColor(OnLifeColors.textTertiary)
    }

    // MARK: - Connection Action Button

    @ViewBuilder
    private var connectionActionButton: some View {
        if let connection = existingConnection {
            // Already connected
            connectionLevelBadge(connection.level)
        } else if let request = pendingRequest {
            // Pending request
            pendingBadge(request)
        } else {
            // Can connect
            Button(action: {
                showingConnectionOptions = true
                HapticManager.shared.impact(style: .light)
            }) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14))

                    Text("Connect")
                        .font(OnLifeFont.label())
                }
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(OnLifeColors.socialTeal)
                )
            }
        }
    }

    private func connectionLevelBadge(_ level: ConnectionLevel) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: level.icon)
                .font(.system(size: 12))

            Text(level.rawValue)
                .font(OnLifeFont.labelSmall())
        }
        .foregroundColor(levelColor(level))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(levelColor(level).opacity(0.15))
        )
    }

    private func pendingBadge(_ request: ConnectionRequest) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "clock")
                .font(.system(size: 12))

            Text(request.fromUserId == profile.id ? "Requested" : "Pending")
                .font(OnLifeFont.labelSmall())
        }
        .foregroundColor(OnLifeColors.warning)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(OnLifeColors.warning.opacity(0.15))
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
}

// MARK: - User Avatar View

struct UserAvatarView: View {
    let profile: UserProfile
    let size: CGFloat
    var showBadge: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Avatar circle
            Circle()
                .fill(avatarGradient)
                .frame(width: size, height: size)
                .overlay(
                    Text(initials)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(.white)
                )

            // Online/status badge
            if showBadge {
                Circle()
                    .fill(OnLifeColors.healthy)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay(
                        Circle()
                            .stroke(OnLifeColors.cardBackground, lineWidth: 2)
                    )
            }
        }
    }

    private var initials: String {
        let name = profile.displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var avatarGradient: LinearGradient {
        // Generate consistent color based on user ID
        let hash = abs(profile.id.hashValue)
        let hue = Double(hash % 360) / 360.0

        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.6, brightness: 0.7),
                Color(hue: hue, saturation: 0.7, brightness: 0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - User Search Result Compact

struct UserSearchResultCompact: View {
    let profile: UserProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                UserAvatarView(profile: profile, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("@\(profile.username)")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(OnLifeColors.textTertiary)
            }
            .padding(Spacing.sm)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct UserSearchResultCard_Previews: PreviewProvider {
    static let sampleProfile = UserProfile(
        id: "user1",
        username: "sarahflows",
        displayName: "Sarah Chen",
        chronotype: .moderateMorning,
        gardenAgeDays: 90,
        thirtyDayTrajectory: 23,
        consistencyPercentile: 85,
        totalPlantsGrown: 45,
        speciesUnlocked: 12
    )

    static var previews: some View {
        VStack(spacing: Spacing.md) {
            // Not connected
            UserSearchResultCard(
                profile: sampleProfile,
                existingConnection: nil,
                pendingRequest: nil,
                onConnect: { _ in },
                onViewProfile: {}
            )

            // Already connected
            UserSearchResultCard(
                profile: sampleProfile,
                existingConnection: Connection(
                    id: "conn1",
                    user1Id: "me",
                    user2Id: "user1",
                    level: .friend,
                    createdAt: Date()
                ),
                pendingRequest: nil,
                onConnect: { _ in },
                onViewProfile: {}
            )

            // Pending request
            UserSearchResultCard(
                profile: sampleProfile,
                existingConnection: nil,
                pendingRequest: ConnectionRequest(
                    id: "req1",
                    fromUserId: "me",
                    toUserId: "user1",
                    requestedLevel: .friend,
                    createdAt: Date()
                ),
                onConnect: { _ in },
                onViewProfile: {}
            )

            // Compact
            UserSearchResultCompact(profile: sampleProfile, onTap: {})
                .padding()
                .background(OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)
        }
        .padding()
        .background(OnLifeColors.deepForest)
        .preferredColorScheme(.dark)
    }
}
#endif
