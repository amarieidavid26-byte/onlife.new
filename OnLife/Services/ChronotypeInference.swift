import Foundation

// MARK: - Chronotype Model
/// Represents the user's circadian preference (morningness-eveningness).
/// Research basis: Roenneberg et al. Munich Chronotype Questionnaire (MCTQ).
enum Chronotype: String, Codable, CaseIterable {
    case extremeMorning = "Extreme Morning"   // Wake 5-6 AM, Peak 7-10 AM
    case moderateMorning = "Morning"          // Wake 6-7 AM, Peak 9-11 AM
    case intermediate = "Intermediate"         // Wake 7-8 AM, Peak 11 AM-2 PM
    case moderateEvening = "Evening"          // Wake 8-9 AM, Peak 4-7 PM
    case extremeEvening = "Extreme Evening"   // Wake 10+ AM, Peak 7-10 PM

    var peakWindow: (start: Int, end: Int) {
        switch self {
        case .extremeMorning: return (7, 10)
        case .moderateMorning: return (9, 12)
        case .intermediate: return (11, 14)
        case .moderateEvening: return (16, 19)
        case .extremeEvening: return (19, 22)
        }
    }

    var circadianDip: (start: Int, end: Int) {
        // Post-lunch dip is universal, but timing varies by chronotype
        switch self {
        case .extremeMorning: return (13, 15)
        case .moderateMorning: return (14, 16)
        case .intermediate: return (13, 15)
        case .moderateEvening: return (12, 14)
        case .extremeEvening: return (11, 13)
        }
    }

    var secondWindWindow: (start: Int, end: Int)? {
        // Evening types get a "second wind" - temporary alertness boost
        switch self {
        case .moderateEvening: return (20, 22)
        case .extremeEvening: return (21, 23)
        default: return nil
        }
    }

    var description: String {
        switch self {
        case .extremeMorning:
            return "You're an early bird! Your brain is sharpest in the early morning."
        case .moderateMorning:
            return "You're a morning person. Your peak focus is mid-morning."
        case .intermediate:
            return "You have a balanced rhythm. Late morning to early afternoon is your sweet spot."
        case .moderateEvening:
            return "You're an evening person. Your focus peaks in the late afternoon."
        case .extremeEvening:
            return "You're a night owl! Evening hours are when you do your best work."
        }
    }

    /// Emoji representation for UI
    var icon: String {
        switch self {
        case .extremeMorning: return "🌅"
        case .moderateMorning: return "☀️"
        case .intermediate: return "🌤️"
        case .moderateEvening: return "🌆"
        case .extremeEvening: return "🌙"
        }
    }

    /// Short display name for compact UI
    var shortName: String {
        switch self {
        case .extremeMorning: return "Early Bird"
        case .moderateMorning: return "Morning"
        case .intermediate: return "Balanced"
        case .moderateEvening: return "Evening"
        case .extremeEvening: return "Night Owl"
        }
    }
}

// MARK: - Chronotype Inference Result
struct ChronotypeInferenceResult: Codable {
    let chronotype: Chronotype
    let confidence: ConfidenceLevel
    let peakPerformanceHour: Int
    let dataPoints: Int
    let recommendation: String

    enum ConfidenceLevel: String, Codable {
        case low = "Low"           // < 7 days of data
        case medium = "Medium"     // 7-14 days of data
        case high = "High"         // 14+ days with varied hours
    }
}

// MARK: - Time Recommendation
struct TimeRecommendation: Codable {
    let timeRange: String
    let quality: TimeQuality
    let reason: String

    enum TimeQuality: String, Codable {
        case optimal = "Optimal"
        case good = "Good"
        case suboptimal = "Suboptimal"
    }
}

// MARK: - Quick Assessment (Onboarding)
struct ChronotypeQuickAssessment: Codable {
    let preferredWakeTime: Int      // Hour (0-23)
    let preferredSleepTime: Int     // Hour (0-23)
    let selfPerceivedType: SelfPerception
    let bestFocusTime: FocusTimePref

    enum SelfPerception: String, Codable {
        case morning = "morning"
        case evening = "evening"
        case neither = "neither"
    }

