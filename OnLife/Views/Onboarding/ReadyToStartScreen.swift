import SwiftUI

struct ReadyToStartScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Text("🎉")
                    .font(.system(size: 100))

                Text("You're All Set!")
                    .font(AppFont.heading1())
                    .foregroundColor(AppColors.textPrimary)

                Text("Your \(viewModel.gardenName) garden is ready to grow")
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            PrimaryButton(title: "Start Growing") {
                viewModel.completeOnboarding()
                hasCompletedOnboarding = true
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)
        }
    }
}
