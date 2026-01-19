import Foundation
import SwiftUI
import Combine

// MARK: - Behavioral Features Model
/// Captures behavioral signals for phone-only flow detection.
/// Research basis: Brizan et al. 2015 achieved 72.4% accuracy classifying
/// cognitive load from keystroke dynamics alone.
struct BehavioralFeatures: Codable {
    // === SESSION PATTERNS ===
    var sessionDuration: TimeInterval = 0
    var sessionCompletionRate: Double = 0        // completed / started (0-1)
    var pauseCount: Int = 0
    var pauseTotalDuration: TimeInterval = 0

    // === DISTRACTION METRICS ===
    var timeToFirstPause: TimeInterval?          // nil if no pause
    var avgTimeBetweenPauses: TimeInterval?
    var longestUninterruptedStretch: TimeInterval = 0
    var appSwitchCount: Int = 0                  // Background/foreground switches

    // === TOUCH DYNAMICS (during any in-app interaction) ===
    var touchCount: Int = 0
    var touchFrequency: Double = 0               // touches per minute
    var touchIntervalVariance: Double = 0        // consistency of touch timing
    var lastTouchTimestamp: Date?
    private var touchIntervals: [TimeInterval] = []

    // === TEMPORAL CONTEXT ===
    var hourOfDay: Int = 0
    var dayOfWeek: Int = 0                       // 1 = Sunday, 7 = Saturday
    var minutesSinceLastSession: Int?

    // === HISTORICAL COMPARISON ===
    var sessionCountToday: Int = 0
    var avgSessionDurationLast7Days: TimeInterval = 0
    var completionRateLast7Days: Double = 0
    var avgFlowScoreLast7Days: Double = 0        // Average flow score (0-100)
    var bestPerformanceHour: Int?                // hour with highest completion rates

    // === CONSISTENCY METRICS (for BehavioralFlowDetector) ===
    var sameTimeOfDayAsUsual: Bool = false       // Within 2 hours of usual time
    var consecutiveDays: Int = 0                 // Active streak

    // Target duration for completion rate calculation
    private var targetDuration: TimeInterval = 25 * 60 // Default 25 min

    // MARK: - Coding Keys (exclude computed/transient data)
    enum CodingKeys: String, CodingKey {
        case sessionDuration, sessionCompletionRate, pauseCount, pauseTotalDuration
        case timeToFirstPause, avgTimeBetweenPauses, longestUninterruptedStretch, appSwitchCount
        case touchCount, touchFrequency, touchIntervalVariance
        case hourOfDay, dayOfWeek, minutesSinceLastSession
        case sessionCountToday, avgSessionDurationLast7Days, completionRateLast7Days, avgFlowScoreLast7Days, bestPerformanceHour
        case sameTimeOfDayAsUsual, consecutiveDays
    }

    // MARK: - Touch Recording
    mutating func recordTouch() {
        let now = Date()
        touchCount += 1

        if let lastTouch = lastTouchTimestamp {
            let interval = now.timeIntervalSince(lastTouch)
            touchIntervals.append(interval)

            // Keep only last 100 intervals for memory efficiency
            if touchIntervals.count > 100 {
                touchIntervals.removeFirst()
            }

            // Calculate variance (consistency measure)
            // Lower variance = more consistent touch pattern = likely focused
            // Higher variance = erratic touching = likely distracted
            if touchIntervals.count >= 5 {
                let mean = touchIntervals.reduce(0, +) / Double(touchIntervals.count)
                let variance = touchIntervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(touchIntervals.count)
                touchIntervalVariance = sqrt(variance) // Standard deviation
            }
        }

        lastTouchTimestamp = now
    }

