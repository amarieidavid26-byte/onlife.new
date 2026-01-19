import SwiftUI

/// Alert overlay shown when a streak freeze is automatically used
/// Provides positive reinforcement for the protection mechanic
struct StreakSavedAlert: View {
    @Binding var isPresented: Bool
    let freezesRemaining: Int
    let currentStreak: Int

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var snowflakeRotation: Double = 0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .opacity(opacity)
                .onTapGesture {
                    dismissAlert()
                }

            // Alert card
            VStack(spacing: Spacing.lg) {
                // Animated snowflake
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(Color.cyan.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)

                    Text("🧊")
                        .font(.system(size: 60))
                        .rotationEffect(.degrees(snowflakeRotation))
                }

                Text("Streak Saved!")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("A freeze was automatically used to protect your \(currentStreak)-day streak")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.md)

                // Freezes remaining indicator
                freezesRemainingBadge

                // Dismiss button
                Button(action: dismissAlert) {
                    Text("Got it!")
                        .font(OnLifeFont.button())
                        .foregroundColor(OnLifeColors.deepForest)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                .fill(Color.cyan)
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackgroundElevated)
                    .shadow(color: Color.cyan.opacity(0.3), radius: 30, y: 10)
            )
            .padding(Spacing.xl)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Freezes Remaining Badge

    @ViewBuilder
    private var freezesRemainingBadge: some View {
        HStack(spacing: Spacing.sm) {
            // Snowflake icons
            HStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { index in
                    Image(systemName: "snowflake")
                        .font(.system(size: 14))
                        .foregroundColor(index < freezesRemaining ? .cyan : OnLifeColors.textTertiary.opacity(0.4))
                }
            }

            Text("\(freezesRemaining) freeze\(freezesRemaining == 1 ? "" : "s") remaining this month")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(Color.cyan.opacity(0.15))
        )
    }

    // MARK: - Animation

    private func startAnimation() {
        // Card appearance
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }

        // Snowflake rotation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            snowflakeRotation = 15
        }

        HapticManager.shared.notification(type: .success)
    }

    private func dismissAlert() {
        withAnimation(.easeIn(duration: 0.2)) {
            scale = 0.8
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

// MARK: - Streak Milestone Alert

struct StreakMilestoneAlert: View {
    let milestone: StreakMilestone
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var emojiScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .opacity(opacity)
                .onTapGesture { dismissAlert() }

            VStack(spacing: Spacing.lg) {
                // Milestone emoji with pulse
                Text(milestone.emoji)
                    .font(.system(size: 80))
                    .scaleEffect(emojiScale)

                Text("Milestone Reached!")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(milestone.celebrationMessage)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.amber)
                    .multilineTextAlignment(.center)

                Text("\(milestone.days) Day Streak")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)

                Button(action: dismissAlert) {
                    Text("Amazing!")
                        .font(OnLifeFont.button())
                        .foregroundColor(OnLifeColors.deepForest)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                .fill(OnLifeColors.amber)
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackgroundElevated)
                    .shadow(color: OnLifeColors.amber.opacity(0.3), radius: 30, y: 10)
            )
            .padding(Spacing.xl)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }

            // Emoji pulse animation
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                emojiScale = 1.15
            }

            HapticManager.shared.notification(type: .success)
        }
    }

    private func dismissAlert() {
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
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        StreakSavedAlert(
            isPresented: .constant(true),
            freezesRemaining: 1,
            currentStreak: 15
        )
    }
}
