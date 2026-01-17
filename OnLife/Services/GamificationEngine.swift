import Foundation

// MARK: - Research Citations
/*
 Variable Reward Gamification Engine

 Research Foundation:

 1. Skinner BF (1957) "Schedules of Reinforcement"
    - Variable ratio schedules produce highest response persistence
    - Optimal bonus rate: ~20% for sustained engagement
    - Unpredictable rewards resist extinction better than fixed schedules

 2. Duolingo Research (2018-2022)
    - Streak freezes reduce quit rate by 40% after missed days
    - Users with 7+ day streaks have 3× higher long-term retention
    - "Soft" streak systems outperform "hard" streaks for retention

 3. Clear J (2018) "Atomic Habits"
    - Identity-based habits 2-3× more effective than outcome-based
    - "I am someone who focuses" > "I want to focus more"
    - Milestone language should reinforce identity shift

 4. Eyal N (2014) "Hooked: How to Build Habit-Forming Products"
    - Variable rewards create anticipation/engagement loop
    - Three types: Rewards of the tribe, hunt, and self
    - Investment increases commitment and future engagement

 5. Industry Benchmarks (Adjust, AppsFlyer 2023)
    - Average Day 30 retention: 7%
    - Top quartile Day 30 retention: 15%+
    - Gamified apps show 2-3× retention vs non-gamified

 Design Principles:
 - Variable ratio > fixed ratio for persistence
 - Protect streaks to prevent quit cascades
 - Identity progression > points accumulation
 - Rare drops create "stories" users share
*/

// MARK: - Reward Types

/// Types of rewards that can be earned
enum RewardType: Codable {
    case lifeOrbs(amount: Int)
    case bonusMultiplier(multiplier: Double)
    case rarePlant(plantId: String)
    case achievement(achievementId: String)
    case streakFreeze
    case identityMilestone(title: String)

    // Custom coding for enum with associated values
    private enum CodingKeys: String, CodingKey {
        case type, amount, multiplier, plantId, achievementId, title
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .lifeOrbs(let amount):
            try container.encode("lifeOrbs", forKey: .type)
            try container.encode(amount, forKey: .amount)
        case .bonusMultiplier(let multiplier):
            try container.encode("bonusMultiplier", forKey: .type)
            try container.encode(multiplier, forKey: .multiplier)
        case .rarePlant(let plantId):
            try container.encode("rarePlant", forKey: .type)
            try container.encode(plantId, forKey: .plantId)
        case .achievement(let achievementId):
            try container.encode("achievement", forKey: .type)
            try container.encode(achievementId, forKey: .achievementId)
        case .streakFreeze:
            try container.encode("streakFreeze", forKey: .type)
        case .identityMilestone(let title):
            try container.encode("identityMilestone", forKey: .type)
            try container.encode(title, forKey: .title)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "lifeOrbs":
            let amount = try container.decode(Int.self, forKey: .amount)
            self = .lifeOrbs(amount: amount)
        case "bonusMultiplier":
            let multiplier = try container.decode(Double.self, forKey: .multiplier)
            self = .bonusMultiplier(multiplier: multiplier)
        case "rarePlant":
            let plantId = try container.decode(String.self, forKey: .plantId)
            self = .rarePlant(plantId: plantId)
        case "achievement":
            let achievementId = try container.decode(String.self, forKey: .achievementId)
            self = .achievement(achievementId: achievementId)
        case "streakFreeze":
            self = .streakFreeze
        case "identityMilestone":
            let title = try container.decode(String.self, forKey: .title)
            self = .identityMilestone(title: title)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown reward type")
        }
    }
}

// MARK: - Rare Plants

/// Collectible rare plants with tiered rarity
enum RarePlant: String, Codable, CaseIterable {
    case goldenOak = "Golden Oak"
    case crystalLotus = "Crystal Lotus"
    case moonflower = "Moonflower"
    case stardustFern = "Stardust Fern"
    case ancientSequoia = "Ancient Sequoia"
    case phoenixBloom = "Phoenix Bloom"
    case voidOrchid = "Void Orchid"
    case timelessBonsai = "Timeless Bonsai"

