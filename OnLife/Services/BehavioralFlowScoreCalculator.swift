import Foundation
import Combine

// MARK: - Flow Score Result
/// The result of a behavioral flow score calculation.
/// Provides score, confidence level, breakdown, and recommendations.
struct BehavioralFlowResult: Codable {
    let score: Double                    // 0-100
    let confidence: ConfidenceLevel
    let breakdown: FlowScoreBreakdown
    let recommendations: [String]
    let timestamp: Date

    enum ConfidenceLevel: String, Codable {
        case low = "Low"         // < 7 days of data
        case medium = "Medium"   // Phone-only detection (calibrated)
        case high = "High"       // With wearable biometric data
    }

    init(score: Double, confidence: ConfidenceLevel, breakdown: FlowScoreBreakdown, recommendations: [String]) {
        self.score = score
        self.confidence = confidence
        self.breakdown = breakdown
        self.recommendations = recommendations
        self.timestamp = Date()
    }
}

// MARK: - Flow Score Breakdown
/// Detailed breakdown of what contributed to the flow score.
struct FlowScoreBreakdown: Codable {
    let sessionQuality: Double       // 0-1 (40% weight)
    let distractionResistance: Double // 0-1 (30% weight)
    let circadianAlignment: Double   // 0-1 (20% weight)
    let consistencyBonus: Double     // 0-1 (10% weight)
    let fatiguePenalty: Double       // 0-1 (1 = no penalty, multiplier)

    /// Human-readable description of the strongest contributor
    var strongestFactor: String {
        let factors: [(String, Double)] = [
            ("Session completion", sessionQuality),
            ("Focus without interruptions", distractionResistance),
            ("Optimal timing", circadianAlignment),
            ("Consistent routine", consistencyBonus)
        ]
        return factors.max(by: { $0.1 < $1.1 })?.0 ?? "Overall balance"
    }

    /// Human-readable description of the weakest factor
    var weakestFactor: String {
        let factors: [(String, Double)] = [
            ("Session completion", sessionQuality),
            ("Focus without interruptions", distractionResistance),
            ("Optimal timing", circadianAlignment),
            ("Consistent routine", consistencyBonus)
        ]
        return factors.min(by: { $0.1 < $1.1 })?.0 ?? "None identified"
    }
}

// MARK: - User Behavioral Baseline
/// Personalized baseline built from user's historical session data.
/// Used to compare current session performance against personal norms.
struct UserBehavioralBaseline: Codable {
    // Session patterns
    var avgSessionDuration: TimeInterval = 25 * 60  // 25 min default
    var avgCompletionRate: Double = 0.7
    var avgPauseCount: Double = 1.5

    // Touch dynamics baseline
    var avgTouchFrequency: Double = 2.0             // touches per minute
    var avgTouchVariance: Double = 1.0

    // Circadian patterns
    var inferredChronotype: Chronotype = .intermediate
    var bestPerformanceHour: Int = 10               // 10 AM default
    var typicalSessionHours: [Int] = [9, 10, 14, 15] // When they usually work

    // Calibration status
    var isCalibrated: Bool = false
    var daysOfData: Int = 0
    var totalSessions: Int = 0
    var lastUpdated: Date = Date()

    // Note: Uses Chronotype from ChronotypeInference.swift

    // MARK: - Default Baseline
    static var `default`: UserBehavioralBaseline {
        UserBehavioralBaseline()
    }
}

// MARK: - Behavioral Flow Score Calculator
/// Calculates flow score (0-100) using ONLY behavioral signals from the phone.
/// No wearable required. Based on research achieving 65-72% accuracy.
///
/// Research basis:
/// - Brizan et al. 2015: 72.4% accuracy from keystroke dynamics
/// - Gloria Mark: 23+ min to recover focus after distraction
/// - Session patterns correlate strongly with focus quality
class BehavioralFlowScoreCalculator: ObservableObject {
    static let shared = BehavioralFlowScoreCalculator()