    // MARK: - Session Analysis
    mutating func finalizeSessionMetrics(totalDuration: TimeInterval, completed: Bool, targetDuration: TimeInterval) {
        sessionDuration = totalDuration
        self.targetDuration = targetDuration

        if completed {
            sessionCompletionRate = 1.0
        } else {
            sessionCompletionRate = min(totalDuration / max(targetDuration, 1), 1.0)
        }

        if totalDuration > 0 {
            touchFrequency = Double(touchCount) / (totalDuration / 60.0)
        }
    }

    // MARK: - Flow Indicators
    /// Returns a preliminary flow score (0-100) based on behavioral features alone.
    /// This is less accurate than biometric-based detection but provides
    /// useful signal for users without Apple Watch.
    var behavioralFlowScore: Int {
        var score: Double = 50 // Base score

        // Completion rate contribution (0-25 points)
        score += sessionCompletionRate * 25

        // Pause penalty (-15 to 0 points)
        // Gloria Mark research: 23+ min to recover from distraction
        let pausePenalty = min(Double(pauseCount) * 5, 15)
        score -= pausePenalty

        // Longest uninterrupted stretch bonus (0-15 points)
        // Longer stretches indicate deeper focus
        let stretchMinutes = longestUninterruptedStretch / 60
        let stretchBonus = min(stretchMinutes / 20 * 15, 15) // Max bonus at 20+ min
        score += stretchBonus

        // Touch consistency bonus (0-10 points)
        // Lower variance = more consistent = more focused
        if touchIntervalVariance > 0 && touchIntervalVariance < 5 {
            score += 10
        } else if touchIntervalVariance >= 5 && touchIntervalVariance < 10 {
            score += 5
        }
        // High variance (>10) = no bonus, likely distracted

        // Optimal time-of-day bonus (0-5 points)
        if let bestHour = bestPerformanceHour, hourOfDay == bestHour {
            score += 5
        }

        return max(0, min(100, Int(score)))
    }

    /// Confidence level for the behavioral flow score (0-1)
    var scoreConfidence: Double {
        var confidence: Double = 0.5 // Base confidence

        // More touches = more data = higher confidence
        if touchCount >= 50 {
            confidence += 0.2
        } else if touchCount >= 20 {
            confidence += 0.1
        }

        // Longer session = more reliable patterns
        if sessionDuration >= 25 * 60 {
            confidence += 0.2
        } else if sessionDuration >= 15 * 60 {
            confidence += 0.1
        }

        // Historical context improves confidence
        if avgSessionDurationLast7Days > 0 {
            confidence += 0.1
        }

        return min(confidence, 1.0)
    }
}

// MARK: - Screen Off Event
/// Tracks individual screen lock/unlock events during focus sessions
/// Research: Screen-off >30 seconds correlates with loss of flow state
struct ScreenOffEvent: Codable {
    let startTime: Date
    let duration: TimeInterval
    let isSignificant: Bool // >30 seconds

    var severity: Severity {
        switch duration {
        case 0..<10: return .minimal       // Quick check - no penalty
        case 10..<30: return .minor        // Brief distraction
        case 30..<120: return .moderate    // Significant break
        default: return .severe            // Long interruption (Gloria Mark: 23min recovery)
        }
    }

    enum Severity: String, Codable {
        case minimal, minor, moderate, severe

        var penaltyPoints: Double {
            switch self {
            case .minimal: return 0      // No penalty for <10s
            case .minor: return 2        // Small penalty for 10-30s
            case .moderate: return 10    // Moderate penalty for 30-120s
            case .severe: return 20      // Heavy penalty for >120s
            }
        }

        var displayName: String {
            switch self {
            case .minimal: return "Quick check"
            case .minor: return "Brief distraction"
            case .moderate: return "Significant break"
            case .severe: return "Long interruption"
            }
        }
    }
}

// MARK: - Screen Activity Summary
/// Summary of screen activity during a focus session
struct ScreenActivitySummary {
    let totalScreenOffEvents: Int
    let significantDistractions: Int
    let totalScreenOffTime: TimeInterval
    let averageScreenOffDuration: TimeInterval
    let flowPenalty: Double

