import SwiftUI

struct SessionInputView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: FocusSessionViewModel
    @ObservedObject var gardenViewModel: GardenViewModel
    @FocusState private var isTaskFieldFocused: Bool
    @State private var contentAppeared = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [OnLifeColors.deepForest, OnLifeColors.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Garden Selector
                        sectionContainer(title: "GARDEN") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.md) {
                                    ForEach(gardenViewModel.gardens) { garden in
                                        GardenSelectorChip(
                                            garden: garden,
                                            isSelected: viewModel.currentGarden?.id == garden.id
                                        ) {
                                            Haptics.selection()
                                            withAnimation(OnLifeAnimation.quick) {
                                                viewModel.currentGarden = garden
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, Spacing.lg)
                            }
                            .padding(.horizontal, -Spacing.lg) // Offset to allow edge-to-edge scrolling
                        }

                        // Task Description
                        sectionContainer(title: "WHAT ARE YOU WORKING ON?") {
                            TextField("Describe your task...", text: $viewModel.taskDescription)
                                .font(OnLifeFont.body())
                                .foregroundColor(OnLifeColors.textPrimary)
                                .focused($isTaskFieldFocused)
                                .padding(Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                        .fill(OnLifeColors.cardBackground)
                                )
                        }

                        // Seed Type
                        sectionContainer(title: "SEED TYPE") {
                            HStack(spacing: Spacing.md) {
                                SeedTypeCard(
                                    seedType: .oneTime,
                                    isSelected: viewModel.selectedSeedType == .oneTime
                                ) {
                                    Haptics.selection()
                                    withAnimation(OnLifeAnimation.quick) {
                                        viewModel.selectedSeedType = .oneTime
                                    }
                                }

                                SeedTypeCard(
                                    seedType: .recurring,
                                    isSelected: viewModel.selectedSeedType == .recurring
                                ) {
                                    Haptics.selection()
                                    withAnimation(OnLifeAnimation.quick) {
                                        viewModel.selectedSeedType = .recurring
                                    }
                                }
                            }
                        }

                        // Duration
                        sectionContainer(title: "DURATION") {
                            DurationChipSelector(selectedDuration: $viewModel.selectedDuration)
                        }

                        // Environment
                        sectionContainer(title: "ENVIRONMENT") {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: Spacing.md),
                                    GridItem(.flexible(), spacing: Spacing.md)
                                ],
                                spacing: Spacing.md
                            ) {
                                ForEach(FocusEnvironment.allCases, id: \.self) { environment in
                                    EnvironmentChip(
                                        environment: environment,
                                        isSelected: viewModel.selectedEnvironment == environment
                                    ) {
                                        Haptics.selection()
                                        withAnimation(OnLifeAnimation.quick) {
                                            viewModel.selectedEnvironment = environment
                                        }
                                    }
                                }
                            }
                        }

                        // Plant Species
                        sectionContainer(title: "PLANT SPECIES") {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: Spacing.md),
                                    GridItem(.flexible(), spacing: Spacing.md)
                                ],
                                spacing: Spacing.md
                            ) {
                                ForEach(PlantSpecies.allCases, id: \.self) { species in
                                    PlantSpeciesChip(
                                        species: species,
                                        isSelected: viewModel.selectedPlantSpecies == species
                                    ) {
                                        Haptics.selection()
                                        withAnimation(OnLifeAnimation.quick) {
                                            viewModel.selectedPlantSpecies = species
                                        }
                                    }
                                }
                            }
                        }

                        // Plant Seed Button
                        PlantSeedButton(
                            isEnabled: !viewModel.taskDescription.isEmpty && viewModel.currentGarden != nil
                        ) {
                            Haptics.impact(.medium)
                            dismiss()
                            viewModel.startSession()
                        }
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.xxl)
                    }
                    .padding(.top, Spacing.lg)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("New Focus Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OnLifeColors.deepForest, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        Haptics.light()
                        dismiss()
                    }
                    .foregroundColor(OnLifeColors.sage)
                }
            }
            .onAppear {
                // Ensure currentGarden is set if nil
                if viewModel.currentGarden == nil && !gardenViewModel.gardens.isEmpty {
                    viewModel.currentGarden = gardenViewModel.selectedGarden
                    print("📝 SessionInputView: Set currentGarden to \(viewModel.currentGarden?.name ?? "nil")")
                }

                // Animate content in
                withAnimation(OnLifeAnimation.elegant) {
                    contentAppeared = true
                }
            }
            .onTapGesture {
                isTaskFieldFocused = false
            }
        }
    }

    // MARK: - Section Container

    @ViewBuilder
    private func sectionContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .tracking(1.2)
                .padding(.leading, Spacing.xs)

            content()
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Garden Selector Chip

struct GardenSelectorChip: View {
    let garden: Garden
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(garden.icon)
                    .font(.system(size: 20))

                Text(garden.name)
                    .font(OnLifeFont.body())
                    .foregroundColor(isSelected ? OnLifeColors.sage : OnLifeColors.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(isSelected ? OnLifeColors.sage.opacity(0.2) : OnLifeColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isSelected ? OnLifeColors.sage : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = false }
                }
        )
    }
}

// MARK: - Seed Type Card

struct SeedTypeCard: View {
    let seedType: SeedType
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(seedType.icon)
                    .font(.system(size: 28))

                Text(seedType.displayName)
                    .font(OnLifeFont.body())
                    .foregroundColor(isSelected ? OnLifeColors.sage : OnLifeColors.textPrimary)

                Text(seedType == .oneTime ? "One-time task" : "Recurring habit")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(isSelected ? OnLifeColors.sage.opacity(0.2) : OnLifeColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isSelected ? OnLifeColors.sage : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = false }
                }
        )
    }
}

// MARK: - Environment Chip

struct EnvironmentChip: View {
    let environment: FocusEnvironment
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(environment.icon)
                    .font(.system(size: 20))

                Text(environment.displayName)
                    .font(OnLifeFont.body())
                    .foregroundColor(isSelected ? OnLifeColors.sage : OnLifeColors.textSecondary)

                Spacer()
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(isSelected ? OnLifeColors.sage.opacity(0.2) : OnLifeColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isSelected ? OnLifeColors.sage : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = false }
                }
        )
    }
}

// MARK: - Plant Species Chip

struct PlantSpeciesChip: View {
    let species: PlantSpecies
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(species.icon)
                    .font(.system(size: 24))

                Text(species.displayName)
                    .font(OnLifeFont.body())
                    .foregroundColor(isSelected ? OnLifeColors.sage : OnLifeColors.textSecondary)

                Spacer()
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(isSelected ? OnLifeColors.sage.opacity(0.2) : OnLifeColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isSelected ? OnLifeColors.sage : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = false }
                }
        )
    }
}

// MARK: - Plant Seed Button

struct PlantSeedButton: View {
    let isEnabled: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text("Plant Seed")
                .font(OnLifeFont.button())
                .foregroundColor(OnLifeColors.deepForest)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(OnLifeColors.amber)
                )
                .shadow(
                    color: OnLifeColors.amber.opacity(isEnabled ? 0.4 : 0),
                    radius: isPressed ? 4 : 12,
                    y: isPressed ? 2 : 6
                )
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .padding(.horizontal, Spacing.lg)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isEnabled {
                        withAnimation(OnLifeAnimation.quick) { isPressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = false }
                }
        )
    }
}
