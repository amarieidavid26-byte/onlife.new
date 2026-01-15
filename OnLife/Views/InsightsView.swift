import SwiftUI

struct InsightsView: View {
    var body: some View {
        ZStack {
            AppColors.richSoil
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Your Focus")
                                .font(AppFont.bodySmall())
                                .foregroundColor(AppColors.textTertiary)

                            Text("Insights")
                                .font(AppFont.heading1())
                                .foregroundColor(AppColors.textPrimary)
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
                                .font(AppFont.heading2())
                                .foregroundColor(AppColors.textPrimary)

                            Text("Complete more focus sessions to unlock AI-powered insights about your productivity patterns")
                                .font(AppFont.body())
                                .foregroundColor(AppColors.textSecondary)
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
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textPrimary)

                Text(value)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(AppColors.lightSoil)
        .cornerRadius(CornerRadius.large)
    }
}