    var distractionRate: String {
        switch significantDistractions {
        case 0: return "Excellent focus"
        case 1...2: return "Minor distractions"
        case 3...5: return "Moderate distractions"
        default: return "Highly distracted"
        }
    }

    /// Calculate screen-on percentage given session duration
    func screenOnPercentage(sessionDuration: TimeInterval) -> Double {
        guard sessionDuration > 0 else { return 100 }
        let screenOnTime = sessionDuration - totalScreenOffTime
        return max(0, min(100, (screenOnTime / sessionDuration) * 100))
    }
}

// MARK: - App Switch Event
/// Tracks individual app background/foreground switches during focus sessions
/// Research: Gloria Mark - 23 minutes to regain focus after context switch
struct AppSwitchEvent: Codable {
    let timestamp: Date
    let backgroundDuration: TimeInterval
    let switchNumber: Int // 1st switch, 2nd switch, etc.

    var severity: SwitchSeverity {
        switch backgroundDuration {
        case 0..<30: return .quickCheck      // <30s: quick reference
        case 30..<120: return .moderate      // 30s-2min: distraction
        default: return .severe              // >2min: context switch
        }
    }

    enum SwitchSeverity: String, Codable {
        case quickCheck, moderate, severe

        var penaltyPoints: Double {
            switch self {
            case .quickCheck: return 3      // Light penalty for quick checks
            case .moderate: return 8        // Moderate penalty
            case .severe: return 15         // Heavy penalty (Gloria Mark research)
            }
        }

        var description: String {
            switch self {
            case .quickCheck: return "Quick check"
            case .moderate: return "Brief distraction"
            case .severe: return "Context switch"
            }
        }

        var icon: String {
            switch self {
            case .quickCheck: return "eye"
            case .moderate: return "exclamationmark.circle"
            case .severe: return "arrow.triangle.2.circlepath"
            }
        }
    }
}

// MARK: - App Switch Analysis
/// Analysis of app switching patterns during a focus session
struct AppSwitchAnalysis {
    let totalSwitches: Int
    let quickChecks: Int      // <30s
    let distractions: Int     // 30s-2min
    let contextSwitches: Int  // >2min
    let averageTimeAway: TimeInterval
    let longestTimeAway: TimeInterval
    let flowPenalty: Double

    var switchPattern: SwitchPattern {
        if totalSwitches == 0 {
            return .focused
        } else if totalSwitches <= 2 && quickChecks == totalSwitches {
            return .minimal
        } else if distractions + contextSwitches <= 2 {
            return .moderate
        } else {
            return .severe
        }
    }

    enum SwitchPattern {
        case focused      // 0 switches
        case minimal      // 1-2 quick checks only
        case moderate     // Some distractions
        case severe       // Many or long switches

        var label: String {
            switch self {
            case .focused: return "Fully focused"
            case .minimal: return "Minimal distractions"
            case .moderate: return "Some distractions"
            case .severe: return "Highly distracted"
            }
        }

        var color: Color {
            switch self {
            case .focused: return OnLifeColors.sage
            case .minimal: return OnLifeColors.sage.opacity(0.7)
            case .moderate: return OnLifeColors.amber
            case .severe: return OnLifeColors.terracotta
            }
        }

        var icon: String {
            switch self {
            case .focused: return "checkmark.circle.fill"
            case .minimal: return "checkmark.circle"
            case .moderate: return "exclamationmark.circle"
            case .severe: return "xmark.circle"
            }
        }
    }
}

// MARK: - Behavioral Feature Collector
/// Collects behavioral signals during focus sessions for phone-only flow detection.
/// Designed for users without Apple Watch who still want flow state insights.
class BehavioralFeatureCollector: ObservableObject {
    static let shared = BehavioralFeatureCollector()

    @Published var currentFeatures = BehavioralFeatures()
    @Published var isCollecting = false

