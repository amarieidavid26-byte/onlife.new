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
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Your \(viewModel.gardenName) garden is ready to grow")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
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