    var rarity: Rarity {
        switch self {
        case .goldenOak, .crystalLotus:
            return .rare
        case .moonflower, .stardustFern:
            return .epic
        case .ancientSequoia, .phoenixBloom:
            return .legendary
        case .voidOrchid, .timelessBonsai:
            return .mythic
        }
    }

    var description: String {
        switch self {
        case .goldenOak:
            return "A tree that gleams with inner light, representing steady growth."
        case .crystalLotus:
            return "Blooms only in moments of perfect clarity."
        case .moonflower:
            return "Said to bloom when focus aligns with lunar cycles."
        case .stardustFern:
            return "Its fronds sparkle with concentrated attention."
        case .ancientSequoia:
            return "Millennia of wisdom in a single seed."
        case .phoenixBloom:
            return "Rises from the ashes of distraction."
        case .voidOrchid:
            return "Exists in the space between thoughts."
        case .timelessBonsai:
            return "A master's lifetime of focus, miniaturized."
        }
    }

    enum Rarity: String, Codable {
        case rare = "Rare"           // 2% base drop
        case epic = "Epic"           // 0.5% base drop
        case legendary = "Legendary" // 0.1% base drop
        case mythic = "Mythic"       // 0.01% base drop

        var dropChance: Double {
            switch self {
            case .rare: return 0.02
            case .epic: return 0.005
            case .legendary: return 0.001
            case .mythic: return 0.0001
            }
        }

        var color: String {
            switch self {
            case .rare: return "blue"
            case .epic: return "purple"
            case .legendary: return "orange"
            case .mythic: return "red"
            }
        }
    }
}

// MARK: - Achievements

/// Achievement milestones
enum Achievement: String, Codable, CaseIterable {
    // Session milestones
    case firstSession = "First Seed"
    case tenSessions = "Sprout Keeper"
    case fiftySessions = "Grove Tender"
    case hundredSessions = "Garden Master"
    case fiveHundredSessions = "Forest Guardian"
    case thousandSessions = "Nature's Sage"

    // Streak milestones
    case weekStreak = "Week Warrior"
    case twoWeekStreak = "Fortnight Focus"
    case monthStreak = "Month Champion"
    case quarterStreak = "Season Master"
    case yearStreak = "Year Legend"

    // Flow milestones
    case firstDeepFlow = "Flow State Unlocked"
    case tenDeepFlows = "Flow Seeker"
    case fiftyDeepFlows = "Flow Master"
    case hundredDeepFlows = "Flow Legend"

    // Time milestones
    case tenHours = "Decade of Focus"
    case fiftyHours = "Half-Century"
    case hundredHours = "Century Cultivator"
    case fiveHundredHours = "Time Weaver"

    // Special achievements
    case earlyBird = "Early Bird"           // 5 AM session
    case nightOwl = "Night Owl"             // 11 PM session
    case weekendWarrior = "Weekend Warrior" // Sessions on 4 consecutive weekends
    case perfectWeek = "Perfect Week"       // Daily goal met 7 days straight
    case comeback = "The Comeback"          // Return after 7+ day break

    var title: String { rawValue }

    var description: String {
        switch self {
        case .firstSession: return "Plant your first seed of focus"
        case .tenSessions: return "Complete 10 focus sessions"
        case .fiftySessions: return "Complete 50 focus sessions"
        case .hundredSessions: return "Complete 100 focus sessions"
        case .fiveHundredSessions: return "Complete 500 focus sessions"
        case .thousandSessions: return "Complete 1000 focus sessions"
        case .weekStreak: return "Maintain a 7-day streak"
        case .twoWeekStreak: return "Maintain a 14-day streak"
        case .monthStreak: return "Maintain a 30-day streak"
        case .quarterStreak: return "Maintain a 90-day streak"
        case .yearStreak: return "Maintain a 365-day streak"
        case .firstDeepFlow: return "Achieve your first deep flow state"
        case .tenDeepFlows: return "Achieve 10 deep flow states"
        case .fiftyDeepFlows: return "Achieve 50 deep flow states"
        case .hundredDeepFlows: return "Achieve 100 deep flow states"
        case .tenHours: return "Accumulate 10 hours of focus"
        case .fiftyHours: return "Accumulate 50 hours of focus"
        case .hundredHours: return "Accumulate 100 hours of focus"
        case .fiveHundredHours: return "Accumulate 500 hours of focus"
        case .earlyBird: return "Complete a session before 6 AM"
        case .nightOwl: return "Complete a session after 11 PM"
        case .weekendWarrior: return "Focus on 4 consecutive weekends"
        case .perfectWeek: return "Meet daily goal 7 days in a row"
        case .comeback: return "Return after a week away"
        }
    }

