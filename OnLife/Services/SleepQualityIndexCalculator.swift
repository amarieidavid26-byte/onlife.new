import Foundation
import HealthKit
import Combine

// MARK: - Research Citations
/*
 Sleep Quality Index (SQI) Calculator

 Research Foundation:

 1. Van Dongen HPA, Maislin G, Mullington JM, Dinges DF. "The cumulative cost of
    additional wakefulness: dose-response effects on neurobehavioral functions and
    sleep physiology from chronic sleep restriction and total sleep deprivation."
    Sleep. 2003;26(2):117-126.
    - Key finding: Cognitive performance degrades linearly with sleep debt
    - 4h sleep/night = equivalent to 2 days total deprivation after 2 weeks

 2. Hirshkowitz M, et al. "National Sleep Foundation's sleep time duration
    recommendations: methodology and results summary." Sleep Health. 2015;1(1):40-43.
    - Age-based optimal sleep duration recommendations
    - Adults (26-64): 7-9 hours optimal, 6-10 hours acceptable

 3. Ohayon M, et al. "Meta-analysis of quantitative sleep parameters from childhood
    to old age in healthy individuals." Sleep. 2004;27(7):1255-1273.
    - Deep sleep (N3): ~15-20% of total sleep time in adults
    - REM sleep: ~20-25% of total sleep time in adults

 4. Walker MP. "Why We Sleep: Unlocking the Power of Sleep and Dreams." 2017.
    - Sleep debt accumulation and partial recovery
    - Sleep timing and circadian alignment effects

 5. Åkerstedt T, et al. "Sleep duration and mortality." Sleep. 2017;40(2).
    - U-shaped relationship: both short and long sleep associated with issues
    - Optimal duration: 7-8 hours for cognitive function
*/

// MARK: - Sleep Data Container

/// Container for sleep data from HealthKit
struct SleepData: Codable {
    let date: Date
    let totalSleepDuration: TimeInterval      // Total time in bed
    let actualSleepDuration: TimeInterval     // Time actually asleep
    let sleepOnsetTime: Date                  // Time fell asleep
    let wakeTime: Date                        // Time woke up
    let deepSleepDuration: TimeInterval?      // Stage 3/4 NREM
    let remSleepDuration: TimeInterval?       // REM sleep
    let lightSleepDuration: TimeInterval?     // Stage 1/2 NREM
    let awakeningCount: Int                   // Number of awakenings
    let awakeningDuration: TimeInterval       // Total time awake during night
    let sleepLatency: TimeInterval?           // Time to fall asleep
    let heartRateDip: Double?                 // % HR drop during sleep
    let respiratoryRate: Double?              // Breaths per minute
    let spo2Average: Double?                  // Blood oxygen average

    /// Sleep efficiency: actual sleep / time in bed
    var sleepEfficiency: Double {
        guard totalSleepDuration > 0 else { return 0 }
        return actualSleepDuration / totalSleepDuration
    }

    /// Deep sleep percentage
    var deepSleepPercentage: Double? {
        guard let deep = deepSleepDuration, actualSleepDuration > 0 else { return nil }
        return deep / actualSleepDuration
    }

    /// REM sleep percentage
    var remSleepPercentage: Double? {
        guard let rem = remSleepDuration, actualSleepDuration > 0 else { return nil }
        return rem / actualSleepDuration
    }

    /// Mid-sleep time (for circadian alignment)
    var midSleepTime: Date {
        return sleepOnsetTime.addingTimeInterval(actualSleepDuration / 2)
    }
}

// MARK: - Sleep Quality Result

/// Result of sleep quality assessment
struct SleepQualityResult: Codable {
    let date: Date
    let sleepQualityIndex: Double             // 0-100 overall SQI
    let flowCapacityCeiling: Double           // 0-1, max achievable flow
    let sleepDebt: TimeInterval               // Accumulated sleep debt (hours)
    let recoveryPotential: Double             // 0-1, how much today can recover

    // Component scores (0-100)
    let durationScore: Double
    let efficiencyScore: Double
    let architectureScore: Double             // Deep + REM balance
    let continuityScore: Double               // Awakenings impact
    let timingScore: Double                   // Circadian alignment
    let regularityScore: Double               // Day-to-day consistency

    // Advisory
    let impactOnFlow: FlowImpact
    let recommendation: String

