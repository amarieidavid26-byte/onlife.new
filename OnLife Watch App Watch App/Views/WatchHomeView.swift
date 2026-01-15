import SwiftUI
import WatchKit

struct WatchHomeView: View {
    @EnvironmentObject var workoutManager: WorkoutSessionManager
    @EnvironmentObject var flowCalculator: FlowScoreCalculator
    @EnvironmentObject var connectivity: WatchConnectivityManager

    @State private var showingSession = false
    @State private var isRequestingAuth = false
    @State private var selectedGardenName: String?

    // Alert states
    @State private var showLowBatteryAlert = false
    @State private var showOfflineAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status Card
                statusCard

                // Authorization or Start Button
                if !workoutManager.isAuthorized {
                    authorizationButton
                } else if !workoutManager.isSessionActive {
                    startButton
                } else {
                    activeSessionCard
                }

                // Garden Selection
                NavigationLink(destination: WatchGardenPickerView()) {
                    HStack {
                        Image(systemName: "leaf.circle")
                            .foregroundColor(.green)
                        Text("Choose Garden")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Baseline Status
                baselineStatus
            }
            .padding()
        }
        .navigationTitle("OnLife")
        .fullScreenCover(isPresented: $showingSession) {
            WatchFocusSessionView()
        }
        .alert("Low Battery", isPresented: $showLowBatteryAlert) {
            Button("Start Anyway") {
                showingSession = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your Watch battery is below 20%. Session may not complete.")
        }
        .alert("iPhone Not Connected", isPresented: $showOfflineAlert) {
            Button("Start Anyway") {
                showingSession = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Session data will sync when reconnected.")
        }
        .onAppear {
            workoutManager.checkAuthorizationStatus()
            // Load selected garden name
            if let _ = UserDefaults.standard.string(forKey: "selectedGardenID"),
               let gardenName = UserDefaults.standard.string(forKey: "selectedGardenName") {
                selectedGardenName = gardenName
            }
        }
        // REMOVED: Auto-dismiss that was killing summary view
        // The WatchFocusSessionView now handles its own dismissal
    }

    // MARK: - Authorization Button

    private var authorizationButton: some View {
        Button(action: {
            requestAuthorization()
        }) {
            VStack(spacing: 8) {
                if isRequestingAuth {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(height: 32)
                } else {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }

                Text(isRequestingAuth ? "Authorizing..." : "Enable HealthKit")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Required for biometrics")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isRequestingAuth)
    }

    private func requestAuthorization() {
        isRequestingAuth = true
        Task {
            do {
                try await workoutManager.requestAuthorization()
                print("✅ [WatchHomeView] Authorization complete, ready to start sessions")
            } catch {
                print("❌ [WatchHomeView] Authorization failed: \(error)")
                // Reset authorization flag so user can try again
                await MainActor.run {
                    workoutManager.isAuthorized = false
                }
            }
            await MainActor.run {
                isRequestingAuth = false
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: connectivity.isReachable ? "iphone" : "iphone.slash")
                    .foregroundColor(connectivity.isReachable ? .green : .gray)

                Text(connectivity.isReachable ? "Connected" : "Offline")
                    .font(.caption)
                    .foregroundColor(connectivity.isReachable ? .green : .gray)
            }

            if flowCalculator.baseline.isCalibrated {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Calibrated")
                        .font(.caption)
                }
            } else {
                HStack {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .foregroundColor(.yellow)
                    Text("Calibrating (\(flowCalculator.baseline.dataPointCount)/14)")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button(action: {
            checkConditionsAndStart()
        }) {
            VStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.green)

                Text("Start Focus Session")
                    .font(.headline)
                    .foregroundColor(.white)

                if let gardenName = selectedGardenName {
                    Text(gardenName)
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("25 min")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.green.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session Start Checks

    private func checkConditionsAndStart() {
        // Enable battery monitoring
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        let batteryLevel = WKInterfaceDevice.current().batteryLevel

        // Check battery level (batteryLevel is -1 if monitoring not available)
        if batteryLevel >= 0 && batteryLevel < 0.2 {
            showLowBatteryAlert = true
            return
        }

        // Check connectivity
        if !connectivity.isReachable {
            showOfflineAlert = true
            return
        }

        // All checks passed, start session
        showingSession = true
    }

    // MARK: - Active Session Card

    private var activeSessionCard: some View {
        Button(action: {
            showingSession = true
        }) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.green)

                    Text("Session Active")
                        .font(.headline)
                }

                HStack(spacing: 16) {
                    VStack {
                        Text("\(workoutManager.elapsedSeconds / 60)")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("min")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    VStack {
                        Text("\(Int(workoutManager.currentHeartRate))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("BPM")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    VStack {
                        Text("\(flowCalculator.currentScore.total)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(flowStateColor)
                        Text("Flow")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.2))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Baseline Status

    private var baselineStatus: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Baseline")
                .font(.caption)
                .foregroundColor(.gray)

            HStack {
                VStack {
                    Text("\(Int(flowCalculator.baseline.restingHR))")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("HR")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack {
                    Text("\(Int(flowCalculator.baseline.baselineRMSSD))")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("HRV")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack {
                    Text("\(Int(flowCalculator.sleepScore))")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Sleep")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }

    private var flowStateColor: Color {
        switch flowCalculator.currentScore.state {
        case .flow: return .green
        case .preFlow: return .yellow
        case .postFlow: return .orange
        case .overload: return .red
        case .disengaged: return .purple
        case .calibrating: return .gray
        case .baseline: return .blue
        }
    }
}

#if DEBUG
struct WatchHomeView_Previews: PreviewProvider {
    static var previews: some View {
        WatchHomeView()
            .environmentObject(WorkoutSessionManager.shared)
            .environmentObject(FlowScoreCalculator.shared)
            .environmentObject(WatchConnectivityManager.shared)
    }
}
#endif
