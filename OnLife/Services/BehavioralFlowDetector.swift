import Foundation
import SwiftUI

/// Detects flow states for users without Apple Watch using behavioral signals
/// Research basis: Brizan et al. 2015 - 72.4% accuracy from behavioral patterns
/// Gloria Mark: 23 min 15 sec average to recover focus after distraction
class BehavioralFlowDetector {
    static let shared = BehavioralFlowDetector()

    private init() {}

    // MARK: - Flow Probability Calculation

    /// Calculate flow probability from behavioral features (0-100)
    func calculateFlowProbability(features: BehavioralFeatures) -> Double {
        return calculateFlowProbability(features: features, screenSummary: nil, appSwitchAnalysis: nil)
    }

    /// Calculate flow probability from behavioral features with screen activity (0-100)
    func calculateFlowProbability(features: BehavioralFeatures, screenSummary: ScreenActivitySummary?) -> Double {
        return calculateFlowProbability(features: features, screenSummary: screenSummary, appSwitchAnalysis: nil)
    }

    /// Calculate flow probability with full context (screen activity + app switching)
    /// Research: Screen-off >30 seconds correlates with loss of flow state
    /// Gloria Mark: 23 minutes to regain focus after context switch
    func calculateFlowProbability(
        features: BehavioralFeatures,
        screenSummary: ScreenActivitySummary?,
        appSwitchAnalysis: AppSwitchAnalysis?
    ) -> Double {
        var score = 50.0 // Neutral baseline

        // === SCREEN ACTIVITY PENALTY (max -40 points) ===
        if let screenSummary = screenSummary {
            score -= screenSummary.flowPenalty

            // Additional penalty for high distraction frequency
            if screenSummary.significantDistractions >= 5 {
                score -= 10
            } else if screenSummary.significantDistractions >= 3 {
                score -= 5
            }
        }

        // === APP SWITCHING PENALTY (max -45 points) ===
        if let switchAnalysis = appSwitchAnalysis {
            score -= switchAnalysis.flowPenalty

            // Additional penalty for severe switching pattern
            switch switchAnalysis.switchPattern {
            case .severe:
                score -= 10
            case .moderate:
                score -= 5
            default:
                break
            }
        } else {
            // Fallback to basic count if no detailed analysis
            score -= Double(features.appSwitchCount) * 5.0
        }

        score = max(score, 0)

        // === DISTRACTION PENALTY (max -30 points) ===
        // Only apply if no app switch analysis (to avoid double counting)
        if appSwitchAnalysis == nil {
            score += calculateDistractionScore(features: features)
        } else {
            // Still apply pause frequency penalty but not app switch penalty
            score += calculatePauseOnlyDistractionScore(features: features)
        }

        // === FOCUS CONSISTENCY BONUS (max +25 points) ===
        score += calculateFocusConsistencyScore(features: features)

        // === HISTORICAL PERFORMANCE (max +15 points) ===
        score += calculateHistoricalScore(features: features)

        // === TEMPORAL PATTERNS (max +10 points) ===
        score += calculateTemporalScore(features: features)

        // === SESSION FATIGUE PENALTY (max -10 points) ===
        score += calculateFatigueScore(features: features)

        return max(0, min(100, score))
    }

    // MARK: - Score Components

    private func calculateDistractionScore(features: BehavioralFeatures) -> Double {
        var penalty = 0.0

        // Frequent pauses hurt flow
        if features.sessionDuration > 0 {
            let pauseFrequency = Double(features.pauseCount) / (features.sessionDuration / 60.0)

            if pauseFrequency > 2 { // More than 2 pauses per minute
                penalty -= 30
            } else if pauseFrequency > 1 {
                penalty -= 20
            } else if pauseFrequency > 0.5 {
                penalty -= 10
            }
        }

        // App switching penalty (Gloria Mark: 23min recovery)
        penalty -= Double(features.appSwitchCount) * 5.0

        return max(-30, penalty)
    }