    enum FlowImpact: String, Codable {
        case optimal = "Optimal"              // SQI > 85
        case good = "Good"                    // SQI 70-85
        case moderate = "Moderate"            // SQI 55-70
        case impaired = "Impaired"            // SQI 40-55
        case severelyImpaired = "Severely Impaired"  // SQI < 40

        var flowMultiplier: Double {
            switch self {
            case .optimal: return 1.0
            case .good: return 0.90
            case .moderate: return 0.75
            case .impaired: return 0.55
            case .severelyImpaired: return 0.35
            }
        }
    }
}

// MARK: - Sleep Quality Index Calculator

/// Calculates Sleep Quality Index and its impact on flow capacity
/// Based on Van Dongen 2003 sleep deprivation dose-response research
class SleepQualityIndexCalculator {

    static let shared = SleepQualityIndexCalculator()

    // MARK: - Configuration

    /// Optimal sleep duration for adults (hours) - Hirshkowitz et al. 2015
    private let optimalSleepHours: Double = 7.5
    private let minAcceptableSleepHours: Double = 6.0
    private let maxBeneficialSleepHours: Double = 9.0

    /// Optimal sleep architecture - Ohayon et al. 2004
    private let optimalDeepSleepPercentage: Double = 0.18    // 18%
    private let optimalREMPercentage: Double = 0.23          // 23%
    private let minDeepSleepPercentage: Double = 0.10        // 10%
    private let minREMPercentage: Double = 0.15              // 15%

    /// Sleep efficiency thresholds
    private let optimalEfficiency: Double = 0.90             // 90%
    private let goodEfficiency: Double = 0.85                // 85%
    private let poorEfficiency: Double = 0.75                // 75%

    /// Sleep debt parameters (Van Dongen 2003)
    private let maxRecoverableDebtHours: Double = 20.0       // Max debt that can be recovered
    private let debtRecoveryRate: Double = 0.4               // 40% recovery per good night

    /// Component weights for SQI calculation
    private let weights = (
        duration: 0.25,
        efficiency: 0.20,
        architecture: 0.20,
        continuity: 0.15,
        timing: 0.10,
        regularity: 0.10
    )

    // MARK: - State

    /// Recent sleep history for regularity calculation
    private var sleepHistory: [SleepData] = []
    private let maxHistoryDays = 14

    /// Accumulated sleep debt
    private(set) var currentSleepDebt: TimeInterval = 0

    /// User's preferred wake time (for timing calculations)
    var preferredWakeTime: DateComponents? = nil

    /// User's chronotype (affects optimal timing)
    var userChronotype: Chronotype = .intermediate

    // MARK: - Publishers

    let sleepQualityPublisher = PassthroughSubject<SleepQualityResult, Never>()

    // MARK: - Main Calculation

    /// Calculate comprehensive sleep quality index
    /// - Parameter sleepData: Last night's sleep data
    /// - Returns: SleepQualityResult with all component scores
    func calculateSleepQuality(from sleepData: SleepData) -> SleepQualityResult {
        // Store in history
        addToHistory(sleepData)

        // Calculate component scores
        let durationScore = calculateDurationScore(sleepData.actualSleepDuration)
        let efficiencyScore = calculateEfficiencyScore(sleepData.sleepEfficiency)
        let architectureScore = calculateArchitectureScore(
            deepPercentage: sleepData.deepSleepPercentage,
            remPercentage: sleepData.remSleepPercentage
        )
        let continuityScore = calculateContinuityScore(
            awakenings: sleepData.awakeningCount,
            awakeningDuration: sleepData.awakeningDuration,
            totalSleep: sleepData.actualSleepDuration
        )
        let timingScore = calculateTimingScore(
            sleepOnset: sleepData.sleepOnsetTime,
            wakeTime: sleepData.wakeTime
        )
        let regularityScore = calculateRegularityScore()

        // Calculate weighted SQI
        let sqi = (durationScore * weights.duration +
                   efficiencyScore * weights.efficiency +
                   architectureScore * weights.architecture +
                   continuityScore * weights.continuity +
                   timingScore * weights.timing +
                   regularityScore * weights.regularity)

        // Update sleep debt
        updateSleepDebt(actualSleep: sleepData.actualSleepDuration, sqi: sqi)

        // Calculate flow capacity ceiling
        let flowCeiling = calculateFlowCapacityCeiling(sqi: sqi, sleepDebt: currentSleepDebt)

        // Determine impact and recommendation
        let impact = determineFlowImpact(sqi: sqi)
        let recommendation = generateRecommendation(
            sqi: sqi,
            sleepData: sleepData,
            durationScore: durationScore,
            architectureScore: architectureScore
        )

        let result = SleepQualityResult(
            date: sleepData.date,
            sleepQualityIndex: sqi,
            flowCapacityCeiling: flowCeiling,
            sleepDebt: currentSleepDebt,
            recoveryPotential: calculateRecoveryPotential(),
            durationScore: durationScore,
            efficiencyScore: efficiencyScore,
            architectureScore: architectureScore,
            continuityScore: continuityScore,
            timingScore: timingScore,
            regularityScore: regularityScore,
            impactOnFlow: impact,
            recommendation: recommendation
        )

        sleepQualityPublisher.send(result)

        print("😴 [SleepQuality] SQI: \(String(format: "%.1f", sqi)), Flow Ceiling: \(String(format: "%.0f%%", flowCeiling * 100)), Debt: \(String(format: "%.1fh", currentSleepDebt / 3600))")

        return result
    }

