import SwiftUI
import RealityKit

/// Premium garden experience - 3D by default, 2D fallback
struct GardenExperienceView: View {
    @ObservedObject var gardenViewModel: GardenViewModel
    @StateObject private var coordinator = GardenSceneCoordinator.shared
    @ObservedObject var themeManager = ThemeManager.shared

    @State private var isLoading = true
    @State private var use3D = true
    @State private var showPlantDetail: Plant? = nil
    @State private var selectedPlantID: UUID? = nil

    var theme: AppTheme { themeManager.currentTheme }

    // Check if device supports RealityKit well
    private var supports3D: Bool {
        // All devices iOS 15+ support RealityKit
        // Could add memory/thermal checks here
        return true
    }

    var body: some View {
        ZStack {
            if use3D && supports3D {
                // PREMIUM 3D EXPERIENCE
                Garden3DContainerView(gardenViewModel: gardenViewModel)
                    .overlay(alignment: .top) {
                        gardenHeader
                    }
                    .overlay(alignment: .bottom) {
                        gardenFooter
                    }
            } else {
                // Fallback 2D view
                fallback2DView
            }
        }
        .sheet(item: $showPlantDetail) { plant in
            PlantDetailView(plant: plant)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            setupGarden()
        }
    }

    // MARK: - Header Overlay

    private var gardenHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(gardenViewModel.selectedGarden?.name ?? "My Garden")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("\(gardenViewModel.plants.count) plants \(totalFocusTime)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            // 3D/2D toggle (subtle, for accessibility)
            Button {
                withAnimation(.spring()) {
                    use3D.toggle()
                }
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: use3D ? "cube.fill" : "square.grid.2x2")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding()
        .padding(.top, 50) // Safe area
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Footer Overlay

    private var gardenFooter: some View {
        VStack(spacing: 12) {
            // Plant quick-select carousel
            if !gardenViewModel.plants.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(gardenViewModel.plants) { plant in
                            PlantQuickCard(
                                plant: plant,
                                isSelected: selectedPlantID == plant.id
                            ) {
                                selectedPlantID = plant.id
                                // Notify 3D scene to focus on this plant
                                NotificationCenter.default.post(
                                    name: .focusOnPlant,
                                    object: plant.id
                                )
                                HapticManager.shared.impact(style: .light)
                            } onDoubleTap: {
                                showPlantDetail = plant
                                HapticManager.shared.impact(style: .medium)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Garden stats bar
            HStack(spacing: 20) {
                StatPill(icon: "leaf.fill", value: "\(gardenViewModel.plants.count)", label: "Plants")
                StatPill(icon: "heart.fill", value: "\(Int(averageHealth))%", label: "Health")
                StatPill(icon: "clock.fill", value: totalFocusTime, label: "Focus")
            }
            .padding(.horizontal)
            .padding(.bottom, 100) // Tab bar space
        }
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Fallback 2D View

    private var fallback2DView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(gardenViewModel.plants) { plant in
                    Plant2DCard(plant: plant)
                        .onTapGesture {
                            showPlantDetail = plant
                        }
                }
            }
            .padding()
        }
        .background(theme.backgroundPrimary)
    }

    // MARK: - Computed Properties

    private var totalFocusTime: String {
        let totalSeconds = gardenViewModel.plants.reduce(0.0) { $0 + $1.totalFocusTime }
        let minutes = Int(totalSeconds / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    private var averageHealth: Double {
        guard !gardenViewModel.plants.isEmpty else { return 100 }
        let total = gardenViewModel.plants.reduce(0.0) { $0 + $1.healthLevel }
        return (total / Double(gardenViewModel.plants.count)) * 100
    }

    // MARK: - Setup

    private func setupGarden() {
        Task {
            await coordinator.initialize()
            withAnimation {
                isLoading = false
            }
        }
    }
}

// MARK: - Plant Quick Card

struct PlantQuickCard: View {
    let plant: Plant
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: 6) {
            Text(plantEmoji)
                .font(.title)

            Text(plant.name ?? plant.species.rawValue.capitalized)
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)

            // Health indicator
            Circle()
                .fill(healthColor)
                .frame(width: 6, height: 6)
        }
        .frame(width: 60, height: 70)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? theme.accent.opacity(0.3) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onTapGesture(count: 1, perform: onTap)
    }

    private var plantEmoji: String {
        switch plant.species {
        case .oak: return "🌳"
        case .rose: return "🌹"
        case .cactus: return "🌵"
        case .sunflower: return "🌻"
        case .fern: return "🌿"
        case .bamboo: return "🎋"
        case .lavender: return "💜"
        case .bonsai: return "🪴"
        case .cherry: return "🌸"
        case .tulip: return "🌷"
        }
    }

    private var healthColor: Color {
        let health = plant.healthLevel
        if health > 0.7 { return .green }
        if health > 0.3 { return .yellow }
        return .red
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - 2D Plant Card (Fallback)

struct Plant2DCard: View {
    let plant: Plant

    var body: some View {
        VStack(spacing: 8) {
            Text(plantEmoji)
                .font(.system(size: 50))

            Text(plant.name ?? plant.species.rawValue.capitalized)
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textPrimary)

            // Growth progress
            ProgressView(value: plant.growthProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: OnLifeColors.sage))
                .frame(width: 80)

            // Health indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(healthColor)
                    .frame(width: 8, height: 8)
                Text("\(Int(plant.healthLevel * 100))%")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private var plantEmoji: String {
        switch plant.species {
        case .oak: return "🌳"
        case .rose: return "🌹"
        case .cactus: return "🌵"
        case .sunflower: return "🌻"
        case .fern: return "🌿"
        case .bamboo: return "🎋"
        case .lavender: return "💜"
        case .bonsai: return "🪴"
        case .cherry: return "🌸"
        case .tulip: return "🌷"
        }
    }

    private var healthColor: Color {
        let health = plant.healthLevel
        if health > 0.7 { return OnLifeColors.healthy }
        if health > 0.3 { return OnLifeColors.amber }
        return OnLifeColors.terracotta
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let focusOnPlant = Notification.Name("focusOnPlant")
}

// MARK: - Preview

#if DEBUG
struct GardenExperienceView_Previews: PreviewProvider {
    static var previews: some View {
        GardenExperienceView(gardenViewModel: GardenViewModel())
            .preferredColorScheme(.dark)
    }
}
#endif