    /// Calculate pause-only distraction score (excludes app switching when detailed analysis is available)
    private func calculatePauseOnlyDistractionScore(features: BehavioralFeatures) -> Double {
        var penalty = 0.0

        // Frequent pauses hurt flow
        if features.sessionDuration > 0 {
            let pauseFrequency = Double(features.pauseCount) / (features.sessionDuration / 60.0)

            if pauseFrequency > 2 {
                penalty -= 20
            } else if pauseFrequency > 1 {
                penalty -= 10
            } else if pauseFrequency > 0.5 {
                penalty -= 5
            }
        }

        return max(-20, penalty)
    }

    private func calculateFocusConsistencyScore(features: BehavioralFeatures) -> Double {
        var bonus = 0.0

        // Long uninterrupted stretches indicate flow
        if features.longestUninterruptedStretch >= 25 * 60 { // 25+ minutes
            bonus += 25
        } else if features.longestUninterruptedStretch >= 15 * 60 { // 15-25 minutes
            bonus += 15
        } else if features.longestUninterruptedStretch >= 10 * 60 { // 10-15 minutes
            bonus += 10
        } else if features.longestUninterruptedStretch >= 5 * 60 { // 5-10 minutes
            bonus += 5
        }

        // Time to first pause (delayed distraction = better flow)
        if let timeToFirstPause = features.timeToFirstPause {
            if timeToFirstPause >= 20 * 60 { // 20+ minutes
                bonus += 15
            } else if timeToFirstPause >= 10 * 60 { // 10-20 minutes
                bonus += 10
            } else if timeToFirstPause >= 5 * 60 { // 5-10 minutes
                bonus += 5
            }
        } else if features.sessionDuration >= 10 * 60 {
            // No pause at all and session is 10+ minutes - excellent focus
            bonus += 15
        }

        return min(25, bonus)
    }

    private func calculateHistoricalScore(features: BehavioralFeatures) -> Double {
        var bonus = 0.0

        // Recent high performers likely in flow
        if features.avgFlowScoreLast7Days >= 75 {
            bonus += 15
        } else if features.avgFlowScoreLast7Days >= 60 {
            bonus += 10
        } else if features.avgFlowScoreLast7Days >= 50 {
            bonus += 5
        }

        return min(15, bonus)
    }

    private func calculateTemporalScore(features: BehavioralFeatures) -> Double {
        var bonus = 0.0

        // Consistency bonus (same time = better preparation)
        if features.sameTimeOfDayAsUsual {
            bonus += 5
        }

        // Consecutive days (momentum effect)
        if features.consecutiveDays >= 7 {
            bonus += 10
        } else if features.consecutiveDays >= 3 {
            bonus += 5
        } else if features.consecutiveDays >= 1 {
            bonus += 2
        }

        return min(10, bonus)
    }

    private func calculateFatigueScore(features: BehavioralFeatures) -> Double {
        var penalty = 0.0

        // Too many sessions today = diminishing returns
        if features.sessionCountToday >= 5 {
            penalty -= 10
        } else if features.sessionCountToday >= 3 {
            penalty -= 5
        }

        // Too soon after last session
        if let minutesSince = features.minutesSinceLastSession, minutesSince < 30 {
            penalty -= 10
        }

        return max(-10, penalty)
    }

    // MARK: - Session Success Prediction