    // MARK: - Component Calculations

    /// Duration score based on optimal 7-9 hour range
    private func calculateDurationScore(_ duration: TimeInterval) -> Double {
        let hours = duration / 3600

        if hours >= optimalSleepHours && hours <= maxBeneficialSleepHours {
            // Optimal range: full score
            return 100
        } else if hours < optimalSleepHours {
            // Short sleep: linear degradation
            if hours >= minAcceptableSleepHours {
                let deficit = optimalSleepHours - hours
                return 100 - (deficit * 20) // -20 points per hour short
            } else {
                // Severe short sleep
                let deficit = optimalSleepHours - hours
                return max(0, 100 - (deficit * 25))
            }
        } else {
            // Long sleep: slight penalty (U-shaped relationship)
            let excess = hours - maxBeneficialSleepHours
            return max(60, 100 - (excess * 10))
        }
    }

    /// Efficiency score based on actual sleep / time in bed
    private func calculateEfficiencyScore(_ efficiency: Double) -> Double {
        if efficiency >= optimalEfficiency {
            return 100
        } else if efficiency >= goodEfficiency {
            // Linear interpolation from good to optimal
            let range = optimalEfficiency - goodEfficiency
            let position = (efficiency - goodEfficiency) / range
            return 80 + (position * 20)
        } else if efficiency >= poorEfficiency {
            // Linear interpolation from poor to good
            let range = goodEfficiency - poorEfficiency
            let position = (efficiency - poorEfficiency) / range
            return 50 + (position * 30)
        } else {
            // Very poor efficiency
            return max(0, efficiency / poorEfficiency * 50)
        }
    }

    /// Architecture score based on deep sleep and REM percentages
    private func calculateArchitectureScore(deepPercentage: Double?, remPercentage: Double?) -> Double {
        var score: Double = 70 // Default if no stage data

        if let deep = deepPercentage, let rem = remPercentage {
            // Both available - full assessment
            let deepScore = calculateStageScore(deep, optimal: optimalDeepSleepPercentage, minimum: minDeepSleepPercentage)
            let remScore = calculateStageScore(rem, optimal: optimalREMPercentage, minimum: minREMPercentage)

            // Weight deep sleep slightly higher (more impactful for restoration)
            score = (deepScore * 0.55) + (remScore * 0.45)
        } else if let deep = deepPercentage {
            score = calculateStageScore(deep, optimal: optimalDeepSleepPercentage, minimum: minDeepSleepPercentage)
        } else if let rem = remPercentage {
            score = calculateStageScore(rem, optimal: optimalREMPercentage, minimum: minREMPercentage)
        }

        return score
    }

    /// Helper for sleep stage scoring
    private func calculateStageScore(_ percentage: Double, optimal: Double, minimum: Double) -> Double {
        if percentage >= optimal {
            // At or above optimal
            let excess = percentage - optimal
            // Slight penalty for excess (though generally okay)
            return max(85, 100 - (excess * 100))
        } else if percentage >= minimum {
            // Between minimum and optimal
            let range = optimal - minimum
            let position = (percentage - minimum) / range
            return 60 + (position * 40)
        } else {
            // Below minimum
            return max(0, (percentage / minimum) * 60)
        }
    }

