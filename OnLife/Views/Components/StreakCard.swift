import SwiftUI

/// Displays current streak status with freeze protection info
/// Uses the OnLife design system for consistent styling
struct StreakCard: View {
    @ObservedObject var streakManager = StreakManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header with flame and status
            HStack {
                Text(streakManager.streakData.streakStatus.emoji)
                    .font(.system(size: 36))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Streak")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(streakManager.streakData.streakStatus.label)
                        .font(OnLifeFont.caption())
                        .foregroundColor(streakManager.streakData.streakStatus.color)
                }

                Spacer()

                // Streak count badge
                streakBadge
            }

            // Progress to next milestone
            if let nextMilestone = streakManager.streakData.nextMilestone,
               let daysRemaining = streakManager.streakData.daysToNextMilestone {
                milestoneProgress(next: nextMilestone, daysRemaining: daysRemaining)
            }

            Divider()
                .background(OnLifeColors.textTertiary.opacity(0.3))

            // Streak freezes section
            freezeSection
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Streak Badge

    @ViewBuilder
    private var streakBadge: some View {
        VStack(spacing: 2) {
            Text("\(streakManager.streakData.currentStreak)")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(OnLifeColors.amber)

            Text("day\(streakManager.streakData.currentStreak == 1 ? "" : "s")")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
        }
    }

    // MARK: - Milestone Progress

    @ViewBuilder
    private func milestoneProgress(next: StreakMilestone, daysRemaining: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(next.emoji)
                    .font(.system(size: 16))

                Text("\(daysRemaining) days to \(next.label)")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)

                Spacer()

                // Progress percentage
                let progress = Double(streakManager.streakData.currentStreak) / Double(next.days)
                Text("\(Int(progress * 100))%")
                    .font(OnLifeFont.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.sage)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.textTertiary.opacity(0.2))
                        .frame(height: 6)

                    let progress = Double(streakManager.streakData.currentStreak) / Double(next.days)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [OnLifeColors.amber, OnLifeColors.terracotta],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(1.0, progress), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Freeze Section

    @ViewBuilder
    private var freezeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "snowflake")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)

                Text("Streak Freezes")
                    .font(OnLifeFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                // Freeze count
                HStack(spacing: 4) {
                    ForEach(0..<streakManager.streakData.monthlyFreezeAllowance, id: \.self) { index in
                        Image(systemName: index < streakManager.streakData.freezesAvailable ? "snowflake" : "snowflake")
                            .font(.system(size: 14))
                            .foregroundColor(index < streakManager.streakData.freezesAvailable ? .cyan : OnLifeColors.textTertiary.opacity(0.4))
                    }
                }
            }

            Text("Auto-protects your streak if you miss a day")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)

            if streakManager.streakData.freezesAvailable == 0 {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))

                    Text("Refreshes in \(streakManager.streakData.daysUntilFreezeRefresh) days")
                        .font(OnLifeFont.caption())
                }
                .foregroundColor(OnLifeColors.textTertiary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.cyan.opacity(0.1))
        )
    }
}

// MARK: - Compact Streak Indicator

struct StreakCompactIndicator: View {
    @ObservedObject var streakManager = StreakManager.shared

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(streakManager.streakData.streakStatus.emoji)
                .font(.system(size: 20))

            Text("\(streakManager.streakData.currentStreak)")
                .font(OnLifeFont.heading3())
                .fontWeight(.bold)
                .foregroundColor(OnLifeColors.amber)

            if streakManager.streakData.streakStatus == .atRisk {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(OnLifeColors.warning)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(OnLifeColors.cardBackground)
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                Text("Streak Components")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                StreakCard()

                StreakCompactIndicator()

                Spacer()
            }
            .padding()
        }
    }
}
