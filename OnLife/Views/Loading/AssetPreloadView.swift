import SwiftUI
import RealityKit
import Combine

/// Premium loading screen displayed while preloading 3D plant assets
/// Shown at app launch before transitioning to main content
struct AssetPreloadView: View {
    @StateObject private var assetLoader = PlantAssetLoader.shared
    @State private var currentEmojiIndex = 0
    @State private var emojiScale: CGFloat = 1.0
    @State private var showingProgress = false
    @State private var pulseOpacity: Double = 0.3

    let onComplete: () -> Void

    // Cycle through all plant emojis
    private let plantEmojis = PlantSpecies.allCases.map { $0.emoji }

    // Timer for emoji animation
    private let emojiTimer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
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
                    // Glow behind emoji
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

                    Text("Loading 3D assets...")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                // Progress section
                VStack(spacing: Spacing.lg) {
                    // Progress bar
                    progressBar
                        .opacity(showingProgress ? 1 : 0)

                    // Progress text
                    HStack(spacing: 4) {
                        if assetLoader.isPreloading {
                            Text("\(assetLoader.preloadedCount)")
                                .font(OnLifeFont.heading3())
                                .foregroundColor(OnLifeColors.sage)
                            Text("/ \(assetLoader.totalAssets) assets")
                                .font(OnLifeFont.body())
                                .foregroundColor(OnLifeColors.textTertiary)
                        } else if assetLoader.isReady {
                            Text("Ready!")
                                .font(OnLifeFont.heading3())
                                .foregroundColor(OnLifeColors.healthy)
                        }
                    }
                    .opacity(showingProgress ? 1 : 0)
                }
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
            startPreloading()
        }
        .onReceive(emojiTimer) { _ in
            animateEmojiChange()
        }
        .onReceive(pulseTimer) { _ in
            animatePulse()
        }
        .onChange(of: assetLoader.isReady) { _, isReady in
            if isReady {
                completePreloading()
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 8)
                    .fill(OnLifeColors.surface)

                // Progress fill with gradient
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                OnLifeColors.sage,
                                OnLifeColors.healthy,
                                OnLifeColors.sage.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * assetLoader.preloadProgress))

                // Shimmer effect overlay
                if assetLoader.isPreloading {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 60)
                        .offset(x: shimmerOffset(for: geo.size.width))
                        .mask(
                            RoundedRectangle(cornerRadius: 8)
                                .frame(width: max(0, geo.size.width * assetLoader.preloadProgress))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                }
            }
        }
        .frame(height: 16)
    }

    private func shimmerOffset(for width: CGFloat) -> CGFloat {
        let progressWidth = width * assetLoader.preloadProgress
        let time = Date().timeIntervalSinceReferenceDate
        let normalizedTime = (time.truncatingRemainder(dividingBy: 1.5)) / 1.5
        return -30 + (progressWidth * normalizedTime)
    }

    // MARK: - Animations

    private func startPreloading() {
        // Fade in progress
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            showingProgress = true
        }

        // Start preloading assets
        Task {
            await assetLoader.preloadAllAssets()
        }
    }

    private func animateEmojiChange() {
        // Scale down
        withAnimation(.easeIn(duration: 0.15)) {
            emojiScale = 0.7
        }

        // Change emoji and scale up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentEmojiIndex = (currentEmojiIndex + 1) % plantEmojis.count
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                emojiScale = 1.0
            }
        }
    }

    private func animatePulse() {
        withAnimation(.easeInOut(duration: 1.5)) {
            pulseOpacity = pulseOpacity == 0.3 ? 0.5 : 0.3
        }
    }

    private func completePreloading() {
        // Brief delay to show "Ready!" state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                onComplete()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AssetPreloadView_Previews: PreviewProvider {
    static var previews: some View {
        AssetPreloadView(onComplete: {})
            .preferredColorScheme(.dark)
    }
}
#endif
