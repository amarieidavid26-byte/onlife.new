import Foundation

// MARK: - Biometric Sample (real-time data point)

struct BiometricSample: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let heartRate: Double?
    let rmssd: Double?
    let rrIntervals: [Double]?

    init(timestamp: Date = Date(), heartRate: Double? = nil, rmssd: Double? = nil, rrIntervals: [Double]? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.rmssd = rmssd
        self.rrIntervals = rrIntervals
    }
}

// MARK: - Personal Baseline (14-day calibration data)

struct PersonalBaseline: Codable {
    var restingHR: Double                    // Mean resting HR (bpm)
    var restingHRStdDev: Double              // Standard deviation
    var baselineRMSSD: Double                // Mean RMSSD at rest (ms)
    var baselineRMSSDStdDev: Double          // Standard deviation
    var sleepScore: Double                   // 0-100 normalized
    var circadianHRVModifiers: [Int: Double] // Hour (0-23) -> multiplier
    var dataPointCount: Int                  // Total samples collected
    var lastUpdated: Date
    var isCalibrated: Bool                   // True if 14+ days of data

    /// Default baseline for new users (population averages)
    static var `default`: PersonalBaseline {
        PersonalBaseline(
            restingHR: 70.0,
            restingHRStdDev: 10.0,
            baselineRMSSD: 50.0,
            baselineRMSSDStdDev: 15.0,
            sleepScore: 70.0,
            circadianHRVModifiers: [:],
            dataPointCount: 0,
            lastUpdated: Date(),
            isCalibrated: false
        )
    }

    /// Update baseline with exponential moving average (called daily)
    mutating func update(newRestingHR: Double, newRMSSD: Double, newSleepScore: Double) {
        let alpha = 0.1  // Smoothing factor

        restingHR = alpha * newRestingHR + (1 - alpha) * restingHR
        baselineRMSSD = alpha * newRMSSD + (1 - alpha) * baselineRMSSD
        sleepScore = alpha * newSleepScore + (1 - alpha) * sleepScore
        dataPointCount += 1
        lastUpdated = Date()
        isCalibrated = dataPointCount >= 14
    }

    /// Get circadian-adjusted baseline RMSSD for current hour
    func adjustedBaselineRMSSD(forHour hour: Int) -> Double {
        let modifier = circadianHRVModifiers[hour] ?? 1.0
        return baselineRMSSD * modifier
    }
}

// MARK: - Flow Score (real-time calculation result)

struct FlowScore: Codable, Identifiable {
    let id: UUID
    let total: Int                  // 0-100
    let hrvSubscore: Double         // 0-40
    let hrSubscore: Double          // 0-30
    let sleepSubscore: Double       // 0-20
    let substanceSubscore: Double   // 0-10
    let confidence: Double          // 0-1 (based on calibration)
    let state: FlowState
    let timestamp: Date

    init(
        total: Int,
        hrvSubscore: Double,
        hrSubscore: Double,
        sleepSubscore: Double,
        substanceSubscore: Double,
        confidence: Double,
        state: FlowState
    ) {
        self.id = UUID()
        self.total = total
        self.hrvSubscore = hrvSubscore
        self.hrSubscore = hrSubscore
        self.sleepSubscore = sleepSubscore
        self.substanceSubscore = substanceSubscore
        self.confidence = confidence
        self.state = state
        self.timestamp = Date()
    }

    /// Placeholder score during calibration
    static var calibrating: FlowScore {
        FlowScore(
            total: 0,
            hrvSubscore: 0,
            hrSubscore: 0,
            sleepSubscore: 0,
            substanceSubscore: 0,
            confidence: 0,
            state: .calibrating
        )
    }
}

// MARK: - Flow State

enum FlowState: String, Codable, CaseIterable {
    case calibrating    // First 14 days, collecting baseline
    case baseline       // Not in session
    case preFlow        // Session started, warming up (first 2-3 min)
    case flow           // Optimal zone detected (score 70+)
    case postFlow       // Declining from flow (score dropped below 60)
    case overload       // Stress indicators (HR >150% AND RMSSD <50%)
    case disengaged     // Low arousal (score <30)

    var displayName: String {
        switch self {
        case .calibrating: return "Calibrating"
        case .baseline: return "Ready"
        case .preFlow: return "Warming Up"
        case .flow: return "In Flow"
        case .postFlow: return "Winding Down"
        case .overload: return "Overloaded"
        case .disengaged: return "Unfocused"
        }
    }

    var color: String {
        switch self {
        case .calibrating: return "gray"
        case .baseline: return "blue"
        case .preFlow: return "yellow"
        case .flow: return "green"
        case .postFlow: return "orange"
        case .overload: return "red"
        case .disengaged: return "purple"
        }
    }

