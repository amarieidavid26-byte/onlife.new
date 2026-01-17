import Foundation
import Combine

// MARK: - Fatigue Level
/// Represents the detected fatigue level with contributing signals and recommendations.
/// Research basis: Response time variability increases with fatigue (more diagnostic than mean slowing).
struct FatigueLevel: Codable {
    let score: Double           // 0-1 (0 = fresh, 1 = exhausted)
    let level: Level
    let signals: [FatigueSignal]
    let recommendation: String
    let timestamp: Date

    enum Level: String, Codable {
        case fresh = "Fresh"
        case mild = "Mild Fatigue"
        case moderate = "Moderate Fatigue"
        case high = "High Fatigue"
        case severe = "Severe Fatigue"

        init(score: Double) {
            switch score {
            case 0..<0.2: self = .fresh
            case 0.2..<0.4: self = .mild
            case 0.4..<0.6: self = .moderate
            case 0.6..<0.8: self = .high
            default: self = .severe
            }
        }

        var icon: String {
            switch self {
            case .fresh: return "⚡️"
            case .mild: return "🙂"
            case .moderate: return "😐"
            case .high: return "😓"
            case .severe: return "😴"
            }
        }

        var color: String {
            switch self {
            case .fresh: return "green"
            case .mild: return "yellow"
            case .moderate: return "orange"
            case .high: return "red"
            case .severe: return "darkRed"
            }
        }
    }

    init(score: Double, signals: [FatigueSignal]) {
        self.score = max(0, min(1, score))
        self.level = Level(score: self.score)
        self.signals = signals
        self.recommendation = FatigueLevel.generateRecommendation(level: self.level, signals: signals)
        self.timestamp = Date()
    }

    private static func generateRecommendation(level: Level, signals: [FatigueSignal]) -> String {
        switch level {
        case .fresh:
            return "You're well-rested. Great time for challenging work!"
        case .mild:
            return "Slight fatigue detected. Stay hydrated and take regular breaks."
        case .moderate:
            return "Moderate fatigue. Consider a 10-15 minute break soon."
        case .high:
            return "High fatigue detected. Take a 20-minute break or power nap."
        case .severe:
            return "You're pushing too hard. Rest now to avoid burnout."
        }
    }

    /// Multiplier to apply to flow score expectations (1.0 = no adjustment)
    var flowScoreMultiplier: Double {
        switch level {
        case .fresh: return 1.0
        case .mild: return 0.95
        case .moderate: return 0.85
        case .high: return 0.75
        case .severe: return 0.6
        }
    }

    /// Whether to show a warning to the user
    var shouldWarn: Bool {
        level == .high || level == .severe
    }
}

// MARK: - Fatigue Signals
/// Individual signals that contribute to fatigue detection.
enum FatigueSignal: String, Codable, CaseIterable {
    case longSession = "Extended session without break"
    case manySessions = "Many sessions today"
    case lateHour = "Late hour working"
    case earlyHour = "Very early hour working"
    case inconsistentTouches = "Inconsistent interaction pattern"
    case decliningCompletion = "Declining completion rate"
    case shortRecovery = "Insufficient recovery between sessions"
    case longHoursAwake = "Many hours since wake"
    case poorSleepHistory = "Recent poor sleep"
    case highPauseRate = "Frequent session pauses"

    var description: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .longSession: return "⏱️"
        case .manySessions: return "📊"
        case .lateHour: return "🌙"
        case .earlyHour: return "🌅"
        case .inconsistentTouches: return "👆"
        case .decliningCompletion: return "📉"
        case .shortRecovery: return "⚡️"
        case .longHoursAwake: return "😵"
        case .poorSleepHistory: return "😴"
        case .highPauseRate: return "⏸️"
        }
    }

    /// Severity weight of this signal (0-1)
    var weight: Double {
        switch self {
        case .longSession: return 0.3
        case .manySessions: return 0.25
        case .lateHour: return 0.15
        case .earlyHour: return 0.2
        case .inconsistentTouches: return 0.12
        case .decliningCompletion: return 0.1
        case .shortRecovery: return 0.1
        case .longHoursAwake: return 0.15
        case .poorSleepHistory: return 0.12
        case .highPauseRate: return 0.08
        }
    }
}