    /// Continuity score based on awakenings
    private func calculateContinuityScore(awakenings: Int, awakeningDuration: TimeInterval, totalSleep: TimeInterval) -> Double {
        // Baseline score
        var score: Double = 100

        // Penalty for number of awakenings (normal: 1-2, concerning: >5)
        if awakenings > 2 {
            score -= Double(awakenings - 2) * 8
        }

        // Penalty for time spent awake during night
        let awakePercentage = awakeningDuration / totalSleep
        if awakePercentage > 0.05 {
            score -= (awakePercentage - 0.05) * 200
        }

        return max(0, min(100, score))
    }

    /// Timing score based on circadian alignment
    private func calculateTimingScore(sleepOnset: Date, wakeTime: Date) -> Double {
        let calendar = Calendar.current

        // Get sleep onset hour
        let onsetHour = calendar.component(.hour, from: sleepOnset)
        let onsetMinute = calendar.component(.minute, from: sleepOnset)
        let onsetDecimal = Double(onsetHour) + Double(onsetMinute) / 60

        // Get wake hour
        let wakeHour = calendar.component(.hour, from: wakeTime)
        let wakeMinute = calendar.component(.minute, from: wakeTime)
        let wakeDecimal = Double(wakeHour) + Double(wakeMinute) / 60

        // Optimal timing based on chronotype
        let (optimalOnset, optimalWake) = getOptimalTiming(for: userChronotype)

        // Calculate deviation from optimal
        let onsetDeviation = abs(normalizeHour(onsetDecimal) - normalizeHour(optimalOnset))
        let wakeDeviation = abs(wakeDecimal - optimalWake)

        // Score calculation (penalty for deviation)
        var score: Double = 100
        score -= onsetDeviation * 10  // -10 points per hour off optimal onset
        score -= wakeDeviation * 8    // -8 points per hour off optimal wake

        return max(0, min(100, score))
    }

    /// Get optimal sleep timing for chronotype
    private func getOptimalTiming(for chronotype: Chronotype) -> (onset: Double, wake: Double) {
        switch chronotype {
        case .extremeMorning:
            return (onset: 21.0, wake: 5.0)   // 9 PM - 5 AM
        case .moderateMorning:
            return (onset: 22.0, wake: 6.0)   // 10 PM - 6 AM
        case .intermediate:
            return (onset: 23.0, wake: 7.0)   // 11 PM - 7 AM
        case .moderateEvening:
            return (onset: 24.0, wake: 8.0)   // 12 AM - 8 AM
        case .extremeEvening:
            return (onset: 25.0, wake: 9.0)   // 1 AM - 9 AM
        }
    }

    /// Normalize hour for comparison (handle midnight crossing)
    private func normalizeHour(_ hour: Double) -> Double {
        if hour < 12 {
            return hour + 24
        }
        return hour
    }

    /// Regularity score based on sleep history consistency
    private func calculateRegularityScore() -> Double {
        guard sleepHistory.count >= 3 else {
            // Not enough data for regularity assessment
            return 75 // Neutral score
        }

        let recent = Array(sleepHistory.suffix(7))

        // Calculate standard deviation of sleep onset times
        let onsetTimes = recent.map { data -> Double in
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: data.sleepOnsetTime)
            let minute = calendar.component(.minute, from: data.sleepOnsetTime)
            return normalizeHour(Double(hour) + Double(minute) / 60)
        }

        let onsetMean = onsetTimes.reduce(0, +) / Double(onsetTimes.count)
        let onsetVariance = onsetTimes.map { pow($0 - onsetMean, 2) }.reduce(0, +) / Double(onsetTimes.count)
        let onsetStdDev = sqrt(onsetVariance)

        // Calculate standard deviation of sleep durations
        let durations = recent.map { $0.actualSleepDuration / 3600 } // hours
        let durationMean = durations.reduce(0, +) / Double(durations.count)
        let durationVariance = durations.map { pow($0 - durationMean, 2) }.reduce(0, +) / Double(durations.count)
        let durationStdDev = sqrt(durationVariance)

        // Score: lower variation = higher score
        var score: Double = 100

