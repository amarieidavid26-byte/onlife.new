import SwiftUI
import WatchKit
import Combine

struct WatchFocusSessionView: View {
    @EnvironmentObject var workoutManager: WorkoutSessionManager
    @EnvironmentObject var flowCalculator: FlowScoreCalculator
    @EnvironmentObject var connectivity: WatchConnectivityManager

    @State private var targetDurationMinutes: Int = 25
    @State private var taskDescription: String = "Focus Session"
    @State private var showingSummary = false
    @State private var peakFlowScore: Int = 0
    @State private var timeInFlow: Int = 0
    @State private var flowEntryTime: Date?
    @State private var sessionStarted = false
    @State private var startError: String?
    @State private var isStarting = false

    // Session summary stats (saved when session ends)
    @State private var lastSessionDuration: Int = 0
    @State private var lastPeakFlow: Int = 0
    @State private var lastTimeInFlow: Int = 0

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            if sessionStarted && !showingSummary {
                // Active session UI
                ScrollView {
                    VStack(spacing: 12) {
                        countdownTimerSection
                        heartRateSection
                        flowScoreRing
                        controlButtons
                    }
                    .padding()
                }
            } else if showingSummary {
                // Session summary UI
                ScrollView {
                    summaryView
                        .padding()
                }
                .transition(.opacity)
            } else {
                // Pre-session UI
                ScrollView {
                    preSessionView
                        .padding()
                }
            }
        }
        .navigationTitle("Focus")
        .navigationBarBackButtonHidden(sessionStarted && !showingSummary)
        .animation(.easeInOut(duration: 0.3), value: sessionStarted)
        .animation(.easeInOut(duration: 0.3), value: showingSummary)
        .onChange(of: flowCalculator.currentScore.total) { _, newScore in
            if sessionStarted && newScore > peakFlowScore {
                peakFlowScore = newScore
            }
        }
        .onChange(of: flowCalculator.currentScore.state) { oldState, newState in
            if sessionStarted {
                handleFlowStateChange(from: oldState, to: newState)
            }
        }
        .onReceive(workoutManager.$currentHeartRate) { newHR in
            if sessionStarted {
                print("🔄 [WatchFocusSessionView] HR updated in view: \(newHR)")
            }
        }
        .onReceive(flowCalculator.$currentScore) { newScore in
            if sessionStarted {
                print("🧠 [WatchFocusSessionView] Flow score updated: \(newScore.total), state: \(newScore.state.displayName)")
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            // Timer fires every second to ensure countdown display updates
            // Haptic feedback at time milestones
            if sessionStarted {
                if remainingSeconds == 300 {
                    // 5 minutes remaining
                    WKInterfaceDevice.current().play(.notification)
                } else if remainingSeconds == 60 {
                    // 1 minute remaining
                    WKInterfaceDevice.current().play(.start)
                }
            }
        }
    }

    private func handleFlowStateChange(from oldState: FlowState, to newState: FlowState) {
        // Track time in flow
        if newState == .flow && oldState != .flow {
            flowEntryTime = Date()
        } else if oldState == .flow && newState != .flow {
            if let entry = flowEntryTime {
                timeInFlow += Int(Date().timeIntervalSince(entry))
            }
            flowEntryTime = nil
        }
    }

    // MARK: - Pre-Session View

    private var preSessionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("Focus Session")
                .font(.headline)

            // Task name input
            TextField("Task name", text: $taskDescription)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .font(.caption)

            // Duration display
            Text("\(targetDurationMinutes) minutes")
                .font(.caption)
                .foregroundColor(.gray)

            if let error = startError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                startSession()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isStarting ? Color.gray : Color.green)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(isStarting)

            Button(action: {
                dismiss()
            }) {
                Text("Cancel")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Summary View

    private var summaryView: some View {
        VStack(spacing: 16) {
            // Celebration header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.green)

                Text("Well Done!")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            // Stats grid
            VStack(spacing: 12) {
                // Duration - prominent
                VStack(spacing: 2) {
                    Text(formatTime(lastSessionDuration))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Duration")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                HStack(spacing: 24) {
                    // Peak Flow
                    VStack(spacing: 2) {
                        Text("\(lastPeakFlow)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        Text("Peak Flow")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    // Time in Flow
                    VStack(spacing: 2) {
                        Text(formatTime(lastTimeInFlow))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("In Flow")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
            )

            Button(action: {
                // Reset ALL state before dismissing
                showingSummary = false
                sessionStarted = false
                peakFlowScore = 0
                timeInFlow = 0
                flowEntryTime = nil
                lastSessionDuration = 0
                lastPeakFlow = 0
                lastTimeInFlow = 0

                // Now dismiss
                dismiss()
            }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            print("📊 [WatchFocusSessionView] Summary view appeared!")
            print("   Duration: \(lastSessionDuration)s, Peak: \(lastPeakFlow), Flow time: \(lastTimeInFlow)s")
            // Celebration haptic
            WKInterfaceDevice.current().play(.success)
        }
    }

    // MARK: - Countdown Timer

    private var remainingSeconds: Int {
        let targetSeconds = targetDurationMinutes * 60
        return max(0, targetSeconds - workoutManager.elapsedSeconds)
    }

    private var timerColor: Color {
        if remainingSeconds > 300 {
            return .green
        } else if remainingSeconds >= 60 {
            return .yellow
        } else {
            return .red
        }
    }

    private var countdownTimerSection: some View {
        VStack(spacing: 2) {
            Text(formatTime(remainingSeconds))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(timerColor)
                .lineLimit(1)
                .fixedSize()
                .minimumScaleFactor(0.8)

            Text("remaining")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Heart Rate Section

    private var heartRateSection: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
                .symbolEffect(.pulse, options: .repeating, value: workoutManager.currentHeartRate)

            Text("\(Int(workoutManager.currentHeartRate))")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text("BPM")
                .font(.caption)
                .foregroundColor(.gray)

            Spacer()

            // HRV indicator
            if workoutManager.currentRMSSD > 0 {
                VStack(alignment: .trailing) {
                    Text("\(Int(workoutManager.currentRMSSD))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.cyan)
                    Text("HRV")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .id(workoutManager.currentHeartRate)  // Force refresh on every HR change
        .padding(.vertical, 8)
    }

    // MARK: - Flow Score Ring

    private var flowScoreRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)

            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(flowCalculator.currentScore.total) / 100)
                .stroke(
                    flowStateColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: flowCalculator.currentScore.total)

            // Score text
            VStack(spacing: 2) {
                Text("\(flowCalculator.currentScore.total)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(flowStateColor)

                Text("FLOW")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 100, height: 100)
        .id(flowCalculator.currentScore.id)  // Force refresh when score changes
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 16) {
            // End Session Button
            Button(action: endSession) {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - Helpers

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

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Session Control

    private func startSession() {
        // Prevent multiple simultaneous start attempts
        guard !isStarting else {
            print("⚠️ [WatchFocusSessionView] Already starting session")
            return
        }

        guard !workoutManager.isSessionActive else {
            print("⚠️ [WatchFocusSessionView] Session already active")
            return
        }

        isStarting = true
        startError = nil

        // Validate task name
        let finalTaskName = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalTaskName.isEmpty {
            taskDescription = "Focus Session"
        }

        Task {
            do {
                // Configure session metadata before starting
                workoutManager.configureSession(
                    taskName: taskDescription,
                    targetDurationMinutes: targetDurationMinutes,
                    seedType: "oneTime",
                    plantSpecies: "oak"
                )

                try await workoutManager.startSession()
                flowCalculator.startScoring()

                await MainActor.run {
                    sessionStarted = true
                    isStarting = false
                    WKInterfaceDevice.current().play(.start)
                }

                // Sync state to iPhone (legacy - now handled by WorkoutSessionManager)
                let state = WatchSessionState(
                    isActive: true,
                    elapsedSeconds: 0,
                    currentHeartRate: 0,
                    currentFlowScore: 0,
                    currentFlowState: .preFlow,
                    taskDescription: taskDescription,
                    targetDurationMinutes: targetDurationMinutes
                )
                connectivity.syncSessionState(state)

                print("✅ [WatchFocusSessionView] Session started successfully")

            } catch {
                print("❌ [WatchFocusSessionView] Failed to start session: \(error)")
                await MainActor.run {
                    startError = error.localizedDescription
                    isStarting = false
                    WKInterfaceDevice.current().play(.failure)
                }
                // Do NOT dismiss - let user see the error and try again
            }
        }
    }

    private func endSession() {
        print("🛑 [WatchFocusSessionView] endSession() called")

        // Calculate final time in flow
        if flowCalculator.currentScore.state == .flow, let entry = flowEntryTime {
            timeInFlow += Int(Date().timeIntervalSince(entry))
        }

        // Determine if session was completed
        let wasCompleted = workoutManager.elapsedSeconds >= (targetDurationMinutes * 60)

        // Save stats for summary BEFORE any async work
        lastSessionDuration = workoutManager.elapsedSeconds
        lastPeakFlow = peakFlowScore
        lastTimeInFlow = timeInFlow

        print("   Stats saved - duration: \(lastSessionDuration)s, peak: \(lastPeakFlow), flowTime: \(lastTimeInFlow)s")

        // Show summary FIRST (before async operations)
        showingSummary = true
        sessionStarted = false  // This is safe now because we check showingSummary first in body

        // Haptic feedback
        WKInterfaceDevice.current().play(.success)

        // THEN do async cleanup
        Task {
            // Send to iPhone
            workoutManager.sendSessionEndToiPhone(
                wasCompleted: wasCompleted,
                peakFlowScore: peakFlowScore,
                timeInFlowSeconds: timeInFlow
            )

            // End workout session
            await workoutManager.endSession()
            flowCalculator.stopScoring()

            // Sync state
            connectivity.syncSessionState(.inactive)

            print("✅ [WatchFocusSessionView] Session cleanup complete, summary should be visible")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct WatchFocusSessionView_Previews: PreviewProvider {
    static var previews: some View {
        WatchFocusSessionView()
            .environmentObject(WorkoutSessionManager.shared)
            .environmentObject(FlowScoreCalculator.shared)
            .environmentObject(WatchConnectivityManager.shared)
    }
}
#endif