    // Screen activity tracking
    @Published var screenOffEvents: [ScreenOffEvent] = []
    @Published var totalScreenOffTime: TimeInterval = 0
    @Published var significantDistractions: Int = 0 // >30s screen-off events
    private var screenOffStartTime: Date?

    // App switch tracking
    @Published var appSwitchEvents: [AppSwitchEvent] = []
    private var backgroundEnteredTime: Date?
    private var switchCount: Int = 0

    private var sessionStartTime: Date?
    private var pauseStartTime: Date?
    private var pauseTimestamps: [(start: Date, end: Date?)] = []
    private var targetDuration: TimeInterval = 25 * 60

    private init() {}

    // MARK: - Session Lifecycle

    /// Start collecting behavioral features for a new session
    func startSession(targetDuration: TimeInterval) {
        sessionStartTime = Date()
        self.targetDuration = targetDuration
        currentFeatures = BehavioralFeatures()
        currentFeatures.hourOfDay = Calendar.current.component(.hour, from: Date())
        currentFeatures.dayOfWeek = Calendar.current.component(.weekday, from: Date())
        pauseTimestamps = []
        isCollecting = true

        // Reset all tracking for new session
        resetAllTracking()

        print("📊 [Behavioral] Session started - Hour: \(currentFeatures.hourOfDay), Day: \(currentFeatures.dayOfWeek)")
    }

    /// Record a pause event
    func pauseSession() {
        guard pauseStartTime == nil else { return }
        pauseStartTime = Date()
        currentFeatures.pauseCount += 1

        // Record time to first pause
        if currentFeatures.timeToFirstPause == nil, let start = sessionStartTime {
            currentFeatures.timeToFirstPause = Date().timeIntervalSince(start)
            print("📊 [Behavioral] First pause at \(Int(currentFeatures.timeToFirstPause! / 60))m")
        }

        pauseTimestamps.append((start: Date(), end: nil))
    }

    /// Record a resume event
    func resumeSession() {
        guard let pauseStart = pauseStartTime else { return }
        let pauseDuration = Date().timeIntervalSince(pauseStart)
        currentFeatures.pauseTotalDuration += pauseDuration
        pauseStartTime = nil

        // Update last pause timestamp
        if !pauseTimestamps.isEmpty {
            pauseTimestamps[pauseTimestamps.count - 1].end = Date()
        }

        print("📊 [Behavioral] Resumed after \(Int(pauseDuration))s pause")
    }

    /// Record app going to background (distraction indicator)
    func recordBackground() {
        guard isCollecting else { return }

        // Track app switch with timing
        backgroundEnteredTime = Date()
        switchCount += 1
        currentFeatures.appSwitchCount = switchCount

        // Also treat as a pause if not already paused
        if pauseStartTime == nil {
            pauseSession()
        }

        print("📱 [AppSwitch] App entered background (switch #\(switchCount))")
    }

    /// Record app returning to foreground
    func recordForeground() {
        guard isCollecting else { return }

        // Track app switch duration if we have a start time
        if let backgroundTime = backgroundEnteredTime {
            let duration = Date().timeIntervalSince(backgroundTime)

            let event = AppSwitchEvent(
                timestamp: backgroundTime,
                backgroundDuration: duration,
                switchNumber: switchCount
            )

            appSwitchEvents.append(event)

            print("📱 [AppSwitch] Returned after \(Int(duration))s - \(event.severity.description)")

            backgroundEnteredTime = nil
        }

        // Resume if we were paused due to backgrounding
        if pauseStartTime != nil {
            resumeSession()
        }
    }

    // MARK: - Screen Lock/Unlock Tracking

    /// Record screen going off (device locked)
    func recordScreenOff() {
        guard isCollecting else { return }
        screenOffStartTime = Date()
        print("📱 [ScreenTracking] Screen went off")
    }

