import SwiftUI
import Combine

/// Splash screen shown at app launch
/// SceneKit loads assets on demand, so this is just a brief loading state
struct AssetPreloadView: View {
    @State private var currentEmojiIndex = 0
    @State private var emojiScale: CGFloat = 1.0
    @State private var progress: CGFloat = 0
    @State private var pulseOpacity: Double = 0.3

    let onComplete: () -> Void

    // Cycle through all plant emojis
    private let plantEmojis = PlantSpecies.allCases.map { $0.emoji }

    // Timers
    private let emojiTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    private let pulseTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    OnLifeColors.deepForest,
                    OnLifeColors.deepForest.opacity(0.95),
                    Color(red: 0.05, green: 0.12, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Ambient glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            OnLifeColors.sage.opacity(pulseOpacity),
                            OnLifeColors.sage.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(y: -50)

            VStack(spacing: Spacing.xxl) {
                Spacer()

                // Animated plant emoji
                ZStack {
                    Circle()
                        .fill(OnLifeColors.sage.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)

                    Text(plantEmojis[currentEmojiIndex])
                        .font(.system(size: 80))
                        .scaleEffect(emojiScale)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                .frame(height: 160)

                // Title and subtitle
                VStack(spacing: Spacing.md) {
                    Text("Preparing Your Garden")
                        .font(OnLifeFont.heading1())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Loading...")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                // Progress bar
                progressBar
                    .padding(.horizontal, Spacing.xxl)

                Spacer()

                // Branding at bottom
                VStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(OnLifeColors.sage)
                        Text("OnLife")
                            .font(OnLifeFont.heading3())
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    Text("Grow with intention")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding(.bottom, Spacing.xxl)
            }
        }
        .onAppear {
            startLoading()
        }
        .onReceive(emojiTimer) { _ in
            animateEmojiChange()
        }
        .onReceive(pulseTimer) { _ in
            animatePulse()
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 8)
                    .fill(OnLifeColors.surface)

                // Progress fill
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [OnLifeColors.sage, OnLifeColors.healthy],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * progress))
            }
        }
        .frame(height: 12)
    }

    // MARK: - Animations

    private func startLoading() {
        // Animate progress bar
        withAnimation(.easeInOut(duration: 1.2)) {
            progress = 1.0
        }

        // Complete after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                onComplete()
            }
        }
    }

    private func animateEmojiChange() {
        withAnimation(.easeIn(duration: 0.1)) {
            emojiScale = 0.8
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            currentEmojiIndex = (currentEmojiIndex + 1) % plantEmojis.count
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                emojiScale = 1.0
            }
        }
    }

    private func animatePulse() {
        withAnimation(.easeInOut(duration: 1.5)) {
            pulseOpacity = pulseOpacity == 0.3 ? 0.5 : 0.3
        }
    }
}

// MARK: - Preview

#Preview {
    AssetPreloadView(onComplete: {})
        .preferredColorScheme(.dark)
}
