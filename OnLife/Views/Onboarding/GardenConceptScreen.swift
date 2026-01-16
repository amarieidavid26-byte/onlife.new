import SwiftUI

struct GardenConceptScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Spacing.xxxl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Text("🌻")
                    .font(.system(size: 80))

                Text("Your Focus Garden")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                VStack(spacing: Spacing.md) {
                    Text("Each garden represents a part of your life")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("Work, Personal, Creative, Health...")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
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