// MARK: - Mid-Session Fatigue Alert
/// Alert shown during an active session when fatigue is detected.
struct MidSessionFatigueAlert: Codable {
    let type: AlertType
    let message: String
    let urgency: Urgency
    let sessionDuration: TimeInterval
    let timestamp: Date

    enum AlertType: String, Codable {
        case breakSuggestion = "Break Suggestion"
        case breakWarning = "Break Warning"
        case fatigueDetected = "Fatigue Detected"
    }

    enum Urgency: String, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var shouldVibrate: Bool {
            self != .low
        }

        var shouldInterrupt: Bool {
            self == .high
        }
    }

    init(type: AlertType, message: String, urgency: Urgency, sessionDuration: TimeInterval) {
        self.type = type
        self.message = message
        self.urgency = urgency
        self.sessionDuration = sessionDuration
        self.timestamp = Date()
    }
}

// MARK: - Sleep Record (for fatigue context)
/// Records sleep data for fatigue calculation.
/// Can be populated from HealthKit or manual entry.
struct SleepRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let duration: TimeInterval  // Total sleep in seconds
    let quality: Double         // 0-1 (subjective or derived from HRV)
    let bedtime: Date?
    let wakeTime: Date?

    init(
        id: UUID = UUID(),
        date: Date,
        duration: TimeInterval,
        quality: Double,
        bedtime: Date? = nil,
        wakeTime: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.quality = max(0, min(1, quality))
        self.bedtime = bedtime
        self.wakeTime = wakeTime
    }

    /// Hours of sleep
    var hoursSlept: Double {
        duration / 3600
    }

    /// Whether sleep duration meets recommended minimum (7 hours)
    var isSufficientDuration: Bool {
        hoursSlept >= 7
    }
}

// MARK: - Fatigue Detection Engine
/// Detects fatigue from behavioral signals to warn users and adjust expectations.
/// Research basis:
/// - Response time VARIABILITY increases with fatigue (more diagnostic than mean slowing)
/// - Sessions >90 min without breaks show diminishing returns
/// - Daily deep work cap: ~4 hours for elite performers (Ericsson)
class FatigueDetectionEngine: ObservableObject {
    static let shared = FatigueDetectionEngine()

    @Published var currentFatigueLevel: FatigueLevel?
    @Published var lastAlert: MidSessionFatigueAlert?

    // Research-based thresholds
    private let maxOptimalSessionMinutes: Double = 90
    private let maxDailyDeepWorkHours: Double = 4
    private let minRecoveryMinutes: Double = 30
    private let lateHourThreshold: Int = 23   // 11 PM
    private let earlyHourThreshold: Int = 5   // 5 AM
    private let biologicalNightStart: Int = 3
    private let biologicalNightEnd: Int = 5

    // Alert cooldowns to prevent spam
    private var lastAlertTime: Date?
    private let alertCooldownMinutes: Double = 15

    // Storage
    private let sleepHistoryKey = "onlife_sleep_history"

    private init() {}

    // MARK: - Main Detection