    /// Record screen coming back on (device unlocked)
    func recordScreenOn() {
        guard isCollecting, let offStartTime = screenOffStartTime else { return }

        let duration = Date().timeIntervalSince(offStartTime)
        let isSignificant = duration >= 30.0

        let event = ScreenOffEvent(
            startTime: offStartTime,
            duration: duration,
            isSignificant: isSignificant
        )

        screenOffEvents.append(event)
        totalScreenOffTime += duration

        if isSignificant {
            significantDistractions += 1
        }

        print("📱 [ScreenTracking] Screen on after \(Int(duration))s - \(event.severity.displayName)")

        screenOffStartTime = nil
    }

    /// Get summary of screen activity for the current session
    func getScreenActivitySummary() -> ScreenActivitySummary {
        let totalEvents = screenOffEvents.count
        let significantEvents = screenOffEvents.filter { $0.isSignificant }.count
        let averageDuration = totalEvents > 0 ?
            screenOffEvents.reduce(0) { $0 + $1.duration } / Double(totalEvents) : 0

        return ScreenActivitySummary(
            totalScreenOffEvents: totalEvents,
            significantDistractions: significantEvents,
            totalScreenOffTime: totalScreenOffTime,
            averageScreenOffDuration: averageDuration,
            flowPenalty: calculateScreenOffPenalty()
        )
    }

    /// Calculate flow penalty from screen-off events
    private func calculateScreenOffPenalty() -> Double {
        // Calculate total penalty from screen-off events
        let totalPenalty = screenOffEvents.reduce(0.0) { total, event in
            total + event.severity.penaltyPoints
        }

        // Cap penalty at 40 points max
        return min(totalPenalty, 40.0)
    }

    /// Reset screen tracking for new session
    func resetScreenTracking() {
        screenOffEvents.removeAll()
        totalScreenOffTime = 0
        significantDistractions = 0
        screenOffStartTime = nil
        print("📱 [ScreenTracking] Reset for new session")
    }

    // MARK: - App Switch Analysis

    /// Get analysis of app switching patterns for the current session
    func getAppSwitchAnalysis() -> AppSwitchAnalysis {
        let quickChecks = appSwitchEvents.filter { $0.severity == .quickCheck }.count
        let distractions = appSwitchEvents.filter { $0.severity == .moderate }.count
        let contextSwitches = appSwitchEvents.filter { $0.severity == .severe }.count

        let averageTime = appSwitchEvents.isEmpty ? 0 :
            appSwitchEvents.reduce(0) { $0 + $1.backgroundDuration } / Double(appSwitchEvents.count)

        let longestTime = appSwitchEvents.max(by: { $0.backgroundDuration < $1.backgroundDuration })?.backgroundDuration ?? 0

        // Calculate penalty (capped at 45 points)
        let totalPenalty = appSwitchEvents.reduce(0.0) { total, event in
            total + event.severity.penaltyPoints
        }
        let cappedPenalty = min(totalPenalty, 45.0)

        return AppSwitchAnalysis(
            totalSwitches: appSwitchEvents.count,
            quickChecks: quickChecks,
            distractions: distractions,
            contextSwitches: contextSwitches,
            averageTimeAway: averageTime,
            longestTimeAway: longestTime,
            flowPenalty: cappedPenalty
        )
    }

    /// Reset app switch tracking for new session
    func resetAppSwitchTracking() {
        appSwitchEvents.removeAll()
        backgroundEnteredTime = nil
        switchCount = 0
        print("📱 [AppSwitch] Reset for new session")
    }

    /// Reset all tracking (screen + app switches) for new session
    func resetAllTracking() {
        resetScreenTracking()
        resetAppSwitchTracking()
    }

