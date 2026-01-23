import SwiftUI

struct SettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @StateObject private var profileManager = MetabolismProfileManager.shared
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @State private var showClearDataConfirmation = false
    @State private var showResetProfileConfirmation = false
    @State private var showResetOnboardingConfirmation = false
    @State private var showingProfileEdit = false
    @State private var contentAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [OnLifeColors.deepForest, OnLifeColors.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Header
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("YOUR PROFILE")
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textTertiary)
                                .tracking(1.2)

                            Text("Settings")
                                .font(OnLifeFont.display())
                                .foregroundColor(OnLifeColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)

                        // APP Section
                        SettingsSection(title: "APP") {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "bell.fill",
                                    iconColor: OnLifeColors.amber,
                                    title: "Notifications",
                                    value: "Coming soon",
                                    showChevron: false
                                )

                                SettingsDivider()

                                SettingsRow(
                                    icon: "paintpalette.fill",
                                    iconColor: OnLifeColors.sage,
                                    title: "Theme",
                                    value: "Earth tones",
                                    showChevron: false
                                )

                                SettingsDivider()

                                SettingsRow(
                                    icon: "speaker.wave.2.fill",
                                    iconColor: OnLifeColors.sage,
                                    title: "Sounds",
                                    value: "Enabled",
                                    showChevron: false
                                )
                            }
                        }
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(OnLifeAnimation.elegant.delay(0.05), value: contentAppeared)

                        // METABOLISM PROFILE Section
                        SettingsSection(title: "METABOLISM PROFILE") {
                            SettingsRowButton(
                                icon: "heart.text.square.fill",
                                iconColor: OnLifeColors.terracotta,
                                title: "View/Edit Profile",
                                value: "\(Int(profileManager.profile.profileCompleteness * 100))%",
                                showChevron: true
                            ) {
                                Haptics.light()
                                showingProfileEdit = true
                            }
                        }
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(OnLifeAnimation.elegant.delay(0.1), value: contentAppeared)

                        // CHRONOTYPE Section
                        if let chronotypeResult = ChronotypeInferenceEngine.shared.storedResult {
                            SettingsSection(title: "YOUR CHRONOTYPE") {
                                ChronotypeDisplayCard(result: chronotypeResult)
                            }
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 20)
                            .animation(OnLifeAnimation.elegant.delay(0.12), value: contentAppeared)
                        }

                        // INTEGRATIONS Section
                        SettingsSection(title: "INTEGRATIONS") {
                            NavigationLink {
                                WHOOPSettingsView()
                            } label: {
                                SettingsRowContent(
                                    icon: "heart.circle.fill",
                                    iconColor: OnLifeColors.sage,
                                    title: "WHOOP",
                                    trailing: {
                                        HStack(spacing: Spacing.sm) {
                                            if WHOOPAuthService.shared.isAuthenticated {
                                                Text("Connected")
                                                    .font(OnLifeFont.caption())
                                                    .foregroundColor(OnLifeColors.sage)
                                            }

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(OnLifeColors.textTertiary)
                                        }
                                    }
                                )
                            }
                            .buttonStyle(SettingsRowButtonStyle())
                        }
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(OnLifeAnimation.elegant.delay(0.13), value: contentAppeared)

                        // ACCOUNT Section
                        SettingsSection(title: "ACCOUNT") {
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "person.fill",
                                    iconColor: OnLifeColors.sage,
                                    title: "Profile",
                                    value: "Coming soon",
                                    showChevron: false
                                )

                                SettingsDivider()

                                SettingsRow(
                                    icon: "cloud.fill",
                                    iconColor: OnLifeColors.sage,
                                    title: "Sync",
                                    value: "Local only",
                                    showChevron: false
                                )
                            }
                        }
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(OnLifeAnimation.elegant.delay(0.17), value: contentAppeared)

                        // DEVELOPER Section
                        SettingsSection(title: "DEVELOPER") {
                            VStack(spacing: 0) {
                                NavigationLink {
                                    WatchConnectivityDebugView()
                                } label: {
                                    SettingsRowContent(
                                        icon: "applewatch",
                                        iconColor: OnLifeColors.sage,
                                        title: "WatchConnectivity Debug",
                                        trailing: {
                                            HStack(spacing: Spacing.sm) {
                                                if watchConnectivity.isSessionActivated {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(OnLifeColors.sage)
                                                } else {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .foregroundColor(OnLifeColors.terracotta)
                                                }

                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(OnLifeColors.textTertiary)
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(SettingsRowButtonStyle())

                                SettingsDivider()

                                NavigationLink {
                                    WatchConnectivityTestView()
                                } label: {
                                    SettingsRowContent(
                                        icon: "antenna.radiowaves.left.and.right",
                                        iconColor: OnLifeColors.sage,
                                        title: "Test Watch Connection",
                                        trailing: {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(OnLifeColors.textTertiary)
                                        }
                                    )
                                }
                                .buttonStyle(SettingsRowButtonStyle())
                            }
                        }
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(OnLifeAnimation.elegant.delay(0.22), value: contentAppeared)

                        // DANGER ZONE Section
                        SettingsSection(title: "DANGER ZONE", titleColor: OnLifeColors.terracotta) {
                            VStack(spacing: 0) {
                                SettingsRowButton(
                                    icon: "arrow.counterclockwise",
                                    iconColor: OnLifeColors.textSecondary,
                                    title: "Reset Onboarding",
                                    titleColor: OnLifeColors.textPrimary,
                                    showChevron: false
                                ) {
                                    Haptics.warning()
                                    showResetOnboardingConfirmation = true
                                }

                                SettingsDivider()

                                SettingsRowButton(
                                    icon: "arrow.triangle.2.circlepath",
                                    iconColor: OnLifeColors.terracotta,
                                    title: "Reset Metabolism Profile",
                                    titleColor: OnLifeColors.terracotta,
                                    showChevron: false
                                ) {
                                    Haptics.warning()
                                    showResetProfileConfirmation = true
                                }

                                SettingsDivider()

                                SettingsRowButton(
                                    icon: "trash.fill",
                                    iconColor: OnLifeColors.terracotta,
                                    title: "Clear All Data",
                                    titleColor: OnLifeColors.terracotta,
                                    showChevron: false
                                ) {
                                    Haptics.warning()
                                    showClearDataConfirmation = true
                                }
                            }
                        }
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(OnLifeAnimation.elegant.delay(0.27), value: contentAppeared)

                        // Footer
                        VStack(spacing: Spacing.sm) {
                            Text("OnLife")
                                .font(OnLifeFont.heading3())
                                .foregroundColor(OnLifeColors.textPrimary)

                            Text("Version 1.0.0")
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textTertiary)

                            Text("Built with ❤️")
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textTertiary)
                        }
                        .padding(.vertical, Spacing.xxl)
                        .opacity(contentAppeared ? 1 : 0)
                        .animation(OnLifeAnimation.elegant.delay(0.32), value: contentAppeared)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxl)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            withAnimation(OnLifeAnimation.elegant) {
                contentAppeared = true
            }
        }
        // Reset Onboarding Confirmation
        .alert("Reset Onboarding", isPresented: $showResetOnboardingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                hasCompletedOnboarding = false
            }
        } message: {
            Text("This will show the onboarding flow again on next app launch.")
        }
        // Reset Profile Confirmation
        .alert("Reset Metabolism Profile", isPresented: $showResetProfileConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                profileManager.resetToDefaults()
            }
        } message: {
            Text("This will reset your metabolism profile to default values. You'll need to reconfigure your settings.")
        }
        // Clear All Data Confirmation
        .alert("Clear All Data", isPresented: $showClearDataConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Everything", role: .destructive) {
                GardenDataManager.shared.clearAllData()
                hasCompletedOnboarding = false
            }
        } message: {
            Text("This will delete all your gardens, plants, and sessions. This action cannot be undone.")
        }
        .sheet(isPresented: $showingProfileEdit) {
            NavigationView {
                MetabolismProfileEditView()
            }
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    var titleColor: Color = OnLifeColors.textTertiary
    let content: Content

    init(title: String, titleColor: Color = OnLifeColors.textTertiary, @ViewBuilder content: () -> Content) {
        self.title = title
        self.titleColor = titleColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(OnLifeFont.caption())
                .foregroundColor(titleColor)
                .tracking(1.2)
                .padding(.leading, Spacing.sm)

            content
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .fill(OnLifeColors.cardBackground)
                )
        }
    }
}

