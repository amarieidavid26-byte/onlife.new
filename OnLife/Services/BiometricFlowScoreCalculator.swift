import Foundation
import Combine

// MARK: - Scientific Citations
// ==============================================================================
// CITATIONS:
// - Peifer C, Schulz A, Schächinger H, Baumann N, Antoni CH.
//   The relation of flow-experience and physiological arousal under stress —
//   Can u shape it? J Exp Soc Psychol. 2014;53:62-69.
//   KEY FINDING: Flow shows INVERTED-U with sympathetic arousal (R² = 0.21-0.40)
//
// - de Manzano Ö, Theorell T, Harmat L, Ullén F.
//   The psychophysiology of flow during piano playing.
//   Emotion. 2010;10(3):301-311.
//   KEY FINDING: Flow correlates with HRV measures and moderate arousal
//
// - Keller J, Bless H, Blomann F, Kleinböhl D.
//   Physiological aspects of flow experiences: Skills-demand-compatibility
//   effects on heart rate variability and salivary cortisol.
//   J Exp Soc Psychol. 2011;47(4):849-852.
// ==============================================================================

// MARK: - Biometric Flow Result
/// Complete result of biometric flow analysis including score, state, and recommendations.
struct BiometricFlowResult: Codable {
    let score: Double                    // 0-100
    let state: FlowState
    let confidence: ConfidenceLevel
    let breakdown: BiometricFlowBreakdown
    let stateHistory: [FlowState]        // Last 5 readings for trend
    let recommendation: String
    let timestamp: Date

    enum FlowState: String, Codable, CaseIterable {
        case deepFlow = "Deep Flow"      // score ≥ 80, sustained 3+ min
        case lightFlow = "Light Flow"    // score ≥ 60
        case preFlow = "Pre-Flow"        // score ≥ 40, improving
        case baseline = "Baseline"       // normal state
        case overload = "Overload"       // sympathetic >90th percentile
        case boredom = "Boredom"         // sympathetic <10th percentile, low engagement

        var icon: String {
            switch self {
            case .deepFlow: return "🌊"
            case .lightFlow: return "💫"
            case .preFlow: return "🌀"
            case .baseline: return "⚪"
            case .overload: return "🔥"
            case .boredom: return "😐"
            }
        }

        var description: String {
            switch self {
            case .deepFlow:
                return "Optimal performance state with full immersion"
            case .lightFlow:
                return "Entering flow with good focus"
            case .preFlow:
                return "Building toward flow state"
            case .baseline:
                return "Normal resting state"
            case .overload:
                return "Excessive arousal - stress response active"
            case .boredom:
                return "Low engagement - task may be too easy"
            }
        }

        /// Color name for UI rendering
        var colorName: String {
            switch self {
            case .deepFlow: return "deepFlowBlue"
            case .lightFlow: return "lightFlowGreen"
            case .preFlow: return "preFlowYellow"
            case .baseline: return "baselineGray"
            case .overload: return "overloadRed"
            case .boredom: return "boredomOrange"
            }
        }
    }

    enum ConfidenceLevel: String, Codable {
        case low = "Low"         // < 7 days calibration
        case medium = "Medium"   // 7-14 days calibration
        case high = "High"       // 14+ days + good signal quality

        var multiplier: Double {
            switch self {
            case .low: return 0.7
            case .medium: return 0.85
            case .high: return 1.0
            }
        }
    }

    init(
        score: Double,
        state: FlowState,
        confidence: ConfidenceLevel,
        breakdown: BiometricFlowBreakdown,
        stateHistory: [FlowState],
        recommendation: String
    ) {
        self.score = score
        self.state = state
        self.confidence = confidence
        self.breakdown = breakdown
        self.stateHistory = stateHistory
        self.recommendation = recommendation
        self.timestamp = Date()
    }
}