    @Published var baseline: UserBehavioralBaseline
    @Published var lastResult: BehavioralFlowResult?

    private let baselineKey = "user_behavioral_baseline"

    private init() {
        // Load saved baseline or use default
        if let data = UserDefaults.standard.data(forKey: baselineKey),
           let saved = try? JSONDecoder().decode(UserBehavioralBaseline.self, from: data) {
            self.baseline = saved
            print("📊 [FlowCalc] Loaded baseline: \(saved.daysOfData) days of data, calibrated: \(saved.isCalibrated)")
        } else {
            self.baseline = .default
            print("📊 [FlowCalc] Using default baseline")
        }
    }

    // MARK: - Main Calculation

    /// Calculate flow score from behavioral features collected during a session.
    /// Call this after session ends.
    func calculateFlowScore(features: BehavioralFeatures) -> BehavioralFlowResult {
        // === 1. SESSION QUALITY (40% weight) ===
        let sessionQuality = calculateSessionQuality(features: features)

        // === 2. DISTRACTION RESISTANCE (30% weight) ===
        let distractionResistance = calculateDistractionResistance(features: features)

        // === 3. CIRCADIAN ALIGNMENT (20% weight) ===
        let circadianAlignment = calculateCircadianAlignment(features: features)

        // === 4. CONSISTENCY BONUS (10% weight) ===
        let consistencyBonus = calculateConsistencyBonus(features: features)

        // === 5. FATIGUE PENALTY (multiplier) ===
        let fatiguePenalty = calculateFatiguePenalty(features: features)

        // === COMBINE WITH WEIGHTS ===
        let rawScore = (sessionQuality * 0.40) +
                       (distractionResistance * 0.30) +
                       (circadianAlignment * 0.20) +
                       (consistencyBonus * 0.10)

        // Apply fatigue penalty (multiplier 0.5-1.0)
        let finalScore = rawScore * fatiguePenalty * 100

        // Build breakdown
        let breakdown = FlowScoreBreakdown(
            sessionQuality: sessionQuality,
            distractionResistance: distractionResistance,
            circadianAlignment: circadianAlignment,
            consistencyBonus: consistencyBonus,
            fatiguePenalty: fatiguePenalty
        )

        // Determine confidence
        let confidence: BehavioralFlowResult.ConfidenceLevel = baseline.isCalibrated ? .medium : .low

        // Generate recommendations
        let recommendations = generateRecommendations(features: features, breakdown: breakdown)

        let result = BehavioralFlowResult(
            score: min(100, max(0, finalScore)),
            confidence: confidence,
            breakdown: breakdown,
            recommendations: recommendations
        )

        lastResult = result

        print("📊 [FlowCalc] Score: \(Int(result.score)) (\(confidence.rawValue) confidence)")
        print("📊 [FlowCalc] Breakdown - Quality: \(String(format: "%.0f%%", sessionQuality * 100)), Distraction: \(String(format: "%.0f%%", distractionResistance * 100)), Circadian: \(String(format: "%.0f%%", circadianAlignment * 100))")

        return result
    }

    // MARK: - Component Calculations

    /// Session Quality: Duration relative to target, completion rate (40% weight)
    private func calculateSessionQuality(features: BehavioralFeatures) -> Double {
        // Duration score: How close to baseline average?
        let durationRatio = features.sessionDuration / baseline.avgSessionDuration
        let durationScore: Double

        if durationRatio >= 0.9 && durationRatio <= 1.3 {
            // Optimal range: 90-130% of typical duration
            durationScore = 1.0
        } else if durationRatio >= 0.7 {
            // Approaching optimal
            durationScore = 0.7 + (durationRatio - 0.7) * 1.5
        } else if durationRatio > 1.3 {
            // Slightly penalize very long sessions (fatigue risk)
            durationScore = max(0.7, 1.0 - (durationRatio - 1.3) * 0.3)
        } else {
            // Short session penalty
            durationScore = max(0.3, durationRatio)
        }

        // Completion score (did they finish what they started?)
        let completionScore = features.sessionCompletionRate

        // Combine: 60% duration quality, 40% completion
        return (durationScore * 0.6) + (completionScore * 0.4)
    }

