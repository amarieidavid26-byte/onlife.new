import SwiftUI

// ComparisonMode is defined in Models/Social/UserProfile.swift

// MARK: - Comparison Mode Toggle

struct ComparisonModeToggle: View {
    @Binding var mode: ComparisonMode
    let onPhilosophyTap: () -> Void

    @State private var showingExplanation = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Header with philosophy button
            HStack {
                Text("Compare Mode")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)

                PhilosophyButton(action: onPhilosophyTap)

                Spacer()

                Button(action: { withAnimation { showingExplanation.toggle() } }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            // Toggle buttons
            HStack(spacing: Spacing.sm) {
                ForEach(ComparisonMode.allCases, id: \.self) { modeOption in
                    modeButton(modeOption)
                }
            }

            // Explanation card (expandable)
            if showingExplanation {
                explanationCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Mode Button

    private func modeButton(_ modeOption: ComparisonMode) -> some View {
        Button(action: {
            withAnimation(.spring(duration: 0.3)) {
                mode = modeOption
            }
            HapticManager.shared.impact(style: .light)
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: modeOption.icon)
                    .font(.system(size: 14))

                Text(modeOption.displayName)
                    .font(OnLifeFont.button())
            }
            .foregroundColor(mode == modeOption ? OnLifeColors.textPrimary : OnLifeColors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(mode == modeOption ? modeOption.color : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(mode == modeOption ? Color.clear : OnLifeColors.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Explanation Card

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Inspiration explanation
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(OnLifeColors.amber)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Inspiration Mode")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Focus on WHAT they do differently. Shows their protocols, timing, and techniques you can learn from.")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
                .background(OnLifeColors.textMuted.opacity(0.3))

            // Competition explanation
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 16))
                    .foregroundColor(OnLifeColors.socialTeal)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Competition Mode")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Focus on WHO is improving faster. Shows relative growth rates, not absolute scores.")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Psychology note
            HStack(spacing: Spacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12))
                    .foregroundColor(OnLifeColors.socialTeal)

                Text("Both modes compare GROWTH, never static states")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.socialTeal)
                    .italic()
            }
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackgroundElevated)
        )
    }
}

// MARK: - Compact Mode Indicator

struct ComparisonModeIndicator: View {
    let mode: ComparisonMode

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: mode.icon)
                .font(.system(size: 10))

            Text(mode.displayName)
                .font(OnLifeFont.labelSmall())
        }
        .foregroundColor(mode.color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(mode.color.opacity(0.15))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ComparisonModeToggle_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var mode: ComparisonMode = .inspiration

        var body: some View {
            VStack(spacing: Spacing.xl) {
                ComparisonModeToggle(
                    mode: $mode,
                    onPhilosophyTap: {}
                )

                // Show current mode indicator
                HStack {
                    Text("Current:")
                        .foregroundColor(OnLifeColors.textTertiary)
                    ComparisonModeIndicator(mode: mode)
                }
            }
            .padding()
            .background(OnLifeColors.deepForest)
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .preferredColorScheme(.dark)
    }
}
#endif