    /// Predict likelihood of successful session completion
    func predictSessionSuccess(features: BehavioralFeatures) -> (probability: Double, factors: [SuccessFactor]) {
        var successProbability = 0.5 // Neutral
        var factors: [SuccessFactor] = []

        // Historical completion rate (strongest predictor)
        if features.completionRateLast7Days >= 0.8 {
            successProbability += 0.25
            factors.append(SuccessFactor(
                description: "Strong completion history",
                impact: .positive,
                icon: "checkmark.seal.fill"
            ))
        } else if features.completionRateLast7Days >= 0.6 {
            successProbability += 0.15
            factors.append(SuccessFactor(
                description: "Good completion history",
                impact: .positive,
                icon: "checkmark.circle"
            ))
        } else if features.completionRateLast7Days <= 0.4 && features.completionRateLast7Days > 0 {
            successProbability -= 0.15
            factors.append(SuccessFactor(
                description: "Low recent completion rate",
                impact: .negative,
                icon: "exclamationmark.triangle"
            ))
        }

        // Time of day consistency
        if features.sameTimeOfDayAsUsual {
            successProbability += 0.1
            factors.append(SuccessFactor(
                description: "Familiar time of day",
                impact: .positive,
                icon: "clock.badge.checkmark"
            ))
        }

        // Consecutive days streak
        if features.consecutiveDays >= 3 {
            successProbability += 0.1
            factors.append(SuccessFactor(
                description: "Active streak momentum",
                impact: .positive,
                icon: "flame.fill"
            ))
        }

        // Session fatigue
        if features.sessionCountToday >= 4 {
            successProbability -= 0.15
            factors.append(SuccessFactor(
                description: "High session count today",
                impact: .negative,
                icon: "battery.25"
            ))
        }

        // Time since last session
        if let minutesSince = features.minutesSinceLastSession {
            if minutesSince < 30 {
                successProbability -= 0.1
                factors.append(SuccessFactor(
                    description: "Too soon after last session",
                    impact: .negative,
                    icon: "timer"
                ))
            } else if minutesSince > 180 {
                successProbability += 0.05
                factors.append(SuccessFactor(
                    description: "Well-rested",
                    impact: .positive,
                    icon: "sparkles"
                ))
            }
        }

        return (max(0, min(1, successProbability)), factors)
    }

    // MARK: - Recommendations

    /// Generate context-aware recommendation
    func generateRecommendation(features: BehavioralFeatures, flowProbability: Double) -> String {
        return generateRecommendation(features: features, flowProbability: flowProbability, screenSummary: nil, appSwitchAnalysis: nil)
    }

    /// Generate context-aware recommendation with screen activity data
    func generateRecommendation(features: BehavioralFeatures, flowProbability: Double, screenSummary: ScreenActivitySummary?) -> String {
        return generateRecommendation(features: features, flowProbability: flowProbability, screenSummary: screenSummary, appSwitchAnalysis: nil)
    }

    /// Generate context-aware recommendation with full context
    func generateRecommendation(
        features: BehavioralFeatures,
        flowProbability: Double,
        screenSummary: ScreenActivitySummary?,
        appSwitchAnalysis: AppSwitchAnalysis?
    ) -> String {
        // Check app switching first for specific recommendations
        if let analysis = appSwitchAnalysis {
            if analysis.contextSwitches >= 2 {
                return "Multiple context switches detected. Try enabling Focus mode to minimize interruptions."
            } else if analysis.switchPattern == .severe {
                return "High distraction level. Consider finding a quieter environment or silencing notifications."
            } else if analysis.totalSwitches >= 5 {
                return "Frequent app switching affecting focus. Try keeping only essential apps open."
            }
        }

        // Check screen activity for specific recommendations
        if let screenSummary = screenSummary {
            if screenSummary.significantDistractions >= 5 {
                return "High screen distractions detected. Try putting your phone in Do Not Disturb mode."
            } else if screenSummary.significantDistractions >= 3 {
                return "Multiple distractions affecting focus. Consider silencing notifications."
            }
        }

        if flowProbability >= 75 {
            return "Excellent conditions for deep work. Tackle your most important task."
        } else if flowProbability >= 60 {
            return "Good focus potential. You're ready for focused work."
        } else if flowProbability >= 40 {
            if let analysis = appSwitchAnalysis, analysis.distractions > 0 {
                return "Moderate conditions with some distractions. Consider using Do Not Disturb mode."
            }
            return "Moderate conditions. Start with easier tasks to build momentum."
        } else {
            // Provide specific advice based on factors
            if features.sessionCountToday >= 4 {
                return "You've had a productive day. Consider taking a break to recharge."
            } else if let minutesSince = features.minutesSinceLastSession, minutesSince < 30 {
                return "Give yourself 30+ minutes between sessions for better focus."
            } else if features.appSwitchCount > 3 {
                return "Minimize distractions before starting. Close unnecessary apps."
            } else {
                return "Consider a short break or prep routine before starting."
            }
        }
    }