    var orbReward: Int {
        switch self {
        case .firstSession: return 50
        case .tenSessions: return 100
        case .fiftySessions: return 250
        case .hundredSessions: return 500
        case .fiveHundredSessions: return 1000
        case .thousandSessions: return 2500
        case .weekStreak: return 100
        case .twoWeekStreak: return 200
        case .monthStreak: return 500
        case .quarterStreak: return 1500
        case .yearStreak: return 5000
        case .firstDeepFlow: return 75
        case .tenDeepFlows: return 200
        case .fiftyDeepFlows: return 500
        case .hundredDeepFlows: return 1000
        case .tenHours: return 150
        case .fiftyHours: return 400
        case .hundredHours: return 800
        case .fiveHundredHours: return 2000
        case .earlyBird, .nightOwl: return 50
        case .weekendWarrior: return 150
        case .perfectWeek: return 200
        case .comeback: return 100
        }
    }
}

// MARK: - User Gamification Stats

/// Persistent user gamification state
struct UserGamificationStats: Codable {
    var totalSessions: Int = 0
    var sessionsToday: Int = 0
    var dailyGoal: Int = 3
    var dailyGoalMetToday: Bool = false
    var dailyGoalStreakDays: Int = 0

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastSessionDate: Date?
    var lastActiveDate: Date?

    var totalLifeOrbs: Int = 0
    var totalFocusSeconds: TimeInterval = 0

    var deepFlowCount: Int = 0
    var consecutiveWeekends: Int = 0
    var lastWeekendSession: Date?

    var freezesRemaining: Int = 2
    var lastFreezeReset: Date?

    var unlockedAchievements: Set<String> = []
    var unlockedPlants: Set<String> = []
    var identityLevel: Int = 0
    var identityTitle: String = "Beginner"

    /// Total focus hours
    var totalFocusHours: Double {
        return totalFocusSeconds / 3600
    }
}

// MARK: - Reward Result

/// Result of a session reward calculation
struct RewardResult {
    let baseReward: Int
    let bonusReward: Int
    let specialRewards: [RewardType]
    let totalOrbs: Int
    let showCelebration: Bool
    let celebrationMessage: String?
    let celebrationType: CelebrationType

    enum CelebrationType {
        case none
        case bonus
        case rareDrop
        case achievement
        case milestone
        case legendary
    }
}

// MARK: - Streak Result

/// Result of a streak update
struct StreakResult {
    let currentStreak: Int
    let longestStreak: Int
    let bonusOrbs: Int
    let freezeUsed: Bool
    let freezesRemaining: Int
    let message: String?
    let streakBroken: Bool
}

// MARK: - Identity Milestone

/// Identity-based progression milestones (James Clear research)
struct IdentityMilestone {
    let sessions: Int
    let title: String
    let message: String
    let level: Int

    /// Identity milestones emphasize WHO you are becoming, not WHAT you've done
    static let milestones: [IdentityMilestone] = [
        IdentityMilestone(
            sessions: 1,
            title: "Seeker",
            message: "You've taken the first step. Every master was once a beginner.",
            level: 1
        ),
        IdentityMilestone(
            sessions: 10,
            title: "Focus Apprentice",
            message: "You're building the habit of focused work. This is how change begins.",
            level: 2
        ),
        IdentityMilestone(
            sessions: 30,
            title: "Garden Keeper",
            message: "You're becoming someone who values deep focus. Your garden grows.",
            level: 3
        ),
        IdentityMilestone(
            sessions: 75,
            title: "Grove Tender",
            message: "Focus is becoming natural to you. Others notice your dedication.",
            level: 4
        ),
        IdentityMilestone(
            sessions: 150,
            title: "Flow Cultivator",
            message: "Deep work is now part of your identity. You seek flow naturally.",
            level: 5
        ),
        IdentityMilestone(
            sessions: 300,
            title: "Forest Guardian",
            message: "You ARE a focused person. This is who you are now.",
            level: 6
        ),
        IdentityMilestone(
            sessions: 500,
            title: "Nature's Sage",
            message: "Your focus inspires others. You've mastered the art of presence.",
            level: 7
        ),
        IdentityMilestone(
            sessions: 1000,
            title: "Timeless One",
            message: "You have transcended distraction. Focus flows through you effortlessly.",
            level: 8
        )
    ]
}

