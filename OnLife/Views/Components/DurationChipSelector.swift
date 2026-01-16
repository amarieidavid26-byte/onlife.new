import SwiftUI

struct DurationChipSelector: View {
    @Binding var selectedDuration: Int
    let durations = [15, 30, 45, 60]

    var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(durations, id: \.self) { duration in
                DurationChip(
                    duration: duration,
                    isSelected: selectedDuration == duration
                ) {
                    Haptics.selection()
                    withAnimation(OnLifeAnimation.quick) {
                        selectedDuration = duration
                    }
                }
            }
        }
    }
}

struct DurationChip: View {
    let duration: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(duration)")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(isSelected ? OnLifeColors.deepForest : OnLifeColors.textSecondary)

                Text("min")
                    .font(OnLifeFont.caption())
                    .foregroundColor(isSelected ? OnLifeColors.deepForest.opacity(0.7) : OnLifeColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(isSelected ? OnLifeColors.sage : OnLifeColors.cardBackground)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = false }
                }
        )
    }
}
