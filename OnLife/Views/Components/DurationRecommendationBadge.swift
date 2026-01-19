import SwiftUI

/// Shows predicted completion probability for a selected session duration
/// Displays real-time feedback as user adjusts duration in session setup
struct DurationRecommendationBadge: View {
    let requestedDuration: TimeInterval
    let pattern: CompletionPattern?

    var body: some View {
        if let pattern = pattern {
            let (probability, confidence) = CompletionPatternAnalyzer.shared.predictCompletionProbability(
                duration: requestedDuration,
                hourOfDay: Calendar.current.component(.hour, from: Date()),
                pattern: pattern
            )

            HStack(spacing: Spacing.xs) {
                Image(systemName: probabilityIcon(probability))
                    .font(.system(size: 14))
                    .foregroundColor(probabilityColor(probability))

                Text("\(Int(probability * 100))% completion rate")
                    .font(OnLifeFont.caption())
                    .fontWeight(.medium)
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("(\(confidence))")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .fill(probabilityColor(probability).opacity(0.15))
            )
        }
    }

    private func probabilityIcon(_ probability: Double) -> String {
        switch probability {
        case 0.8...1.0: return "checkmark.circle.fill"
        case 0.6..<0.8: return "checkmark.circle"
        case 0.4..<0.6: return "exclamationmark.circle"
        default: return "xmark.circle"
        }
    }

    private func probabilityColor(_ probability: Double) -> Color {
        switch probability {
        case 0.8...1.0: return OnLifeColors.sage
        case 0.6..<0.8: return OnLifeColors.amber
        case 0.4..<0.6: return OnLifeColors.terracotta.opacity(0.8)
        default: return OnLifeColors.terracotta
        }
    }
}

/// Expanded recommendation view with suggestion text
struct DurationRecommendationView: View {
    let requestedDuration: TimeInterval
    let pattern: CompletionPattern?

    var body: some View {
        if let pattern = pattern {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                DurationRecommendationBadge(
                    requestedDuration: requestedDuration,
                    pattern: pattern
                )

                Text(CompletionPatternAnalyzer.shared.generateRecommendation(
                    requestedDuration: requestedDuration,
                    pattern: pattern
                ))
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
        }
    }
}

/// Compact inline badge showing sweet spot alignment
struct SweetSpotIndicator: View {
    let selectedDuration: Int
    let pattern: CompletionPattern?

    var body: some View {
        if let pattern = pattern {
            let optimalMinutes = Int(pattern.optimalDuration / 60)
            let isInSweetSpot = abs(selectedDuration - optimalMinutes) <= 5

            if isInSweetSpot {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))

                    Text("Sweet spot")
                        .font(OnLifeFont.caption())
                        .fontWeight(.medium)
                }
                .foregroundColor(OnLifeColors.sage)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(OnLifeColors.sage.opacity(0.15))
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let mockPattern = CompletionPattern(
        optimalDuration: 30 * 60,
        optimalHourOfDay: 9,
        completionRateByDuration: [
            .short: 0.85,
            .medium: 0.72,
            .long: 0.60,
            .extended: 0.45
        ],
        completionRateByHour: [9: 0.88],
        totalSessions: 45,
        overallCompletionRate: 0.72,
        confidence: 0.45
    )

    return ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        VStack(spacing: Spacing.xl) {
            Text("Badge Variants")
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)

            // High probability (30 min - in sweet spot)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("30 min (Sweet Spot)")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                DurationRecommendationBadge(
                    requestedDuration: 30 * 60,
                    pattern: mockPattern
                )
            }

            // Medium probability (45 min)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("45 min")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                DurationRecommendationBadge(
                    requestedDuration: 45 * 60,
                    pattern: mockPattern
                )
            }

            // Lower probability (75 min)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("75 min")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                DurationRecommendationBadge(
                    requestedDuration: 75 * 60,
                    pattern: mockPattern
                )
            }

            Divider()
                .background(OnLifeColors.textTertiary.opacity(0.3))

            // Full recommendation view
            Text("Full Recommendation")
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            DurationRecommendationView(
                requestedDuration: 45 * 60,
                pattern: mockPattern
            )

            // Sweet spot indicator
            HStack {
                SweetSpotIndicator(selectedDuration: 30, pattern: mockPattern)
                SweetSpotIndicator(selectedDuration: 60, pattern: mockPattern)
            }
        }
        .padding()
    }
}
