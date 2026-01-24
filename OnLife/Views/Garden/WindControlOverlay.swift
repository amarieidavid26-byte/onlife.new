import SwiftUI

/// Overlay panel for controlling wind settings in the 3D garden
/// Shown via long press gesture on garden view
struct WindControlOverlay: View {
    @ObservedObject var windSystem = WindSystem.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Binding var isVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.md)

            // Title
            HStack {
                Image(systemName: "wind")
                    .foregroundColor(OnLifeColors.sage)
                Text("Wind Settings")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(OnLifeColors.textTertiary)
                        .font(.title3)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.md)

            // Preset buttons
            HStack(spacing: Spacing.md) {
                ForEach(WindSystem.WindPreset.allCases, id: \.self) { preset in
                    WindPresetButton(
                        preset: preset,
                        isSelected: windSystem.windPreset == preset
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            windSystem.windPreset = preset
                        }

                        // Haptic feedback
                        let feedback = UIImpactFeedbackGenerator(style: .light)
                        feedback.impactOccurred()
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Divider()
                .background(OnLifeColors.textTertiary.opacity(0.3))
                .padding(.vertical, Spacing.md)

            // Status indicator
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(windSystem.isRunning ? OnLifeColors.healthy : OnLifeColors.terracotta)
                    .frame(width: 8, height: 8)
                Text(windSystem.isRunning ? "Wind Active" : "Wind Paused")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)

            // Gust button
            Button {
                windSystem.triggerGust(strength: 0.6)

                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "tornado")
                        .font(.title3)
                    Text("Trigger Gust")
                        .font(OnLifeFont.body())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    LinearGradient(
                        colors: [OnLifeColors.sage, OnLifeColors.healthy],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, y: -5)
        )
    }
}

// MARK: - Wind Preset Button

struct WindPresetButton: View {
    let preset: WindSystem.WindPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? OnLifeColors.sage : OnLifeColors.surface)
                        .frame(width: 50, height: 50)

                    // Animated wind lines when selected
                    if isSelected {
                        Circle()
                            .strokeBorder(OnLifeColors.sage.opacity(0.5), lineWidth: 2)
                            .frame(width: 58, height: 58)
                    }

                    Image(systemName: preset.icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : OnLifeColors.textSecondary)
                }

                Text(preset.rawValue)
                    .font(OnLifeFont.caption())
                    .foregroundColor(isSelected ? OnLifeColors.sage : OnLifeColors.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Wind Indicator

/// Small indicator showing current wind state (for toolbar)
struct WindIndicator: View {
    @ObservedObject var windSystem = WindSystem.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: windSystem.windPreset.icon)
                .font(.caption)

            if windSystem.isRunning {
                // Animated wind lines
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(OnLifeColors.sage)
                        .frame(width: 2, height: CGFloat(4 + i * 2))
                        .opacity(Double(i + 1) / 3)
                }
            }
        }
        .foregroundColor(OnLifeColors.sage)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(OnLifeColors.surface.opacity(0.8))
        .cornerRadius(CornerRadius.small)
    }
}

// MARK: - Preview

#if DEBUG
struct WindControlOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            OnLifeColors.deepForest.ignoresSafeArea()

            VStack {
                Spacer()
                WindControlOverlay(isVisible: .constant(true))
                    .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
