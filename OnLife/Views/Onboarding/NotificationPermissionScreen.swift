import SwiftUI
import UserNotifications

struct NotificationPermissionScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var isRequesting = false
    @State private var showError = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Title and description
            VStack(spacing: Spacing.md) {
                Text("Stay on Track")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Get timely reminders to maximize your focus sessions and optimize substance timing.")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            // Use cases
            VStack(alignment: .leading, spacing: Spacing.md) {
                NotificationUseCaseRow(
                    icon: "clock.fill",
                    iconColor: .blue,
                    title: "Optimal Timing",
                    description: "Get alerts when caffeine peaks for best focus"
                )

                NotificationUseCaseRow(
                    icon: "leaf.fill",
                    iconColor: OnLifeColors.sage,
                    title: "Plant Care",
                    description: "Reminders to maintain your recurring plants"
                )

                NotificationUseCaseRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: OnLifeColors.amber,
                    title: "Performance Insights",
                    description: "Weekly summaries of your focus achievements"
                )
            }
            .padding(Spacing.lg)
            .background(OnLifeColors.cardBackground)
            .cornerRadius(CornerRadius.medium)
            .padding(.horizontal, Spacing.xl)

            Spacer()

            // Buttons
            VStack(spacing: Spacing.md) {
                Button(action: requestPermission) {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    } else {
                        Text("Enable Notifications")
                            .font(OnLifeFont.button())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                }
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(CornerRadius.medium)
                .disabled(isRequesting)

                Button(action: skipPermission) {
                    Text("Maybe Later")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)
        }
        .alert("Notifications Disabled", isPresented: $showError) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Skip", role: .cancel) {
                skipPermission()
            }
        } message: {
            Text("You can enable notifications later in Settings > Notifications > OnLife")
        }
    }

    private func requestPermission() {
        isRequesting = true

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                isRequesting = false

                if let error = error {
                    print("⚠️ [Notifications] Error: \(error.localizedDescription)")
                    showError = true
                    return
                }

                if granted {
                    print("✅ [Notifications] Permission granted")
                    HapticManager.shared.impact(style: .medium)
                } else {
                    print("❌ [Notifications] Permission denied")
                }

                // Continue regardless of result
                viewModel.nextScreen()
            }
        }
    }

    private func skipPermission() {
        print("⏭️ [Notifications] User skipped permission")
        viewModel.nextScreen()
    }
}

struct NotificationUseCaseRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(OnLifeFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.textPrimary)
                Text(description)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            Spacer()
        }
    }
}
