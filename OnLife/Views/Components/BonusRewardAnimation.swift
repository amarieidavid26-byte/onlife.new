import SwiftUI

/// Animated celebration overlay for variable reward bonuses
/// Research: Variable rewards activate dopamine 2-3x more than predictable rewards
struct BonusRewardAnimation: View {
    let result: VariableRewardSystem.VariableRewardResult
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    @State private var emojiScale: CGFloat = 0.5
    @State private var emojiRotation: Double = 0
    @State private var labelOpacity: Double = 0
    @State private var multiplierScale: CGFloat = 0
    @State private var orbsVisible = false
    @State private var confettiVisible = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .opacity(opacity)
                .onTapGesture {
                    dismissAnimation()
                }

            // Confetti layer
            if confettiVisible && result.celebrationLevel != .standard {
                BonusConfettiView(level: result.celebrationLevel)
            }

            // Main bonus card
            VStack(spacing: Spacing.lg) {
                // Celebration emoji
                Text(result.celebrationLevel.emoji)
                    .font(.system(size: 80))
                    .scaleEffect(emojiScale)
                    .rotationEffect(.degrees(emojiRotation))

                if result.wasBonus {
                    // Bonus label
                    Text(result.celebrationLevel.label)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(labelOpacity)

                    // Multiplier badge
                    if let multiplier = result.multiplier {
                        Text("\(String(format: "%.1f", multiplier))x MULTIPLIER!")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [OnLifeColors.amber, OnLifeColors.terracotta],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .scaleEffect(multiplierScale)
                    }

                    // Orbs comparison
                    if orbsVisible {
                        orbsComparisonView
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Celebration message
                if let message = result.celebrationMessage {
                    Text(message)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(labelOpacity)
                }

                // Tap to dismiss hint
                Text("Tap anywhere to continue")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .opacity(labelOpacity * 0.7)
                    .padding(.top, Spacing.md)
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackgroundElevated)
                    .shadow(color: shadowColor.opacity(0.4), radius: 30, y: 10)
            )
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Orbs Comparison View

    @ViewBuilder
    private var orbsComparisonView: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                // Base orbs (crossed out)
                Text("\(result.baseOrbs)")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .strikethrough(color: OnLifeColors.textTertiary)
                    .foregroundColor(OnLifeColors.textTertiary)

                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(OnLifeColors.sage)

                // Total orbs (highlighted)
                HStack(spacing: 4) {
                    Text("\(result.totalOrbs)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(OnLifeColors.sage)

                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(OnLifeColors.amber)
                }
            }

            // Bonus amount
            Text("+\(result.bonusOrbs) bonus orbs!")
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.sage)
        }
    }

    // MARK: - Gradient Colors

    private var gradientColors: [Color] {
        switch result.celebrationLevel {
        case .standard:
            return [OnLifeColors.textPrimary, OnLifeColors.textSecondary]
        case .bonus:
            return [OnLifeColors.amber, .orange]
        case .great:
            return [.orange, OnLifeColors.terracotta]
        case .epic:
            return [.purple, .pink]
        case .legendary:
            return [OnLifeColors.amber, .red, .orange]
        }
    }

    private var shadowColor: Color {
        switch result.celebrationLevel {
        case .standard: return .black
        case .bonus: return OnLifeColors.amber
        case .great: return .orange
        case .epic: return .purple
        case .legendary: return OnLifeColors.amber
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        // Trigger haptics
        VariableRewardSystem.shared.triggerCelebrationHaptics(level: result.celebrationLevel)

        // Card fade in
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 1.0
            opacity = 1.0
        }

        // Emoji pop
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.1)) {
            emojiScale = 1.3
        }

        // Emoji settle
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.4)) {
            emojiScale = 1.0
        }

        // Emoji rotation for bonus
        if result.wasBonus {
            withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
                emojiRotation = 360
            }
        }

        // Label fade in
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            labelOpacity = 1.0
        }

        // Multiplier pop
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.5)) {
            multiplierScale = 1.0
        }

        // Orbs appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                orbsVisible = true
            }
        }

        // Confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            confettiVisible = true
        }

        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            dismissAnimation()
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

// MARK: - Bonus Confetti View

struct BonusConfettiView: View {
    let level: VariableRewardSystem.CelebrationLevel
    @State private var particles: [BonusConfettiParticle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    BonusConfettiPiece(
                        particle: particle,
                        screenSize: geometry.size
                    )
                }
            }
        }
        .onAppear {
            generateParticles()
        }
    }

    private func generateParticles() {
        let colors: [Color] = [
            OnLifeColors.sage,
            OnLifeColors.amber,
            OnLifeColors.terracotta,
            .yellow,
            .orange,
            .purple,
            .pink
        ]

        particles = (0..<level.confettiCount).map { _ in
            BonusConfettiParticle(
                color: colors.randomElement()!,
                startX: CGFloat.random(in: 0...1),
                startY: CGFloat.random(in: -0.2...0),
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.2),
                shape: ConfettiShape.allCases.randomElement()!
            )
        }
    }
}

struct BonusConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let startX: CGFloat
    let startY: CGFloat
    let rotation: Double
    let scale: CGFloat
    let shape: ConfettiShape
}

enum ConfettiShape: CaseIterable {
    case rectangle
    case circle
    case star
}

struct BonusConfettiPiece: View {
    let particle: BonusConfettiParticle
    let screenSize: CGSize

    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        Group {
            switch particle.shape {
            case .rectangle:
                Rectangle()
                    .fill(particle.color)
                    .frame(width: 8, height: 12)
            case .circle:
                Circle()
                    .fill(particle.color)
                    .frame(width: 10, height: 10)
            case .star:
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(particle.color)
            }
        }
        .scaleEffect(particle.scale)
        .rotationEffect(.degrees(rotation))
        .position(
            x: screenSize.width * particle.startX + xOffset,
            y: screenSize.height * particle.startY + yOffset
        )
        .opacity(opacity)
        .onAppear {
            let duration = Double.random(in: 2.0...3.5)

            withAnimation(.easeOut(duration: duration)) {
                yOffset = screenSize.height * 1.2
                xOffset = CGFloat.random(in: -100...100)
                rotation = particle.rotation + Double.random(in: 360...1080)
            }

            withAnimation(.easeIn(duration: duration * 0.3).delay(duration * 0.7)) {
                opacity = 0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        VStack {
            Text("Background Content")
                .foregroundColor(OnLifeColors.textPrimary)
        }

        BonusRewardAnimation(
            result: VariableRewardSystem.VariableRewardResult(
                baseOrbs: 15,
                bonusOrbs: 30,
                multiplier: 3.0,
                celebrationMessage: "Excellent focus session!"
            ),
            onDismiss: {}
        )
    }
}