// MARK: - Gamification Engine

/// Research-based gamification engine using variable reward schedules
/// Implements Skinner's variable ratio principles for optimal engagement
class GamificationEngine {

    static let shared = GamificationEngine()

    // MARK: - Reward Schedule Constants (Skinner Research)

    /// Base orbs per completed session
    private let baseSessionOrbs = 10

    /// Bonus for meeting daily goal
    private let dailyGoalBonus = 25

    /// Weekly streak milestone bonus
    private let weeklyStreakBonus = 50

    /// Variable bonus trigger rate (Skinner: ~20% optimal)
    private let variableBonusChance: Double = 0.20

    /// Possible bonus multipliers (weighted toward lower)
    private let bonusMultipliers: [(multiplier: Double, weight: Double)] = [
        (1.5, 0.40),  // 40% of bonuses
        (2.0, 0.30),  // 30% of bonuses
        (2.5, 0.15),  // 15% of bonuses
        (3.0, 0.10),  // 10% of bonuses
        (5.0, 0.05)   // 5% of bonuses (jackpot!)
    ]

    /// Flow quality bonuses
    private let deepFlowBonus = 15      // Flow score >= 80
    private let moderateFlowBonus = 8   // Flow score >= 65
    private let lightFlowBonus = 3      // Flow score >= 50

    // MARK: - Soft Streak System (Duolingo Research)

    /// Free misses before streak breaks
    private let freezesPerMonth = 2

    /// Minimum streak to auto-apply freeze
    private let freezeProtectionThreshold = 7

    /// Grace period for same-day catch-up (hours)
    private let gracePeriodHours = 4

    // MARK: - State

    private(set) var stats: UserGamificationStats

    // MARK: - Initialization

    init(stats: UserGamificationStats = UserGamificationStats()) {
        self.stats = stats
    }

    /// Load stats from storage
    func loadStats(_ stats: UserGamificationStats) {
        self.stats = stats
    }

    // MARK: - Session Reward Calculation

