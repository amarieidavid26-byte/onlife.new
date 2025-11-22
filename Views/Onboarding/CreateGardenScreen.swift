import SwiftUI

struct CreateGardenScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Text("Create Your First Garden")
                    .font(AppFont.heading2())
                    .foregroundColor(AppColors.textPrimary)

                TextField("Garden Name", text: $viewModel.gardenName)
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textPrimary)
                    .padding(Spacing.lg)
                    .background(AppColors.lightSoil)
                    .cornerRadius(CornerRadius.medium)
                    .padding(.horizontal, Spacing.xl)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Spacing.md) {
                    ForEach(viewModel.availableIcons, id: \.self) { icon in
                        Button(action: { viewModel.selectedIcon = icon }) {
                            Text(icon)
                                .font(.system(size: 40))
                                .frame(width: 60, height: 60)
                                .background(viewModel.selectedIcon == icon ? AppColors.healthy : AppColors.lightSoil)
                                .cornerRadius(CornerRadius.medium)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
            }

            Spacer()

            PrimaryButton(title: "Continue") {
                viewModel.nextScreen()
            }
            .disabled(viewModel.gardenName.isEmpty)
            .opacity(viewModel.gardenName.isEmpty ? 0.5 : 1.0)
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)
        }
    }
}