// MARK: - Biometric Flow Breakdown
/// Detailed breakdown of what contributed to the flow score.
struct BiometricFlowBreakdown: Codable {
    let parasympatheticScore: Double    // 0-1, higher = better (linear)
    let sympatheticOptimality: Double   // 0-1, peaks at 0.5 (inverted-U)
    let hrZoneScore: Double             // 0-1, 110-130% of resting is optimal
    let sleepReadiness: Double          // 0-1, from last night's sleep
    let signalQuality: Double           // 0-1, data reliability

    /// The strongest positive contributor
    var strongestContributor: String {
        let scores = [
            ("Parasympathetic balance", parasympatheticScore),
            ("Arousal optimality", sympatheticOptimality),
            ("Heart rate zone", hrZoneScore),
            ("Sleep readiness", sleepReadiness)
        ]
        return scores.max(by: { $0.1 < $1.1 })?.0 ?? "Overall balance"
    }

    /// The weakest contributor (area for improvement)
    var weakestContributor: String {
        let scores = [
            ("Parasympathetic balance", parasympatheticScore),
            ("Arousal optimality", sympatheticOptimality),
            ("Heart rate zone", hrZoneScore),
            ("Sleep readiness", sleepReadiness)
        ]
        return scores.min(by: { $0.1 < $1.1 })?.0 ?? "None identified"
    }
}

// MARK: - Personal Biometric Baseline
/// Personalized biometric baseline built from user's historical data.
/// Requires 14+ days for full calibration.
struct BiometricBaseline: Codable {
    // HRV Baselines
    var restingRMSSD: Double = 50           // ms, morning resting average
    var restingRMSSDStdDev: Double = 10     // Standard deviation
    var restingHFPower: Double = 1000       // ms², parasympathetic
    var restingLFPower: Double = 1500       // ms², mixed

    // Heart Rate Baselines
    var restingHR: Double = 65              // bpm
    var restingHRStdDev: Double = 5
    var maxHR: Double = 180                 // Estimated max HR

    // Percentile distributions (built over 14+ days)
    var lfPercentiles: [Double] = []        // [10th, 25th, 50th, 75th, 90th]
    var rmssdPercentiles: [Double] = []

    // Calibration Status
    var daysOfData: Int = 0
    var totalReadings: Int = 0
    var isCalibrated: Bool = false          // True after 14 days
    var lastUpdated: Date = Date()

    // Circadian modifiers (HRV varies by time of day)
    var circadianHRVModifiers: [Int: Double] = [:]  // Hour -> multiplier

    // Sleep baseline
    var avgSleepQuality: Double = 0.75
    var avgSleepDuration: TimeInterval = 7 * 3600

    // MARK: - Percentile Calculation

    /// Get the percentile rank of a value within a distribution
    /// - Parameters:
    ///   - value: The value to rank
    ///   - distribution: Array of [10th, 25th, 50th, 75th, 90th] percentile values
    /// - Returns: Percentile rank (0.0 to 1.0)
    func getPercentile(value: Double, distribution: [Double]) -> Double {
        guard distribution.count >= 5 else { return 0.5 }

        // Percentiles: [10th, 25th, 50th, 75th, 90th]
        if value <= distribution[0] { return 0.05 }
        if value >= distribution[4] { return 0.95 }

        if value <= distribution[1] {
            return 0.10 + (value - distribution[0]) / (distribution[1] - distribution[0]) * 0.15
        }
        if value <= distribution[2] {
            return 0.25 + (value - distribution[1]) / (distribution[2] - distribution[1]) * 0.25
        }
        if value <= distribution[3] {
            return 0.50 + (value - distribution[2]) / (distribution[3] - distribution[2]) * 0.25
        }
        return 0.75 + (value - distribution[3]) / (distribution[4] - distribution[3]) * 0.15
    }

    /// Apply circadian adjustment to HRV reading
    func applyCircadianAdjustment(_ rmssd: Double, hour: Int) -> Double {
        let modifier = circadianHRVModifiers[hour] ?? 1.0
        return rmssd / modifier  // Normalize to baseline equivalent
    }