    /// Detect fatigue level from current session and context
    /// Call this before each session to set expectations
    func detectFatigue(
        currentSessionDuration: TimeInterval = 0,
        features: BehavioralFeatures,
        sessionHistory: [FocusSession],
        sleepHistory: [SleepRecord]? = nil,
        baseline: UserBehavioralBaseline,
        hoursSinceWake: Double? = nil
    ) -> FatigueLevel {

        var fatigueScore = 0.0
        var signals: [FatigueSignal] = []

        // === SIGNAL 1: Session Duration ===
        // Research: >90 min without break = diminishing returns
        if currentSessionDuration > maxOptimalSessionMinutes * 60 {
            let overtime = (currentSessionDuration - maxOptimalSessionMinutes * 60) / (30 * 60)
            fatigueScore += min(0.3, overtime * 0.1)  // +10% per 30 min over
            signals.append(.longSession)
        }

        // === SIGNAL 2: Total Deep Work Today ===
        // Research: Elite performers max ~4 hours/day (Ericsson)
        let todaysSessions = getTodaysSessions(from: sessionHistory)
        let totalDeepWorkToday = todaysSessions.reduce(0.0) { $0 + $1.actualDuration } + currentSessionDuration
        let deepWorkHours = totalDeepWorkToday / 3600

        if deepWorkHours > maxDailyDeepWorkHours {
            let overtime = deepWorkHours - maxDailyDeepWorkHours
            fatigueScore += min(0.25, overtime * 0.1)  // +10% per hour over
            signals.append(.manySessions)
        }

        // === SIGNAL 3: Session Count Today ===
        let sessionCountToday = todaysSessions.count + (currentSessionDuration > 0 ? 1 : 0)
        if sessionCountToday > 6 {
            fatigueScore += 0.15
            if !signals.contains(.manySessions) {
                signals.append(.manySessions)
            }
        } else if sessionCountToday > 4 {
            fatigueScore += 0.08
        }

        // === SIGNAL 4: Late/Early Hour ===
        let currentHour = features.hourOfDay
        if currentHour >= lateHourThreshold {
            fatigueScore += 0.15
            signals.append(.lateHour)
        }
        if currentHour <= earlyHourThreshold && currentHour > 0 {
            fatigueScore += 0.15
            signals.append(.earlyHour)
        }
        // Biological night (3-5 AM) - additional penalty
        if currentHour >= biologicalNightStart && currentHour <= biologicalNightEnd {
            fatigueScore += 0.1
        }

        // === SIGNAL 5: Touch Pattern Irregularity ===
        // Research: Response time VARIABILITY is more diagnostic than mean
        if features.touchIntervalVariance > 0 && baseline.avgTouchVariance > 0 {
            if features.touchIntervalVariance > baseline.avgTouchVariance * 1.5 {
                fatigueScore += 0.12
                signals.append(.inconsistentTouches)
            } else if features.touchIntervalVariance > baseline.avgTouchVariance * 1.3 {
                fatigueScore += 0.06
            }
        }

        // === SIGNAL 6: Declining Completion Rate ===
        let recentCompletionTrend = calculateCompletionTrend(from: sessionHistory)
        if recentCompletionTrend < -0.15 {  // >15% decline
            fatigueScore += 0.1
            signals.append(.decliningCompletion)
        }

        // === SIGNAL 7: Recovery Time Since Last Session ===
        if let minSinceLast = features.minutesSinceLastSession {
            if Double(minSinceLast) < minRecoveryMinutes && minSinceLast > 0 {
                fatigueScore += 0.1
                signals.append(.shortRecovery)
            }
        }

        // === SIGNAL 8: Hours Since Wake ===
        // Fatigue accumulates throughout the day (homeostatic sleep pressure)
        if let hoursAwake = hoursSinceWake {
            if hoursAwake > 14 {
                fatigueScore += 0.15
                signals.append(.longHoursAwake)
            } else if hoursAwake > 12 {
                fatigueScore += 0.08
            } else if hoursAwake > 10 {
                fatigueScore += 0.04
            }
        }

        // === SIGNAL 9: Recent Sleep Quality ===
        if let sleepHistory = sleepHistory, !sleepHistory.isEmpty {
            let recentSleep = Array(sleepHistory.prefix(3))
            let avgQuality = recentSleep.map { $0.quality }.reduce(0, +) / Double(recentSleep.count)
            let avgDuration = recentSleep.map { $0.hoursSlept }.reduce(0, +) / Double(recentSleep.count)

            if avgQuality < 0.6 || avgDuration < 6 {
                fatigueScore += 0.12
                signals.append(.poorSleepHistory)
            } else if avgQuality < 0.75 || avgDuration < 7 {
                fatigueScore += 0.06
            }
        }

        // === SIGNAL 10: High Pause Rate ===
        if features.pauseCount > 0 && features.sessionDuration > 0 {
            let pauseRate = Double(features.pauseCount) / (features.sessionDuration / 60 / 15) // pauses per 15 min
            if pauseRate > 2 {
                fatigueScore += 0.08
                signals.append(.highPauseRate)
            }
        }

        let fatigueLevel = FatigueLevel(score: fatigueScore, signals: signals)
        currentFatigueLevel = fatigueLevel

        print("😴 [Fatigue] Detected: \(fatigueLevel.level.rawValue) (score: \(String(format: "%.2f", fatigueScore))), Signals: \(signals.map { $0.rawValue })")

        return fatigueLevel
    }

