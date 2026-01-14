import SwiftUI

struct SettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @StateObject private var profileManager = MetabolismProfileManager.shared
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @State private var showClearDataConfirmation = false
    @State private var showingProfileEdit = false

    var body: some View {
        NavigationStack{
        ZStack {
            AppColors.richSoil
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Your Profile")
                                .font(AppFont.bodySmall())
                                .foregroundColor(AppColors.textTertiary)

                            Text("Settings")
                                .font(AppFont.heading1())
                                .foregroundColor(AppColors.textPrimary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xxxl)

                    // Settings list
                    VStack(spacing: Spacing.md) {
                        SettingsSection(title: "APP") {
                            SettingsRow(icon: "🔔", title: "Notifications", value: "Coming soon")
                            SettingsRow(icon: "🎨", title: "Theme", value: "Earth tones")
                            SettingsRow(icon: "🔊", title: "Sounds", value: "Enabled")
                        }

                        SettingsSection(title: "METABOLISM PROFILE") {
                            Button(action: {
                                showingProfileEdit = true
                            }) {
                                HStack {
                                    Text("🧬")
                                        .font(.system(size: 20))

                                    Text("View/Edit Profile")
                                        .font(AppFont.body())
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()

                                    Text("\(Int(profileManager.profile.profileCompleteness * 100))%")
                                        .font(AppFont.bodySmall())
                                        .foregroundColor(AppColors.textSecondary)

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(Spacing.lg)
                                .background(AppColors.lightSoil)
                                .cornerRadius(CornerRadius.medium)
                            }
                        }

                        SettingsSection(title: "ACCOUNT") {
                            SettingsRow(icon: "👤", title: "Profile", value: "Coming soon")
                            SettingsRow(icon: "☁️", title: "Sync", value: "Local only")
                        }

                        // Developer/Debug section
                        SettingsSection(title: "DEVELOPER") {
                            NavigationLink {
                                WatchConnectivityDebugView()
                            } label: {
                                HStack {
                                    Text("⌚")
                                        .font(.system(size: 20))

                                    Text("WatchConnectivity Debug")
                                        .font(AppFont.body())
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()

                                    // Status indicator
                                    if watchConnectivity.isSessionActivated {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(Spacing.lg)
                                .background(AppColors.lightSoil)
                                .cornerRadius(CornerRadius.medium)
                            }

                            NavigationLink {
                                WatchConnectivityTestView()
                            } label: {
                                HStack {
                                    Image(systemName: "applewatch.radiowaves.left.and.right")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppColors.textPrimary)

                                    Text("Test Watch Connection")
                                        .font(AppFont.body())
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(Spacing.lg)
                                .background(AppColors.lightSoil)
                                .cornerRadius(CornerRadius.medium)
                            }
                        }

                        SettingsSection(title: "DANGER ZONE") {
                            Button(action: {
                                hasCompletedOnboarding = false
                            }) {
                                HStack {
                                    Text("🔄")
                                        .font(.system(size: 20))

                                    Text("Reset Onboarding")
                                        .font(AppFont.body())
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()
                                }
                                .padding(Spacing.lg)
                                .background(AppColors.lightSoil)
                                .cornerRadius(CornerRadius.medium)
                            }

                            Button(action: resetMetabolismProfile) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundColor(.red)

                                    Text("Reset Metabolism Profile")
                                        .font(AppFont.body())
                                        .foregroundColor(.red)

                                    Spacer()
                                }
                                .padding(Spacing.lg)
                                .background(AppColors.lightSoil)
                                .cornerRadius(CornerRadius.medium)
                            }

                            Button(action: {
                                showClearDataConfirmation = true
                            }) {
                                HStack {
                                    Text("🗑️")
                                        .font(.system(size: 20))

                                    Text("Clear All Data")
                                        .font(AppFont.body())
                                        .foregroundColor(AppColors.error)

                                    Spacer()
                                }
                                .padding(Spacing.lg)
                                .background(AppColors.lightSoil)
                                .cornerRadius(CornerRadius.medium)
                            }
                        }

                        // App info
                        VStack(spacing: Spacing.sm) {
                            Text("OnLife")
                                .font(AppFont.heading3())
                                .foregroundColor(AppColors.textPrimary)

                            Text("Version 1.0.0")
                                .font(AppFont.bodySmall())
                                .foregroundColor(AppColors.textTertiary)

                            Text("Built with ❤️")
                                .font(AppFont.bodySmall())
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.top, Spacing.xl)
                    }
                    .padding(.horizontal, Spacing.xl)
                }
            }
        }
        .alert("Clear All Data", isPresented: $showClearDataConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
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

    private func resetMetabolismProfile() {
        profileManager.resetToDefaults()
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(AppFont.label())
                .foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.sm) {
                content
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(icon)
                .font(.system(size: 20))

            Text(title)
                .font(AppFont.body())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(value)
                .font(AppFont.bodySmall())
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(Spacing.lg)
        .background(AppColors.lightSoil)
        .cornerRadius(CornerRadius.medium)
    }
}
