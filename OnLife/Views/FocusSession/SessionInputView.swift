import SwiftUI

struct SessionInputView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: FocusSessionViewModel
    @ObservedObject var gardenViewModel: GardenViewModel

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.richSoil
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Garden Selector
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("GARDEN")
                                .font(AppFont.label())
                                .foregroundColor(AppColors.textTertiary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.md) {
                                    ForEach(gardenViewModel.gardens) { garden in
                                        GardenSelectorChip(
                                            garden: garden,
                                            isSelected: viewModel.currentGarden?.id == garden.id
                                        ) {
                                            viewModel.currentGarden = garden
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Task Description
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("WHAT ARE YOU WORKING ON?")
                                .font(AppFont.label())
                                .foregroundColor(AppColors.textTertiary)

                            TextField("Task description", text: $viewModel.taskDescription)
                                .font(AppFont.body())
                                .foregroundColor(AppColors.textPrimary)
                                .padding(Spacing.lg)
                                .background(AppColors.lightSoil)
                                .cornerRadius(CornerRadius.medium)
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Seed Type
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("SEED TYPE")
                                .font(AppFont.label())
                                .foregroundColor(AppColors.textTertiary)

                            HStack(spacing: Spacing.md) {
                                SessionSeedTypeCard(
                                    seedType: .oneTime,
                                    isSelected: viewModel.selectedSeedType == .oneTime
                                ) {
                                    viewModel.selectedSeedType = .oneTime
                                }

                                SessionSeedTypeCard(
                                    seedType: .recurring,
                                    isSelected: viewModel.selectedSeedType == .recurring
                                ) {
                                    viewModel.selectedSeedType = .recurring
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Duration
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("DURATION")
                                .font(AppFont.label())
                                .foregroundColor(AppColors.textTertiary)

                            DurationChipSelector(selectedDuration: $viewModel.selectedDuration)
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Environment
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("ENVIRONMENT")
                                .font(AppFont.label())
                                .foregroundColor(AppColors.textTertiary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Spacing.md) {
                                ForEach(FocusEnvironment.allCases, id: \.self) { environment in
                                    EnvironmentChip(
                                        environment: environment,
                                        isSelected: viewModel.selectedEnvironment == environment
                                    ) {
                                        viewModel.selectedEnvironment = environment
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Plant Species
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("PLANT SPECIES")
                                .font(AppFont.label())
                                .foregroundColor(AppColors.textTertiary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Spacing.md) {
                                ForEach(PlantSpecies.allCases, id: \.self) { species in
                                    PlantSpeciesChip(
                                        species: species,
                                        isSelected: viewModel.selectedPlantSpecies == species
                                    ) {
                                        viewModel.selectedPlantSpecies = species
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Plant Seed Button
                        PrimaryButton(title: "Plant Seed") {
                            dismiss()
                            viewModel.startSession()
                        }
                        .disabled(viewModel.taskDescription.isEmpty || viewModel.currentGarden == nil)
                        .opacity((viewModel.taskDescription.isEmpty || viewModel.currentGarden == nil) ? 0.5 : 1.0)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.bottom, Spacing.xxxl)
                    }
                    .padding(.top, Spacing.xl)
                }
            }
            .navigationTitle("New Focus Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
            .onAppear {
                // Ensure currentGarden is set if nil
                if viewModel.currentGarden == nil && !gardenViewModel.gardens.isEmpty {
                    viewModel.currentGarden = gardenViewModel.selectedGarden
                    print("📝 SessionInputView: Set currentGarden to \(viewModel.currentGarden?.name ?? "nil")")
                }
            }
        }
    }
}

struct GardenSelectorChip: View {
    let garden: Garden
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(garden.icon)
                    .font(.system(size: 20))

                Text(garden.name)
                    .font(AppFont.body())
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(isSelected ? AppColors.healthy : AppColors.lightSoil)
            .cornerRadius(CornerRadius.medium)
        }
    }
}

struct SessionSeedTypeCard: View {
    let seedType: SeedType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(seedType.icon)
                    .font(.system(size: 30))

                Text(seedType.displayName)
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textPrimary)

                Text(seedType == .oneTime ? "One-time task" : "Recurring habit")
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(isSelected ? AppColors.healthy : AppColors.lightSoil)
            .cornerRadius(CornerRadius.medium)
        }
    }
}

struct EnvironmentChip: View {
    let environment: FocusEnvironment
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(environment.icon)
                    .font(.system(size: 20))

                Text(environment.displayName)
                    .font(AppFont.body())
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)

                Spacer()
            }
            .padding(Spacing.md)
            .background(isSelected ? AppColors.healthy : AppColors.lightSoil)
            .cornerRadius(CornerRadius.medium)
        }
    }
}

struct PlantSpeciesChip: View {
    let species: PlantSpecies
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(species.icon)
                    .font(.system(size: 24))

                Text(species.displayName)
                    .font(AppFont.body())
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)

                Spacer()
            }
            .padding(Spacing.md)
            .background(isSelected ? AppColors.healthy : AppColors.lightSoil)
            .cornerRadius(CornerRadius.medium)
        }
    }
}