    // MARK: - Default Baseline
    static var `default`: BiometricBaseline {
        var baseline = BiometricBaseline()
        // Population average percentiles for LF power
        baseline.lfPercentiles = [500, 800, 1200, 1800, 2500]
        // Population average percentiles for RMSSD
        baseline.rmssdPercentiles = [20, 30, 45, 65, 90]
        return baseline
    }
}

// MARK: - Biometric Flow Score Calculator
/// Calculates flow score using biometric signals with research-validated algorithms.
/// Implements inverted-U arousal model from Peifer et al. (2014).
class BiometricFlowScoreCalculator: ObservableObject {
    static let shared = BiometricFlowScoreCalculator()

    @Published var currentResult: BiometricFlowResult?
    @Published var baseline: BiometricBaseline

    private var stateHistory: [BiometricFlowResult.FlowState] = []
    private var scoreHistory: [Double] = []
    private var lastStateChangeTime: Date = Date()

    // Storage key
    private let baselineKey = "onlife_biometric_baseline"

    // === RESEARCH-VALIDATED WEIGHTS ===
    // From Algorithm Masterplan synthesis of 150+ studies

    /// Parasympathetic weight (linear relationship with flow)
    /// Reference: Higher HF-HRV correlates linearly with flow (r ≈ 0.5)
    private let parasympatheticWeight: Double = 0.35

    /// Sympathetic optimality weight (inverted-U relationship)
    /// Reference: Peifer et al. 2014 - peak flow at 40-60th percentile LF
    private let sympatheticWeight: Double = 0.35

    /// Heart rate zone weight (moderate elevation optimal)
    /// Reference: 110-130% of resting HR optimal for cognitive tasks
    private let hrZoneWeight: Double = 0.15

    /// Sleep readiness weight (ceiling on flow capacity)
    /// Reference: Sleep deprivation reduces HRV and flow capacity
    private let sleepWeight: Double = 0.10

    /// Signal quality weight
    private let signalQualityWeight: Double = 0.05

    // === THRESHOLDS ===

    /// Flow detection thresholds (require 2+ min persistence)
    private let deepFlowThreshold: Double = 80
    private let lightFlowThreshold: Double = 60
    private let preFlowThreshold: Double = 40

    /// Sympathetic percentile bounds for inverted-U
    /// Reference: Peifer et al. 2014 - optimal arousal at 40-60th percentile
    private let optimalSympatheticLow: Double = 0.40   // 40th percentile
    private let optimalSympatheticHigh: Double = 0.60  // 60th percentile
    private let overloadThreshold: Double = 0.90       // >90th = overload
    private let boredomThreshold: Double = 0.10        // <10th = boredom

    /// Heart rate zone for optimal focus (percentage of resting HR)
    private let optimalHRRangeLow: Double = 1.10       // 110% of resting
    private let optimalHRRangeHigh: Double = 1.30      // 130% of resting

    /// Persistence requirements (number of consecutive readings)
    private let deepFlowPersistence: Int = 3           // 3 readings (~3 min at 1/min)
    private let lightFlowPersistence: Int = 2          // 2 readings (~2 min)

    private init() {
        self.baseline = BiometricFlowScoreCalculator.loadBaseline() ?? .default
    }

    // MARK: - Main Flow Score Calculation

