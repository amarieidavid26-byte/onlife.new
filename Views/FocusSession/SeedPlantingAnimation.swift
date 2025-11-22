import SwiftUI

struct SeedPlantingAnimation: View {
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0
    @State private var yOffset: CGFloat = -300
    @State private var showParticles: Bool = false

    var body: some View {
        ZStack {
            VStack(spacing: Spacing.xl) {
                Spacer()

                ZStack {
                    // Particle burst effect
                    if showParticles {
                        ParticleBurst()
                    }

                    // Seed emoji with animations
                    Text("🌱")
                        .font(.system(size: 100))
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .rotationEffect(.degrees(rotation))
                        .offset(y: yOffset)
                }

                Text("Planting your seed...")
                    .font(AppFont.heading2())
                    .foregroundColor(AppColors.textPrimary)
                    .opacity(opacity)

                Spacer()
            }
        }
        .onAppear {
            // 0.0s: Seed appears at top (scale 0)
            HapticManager.shared.impact(style: .light)

            // 0.5s: Seed scales to 1.2 while falling
            withAnimation(.easeOut(duration: 0.5)) {
                scale = 1.2
                opacity = 1.0
            }

            // 1.5s: Seed rotates 360 degrees
            withAnimation(.easeInOut(duration: 1.5)) {
                rotation = 360
                yOffset = 0
            }

            // 2.5s: Seed lands, scales to 1.0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(2.5)) {
                scale = 1.0
            }

            // 2.5s: Haptic feedback on land
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                HapticManager.shared.impact(style: .medium)
            }

            // 2.7s: Burst of particles
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                showParticles = true
                HapticManager.shared.impact(style: .heavy)
            }
        }
    }
}

// MARK: - Particle Burst Effect
struct ParticleBurst: View {
    @State private var particleOpacity: Double = 1.0
    @State private var particleScale: CGFloat = 0.5

    var body: some View {
        ZStack {
            ForEach(0..<8) { index in
                Circle()
                    .fill(particleColor(index))
                    .frame(width: 8, height: 8)
                    .scaleEffect(particleScale)
                    .opacity(particleOpacity)
                    .offset(particleOffset(index))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                particleScale = 1.5
                particleOpacity = 0
            }
        }
    }

    func particleOffset(_ index: Int) -> CGSize {
        let angle = Double(index) * 45.0 * .pi / 180.0
        let distance: CGFloat = 40.0
        let x = cos(angle) * distance
        let y = sin(angle) * distance
        return CGSize(width: x, height: y)
    }

    func particleColor(_ index: Int) -> Color {
        let colors = [AppColors.healthy, AppColors.thriving, Color.yellow, Color.green]
        return colors[index % colors.count]
    }
}
