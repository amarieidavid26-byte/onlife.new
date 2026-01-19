import SwiftUI

/// Card displaying behavioral flow readiness for users without Apple Watch
struct BehavioralFlowCard: View {
    let assessment: BehavioralFlowDetector.ReadinessAssessment
    let features: BehavioralFeatures
    @State private var contentAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(assessment.level.color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: assessment.level.icon)
                        .font(.system(size: 20))
                        .foregroundColor(assessment.level.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Flow Readiness")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Behavioral analysis")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                Spacer()

                // Score display
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(assessment.flowProbability))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(assessment.level.color)

                    Text(assessment.level.rawValue)
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 10)

            // Recommendation
            HStack(spacing: Spacing.sm) {
                Text(assessment.level.emoji)
                    .font(.system(size: 20))

                Text(assessment.recommendation)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(assessment.level.color.opacity(0.1))
            )
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 10)
            .animation(OnLifeAnimation.elegant.delay(0.05), value: contentAppeared)

            // Key metrics
            VStack(spacing: Spacing.sm) {
                if features.completionRateLast7Days > 0 {
                    BehavioralMetricRow(
                        icon: "target",
                        label: "Completion Rate (7d)",
                        value: "\(Int(features.completionRateLast7Days * 100))%",
                        isPositive: features.completionRateLast7Days >= 0.7
                    )
                }

                if features.consecutiveDays > 0 {
                    BehavioralMetricRow(
                        icon: "flame.fill",
                        label: "Active Streak",
                        value: "\(features.consecutiveDays) day\(features.consecutiveDays == 1 ? "" : "s")",
                        isPositive: true
                    )
                }

                if features.sessionCountToday > 0 {
                    BehavioralMetricRow(
                        icon: "checkmark.circle",
                        label: "Sessions Today",
                        value: "\(features.sessionCountToday)",
                        isPositive: features.sessionCountToday < 4
                    )
                }

                if features.avgFlowScoreLast7Days > 0 {
                    BehavioralMetricRow(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "Avg Flow (7d)",
                        value: "\(Int(features.avgFlowScoreLast7Days))",
                        isPositive: features.avgFlowScoreLast7Days >= 60
                    )
                }

                if features.sameTimeOfDayAsUsual {
                    BehavioralMetricRow(
                        icon: "clock.badge.checkmark",
                        label: "Routine Time",
                        value: "Yes",
                        isPositive: true
                    )
                }
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 10)
            .animation(OnLifeAnimation.elegant.delay(0.1), value: contentAppeared)

            // Success factors (if any significant ones)
            if !assessment.factors.isEmpty {
                Divider()
                    .background(OnLifeColors.textTertiary.opacity(0.3))

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Factors")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)

                    ForEach(assessment.factors.prefix(3), id: \.description) { factor in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: factor.icon)
                                .font(.system(size: 12))
                                .foregroundColor(factor.impact.color)
                                .frame(width: 16)

                            Text(factor.description)
                                .font(OnLifeFont.caption())
                                .foregroundColor(factor.impact.color)
                        }
                    }
                }
                .opacity(contentAppeared ? 1 : 0)
                .animation(OnLifeAnimation.elegant.delay(0.15), value: contentAppeared)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .shadow(
            color: assessment.level.color.opacity(0.15),
            radius: 12,
            y: 4
        )
        .onAppear {
            withAnimation(OnLifeAnimation.elegant) {
                contentAppeared = true
            }
        }
    }
}

// MARK: - Behavioral Metric Row

struct BehavioralMetricRow: View {
    let icon: String
    let label: String
    let value: String
    let isPositive: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isPositive ? OnLifeColors.sage : OnLifeColors.amber)
                .frame(width: 20)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)

            Spacer()

            Text(value)
                .font(OnLifeFont.bodySmall())
                .fontWeight(.medium)
                .foregroundColor(isPositive ? OnLifeColors.sage : OnLifeColors.amber)
        }
    }
}

// MARK: - Compact Version for Home

struct BehavioralFlowCompactCard: View {
    let assessment: BehavioralFlowDetector.ReadinessAssessment
    @State private var appeared = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(assessment.level.color.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: assessment.level.icon)
                    .font(.system(size: 22))
                    .foregroundColor(assessment.level.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.sm) {
                    Text("Flow Readiness")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)

                    Text(assessment.level.emoji)
                        .font(.system(size: 14))
                }

                Text(assessment.recommendation)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .lineLimit(2)
            }

            Spacer()

            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(assessment.flowProbability))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(assessment.level.color)

                Text(assessment.level.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(OnLifeAnimation.elegant) {
                appeared = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Create sample features with properties set
    var sampleFeatures = BehavioralFeatures()
    sampleFeatures.completionRateLast7Days = 0.85
    sampleFeatures.avgFlowScoreLast7Days = 68
    sampleFeatures.sameTimeOfDayAsUsual = true
    sampleFeatures.consecutiveDays = 5
    sampleFeatures.sessionCountToday = 2

    return ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                BehavioralFlowCard(
                    assessment: BehavioralFlowDetector.ReadinessAssessment(
                        level: .good,
                        flowProbability: 72,
                        successProbability: 0.75,
                        recommendation: "Good focus potential. You're ready for focused work.",
                        factors: [
                            BehavioralFlowDetector.SuccessFactor(
                                description: "Strong completion history",
                                impact: .positive,
                                icon: "checkmark.seal.fill"
                            ),
                            BehavioralFlowDetector.SuccessFactor(
                                description: "Active streak momentum",
                                impact: .positive,
                                icon: "flame.fill"
                            )
                        ]
                    ),
                    features: sampleFeatures
                )

                BehavioralFlowCompactCard(
                    assessment: BehavioralFlowDetector.ReadinessAssessment(
                        level: .excellent,
                        flowProbability: 85,
                        successProbability: 0.9,
                        recommendation: "Excellent conditions for deep work!",
                        factors: []
                    )
                )
            }
            .padding()
        }
    }
}
