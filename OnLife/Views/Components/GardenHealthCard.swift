import SwiftUI

/// Displays overall garden health status with rescue prompt
/// Uses loss aversion to encourage session completion
struct GardenHealthCard: View {
    @ObservedObject var healthManager = PlantHealthManager.shared
    let onTapRescue: () -> Void

    var body: some View {
        if let summary = healthManager.gardenHealthSummary, summary.totalPlants > 0 {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header
                HStack {
                    Text(summary.overallHealth.emoji)
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Garden Health")
                            .font(OnLifeFont.heading3())
                            .foregroundColor(OnLifeColors.textPrimary)

                        Text("\(Int(summary.healthPercentage))% healthy")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }

                    Spacer()

                    // Overall health badge
                    Text(summary.overallHealth.label)
                        .font(OnLifeFont.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(summary.overallHealth.color)
                        )
                }

                // Health breakdown pills
                healthBreakdownView(summary: summary)

                // Warning/Action section
                if summary.criticalPlants > 0 {
                    rescueButton(criticalCount: summary.criticalPlants)
                } else if summary.wiltingPlants > 0 {
                    wiltingWarning(wiltingCount: summary.wiltingPlants)
                }
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
        }
    }

    // MARK: - Health Breakdown

    @ViewBuilder
    private func healthBreakdownView(summary: PlantHealthManager.GardenHealthSummary) -> some View {
        HStack(spacing: Spacing.sm) {
            if summary.thrivingPlants > 0 {
                HealthPill(count: summary.thrivingPlants, state: .thriving)
            }
            if summary.healthyPlants > 0 {
                HealthPill(count: summary.healthyPlants, state: .healthy)
            }
            if summary.wiltingPlants > 0 {
                HealthPill(count: summary.wiltingPlants, state: .wilting)
            }
            if summary.criticalPlants > 0 {
                HealthPill(count: summary.criticalPlants, state: .critical)
            }
            Spacer()
        }
    }

    // MARK: - Rescue Button

    @ViewBuilder
    private func rescueButton(criticalCount: Int) -> some View {
        Button(action: onTapRescue) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16))

                Text("Rescue \(criticalCount) plant\(criticalCount > 1 ? "s" : "") now!")
                    .font(OnLifeFont.bodySmall())
                    .fontWeight(.semibold)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
            }
            .foregroundColor(.white)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(OnLifeColors.error)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Wilting Warning

    @ViewBuilder
    private func wiltingWarning(wiltingCount: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(OnLifeColors.warning)
                .font(.system(size: 14))

            Text("\(wiltingCount) plant\(wiltingCount > 1 ? "s" : "") need\(wiltingCount == 1 ? "s" : "") attention soon")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Health Pill

struct HealthPill: View {
    let count: Int
    let state: PlantHealthState

    var body: some View {
        HStack(spacing: 4) {
            Text(state.emoji)
                .font(.system(size: 12))

            Text("\(count)")
                .font(OnLifeFont.caption())
                .fontWeight(.semibold)
        }
        .foregroundColor(state.color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(state.color.opacity(0.15))
        )
    }
}

// MARK: - Compact Garden Health Indicator

struct GardenHealthCompactIndicator: View {
    @ObservedObject var healthManager = PlantHealthManager.shared

    var body: some View {
        if let summary = healthManager.gardenHealthSummary, summary.totalPlants > 0 {
            HStack(spacing: Spacing.sm) {
                Text(summary.overallHealth.emoji)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(Int(summary.healthPercentage))%")
                        .font(OnLifeFont.bodySmall())
                        .fontWeight(.bold)
                        .foregroundColor(summary.overallHealth.color)

                    Text("healthy")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                if summary.criticalPlants > 0 {
                    Circle()
                        .fill(OnLifeColors.error)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(OnLifeColors.cardBackground)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                Text("Garden Health Cards")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                // Simulated healthy state
                GardenHealthCard(onTapRescue: {})

                // Compact indicator
                GardenHealthCompactIndicator()

                Spacer()
            }
            .padding()
        }
    }
    .onAppear {
        // Add some test plants
        PlantHealthManager.shared.trackPlant("test-1")
        PlantHealthManager.shared.trackPlant("test-2")
        PlantHealthManager.shared.trackPlant("test-3")
    }
}