    /// End session and finalize metrics
    func endSession(completed: Bool) -> BehavioralFeatures {
        guard let start = sessionStartTime else { return currentFeatures }

        let totalDuration = Date().timeIntervalSince(start)
        currentFeatures.finalizeSessionMetrics(
            totalDuration: totalDuration,
            completed: completed,
            targetDuration: targetDuration
        )

        // Calculate longest uninterrupted stretch
        calculateLongestStretch(sessionStart: start, sessionEnd: Date())

        // Calculate avg time between pauses
        calculateAvgTimeBetweenPauses()

        isCollecting = false

        // Get summaries
        let screenSummary = getScreenActivitySummary()
        let appSwitchSummary = getAppSwitchAnalysis()

        print("📊 [Behavioral] Session ended - Score: \(currentFeatures.behavioralFlowScore), Confidence: \(String(format: "%.0f%%", currentFeatures.scoreConfidence * 100))")
        print("📊 [Behavioral] Touches: \(currentFeatures.touchCount), Pauses: \(currentFeatures.pauseCount), Longest stretch: \(Int(currentFeatures.longestUninterruptedStretch / 60))m")
        print("📱 [ScreenTracking] Summary - Events: \(screenSummary.totalScreenOffEvents), Significant: \(screenSummary.significantDistractions), Penalty: \(String(format: "%.1f", screenSummary.flowPenalty))")
        print("📱 [AppSwitch] Summary - Total: \(appSwitchSummary.totalSwitches), Quick: \(appSwitchSummary.quickChecks), Distractions: \(appSwitchSummary.distractions), Context: \(appSwitchSummary.contextSwitches), Penalty: \(String(format: "%.1f", appSwitchSummary.flowPenalty))")

        return currentFeatures
    }

    // MARK: - Touch Tracking

    /// Record a touch event during the session
    func recordTouch() {
        guard isCollecting else { return }
        currentFeatures.recordTouch()
    }

    // MARK: - Helper Calculations

    private func calculateLongestStretch(sessionStart: Date, sessionEnd: Date) {
        var stretches: [TimeInterval] = []
        var currentStart = sessionStart

        for pause in pauseTimestamps {
            let stretchDuration = pause.start.timeIntervalSince(currentStart)
            stretches.append(stretchDuration)
            if let end = pause.end {
                currentStart = end
            }
        }

        // Add final stretch from last pause end to session end
        let finalStretch = sessionEnd.timeIntervalSince(currentStart)
        stretches.append(finalStretch)

        currentFeatures.longestUninterruptedStretch = stretches.max() ?? 0
    }

    private func calculateAvgTimeBetweenPauses() {
        guard pauseTimestamps.count >= 2 else { return }

        var intervals: [TimeInterval] = []
        for i in 1..<pauseTimestamps.count {
            if let prevEnd = pauseTimestamps[i-1].end {
                let interval = pauseTimestamps[i].start.timeIntervalSince(prevEnd)
                intervals.append(interval)
            }
        }

        if !intervals.isEmpty {
            currentFeatures.avgTimeBetweenPauses = intervals.reduce(0, +) / Double(intervals.count)
        }
    }

    // MARK: - Historical Data Loading

    /// Load historical context from past sessions
    func loadHistoricalContext(from sessions: [FocusSession]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return }

        // Sessions today
        currentFeatures.sessionCountToday = sessions.filter {
            calendar.isDate($0.startTime, inSameDayAs: today)
        }.count

        // Last 7 days sessions
        let recentSessions = sessions.filter { $0.startTime >= sevenDaysAgo }

        if !recentSessions.isEmpty {
            let completedRecent = recentSessions.filter { $0.wasCompleted }

            currentFeatures.avgSessionDurationLast7Days = completedRecent.isEmpty ? 0 :
                completedRecent.map { $0.actualDuration }.reduce(0, +) / Double(completedRecent.count)

            currentFeatures.completionRateLast7Days = Double(completedRecent.count) / Double(recentSessions.count)

            // Calculate average flow score from biometrics or focus quality
            var flowScores: [Double] = []
            for session in completedRecent {
                if let biometrics = session.biometrics, biometrics.averageFlowScore > 0 {
                    flowScores.append(Double(biometrics.averageFlowScore))
                } else {
                    flowScores.append(session.focusQuality * 100)
                }
            }
            currentFeatures.avgFlowScoreLast7Days = flowScores.isEmpty ? 0 :
                flowScores.reduce(0, +) / Double(flowScores.count)
        }

