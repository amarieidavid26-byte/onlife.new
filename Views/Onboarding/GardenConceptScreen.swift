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
                    .font(AppFont.heading1())
                    .foregroundColor(AppColors.textPrimary)

                VStack(spacing: Spacing.md) {
                    Text("Each garden represents a part of your life")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("Work, Personal, Creative, Health...")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
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
