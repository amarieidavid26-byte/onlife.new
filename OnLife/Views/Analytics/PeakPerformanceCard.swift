import SwiftUI

/// Card displaying AI-identified peak performance windows
struct PeakPerformanceCard: View {
    let windows: [PerformanceAnalyzer.PerformanceWindow]
    let alignment: ChronotypeAlignment?
    @State private var contentAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.3), .purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 40, height: 40)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Peak Performance Windows")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    if windows.isEmpty {
                        Text("Complete 14+ sessions to unlock")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    } else {
                        Text("AI-identified from your flow data")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }

                Spacer()
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 10)

            if windows.isEmpty {
                // Empty state
                emptyStateView
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(OnLifeAnimation.elegant.delay(0.05), value: contentAppeared)
            } else {
                // Peak windows
                ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                    PeakWindowRow(window: window, rank: index + 1)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 10)
                        .animation(OnLifeAnimation.elegant.delay(0.05 + Double(index) * 0.08), value: contentAppeared)
                }

                // Chronotype alignment (if available)
                if let alignment = alignment {
                    ChronotypeAlignmentBadge(alignment: alignment)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 10)
                        .animation(OnLifeAnimation.elegant.delay(0.3), value: contentAppeared)
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .onAppear {
            withAnimation(OnLifeAnimation.elegant) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(OnLifeColors.surface)
                    .frame(width: 64, height: 64)

                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 28))
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Text("Not Enough Data Yet")
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            Text("Complete at least 14 focus sessions so we can identify your optimal work windows with confidence.")
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)

            // Progress indicator
            HStack(spacing: Spacing.xs) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12))
                    .foregroundColor(OnLifeColors.sage)

                Text("Keep focusing to unlock insights")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }
}

// MARK: - Peak Window Row

struct PeakWindowRow: View {
    let window: PerformanceAnalyzer.PerformanceWindow
    let rank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                // Rank badge
                Text("#\(rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(rankColor)
                    )

                // Time range
                Text(window.timeRangeDescription)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                // Flow score
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(window.averageFlowScore))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)

                    Text("avg flow")
                        .font(.system(size: 10))
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            // Recommendation
            Text(window.recommendation)
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textSecondary)

            // Confidence + session count
            HStack(spacing: Spacing.md) {
                HStack(spacing: 4) {
                    Image(systemName: window.confidenceLevel.icon)
                        .font(.system(size: 11))
                    Text(window.confidenceLevel.label)
                        .font(OnLifeFont.caption())
                }
                .foregroundColor(window.confidenceLevel.color)

                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11))
                    Text("\(window.sessionCount) sessions")
                        .font(OnLifeFont.caption())
                }
                .foregroundColor(OnLifeColors.textTertiary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.surface)
        )
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .purple
        case 2: return .blue
        case 3: return .cyan
        default: return OnLifeColors.textTertiary
        }
    }

    private var scoreColor: Color {
        switch window.averageFlowScore {
        case 80...100: return .green
        case 70..<80: return OnLifeColors.sage
        case 60..<70: return OnLifeColors.amber
        default: return OnLifeColors.terracotta
        }
    }
}

// MARK: - Chronotype Alignment Badge

struct ChronotypeAlignmentBadge: View {
    let alignment: ChronotypeAlignment

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: alignment.level.icon)
                    .font(.system(size: 16))
                    .foregroundColor(alignment.level.color)

                Text("Chronotype Alignment")
                    .font(OnLifeFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                Text(alignment.level.label)
                    .font(OnLifeFont.caption())
                    .foregroundColor(alignment.level.color)
            }

            Text(alignment.insight)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)

            // Visual comparison
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Predicted")
                        .font(.system(size: 10))
                        .foregroundColor(OnLifeColors.textTertiary)
                    Text(alignment.chronotypeWindowFormatted)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(OnLifeColors.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Actual Peak")
                        .font(.system(size: 10))
                        .foregroundColor(OnLifeColors.textTertiary)
                    Text(alignment.actualWindowFormatted)
                        .font(OnLifeFont.bodySmall())
                        .fontWeight(.medium)
                        .foregroundColor(alignment.level.color)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(alignment.level.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(alignment.level.color.opacity(0.3), lineWidth: 1)
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
                // With data
                PeakPerformanceCard(
                    windows: [
                        PerformanceAnalyzer.PerformanceWindow(
                            startHour: 9,
                            endHour: 12,
                            averageFlowScore: 82,
                            sessionCount: 15,
                            confidence: 0.85,
                            recommendation: "Your peak performance window. Schedule deep work here."
                        ),
                        PerformanceAnalyzer.PerformanceWindow(
                            startHour: 15,
                            endHour: 17,
                            averageFlowScore: 74,
                            sessionCount: 8,
                            confidence: 0.6,
                            recommendation: "Strong focus window. Good for important tasks."
                        ),
                        PerformanceAnalyzer.PerformanceWindow(
                            startHour: 20,
                            endHour: 22,
                            averageFlowScore: 68,
                            sessionCount: 5,
                            confidence: 0.4,
                            recommendation: "Promising time slot. Gather more data to confirm."
                        )
                    ],
                    alignment: ChronotypeAlignment(
                        level: .closeMatch,
                        chronotypeWindow: (9, 12),
                        actualWindow: (9, 12),
                        insight: "Your performance is close to your predicted Morning peak window."
                    )
                )

                // Empty state
                PeakPerformanceCard(windows: [], alignment: nil)
            }
            .padding()
        }
    }
}
