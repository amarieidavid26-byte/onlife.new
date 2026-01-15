import Foundation
import Combine
import WatchKit

/// Calculates real-time flow score from biometric data
final class FlowScoreCalculator: ObservableObject {
    static let shared = FlowScoreCalculator()

    private let workoutManager = WorkoutSessionManager.shared
    private let connectivityManager = WatchConnectivityManager.shared

    private var cancellables = Set<AnyCancellable>()
    private var scoreHistory: [Int] = []  // For hysteresis
    private var currentState: FlowState = .baseline
    private var stateEnteredAt: Date = Date()

    // MARK: - Configuration

    private let minimumStateDuration: TimeInterval = 60  // 1 minute hysteresis
    private let flowThreshold = 70
    private let disengagedThreshold = 30
    private let overloadHRThreshold = 1.5  // 50% above resting
    private let overloadHRVThreshold = 0.5  // Below 50% of baseline

    // MARK: - Published Properties

    @Published var currentScore: FlowScore = .calibrating
    @Published var baseline: PersonalBaseline = .default
    @Published var activeCaffeine: Double = 0
    @Published var activeLTheanine: Double = 0
    @Published var sleepScore: Double = 70

    // Update timer
    private var updateTimer: Timer?

    private init() {
        loadBaseline()
        setupSubscriptions()
    }

    // MARK: - Setup

    private func loadBaseline() {
        if let stored = connectivityManager.getStoredBaseline() {
            baseline = stored
            print("📊 [FlowScore] Loaded baseline: HR=\(baseline.restingHR), RMSSD=\(baseline.baselineRMSSD)")
        }
    }

    private func setupSubscriptions() {
        // Listen for substance updates from iPhone
        NotificationCenter.default.publisher(for: .substanceLevelsUpdated)
            .sink { [weak self] notification in
                if let caffeine = notification.userInfo?["caffeine"] as? Double,
                   let lTheanine = notification.userInfo?["lTheanine"] as? Double {
                    self?.updateSubstanceLevels(caffeine: caffeine, lTheanine: lTheanine)
                }
            }
            .store(in: &cancellables)

        // Listen for sleep score updates
        NotificationCenter.default.publisher(for: .sleepScoreUpdated)
            .sink { [weak self] notification in
                if let score = notification.userInfo?["sleepScore"] as? Double {
                    self?.updateSleepScore(score)
                }
            }
            .store(in: &cancellables)

        // Listen for HR updates to trigger recalculation
        workoutManager.$currentHeartRate
            .dropFirst()
            .debounce(for: .seconds(5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.calculateScore()
            }
            .store(in: &cancellables)
    }

    // MARK: - Start/Stop Scoring

    func startScoring() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.calculateScore()
        }

