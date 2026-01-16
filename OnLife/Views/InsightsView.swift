import SwiftUI

struct InsightsView: View {
    var body: some View {
        ZStack {
            OnLifeColors.deepForest
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Your Focus")
                                .font(OnLifeFont.bodySmall())
                                .foregroundColor(OnLifeColors.textTertiary)

                            Text("Insights")
                                .font(OnLifeFont.heading1())
                                .foregroundColor(OnLifeColors.textPrimary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xxxl)

                    // Coming soon placeholder
                    VStack(spacing: Spacing.xl) {
                        Text("📊")
                            .font(.system(size: 80))

                        VStack(spacing: Spacing.md) {
                            Text("Insights Coming Soon")
                                .font(OnLifeFont.heading2())
                                .foregroundColor(OnLifeColors.textPrimary)

                            Text("Complete more focus sessions to unlock AI-powered insights about your productivity patterns")
                                .font(OnLifeFont.body())
                                .foregroundColor(OnLifeColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Spacing.xl)
                        }

                        // Preview cards
                        VStack(spacing: Spacing.md) {
                            InsightPreviewCard(
                                icon: "🏠",
                                title: "Best Environment",
                                value: "Coming soon"
                            )

                            InsightPreviewCard(
                                icon: "🌅",
                                title: "Peak Focus Time",
                                value: "Coming soon"
                            )

                            InsightPreviewCard(
                                icon: "⏱️",
                                title: "Average Session",
                                value: "Coming soon"
                            )
                        }
                        .padding(.horizontal, Spacing.xl)
                    }
                    .padding(.top, Spacing.xxxl)
                }
            }
        }
    }
}

struct InsightPreviewCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(icon)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(value)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(OnLifeColors.surface)
        .cornerRadius(CornerRadius.large)
    }
}
