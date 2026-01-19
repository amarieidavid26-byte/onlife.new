import Foundation

/// Analyzes user's session completion patterns to predict success probability
/// and recommend optimal session lengths.
///
/// Research basis:
/// - Users have individual optimal session lengths (15-90 minutes)
/// - Completion rate is the best predictor of future success (self-consistency)
/// - Time of day, recent history, and session length interact to predict completion
/// - Minimum 30 sessions needed for reliable predictions
class CompletionPatternAnalyzer {
    static let shared = CompletionPatternAnalyzer()

    private init() {}

    // MARK: - Pattern Analysis

    /// Analyze completion patterns from session history
    /// Returns nil if fewer than 30 sessions (insufficient data for reliable analysis)
    func analyzeCompletionPatterns(sessions: [FocusSession]) -> CompletionPattern? {
        // Need at least 30 sessions for meaningful analysis
        guard sessions.count >= 30 else { return nil }

        let completedSessions = sessions.filter { $0.wasCompleted }
        let overallCompletionRate = Double(completedSessions.count) / Double(sessions.count)

        // Analyze by duration bracket
        var durationStats: [CompletionPattern.DurationBracket: (completed: Int, total: Int)] = [:]

        for session in sessions {
            let bracket = CompletionPattern.DurationBracket.bracket(for: session.plannedDuration)

            if durationStats[bracket] == nil {
                durationStats[bracket] = (0, 0)
            }

            durationStats[bracket]!.total += 1
            if session.wasCompleted {
                durationStats[bracket]!.completed += 1
            }
        }

        let completionByDuration = durationStats.mapValues { stats in
            stats.total > 0 ? Double(stats.completed) / Double(stats.total) : 0.0
        }

        // Find optimal duration (highest completion rate with at least 5 sessions)
        let optimalBracket = completionByDuration
            .filter { durationStats[$0.key]?.total ?? 0 >= 5 }
            .max { $0.value < $1.value }?.key ?? .medium

        let optimalDuration = optimalDurationFor(bracket: optimalBracket)

        // Analyze by hour of day
        var hourStats: [Int: (completed: Int, total: Int)] = [:]

        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)

            if hourStats[hour] == nil {
                hourStats[hour] = (0, 0)
            }