        // Onset time variation (optimal: <30min, poor: >2h)
        if onsetStdDev > 0.5 { // 30 min
            score -= (onsetStdDev - 0.5) * 20
        }

        // Duration variation (optimal: <30min, poor: >1.5h)
        if durationStdDev > 0.5 {
            score -= (durationStdDev - 0.5) * 15
        }

        return max(0, min(100, score))
    }

    // MARK: - Sleep Debt Management

    /// Update accumulated sleep debt based on last night's sleep
    private func updateSleepDebt(actualSleep: TimeInterval, sqi: Double) {
        let optimalSleep = optimalSleepHours * 3600
        let deficit = optimalSleep - actualSleep

        if deficit > 0 {
            // Add to debt
            currentSleepDebt += deficit
            // Cap debt (beyond a point, you can't "bank" more debt)
            currentSleepDebt = min(currentSleepDebt, maxRecoverableDebtHours * 3600)
        } else if sqi > 70 {
            // Good sleep: recover some debt
            let recovery = min(-deficit, currentSleepDebt * debtRecoveryRate)
            currentSleepDebt = max(0, currentSleepDebt - recovery)
        }
    }

    /// Calculate how much recovery is possible today
    private func calculateRecoveryPotential() -> Double {
        if currentSleepDebt <= 0 {
            return 1.0 // Fully recovered
        }

        // Recovery potential decreases with accumulated debt
        let debtHours = currentSleepDebt / 3600
        if debtHours < 5 {
            return 0.8 // Minor debt, good recovery potential
        } else if debtHours < 10 {
            return 0.6
        } else if debtHours < 15 {
            return 0.4
        } else {
            return 0.25 // Severe debt, limited single-night recovery
        }
    }

    // MARK: - Flow Capacity

    /// Calculate maximum achievable flow state based on sleep
    /// Based on Van Dongen 2003 dose-response relationship
    private func calculateFlowCapacityCeiling(sqi: Double, sleepDebt: TimeInterval) -> Double {
        // Base ceiling from SQI
        var ceiling = sqi / 100

        // Additional penalty from accumulated sleep debt
        // Van Dongen: Each hour of debt reduces performance ~4%
        let debtHours = sleepDebt / 3600
        let debtPenalty = debtHours * 0.04
        ceiling -= debtPenalty

        // Floor at 0.2 (even severe sleep deprivation allows some function)
        return max(0.2, min(1.0, ceiling))
    }

    /// Determine flow impact category
    private func determineFlowImpact(sqi: Double) -> SleepQualityResult.FlowImpact {
        switch sqi {
        case 85...100:
            return .optimal
        case 70..<85:
            return .good
        case 55..<70:
            return .moderate
        case 40..<55:
            return .impaired
        default:
            return .severelyImpaired
        }
    }

    // MARK: - Recommendations

    /// Generate personalized sleep recommendation
    private func generateRecommendation(sqi: Double, sleepData: SleepData, durationScore: Double, architectureScore: Double) -> String {
        var recommendations: [String] = []

        // Duration issues
        let hours = sleepData.actualSleepDuration / 3600
        if hours < minAcceptableSleepHours {
            recommendations.append("Prioritize getting at least \(Int(optimalSleepHours)) hours tonight")
        } else if durationScore < 70 {
            let targetHours = optimalSleepHours
            recommendations.append("Aim for \(Int(targetHours)) hours of sleep")
        }

        // Efficiency issues
        if sleepData.sleepEfficiency < goodEfficiency {
            recommendations.append("Reduce time in bed awake - try going to bed when sleepy")
        }

        // Architecture issues
        if let deep = sleepData.deepSleepPercentage, deep < minDeepSleepPercentage {
            recommendations.append("Exercise and avoid alcohol to improve deep sleep")
        }

        // Timing issues
        let calendar = Calendar.current
        let onsetHour = calendar.component(.hour, from: sleepData.sleepOnsetTime)
        let (optimalOnset, _) = getOptimalTiming(for: userChronotype)
        if abs(Double(onsetHour) - optimalOnset) > 2 {
            recommendations.append("Adjust bedtime closer to \(Int(optimalOnset > 24 ? optimalOnset - 24 : optimalOnset)):00")
        }

        // Sleep debt warning
        if currentSleepDebt > 10 * 3600 {
            recommendations.insert("Sleep debt is significant - prioritize recovery sleep", at: 0)
        }

        if recommendations.isEmpty {
            return "Sleep quality is good - maintain your current routine"
        }

        return recommendations.first ?? "Focus on consistent sleep timing"
    }

    // MARK: - History Management

    private func addToHistory(_ data: SleepData) {
        sleepHistory.append(data)

        // Prune old entries
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxHistoryDays, to: Date())!
        sleepHistory = sleepHistory.filter { $0.date > cutoff }
    }

    /// Clear history and reset debt (for testing or user reset)
    func reset() {
        sleepHistory.removeAll()
        currentSleepDebt = 0
    }

    // MARK: - Quick Assessment

    /// Quick assessment when only basic data available
    func quickAssessment(sleepHours: Double) -> (sqi: Double, flowCeiling: Double) {
        let durationScore = calculateDurationScore(sleepHours * 3600)

        // Estimate SQI from duration alone (other components assumed average)
        let estimatedSQI = durationScore * 0.6 + 40 * 0.4 // 40 as neutral baseline
        let flowCeiling = calculateFlowCapacityCeiling(sqi: estimatedSQI, sleepDebt: currentSleepDebt)

        return (sqi: estimatedSQI, flowCeiling: flowCeiling)
    }

    // MARK: - HealthKit Integration Helpers

    /// Convert HealthKit sleep samples to SleepData
    func createSleepData(from samples: [HKCategorySample], heartRateSamples: [HKQuantitySample]? = nil) -> SleepData? {
        guard !samples.isEmpty else { return nil }

        // Sort by start date
        let sorted = samples.sorted { $0.startDate < $1.startDate }

        guard let firstSample = sorted.first,
              let lastSample = sorted.last else { return nil }

        let sleepOnset = firstSample.startDate
        let wakeTime = lastSample.endDate
        let totalDuration = wakeTime.timeIntervalSince(sleepOnset)

        // Calculate durations by sleep stage
        var asleepDuration: TimeInterval = 0
        var deepDuration: TimeInterval = 0
        var remDuration: TimeInterval = 0
        var coreDuration: TimeInterval = 0
        var awakeDuration: TimeInterval = 0
        var awakeCount = 0

        for sample in sorted {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)

            if #available(iOS 16.0, watchOS 9.0, *) {
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepDuration += duration
                    asleepDuration += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    remDuration += duration
                    asleepDuration += duration
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    coreDuration += duration
                    asleepDuration += duration
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    awakeDuration += duration
                    awakeCount += 1
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    asleepDuration += duration
                default:
                    // InBed or other
                    break
                }
            } else {
                // Pre-iOS 16: only asleep/inBed available
                if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                    asleepDuration += duration
                }
            }
        }

        // If no stage data, estimate
        let hasStageData = deepDuration > 0 || remDuration > 0

        // Calculate heart rate dip if HR data available
        var hrDip: Double? = nil
        if let hrSamples = heartRateSamples, hrSamples.count >= 10 {
            let hrValues = hrSamples.map { $0.quantity.doubleValue(for: .count().unitDivided(by: .minute())) }
            let minHR = hrValues.min() ?? 0
            let maxHR = hrValues.max() ?? 1
            if maxHR > 0 {
                hrDip = 1.0 - (minHR / maxHR)
            }
        }

        return SleepData(
            date: sleepOnset,
            totalSleepDuration: totalDuration,
            actualSleepDuration: asleepDuration > 0 ? asleepDuration : totalDuration * 0.85,
            sleepOnsetTime: sleepOnset,
            wakeTime: wakeTime,
            deepSleepDuration: hasStageData ? deepDuration : nil,
            remSleepDuration: hasStageData ? remDuration : nil,
            lightSleepDuration: hasStageData ? coreDuration : nil,
            awakeningCount: awakeCount,
            awakeningDuration: awakeDuration,
            sleepLatency: nil,
            heartRateDip: hrDip,
            respiratoryRate: nil,
            spo2Average: nil
        )
    }
}

// MARK: - Combine Extensions

extension SleepQualityIndexCalculator {
    /// Publisher for sleep quality updates
    var qualityUpdates: AnyPublisher<SleepQualityResult, Never> {
        sleepQualityPublisher.eraseToAnyPublisher()
    }
}
