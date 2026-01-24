import SwiftUI

struct PlantDetailSheet: View {
    let plant: Plant
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    // Plant visualization
                    plantVisualization
                        .padding(.top, Spacing.lg)

                    // Name and status
                    plantHeader

                    // Stats grid
                    statsGrid
                        .padding(.horizontal, Spacing.lg)

                    // Growth progress bar
                    growthProgressSection
                        .padding(.horizontal, Spacing.lg)

                    // Health history (placeholder for future)
                    if plant.hasScar {
                        recoveryBadge
                            .padding(.horizontal, Spacing.lg)
                    }

                    Spacer(minLength: Spacing.xxl)
                }
            }
            .background(OnLifeColors.deepForest.ignoresSafeArea())
            .navigationTitle("Plant Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(OnLifeColors.sage)
                }
            }
        }
    }

    // MARK: - Plant Visualization

    private var plantVisualization: some View {
        ZStack {
            // Glowing background circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            healthColor.opacity(0.3),
                            healthColor.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)

            // Plant emoji
            Text(plant.species.emoji)
                .font(.system(size: 80))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
    }

    // MARK: - Plant Header

    private var plantHeader: some View {
        VStack(spacing: Spacing.sm) {
            Text(plant.species.displayName)
                .font(OnLifeFont.heading1())
                .foregroundColor(OnLifeColors.textPrimary)

            HStack(spacing: Spacing.sm) {
                Image(systemName: healthIcon)
                    .foregroundColor(healthColor)
                Text(healthStatus)
                    .foregroundColor(healthColor)
            }
            .font(OnLifeFont.body())

            // Seed type badge
            HStack(spacing: Spacing.xs) {
                Text(plant.seedType.icon)
                Text(plant.seedType.displayName)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(OnLifeColors.cardBackground)
            .cornerRadius(CornerRadius.small)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: Spacing.md) {
            PlantStatCard(
                icon: "leaf.fill",
                label: "Growth",
                value: "\(Int(plant.growthProgress * 100))%",
                color: OnLifeColors.healthy
            )

            PlantStatCard(
                icon: "heart.fill",
                label: "Health",
                value: "\(Int(plant.healthLevel * 100))%",
                color: healthColor
            )

            PlantStatCard(
                icon: "calendar",
                label: "Age",
                value: plantAge,
                color: OnLifeColors.sage
            )

            PlantStatCard(
                icon: "flame.fill",
                label: "Focus Time",
                value: focusTimeFormatted,
                color: OnLifeColors.amber
            )
        }
    }

    // MARK: - Growth Progress Section

    private var growthProgressSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("GROWTH PROGRESS")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .tracking(1.2)

            VStack(spacing: Spacing.sm) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 6)
                            .fill(OnLifeColors.surface)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [OnLifeColors.sage, OnLifeColors.healthy],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * plant.growthProgress)
                    }
                }
                .frame(height: 12)

                // Labels
                HStack {
                    Label("Seed", systemImage: "leaf")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                    Spacer()
                    Label("Mature", systemImage: "tree")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }
            .padding(Spacing.md)
            .background(OnLifeColors.cardBackground)
            .cornerRadius(CornerRadius.card)
        }
    }

    // MARK: - Recovery Badge

    private var recoveryBadge: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "bandage.fill")
                .foregroundColor(OnLifeColors.amber)

            VStack(alignment: .leading, spacing: 2) {
                Text("Recovered Plant")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textPrimary)
                Text("This plant recovered from a period of neglect")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(OnLifeColors.amber.opacity(0.1))
        .cornerRadius(CornerRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .stroke(OnLifeColors.amber.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Computed Properties

    private var healthIcon: String {
        switch plant.healthStatus {
        case .thriving: return "heart.fill"
        case .healthy: return "heart.fill"
        case .stressed: return "heart.slash"
        case .wilting: return "heart.slash.fill"
        case .dead: return "xmark.circle.fill"
        }
    }

    private var healthColor: Color {
        switch plant.healthStatus {
        case .thriving: return OnLifeColors.healthy
        case .healthy: return OnLifeColors.sage
        case .stressed: return OnLifeColors.amber
        case .wilting: return OnLifeColors.terracotta
        case .dead: return OnLifeColors.textTertiary
        }
    }

    private var healthStatus: String {
        plant.healthStatus.displayName
    }

    private var plantAge: String {
        guard let planted = plant.plantedDate else { return "New" }
        let days = Calendar.current.dateComponents([.day], from: planted, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "1 day" }
        return "\(days) days"
    }

    private var focusTimeFormatted: String {
        let minutes = plant.focusMinutes
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Plant Stat Card

struct PlantStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)

            Text(value)
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(OnLifeColors.cardBackground)
        .cornerRadius(CornerRadius.card)
    }
}

// MARK: - Preview

#if DEBUG
struct PlantDetailSheet_Previews: PreviewProvider {
    static var previews: some View {
        PlantDetailSheet(
            plant: Plant(
                gardenId: UUID(),
                sessionId: UUID(),
                species: .rose,
                seedType: .recurring,
                health: 85,
                growthStage: 7
            )
        )
        .preferredColorScheme(.dark)
    }
}
#endif
