import SwiftUI
import SceneKit

/// Main garden diorama view - Nintendo/Animal Crossing style
/// Contains the 3D SceneKit view with UI overlays
/// Long-press and drag to move plants around the island
/// Supports placement mode for newly earned plants
struct GardenDioramaView: View {
    @ObservedObject var gardenViewModel: GardenViewModel
    @State private var selectedPlantID: UUID?

    // Placement mode (for newly earned plants)
    @Binding var isInPlacementMode: Bool
    @Binding var pendingPlantToPlace: Plant?
    var onPlacementComplete: ((Plant, PlantPosition) -> Void)?

    init(gardenViewModel: GardenViewModel,
         isInPlacementMode: Binding<Bool> = .constant(false),
         pendingPlantToPlace: Binding<Plant?> = .constant(nil),
         onPlacementComplete: ((Plant, PlantPosition) -> Void)? = nil) {
        self.gardenViewModel = gardenViewModel
        self._isInPlacementMode = isInPlacementMode
        self._pendingPlantToPlace = pendingPlantToPlace
        self.onPlacementComplete = onPlacementComplete
    }

    var body: some View {
        let plants = gardenViewModel.plants

        ZStack {
            // The 3D Garden Scene - fills entire card
            // Long-press + drag to move plants, or place new plants
            SceneKitGardenView(
                plants: plants,
                isInPlacementMode: $isInPlacementMode,
                pendingPlantToPlace: $pendingPlantToPlace,
                onPlacementComplete: { plant, position in
                    isInPlacementMode = false
                    pendingPlantToPlace = nil
                    onPlacementComplete?(plant, position)
                }
            )

            // Gradient overlay at bottom for readability (hide during placement)
            if !isInPlacementMode {
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                }
            }

            // Placement mode overlay
            if isInPlacementMode, let plant = pendingPlantToPlace {
                VStack {
                    // Top prompt
                    VStack(spacing: 8) {
                        Text("🌱 Long-press to plant your \(plant.species.rawValue.capitalized)!")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Hold on the grass where you want it")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.top, 20)

                    Spacer()

                    // Cancel button
                    Button(action: {
                        isInPlacementMode = false
                        pendingPlantToPlace = nil
                    }) {
                        Text("Cancel")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.8), in: Capsule())
                    }
                    .padding(.bottom, 20)
                }
            }

            // UI Overlays (hide during placement)
            VStack(spacing: 0) {
                // Top: Garden name (if multiple gardens)
                if let garden = gardenViewModel.selectedGarden {
                    HStack {
                        Text(garden.icon)
                            .font(.title2)
                        Text(garden.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                Spacer()

                // Bottom: Plant carousel + Stats
                VStack(spacing: 12) {
                    // Plant quick-select carousel
                    if !plants.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(plants) { plant in
                                    PlantPillButton(
                                        plant: plant,
                                        isSelected: selectedPlantID == plant.id
                                    ) {
                                        selectedPlantID = plant.id
                                        HapticManager.shared.impact(style: .light)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Stats bar
                    HStack(spacing: 16) {
                        DioramaStatPill(
                            icon: "leaf.fill",
                            value: "\(plants.count)",
                            label: "Plants"
                        )

                        DioramaStatPill(
                            icon: "heart.fill",
                            value: "\(Int(averageHealth * 100))%",
                            label: "Health"
                        )

                        DioramaStatPill(
                            icon: "clock.fill",
                            value: totalFocusTimeString,
                            label: "Focus"
                        )

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Computed Properties

    private var averageHealth: Double {
        let plants = gardenViewModel.plants
        guard !plants.isEmpty else { return 1.0 }
        let total = plants.reduce(0.0) { $0 + $1.healthLevel }
        return total / Double(plants.count)
    }

    private var totalFocusTimeString: String {
        let totalSeconds = gardenViewModel.plants.reduce(0.0) { $0 + $1.totalFocusTime }
        let minutes = Int(totalSeconds / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Plant Pill Button

struct PlantPillButton: View {
    let plant: Plant
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(plantEmoji)
                    .font(.system(size: 16))

                Text(plant.name ?? plant.species.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
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
}

// MARK: - Stat Pill

struct DioramaStatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        GardenDioramaView(gardenViewModel: GardenViewModel())
            .frame(height: 450)
            .padding()
    }
}