// MARK: - Settings Divider

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(OnLifeColors.textTertiary.opacity(0.1))
            .frame(height: 1)
            .padding(.leading, 56 + Spacing.lg) // Icon width + spacing
    }
}

// MARK: - Settings Row (Static)

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var value: String = ""
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)

            Spacer()

            if !value.isEmpty {
                Text(value)
                    .font(OnLifeFont.body())
                    .foregroundColor(value == "Coming soon" ? OnLifeColors.textTertiary : OnLifeColors.textSecondary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
}

// MARK: - Settings Row Button (Tappable)

struct SettingsRowButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    var titleColor: Color = OnLifeColors.textPrimary
    var value: String = ""
    var showChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                Text(title)
                    .font(OnLifeFont.body())
                    .foregroundColor(titleColor)

                Spacer()

                if !value.isEmpty {
                    Text(value)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .buttonStyle(SettingsRowButtonStyle())
    }
}

// MARK: - Settings Row Content (For NavigationLink)

struct SettingsRowContent<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let trailing: Trailing

    init(icon: String, iconColor: Color, title: String, @ViewBuilder trailing: () -> Trailing) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)

            Spacer()

            trailing
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
}

// MARK: - Settings Row Button Style

struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? OnLifeColors.surface : Color.clear)
            .animation(OnLifeAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Chronotype Display Card

struct ChronotypeDisplayCard: View {
    let result: ChronotypeInferenceResult

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Main chronotype display
            HStack(spacing: Spacing.md) {
                Text(result.chronotype.icon)
                    .font(.system(size: 48))

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        Text(result.chronotype.shortName)
                            .font(OnLifeFont.heading2())
                            .foregroundColor(OnLifeColors.textPrimary)

                        // Confidence badge
                        Text(result.confidence.rawValue)
                            .font(OnLifeFont.caption())
                            .foregroundColor(confidenceColor)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                                    .fill(confidenceColor.opacity(0.15))
                            )
                    }

                    Text(result.chronotype.description)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(OnLifeColors.surface.opacity(0.5))
            )

            // Peak performance time
            HStack(spacing: Spacing.sm) {
                Image(systemName: "clock.fill")
                    .foregroundColor(OnLifeColors.sage)
                    .font(.system(size: 14))

                Text("Peak Performance: \(formatHourRange(result.chronotype.peakWindow))")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)

                Spacer()
            }

            // Circadian dip warning
            HStack(spacing: Spacing.sm) {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(OnLifeColors.amber)
                    .font(.system(size: 14))

                Text("Energy Dip: \(formatHourRange(result.chronotype.circadianDip))")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)

                Spacer()
            }

            // Recommendation
            if !result.recommendation.isEmpty {
                Text(result.recommendation)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.md)
    }

    private var confidenceColor: Color {
        switch result.confidence {
        case .low: return OnLifeColors.amber
        case .medium: return OnLifeColors.sage
        case .high: return .green
        }
    }

    private func formatHourRange(_ range: (start: Int, end: Int)) -> String {
        return "\(formatHour(range.start)) - \(formatHour(range.end))"
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour == 12 { return "12 PM" }
        if hour < 12 { return "\(hour) AM" }
        return "\(hour - 12) PM"
    }
}
