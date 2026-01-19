import SwiftUI

/// An animated plant view that displays organic growth with swaying, glowing, and transition effects
struct AnimatedPlantView: View {
    let growthStage: Int          // 0-10 (matches FocusSessionViewModel)
    let plantSpecies: PlantSpecies
    let isWilting: Bool
    let isPaused: Bool

    @State private var sway: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var glowPulse: Double = 0
    @State private var showGrowthParticles = false
    @State private var previousStage: Int = 0

    private var plantEmoji: String {
        if growthStage < 3 {
            return "🌱" // Seed/sprout
        } else if growthStage < 7 {
            return "🪴" // Young plant
        } else {
            return plantSpecies.icon // Mature - use species icon
        }
    }

    private var healthFactor: Double {
        isWilting ? 0.5 : 1.0
    }

    private var glowOpacity: Double {
        guard !isWilting && !isPaused else { return 0.1 }
        let baseGlow = Double(growthStage) / 10.0 * 0.4
        return baseGlow + glowPulse * 0.1
    }

    var body: some View {
        ZStack {
            // Ambient glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            OnLifeColors.sage.opacity(glowOpacity),
                            OnLifeColors.sage.opacity(0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 25)
                .opacity(isPaused ? 0.3 : 1.0)

            // Growth particles (shown on stage transitions)
            if showGrowthParticles {
                GrowthParticleEmitter()
                    .transition(.opacity)
            }

            // The plant itself
            Text(plantEmoji)
                .font(.system(size: 100))
                .scaleEffect(scale)
                .rotationEffect(.degrees(sway))
                .offset(y: isWilting ? 15 : 0)
                .opacity(isWilting ? 0.6 : 1.0)
                .saturation(healthFactor)
                .brightness(isPaused ? -0.1 : 0)
        }
        .onAppear {
            previousStage = growthStage
            startSwayAnimation()
            startGlowPulse()
        }
        .onChange(of: growthStage) { oldStage, newStage in
            if newStage > oldStage {
                playGrowthTransition()
            }
            previousStage = newStage
        }
        .onChange(of: isPaused) { _, paused in
            if paused {
                // Stop swaying when paused
                withAnimation(.easeOut(duration: 0.5)) {
                    sway = 0
                }
            } else {
                // Resume swaying
                startSwayAnimation()
            }
        }
        .onChange(of: isWilting) { _, wilting in
            if wilting {
                // Droop animation
                withAnimation(.easeOut(duration: 0.3)) {
                    sway = 0
                    scale = 0.95
                }
            } else {
                // Recovery animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    scale = 1.0
                }
                startSwayAnimation()
            }
        }
    }

    // MARK: - Animations

    /// Gentle swaying animation for alive feeling
    private func startSwayAnimation() {
        guard !isWilting && !isPaused else { return }

        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            sway = 4.0
        }
    }

    /// Subtle glow pulse
    private func startGlowPulse() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            glowPulse = 1.0
        }
    }

    /// Plays satisfying animation when advancing to next growth stage
    private func playGrowthTransition() {
        // Haptic feedback
        HapticManager.shared.impact(style: .medium)

        // Show particles
        withAnimation(.easeIn(duration: 0.1)) {
            showGrowthParticles = true
        }

        // Anticipation - shrink slightly
        withAnimation(.easeOut(duration: 0.15)) {
            scale = 0.9
        }

        // Growth burst - expand dramatically
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                scale = 1.2
            }
        }

        // Settle back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                scale = 1.0
            }
        }

        // Hide particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showGrowthParticles = false
            }
        }
    }
}

// MARK: - Growth Particle Emitter

struct GrowthParticleEmitter: View {
    @State private var particles: [GrowthParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            generateParticles()
        }
    }

    private func generateParticles() {
        let colors: [Color] = [
            OnLifeColors.sage,
            OnLifeColors.sage.opacity(0.7),
            OnLifeColors.amber,
            .green,
            .yellow.opacity(0.8)
        ]

        for i in 0..<15 {
            let delay = Double(i) * 0.03

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                var particle = GrowthParticle(
                    x: 0,
                    y: 0,
                    targetX: CGFloat.random(in: -80...80),
                    targetY: CGFloat.random(in: -100...(-20)),
                    color: colors.randomElement()!,
                    size: CGFloat.random(in: 4...10),
                    opacity: 1.0
                )

                particles.append(particle)

                // Animate outward
                withAnimation(.easeOut(duration: 0.8)) {
                    if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                        particles[index].x = particle.targetX
                        particles[index].y = particle.targetY
                    }
                }

                // Fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                            particles[index].opacity = 0
                        }
                    }
                }
            }
        }
    }
}

struct GrowthParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var targetX: CGFloat
    var targetY: CGFloat
    var color: Color
    var size: CGFloat
    var opacity: Double
}

// MARK: - Preview

#Preview {
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        VStack(spacing: 40) {
            AnimatedPlantView(
                growthStage: 5,
                plantSpecies: .oak,
                isWilting: false,
                isPaused: false
            )

            Text("Growth Stage: 5/10")
                .foregroundColor(.white)
        }
    }
}
