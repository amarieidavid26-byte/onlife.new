import SwiftUI

/// Displays app switching metrics during a focus session
/// Shows switch breakdown by severity and overall focus quality
struct AppSwitchIndicator: View {
    let analysis: AppSwitchAnalysis
    let sessionDuration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(indicatorColor)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text("App Switching")
                        .font(OnLifeFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(analysis.switchPattern.label)
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(analysis.totalSwitches)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(indicatorColor)

                    Text("switches")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            // Switch breakdown bar
            if analysis.totalSwitches > 0 {
                switchBreakdownBar
            }

            // Details row
            HStack(spacing: Spacing.lg) {
                AppSwitchDetailLabel(
                    icon: "bolt",
                    value: "\(analysis.quickChecks)",
                    label: "quick",
                    color: OnLifeColors.sage
                )

                AppSwitchDetailLabel(
                    icon: "clock",
                    value: "\(analysis.distractions)",
                    label: "distractions",
                    color: OnLifeColors.amber
                )

                AppSwitchDetailLabel(
                    icon: "arrow.triangle.2.circlepath",
                    value: "\(analysis.contextSwitches)",
                    label: "context",
                    color: OnLifeColors.terracotta
                )

                Spacer()
            }

            // Average time away
            if analysis.totalSwitches > 0 {
                HStack(spacing: Spacing.xs) {
                    Text("Avg time away:")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)

                    Text(formatDuration(analysis.averageTimeAway))
                        .font(OnLifeFont.caption())
                        .fontWeight(.medium)
                        .foregroundColor(OnLifeColors.textSecondary)

                    if analysis.longestTimeAway > 0 {
                        Text("(longest: \(formatDuration(analysis.longestTimeAway)))")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    @ViewBuilder
    private var switchBreakdownBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                // Quick checks (green)
                if analysis.quickChecks > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(OnLifeColors.sage)
                        .frame(width: barWidth(for: analysis.quickChecks, total: analysis.totalSwitches, fullWidth: geometry.size.width))
                }

                // Distractions (amber)
                if analysis.distractions > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(OnLifeColors.amber)
                        .frame(width: barWidth(for: analysis.distractions, total: analysis.totalSwitches, fullWidth: geometry.size.width))
                }

                // Context switches (terracotta)
                if analysis.contextSwitches > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(OnLifeColors.terracotta)
                        .frame(width: barWidth(for: analysis.contextSwitches, total: analysis.totalSwitches, fullWidth: geometry.size.width))
                }
            }
        }
        .frame(height: 8)
    }

    private func barWidth(for count: Int, total: Int, fullWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        let spacing: CGFloat = 2 * CGFloat(max(0, numberOfSegments - 1))
        let availableWidth = fullWidth - spacing
        return availableWidth * CGFloat(count) / CGFloat(total)
    }

    private var numberOfSegments: Int {
        var count = 0
        if analysis.quickChecks > 0 { count += 1 }
        if analysis.distractions > 0 { count += 1 }
        if analysis.contextSwitches > 0 { count += 1 }
        return count
    }

    private var indicatorColor: Color {
        switch analysis.switchPattern {
        case .focused: return OnLifeColors.sage
        case .minimal: return OnLifeColors.sage.opacity(0.8)
        case .moderate: return OnLifeColors.amber
        case .severe: return OnLifeColors.terracotta
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

// MARK: - Detail Label

struct AppSwitchDetailLabel: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color.opacity(0.8))

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(OnLifeFont.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(color)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
    }
}

// MARK: - Compact Version

struct AppSwitchCompactIndicator: View {
    let analysis: AppSwitchAnalysis
    let sessionDuration: TimeInterval

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon with color indicator
            ZStack {
                Circle()
                    .fill(indicatorColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16))
                    .foregroundColor(indicatorColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(analysis.totalSwitches) app switches")
                    .font(OnLifeFont.bodySmall())
                    .fontWeight(.medium)
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(analysis.switchPattern.label)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            Spacer()

            // Severity breakdown badges
            if analysis.totalSwitches > 0 {
                HStack(spacing: 4) {
                    if analysis.contextSwitches > 0 {
                        SwitchCountBadge(count: analysis.contextSwitches, color: OnLifeColors.terracotta)
                    }
                    if analysis.distractions > 0 {
                        SwitchCountBadge(count: analysis.distractions, color: OnLifeColors.amber)
                    }
                    if analysis.quickChecks > 0 {
                        SwitchCountBadge(count: analysis.quickChecks, color: OnLifeColors.sage)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private var indicatorColor: Color {
        switch analysis.switchPattern {
        case .focused: return OnLifeColors.sage
        case .minimal: return OnLifeColors.sage.opacity(0.8)
        case .moderate: return OnLifeColors.amber
        case .severe: return OnLifeColors.terracotta
        }
    }
}

struct SwitchCountBadge: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(OnLifeFont.caption())
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }
}

// MARK: - Preview

#Preview {
    let focusedAnalysis = AppSwitchAnalysis(
        totalSwitches: 0,
        quickChecks: 0,
        distractions: 0,
        contextSwitches: 0,
        averageTimeAway: 0,
        longestTimeAway: 0,
        flowPenalty: 0
    )

    let minimalAnalysis = AppSwitchAnalysis(
        totalSwitches: 2,
        quickChecks: 2,
        distractions: 0,
        contextSwitches: 0,
        averageTimeAway: 15,
        longestTimeAway: 22,
        flowPenalty: 6
    )

    let moderateAnalysis = AppSwitchAnalysis(
        totalSwitches: 5,
        quickChecks: 2,
        distractions: 2,
        contextSwitches: 1,
        averageTimeAway: 45,
        longestTimeAway: 150,
        flowPenalty: 37
    )

    let severeAnalysis = AppSwitchAnalysis(
        totalSwitches: 8,
        quickChecks: 2,
        distractions: 3,
        contextSwitches: 3,
        averageTimeAway: 90,
        longestTimeAway: 300,
        flowPenalty: 75
    )

    return ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                Text("App Switch Indicators")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Full Version")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)

                AppSwitchIndicator(
                    analysis: focusedAnalysis,
                    sessionDuration: 25 * 60
                )

                AppSwitchIndicator(
                    analysis: minimalAnalysis,
                    sessionDuration: 25 * 60
                )

                AppSwitchIndicator(
                    analysis: moderateAnalysis,
                    sessionDuration: 25 * 60
                )

                AppSwitchIndicator(
                    analysis: severeAnalysis,
                    sessionDuration: 25 * 60
                )

                Divider()
                    .background(OnLifeColors.textTertiary.opacity(0.3))

                Text("Compact Version")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)

                AppSwitchCompactIndicator(
                    analysis: focusedAnalysis,
                    sessionDuration: 25 * 60
                )

                AppSwitchCompactIndicator(
                    analysis: minimalAnalysis,
                    sessionDuration: 25 * 60
                )

                AppSwitchCompactIndicator(
                    analysis: moderateAnalysis,
                    sessionDuration: 25 * 60
                )

                AppSwitchCompactIndicator(
                    analysis: severeAnalysis,
                    sessionDuration: 25 * 60
                )
            }
            .padding()
        }
    }
}
