import SwiftUI

/// Displays screen activity metrics during a focus session
/// Shows screen-on percentage, distraction events, and overall focus quality
struct ScreenActivityIndicator: View {
    let summary: ScreenActivitySummary
    let sessionDuration: TimeInterval

    var screenOnPercentage: Double {
        summary.screenOnPercentage(sessionDuration: sessionDuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                Image(systemName: "rectangle.on.rectangle")
                    .foregroundColor(indicatorColor)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen Activity")
                        .font(OnLifeFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(summary.distractionRate)
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(screenOnPercentage))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(indicatorColor)

                    Text("on screen")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(OnLifeColors.textTertiary.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(indicatorColor)
                        .frame(width: geometry.size.width * (screenOnPercentage / 100), height: 6)
                }
            }
            .frame(height: 6)

            // Details row
            HStack(spacing: Spacing.lg) {
                ScreenDetailLabel(
                    icon: "eye.slash",
                    value: "\(summary.totalScreenOffEvents)",
                    label: "screen-offs"
                )

                ScreenDetailLabel(
                    icon: "exclamationmark.triangle",
                    value: "\(summary.significantDistractions)",
                    label: "distractions"
                )

                if summary.totalScreenOffTime > 0 {
                    ScreenDetailLabel(
                        icon: "clock",
                        value: formatDuration(summary.totalScreenOffTime),
                        label: "off time"
                    )
                }

                Spacer()
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private var indicatorColor: Color {
        switch screenOnPercentage {
        case 90...100: return OnLifeColors.sage
        case 75..<90: return OnLifeColors.amber
        case 50..<75: return OnLifeColors.terracotta.opacity(0.8)
        default: return OnLifeColors.terracotta
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

struct ScreenDetailLabel: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(OnLifeColors.textTertiary)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(OnLifeFont.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.textSecondary)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
    }
}

// MARK: - Compact Version

struct ScreenActivityCompactIndicator: View {
    let summary: ScreenActivitySummary
    let sessionDuration: TimeInterval

    var screenOnPercentage: Double {
        summary.screenOnPercentage(sessionDuration: sessionDuration)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon with color indicator
            ZStack {
                Circle()
                    .fill(indicatorColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 16))
                    .foregroundColor(indicatorColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(screenOnPercentage))% on screen")
                    .font(OnLifeFont.bodySmall())
                    .fontWeight(.medium)
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(summary.distractionRate)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            Spacer()

            // Distraction count badge
            if summary.significantDistractions > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("\(summary.significantDistractions)")
                        .font(OnLifeFont.caption())
                        .fontWeight(.semibold)
                }
                .foregroundColor(OnLifeColors.terracotta)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(OnLifeColors.terracotta.opacity(0.15))
                )
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private var indicatorColor: Color {
        switch screenOnPercentage {
        case 90...100: return OnLifeColors.sage
        case 75..<90: return OnLifeColors.amber
        case 50..<75: return OnLifeColors.terracotta.opacity(0.8)
        default: return OnLifeColors.terracotta
        }
    }
}

// MARK: - Preview

#Preview {
    let goodSummary = ScreenActivitySummary(
        totalScreenOffEvents: 2,
        significantDistractions: 0,
        totalScreenOffTime: 15,
        averageScreenOffDuration: 7.5,
        flowPenalty: 0
    )

    let moderateSummary = ScreenActivitySummary(
        totalScreenOffEvents: 5,
        significantDistractions: 2,
        totalScreenOffTime: 90,
        averageScreenOffDuration: 18,
        flowPenalty: 20
    )

    let poorSummary = ScreenActivitySummary(
        totalScreenOffEvents: 8,
        significantDistractions: 5,
        totalScreenOffTime: 300,
        averageScreenOffDuration: 37.5,
        flowPenalty: 40
    )

    return ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                Text("Screen Activity Indicators")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Full Version")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)

                ScreenActivityIndicator(
                    summary: goodSummary,
                    sessionDuration: 25 * 60
                )

                ScreenActivityIndicator(
                    summary: moderateSummary,
                    sessionDuration: 25 * 60
                )

                ScreenActivityIndicator(
                    summary: poorSummary,
                    sessionDuration: 25 * 60
                )

                Divider()
                    .background(OnLifeColors.textTertiary.opacity(0.3))

                Text("Compact Version")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)

                ScreenActivityCompactIndicator(
                    summary: goodSummary,
                    sessionDuration: 25 * 60
                )

                ScreenActivityCompactIndicator(
                    summary: moderateSummary,
                    sessionDuration: 25 * 60
                )

                ScreenActivityCompactIndicator(
                    summary: poorSummary,
                    sessionDuration: 25 * 60
                )
            }
            .padding()
        }
    }
}
