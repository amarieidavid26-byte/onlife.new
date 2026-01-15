import SwiftUI

struct HomeView: View {
    @StateObject private var sessionViewModel = FocusSessionViewModel()
    @StateObject private var gardenViewModel = GardenViewModel()
    @StateObject private var decayManager = PlantDecayManager.shared
    @State private var showSessionInput = false
    @State private var selectedPlant: Plant? = nil
    @State private var showCreateGarden = false
    @State private var editingGarden: Garden? = nil
    @State private var showDeleteAlert = false
    @State private var gardenToDelete: Garden? = nil

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.richSoil
                    .ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Welcome back")
                                .font(AppFont.bodySmall())
                                .foregroundColor(AppColors.textTertiary)

                            Text("Your Gardens")
                                .font(AppFont.heading1())
                                .foregroundColor(AppColors.textPrimary)
                        }

                        Spacer()

                        // Create Garden Button
                        Button(action: {
                            showCreateGarden = true
                            HapticManager.shared.impact(style: .light)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.healthy)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xl)

                // Gardens
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        if let garden = gardenViewModel.selectedGarden {
                            GardenCard(
                                garden: garden,
                                plantCount: gardenViewModel.plantCount,
                                totalFocusTime: gardenViewModel.totalFocusTime,
                                onEdit: {
                                    editingGarden = garden
                                    HapticManager.shared.impact(style: .light)
                                },
                                onDelete: {
                                    if gardenViewModel.gardens.count > 1 {
                                        gardenToDelete = garden
                                        showDeleteAlert = true
                                        HapticManager.shared.impact(style: .light)
                                    }
                                }
                            )

                            // Plants grid
                            if !gardenViewModel.plants.isEmpty {
                                PlantsGridView(plants: gardenViewModel.plants, selectedPlant: $selectedPlant)
                            } else {
                                VStack(spacing: Spacing.md) {
                                    Text("🌱")
                                        .font(.system(size: 60))

                                    Text("No plants yet")
                                        .font(AppFont.body())
                                        .foregroundColor(AppColors.textTertiary)

                                    Text("Start a focus session to grow your first plant!")
                                        .font(AppFont.bodySmall())
                                        .foregroundColor(AppColors.textTertiary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, Spacing.xxxl)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                }

                Spacer()
            }

            // FAB to start focus session
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        showSessionInput = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.healthy)
                                .frame(width: ComponentSize.fabSize, height: ComponentSize.fabSize)
                                .shadow(color: AppColors.healthy.opacity(0.5), radius: 16, y: 8)

                            Image(systemName: "plus")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    .padding(.trailing, Spacing.xl)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
        }
        .sheet(isPresented: $showSessionInput) {
            SessionInputView(viewModel: sessionViewModel, gardenViewModel: gardenViewModel)
        }
        .fullScreenCover(isPresented: $sessionViewModel.isSessionActive) {
            FocusSessionView(viewModel: sessionViewModel)
        }
        .sheet(item: $selectedPlant) { plant in
            PlantDetailView(plant: plant)
        }
        .sheet(isPresented: $showCreateGarden) {
            CreateGardenSheet(gardenViewModel: gardenViewModel, isPresented: $showCreateGarden)
        }
        .sheet(item: $editingGarden) { garden in
            EditGardenSheet(
                gardenViewModel: gardenViewModel,
                garden: garden,
                isPresented: Binding(
                    get: { editingGarden != nil },
                    set: { if !$0 { editingGarden = nil } }
                )
            )
        }
        .alert("Delete Garden", isPresented: $showDeleteAlert, presenting: gardenToDelete) { garden in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                gardenViewModel.deleteGarden(garden)
                HapticManager.shared.notification(type: .success)
            }
        } message: { garden in
            Text("Are you sure you want to delete \"\(garden.name)\"? This will also delete all \(gardenViewModel.plants(for: garden.id).count) plants in this garden.")
        }
        .navigationBarHidden(true)
        }
        .onAppear {
            print("🏠 HomeView appeared")

            // Refresh gardens first to ensure we have the latest data
            gardenViewModel.refreshGardens()

            // Then set the current garden in session viewmodel
            sessionViewModel.currentGarden = gardenViewModel.selectedGarden
            print("🏠 Selected garden: \(String(describing: gardenViewModel.selectedGarden))")
            print("🏠 Set sessionViewModel.currentGarden to: \(String(describing: sessionViewModel.currentGarden))")
        }
        .onChange(of: sessionViewModel.sessionPhase) { oldValue, newValue in
            // Refresh gardens when session completes
            if newValue == .input {
                print("🔄 Session completed, refreshing gardens...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    gardenViewModel.refreshGardens()
                }
            }
        }
        .onChange(of: decayManager.needsUpdate) { oldValue, newValue in
            if newValue {
                print("🔄 Decay update detected in HomeView, refreshing gardens...")
                gardenViewModel.refreshGardens()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectGardenFromWatch)) { notification in
            if let gardenId = notification.userInfo?["gardenId"] as? UUID {
                print("🏠 [HomeView] Received garden selection from Watch: \(gardenId)")
                gardenViewModel.selectGarden(id: gardenId)
            }
        }
    }
}

