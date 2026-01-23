//
//  WHOOPSettingsView.swift
//  OnLife
//
//  Settings view for WHOOP connection management
//

import SwiftUI

/// Settings view for WHOOP connection management
struct WHOOPSettingsView: View {
    @StateObject private var viewModel = WHOOPConnectionViewModel()
    @StateObject private var bleManager = WHOOPBLEManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background gradient matching app style
            LinearGradient(
                colors: [OnLifeColors.deepForest, OnLifeColors.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // WHOOP Logo/Header Card
                    whoopHeaderCard

                    // Connection Status
                    connectionStatusSection

                    // Connect/Disconnect Button
                    actionButton

                    // Data Access Info (when not connected)
                    if !viewModel.isConnected {
                        dataAccessSection
                    }

                    // Connection Info (when connected)
                    if viewModel.isConnected {
                        connectedInfoSection

                        // Test API Button
                        testAPIButton
                    }

                    // BLE Heart Rate Section (always visible)
                    bleHeartRateSection

                    Spacer(minLength: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
            }
        }
        .navigationTitle("WHOOP Integration")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Connection Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .alert("WHOOP Recovery Data", isPresented: $viewModel.showTestResult) {
            Button("OK", role: .cancel) {
                viewModel.dismissTestResult()
            }
        } message: {
            Text(viewModel.testResult ?? "No data available")
        }
    }

    // MARK: - Header Card

