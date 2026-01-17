import SwiftUI

struct SessionCompletedScreen: View {
    @ObservedObject var viewModel: FocusSessionViewModel
    @State private var plantScale: CGFloat = 0.8
    @State private var showConfetti: Bool = false
    @State private var showSparkles: Bool = false
    @State private var showRewards: Bool = false
    @State private var orbsAnimated: Int = 0

    var body: some View {
        ZStack {
            // Confetti layer
            if showConfetti {
                ConfettiView()
            }

            VStack(spacing: Spacing.xxxl) {
                Spacer()

                VStack(spacing: Spacing.xl) {
                    ZStack {
                        // Sparkle effects
                        if showSparkles {
                            SparkleEffect()
                        }

                        // Blooming plant with animation
                        Text(viewModel.selectedPlantSpecies.icon)
                            .font(.system(size: 100))
                            .scaleEffect(plantScale)
                    }

                    Text("Session Complete!")
                        .font(OnLifeFont.heading1())
                        .foregroundColor(OnLifeColors.textPrimary)

                    // Flow Score Display
                    if viewModel.averageFlowScore > 0 {
                        HStack(spacing: Spacing.xs) {
                            Text("🧠")
                                .font(.system(size: 20))
                            Text("Flow Score: \(Int(viewModel.averageFlowScore))%")
                                .font(OnLifeFont.heading3())
                                .foregroundColor(viewModel.averageFlowScore >= 70 ? OnLifeColors.sage : OnLifeColors.textSecondary)
                        }
                    }

                // Rewards Section (NEW)
                if showRewards, let reward = viewModel.sessionReward {
                    rewardsSection(reward: reward)
                        .transition(.opacity.combined(with: .scale))
                }

                VStack(spacing: Spacing.md) {
                    StatRow(label: "Task", value: viewModel.taskDescription)
                    StatRow(label: "Duration", value: "\(viewModel.selectedDuration) min")
                    StatRow(label: "Plant", value: viewModel.selectedPlantSpecies.displayName)
                    StatRow(label: "Growth", value: "Stage \(viewModel.plantGrowthStage)/10")
                }
                .padding(.horizontal, Spacing.xl)
            }

            Spacer()

            PrimaryButton(title: "Back to Garden") {
                viewModel.resetSession()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)
            }
        }
        .onAppear {
            // Bloom animation sequence
            AudioManager.shared.play(.success, volume: 0.8)

            // 1. Plant blooms (scale up)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                plantScale = 1.3
            }

            // 2. Spring back to normal
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                plantScale = 1.0
            }

            // 3. Show sparkles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showSparkles = true
            }

            // 4. Show confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showConfetti = true
                HapticManager.shared.notification(type: .success)
            }

            // 5. Heavy haptic sequence
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                HapticManager.shared.impact(style: .heavy)
            }

            // 6. Show rewards with animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showRewards = true
                }
                // Animate orbs counter
                animateOrbsCounter()
            }
        }
    }

    // MARK: - Rewards Section

    @ViewBuilder
    private func rewardsSection(reward: SessionRewardResult) -> some View {
        VStack(spacing: Spacing.md) {
            // Orbs Earned
            HStack(spacing: Spacing.sm) {
                Text("✨")
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("+\(orbsAnimated) orbs")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.amber)

                    if reward.hasBonus {
                        Text("Includes \(reward.bonusOrbs) bonus!")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.sage)
                    }
                }

                Spacer()
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.amber.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .stroke(OnLifeColors.amber.opacity(0.3), lineWidth: 1)
            )

            // Special Rewards (if any)
            if !reward.specialRewards.isEmpty {
                ForEach(reward.specialRewards, id: \.self) { rewardType in
                    specialRewardCard(type: rewardType)
                }
            }

            // Celebration Message (if any)
            if let message = reward.celebrationMessage {
                Text(message)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.sm)
            }
        }
        .padding(.horizontal, Spacing.xl)
    }

    @ViewBuilder
    private func specialRewardCard(type: RewardType) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(type.icon)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(type.description)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.sage.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .stroke(OnLifeColors.sage.opacity(0.3), lineWidth: 1)
        )
    }

    private func animateOrbsCounter() {
        guard let reward = viewModel.sessionReward else { return }
        let targetOrbs = reward.totalOrbs
        let duration: Double = 1.0
        let steps = 20
        let interval = duration / Double(steps)

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(step)) {
                let progress = Double(step) / Double(steps)
                // Ease-out curve
                let easedProgress = 1 - pow(1 - progress, 3)
                orbsAnimated = Int(Double(targetOrbs) * easedProgress)

                // Subtle haptic on orb increments
                if step % 5 == 0 && step > 0 {
                    HapticManager.shared.impact(style: .light)
                }
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textTertiary)

            Spacer()

            Text(value)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)
        }
        .padding(Spacing.lg)
        .background(OnLifeColors.surface)
        .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Sparkle Effect
struct SparkleEffect: View {
    @State private var opacity: Double = 0
    @State private var isVisible = false

    var body: some View {
        ZStack {
            ForEach(0..<6) { index in
                Star()
                    .fill(Color.yellow.opacity(0.8))
                    .frame(width: 12, height: 12)
                    .offset(sparkleOffset(index))
                    .opacity(opacity)
            }
        }
        .onAppear {
            isVisible = true
            startSparkleAnimation()
        }
        .onDisappear {
            isVisible = false
            opacity = 0
        }
    }

    private func startSparkleAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            guard isVisible else {
                timer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 1.5)) {
                opacity = opacity == 0 ? 1.0 : 0
            }
        }
        // Initial fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 1.5)) {
                opacity = 1.0
            }
        }
    }

    func sparkleOffset(_ index: Int) -> CGSize {
        let angle = Double(index) * 60.0 * .pi / 180.0
        let distance: CGFloat = 60.0
        let x = cos(angle) * distance
        let y = sin(angle) * distance
        return CGSize(width: x, height: y)
    }
}

// MARK: - Star Shape
struct Star: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4

        for i in 0..<10 {
            let angle = CGFloat(i) * .pi / 5 - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}
