import SwiftUI
import HealthKit

struct HealthKitPermissionScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var isRequesting = false
    @State private var showError = false

    private let healthKitManager = HealthKitManager.shared

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)

            // Title and description
            VStack(spacing: Spacing.md) {
                Text("Connect Health Data")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("OnLife uses your health data to recommend optimal focus times and detect flow states.")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            // What we read
            VStack(alignment: .leading, spacing: Spacing.md) {
                HealthKitPermissionRow(
                    icon: "bed.double.fill",
                    title: "Sleep Data",
                    description: "For chronotype and readiness"
                )
                HealthKitPermissionRow(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    description: "For flow state detection"
                )
                HealthKitPermissionRow(
                    icon: "waveform.path.ecg",
                    title: "Heart Rate Variability",
                    description: "For stress and recovery insights"
                )
            }
            .padding()
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
                        Text("Allow Access")
                            .font(OnLifeFont.button())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                }
                .background(OnLifeColors.sage)
                .cornerRadius(CornerRadius.medium)
                .disabled(isRequesting)

                Button(action: skipPermission) {
                    Text("Skip for Now")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)
        }
        .alert("Permission Issue", isPresented: $showError) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Skip", role: .cancel) {
                skipPermission()
            }
        } message: {
            Text("You can enable HealthKit permissions in Settings > Privacy & Security > Health > OnLife")
        }
    }

    private func requestPermission() {
        guard HKHealthStore.isHealthDataAvailable() else {
            showError = true
            return
        }

        isRequesting = true

        Task {
            do {
                try await healthKitManager.requestAuthorization()
                await MainActor.run {
                    isRequesting = false
                    HapticManager.shared.impact(style: .medium)
                    viewModel.nextScreen()
                }
            } catch {
                await MainActor.run {
                    isRequesting = false
                    showError = true
                }
            }
        }
    }

    private func skipPermission() {
        viewModel.nextScreen()
    }
}

struct HealthKitPermissionRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(OnLifeColors.sage)
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
