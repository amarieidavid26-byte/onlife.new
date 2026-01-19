import SwiftUI

/// Animated orb counter that counts up to target value
/// Creates anticipation and excitement during reward reveal
struct OrbCounterAnimation: View {
    let targetValue: Int
    let duration: Double
    let showIcon: Bool
    let color: Color

    @State private var currentValue: Int = 0
    @State private var scale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0

    init(
        targetValue: Int,
        duration: Double = 1.5,
        showIcon: Bool = true,
        color: Color = OnLifeColors.sage
    ) {
        self.targetValue = targetValue
        self.duration = duration
        self.showIcon = showIcon
        self.color = color
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if showIcon {
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .blur(radius: 8)
                        .opacity(glowOpacity)

                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundColor(color)
                        .scaleEffect(scale)
                }
            }

            Text("\(currentValue)")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentValue)
        }
        .onAppear {
            animateCount()
        }
    }

    private func animateCount() {
        guard targetValue > 0 else {
            currentValue = 0
            return
        }

        let steps = min(30, targetValue)
        let interval = duration / Double(steps)

        // Ease-out curve for more exciting finish
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                let progress = Double(i) / Double(steps)
                // Ease-out cubic
                let easedProgress = 1 - pow(1 - progress, 3)
                currentValue = Int(Double(targetValue) * easedProgress)

                // Pulse animation on each step
                withAnimation(.easeInOut(duration: 0.08)) {
                    scale = 1.15
                    glowOpacity = 0.8
                }
                withAnimation(.easeInOut(duration: 0.08).delay(0.08)) {
                    scale = 1.0
                    glowOpacity = 0.3
                }

                // Haptic on every 5th step
                if i % 5 == 0 && i > 0 {
                    HapticManager.shared.impact(style: .light)
                }
            }
        }

        // Final value and celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            currentValue = targetValue
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                scale = 1.25
                glowOpacity = 1.0
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.2)) {
                scale = 1.0
                glowOpacity = 0.5
            }
            HapticManager.shared.notification(type: .success)
        }
    }
}

/// Compact orb counter for inline display
struct CompactOrbCounter: View {
    let value: Int
    let animated: Bool
    let size: CounterSize

    @State private var displayValue: Int = 0

    enum CounterSize {
        case small
        case medium
        case large

        var fontSize: CGFloat {
            switch self {
            case .small: return 18
            case .medium: return 24
            case .large: return 32
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 18
            case .large: return 24
            }
        }
    }

    init(value: Int, animated: Bool = true, size: CounterSize = .medium) {
        self.value = value
        self.animated = animated
        self.size = size
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: size.iconSize))
                .foregroundColor(OnLifeColors.amber)

            Text("\(displayValue)")
                .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                .foregroundColor(OnLifeColors.textPrimary)
                .contentTransition(.numericText())
        }
        .onAppear {
            if animated {
                animateValue()
            } else {
                displayValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            if animated {
                animateToValue(newValue)
            } else {
                displayValue = newValue
            }
        }
    }

    private func animateValue() {
        displayValue = 0
        animateToValue(value)
    }

    private func animateToValue(_ target: Int) {
        let steps = 20
        let duration: Double = 0.8
        let interval = duration / Double(steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                let progress = Double(i) / Double(steps)
                let easedProgress = 1 - pow(1 - progress, 2)
                withAnimation(.easeOut(duration: 0.05)) {
                    displayValue = Int(Double(target) * easedProgress)
                }
            }
        }
    }
}

/// Orb reward display with optional bonus indicator
struct OrbRewardDisplay: View {
    let baseOrbs: Int
    let bonusOrbs: Int
    let wasBonus: Bool

    @State private var showBonus = false

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                // Orb icon with glow
                ZStack {
                    if wasBonus {
                        Circle()
                            .fill(OnLifeColors.amber.opacity(0.3))
                            .frame(width: 56, height: 56)
                            .blur(radius: 10)
                    }

                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(wasBonus ? OnLifeColors.amber : OnLifeColors.sage)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("+\(baseOrbs + bonusOrbs)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(wasBonus ? OnLifeColors.amber : OnLifeColors.sage)

                        Text("orbs")
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }

                    if wasBonus && showBonus {
                        HStack(spacing: 4) {
                            Text("Includes")
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textTertiary)

                            Text("+\(bonusOrbs) bonus!")
                                .font(OnLifeFont.caption())
                                .fontWeight(.semibold)
                                .foregroundColor(OnLifeColors.amber)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            if wasBonus {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showBonus = true
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        VStack(spacing: Spacing.xxl) {
            Text("Orb Counter Animations")
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)

            // Large animated counter
            OrbCounterAnimation(targetValue: 45, duration: 2.0)

            Divider()
                .background(OnLifeColors.textTertiary.opacity(0.3))

            // Compact counters
            HStack(spacing: Spacing.xl) {
                CompactOrbCounter(value: 125, size: .small)
                CompactOrbCounter(value: 250, size: .medium)
                CompactOrbCounter(value: 500, size: .large)
            }

            Divider()
                .background(OnLifeColors.textTertiary.opacity(0.3))

            // Reward displays
            VStack(spacing: Spacing.lg) {
                OrbRewardDisplay(baseOrbs: 15, bonusOrbs: 0, wasBonus: false)

                OrbRewardDisplay(baseOrbs: 15, bonusOrbs: 30, wasBonus: true)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(OnLifeColors.cardBackground)
            )
        }
        .padding()
    }
}