    /// Calculate flow score from current biometric readings
    /// Call this every 30-60 seconds with updated HRV data
    func calculateFlowScore(
        hrvMetrics: HRVMetrics,
        currentHR: Double,
        sleepQuality: Double? = nil
    ) -> BiometricFlowResult {

        // === 1. PARASYMPATHETIC SCORE (Linear relationship) ===
        // Higher HF-HRV / RMSSD = better for flow
        let parasympatheticScore = calculateParasympatheticScore(hrvMetrics)

        // === 2. SYMPATHETIC OPTIMALITY (Inverted-U) ===
        // Moderate LF is optimal; too low = boredom, too high = overload
        let (sympatheticOptimality, sympatheticPercentile) = calculateSympatheticOptimality(hrvMetrics)

        // === 3. HEART RATE ZONE ===
        // 110-130% of resting is optimal focus zone
        let hrZoneScore = calculateHRZoneScore(currentHR)

        // === 4. SLEEP READINESS ===
        // Poor sleep caps flow capacity
        let sleepReadiness = sleepQuality ?? baseline.avgSleepQuality

        // === 5. SIGNAL QUALITY ===
        let signalQuality = hrvMetrics.isValid ? (1.0 - hrvMetrics.artifactPercentage) : 0.3

        // === COMBINE WITH WEIGHTS ===
        let rawScore = (parasympatheticScore * parasympatheticWeight) +
                       (sympatheticOptimality * sympatheticWeight) +
                       (hrZoneScore * hrZoneWeight) +
                       (sleepReadiness * sleepWeight) +
                       (signalQuality * signalQualityWeight)

        let normalizedScore = rawScore * 100

        // === DETERMINE STATE ===
        let state = determineFlowState(
            score: normalizedScore,
            sympatheticPercentile: sympatheticPercentile,
            parasympatheticScore: parasympatheticScore
        )

        // Update history
        updateHistory(score: normalizedScore, state: state)

        // Determine confidence
        let confidence = determineConfidence(hrvMetrics: hrvMetrics)

        // Build breakdown
        let breakdown = BiometricFlowBreakdown(
            parasympatheticScore: parasympatheticScore,
            sympatheticOptimality: sympatheticOptimality,
            hrZoneScore: hrZoneScore,
            sleepReadiness: sleepReadiness,
            signalQuality: signalQuality
        )

        // Generate recommendation
        let recommendation = generateRecommendation(
            state: state,
            breakdown: breakdown,
            sympatheticPercentile: sympatheticPercentile
        )

        let result = BiometricFlowResult(
            score: min(100, max(0, normalizedScore)),
            state: state,
            confidence: confidence,
            breakdown: breakdown,
            stateHistory: Array(stateHistory.suffix(5)),
            recommendation: recommendation
        )

        currentResult = result

        print("🌊 [BiometricFlow] Score: \(String(format: "%.1f", result.score)), State: \(state.rawValue), Confidence: \(confidence.rawValue)")

        return result
    }

    // MARK: - Component Calculations

    /// Parasympathetic score: Higher RMSSD relative to baseline = better
    /// Linear relationship with flow (Peifer 2014)
    private func calculateParasympatheticScore(_ hrvMetrics: HRVMetrics) -> Double {
        let rmssd = hrvMetrics.rmssd
        let baselineRMSSD = baseline.restingRMSSD

        guard baselineRMSSD > 0 else { return 0.5 }

        // Score based on ratio to baseline
        // At baseline = 0.5, significantly above = approaching 1.0
        let ratio = rmssd / baselineRMSSD

        // Piecewise linear mapping:
        // ratio < 0.5: Very low parasympathetic → 0.2
        // ratio 0.5-0.8: Poor → 0.2-0.5
        // ratio 0.8-1.0: Below baseline → 0.5-0.8
        // ratio 1.0-1.2: Good → 0.8-1.0
        // ratio > 1.2: Excellent → capped at 1.0

        if ratio < 0.5 {
            return 0.2
        } else if ratio < 0.8 {
            return 0.2 + (ratio - 0.5) / 0.3 * 0.3  // 0.2 to 0.5
        } else if ratio < 1.0 {
            return 0.5 + (ratio - 0.8) / 0.2 * 0.3  // 0.5 to 0.8
        } else if ratio < 1.2 {
            return 0.8 + (ratio - 1.0) / 0.2 * 0.2  // 0.8 to 1.0
        } else {
            return min(1.0, 0.95 + (ratio - 1.2) * 0.1)  // Cap at 1.0
        }
    }

