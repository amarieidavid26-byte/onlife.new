import SwiftUI

// MARK: - Comparison Insight Type

enum ComparisonInsightType {
    case learningOpportunity    // They're doing something you could try
    case celebration            // You're doing great
    case contextual             // Important context about the comparison
    case actionable             // Specific action to take

    var icon: String {
        switch self {
        case .learningOpportunity: return "lightbulb.fill"
        case .celebration: return "star.fill"
        case .contextual: return "info.circle.fill"
        case .actionable: return "arrow.right.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .learningOpportunity: return OnLifeColors.amber
        case .celebration: return OnLifeColors.healthy
        case .contextual: return OnLifeColors.socialTeal
        case .actionable: return Color(hex: "7B68EE") // Purple
        }
    }
}

// MARK: - Comparison Insight

struct ComparisonInsight: Identifiable {
    let id = UUID()
    let type: ComparisonInsightType
    let title: String
    let body: String
    let action: ComparisonInsightAction?

    struct ComparisonInsightAction {
        let label: String
        let destination: InsightActionDestination
    }

    enum InsightActionDestination {
        case flowProtocol(id: String)
        case profile(userId: String)
        case settings
        case philosophyMoment(PhilosophyMoment)
    }
}

// MARK: - Comparison Insight Card

struct ComparisonInsightCard: View {
    let insight: ComparisonInsight
    let onActionTap: ((ComparisonInsight.InsightActionDestination) -> Void)?
    let onDismiss: (() -> Void)?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack(alignment: .top, spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(insight.type.color.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: insight.type.icon)
                        .font(.system(size: 16))
                        .foregroundColor(insight.type.color)
                }

                // Content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(insight.title)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(insight.body)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Dismiss button (if available)
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                }
            }

            // Expand/collapse for long text
            if insight.body.count > 100 && !isExpanded {
                Button(action: { withAnimation { isExpanded = true } }) {
                    Text("Read more")
                        .font(OnLifeFont.label())
                        .foregroundColor(insight.type.color)
                }
            }

            // Action button (if available)
            if let action = insight.action {
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onActionTap?(action.destination)
                }) {
                    HStack(spacing: Spacing.sm) {
                        Text(action.label)
                            .font(OnLifeFont.button())

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(OnLifeColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(insight.type.color)
                    )
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .stroke(insight.type.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Compact Insight Chip

struct ComparisonInsightChip: View {
    let insight: ComparisonInsight
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: insight.type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(insight.type.color)

                Text(insight.title)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(insight.type.color.opacity(0.1))
            )
        }
    }
}

// MARK: - Insights Stack

struct ComparisonInsightsStack: View {
    let insights: [ComparisonInsight]
    let onActionTap: (ComparisonInsight.InsightActionDestination) -> Void
    let onPhilosophyTap: () -> Void

    @State private var dismissedInsights: Set<UUID> = []

    private var visibleInsights: [ComparisonInsight] {
        insights.filter { !dismissedInsights.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                Text("Insights")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                PhilosophyButton(action: onPhilosophyTap)

                Spacer()

                Text("\(visibleInsights.count) actionable")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            if visibleInsights.isEmpty {
                emptyState
            } else {
                // Insight cards
                ForEach(visibleInsights) { insight in
                    ComparisonInsightCard(
                        insight: insight,
                        onActionTap: onActionTap,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                _ = dismissedInsights.insert(insight.id)
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(OnLifeColors.healthy)

            VStack(alignment: .leading, spacing: 2) {
                Text("All caught up!")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("No new insights right now")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }
}

// MARK: - Context Banner

struct ComparisonContextBanner: View {
    let context: String
    let icon: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(OnLifeColors.socialTeal)

            Text(context)
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textSecondary)

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.socialTeal.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(OnLifeColors.socialTeal.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ComparisonInsightCard_Previews: PreviewProvider {
    static let sampleInsights = [
        ComparisonInsight(
            type: .learningOpportunity,
            title: "Sarah uses a 90-minute timer",
            body: "Her protocol includes a fixed 90-minute block which matches the brain's natural ultradian rhythm. This could explain her 11% higher deep work scores.",
            action: .init(
                label: "View her protocol",
                destination: .flowProtocol(id: "123")
            )
        ),
        ComparisonInsight(
            type: .contextual,
            title: "They've trained 4 months longer",
            body: "Sarah has been using OnLife for 4 months longer than you. At your current trajectory, you'll reach her level in approximately 6 weeks.",
            action: nil
        ),
        ComparisonInsight(
            type: .celebration,
            title: "Your morning consistency is exceptional",
            body: "You're in the top 15% for morning session consistency. This is a key predictor of long-term flow skill development.",
            action: nil
        ),
        ComparisonInsight(
            type: .actionable,
            title: "Try her pre-flow ritual",
            body: "Sarah's 5-minute breathing exercise before sessions correlates with 23% faster flow entry. You could add this to your protocol.",
            action: .init(
                label: "Add to my protocol",
                destination: .settings
            )
        )
    ]

    static var previews: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Individual cards
                ForEach(sampleInsights) { insight in
                    ComparisonInsightCard(
                        insight: insight,
                        onActionTap: { _ in },
                        onDismiss: {}
                    )
                }

                Divider()
                    .background(OnLifeColors.textMuted)

                // Insights stack
                ComparisonInsightsStack(
                    insights: sampleInsights,
                    onActionTap: { _ in },
                    onPhilosophyTap: {}
                )

                // Context banner
                ComparisonContextBanner(
                    context: "They've been practicing 4 months longer than you",
                    icon: "clock"
                )

                // Chips
                HStack {
                    ForEach(sampleInsights.prefix(2)) { insight in
                        ComparisonInsightChip(insight: insight, onTap: {})
                    }
                }
            }
            .padding()
        }
        .background(OnLifeColors.deepForest)
        .preferredColorScheme(.dark)
    }
}
#endif