    /// Calculate rewards for a completed session
    /// Uses variable ratio schedule for optimal engagement
    func calculateSessionReward(
        sessionDuration: TimeInterval,
        flowScore: Double,
        completed: Bool,
        timestamp: Date = Date()
    ) -> RewardResult {

        var totalOrbs = 0
        var bonusOrbs = 0
        var specialRewards: [RewardType] = []
        var showCelebration = false
        var celebrationMessage: String? = nil
        var celebrationType: RewardResult.CelebrationType = .none

        // === BASE REWARD ===
        if completed {
            totalOrbs += baseSessionOrbs
        } else {
            // Partial credit encourages completion attempts
            let completionRatio = min(1.0, sessionDuration / (25 * 60))
            let partialCredit = Int(Double(baseSessionOrbs) * completionRatio)
            totalOrbs += max(1, partialCredit)
        }

        // === FLOW QUALITY BONUS ===
        if flowScore >= 80 {
            totalOrbs += deepFlowBonus
            specialRewards.append(.lifeOrbs(amount: deepFlowBonus))
            stats.deepFlowCount += 1
        } else if flowScore >= 65 {
            totalOrbs += moderateFlowBonus
        } else if flowScore >= 50 {
            totalOrbs += lightFlowBonus
        }

        // === VARIABLE BONUS (Skinner's Optimal Schedule) ===
        if Double.random(in: 0...1) < variableBonusChance {
            let multiplier = selectWeightedMultiplier()
            bonusOrbs = Int(Double(baseSessionOrbs) * multiplier) - baseSessionOrbs
            totalOrbs += bonusOrbs
            specialRewards.append(.bonusMultiplier(multiplier: multiplier))
            showCelebration = true
            celebrationMessage = multiplier >= 3.0 ?
                "JACKPOT! \(multiplier)× orbs!" :
                "Bonus! \(multiplier)× orbs!"
            celebrationType = multiplier >= 3.0 ? .legendary : .bonus
        }

        // === RARE DROP ROLL ===
        if let plantDrop = rollForRarePlant() {
            specialRewards.append(.rarePlant(plantId: plantDrop.rawValue))
            stats.unlockedPlants.insert(plantDrop.rawValue)
            showCelebration = true

            switch plantDrop.rarity {
            case .mythic:
                celebrationMessage = "MYTHIC! You discovered \(plantDrop.rawValue)!"
                celebrationType = .legendary
            case .legendary:
                celebrationMessage = "LEGENDARY! You found \(plantDrop.rawValue)!"
                celebrationType = .legendary
            case .epic:
                celebrationMessage = "Epic find: \(plantDrop.rawValue)!"
                celebrationType = .rareDrop
            case .rare:
                celebrationMessage = "Rare plant: \(plantDrop.rawValue)!"
                celebrationType = .rareDrop
            }
        }

        // === UPDATE SESSION STATS ===
        stats.sessionsToday += 1
        stats.totalSessions += 1
        stats.totalFocusSeconds += sessionDuration
        stats.lastSessionDate = timestamp

        // === DAILY GOAL CHECK ===
        if stats.sessionsToday >= stats.dailyGoal && !stats.dailyGoalMetToday {
            stats.dailyGoalMetToday = true
            stats.dailyGoalStreakDays += 1
            totalOrbs += dailyGoalBonus
            specialRewards.append(.lifeOrbs(amount: dailyGoalBonus))

            if celebrationType == .none {
                showCelebration = true
                celebrationMessage = "Daily goal reached! +\(dailyGoalBonus) orbs"
                celebrationType = .bonus
            }
        }

        // === ACHIEVEMENT CHECKS ===
        let newAchievements = checkAchievements(flowScore: flowScore, timestamp: timestamp)
        for achievement in newAchievements {
            specialRewards.append(.achievement(achievementId: achievement.rawValue))
            totalOrbs += achievement.orbReward

            if celebrationType.priority < RewardResult.CelebrationType.achievement.priority {
                showCelebration = true
                celebrationMessage = "Achievement: \(achievement.title)!"
                celebrationType = .achievement
            }
        }

        // === IDENTITY MILESTONE CHECK ===
        if let milestone = checkIdentityMilestone() {
            specialRewards.append(.identityMilestone(title: milestone.title))
            stats.identityLevel = milestone.level
            stats.identityTitle = milestone.title

            showCelebration = true
            celebrationMessage = milestone.message
            celebrationType = .milestone
        }

        // === UPDATE TOTAL ORBS ===
        stats.totalLifeOrbs += totalOrbs

        print("🎮 [Gamification] Session reward: \(totalOrbs) orbs (base: \(baseSessionOrbs), bonus: \(bonusOrbs))")

        return RewardResult(
            baseReward: baseSessionOrbs,
            bonusReward: bonusOrbs,
            specialRewards: specialRewards,
            totalOrbs: totalOrbs,
            showCelebration: showCelebration,
            celebrationMessage: celebrationMessage,
            celebrationType: celebrationType
        )
    }

    // MARK: - Variable Reward Selection

    /// Select bonus multiplier using weighted random selection
    private func selectWeightedMultiplier() -> Double {
        let totalWeight = bonusMultipliers.reduce(0) { $0 + $1.weight }
        var random = Double.random(in: 0..<totalWeight)

        for (multiplier, weight) in bonusMultipliers {
            random -= weight
            if random <= 0 {
                return multiplier
            }
        }

        return bonusMultipliers.first?.multiplier ?? 1.5
    }

    /// Roll for rare plant drop
    private func rollForRarePlant() -> RarePlant? {
        let roll = Double.random(in: 0...1)

        // Check each rarity tier
        for rarity in [RarePlant.Rarity.mythic, .legendary, .epic, .rare] {
            if roll < rarity.dropChance {
                let plantsOfRarity = RarePlant.allCases.filter { $0.rarity == rarity }
                return plantsOfRarity.randomElement()
            }
        }

        return nil
    }

    // MARK: - Streak Management (Soft Streak System)