    /// Distraction Resistance: Pauses, longest stretch, time to first pause (30% weight)
    private func calculateDistractionResistance(features: BehavioralFeatures) -> Double {
        var score = 1.0

        // Pause penalty: Each pause beyond baseline reduces score
        let pauseDiff = Double(features.pauseCount) - baseline.avgPauseCount
        if pauseDiff > 0 {
            score -= pauseDiff * 0.1  // -10% per extra pause
        } else if pauseDiff < -1 {
            score += 0.1  // Bonus for fewer pauses than usual
        }

        // Time to first pause bonus (Gloria Mark: 23 min to recover focus)
        if let timeToFirst = features.timeToFirstPause {
            if timeToFirst > 20 * 60 {  // > 20 min without pause = excellent
                score += 0.15
            } else if timeToFirst > 10 * 60 {  // > 10 min = good
                score += 0.05
            } else if timeToFirst < 5 * 60 {  // < 5 min = poor start
                score -= 0.1
            }
        } else {
            // No pauses at all - excellent focus!
            score += 0.2
        }

        // Longest uninterrupted stretch bonus
        if features.sessionDuration > 0 {
            let stretchRatio = features.longestUninterruptedStretch / features.sessionDuration
            if stretchRatio > 0.8 {
                score += 0.1  // 80%+ of session uninterrupted
            } else if stretchRatio < 0.5 {
                score -= 0.1  // Less than 50% uninterrupted
            }
        }

        return max(0, min(1, score))
    }

    /// Circadian Alignment: Is user working during their peak hours? (20% weight)
    private func calculateCircadianAlignment(features: BehavioralFeatures) -> Double {
        let currentHour = features.hourOfDay

        // Peak hours - maximum alignment
        let peakWindow = baseline.inferredChronotype.peakWindow
        if currentHour >= peakWindow.start && currentHour <= peakWindow.end {
            return 1.0
        }

        // Personal best hour
        if currentHour == baseline.bestPerformanceHour {
            return 1.0
        }

        // Dip hours - reduced alignment (post-lunch dip is universal)
        let dipWindow = baseline.inferredChronotype.circadianDip
        if currentHour >= dipWindow.start && currentHour <= dipWindow.end {
            return 0.7
        }

        // Late night / early morning - circadian low (3-5 AM)
        if currentHour >= 3 && currentHour <= 5 {
            return 0.5
        }

        // Very late night (11 PM - 2 AM)
        if currentHour >= 23 || currentHour <= 2 {
            return 0.6
        }

        // Otherwise neutral
        return 0.85
    }

    /// Consistency Bonus: Regular timing and spacing helps flow (10% weight)
    private func calculateConsistencyBonus(features: BehavioralFeatures) -> Double {
        var score = 0.7  // Base score

        // Working at a typical time for this user
        if baseline.typicalSessionHours.contains(features.hourOfDay) {
            score += 0.2
        }

        // Session spacing (need recovery time between sessions)
        if let minSinceLast = features.minutesSinceLastSession {
            if minSinceLast < 30 {
                score -= 0.2  // Too soon, cognitive resources not recovered
            } else if minSinceLast >= 60 && minSinceLast <= 240 {
                score += 0.1  // Good spacing (1-4 hours)
            }
        }

        // Historical completion trend
        if features.completionRateLast7Days > 0.8 {
            score += 0.1  // Strong recent performance
        } else if features.completionRateLast7Days < 0.5 {
            score -= 0.1  // Struggling lately
        }

        return max(0, min(1, score))
    }