        // Best performance hour
        currentFeatures.bestPerformanceHour = findBestPerformanceHour(from: sessions)

        // Minutes since last session
        if let lastSession = sessions.max(by: { $0.startTime < $1.startTime }) {
            currentFeatures.minutesSinceLastSession = Int(Date().timeIntervalSince(lastSession.endTime ?? lastSession.startTime) / 60)
        }

        // Calculate same time of day as usual
        let currentHour = calendar.component(.hour, from: Date())
        let usualHours = recentSessions.map { calendar.component(.hour, from: $0.startTime) }
        if !usualHours.isEmpty {
            let avgHour = usualHours.reduce(0, +) / usualHours.count
            currentFeatures.sameTimeOfDayAsUsual = abs(currentHour - avgHour) <= 2
        }

        // Calculate consecutive days streak
        currentFeatures.consecutiveDays = calculateConsecutiveDays(from: sessions)

        print("📊 [Behavioral] Historical context loaded - Sessions today: \(currentFeatures.sessionCountToday), Streak: \(currentFeatures.consecutiveDays), Best hour: \(currentFeatures.bestPerformanceHour ?? -1)")
    }

    // MARK: - Pre-Session Analysis

    /// Analyze behavioral features before starting a session (for flow readiness)
    /// Call this from HomeView to get current behavioral context without starting a session
    func analyzePreSession(sessions: [FocusSession]) {
        // Reset features and populate with historical data
        currentFeatures = BehavioralFeatures()
        currentFeatures.hourOfDay = Calendar.current.component(.hour, from: Date())
        currentFeatures.dayOfWeek = Calendar.current.component(.weekday, from: Date())

        // Load all historical context
        loadHistoricalContext(from: sessions)

        print("📊 [Behavioral] Pre-session analysis complete - Flow score: \(currentFeatures.avgFlowScoreLast7Days), Streak: \(currentFeatures.consecutiveDays)")
    }

    /// Calculate consecutive days with sessions (streak)
    private func calculateConsecutiveDays(from sessions: [FocusSession]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get unique days with sessions, sorted descending
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.startTime) }).sorted(by: >)

        guard !uniqueDays.isEmpty else { return 0 }

        var consecutive = 0
        var checkDate = today

        // Check if today has a session, otherwise start from yesterday
        if !uniqueDays.contains(today) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
                checkDate = yesterday
            }
        }

        for day in uniqueDays {
            if day == checkDate {
                consecutive += 1
                if let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) {
                    checkDate = previousDay
                }
            } else if day < checkDate {
                break
            }
        }

        return consecutive
    }

    private func findBestPerformanceHour(from sessions: [FocusSession]) -> Int? {
        var hourPerformance: [Int: (completed: Int, total: Int)] = [:]

        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            var stats = hourPerformance[hour] ?? (0, 0)
            stats.total += 1
            if session.wasCompleted { stats.completed += 1 }
            hourPerformance[hour] = stats
        }

        // Find hour with best completion rate (minimum 3 sessions for statistical significance)
        let qualified = hourPerformance.filter { $0.value.total >= 3 }
        let best = qualified.max {
            Double($0.value.completed) / Double($0.value.total) <
            Double($1.value.completed) / Double($1.value.total)
        }

        return best?.key
    }
}

// MARK: - View Extension for Touch Tracking
extension View {
    /// Adds behavioral touch tracking to a view.
    /// Use this on interactive elements within focus sessions.
    func trackTouches() -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    BehavioralFeatureCollector.shared.recordTouch()
                }
        )
    }
}
