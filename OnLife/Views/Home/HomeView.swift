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
                            if gardenViewModel.gardens.isEmpty {
                                // No gardens - show empty state
                                EmptyGardensCarouselView(onCreateGarden: {
                                    showCreateGarden = true
                                })
                            } else {
                                // Garden Carousel
                                GardenCarouselView(
                                    gardens: gardenViewModel.gardens,
                                    selectedGarden: Binding(
                                        get: { gardenViewModel.selectedGarden },
                                        set: { garden in
                                            if let garden = garden {
                                                gardenViewModel.selectGarden(id: garden.id)
                                            }
                                        }
                                    ),
                                    gardenViewModel: gardenViewModel,
                                    onEdit: { garden in
                                        editingGarden = garden
                                        Haptics.light()
                                    },
                                    onDelete: { garden in
                                        gardenToDelete = garden
                                        showDeleteAlert = true
                                        Haptics.light()
                                    }
                                )
                                .padding(.horizontal, -Spacing.lg) // Allow full bleed for carousel

                                // Plants Section
                                if let selectedGarden = gardenViewModel.selectedGarden {
                                    let plants = gardenViewModel.plants(for: selectedGarden.id)
                                    if !plants.isEmpty {
                                        PlantsGridView(
                                            plants: plants,
                                            gardenName: selectedGarden.name,
                                            selectedPlant: $selectedPlant
                                        )
                                        .padding(.top, Spacing.sm)
                                    } else {
                                        EmptyGardenPlantsView(
                                            gardenName: selectedGarden.name,
                                            onStartSession: {
                                                showSessionInput = true
                                            }
                                        )
                                        .frame(minHeight: 300)
                                        .padding(.top, Spacing.md)
                                    }
                                }
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
    var gardenName: String = "Your"
    @Binding var selectedPlant: Plant?

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            Text("Plants in \(gardenName)")
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(.leading, Spacing.xs)

            // Grid with 2 columns
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(Array(plants.enumerated()), id: \.element.id) { index, plant in
                    PlantGridCard(plant: plant) {
                        selectedPlant = plant
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05),
                        value: plants.count
                    )
                }
            }
        }
    }
}

