import SwiftUI

// MARK: - Biometric Source Banner

/// A banner that appears when a better biometric source becomes available
struct BiometricSourceBanner: View {
    let change: BiometricSourceChange
    let onSwitch: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(OnLifeColors.healthy)
                    .font(.system(size: 20))

                Text("Better Data Source Available")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(OnLifeColors.textTertiary)
                        .padding(Spacing.xs)
                        .background(Circle().fill(OnLifeColors.surface))
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: change.from.icon)
                            .font(.system(size: 12))
                            .foregroundColor(OnLifeColors.textTertiary)

                        Text(change.from.displayName)
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textSecondary)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(OnLifeColors.textTertiary)

                        Image(systemName: change.to.icon)
                            .font(.system(size: 12))
                            .foregroundColor(OnLifeColors.healthy)

                        Text(change.to.displayName)
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    Text("\(change.to.accuracy) vs \(change.from.accuracy)")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.healthy)
                }

                Spacer()

                Button(action: onSwitch) {
                    Text("Switch")
                        .font(OnLifeFont.button())
                        .foregroundColor(OnLifeColors.deepForest)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(OnLifeColors.healthy)
                        .cornerRadius(CornerRadius.medium)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
                .shadow(color: OnLifeColors.healthy.opacity(0.3), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(OnLifeAnimation.celebration) {
                appeared = true
            }
            HapticManager.shared.notificationOccurred(.success)
        }
    }
}

// MARK: - Compact Source Indicator

/// A small indicator showing the current biometric source
/// Use in headers or status bars
struct BiometricSourceIndicator: View {
    @StateObject private var sourceManager = BiometricSourceManager.shared

    var compact: Bool = true

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: sourceManager.activeSource.icon)
                .font(.system(size: compact ? 12 : 14))
                .foregroundColor(sourceColor)

            if !compact {
                Text(sourceManager.activeSource.displayName)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            // Connection indicator
            Circle()
                .fill(sourceColor)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, compact ? Spacing.sm : Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(sourceColor.opacity(0.15))
        )
    }

    private var sourceColor: Color {
        switch sourceManager.activeSource {
        case .whoopBLE, .whoopAPI:
            return OnLifeColors.healthy
        case .appleWatch:
            return OnLifeColors.sage
        case .behavioral:
            return OnLifeColors.textTertiary
        case .none:
            return OnLifeColors.textMuted
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BiometricSourceBanner_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            OnLifeColors.deepForest.ignoresSafeArea()

            VStack {
                BiometricSourceBanner(
                    change: BiometricSourceChange(from: .appleWatch, to: .whoopBLE),
                    onSwitch: {},
                    onDismiss: {}
                )

                Spacer()

                HStack {
                    BiometricSourceIndicator(compact: true)
                    BiometricSourceIndicator(compact: false)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