    private var whoopHeaderCard: some View {
        HStack(spacing: Spacing.md) {
            // WHOOP Icon
            ZStack {
                Circle()
                    .fill(OnLifeColors.sage.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(OnLifeColors.sage)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("WHOOP")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Biometric Integration")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            Spacer()

            // Connection status indicator
            Circle()
                .fill(viewModel.isConnected ? OnLifeColors.sage : OnLifeColors.textTertiary)
                .frame(width: 12, height: 12)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Connection Status Section

    private var connectionStatusSection: some View {
        VStack(spacing: Spacing.sm) {
            if viewModel.isConnected {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(OnLifeColors.sage)

                    Text("Connected")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.sage)
                }

                Text("Your WHOOP data is being used to optimize flow detection and provide personalized insights.")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Connect your WHOOP to enable advanced biometric flow detection with real-time HRV analysis.")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button(action: {
            Haptics.light()
            Task {
                if viewModel.isConnected {
                    viewModel.disconnectWHOOP()
                } else {
                    await viewModel.connectWHOOP()
                }
            }
        }) {
            HStack(spacing: Spacing.sm) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: viewModel.isConnected ? "xmark.circle" : "link")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(viewModel.isConnected ? "Disconnect WHOOP" : "Connect WHOOP")
                    .font(OnLifeFont.body())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(viewModel.isConnected ? OnLifeColors.terracotta : OnLifeColors.sage)
            )
            .foregroundColor(.white)
        }
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.7 : 1.0)
    }

    // MARK: - Data Access Section

    private var dataAccessSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("ONLIFE WILL ACCESS")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .tracking(1.2)

            VStack(spacing: 0) {
                ForEach(whoopDataPoints.indices, id: \.self) { index in
                    HStack(spacing: Spacing.md) {
                        Image(systemName: whoopDataPoints[index].icon)
                            .font(.system(size: 14))
                            .foregroundColor(OnLifeColors.sage)
                            .frame(width: 20)

                        Text(whoopDataPoints[index].title)
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textPrimary)

                        Spacer()

                        Text(whoopDataPoints[index].description)
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.md)

                    if index < whoopDataPoints.count - 1 {
                        Rectangle()
                            .fill(OnLifeColors.textTertiary.opacity(0.1))
                            .frame(height: 1)
                            .padding(.leading, 44)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
        }
    }

    // MARK: - Connected Info Section

    private var connectedInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("INTEGRATION BENEFITS")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .tracking(1.2)

            VStack(spacing: 0) {
                benefitRow(
                    icon: "waveform.path.ecg",
                    title: "Real-time HRV",
                    description: "Flow detection uses live heart rate variability"
                )

                Rectangle()
                    .fill(OnLifeColors.textTertiary.opacity(0.1))
                    .frame(height: 1)
                    .padding(.leading, 44)

                benefitRow(
                    icon: "moon.stars.fill",
                    title: "Sleep Optimization",
                    description: "Personalized focus windows based on recovery"
                )

                Rectangle()
                    .fill(OnLifeColors.textTertiary.opacity(0.1))
                    .frame(height: 1)
                    .padding(.leading, 44)

                benefitRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Strain Tracking",
                    description: "Workout intensity affects focus recommendations"
                )
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
        }
    }

    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(OnLifeColors.sage)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(description)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Test API Button

    private var testAPIButton: some View {
        Button(action: {
            Haptics.light()
            Task {
                await viewModel.testWHOOPConnection()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                if viewModel.isTesting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.sage))
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .medium))
                }

                Text("Test API Connection")
                    .font(OnLifeFont.bodySmall())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(OnLifeColors.sage.opacity(0.5), lineWidth: 1)
            )
            .foregroundColor(OnLifeColors.sage)
        }
        .disabled(viewModel.isTesting)
        .opacity(viewModel.isTesting ? 0.7 : 1.0)
    }

    // MARK: - BLE Heart Rate Section

    private var bleHeartRateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("REAL-TIME BIOMETRICS")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .tracking(1.2)

            VStack(spacing: 0) {
                // Heart Rate Display
                HStack(spacing: Spacing.md) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Heart Rate")
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textPrimary)

                        Text(bleManager.state.rawValue)
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }

                    Spacer()

                    if bleManager.currentHeartRate > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(bleManager.currentHeartRate)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                            Text("BPM")
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textSecondary)
                        }
                    }
                }
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)

                // HRV Data (when available)
                if let hrv = bleManager.latestHRV {
                    Rectangle()
                        .fill(OnLifeColors.textTertiary.opacity(0.1))
                        .frame(height: 1)
                        .padding(.leading, 44)

                    HStack {
                        Text("RMSSD")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                        Spacer()
                        Text("\(String(format: "%.1f", hrv.rmssd)) ms")
                            .font(OnLifeFont.bodySmall())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.md)

                    HStack {
                        Text("Signal Quality")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                        Spacer()
                        Text("\(Int(bleManager.signalQuality * 100))%")
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(bleManager.signalQuality > 0.7 ? OnLifeColors.sage : OnLifeColors.terracotta)
                    }
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.md)

                    HStack {
                        Text("RR Intervals")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                        Spacer()
                        Text("\(hrv.rrCount) samples")
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textPrimary)
                    }
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.md)
                }

                Rectangle()
                    .fill(OnLifeColors.textTertiary.opacity(0.1))
                    .frame(height: 1)
                    .padding(.leading, 44)

                // Scan/Disconnect Button
                Button(action: {
                    Haptics.light()
                    if bleManager.state == .disconnected || bleManager.state == .error {
                        bleManager.startScanning()
                    } else {
                        bleManager.disconnect()
                    }
                }) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: bleManager.state == .disconnected || bleManager.state == .error
                              ? "antenna.radiowaves.left.and.right"
                              : "xmark.circle")
                            .font(.system(size: 14))

                        Text(bleButtonText)
                            .font(OnLifeFont.bodySmall())
                    }
                    .foregroundColor(bleManager.state == .disconnected || bleManager.state == .error
                                     ? OnLifeColors.sage
                                     : OnLifeColors.terracotta)
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.md)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )

            // Footer text
            Text("Requires HR Broadcast enabled in WHOOP app. Used for live flow detection during focus sessions.")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .padding(.horizontal, Spacing.xs)
        }
    }

    private var bleButtonText: String {
        switch bleManager.state {
        case .disconnected, .error:
            return "Start BLE Scan"
        case .scanning:
            return "Scanning..."
        case .connecting:
            return "Connecting..."
        case .connected, .receiving:
            return "Disconnect"
        }
    }

    // MARK: - Data Points

    private var whoopDataPoints: [(icon: String, title: String, description: String)] {
        [
            ("heart.fill", "Recovery Score", "Daily readiness"),
            ("waveform.path.ecg", "Heart Rate Variability", "HRV metrics"),
            ("moon.zzz.fill", "Sleep Stages", "Quality analysis"),
            ("flame.fill", "Workout Strain", "Activity data"),
            ("figure.stand", "Body Measurements", "Physical stats")
        ]
    }
}

#Preview {
    NavigationStack {
        WHOOPSettingsView()
    }
}