        // Initial calculation after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.calculateScore()
        }

        print("🧠 [FlowScore] Scoring started")
    }

    func stopScoring() {
        updateTimer?.invalidate()
        updateTimer = nil
        currentState = .baseline
        scoreHistory.removeAll()
        print("🧠 [FlowScore] Scoring stopped")
    }

    // MARK: - Main Calculation

    func calculateScore() {
        // Check if we're calibrated
        guard baseline.isCalibrated else {
            currentScore = .calibrating
            print("⚠️ [FlowScore] Still calibrating (\(baseline.dataPointCount)/14 days)")
            return
        }

        let currentHR = workoutManager.currentHeartRate
        let currentRMSSD = workoutManager.currentRMSSD
        let minutesInSession = workoutManager.elapsedSeconds / 60

        // Skip if no data yet
        guard currentHR > 0 else {
            print("⚠️ [FlowScore] No HR data yet")
            return
        }

        // Get circadian-adjusted baseline
        let hour = Calendar.current.component(.hour, from: Date())
        let adjustedBaselineRMSSD = baseline.adjustedBaselineRMSSD(forHour: hour)

        // A) HRV Subscore (40% weight)
        let hrvSubscore = calculateHRVSubscore(
            currentRMSSD: currentRMSSD,
            baselineRMSSD: adjustedBaselineRMSSD
        )

        // B) Heart Rate Subscore (30% weight)
        let hrSubscore = calculateHRSubscore(
            currentHR: currentHR,
            restingHR: baseline.restingHR
        )

        // C) Sleep Recovery Subscore (20% weight)
        let sleepSubscore = sleepScore * 0.2

        // D) Substance Timing Subscore (10% weight)
        let substanceSubscore = calculateSubstanceSubscore()

        // Total
        let total = Int(hrvSubscore + hrSubscore + sleepSubscore + substanceSubscore)

        // Confidence based on calibration quality
        let confidence = min(1.0, Double(baseline.dataPointCount) / 30.0)

        // Determine state with hysteresis
        let hrvRatio = currentRMSSD / max(1, adjustedBaselineRMSSD)
        let hrRatio = currentHR / max(1, baseline.restingHR)

        let state = determineState(
            score: total,
            hrvRatio: hrvRatio,
            hrRatio: hrRatio,
            minutesInSession: minutesInSession
        )

        // Create score
        let newScore = FlowScore(
            total: total,
            hrvSubscore: hrvSubscore,
            hrSubscore: hrSubscore,
            sleepSubscore: sleepSubscore,
            substanceSubscore: substanceSubscore,
            confidence: confidence,
            state: state
        )

        currentScore = newScore

        // Send to iPhone
        connectivityManager.sendFlowScore(newScore)

        // Sync session state
        let sessionState = WatchSessionState(
            isActive: workoutManager.isSessionActive,
            elapsedSeconds: workoutManager.elapsedSeconds,
            currentHeartRate: currentHR,
            currentFlowScore: total,
            currentFlowState: state,
            taskDescription: "",
            targetDurationMinutes: 25
        )
        connectivityManager.syncSessionState(sessionState)

        print("🧠 [FlowScore] Score: \(total) | HRV:\(Int(hrvSubscore)) HR:\(Int(hrSubscore)) Sleep:\(Int(sleepSubscore)) Sub:\(Int(substanceSubscore)) | State: \(state.displayName)")
    }

    // MARK: - Subscore Calculations

    private func calculateHRVSubscore(currentRMSSD: Double, baselineRMSSD: Double) -> Double {
        guard baselineRMSSD > 0 else { return 20 }  // Default if no baseline

        let ratio = currentRMSSD / baselineRMSSD

        // Optimal flow: 70-90% of baseline (moderate reduction)
        // Based on research: flow = moderate vagal withdrawal
        if ratio >= 0.7 && ratio <= 0.9 {
            return 40.0
        } else if ratio > 0.9 && ratio <= 1.1 {
            // Near baseline: light engagement
            return 20.0 + 20.0 * (1.1 - ratio) / 0.2
        } else if ratio >= 0.5 && ratio < 0.7 {
            // Too low: possible stress/overload
            return 40.0 * (ratio - 0.5) / 0.2
        } else if ratio > 1.1 && ratio <= 1.3 {
            // Elevated: very relaxed (not in flow)
            return 20.0 - 10.0 * (ratio - 1.1) / 0.2
        } else {
            // Out of range
            return max(0, 10.0 - abs(ratio - 0.8) * 20.0)
        }
    }

    private func calculateHRSubscore(currentHR: Double, restingHR: Double) -> Double {
        guard restingHR > 0 else { return 15 }

        let ratio = currentHR / restingHR

        // Optimal flow: 110-130% of resting (moderate arousal)
        if ratio >= 1.1 && ratio <= 1.3 {
            return 30.0
        } else if ratio >= 1.0 && ratio < 1.1 {
            // Slightly elevated: warming up
            return 20.0 + 10.0 * (ratio - 1.0) / 0.1
        } else if ratio > 1.3 && ratio <= 1.5 {
            // High arousal: possible anxiety
            return 30.0 - 15.0 * (ratio - 1.3) / 0.2
        } else if ratio > 1.5 {
            // Very high: likely overload
            return max(0, 15.0 - (ratio - 1.5) * 30.0)
        } else {
            // Below resting: disengaged
            return max(0, 10.0 + (ratio - 0.8) * 25.0)
        }
    }

    private func calculateSubstanceSubscore() -> Double {
        var score: Double = 5.0  // Base points

        // Caffeine bonus (50-200mg optimal range)
        if activeCaffeine >= 50 && activeCaffeine <= 200 {
            score += 2.5
        } else if activeCaffeine > 200 && activeCaffeine <= 300 {
            score += 1.5  // Slightly over optimal
        }

        // L-theanine synergy bonus (1:2 ratio with caffeine is optimal)
        if activeLTheanine >= 100 && activeCaffeine > 0 {
            let ratio = activeLTheanine / activeCaffeine
            if ratio >= 1.5 && ratio <= 2.5 {
                score += 2.5  // Optimal synergy
            } else if ratio >= 1.0 && ratio < 1.5 {
                score += 1.5  // Good ratio
            }
        }

        return score
    }

    // MARK: - State Determination (with Hysteresis)

    private func determineState(score: Int, hrvRatio: Double, hrRatio: Double, minutesInSession: Int) -> FlowState {
        scoreHistory.append(score)
        if scoreHistory.count > 5 { scoreHistory.removeFirst() }

        let avgScore = scoreHistory.reduce(0, +) / max(scoreHistory.count, 1)
        let timeSinceStateChange = Date().timeIntervalSince(stateEnteredAt)

        // Hysteresis: don't change state too quickly
        guard timeSinceStateChange >= minimumStateDuration else {
            return currentState
        }

        var newState = currentState

        // Check for overload (highest priority)
        if hrRatio > overloadHRThreshold && hrvRatio < overloadHRVThreshold {
            newState = .overload
        }
        // Check for flow entry (score 70+)
        else if avgScore >= flowThreshold && currentState != .flow {
            newState = .flow
        }
        // Check for flow exit (score dropped below 60)
        else if avgScore < flowThreshold - 10 && currentState == .flow {
            newState = .postFlow
        }
        // Check for disengagement (very low score)
        else if avgScore < disengagedThreshold {
            newState = .disengaged
        }
        // Pre-flow warmup (first 2-3 minutes of session)
        else if minutesInSession < 3 && (currentState == .baseline || currentState == .calibrating) {
            newState = .preFlow
        }

        // Update state if changed
        if newState != currentState {
            currentState = newState
            stateEnteredAt = Date()
            triggerHapticForStateChange(newState)
        }

        return currentState
    }

    // MARK: - Haptics

    private func triggerHapticForStateChange(_ state: FlowState) {
        switch state {
        case .flow:
            WKInterfaceDevice.current().play(.success)
        case .overload:
            WKInterfaceDevice.current().play(.failure)
        case .postFlow, .disengaged:
            WKInterfaceDevice.current().play(.notification)
        default:
            WKInterfaceDevice.current().play(.click)
        }
    }

    // MARK: - Update Substance Levels

    func updateSubstanceLevels(caffeine: Double, lTheanine: Double) {
        activeCaffeine = caffeine
        activeLTheanine = lTheanine
        print("💊 [FlowScore] Updated: Caffeine=\(caffeine)mg, L-theanine=\(lTheanine)mg")
    }

    func updateSleepScore(_ score: Double) {
        sleepScore = score
        print("😴 [FlowScore] Updated sleep score: \(score)")
    }

    func updateBaseline(_ newBaseline: PersonalBaseline) {
        baseline = newBaseline
        print("📊 [FlowScore] Updated baseline")
    }
}
