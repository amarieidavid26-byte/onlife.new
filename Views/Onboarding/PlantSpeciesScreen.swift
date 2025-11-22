import SwiftUI

struct PlantSpeciesScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Text("Choose Your Plant")
                    .font(AppFont.heading2())
                    .foregroundColor(AppColors.textPrimary)

                Text("Each species has its own personality")
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Spacing.md) {
                    ForEach(PlantSpecies.allCases, id: \.self) { species in
                        PlantSpeciesButton(species: species, isSelected: viewModel.selectedPlantSpecies == species) {
                            viewModel.selectedPlantSpecies = species
                        }
                    }
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

struct PlantSpeciesButton: View {
    let species: PlantSpecies
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Text(species.icon)
                    .font(.system(size: 40))

                Text(species.displayName)
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .background(isSelected ? AppColors.healthy : AppColors.lightSoil)
            .cornerRadius(CornerRadius.medium)
        }
    }
}