    // MARK: - Mid-Session Monitoring

    /// Real-time fatigue check during session
    /// Call every 5-10 minutes during active session
    func checkMidSessionFatigue(
        sessionDuration: TimeInterval,
        pauseCount: Int,
        touchVariance: Double,
        baseline: UserBehavioralBaseline
    ) -> MidSessionFatigueAlert? {

        // Check cooldown
        if let lastAlert = lastAlertTime,
           Date().timeIntervalSince(lastAlert) < alertCooldownMinutes * 60 {
            return nil
        }

        var alert: MidSessionFatigueAlert?

        // Check for session length milestones
        let minutes = Int(sessionDuration / 60)

        if minutes >= 55 && minutes < 65 {
            alert = MidSessionFatigueAlert(
                type: .breakSuggestion,
                message: "You've been focused for an hour. Consider a short break.",
                urgency: .low,
                sessionDuration: sessionDuration
            )
        } else if minutes >= 85 && minutes < 95 {
            alert = MidSessionFatigueAlert(
                type: .breakSuggestion,
                message: "90 minutes reached. Taking a break now maximizes productivity.",
                urgency: .medium,
                sessionDuration: sessionDuration
            )
        } else if minutes >= 115 && minutes < 125 {
            alert = MidSessionFatigueAlert(
                type: .breakWarning,
                message: "Extended session detected. Fatigue may be affecting your work quality.",
                urgency: .high,
                sessionDuration: sessionDuration
            )
        } else if minutes >= 150 {
            alert = MidSessionFatigueAlert(
                type: .breakWarning,
                message: "2.5+ hours without a break. Your cognitive performance is likely declining.",
                urgency: .high,
                sessionDuration: sessionDuration
            )
        }

        // Check for increasing pause frequency (fatigue indicator)
        if alert == nil {
            let expectedPauses = max(1, Int(sessionDuration / (20 * 60)))  // ~1 per 20 min is normal
            if pauseCount > expectedPauses * 2 {
                alert = MidSessionFatigueAlert(
                    type: .fatigueDetected,
                    message: "Frequent interruptions suggest you may need a proper break.",
                    urgency: .medium,
                    sessionDuration: sessionDuration
                )
            }
        }

        // Check for touch variance spike (indicates mental fatigue)
        if alert == nil && baseline.avgTouchVariance > 0 {
            if touchVariance > baseline.avgTouchVariance * 2 {
                alert = MidSessionFatigueAlert(
                    type: .fatigueDetected,
                    message: "Your interaction pattern suggests mental fatigue.",
                    urgency: .low,
                    sessionDuration: sessionDuration
                )
            }
        }

        if let alert = alert {
            lastAlertTime = Date()
            lastAlert = alert
            print("😴 [Fatigue] Mid-session alert: \(alert.type.rawValue) - \(alert.message)")
        }

        return alert
    }

    // MARK: - Pre-Session Check

    /// Quick fatigue assessment before starting a session
    /// Returns a recommendation about whether to proceed
    func preSessionCheck(
        sessionHistory: [FocusSession],
        baseline: UserBehavioralBaseline
    ) -> PreSessionFatigueCheck {

        let todaysSessions = getTodaysSessions(from: sessionHistory)
        let totalHoursToday = todaysSessions.reduce(0.0) { $0 + $1.actualDuration } / 3600
        let sessionCount = todaysSessions.count
        let currentHour = Calendar.current.component(.hour, from: Date())

        // Check for obvious fatigue indicators
        if totalHoursToday >= maxDailyDeepWorkHours {
            return PreSessionFatigueCheck(
                canProceed: false,
                warning: "You've already done \(String(format: "%.1f", totalHoursToday)) hours of deep work today. Consider resting.",
                suggestedDuration: nil
            )
        }

        if sessionCount >= 6 {
            return PreSessionFatigueCheck(
                canProceed: false,
                warning: "You've completed \(sessionCount) sessions today. Your brain needs rest.",
                suggestedDuration: nil
            )
        }

        if currentHour >= 23 || (currentHour >= 0 && currentHour <= 5) {
            return PreSessionFatigueCheck(
                canProceed: true,
                warning: "Late night working can impact tomorrow's performance. Keep it short.",
                suggestedDuration: 25 * 60 // 25 min max
            )
        }

        // Calculate remaining capacity
        let remainingHours = maxDailyDeepWorkHours - totalHoursToday
        let suggestedMinutes = min(90, Int(remainingHours * 60))

        if remainingHours < 1 {
            return PreSessionFatigueCheck(
                canProceed: true,
                warning: "You're approaching your daily deep work limit. Keep this session under \(suggestedMinutes) minutes.",
                suggestedDuration: Double(suggestedMinutes) * 60
            )
        }

        return PreSessionFatigueCheck(
            canProceed: true,
            warning: nil,
            suggestedDuration: nil
        )
    }

