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
    @State private var headerAppeared = false

    var body: some View {
        NavigationView {
            ZStack {
                // MARK: - Background Gradient
                LinearGradient(
                    colors: [OnLifeColors.deepForest, OnLifeColors.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Header
                    headerView
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, Spacing.md)

                    // MARK: - Content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: Spacing.lg) {
                            if let garden = gardenViewModel.selectedGarden {
                                // Garden Card
                                GardenCard(
                                    garden: garden,
                                    plantCount: gardenViewModel.plantCount,
                                    totalFocusTime: gardenViewModel.totalFocusTime,
                                    onEdit: {
                                        editingGarden = garden
                                        Haptics.light()
                                    },
                                    onDelete: {
                                        if gardenViewModel.gardens.count > 1 {
                                            gardenToDelete = garden
                                            showDeleteAlert = true
                                            Haptics.light()
                                        }
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))

                                // Plants Section
                                if !gardenViewModel.plants.isEmpty {
                                    PlantsGridView(
                                        plants: gardenViewModel.plants,
                                        selectedPlant: $selectedPlant
                                    )
                                    .padding(.top, Spacing.md)
                                } else {
                                    emptyGardenView
                                        .padding(.top, Spacing.xxl)
                                }
                            } else {
                                // No garden selected state
                                noGardenView
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, 120) // Space for FAB
                    }
                }

                // MARK: - FAB (Floating Action Button)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        fabButton
                            .padding(.trailing, Spacing.lg)
                            .padding(.bottom, Spacing.xxl)
                    }
                }
            }
            .navigationBarHidden(true)
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
                Haptics.success()
            }
        } message: { garden in
            Text("Are you sure you want to delete \"\(garden.name)\"? This will also delete all \(gardenViewModel.plants(for: garden.id).count) plants in this garden.")
        }
        .onAppear {
            print("🏠 HomeView appeared")
            gardenViewModel.refreshGardens()
            sessionViewModel.currentGarden = gardenViewModel.selectedGarden

            withAnimation(OnLifeAnimation.elegant) {
                headerAppeared = true
            }
        }
        .onChange(of: sessionViewModel.sessionPhase) { oldValue, newValue in
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

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Welcome back")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)

                Text("Your Gardens")
                    .font(OnLifeFont.display())
                    .foregroundColor(OnLifeColors.textPrimary)
            }
            .opacity(headerAppeared ? 1 : 0)
            .offset(y: headerAppeared ? 0 : -10)

            Spacer()

            // Create Garden Button
            Button(action: {
                showCreateGarden = true
                Haptics.light()
            }) {
                ZStack {
                    Circle()
                        .fill(OnLifeColors.sage.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(OnLifeColors.sage)
                }
            }
            .opacity(headerAppeared ? 1 : 0)
            .scaleEffect(headerAppeared ? 1 : 0.8)
        }
    }

    // MARK: - FAB Button

    private var fabButton: some View {
        Button(action: {
            Haptics.impact(.medium)
            showSessionInput = true
        }) {
            ZStack {
                Circle()
                    .fill(OnLifeColors.amber)
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: OnLifeColors.amber.opacity(0.4),
                        radius: 16,
                        y: 8
                    )

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(OnLifeColors.deepForest)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Empty Garden View

    private var emptyGardenView: some View {
        VStack(spacing: Spacing.lg) {
            Text("🌱")
                .font(.system(size: 72))
                .symbolEffect(.bounce, options: .repeating.speed(0.3))

            VStack(spacing: Spacing.sm) {
                Text("Your garden is waiting to grow")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Start a focus session to plant your first seed!")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                Haptics.impact(.medium)
                showSessionInput = true
            }) {
                Text("Plant Your First Seed")
                    .font(OnLifeFont.button())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.amber)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, Spacing.md)
        }
        .padding(Spacing.xl)
    }

    // MARK: - No Garden View

    private var noGardenView: some View {
        VStack(spacing: Spacing.lg) {
            Text("🏡")
                .font(.system(size: 72))

            VStack(spacing: Spacing.sm) {
                Text("Create Your First Garden")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Gardens help you organize your focus sessions and track your growth.")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                Haptics.impact(.medium)
                showCreateGarden = true
            }) {
                Text("Create Garden")
                    .font(OnLifeFont.button())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.amber)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(Spacing.xl)
        .padding(.top, Spacing.xxl)
    }
}

// MARK: - Garden Card

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
                // Garden icon
                Text(garden.icon)
                    .font(.system(size: 44))

                VStack(alignment: .leading, spacing: 4) {
                    Text(garden.name)
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("\(plantCount) plants")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                Spacer()

                // Focus time
                VStack(alignment: .trailing, spacing: 4) {
                    Text(totalFocusTime)
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("total focus")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .shadow(
            color: Color.black.opacity(0.15),
            radius: 8,
            y: 4
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(OnLifeAnimation.elegant) {
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

            if onDelete != nil {
                Button(role: .destructive, action: {
                    onDelete?()
                }) {
                    Label("Delete Garden", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Plants Grid View

struct PlantsGridView: View {
    let plants: [Plant]
    @Binding var selectedPlant: Plant?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            Text("Your Plants")
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(.leading, Spacing.xs)

            // Grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 3),
                spacing: Spacing.md
            ) {
                ForEach(Array(plants.enumerated()), id: \.element.id) { index, plant in
                    PlantGridItem(plant: plant, index: index)
                        .onTapGesture {
                            Haptics.selection()
                            selectedPlant = plant
                        }
                }
            }
        }
    }
}

// MARK: - Plant Grid Item

struct PlantGridItem: View {
    let plant: Plant
    let index: Int

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Plant emoji
            Text(plantEmoji(for: plant.species))
                .font(.system(size: 44))

            // Plant name
            Text(plant.species.rawValue.capitalized)
                .font(OnLifeFont.label())
                .foregroundColor(OnLifeColors.textPrimary)
                .lineLimit(1)

            // Health indicator dot
            Circle()
                .fill(healthColor(for: plant.healthStatus))
                .frame(width: 10, height: 10)
                .shadow(color: healthColor(for: plant.healthStatus).opacity(0.5), radius: 4)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(OnLifeColors.cardBackgroundElevated)
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            // Staggered animation
            let delay = Double(index) * 0.05
            withAnimation(OnLifeAnimation.standard.delay(delay)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    // MARK: - Helpers

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
        case .thriving:
            return OnLifeColors.healthy
        case .healthy:
            return OnLifeColors.healthy
        case .stressed:
            return OnLifeColors.thirsty
        case .wilting:
            return OnLifeColors.wilting
        case .dead:
            return OnLifeColors.dormant
        }
    }
}
