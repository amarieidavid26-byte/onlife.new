import SwiftUI

/// Urgent rescue view for plants in critical state
/// Uses loss aversion psychology - the urgency motivates action
struct PlantRescueView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var healthManager = PlantHealthManager.shared

    let plantsToRescue: [PlantHealth]
    let onStartSession: () -> Void

    @State private var pulseAnimation = false

    var body: some View {
        NavigationView {
            ZStack {
                OnLifeColors.deepForest
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Emergency header
                        emergencyHeader

                        // Plants in danger
                        VStack(spacing: Spacing.md) {
                            ForEach(Array(plantsToRescue.enumerated()), id: \.element.plantId) { index, plant in
                                CriticalPlantCard(plant: plant, index: index + 1)
                            }
                        }

                        // Rescue button
                        rescueButton

                        // Encouragement
                        Text("One focused session will revive all your plants!")
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)

                        Spacer(minLength: Spacing.xxl)
                    }
                    .padding(Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Later") {
                        dismiss()
                    }
                    .foregroundColor(OnLifeColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Emergency Header

    @ViewBuilder
    private var emergencyHeader: some View {
        VStack(spacing: Spacing.md) {
            // Pulsing emergency icon
            ZStack {
                Circle()
                    .fill(OnLifeColors.error.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0.5 : 1.0)

                Circle()
                    .fill(OnLifeColors.error.opacity(0.3))
                    .frame(width: 100, height: 100)

                Text("🚨")
                    .font(.system(size: 50))
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }

            Text("Garden Emergency!")
                .font(OnLifeFont.heading1())
                .foregroundColor(OnLifeColors.textPrimary)

            Text("\(plantsToRescue.count) plant\(plantsToRescue.count > 1 ? "s" : "") need\(plantsToRescue.count == 1 ? "s" : "") immediate attention")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Rescue Button

    @ViewBuilder
    private var rescueButton: some View {
        Button(action: {
            dismiss()
            onStartSession()
        }) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 20))

                Text("Start Rescue Session")
                    .font(OnLifeFont.button())

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
            }
            .foregroundColor(.white)
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [OnLifeColors.sage, OnLifeColors.leaf],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Critical Plant Card

struct CriticalPlantCard: View {
    let plant: PlantHealth
    let index: Int

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Priority number
            Text("\(index)")
                .font(OnLifeFont.heading3())
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(OnLifeColors.error)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.xs) {
                    Text("Plant")
                        .font(OnLifeFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(plant.healthState.emoji)
                        .font(.system(size: 16))
                }

                Text("\(plant.daysNeglected) days without care")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()

            // Health state badge
            Text(plant.healthState.label)
                .font(OnLifeFont.caption())
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(plant.healthState.color)
                )
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .opacity(plant.healthState.visualOpacity)
    }
}

// MARK: - Rescue Celebration View

struct PlantRescueCelebration: View {
    let rescuedCount: Int
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var confettiVisible = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .opacity(opacity)
                .onTapGesture { dismissAnimation() }

            // Celebration card
            VStack(spacing: Spacing.lg) {
                Text("💚")
                    .font(.system(size: 80))

                Text("Plants Rescued!")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("You saved \(rescuedCount) plant\(rescuedCount > 1 ? "s" : "") from wilting!")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)

                Text("They're recovering and will be thriving soon.")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .multilineTextAlignment(.center)

                Button("Continue") {
                    dismissAnimation()
                }
                .font(OnLifeFont.button())
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
                .background(
                    Capsule()
                        .fill(OnLifeColors.sage)
                )
                .padding(.top, Spacing.md)
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackgroundElevated)
            )
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            HapticManager.shared.notification(type: .success)
        }
    }

    private func dismissAnimation() {
        withAnimation(.easeIn(duration: 0.2)) {
            scale = 0.8
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    let testPlants = [
        PlantHealth(plantId: "test-1", lastCaredFor: Calendar.current.date(byAdding: .day, value: -7, to: Date())!, healthState: .critical, daysNeglected: 7, rescueCount: 0),
        PlantHealth(plantId: "test-2", lastCaredFor: Calendar.current.date(byAdding: .day, value: -8, to: Date())!, healthState: .critical, daysNeglected: 8, rescueCount: 1)
    ]

    return PlantRescueView(
        plantsToRescue: testPlants,
        onStartSession: {}
    )
}