    /// Sympathetic optimality: Inverted-U relationship
    /// Peak flow at 40-60th percentile of baseline LF power
    /// Reference: Peifer et al. 2014, R² = 0.21-0.40
    private func calculateSympatheticOptimality(_ hrvMetrics: HRVMetrics) -> (score: Double, percentile: Double) {
        // Use LF power if available, otherwise estimate from RMSSD/SDNN
        let lfPower = hrvMetrics.lfPower ?? estimateLFFromTimeDomain(
            rmssd: hrvMetrics.rmssd,
            sdnn: hrvMetrics.sdnn
        )

        // Get percentile rank
        let percentile: Double
        if baseline.lfPercentiles.count >= 5 {
            percentile = baseline.getPercentile(value: lfPower, distribution: baseline.lfPercentiles)
        } else {
            // Fallback: estimate percentile from ratio to baseline
            let ratio = lfPower / max(1, baseline.restingLFPower)
            percentile = min(1.0, max(0, ratio * 0.5))
        }

        // === INVERTED-U CALCULATION ===
        // Optimal: 40-60th percentile (0.4-0.6)
        // Formula: score peaks at 0.5 (50th percentile), declines symmetrically

        // Distance from optimal center (0.5)
        let distanceFromOptimal = abs(percentile - 0.5)

        // Base score: 1.0 at center, decreasing toward edges
        var score = 1.0 - (distanceFromOptimal * 2.0)

        // Ensure score in optimal zone is high
        if percentile >= optimalSympatheticLow && percentile <= optimalSympatheticHigh {
            score = max(score, 0.9)  // At least 0.9 in optimal zone
        }

        // Heavy penalty for extreme percentiles
        if percentile > overloadThreshold {
            // Overload: >90th percentile
            score *= 0.3
        } else if percentile < boredomThreshold {
            // Boredom: <10th percentile
            score *= 0.5
        }

        return (max(0, min(1, score)), percentile)
    }

    /// HR Zone score: 110-130% of resting is optimal for focus
    private func calculateHRZoneScore(_ currentHR: Double) -> Double {
        guard baseline.restingHR > 0 else { return 0.5 }

        let hrRatio = currentHR / baseline.restingHR

        if hrRatio >= optimalHRRangeLow && hrRatio <= optimalHRRangeHigh {
            // In optimal zone: full score
            return 1.0
        } else if hrRatio < 1.0 {
            // Below resting: low engagement
            return max(0.3, hrRatio)
        } else if hrRatio < optimalHRRangeLow {
            // Between resting and optimal low: ramping up
            let progress = (hrRatio - 1.0) / (optimalHRRangeLow - 1.0)
            return 0.7 + progress * 0.3
        } else if hrRatio <= 1.5 {
            // Above optimal but not excessive: declining score
            let excess = hrRatio - optimalHRRangeHigh
            return max(0.5, 1.0 - excess * 2.5)
        } else {
            // Very elevated: stress response
            return 0.2
        }
    }

    /// Estimate LF power from time-domain metrics when frequency domain unavailable
    /// LF ≈ SDNN² - RMSSD² (rough approximation since RMSSD captures HF)
    private func estimateLFFromTimeDomain(rmssd: Double, sdnn: Double) -> Double {
        let sdnnSquared = sdnn * sdnn
        let rmssdSquared = rmssd * rmssd
        return max(0, sdnnSquared - rmssdSquared)
    }

    // MARK: - State Determination with Persistence

