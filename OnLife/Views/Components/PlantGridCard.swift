import SwiftUI

struct PlantGridCard: View {
    let plant: Plant
    var onTap: (() -> Void)? = nil

    @State private var appeared = false

    // Calculate health color based on percentage
    private var healthColor: Color {
        switch plant.health {
        case 80...100: return OnLifeColors.sage
        case 50..<80: return Color.yellow.opacity(0.9)
        case 20..<50: return Color.orange
        default: return OnLifeColors.terracotta
        }
    }

    // Calculate overlay for wilting/dead states
    private var stateOverlay: Color {
        switch plant.health {
        case 80...100: return .clear
        case 50..<80: return Color.yellow.opacity(0.03)
        case 20..<50: return Color.orange.opacity(0.05)
        default: return Color.gray.opacity(0.15)
        }
    }

    // Saturation based on health
    private var saturation: Double {
        plant.health >= 50 ? 1.0 : 0.6
    }

    // Health status text
    private var statusText: String {
        switch plant.healthStatus {
        case .thriving: return "Thriving"
        case .healthy: return "Healthy"
        case .stressed: return "Stressed"
        case .wilting: return "Wilting"
        case .dead: return "Withered"
        }
    }

    var body: some View {
        Button(action: {
            Haptics.selection()
            onTap?()
        }) {
            VStack(spacing: Spacing.sm) {
                // Plant image area with health ring
                ZStack {
                    // Background circle
                    Circle()
                        .fill(OnLifeColors.surface.opacity(0.5))
                        .frame(width: 72, height: 72)

                    // Health progress ring background
                    Circle()
                        .stroke(OnLifeColors.surface, lineWidth: 4)
                        .frame(width: 80, height: 80)

                    // Health progress ring
                    Circle()
                        .trim(from: 0, to: CGFloat(plant.health) / 100)
                        .stroke(healthColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: plant.health)

                    // Plant emoji
                    Text(plant.species.icon)
                        .font(.system(size: 40))
                        .saturation(saturation)
                }
                .padding(.top, Spacing.md)

                Spacer()

                // Plant name
                Text(plant.species.displayName)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .lineLimit(1)

                // Health percentage with status dot
                HStack(spacing: 6) {
                    Circle()
                        .fill(healthColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: healthColor.opacity(0.5), radius: 3)

                    Text("\(Int(plant.health))%")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
                .padding(.bottom, Spacing.md)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(stateOverlay)
            )
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 6,
                y: 3
            )
        }
        .buttonStyle(PlantCardButtonStyle())
        .scaleEffect(appeared ? 1.0 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(OnLifeAnimation.standard) {
                appeared = true
            }
        }
    }
}

// MARK: - Button Style

struct PlantCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