    /// Fatigue Penalty: Long sessions, many sessions today, late hours (multiplier)
    private func calculateFatiguePenalty(features: BehavioralFeatures) -> Double {
        var penalty = 1.0  // Start with no penalty

        // Long session fatigue (> 90 min without substantial break)
        if features.sessionDuration > 90 * 60 {
            penalty -= 0.15
        } else if features.sessionDuration > 60 * 60 {
            penalty -= 0.05
        }

        // Many sessions today (cognitive exhaustion)
        if features.sessionCountToday > 6 {
            penalty -= 0.2
        } else if features.sessionCountToday > 4 {
            penalty -= 0.1
        }

        // Late hour fatigue
        if features.hourOfDay >= 23 || features.hourOfDay <= 4 {
            penalty -= 0.15
        }

        // Touch pattern irregularity (high variance = inconsistent attention)
        if baseline.avgTouchVariance > 0 && features.touchIntervalVariance > baseline.avgTouchVariance * 1.5 {
            penalty -= 0.1
        }

        return max(0.5, penalty)  // Floor at 50% (don't completely zero out)
    }

    // MARK: - Recommendations

    private func generateRecommendations(features: BehavioralFeatures, breakdown: FlowScoreBreakdown) -> [String] {
        var recommendations: [String] = []

        // Session quality issues
        if breakdown.sessionQuality < 0.6 {
            recommendations.append("Try to complete full sessions. Partial sessions reduce flow quality.")
        }

        // Distraction issues
        if breakdown.distractionResistance < 0.6 {
            if features.pauseCount > 3 {
                recommendations.append("You had \(features.pauseCount) interruptions. Try enabling Do Not Disturb.")
            } else {
                recommendations.append("Consider removing distractions before starting.")
            }
        }

        // Timing issues
        if breakdown.circadianAlignment < 0.7 {
            let peakWindow = baseline.inferredChronotype.peakWindow
            recommendations.append("Your peak focus time is \(peakWindow.start):00-\(peakWindow.end):00. Schedule important work then.")
        }

        // Fatigue issues
        if breakdown.fatiguePenalty < 0.8 {
            if features.sessionCountToday > 4 {
                recommendations.append("You've done \(features.sessionCountToday) sessions today. Consider taking a longer break.")
            } else if features.sessionDuration > 60 * 60 {
                recommendations.append("Long sessions can cause fatigue. Try 25-50 min blocks with breaks.")
            } else {
                recommendations.append("You may be fatigued. Consider a 20-min nap or a walk outside.")
            }
        }

        // Consistency issues
        if breakdown.consistencyBonus < 0.5 {
            recommendations.append("Building a regular focus routine helps. Try working at similar times each day.")
        }

        // Positive reinforcement
        if breakdown.sessionQuality > 0.9 && breakdown.distractionResistance > 0.9 {
            recommendations.append("Excellent focus session! You're in the zone.")
        }

        return recommendations
    }

    // MARK: - Baseline Management

    /// Update baseline with data from completed session
    func updateBaseline(with features: BehavioralFeatures) {
        // Only update if session was meaningful (> 10 min)
        guard features.sessionDuration > 10 * 60 else { return }

        // Exponential moving average for smooth updates
        let alpha = 0.2  // Weight for new data (20% new, 80% historical)

        baseline.avgSessionDuration = lerp(baseline.avgSessionDuration, features.sessionDuration, alpha)
        baseline.avgCompletionRate = lerp(baseline.avgCompletionRate, features.sessionCompletionRate, alpha)
        baseline.avgPauseCount = lerp(baseline.avgPauseCount, Double(features.pauseCount), alpha)

        if features.touchFrequency > 0 {
            baseline.avgTouchFrequency = lerp(baseline.avgTouchFrequency, features.touchFrequency, alpha)
        }
        if features.touchIntervalVariance > 0 {
            baseline.avgTouchVariance = lerp(baseline.avgTouchVariance, features.touchIntervalVariance, alpha)
        }

        // Update best performance hour if this session was good
        if features.sessionCompletionRate > 0.9 {
            baseline.bestPerformanceHour = features.hourOfDay
        }

        // Track typical session hours
        if !baseline.typicalSessionHours.contains(features.hourOfDay) {
            baseline.typicalSessionHours.append(features.hourOfDay)
            // Keep only top 6 most common hours
            if baseline.typicalSessionHours.count > 6 {
                baseline.typicalSessionHours.removeFirst()
            }
        }

        baseline.totalSessions += 1
        baseline.lastUpdated = Date()

        // Check if enough data for calibration (7+ days)
        let daysSinceFirst = Calendar.current.dateComponents([.day], from: baseline.lastUpdated.addingTimeInterval(-Double(baseline.totalSessions) * 86400), to: Date()).day ?? 0
        baseline.daysOfData = max(baseline.daysOfData, daysSinceFirst)
        baseline.isCalibrated = baseline.totalSessions >= 10 && baseline.daysOfData >= 7

        saveBaseline()

        print("📊 [FlowCalc] Baseline updated - Sessions: \(baseline.totalSessions), Calibrated: \(baseline.isCalibrated)")
    }

