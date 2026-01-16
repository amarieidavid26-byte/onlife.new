import SwiftUI

struct GardenCarouselCard: View {
    let garden: Garden
    let plantCount: Int
    let totalFocusTime: String
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: (() -> Void)?

    // Get preview plants (first 4)
    private var previewPlants: [Plant] {
        Array(garden.plants.prefix(4))
    }

    var body: some View {
        Button(action: {
            Haptics.selection()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Top row: Icon, Name, Stats
                HStack(alignment: .top) {
                    // Garden icon
                    Text(garden.icon)
                        .font(.system(size: 40))
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(garden.name)
                            .font(OnLifeFont.heading2())
                            .foregroundColor(OnLifeColors.textPrimary)
                            .lineLimit(1)

                        Text("\(plantCount) plants")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }

                    Spacer()

                    // Focus time stats
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(totalFocusTime)
                            .font(OnLifeFont.heading3())
                            .foregroundColor(OnLifeColors.sage)

                        Text("focus time")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                }

                // Bottom: Plant preview thumbnails
                if !previewPlants.isEmpty {
                    HStack(spacing: Spacing.xs) {
                        ForEach(previewPlants) { plant in
                            PlantThumbnail(plant: plant)
                        }

                        if garden.plants.count > 4 {
                            Text("+\(garden.plants.count - 4)")
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textTertiary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(OnLifeColors.surface)
                                )
                        }

                        Spacer()
                    }
                    .padding(.top, Spacing.xs)
                } else {
                    // Empty garden hint
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "leaf")
                            .font(.system(size: 12))
                            .foregroundColor(OnLifeColors.textTertiary)

                        Text("Start focusing to grow plants!")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                    .padding(.top, Spacing.xs)
                }
            }
            .padding(Spacing.lg)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected ? OnLifeColors.sage : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: Color.black.opacity(isSelected ? 0.2 : 0.12),
                radius: isSelected ? 12 : 8,
                y: isSelected ? 6 : 4
            )
        }
        .buttonStyle(GardenCarouselCardButtonStyle(isSelected: isSelected))
        .contextMenu {
            Button(action: {
                onEdit()
            }) {
                Label("Edit Garden", systemImage: "pencil")
            }

            if let onDelete = onDelete {
                Button(role: .destructive, action: {
                    onDelete()
                }) {
                    Label("Delete Garden", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Plant Thumbnail

private struct PlantThumbnail: View {
    let plant: Plant

    var body: some View {
        Text(plantEmoji(for: plant.species))
            .font(.system(size: 14))
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(OnLifeColors.cardBackgroundElevated)
            )
            .overlay(
                Circle()
                    .stroke(healthColor(for: plant.healthStatus).opacity(0.5), lineWidth: 1.5)
            )
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
        case .thriving, .healthy:
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

// MARK: - Button Style

struct GardenCarouselCardButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : (isSelected ? 1.02 : 1.0))
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