    enum FocusTimePref: String, Codable {
        case morning = "morning"
        case afternoon = "afternoon"
        case evening = "evening"
        case night = "night"
    }
}

// MARK: - Chronotype Inference Engine
/// Infers user's chronotype from behavioral data or quick assessment.
/// Research basis: 7+ days of session data can classify chronotype with ~85% accuracy.
class ChronotypeInferenceEngine {
    static let shared = ChronotypeInferenceEngine()

    private let storageKey = "onlife_chronotype_result"

    private init() {}

    // MARK: - Stored Result

    /// Get the currently stored chronotype result
    var storedResult: ChronotypeInferenceResult? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let result = try? JSONDecoder().decode(ChronotypeInferenceResult.self, from: data) else {
            return nil
        }
        return result
    }

    /// Save a chronotype result
    func saveResult(_ result: ChronotypeInferenceResult) {
        if let data = try? JSONEncoder().encode(result) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - Quick Assessment (Onboarding)

    /// Quick assessment during onboarding (before we have data)
    /// Uses MSFsc (Mid-Sleep on Free Days) approximation
    func inferFromQuickAssessment(_ assessment: ChronotypeQuickAssessment) -> ChronotypeInferenceResult {
        // Calculate mid-sleep point (MSFsc approximation)
        var sleepHour = assessment.preferredSleepTime
        let wakeHour = assessment.preferredWakeTime

        // Handle overnight sleep (e.g., sleep at 23, wake at 7)
        if sleepHour > wakeHour {
            sleepHour -= 24
        }
        let midSleep = (sleepHour + wakeHour) / 2
        let normalizedMidSleep = midSleep < 0 ? midSleep + 24 : midSleep

        // MSFsc to chronotype mapping (research-based cutoffs)
        // < 3 AM = extreme morning
        // 3-4 AM = moderate morning
        // 4-5 AM = intermediate
        // 5-6 AM = moderate evening
        // > 6 AM = extreme evening
        let chronotype: Chronotype
        if normalizedMidSleep < 3 || normalizedMidSleep >= 22 {
            chronotype = .extremeMorning
        } else if normalizedMidSleep < 4 {
            chronotype = .moderateMorning
        } else if normalizedMidSleep < 5 {
            chronotype = .intermediate
        } else if normalizedMidSleep < 6 {
            chronotype = .moderateEvening
        } else {
            chronotype = .extremeEvening
        }

        // Adjust based on self-perception (secondary signal)
        let adjustedChronotype = adjustForSelfPerception(
            base: chronotype,
            perception: assessment.selfPerceivedType,
            focusPref: assessment.bestFocusTime
        )

        let result = ChronotypeInferenceResult(
            chronotype: adjustedChronotype,
            confidence: .low,
            peakPerformanceHour: adjustedChronotype.peakWindow.start + 1,
            dataPoints: 0,
            recommendation: "This is an initial estimate. We'll refine it as you use OnLife."
        )

        saveResult(result)
        print("🕐 [Chronotype] Quick assessment: \(adjustedChronotype.rawValue), mid-sleep: \(normalizedMidSleep)")

        return result
    }

    private func adjustForSelfPerception(
        base: Chronotype,
        perception: ChronotypeQuickAssessment.SelfPerception,
        focusPref: ChronotypeQuickAssessment.FocusTimePref
    ) -> Chronotype {
        // If self-perception strongly disagrees, shift one level
        switch (base, perception) {
        case (.extremeMorning, .evening), (.moderateMorning, .evening):
            return .intermediate
        case (.extremeEvening, .morning), (.moderateEvening, .morning):
            return .intermediate
        default:
            break
        }

        // Focus time preference can also shift
        switch (base, focusPref) {
        case (.intermediate, .morning):
            return .moderateMorning
        case (.intermediate, .evening), (.intermediate, .night):
            return .moderateEvening
        default:
            break
        }

        return base
    }

    // MARK: - Data-Driven Inference (After 7+ days)

    /// Infer chronotype from session history
    /// Research: 7+ days of data can classify with ~85% accuracy
    func inferFromSessionHistory(_ sessions: [FocusSession]) -> ChronotypeInferenceResult {
        guard sessions.count >= 7 else {
            let result = ChronotypeInferenceResult(
                chronotype: storedResult?.chronotype ?? .intermediate,
                confidence: .low,
                peakPerformanceHour: storedResult?.peakPerformanceHour ?? 10,
                dataPoints: sessions.count,
                recommendation: "Keep using OnLife for \(7 - sessions.count) more days for accurate chronotype detection."
            )
            return result
        }

        // Group sessions by hour and calculate performance
        var performanceByHour: [Int: HourPerformance] = [:]

        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            var perf = performanceByHour[hour] ?? HourPerformance()
            perf.sessionCount += 1
            perf.totalDuration += session.actualDuration
            if session.wasCompleted { perf.completedCount += 1 }
            if let score = session.biometrics?.averageFlowScore, score > 0 {
                perf.flowScores.append(Double(score))
            }
            performanceByHour[hour] = perf
        }

        // Find peak performance hour (requires 3+ sessions at that hour)
        let qualifiedHours = performanceByHour.filter { $0.value.sessionCount >= 3 }

        guard !qualifiedHours.isEmpty else {
            let result = ChronotypeInferenceResult(
                chronotype: storedResult?.chronotype ?? .intermediate,
                confidence: .low,
                peakPerformanceHour: storedResult?.peakPerformanceHour ?? 10,
                dataPoints: sessions.count,
                recommendation: "Try working at different times to help us find your peak focus hours."
            )
            return result
        }

        // Score each hour based on completion rate, flow scores, and duration
        let scoredHours = qualifiedHours.map { (hour, perf) -> (Int, Double) in
            let completionRate = Double(perf.completedCount) / Double(perf.sessionCount)
            let avgFlowScore = perf.flowScores.isEmpty ? 0.5 : perf.flowScores.reduce(0, +) / Double(perf.flowScores.count) / 100
            let avgDuration = perf.totalDuration / Double(perf.sessionCount)
            let durationScore = min(1.0, avgDuration / (45 * 60)) // Normalize to 45 min

            // Combined score: 40% completion, 40% flow, 20% duration
            let score = (completionRate * 0.4) + (avgFlowScore * 0.4) + (durationScore * 0.2)
            return (hour, score)
        }

        let peakHour = scoredHours.max(by: { $0.1 < $1.1 })?.0 ?? 10

        // Infer chronotype from peak hour
        let chronotype: Chronotype
        if peakHour >= 5 && peakHour < 8 {
            chronotype = .extremeMorning
        } else if peakHour >= 8 && peakHour < 11 {
            chronotype = .moderateMorning
        } else if peakHour >= 11 && peakHour < 15 {
            chronotype = .intermediate
        } else if peakHour >= 15 && peakHour < 19 {
            chronotype = .moderateEvening
        } else {
            chronotype = .extremeEvening
        }

        // Calculate confidence based on data quality
        let confidence: ChronotypeInferenceResult.ConfidenceLevel
        if sessions.count >= 30 && qualifiedHours.count >= 5 {
            confidence = .high
        } else if sessions.count >= 14 {
            confidence = .medium
        } else {
            confidence = .low
        }

        let result = ChronotypeInferenceResult(
            chronotype: chronotype,
            confidence: confidence,
            peakPerformanceHour: peakHour,
            dataPoints: sessions.count,
            recommendation: generateRecommendation(chronotype: chronotype, peakHour: peakHour)
        )

        saveResult(result)
        print("🕐 [Chronotype] Data-driven inference: \(chronotype.rawValue), peak hour: \(peakHour), confidence: \(confidence.rawValue)")

        return result
    }

    // MARK: - Helper Types

    private struct HourPerformance {
        var sessionCount: Int = 0
        var completedCount: Int = 0
        var totalDuration: TimeInterval = 0
        var flowScores: [Double] = []
    }

    // MARK: - Recommendations

    private func generateRecommendation(chronotype: Chronotype, peakHour: Int) -> String {
        let peak = chronotype.peakWindow
        let dip = chronotype.circadianDip

        var rec = "Schedule your most important work between \(formatHour(peak.start)) and \(formatHour(peak.end)). "
        rec += "Avoid deep work between \(formatHour(dip.start)) and \(formatHour(dip.end)) if possible."

        if let secondWind = chronotype.secondWindWindow {
            rec += " You may get a 'second wind' around \(formatHour(secondWind.start))-\(formatHour(secondWind.end))."
        }

        return rec
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour == 12 { return "12 PM" }
        if hour < 12 { return "\(hour) AM" }
        return "\(hour - 12) PM"
    }
}