struct GardenCard: View {
    let garden: Garden
    let plantCount: Int
    let totalFocusTime: String
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @State private var scale: CGFloat = 0.95
    @State private var opacity: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(garden.icon)
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: 4) {
                    Text(garden.name)
                        .font(AppFont.heading3())
                        .foregroundColor(AppColors.textPrimary)

                    Text("\(plantCount) plants")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(totalFocusTime)
                        .font(AppFont.heading3())
                        .foregroundColor(AppColors.textPrimary)

                    Text("total focus")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(Spacing.lg)
        .background(AppColors.lightSoil)
        .cornerRadius(ComponentSize.gardenCardRadius)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .contextMenu {
            Button(action: {
                onEdit?()
            }) {
                Label("Edit Garden", systemImage: "pencil")
            }

            Button(role: .destructive, action: {
                onDelete?()
            }) {
                Label("Delete Garden", systemImage: "trash")
            }
        }
    }
}

struct PlantsGridView: View {
    let plants: [Plant]
    @Binding var selectedPlant: Plant?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Your Plants")
                .font(AppFont.heading3())
                .foregroundColor(AppColors.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: Spacing.md) {
                ForEach(plants) { plant in
                    Button(action: {
                        selectedPlant = plant
                        HapticManager.shared.impact(style: .medium)
                    }) {
                        PlantGridItem(plant: plant)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct PlantGridItem: View {
    let plant: Plant
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(plantEmoji(for: plant.species))
                .font(.system(size: 40))
                .scaleEffect(scale)

            Text(plant.species.rawValue.capitalized)
                .font(AppFont.bodySmall())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            // Health indicator
            Circle()
                .fill(healthColor(for: plant.healthStatus))
                .frame(width: 8, height: 8)
        }
        .padding(Spacing.md)
        .background(AppColors.lightSoil)
        .cornerRadius(CornerRadius.medium)
        .opacity(opacity)
        .onAppear {
            let delay = Double.random(in: 0...0.3)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    func plantEmoji(for species: PlantSpecies) -> String {
        switch species {
        case .oak: return "🌳"
        case .rose: return "🌹"
        case .cactus: return "🌵"
        case .sunflower: return "🌻"
        case .fern: return "🌿"
        case .bamboo: return "🎋"
        case .lavender: return "💜"
        case .bonsai: return "🪴"
        }
    }

    func healthColor(for status: HealthStatus) -> Color {
        switch status {
        case .thriving: return AppColors.thriving
        case .healthy: return AppColors.healthy
        case .stressed: return AppColors.stressed
        case .wilting: return AppColors.wilting
        case .dead: return AppColors.dead
        }
    }
}