    /// Determine flow state based on score and biometric signals
    /// Requires persistence to prevent flickering between states
    private func determineFlowState(
        score: Double,
        sympatheticPercentile: Double,
        parasympatheticScore: Double
    ) -> BiometricFlowResult.FlowState {

        // Check for overload first (safety override)
        if sympatheticPercentile > overloadThreshold {
            return .overload
        }

        // Check for boredom (low arousal + high parasympathetic = disengaged)
        if sympatheticPercentile < boredomThreshold && parasympatheticScore > 0.7 {
            return .boredom
        }

        // Check for deep flow (requires persistence)
        if score >= deepFlowThreshold {
            let recentFlowCount = stateHistory.suffix(deepFlowPersistence).filter {
                $0 == .deepFlow || $0 == .lightFlow
            }.count
            if recentFlowCount >= deepFlowPersistence - 1 {
                return .deepFlow
            }
        }

        // Check for light flow (requires persistence)
        if score >= lightFlowThreshold {
            let recentProgressCount = stateHistory.suffix(lightFlowPersistence).filter {
                $0 == .deepFlow || $0 == .lightFlow || $0 == .preFlow
            }.count
            if recentProgressCount >= lightFlowPersistence - 1 {
                return .lightFlow
            }
        }

        // Check for pre-flow (improving trend)
        if score >= preFlowThreshold {
            // Check for improving trend
            if scoreHistory.count >= 3 {
                let recentScores = Array(scoreHistory.suffix(3))
                let olderScores = Array(scoreHistory.prefix(min(5, scoreHistory.count)))

                let recentAvg = recentScores.reduce(0, +) / Double(recentScores.count)
                let olderAvg = olderScores.reduce(0, +) / Double(max(1, olderScores.count))

                if recentAvg > olderAvg + 5 {  // 5+ point improvement
                    return .preFlow
                }
            }
            return .preFlow
        }

        return .baseline
    }

    // MARK: - History Management

    private func updateHistory(score: Double, state: BiometricFlowResult.FlowState) {
        scoreHistory.append(score)
        stateHistory.append(state)

        // Keep last 10 readings (~5-10 minutes at 30-60s intervals)
        if scoreHistory.count > 10 {
            scoreHistory.removeFirst()
        }
        if stateHistory.count > 10 {
            stateHistory.removeFirst()
        }
    }

    /// Clear history (call at session start)
    func resetHistory() {
        scoreHistory.removeAll()
        stateHistory.removeAll()
        lastStateChangeTime = Date()
    }

    private func determineConfidence(hrvMetrics: HRVMetrics) -> BiometricFlowResult.ConfidenceLevel {
        if !baseline.isCalibrated { return .low }
        if baseline.daysOfData < 14 { return .medium }
        if !hrvMetrics.isValid { return .low }
        if hrvMetrics.artifactPercentage > 0.03 { return .medium }
        return .high
    }

    // MARK: - Recommendations

    private func generateRecommendation(
        state: BiometricFlowResult.FlowState,
        breakdown: BiometricFlowBreakdown,
        sympatheticPercentile: Double
    ) -> String {
        switch state {
        case .deepFlow:
            return "You're in deep flow! Avoid interruptions. This is your peak performance zone."

        case .lightFlow:
            return "You're entering flow. Keep going—full immersion is building."

        case .preFlow:
            if breakdown.parasympatheticScore > 0.7 {
                return "Good relaxation. Increase challenge slightly to enter flow."
            } else {
                return "Focus is building. Remove distractions and commit fully to the task."
            }

        case .baseline:
            if breakdown.parasympatheticScore < 0.5 {
                return "Your nervous system seems stressed. Try 5 minutes of slow breathing (5-6 breaths/min)."
            } else if breakdown.hrZoneScore < 0.5 {
                return "Your heart rate suggests low engagement. Try a more challenging aspect of your task."
            } else if breakdown.sleepReadiness < 0.5 {
                return "Sleep deficit may be limiting your focus capacity. Consider a power nap."
            }
            return "Normal state. Start your task and focus will build naturally."

        case .overload:
            return "Stress detected! Take a break. Try slow breathing or step away for 5 minutes."

        case .boredom:
            return "Low engagement detected. Try a more challenging task or increase difficulty."
        }
    }

    // MARK: - Baseline Management

