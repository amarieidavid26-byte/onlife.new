import SwiftUI

struct PlantDetailView: View {
    let plant: Plant
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                OnLifeColors.deepForest
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Plant Display
                        VStack(spacing: Spacing.md) {
                            Text(plantEmoji)
                                .font(.system(size: 100))

                            Text(plant.species.rawValue.capitalized)
                                .font(OnLifeFont.heading2())
                                .foregroundColor(OnLifeColors.textPrimary)

                            // Health indicator
                            HStack(spacing: Spacing.sm) {
                                Text(healthStatusText)
                                    .font(OnLifeFont.label())
                                    .foregroundColor(healthStatusColor)

                                Circle()
                                    .fill(healthStatusColor)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, Spacing.xxl)

                        // Stats Cards
                        VStack(spacing: Spacing.md) {
                            // Created Date
                            StatCard(
                                icon: "calendar",
                                title: "Planted",
                                value: formattedCreatedDate
                            )

                            // Seed Type
                            StatCard(
                                icon: seedTypeIcon,
                                title: "Type",
                                value: plant.seedType == .oneTime ? "One-Time" : "Recurring"
                            )

                            // Health
                            StatCard(
                                icon: "heart.fill",
                                title: "Health",
                                value: "\(Int(plant.health))%"
                            )

                            // Growth Stage
                            StatCard(
                                icon: "arrow.up.circle",
                                title: "Growth",
                                value: "Stage \(plant.growthStage)/10"
                            )

                            // Total Focus Time
                            StatCard(
                                icon: "clock.fill",
                                title: "Total Focus Time",
                                value: totalFocusTime
                            )

                            // Last Session
                            StatCard(
                                icon: "flame.fill",
                                title: "Last Session",
                                value: formatDate(plant.lastSessionDate)
                            )

                            // For recurring plants, show decay info
                            if plant.seedType == .recurring {
                                StatCard(
                                    icon: "drop.fill",
                                    title: "Last Watered",
                                    value: formatDate(plant.lastWateredDate)
                                )

                                StatCard(
                                    icon: "calendar.badge.clock",
                                    title: "Days Since Watering",
                                    value: "\(plant.daysSinceWatering) days"
                                )
                            }
                        }
                        .padding(.horizontal, Spacing.xl)

                        Spacer()
                    }
                }
            }
            .navigationTitle("Plant Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var healthStatusText: String {
        switch plant.healthStatus {
        case .thriving: return "THRIVING"
        case .healthy: return "HEALTHY"
        case .stressed: return "STRESSED"
        case .wilting: return "WILTING"
        case .dead: return "DEAD"
        }
    }

    private var healthStatusColor: Color {
        switch plant.healthStatus {
        case .thriving: return OnLifeColors.thriving
        case .healthy: return OnLifeColors.healthy
        case .stressed: return OnLifeColors.stressed
        case .wilting: return OnLifeColors.wilting
        case .dead: return OnLifeColors.dead
        }
    }

    private var seedTypeIcon: String {
        plant.seedType == .oneTime ? "flower" : "leaf.fill"
    }

    private var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: plant.createdAt)
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
        }
    }

    private var totalFocusTime: String {
        let totalMinutes = Int(plant.totalFocusTime / 60)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours)h \(minutes)m"
        }
        return "\(totalMinutes)m"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - StatCard Component
struct StatCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        CardView {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(OnLifeColors.healthy)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.textSecondary)

                    Text(value)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                }

                Spacer()
            }
            .padding(Spacing.md)
        }
    }
}