    var iconName: String {
        switch self {
        case .calibrating: return "gauge.with.dots.needle.0percent"
        case .baseline: return "circle.dashed"
        case .preFlow: return "flame"
        case .flow: return "brain.head.profile"
        case .postFlow: return "arrow.down.circle"
        case .overload: return "exclamationmark.triangle"
        case .disengaged: return "moon.zzz"
        }
    }
}

// MARK: - Focus Session with Biometrics

struct BiometricFocusSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var taskDescription: String
    var durationMinutes: Int

    // Biometric data
    var heartRateSamples: [BiometricSample]
    var flowScores: [FlowScore]
    var peakFlowScore: Int
    var averageHeartRate: Double
    var averageRMSSD: Double
    var timeInFlowSeconds: Int

    // Substance context
    var activeCaffeineAtStart: Double
    var activeLTheanineAtStart: Double

    var completed: Bool

    init(taskDescription: String, durationMinutes: Int, caffeine: Double, lTheanine: Double) {
        self.id = UUID()
        self.startTime = Date()
        self.taskDescription = taskDescription
        self.durationMinutes = durationMinutes
        self.heartRateSamples = []
        self.flowScores = []
        self.peakFlowScore = 0
        self.averageHeartRate = 0
        self.averageRMSSD = 0
        self.timeInFlowSeconds = 0
        self.activeCaffeineAtStart = caffeine
        self.activeLTheanineAtStart = lTheanine
        self.completed = false
    }

    var flowTimePercent: Double {
        guard let end = endTime else { return 0 }
        let totalSeconds = end.timeIntervalSince(startTime)
        return totalSeconds > 0 ? (Double(timeInFlowSeconds) / totalSeconds) * 100 : 0
    }

    /// Calculate summary statistics when session ends
    mutating func finalize() {
        endTime = Date()
        completed = true

        // Calculate averages
        if !heartRateSamples.isEmpty {
            let validHRs = heartRateSamples.compactMap { $0.heartRate }
            averageHeartRate = validHRs.isEmpty ? 0 : validHRs.reduce(0, +) / Double(validHRs.count)

            let validRMSSDs = heartRateSamples.compactMap { $0.rmssd }
            averageRMSSD = validRMSSDs.isEmpty ? 0 : validRMSSDs.reduce(0, +) / Double(validRMSSDs.count)
        }

        // Calculate peak and time in flow
        if !flowScores.isEmpty {
            peakFlowScore = flowScores.map { $0.total }.max() ?? 0

            // Count time in flow (60 seconds per score since we update every minute)
            timeInFlowSeconds = flowScores.filter { $0.state == .flow }.count * 60
        }
    }
}

// MARK: - Watch Session State (for WatchConnectivity sync)

struct WatchSessionState: Codable {
    var isActive: Bool
    var elapsedSeconds: Int
    var currentHeartRate: Double
    var currentFlowScore: Int
    var currentFlowState: FlowState
    var taskDescription: String
    var targetDurationMinutes: Int

    static var inactive: WatchSessionState {
        WatchSessionState(
            isActive: false,
            elapsedSeconds: 0,
            currentHeartRate: 0,
            currentFlowScore: 0,
            currentFlowState: .baseline,
            taskDescription: "",
            targetDurationMinutes: 0
        )
    }
}

// MARK: - Biometric Session History (for persistence)

struct BiometricSessionHistory: Codable {
    var sessions: [BiometricFocusSession]
    var lastUpdated: Date

    static var empty: BiometricSessionHistory {
        BiometricSessionHistory(sessions: [], lastUpdated: Date())
    }

    mutating func addSession(_ session: BiometricFocusSession) {
        sessions.append(session)
        lastUpdated = Date()

        // Keep only last 100 sessions
        if sessions.count > 100 {
            sessions.removeFirst(sessions.count - 100)
        }
    }

    /// Get average flow time percentage over last N sessions
    func averageFlowTimePercent(lastN: Int = 10) -> Double {
        let recentSessions = Array(sessions.suffix(lastN))
        guard !recentSessions.isEmpty else { return 0 }
        return recentSessions.map { $0.flowTimePercent }.reduce(0, +) / Double(recentSessions.count)
    }

    /// Get trend: positive means improving, negative means declining
    func flowTrend(lastN: Int = 10) -> Double {
        let recentSessions = Array(sessions.suffix(lastN))
        guard recentSessions.count >= 3 else { return 0 }

        let firstHalf = Array(recentSessions.prefix(recentSessions.count / 2))
        let secondHalf = Array(recentSessions.suffix(recentSessions.count / 2))

        let firstAvg = firstHalf.map { $0.flowTimePercent }.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map { $0.flowTimePercent }.reduce(0, +) / Double(secondHalf.count)

        return secondAvg - firstAvg
    }
}
