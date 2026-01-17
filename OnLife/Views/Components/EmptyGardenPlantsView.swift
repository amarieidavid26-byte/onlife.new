import SwiftUI

struct EmptyGardenPlantsView: View {
    let gardenName: String
    var onStartSession: (() -> Void)? = nil

    @State private var isAnimating = false
    @State private var appeared = false
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // Animated plant illustration
            ZStack {
                // Soft glow background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [OnLifeColors.sage.opacity(0.15), OnLifeColors.sage.opacity(0.0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 10)

                // Soil/pot base circle
                Circle()
                    .fill(OnLifeColors.surface.opacity(0.4))
                    .frame(width: 100, height: 100)

                // Seed waiting to grow
                Text("🌱")
                    .font(.system(size: 56))
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .offset(y: isAnimating ? -3 : 0)
                    .animation(.easeInOut(duration: 1.0), value: isAnimating)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)

            VStack(spacing: Spacing.sm) {
                Text("Your garden awaits")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Start a focus session to plant your first seed in \(gardenName)")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            // CTA Button
            if let onStartSession = onStartSession {
                Button(action: {
                    Haptics.impact(.medium)
                    onStartSession()
                }) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))

                        Text("Start Focus Session")
                            .font(OnLifeFont.button())
                    }
                    .foregroundColor(OnLifeColors.deepForest)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.sage)
                    )
                    .shadow(
                        color: OnLifeColors.sage.opacity(0.3),
                        radius: 8,
                        y: 4
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, Spacing.md)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.9)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            isVisible = true
            startSeedAnimation()
            withAnimation(OnLifeAnimation.elegant) {
                appeared = true
            }
        }
        .onDisappear {
            isVisible = false
            isAnimating = false
        }
    }

    private func startSeedAnimation() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            guard isVisible else {
                timer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 1.0)) {
                isAnimating.toggle()
            }
        }
        // Initial animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 1.0)) {
                isAnimating = true
            }
        }
    }
}
