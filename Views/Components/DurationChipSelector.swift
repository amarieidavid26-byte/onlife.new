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
                    selectedDuration = duration
                    HapticManager.shared.selection()
                }
            }
        }
    }
}

struct DurationChip: View {
    let duration: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(duration)")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)

                Text("min")
                    .font(AppFont.bodySmall())
                    .foregroundColor(isSelected ? AppColors.textSecondary : AppColors.textTertiary)
            }
            .frame(width: 70, height: 70)
            .background(isSelected ? AppColors.healthy : AppColors.lightSoil)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(isSelected ? AppColors.healthy : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