    // MARK: - Helper Methods

    private func getTodaysSessions(from sessions: [FocusSession]) -> [FocusSession] {
        let today = Calendar.current.startOfDay(for: Date())
        return sessions.filter {
            Calendar.current.isDate($0.startTime, inSameDayAs: today)
        }
    }

    private func calculateCompletionTrend(from sessions: [FocusSession]) -> Double {
        let recent = Array(sessions.suffix(10))
        guard recent.count >= 5 else { return 0 }

        let firstHalf = Array(recent.prefix(recent.count / 2))
        let secondHalf = Array(recent.suffix(recent.count / 2))

        let firstRate = Double(firstHalf.filter { $0.wasCompleted }.count) / Double(firstHalf.count)
        let secondRate = Double(secondHalf.filter { $0.wasCompleted }.count) / Double(secondHalf.count)

        return secondRate - firstRate  // Negative = declining
    }

    // MARK: - Sleep History Management

    /// Add a sleep record
    func addSleepRecord(_ record: SleepRecord) {
        var history = loadSleepHistory()
        history.insert(record, at: 0)
        // Keep last 30 days
        if history.count > 30 {
            history = Array(history.prefix(30))
        }
        saveSleepHistory(history)
    }

    /// Load sleep history
    func loadSleepHistory() -> [SleepRecord] {
        guard let data = UserDefaults.standard.data(forKey: sleepHistoryKey),
              let history = try? JSONDecoder().decode([SleepRecord].self, from: data) else {
            return []
        }
        return history
    }

    private func saveSleepHistory(_ history: [SleepRecord]) {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: sleepHistoryKey)
        }
    }

    /// Estimate hours since wake based on current time and chronotype
    func estimateHoursSinceWake(chronotype: Chronotype) -> Double {
        let now = Date()
        let currentHour = Calendar.current.component(.hour, from: now)
        let currentMinute = Calendar.current.component(.minute, from: now)

        // Estimate wake time based on chronotype
        let estimatedWakeHour: Int
        switch chronotype {
        case .extremeMorning:
            estimatedWakeHour = 5
        case .moderateMorning:
            estimatedWakeHour = 6
        case .intermediate:
            estimatedWakeHour = 7
        case .moderateEvening:
            estimatedWakeHour = 8
        case .extremeEvening:
            estimatedWakeHour = 10
        }

        var hoursAwake = Double(currentHour - estimatedWakeHour) + Double(currentMinute) / 60

        // Handle overnight (past midnight)
        if hoursAwake < 0 {
            hoursAwake += 24
        }

        return max(0, hoursAwake)
    }

    /// Clear alert state (call when user dismisses alert)
    func clearAlertState() {
        lastAlert = nil
    }
}

// MARK: - Pre-Session Fatigue Check
/// Result of checking fatigue before starting a session.
struct PreSessionFatigueCheck {
    let canProceed: Bool
    let warning: String?
    let suggestedDuration: TimeInterval?

    var hasSuggestion: Bool {
        warning != nil || suggestedDuration != nil
    }
}

// MARK: - Fatigue Level Extensions
extension FatigueLevel {
    /// Summary for display in UI
    var summary: String {
        "\(level.icon) \(level.rawValue)"
    }

    /// Detailed breakdown for debug/analytics
    var debugDescription: String {
        """
        Fatigue Level: \(level.rawValue)
        Score: \(String(format: "%.2f", score))
        Signals: \(signals.map { $0.rawValue }.joined(separator: ", "))
        Recommendation: \(recommendation)
        """
    }
}