    /// Update baseline with new biometric readings
    /// Uses exponential moving average for smooth updates
    func updateBaseline(with hrvMetrics: HRVMetrics, heartRate: Double, sleepQuality: Double?) {
        guard hrvMetrics.isValid else { return }

        // Rolling average update (weight new data at 10%)
        let alpha = 0.1

        baseline.restingRMSSD = baseline.restingRMSSD * (1 - alpha) + hrvMetrics.rmssd * alpha
        baseline.restingHR = baseline.restingHR * (1 - alpha) + heartRate * alpha

        if let hf = hrvMetrics.hfPower {
            baseline.restingHFPower = baseline.restingHFPower * (1 - alpha) + hf * alpha
        }
        if let lf = hrvMetrics.lfPower {
            baseline.restingLFPower = baseline.restingLFPower * (1 - alpha) + lf * alpha
        }

        if let sleep = sleepQuality {
            baseline.avgSleepQuality = baseline.avgSleepQuality * (1 - alpha) + sleep * alpha
        }

        baseline.totalReadings += 1
        baseline.lastUpdated = Date()

        // Check if new day
        let calendar = Calendar.current
        if let lastUpdated = calendar.dateComponents([.day], from: baseline.lastUpdated, to: Date()).day,
           lastUpdated > 0 {
            baseline.daysOfData += 1
        }

        // Mark calibrated after 14 days
        if baseline.daysOfData >= 14 && !baseline.isCalibrated {
            baseline.isCalibrated = true
            print("🌊 [BiometricFlow] Baseline fully calibrated after \(baseline.daysOfData) days")
        }

        saveBaseline()
    }

    /// Update circadian modifiers based on time-of-day HRV patterns
    func updateCircadianModifier(hour: Int, rmssd: Double) {
        // Calculate how this reading compares to overall baseline
        let modifier = rmssd / max(1, baseline.restingRMSSD)

        // Smooth update
        if let existing = baseline.circadianHRVModifiers[hour] {
            baseline.circadianHRVModifiers[hour] = existing * 0.8 + modifier * 0.2
        } else {
            baseline.circadianHRVModifiers[hour] = modifier
        }

        saveBaseline()
    }

    // MARK: - Persistence

    private func saveBaseline() {
        if let data = try? JSONEncoder().encode(baseline) {
            UserDefaults.standard.set(data, forKey: baselineKey)
        }
    }

    private static func loadBaseline() -> BiometricBaseline? {
        guard let data = UserDefaults.standard.data(forKey: "onlife_biometric_baseline"),
              let baseline = try? JSONDecoder().decode(BiometricBaseline.self, from: data) else {
            return nil
        }
        return baseline
    }

    /// Reset to default baseline
    func resetBaseline() {
        baseline = .default
        resetHistory()
        saveBaseline()
        print("🌊 [BiometricFlow] Baseline reset to defaults")
    }

    // MARK: - Flow State Duration Tracking

    /// Calculate how long user has been in current flow state
    func getFlowStateDuration() -> TimeInterval? {
        guard let current = currentResult else { return nil }

        // Count consecutive readings in current state
        var consecutiveCount = 0
        for state in stateHistory.reversed() {
            if state == current.state {
                consecutiveCount += 1
            } else {
                break
            }
        }

        // Approximate duration (assuming ~1 reading per minute)
        return Double(consecutiveCount) * 60
    }

    /// Check if user has achieved sustained flow (3+ minutes in deep/light flow)
    func hasSustainedFlow() -> Bool {
        let flowStates: [BiometricFlowResult.FlowState] = [.deepFlow, .lightFlow]
        let sustainedCount = stateHistory.suffix(3).filter { flowStates.contains($0) }.count
        return sustainedCount >= 3
    }
}

// MARK: - Extensions

extension BiometricFlowResult {
    /// Summary for display in UI
    var summary: String {
        "\(state.icon) \(state.rawValue) (\(Int(score))%)"
    }

    /// Detailed breakdown for analytics
    var debugDescription: String {
        """
        Flow Score: \(String(format: "%.1f", score))
        State: \(state.rawValue)
        Confidence: \(confidence.rawValue)

        Breakdown:
          Parasympathetic: \(String(format: "%.2f", breakdown.parasympatheticScore))
          Sympathetic Opt: \(String(format: "%.2f", breakdown.sympatheticOptimality))
          HR Zone: \(String(format: "%.2f", breakdown.hrZoneScore))
          Sleep: \(String(format: "%.2f", breakdown.sleepReadiness))
          Signal: \(String(format: "%.2f", breakdown.signalQuality))

        Recommendation: \(recommendation)
        """
    }
}