            hourStats[hour]!.total += 1
            if session.wasCompleted {
                hourStats[hour]!.completed += 1
            }
        }

        let completionByHour = hourStats.mapValues { stats in
            stats.total > 0 ? Double(stats.completed) / Double(stats.total) : 0.0
        }

        // Find optimal hour (highest completion rate with at least 3 sessions)
        let optimalHour = completionByHour
            .filter { hourStats[$0.key]?.total ?? 0 >= 3 }
            .max { $0.value < $1.value }?.key ?? 9

        // Calculate confidence based on sample size (100 sessions = full confidence)
        let confidence = min(Double(sessions.count) / 100.0, 1.0)

        return CompletionPattern(
            optimalDuration: optimalDuration,
            optimalHourOfDay: optimalHour,
            completionRateByDuration: completionByDuration,
            completionRateByHour: completionByHour,
            totalSessions: sessions.count,
            overallCompletionRate: overallCompletionRate,
            confidence: confidence
        )
    }

    private func optimalDurationFor(bracket: CompletionPattern.DurationBracket) -> TimeInterval {
        switch bracket {
        case .short: return 25 * 60      // 25 minutes (Pomodoro)
        case .medium: return 35 * 60     // 35 minutes
        case .long: return 50 * 60       // 50 minutes
        case .extended: return 75 * 60   // 75 minutes
        }
    }

    // MARK: - Prediction

    /// Predict completion probability for a given duration and time
    func predictCompletionProbability(
        duration: TimeInterval,
        hourOfDay: Int,
        pattern: CompletionPattern
    ) -> (probability: Double, confidence: String) {
        // Start with overall baseline
        var probability = pattern.overallCompletionRate

        // Adjust for duration (40% weight)
        let bracket = CompletionPattern.DurationBracket.bracket(for: duration)
        if let durationRate = pattern.completionRateByDuration[bracket] {
            probability = (probability * 0.6) + (durationRate * 0.4)
        }

        // Adjust for time of day (30% weight)
        if let hourRate = pattern.completionRateByHour[hourOfDay] {
            probability = (probability * 0.7) + (hourRate * 0.3)
        }

        // Determine confidence level
        let confidenceLabel: String
        if pattern.confidence >= 0.8 {
            confidenceLabel = "High"
        } else if pattern.confidence >= 0.5 {
            confidenceLabel = "Medium"
        } else {
            confidenceLabel = "Low"
        }

        return (probability, confidenceLabel)
    }

    // MARK: - Recommendations

    /// Generate a personalized recommendation based on requested duration
    func generateRecommendation(
        requestedDuration: TimeInterval,
        pattern: CompletionPattern
    ) -> String {
        let requestedMinutes = Int(requestedDuration / 60)
        let optimalMinutes = Int(pattern.optimalDuration / 60)

        let (probability, _) = predictCompletionProbability(
            duration: requestedDuration,
            hourOfDay: Calendar.current.component(.hour, from: Date()),
            pattern: pattern
        )

        if abs(requestedMinutes - optimalMinutes) <= 5 {
            return "Perfect! \(requestedMinutes)min is in your sweet spot. You have a \(Int(probability * 100))% completion rate at this length."
        } else if requestedMinutes > optimalMinutes + 10 {
            return "You typically complete \(optimalMinutes)min sessions better. Consider starting shorter and extending if you're in flow."
        } else if requestedMinutes < optimalMinutes - 10 {
            return "You usually work best in \(optimalMinutes)min sessions. This \(requestedMinutes)min session might feel rushed."
        } else {
            return "\(requestedMinutes)min session - you have a \(Int(probability * 100))% completion rate at this length."
        }
    }

    // MARK: - Early Quit Analysis

    /// Identify patterns in when users typically abandon sessions
    func identifyEarlyQuitPattern(sessions: [FocusSession]) -> EarlyQuitAnalysis? {
        // Find abandoned sessions that lasted at least 1 minute
        let abandoned = sessions.filter { !$0.wasCompleted && $0.actualDuration > 60 }

        guard abandoned.count >= 5 else { return nil }

        // Find average quit time
        let averageQuitTime = abandoned.reduce(0.0) { $0 + $1.actualDuration } / Double(abandoned.count)

        // Check if there's a consistent pattern (quit times cluster within 5 minutes)
        let quitTimes = abandoned.map { $0.actualDuration }
        let variance = calculateVariance(quitTimes)
        let stdDev = sqrt(variance)

        let hasPattern = stdDev < 300 // Within 5 minutes standard deviation

        if hasPattern {
            return EarlyQuitAnalysis(
                averageQuitTime: averageQuitTime,
                quitCount: abandoned.count,
                hasConsistentPattern: true,
                recommendation: "You often quit around \(Int(averageQuitTime / 60)) minutes. Try sessions slightly shorter than this to build completion momentum."
            )
        } else {
            return EarlyQuitAnalysis(
                averageQuitTime: averageQuitTime,
                quitCount: abandoned.count,
                hasConsistentPattern: false,
                recommendation: "Your quit times vary. Focus on completing any length consistently to build the habit."
            )
        }
    }

    private func calculateVariance(_ values: [TimeInterval]) -> Double {
        guard !values.isEmpty else { return 0 }

        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count)
    }

    // MARK: - Weekly Patterns

    /// Analyze completion patterns by day of week
    func analyzeWeeklyPatterns(sessions: [FocusSession]) -> [Int: Double]? {
        guard sessions.count >= 30 else { return nil }

        var dayStats: [Int: (completed: Int, total: Int)] = [:]

        for session in sessions {
            let dayOfWeek = Calendar.current.component(.weekday, from: session.startTime)

            if dayStats[dayOfWeek] == nil {
                dayStats[dayOfWeek] = (0, 0)
            }

            dayStats[dayOfWeek]!.total += 1
            if session.wasCompleted {
                dayStats[dayOfWeek]!.completed += 1
            }
        }

        return dayStats.mapValues { stats in
            stats.total > 0 ? Double(stats.completed) / Double(stats.total) : 0.0
        }
    }
}

// MARK: - Data Types

struct CompletionPattern: Codable {
    let optimalDuration: TimeInterval
    let optimalHourOfDay: Int
    let completionRateByDuration: [DurationBracket: Double]
    let completionRateByHour: [Int: Double]
    let totalSessions: Int
    let overallCompletionRate: Double
    let confidence: Double // 0-1, based on sample size

    enum DurationBracket: String, Codable, CaseIterable, Hashable {
        case short = "15-30 min"
        case medium = "30-45 min"
        case long = "45-60 min"
        case extended = "60+ min"

        func contains(_ duration: TimeInterval) -> Bool {
            let minutes = duration / 60
            switch self {
            case .short: return minutes >= 15 && minutes < 30
            case .medium: return minutes >= 30 && minutes < 45
            case .long: return minutes >= 45 && minutes < 60
            case .extended: return minutes >= 60
            }
        }

        static func bracket(for duration: TimeInterval) -> DurationBracket {
            let minutes = duration / 60
            if minutes < 30 { return .short }
            else if minutes < 45 { return .medium }
            else if minutes < 60 { return .long }
            else { return .extended }
        }

        var displayName: String {
            return rawValue
        }

        var shortName: String {
            switch self {
            case .short: return "Short"
            case .medium: return "Medium"
            case .long: return "Long"
            case .extended: return "Extended"
            }
        }
    }

    var optimalDurationFormatted: String {
        let minutes = Int(optimalDuration / 60)
        return "\(minutes) minutes"
    }

    var confidenceLevel: String {
        if confidence >= 0.8 { return "High" }
        else if confidence >= 0.5 { return "Medium" }
        else { return "Low" }
    }
}

struct EarlyQuitAnalysis {
    let averageQuitTime: TimeInterval
    let quitCount: Int
    let hasConsistentPattern: Bool
    let recommendation: String

    var averageQuitTimeFormatted: String {
        let minutes = Int(averageQuitTime / 60)
        return "\(minutes) min"
    }
}
