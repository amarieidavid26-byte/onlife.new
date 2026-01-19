import Foundation
import UIKit

/// Enhanced variable reward system with celebration levels
/// Works alongside GamificationEngine to provide rich visual feedback
///
/// Research basis (Skinner 1953):
/// - Variable ratio reinforcement produces highest engagement
/// - 20% probability optimal for maintaining motivation
/// - Unpredictable rewards activate dopamine 2-3x more than predictable
class VariableRewardSystem {
    static let shared = VariableRewardSystem()

    private init() {}

    // MARK: - Celebration Level

    /// Determines the intensity of celebration animation
    enum CelebrationLevel: Int, Comparable {
        case standard = 0   // Normal completion
        case bonus = 1      // 1.5x-2x multiplier
        case great = 2      // 2x-2.5x multiplier
        case epic = 3       // 2.5x-3x multiplier
        case legendary = 4  // 3x+ or 5x jackpot

        static func < (lhs: CelebrationLevel, rhs: CelebrationLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var emoji: String {
            switch self {
            case .standard: return "✨"
            case .bonus: return "🎉"
            case .great: return "⭐"
            case .epic: return "💫"
            case .legendary: return "🌟"
            }
        }

        var label: String {
            switch self {
            case .standard: return ""
            case .bonus: return "BONUS!"
            case .great: return "GREAT BONUS!"
            case .epic: return "EPIC BONUS!"
            case .legendary: return "LEGENDARY!"
            }
        }

        var confettiCount: Int {
            switch self {
            case .standard: return 0
            case .bonus: return 20
            case .great: return 35
            case .epic: return 50
            case .legendary: return 80
            }
        }

        var hapticIntensity: Int {
            switch self {
            case .standard: return 1
            case .bonus: return 2
            case .great: return 3
            case .epic: return 4
            case .legendary: return 6
            }
        }

        /// Create from multiplier value
        static func from(multiplier: Double?) -> CelebrationLevel {
            guard let mult = multiplier else { return .standard }

            switch mult {
            case 5.0...: return .legendary
            case 3.0..<5.0: return .legendary
            case 2.5..<3.0: return .epic
            case 2.0..<2.5: return .great
            case 1.5..<2.0: return .bonus
            default: return .standard
            }
        }
    }

    // MARK: - Enhanced Reward Result

    /// Enhanced result with celebration details
    struct VariableRewardResult {
        let baseOrbs: Int
        let bonusOrbs: Int
        let totalOrbs: Int
        let multiplier: Double?
        let wasBonus: Bool
        let celebrationLevel: CelebrationLevel
        let specialRewards: [RewardType]
        let celebrationMessage: String?

        /// Create from GamificationEngine RewardResult
        init(from result: RewardResult) {
            self.baseOrbs = result.baseReward
            self.bonusOrbs = result.bonusReward
            self.totalOrbs = result.totalOrbs
            self.specialRewards = result.specialRewards
            self.celebrationMessage = result.celebrationMessage

            // Extract multiplier from special rewards
            var extractedMultiplier: Double? = nil
            for reward in result.specialRewards {
                if case .bonusMultiplier(let mult) = reward {
                    extractedMultiplier = mult
                    break
                }
            }

            self.multiplier = extractedMultiplier
            self.wasBonus = extractedMultiplier != nil || result.bonusReward > 0
            self.celebrationLevel = CelebrationLevel.from(multiplier: extractedMultiplier)
        }

        /// Direct initializer for custom rewards
        init(
            baseOrbs: Int,
            bonusOrbs: Int,
            multiplier: Double?,
            specialRewards: [RewardType] = [],
            celebrationMessage: String? = nil
        ) {
            self.baseOrbs = baseOrbs
            self.bonusOrbs = bonusOrbs
            self.totalOrbs = baseOrbs + bonusOrbs
            self.multiplier = multiplier
            self.wasBonus = multiplier != nil && multiplier! > 1.0
            self.celebrationLevel = CelebrationLevel.from(multiplier: multiplier)
            self.specialRewards = specialRewards
            self.celebrationMessage = celebrationMessage
        }
    }

    // MARK: - Calculate Enhanced Reward

    /// Calculate reward with enhanced celebration tracking
    /// Wraps GamificationEngine for visual enhancements
    func calculateReward(
        sessionDuration: TimeInterval,
        flowScore: Double,
        completed: Bool
    ) -> VariableRewardResult {
        let result = GamificationEngine.shared.calculateSessionReward(
            sessionDuration: sessionDuration,
            flowScore: flowScore,
            completed: completed
        )

        return VariableRewardResult(from: result)
    }

    /// Calculate standalone bonus (for testing/preview)
    func calculateStandaloneBonus(
        baseOrbs: Int,
        flowScore: Double
    ) -> VariableRewardResult {
        // 20% chance of bonus (Skinner optimal)
        let bonusTriggered = Double.random(in: 0...1) < 0.20

        guard bonusTriggered else {
            return VariableRewardResult(
                baseOrbs: baseOrbs,
                bonusOrbs: 0,
                multiplier: nil
            )
        }

        // Calculate multiplier based on flow score
        let multiplier = calculateBonusMultiplier(flowScore: flowScore)
        let bonusOrbs = Int(Double(baseOrbs) * (multiplier - 1.0))

        return VariableRewardResult(
            baseOrbs: baseOrbs,
            bonusOrbs: bonusOrbs,
            multiplier: multiplier,
            celebrationMessage: multiplier >= 3.0 ? "JACKPOT!" : "Bonus!"
        )
    }

    /// Flow-weighted multiplier selection
    /// Higher flow scores get better multiplier distribution
    private func calculateBonusMultiplier(flowScore: Double) -> Double {
        let random = Double.random(in: 0...1)

        if flowScore >= 80 {
            // Excellent flow: better multiplier chances
            switch random {
            case 0..<0.10: return 5.0   // 10% jackpot
            case 0.10..<0.25: return 3.0  // 15% legendary
            case 0.25..<0.45: return 2.5  // 20% epic
            case 0.45..<0.70: return 2.0  // 25% great
            default: return 1.5           // 30% bonus
            }
        } else if flowScore >= 60 {
            // Good flow: moderate multipliers
            switch random {
            case 0..<0.05: return 5.0   // 5% jackpot
            case 0.05..<0.15: return 3.0  // 10% legendary
            case 0.15..<0.30: return 2.5  // 15% epic
            case 0.30..<0.55: return 2.0  // 25% great
            default: return 1.5           // 45% bonus
            }
        } else {
            // Fair flow: mostly lower multipliers
            switch random {
            case 0..<0.02: return 5.0   // 2% jackpot
            case 0.02..<0.07: return 3.0  // 5% legendary
            case 0.07..<0.17: return 2.5  // 10% epic
            case 0.17..<0.37: return 2.0  // 20% great
            default: return 1.5           // 63% bonus
            }
        }
    }

    // MARK: - Haptic Feedback

    /// Trigger celebration haptics based on level
    func triggerCelebrationHaptics(level: CelebrationLevel) {
        let count = level.hapticIntensity

        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                HapticManager.shared.notification(type: .success)
            }
        }

        // Extra heavy impact for legendary
        if level == .legendary {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(count) * 0.08 + 0.1) {
                HapticManager.shared.impact(style: .heavy)
            }
        }
    }
}