    /// Update streak based on daily activity
    /// Implements Duolingo's soft streak system
    func updateStreak(completedToday: Bool, date: Date = Date()) -> StreakResult {
        let calendar = Calendar.current

        // Check if this is a new day
        if let lastActive = stats.lastActiveDate {
            let daysSinceActive = calendar.dateComponents([.day], from: lastActive, to: date).day ?? 0

            if daysSinceActive == 0 {
                // Same day - no streak change needed
                return StreakResult(
                    currentStreak: stats.currentStreak,
                    longestStreak: stats.longestStreak,
                    bonusOrbs: 0,
                    freezeUsed: false,
                    freezesRemaining: stats.freezesRemaining,
                    message: nil,
                    streakBroken: false
                )
            } else if daysSinceActive > 1 && !completedToday {
                // Missed day(s) - check for freeze protection
                return handleMissedDay(daysMissed: daysSinceActive - 1, date: date)
            }
        }

        if completedToday {
            stats.currentStreak += 1
            stats.longestStreak = max(stats.longestStreak, stats.currentStreak)
            stats.lastActiveDate = date

            // Weekly streak bonus
            var weeklyBonus = 0
            if stats.currentStreak % 7 == 0 {
                weeklyBonus = weeklyStreakBonus
                stats.totalLifeOrbs += weeklyBonus
            }

            return StreakResult(
                currentStreak: stats.currentStreak,
                longestStreak: stats.longestStreak,
                bonusOrbs: weeklyBonus,
                freezeUsed: false,
                freezesRemaining: stats.freezesRemaining,
                message: weeklyBonus > 0 ? "Week \(stats.currentStreak / 7) complete! +\(weeklyBonus) orbs" : nil,
                streakBroken: false
            )
        }

        return StreakResult(
            currentStreak: stats.currentStreak,
            longestStreak: stats.longestStreak,
            bonusOrbs: 0,
            freezeUsed: false,
            freezesRemaining: stats.freezesRemaining,
            message: nil,
            streakBroken: false
        )
    }

    /// Handle missed day with potential freeze protection
    private func handleMissedDay(daysMissed: Int, date: Date) -> StreakResult {
        // Auto-freeze for protected streaks
        if stats.currentStreak >= freezeProtectionThreshold && stats.freezesRemaining > 0 && daysMissed == 1 {
            stats.freezesRemaining -= 1
            stats.lastActiveDate = date

            return StreakResult(
                currentStreak: stats.currentStreak,
                longestStreak: stats.longestStreak,
                bonusOrbs: 0,
                freezeUsed: true,
                freezesRemaining: stats.freezesRemaining,
                message: "Streak protected! \(stats.freezesRemaining) freeze\(stats.freezesRemaining == 1 ? "" : "s") left this month.",
                streakBroken: false
            )
        }

        // Streak breaks
        let previousStreak = stats.currentStreak
        stats.currentStreak = 0
        stats.dailyGoalStreakDays = 0
        stats.lastActiveDate = date

        // Check for comeback achievement opportunity
        let message: String?
        if previousStreak > 0 {
            message = "Streak ended at \(previousStreak) days. Every new beginning is a chance to grow."
        } else {
            message = nil
        }

        return StreakResult(
            currentStreak: 0,
            longestStreak: stats.longestStreak,
            bonusOrbs: 0,
            freezeUsed: false,
            freezesRemaining: stats.freezesRemaining,
            message: message,
            streakBroken: previousStreak > 0
        )
    }

    // MARK: - Achievement Checks

    /// Check for newly earned achievements
    private func checkAchievements(flowScore: Double, timestamp: Date) -> [Achievement] {
        var newAchievements: [Achievement] = []

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)

        // Session count achievements
        let sessionAchievements: [(count: Int, achievement: Achievement)] = [
            (1, .firstSession),
            (10, .tenSessions),
            (50, .fiftySessions),
            (100, .hundredSessions),
            (500, .fiveHundredSessions),
            (1000, .thousandSessions)
        ]

        for (count, achievement) in sessionAchievements {
            if stats.totalSessions == count && !stats.unlockedAchievements.contains(achievement.rawValue) {
                stats.unlockedAchievements.insert(achievement.rawValue)
                newAchievements.append(achievement)
            }
        }

