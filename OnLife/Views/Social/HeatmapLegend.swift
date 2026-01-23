import SwiftUI

// MARK: - Heatmap Legend

struct HeatmapLegend: View {
    let onPhilosophyTap: () -> Void
    let cellSize: CGFloat

    @State private var showingExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                Text("Legend")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)

                PhilosophyButton(action: onPhilosophyTap)

                Spacer()

                Button(action: { withAnimation { showingExplanation.toggle() } }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(OnLifeColors.textMuted)
                }
            }

            // Legend items
            HStack(spacing: Spacing.md) {
                legendItem(intensity: .none, label: "No session")
                legendItem(intensity: .activityOnly, label: "Session")

                Spacer()

                // Flow gradient
                HStack(spacing: 2) {
                    Text("Flow")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)

                    HStack(spacing: 2) {
                        HeatmapDayCellCompact(intensity: .lightFlow, size: cellSize)
                        HeatmapDayCellCompact(intensity: .moderateFlow, size: cellSize)
                        HeatmapDayCellCompact(intensity: .deepFlow, size: cellSize)
                    }

                    Text("Deep")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            // Explanation (expandable)
            if showingExplanation {
                explanationCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Legend Item

    private func legendItem(intensity: HeatmapIntensity, label: String) -> some View {
        HStack(spacing: Spacing.xs) {
            HeatmapDayCellCompact(intensity: intensity, size: cellSize)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
    }

    // MARK: - Explanation Card

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Why we show flow, not just activity")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)

            Text("Time spent doesn't equal skill gained. Research shows that flow state practice is 2-5x more effective for skill development than regular practice.")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
                .lineSpacing(2)

            HStack(spacing: Spacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12))
                    .foregroundColor(OnLifeColors.socialTeal)

                Text("We measure what matters: quality over quantity")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.socialTeal)
                    .italic()
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackgroundElevated)
        )
    }
}

// MARK: - Compact Legend

struct HeatmapLegendCompact: View {
    let cellSize: CGFloat

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("Less")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textMuted)

            HStack(spacing: 2) {
                ForEach(HeatmapIntensity.allCases, id: \.rawValue) { intensity in
                    HeatmapDayCellCompact(intensity: intensity, size: cellSize)
                }
            }

            Text("More Flow")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textMuted)
        }
    }
}

// MARK: - Heatmap Stats Card

struct HeatmapStatsCard: View {
    let stats: HeatmapStats

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Main stats row
            HStack(spacing: Spacing.lg) {
                statItem(
                    value: "\(stats.currentStreak)",
                    label: "Current Streak",
                    icon: "flame.fill",
                    color: stats.currentStreak > 0 ? OnLifeColors.amber : OnLifeColors.textMuted
                )

                Divider()
                    .frame(height: 40)
                    .background(OnLifeColors.textMuted.opacity(0.3))

                statItem(
                    value: "\(stats.longestStreak)",
                    label: "Longest Streak",
                    icon: "trophy.fill",
                    color: OnLifeColors.healthy
                )

                Divider()
                    .frame(height: 40)
                    .background(OnLifeColors.textMuted.opacity(0.3))

                statItem(
                    value: "\(Int(stats.flowRate * 100))%",
                    label: "Flow Rate",
                    icon: "sparkles",
                    color: OnLifeColors.socialTeal
                )
            }

            // Secondary stats
            HStack(spacing: Spacing.xl) {
                secondaryStat(label: "Active Days", value: "\(stats.activeDays)")
                secondaryStat(label: "Flow Days", value: "\(stats.flowDays)")

                if let avgQuality = stats.averageFlowQuality {
                    secondaryStat(label: "Avg Quality", value: "\(Int(avgQuality * 100))%")
                }

                Spacer()
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Stat Item

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)

                Text(value)
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
    }

    private func secondaryStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textMuted)
        }
    }
}

// MARK: - Month Summary Card

struct HeatmapMonthSummary: View {
    let month: HeatmapMonth

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Month name
            Text(month.shortName)
                .font(OnLifeFont.label())
                .foregroundColor(OnLifeColors.textTertiary)
                .frame(width: 40, alignment: .leading)

            // Mini heatmap row
            HStack(spacing: 2) {
                ForEach(month.weeks.flatMap { $0.days }.prefix(31)) { day in
                    HeatmapDayCellCompact(intensity: day.intensityLevel, size: 8)
                }
            }

            Spacer()

            // Flow days count
            HStack(spacing: Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))

                Text("\(month.totalFlowDays)")
                    .font(OnLifeFont.labelSmall())
            }
            .foregroundColor(OnLifeColors.socialTeal)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HeatmapLegend_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.xl) {
            // Full legend
            HeatmapLegend(
                onPhilosophyTap: {},
                cellSize: 12
            )

            // Compact legend
            HeatmapLegendCompact(cellSize: 12)

            // Stats card
            HeatmapStatsCard(
                stats: HeatmapStats(
                    totalDays: 365,
                    activeDays: 180,
                    flowDays: 120,
                    currentStreak: 7,
                    longestStreak: 23,
                    averageFlowQuality: 0.72
                )
            )

            // Month summary
            HeatmapMonthSummary(
                month: HeatmapMonth(
                    id: "2024-1",
                    month: 1,
                    year: 2024,
                    weeks: []
                )
            )
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
