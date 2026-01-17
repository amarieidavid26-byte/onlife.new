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
    var bestPerformanceHour: Int?                // hour with highest completion rates

    // Target duration for completion rate calculation
    private var targetDuration: TimeInterval = 25 * 60 // Default 25 min

    // MARK: - Coding Keys (exclude computed/transient data)
    enum CodingKeys: String, CodingKey {
        case sessionDuration, sessionCompletionRate, pauseCount, pauseTotalDuration
        case timeToFirstPause, avgTimeBetweenPauses, longestUninterruptedStretch
        case touchCount, touchFrequency, touchIntervalVariance
        case hourOfDay, dayOfWeek, minutesSinceLastSession
        case sessionCountToday, avgSessionDurationLast7Days, completionRateLast7Days, bestPerformanceHour
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

// MARK: - Behavioral Feature Collector
/// Collects behavioral signals during focus sessions for phone-only flow detection.
/// Designed for users without Apple Watch who still want flow state insights.
class BehavioralFeatureCollector: ObservableObject {
    static let shared = BehavioralFeatureCollector()

    @Published var currentFeatures = BehavioralFeatures()
    @Published var isCollecting = false

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

        print("📊 [Behavioral] Session ended - Score: \(currentFeatures.behavioralFlowScore), Confidence: \(String(format: "%.0f%%", currentFeatures.scoreConfidence * 100))")
        print("📊 [Behavioral] Touches: \(currentFeatures.touchCount), Pauses: \(currentFeatures.pauseCount), Longest stretch: \(Int(currentFeatures.longestUninterruptedStretch / 60))m")

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
        // Sessions today
        let today = Calendar.current.startOfDay(for: Date())
        currentFeatures.sessionCountToday = sessions.filter {
            Calendar.current.isDate($0.startTime, inSameDayAs: today)
        }.count

        // Last 7 days average
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recentSessions = sessions.filter { $0.startTime >= sevenDaysAgo }

        if !recentSessions.isEmpty {
            currentFeatures.avgSessionDurationLast7Days = recentSessions.map { $0.actualDuration }.reduce(0, +) / Double(recentSessions.count)

            let completedCount = recentSessions.filter { $0.wasCompleted }.count
            currentFeatures.completionRateLast7Days = Double(completedCount) / Double(recentSessions.count)
        }

        // Best performance hour
        currentFeatures.bestPerformanceHour = findBestPerformanceHour(from: sessions)

        // Minutes since last session
        if let lastSession = sessions.max(by: { $0.startTime < $1.startTime }) {
            currentFeatures.minutesSinceLastSession = Int(Date().timeIntervalSince(lastSession.endTime ?? lastSession.startTime) / 60)
        }

        print("📊 [Behavioral] Historical context loaded - Sessions today: \(currentFeatures.sessionCountToday), Best hour: \(currentFeatures.bestPerformanceHour ?? -1)")
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
