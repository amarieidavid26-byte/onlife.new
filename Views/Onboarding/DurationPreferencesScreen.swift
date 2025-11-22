import SwiftUI

struct DurationPreferencesScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Text("Typical Focus Duration")
                    .font(AppFont.heading2())
                    .foregroundColor(AppColors.textPrimary)

                Text("How long do you usually focus?")
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textSecondary)

                DurationChipSelector(selectedDuration: $viewModel.selectedDuration)
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
