import SwiftUI

// MARK: - Theme Picker View

/// Beautiful theme selection interface with live previews
struct ThemePickerView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var contentAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                themeManager.currentTheme.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Header
                        VStack(spacing: Spacing.sm) {
                            Text("Choose Your Vibe")
                                .font(OnLifeFont.heading2())
                                .foregroundColor(themeManager.currentTheme.textPrimary)

                            Text("Each theme is crafted to support your flow state")
                                .font(OnLifeFont.body())
                                .foregroundColor(themeManager.currentTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Spacing.lg)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)

                        // Theme cards
                        VStack(spacing: Spacing.lg) {
                            ForEach(Array(ThemeType.allCases.enumerated()), id: \.element) { index, themeType in
                                ThemePreviewCard(
                                    themeType: themeType,
                                    isSelected: themeManager.currentThemeType == themeType
                                ) {
                                    themeManager.setTheme(themeType)
                                }
                                .opacity(contentAppeared ? 1 : 0)
                                .offset(y: contentAppeared ? 0 : 20)
                                .animation(
                                    OnLifeAnimation.elegant.delay(Double(index) * 0.1),
                                    value: contentAppeared
                                )
                            }
                        }
                        .padding(.horizontal, Spacing.lg)

                        Spacer(minLength: Spacing.xxl)
                    }
                }
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(OnLifeFont.button())
                            .foregroundColor(themeManager.currentTheme.accent)
                    }
                }
            }
            .toolbarBackground(themeManager.currentTheme.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            withAnimation(OnLifeAnimation.elegant) {
                contentAppeared = true
            }
        }
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let themeType: ThemeType
    let isSelected: Bool
    let onSelect: () -> Void

    private var theme: AppTheme { themeType.theme }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Preview header
                HStack(spacing: Spacing.md) {
                    // Theme icon
                    ZStack {
                        Circle()
                            .fill(theme.primary.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: themeType.icon)
                            .font(.system(size: 20))
                            .foregroundColor(theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(themeType.rawValue)
                            .font(OnLifeFont.heading3())
                            .foregroundColor(theme.textPrimary)

                        Text(themeType.description)
                            .font(OnLifeFont.caption())
                            .foregroundColor(theme.textSecondary)
                    }

                    Spacer()

                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? theme.accent : theme.textTertiary.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                .padding(Spacing.md)
                .background(theme.surfaceCard)

                // Color palette preview
                HStack(spacing: 0) {
                    theme.primary
                    theme.secondary
                    theme.accent
                    theme.success
                    theme.backgroundPrimary
                }
                .frame(height: 8)

                // Mini garden preview
                HStack(spacing: Spacing.md) {
                    // Simulated plants
                    HStack(spacing: Spacing.sm) {
                        PlantPreviewDot(color: theme.thriving, size: 24)
                        PlantPreviewDot(color: theme.healthy, size: 20)
                        PlantPreviewDot(color: theme.stressed, size: 16)
                    }

                    Spacer()

                    // Sample text
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("25:00")
                            .font(OnLifeFont.timerSmall())
                            .foregroundColor(theme.textPrimary)
                        Text("Deep Work")
                            .font(OnLifeFont.caption())
                            .foregroundColor(theme.textSecondary)
                    }
                }
                .padding(Spacing.md)
                .background(theme.backgroundSecondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: isSelected ? theme.accent.opacity(0.3) : Color.clear,
                radius: 12,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PressableCardStyle())
    }
}

// MARK: - Plant Preview Dot

struct PlantPreviewDot: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.6)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#if DEBUG
struct ThemePickerView_Previews: PreviewProvider {
    static var previews: some View {
        ThemePickerView()
            .preferredColorScheme(.dark)
    }
}
#endif
