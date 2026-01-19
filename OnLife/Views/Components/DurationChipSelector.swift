import SwiftUI

struct DurationChipSelector: View {
    @Binding var selectedDuration: Int
    @State private var showCustomDurationPicker = false
    @State private var customDuration: Int = 30

    let presetDurations = [15, 30, 45, 60]

    private var isCustomSelected: Bool {
        showCustomDurationPicker || !presetDurations.contains(selectedDuration)
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Preset duration chips + Custom button
            HStack(spacing: Spacing.md) {
                ForEach(presetDurations, id: \.self) { duration in
                    DurationChip(
                        duration: duration,
                        isSelected: selectedDuration == duration && !showCustomDurationPicker
                    ) {
                        Haptics.selection()
                        withAnimation(OnLifeAnimation.quick) {
                            selectedDuration = duration
                            showCustomDurationPicker = false
                        }
                    }
                }

                // Custom button
                CustomDurationChip(
                    customDuration: customDuration,
                    isSelected: isCustomSelected
                ) {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showCustomDurationPicker = true
                        selectedDuration = customDuration
                    }
                }
            }

            // Custom picker (appears when Custom is selected)
            if showCustomDurationPicker {
                CustomDurationPicker(
                    customDuration: $customDuration,
                    selectedDuration: $selectedDuration
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showCustomDurationPicker)
        .onAppear {
            // Load last custom duration from UserDefaults
            if let lastCustom = UserDefaults.standard.object(forKey: "lastCustomDuration") as? Int {
                customDuration = lastCustom
            }

            // Check if current selection is a custom value
            if !presetDurations.contains(selectedDuration) {
                customDuration = selectedDuration
                showCustomDurationPicker = true
            }
        }
        .onChange(of: customDuration) { _, newValue in
            if showCustomDurationPicker {
                selectedDuration = newValue
                UserDefaults.standard.set(newValue, forKey: "lastCustomDuration")
            }
        }
    }
}

// MARK: - Duration Chip

struct DurationChip: View {
    let duration: Int
    let isSelected: Bool
    let action: () -> Void

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
        }
        .buttonStyle(PressableChipStyle())
    }
}

// MARK: - Custom Duration Chip

struct CustomDurationChip: View {
    let customDuration: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? OnLifeColors.deepForest : OnLifeColors.textSecondary)

                Text(isSelected ? "\(customDuration)m" : "Custom")
                    .font(OnLifeFont.caption())
                    .foregroundColor(isSelected ? OnLifeColors.deepForest.opacity(0.7) : OnLifeColors.textTertiary)
            }
            .frame(width: 64)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(isSelected ? OnLifeColors.sage : OnLifeColors.cardBackground)
            )
        }
        .buttonStyle(PressableChipStyle())
    }
}

// MARK: - Custom Duration Picker

struct CustomDurationPicker: View {
    @Binding var customDuration: Int
    @Binding var selectedDuration: Int

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Header with current value
            HStack {
                Text("Custom Duration")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)

                Spacer()

                Text("\(customDuration) minutes")
                    .font(OnLifeFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.sage)
            }

            // Slider with range labels
            HStack(spacing: Spacing.md) {
                Text("5")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .frame(width: 28)

                Slider(
                    value: Binding(
                        get: { Double(customDuration) },
                        set: { customDuration = Int($0) }
                    ),
                    in: 5...180,
                    step: 5
                )
                .tint(OnLifeColors.sage)

                Text("180")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .frame(width: 28)
            }

            // Quick adjust buttons
            HStack(spacing: Spacing.sm) {
                QuickAdjustButton(label: "-5") {
                    Haptics.light()
                    customDuration = max(5, customDuration - 5)
                }

                QuickAdjustButton(label: "-1") {
                    Haptics.light()
                    customDuration = max(5, customDuration - 1)
                }

                Spacer()

                // Large center display
                Text("\(customDuration)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(OnLifeColors.sage)
                    .frame(minWidth: 60)

                Spacer()

                QuickAdjustButton(label: "+1") {
                    Haptics.light()
                    customDuration = min(180, customDuration + 1)
                }

                QuickAdjustButton(label: "+5") {
                    Haptics.light()
                    customDuration = min(180, customDuration + 5)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }
}

// MARK: - Quick Adjust Button

struct QuickAdjustButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(OnLifeColors.sage)
                .frame(width: 48, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .fill(OnLifeColors.sage.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        VStack {
            DurationChipSelector(selectedDuration: .constant(30))
                .padding()
        }
    }
}