        // Streak achievements
        let streakAchievements: [(days: Int, achievement: Achievement)] = [
            (7, .weekStreak),
            (14, .twoWeekStreak),
            (30, .monthStreak),
            (90, .quarterStreak),
            (365, .yearStreak)
        ]

        for (days, achievement) in streakAchievements {
            if stats.currentStreak == days && !stats.unlockedAchievements.contains(achievement.rawValue) {
                stats.unlockedAchievements.insert(achievement.rawValue)
                newAchievements.append(achievement)
            }
        }

        // Flow achievements
        if flowScore >= 80 {
            let flowAchievements: [(count: Int, achievement: Achievement)] = [
                (1, .firstDeepFlow),
                (10, .tenDeepFlows),
                (50, .fiftyDeepFlows),
                (100, .hundredDeepFlows)
            ]

            for (count, achievement) in flowAchievements {
                if stats.deepFlowCount == count && !stats.unlockedAchievements.contains(achievement.rawValue) {
                    stats.unlockedAchievements.insert(achievement.rawValue)
                    newAchievements.append(achievement)
                }
            }
        }

        // Time achievements
        let timeAchievements: [(hours: Double, achievement: Achievement)] = [
            (10, .tenHours),
            (50, .fiftyHours),
            (100, .hundredHours),
            (500, .fiveHundredHours)
        ]

        for (hours, achievement) in timeAchievements {
            if stats.totalFocusHours >= hours && !stats.unlockedAchievements.contains(achievement.rawValue) {
                stats.unlockedAchievements.insert(achievement.rawValue)
                newAchievements.append(achievement)
            }
        }

        // Special achievements
        if hour < 6 && !stats.unlockedAchievements.contains(Achievement.earlyBird.rawValue) {
            stats.unlockedAchievements.insert(Achievement.earlyBird.rawValue)
            newAchievements.append(.earlyBird)
        }

        if hour >= 23 && !stats.unlockedAchievements.contains(Achievement.nightOwl.rawValue) {
            stats.unlockedAchievements.insert(Achievement.nightOwl.rawValue)
            newAchievements.append(.nightOwl)
        }

        // Perfect week
        if stats.dailyGoalStreakDays == 7 && !stats.unlockedAchievements.contains(Achievement.perfectWeek.rawValue) {
            stats.unlockedAchievements.insert(Achievement.perfectWeek.rawValue)
            newAchievements.append(.perfectWeek)
        }

        return newAchievements
    }

    // MARK: - Identity Milestone Check

    /// Check for identity-based milestones (James Clear research)
    private func checkIdentityMilestone() -> IdentityMilestone? {
        for milestone in IdentityMilestone.milestones {
            if stats.totalSessions == milestone.sessions && stats.identityLevel < milestone.level {
                return milestone
            }
        }
        return nil
    }

    // MARK: - Monthly Reset

    /// Reset monthly freezes (call on app launch or daily check)
    func checkMonthlyReset() {
        let calendar = Calendar.current
        let now = Date()

        if let lastReset = stats.lastFreezeReset {
            let monthsSinceReset = calendar.dateComponents([.month], from: lastReset, to: now).month ?? 0
            if monthsSinceReset >= 1 {
                stats.freezesRemaining = freezesPerMonth
                stats.lastFreezeReset = now
                print("🎮 [Gamification] Monthly freeze reset: \(freezesPerMonth) freezes available")
            }
        } else {
            stats.freezesRemaining = freezesPerMonth
            stats.lastFreezeReset = now
        }
    }

    /// Reset daily stats (call at midnight)
    func resetDailyStats() {
        stats.sessionsToday = 0
        stats.dailyGoalMetToday = false
    }

    // MARK: - Utility

    /// Get current stats
    func getStats() -> UserGamificationStats {
        return stats
    }

    /// Manually use a streak freeze
    func useStreakFreeze() -> Bool {
        guard stats.freezesRemaining > 0 else { return false }
        stats.freezesRemaining -= 1
        return true
    }
}

// MARK: - Celebration Priority Extension

extension RewardResult.CelebrationType {
    var priority: Int {
        switch self {
        case .none: return 0
        case .bonus: return 1
        case .rareDrop: return 2
        case .achievement: return 3
        case .milestone: return 4
        case .legendary: return 5
        }
    }
}