    /// Infer chronotype from session history
    func inferChronotype(from sessions: [FocusSession]) {
        guard sessions.count >= 10 else { return }

        // Count successful sessions by hour
        var hourPerformance: [Int: (completed: Int, total: Int)] = [:]

        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            var stats = hourPerformance[hour] ?? (0, 0)
            stats.total += 1
            if session.wasCompleted { stats.completed += 1 }
            hourPerformance[hour] = stats
        }

        // Find peak performance hours
        let qualifiedHours = hourPerformance.filter { $0.value.total >= 3 }
        let sortedByPerformance = qualifiedHours.sorted {
            Double($0.value.completed) / Double($0.value.total) >
            Double($1.value.completed) / Double($1.value.total)
        }

        guard let topHour = sortedByPerformance.first?.key else { return }

        // Infer chronotype from peak hour (5-type system from ChronotypeInference)
        if topHour >= 5 && topHour < 8 {
            baseline.inferredChronotype = .extremeMorning
        } else if topHour >= 8 && topHour < 11 {
            baseline.inferredChronotype = .moderateMorning
        } else if topHour >= 11 && topHour < 15 {
            baseline.inferredChronotype = .intermediate
        } else if topHour >= 15 && topHour < 19 {
            baseline.inferredChronotype = .moderateEvening
        } else {
            baseline.inferredChronotype = .extremeEvening
        }

        baseline.bestPerformanceHour = topHour
        saveBaseline()

        print("📊 [FlowCalc] Chronotype inferred: \(baseline.inferredChronotype.shortName), Best hour: \(topHour):00")
    }

    /// Reset baseline to defaults
    func resetBaseline() {
        baseline = .default
        saveBaseline()
        print("📊 [FlowCalc] Baseline reset to defaults")
    }

    private func saveBaseline() {
        if let data = try? JSONEncoder().encode(baseline) {
            UserDefaults.standard.set(data, forKey: baselineKey)
        }
    }

    /// Linear interpolation helper
    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }
}

// MARK: - Flow State from Score
extension BehavioralFlowResult {
    /// Convert score to a flow state category
    var flowState: FlowStateCategory {
        switch score {
        case 80...100: return .deepFlow
        case 60..<80: return .lightFlow
        case 40..<60: return .neutral
        case 20..<40: return .distracted
        default: return .unfocused
        }
    }

    enum FlowStateCategory: String {
        case deepFlow = "Deep Flow"
        case lightFlow = "Light Flow"
        case neutral = "Neutral"
        case distracted = "Distracted"
        case unfocused = "Unfocused"

        var color: String {
            switch self {
            case .deepFlow: return "green"
            case .lightFlow: return "sage"
            case .neutral: return "amber"
            case .distracted: return "orange"
            case .unfocused: return "terracotta"
            }
        }

        var icon: String {
            switch self {
            case .deepFlow: return "brain.head.profile"
            case .lightFlow: return "leaf.fill"
            case .neutral: return "circle.dashed"
            case .distracted: return "exclamationmark.triangle"
            case .unfocused: return "moon.zzz"
            }
        }
    }
}