// MARK: - Circadian Optimization
extension ChronotypeInferenceEngine {

    /// Get optimal times for a focus session
    func getOptimalSessionTimes(chronotype: Chronotype, date: Date = Date()) -> [TimeRecommendation] {
        var recommendations: [TimeRecommendation] = []

        let peak = chronotype.peakWindow
        let dip = chronotype.circadianDip

        // Primary recommendation: Peak window
        recommendations.append(TimeRecommendation(
            timeRange: "\(formatHour(peak.start)) - \(formatHour(peak.end))",
            quality: .optimal,
            reason: "Your peak cognitive window"
        ))

        // Secondary: Second wind if applicable
        if let secondWind = chronotype.secondWindWindow {
            recommendations.append(TimeRecommendation(
                timeRange: "\(formatHour(secondWind.start)) - \(formatHour(secondWind.end))",
                quality: .good,
                reason: "Your evening 'second wind'"
            ))
        }

        // Warning: Circadian dip
        recommendations.append(TimeRecommendation(
            timeRange: "\(formatHour(dip.start)) - \(formatHour(dip.end))",
            quality: .suboptimal,
            reason: "Post-lunch circadian dip - consider lighter tasks or a nap"
        ))

        return recommendations
    }

    /// Get circadian multiplier for current time
    /// Returns 0.75 - 1.1 multiplier for flow score adjustments
    func getCircadianMultiplier(chronotype: Chronotype, hour: Int) -> Double {
        let peak = chronotype.peakWindow
        let dip = chronotype.circadianDip

        // Peak hours: +10% bonus
        if hour >= peak.start && hour <= peak.end {
            return 1.1
        }

        // Dip hours: -15% penalty
        if hour >= dip.start && hour <= dip.end {
            return 0.85
        }

        // Second wind: +5% bonus
        if let secondWind = chronotype.secondWindWindow {
            if hour >= secondWind.start && hour <= secondWind.end {
                return 1.05
            }
        }

        // Biological night (3-5 AM): -25% penalty
        if hour >= 3 && hour <= 5 {
            return 0.75
        }

        // Late night (11 PM - 2 AM): -10% penalty
        if hour >= 23 || hour <= 2 {
            return 0.9
        }

        // Otherwise neutral
        return 1.0
    }

    /// Check if current time is optimal for focus
    func isOptimalTime(chronotype: Chronotype, date: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        let peak = chronotype.peakWindow
        return hour >= peak.start && hour <= peak.end
    }

    /// Get next optimal focus window
    func getNextOptimalWindow(chronotype: Chronotype, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        let peak = chronotype.peakWindow

        // If currently in peak window, return now
        if currentHour >= peak.start && currentHour <= peak.end {
            return date
        }

        // Calculate hours until peak starts
        var hoursUntilPeak = peak.start - currentHour
        if hoursUntilPeak <= 0 {
            hoursUntilPeak += 24 // Next day
        }

        return calendar.date(byAdding: .hour, value: hoursUntilPeak, to: date)
    }
}

// MARK: - Chronotype Compatibility
extension Chronotype {
    /// Convert to the simpler 3-category system used in some parts of the app
    var simplified: SimplifiedChronotype {
        switch self {
        case .extremeMorning, .moderateMorning:
            return .morning
        case .intermediate:
            return .intermediate
        case .moderateEvening, .extremeEvening:
            return .evening
        }
    }

    enum SimplifiedChronotype: String, Codable {
        case morning = "Morning"
        case intermediate = "Intermediate"
        case evening = "Evening"
    }
}
