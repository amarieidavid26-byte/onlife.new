import SwiftUI

/// Reusable stats card for the analytics dashboard
struct StatsCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let color: Color

    init(icon: String, title: String, value: String, subtitle: String? = nil, color: Color = OnLifeColors.sage) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(title)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                StatsCard(
                    icon: "checkmark.circle.fill",
                    title: "Sessions",
                    value: "24",
                    subtitle: "32 started",
                    color: OnLifeColors.sage
                )

                StatsCard(
                    icon: "clock.fill",
                    title: "Focus Time",
                    value: "8h 45m",
                    subtitle: "Total minutes",
                    color: .purple
                )
            }

            HStack(spacing: Spacing.md) {
                StatsCard(
                    icon: "percent",
                    title: "Completion",
                    value: "75%",
                    subtitle: "Success rate",
                    color: .green
                )

                StatsCard(
                    icon: "flame.fill",
                    title: "Streak",
                    value: "7",
                    subtitle: "Days in a row",
                    color: OnLifeColors.amber
                )
            }
        }
        .padding()
    }
}
