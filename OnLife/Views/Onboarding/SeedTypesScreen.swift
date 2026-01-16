import SwiftUI

struct SeedTypesScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Text("Two Types of Seeds")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                VStack(spacing: Spacing.md) {
                    SeedTypeCard(seedType: .oneTime)
                    SeedTypeCard(seedType: .recurring)
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

struct SeedTypeCard: View {
    let seedType: SeedType

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(seedType.icon)
                .font(.system(size: 40))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(seedType.displayName)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(seedType.description)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(OnLifeColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }
}
