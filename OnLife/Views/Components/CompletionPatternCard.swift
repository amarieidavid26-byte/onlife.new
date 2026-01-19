import SwiftUI

/// Displays completion pattern analysis with optimal duration and time recommendations
struct CompletionPatternCard: View {
    let pattern: CompletionPattern?
    let earlyQuitAnalysis: EarlyQuitAnalysis?
    let appeared: Bool

    @State private var cardAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(OnLifeColors.sage.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 20))
                        .foregroundColor(OnLifeColors.sage)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Patterns")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    if let pattern = pattern {
                        Text("\(pattern.totalSessions) sessions analyzed")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                    } else {
                        Text("Complete 30+ sessions to unlock")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }

                Spacer()
            }

            if let pattern = pattern {
                // Sweet Spot Section
                sweetSpotSection(pattern: pattern)

                // Best Time Section
                bestTimeSection(pattern: pattern)

                // Duration Breakdown
                durationBreakdownSection(pattern: pattern)

                // Early Quit Pattern Warning
                if let quitAnalysis = earlyQuitAnalysis, quitAnalysis.hasConsistentPattern {
                    earlyQuitSection(analysis: quitAnalysis)
                }

            } else {
                // Empty State
                emptyStateView
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 20)
        .onAppear {
            withAnimation(OnLifeAnimation.elegant.delay(0.15)) {
                cardAppeared = true
            }
        }
    }

    // MARK: - Sweet Spot Section

    @ViewBuilder
    private func sweetSpotSection(pattern: CompletionPattern) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "target")
                    .font(.system(size: 14))
                    .foregroundColor(OnLifeColors.sage)

                Text("Your Sweet Spot")
                    .font(OnLifeFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.sage)
            }

            HStack {
                Text("\(Int(pattern.optimalDuration / 60)) minutes")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(pattern.overallCompletionRate * 100))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(OnLifeColors.sage)

                    Text("completion")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }

            Text("Sessions around this length have your highest completion rate")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.sage.opacity(0.1))
        )
    }

    // MARK: - Best Time Section

    @ViewBuilder
    private func bestTimeSection(pattern: CompletionPattern) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                    .foregroundColor(OnLifeColors.amber)

                Text("Best Time")
                    .font(OnLifeFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.amber)
            }

            HStack {
                Text(formatHour(pattern.optimalHourOfDay))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                if let hourRate = pattern.completionRateByHour[pattern.optimalHourOfDay] {
                    Text("\(Int(hourRate * 100))% success")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }

            Text("You complete sessions most consistently at this hour")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.amber.opacity(0.1))
        )
    }

    // MARK: - Duration Breakdown Section

    @ViewBuilder
    private func durationBreakdownSection(pattern: CompletionPattern) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Completion Rate by Length")
                .font(OnLifeFont.bodySmall())
                .fontWeight(.semibold)
                .foregroundColor(OnLifeColors.textPrimary)

            ForEach(CompletionPattern.DurationBracket.allCases, id: \.self) { bracket in
                if let rate = pattern.completionRateByDuration[bracket] {
                    DurationRateRow(
                        bracket: bracket.displayName,
                        rate: rate
                    )
                }
            }
        }
    }

    // MARK: - Early Quit Section

    @ViewBuilder
    private func earlyQuitSection(analysis: EarlyQuitAnalysis) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14))
                    .foregroundColor(OnLifeColors.terracotta)

                Text("Early Quit Pattern")
                    .font(OnLifeFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.terracotta)
            }

            Text(analysis.recommendation)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.terracotta.opacity(0.1))
        )
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(OnLifeColors.textTertiary)

            Text("Not enough data yet")
                .font(OnLifeFont.body())
                .fontWeight(.medium)
                .foregroundColor(OnLifeColors.textSecondary)

            Text("Complete 30 sessions to unlock personalized pattern analysis")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Duration Rate Row

struct DurationRateRow: View {
    let bracket: String
    let rate: Double

    var body: some View {
        HStack {
            Text(bracket)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
                .frame(width: 80, alignment: .leading)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(OnLifeColors.surface)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(rateColor)
                        .frame(width: geometry.size.width * rate, height: 4)
                }
            }
            .frame(height: 4)

            Text("\(Int(rate * 100))%")
                .font(OnLifeFont.caption())
                .fontWeight(.medium)
                .foregroundColor(rateColor)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var rateColor: Color {
        switch rate {
        case 0.8...1.0: return OnLifeColors.sage
        case 0.6..<0.8: return OnLifeColors.amber
        case 0.4..<0.6: return OnLifeColors.terracotta.opacity(0.8)
        default: return OnLifeColors.terracotta
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
        completionRateByHour: [9: 0.88, 10: 0.82, 14: 0.75],
        totalSessions: 45,
        overallCompletionRate: 0.72,
        confidence: 0.45
    )

    let mockQuitAnalysis = EarlyQuitAnalysis(
        averageQuitTime: 18 * 60,
        quitCount: 8,
        hasConsistentPattern: true,
        recommendation: "You often quit around 18 minutes. Try sessions slightly shorter than this to build completion momentum."
    )

    return ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                CompletionPatternCard(
                    pattern: mockPattern,
                    earlyQuitAnalysis: mockQuitAnalysis,
                    appeared: true
                )

                CompletionPatternCard(
                    pattern: nil,
                    earlyQuitAnalysis: nil,
                    appeared: true
                )
            }
            .padding()
        }
    }
}
