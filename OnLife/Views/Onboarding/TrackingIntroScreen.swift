import SwiftUI

struct TrackingIntroScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Text("📊")
                    .font(.system(size: 80))

                Text("Track Your Growth")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                VStack(spacing: Spacing.md) {
                    FeatureRow(icon: "📈", text: "See your focus patterns")
                    FeatureRow(icon: "🏆", text: "Build streaks and achievements")
                    FeatureRow(icon: "🧠", text: "Get AI-powered insights")
                }
                .padding(.horizontal, Spacing.xl)
            }

            Spacer()

            PrimaryButton(title: "Continue") {
                viewModel.nextScreen()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(icon)
                .font(.system(size: 30))

            Text(text)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)

            Spacer()
        }
        .padding(Spacing.lg)
        .background(OnLifeColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }
}