    /// Generate pre-session readiness assessment
    func assessReadiness(features: BehavioralFeatures) -> ReadinessAssessment {
        return assessReadiness(features: features, screenSummary: nil, appSwitchAnalysis: nil)
    }

    /// Generate readiness assessment with screen activity data
    func assessReadiness(features: BehavioralFeatures, screenSummary: ScreenActivitySummary?) -> ReadinessAssessment {
        return assessReadiness(features: features, screenSummary: screenSummary, appSwitchAnalysis: nil)
    }

    /// Generate readiness assessment with full context
    func assessReadiness(
        features: BehavioralFeatures,
        screenSummary: ScreenActivitySummary?,
        appSwitchAnalysis: AppSwitchAnalysis?
    ) -> ReadinessAssessment {
        let flowProbability = calculateFlowProbability(features: features, screenSummary: screenSummary, appSwitchAnalysis: appSwitchAnalysis)
        var (successProbability, factors) = predictSessionSuccess(features: features)
        let recommendation = generateRecommendation(features: features, flowProbability: flowProbability, screenSummary: screenSummary, appSwitchAnalysis: appSwitchAnalysis)

        // Add screen activity factor if significant distractions occurred
        if let screenSummary = screenSummary, screenSummary.significantDistractions > 0 {
            successProbability -= Double(screenSummary.significantDistractions) * 0.05
            successProbability = max(0, min(1, successProbability))

            if screenSummary.significantDistractions >= 3 {
                factors.append(SuccessFactor(
                    description: "Multiple screen distractions",
                    impact: .negative,
                    icon: "rectangle.on.rectangle.slash"
                ))
            }
        }

        // Add app switching factor if significant switching occurred
        if let switchAnalysis = appSwitchAnalysis {
            successProbability -= switchAnalysis.flowPenalty / 100
            successProbability = max(0, min(1, successProbability))

            switch switchAnalysis.switchPattern {
            case .severe:
                factors.append(SuccessFactor(
                    description: "High app switching",
                    impact: .negative,
                    icon: "arrow.triangle.2.circlepath"
                ))
            case .moderate:
                factors.append(SuccessFactor(
                    description: "Moderate app switching",
                    impact: .negative,
                    icon: "arrow.left.arrow.right"
                ))
            case .minimal, .focused:
                if switchAnalysis.totalSwitches == 0 {
                    factors.append(SuccessFactor(
                        description: "No app switching",
                        impact: .positive,
                        icon: "checkmark.seal"
                    ))
                }
            }
        }

        let level: ReadinessAssessment.ReadinessLevel
        switch flowProbability {
        case 75...100: level = .excellent
        case 60..<75: level = .good
        case 40..<60: level = .moderate
        default: level = .low
        }

        return ReadinessAssessment(
            level: level,
            flowProbability: flowProbability,
            successProbability: successProbability,
            recommendation: recommendation,
            factors: factors
        )
    }

    // MARK: - Types

    struct SuccessFactor {
        let description: String
        let impact: Impact
        let icon: String

        enum Impact {
            case positive, negative, neutral

            var color: Color {
                switch self {
                case .positive: return .green
                case .negative: return OnLifeColors.terracotta
                case .neutral: return OnLifeColors.textSecondary
                }
            }
        }
    }

    struct ReadinessAssessment {
        let level: ReadinessLevel
        let flowProbability: Double
        let successProbability: Double
        let recommendation: String
        let factors: [SuccessFactor]

        enum ReadinessLevel: String {
            case excellent = "Excellent"
            case good = "Good"
            case moderate = "Moderate"
            case low = "Low"

            var color: Color {
                switch self {
                case .excellent: return .green
                case .good: return OnLifeColors.sage
                case .moderate: return OnLifeColors.amber
                case .low: return OnLifeColors.terracotta
                }
            }

            var icon: String {
                switch self {
                case .excellent: return "brain.head.profile"
                case .good: return "brain"
                case .moderate: return "cloud.sun"
                case .low: return "cloud"
                }
            }

            var emoji: String {
                switch self {
                case .excellent: return "🔥"
                case .good: return "✨"
                case .moderate: return "💪"
                case .low: return "🌱"
                }
            }
        }
    }
}
