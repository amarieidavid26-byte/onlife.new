import Foundation
import FirebaseFirestore

// MARK: - Chronotype

enum Chronotype: String, Codable, CaseIterable {
    case earlyBird = "Early Bird"
    case nightOwl = "Night Owl"
    case flexible = "Flexible"

    var icon: String {
        switch self {
        case .earlyBird: return "sunrise.fill"
        case .nightOwl: return "moon.stars.fill"
        case .flexible: return "clock.fill"
        }
    }

    var emoji: String {
        switch self {
        case .earlyBird: return "🌅"
        case .nightOwl: return "🌙"
        case .flexible: return "⚖️"
        }
    }

    var peakDescription: String {
        switch self {
        case .earlyBird: return "Morning sessions (6am - 12pm)"
        case .nightOwl: return "Evening sessions (6pm - 2am)"
        case .flexible: return "Adaptable to any time"
        }
    }
}

// MARK: - Time Window

struct TimeWindow: Codable, Hashable {
    let startHour: Int  // 0-23
    let endHour: Int

    var displayString: String {
        let start = formatHour(startHour)
        let end = formatHour(endHour)
        return "\(start) - \(end)"
    }

    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "am" : "pm"
        return "\(h)\(period)"
    }
}

// MARK: - Skill Badge

struct SkillBadge: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let earnedDate: Date
    let category: BadgeCategory

    enum BadgeCategory: String, Codable, CaseIterable {
        case initiation = "Flow Initiation"
        case depth = "Flow Depth"
        case consistency = "Consistency"
        case optimization = "Optimization"
        case mastery = "Mastery"

        var icon: String {
            switch self {
            case .initiation: return "bolt.fill"
            case .depth: return "waveform.path"
            case .consistency: return "calendar.badge.checkmark"
            case .optimization: return "slider.horizontal.3"
            case .mastery: return "star.fill"
            }
        }
    }
}

// MARK: - Garden Visibility

enum GardenVisibility: String, Codable, CaseIterable {
    case privateOnly = "private"
    case friendsOnly = "friends"
    case publicVisible = "public"

    var displayName: String {
        switch self {
        case .privateOnly: return "Private"
        case .friendsOnly: return "Friends Only"
        case .publicVisible: return "Public"
        }
    }

    var description: String {
        switch self {
        case .privateOnly: return "Only you can see your garden"
        case .friendsOnly: return "Friends can see your garden"
        case .publicVisible: return "Anyone with the link can view"
        }
    }

    var icon: String {
        switch self {
        case .privateOnly: return "lock.fill"
        case .friendsOnly: return "person.2.fill"
        case .publicVisible: return "globe"
        }
    }
}

// MARK: - Connection Counts

struct ConnectionCounts: Codable {
    var observers: Int = 0
    var friends: Int = 0
    var flowPartners: Int = 0
    var mentors: Int = 0
    var mentees: Int = 0

    var total: Int {
        observers + friends + flowPartners + mentors + mentees
    }
}

// MARK: - Comparison Mode

enum ComparisonMode: String, Codable, CaseIterable {
    case inspiration = "inspiration"
    case competition = "competition"

    var displayName: String {
        switch self {
        case .inspiration: return "Inspiration"
        case .competition: return "Competition"
        }
    }

    var description: String {
        switch self {
        case .inspiration:
            return "Shows learning trajectories and strategies you could adopt"
        case .competition:
            return "Direct metric comparison and rankings"
        }
    }

    var icon: String {
        switch self {
        case .inspiration: return "lightbulb.fill"
        case .competition: return "trophy.fill"
        }
    }

    var isRecommended: Bool {
        self == .inspiration
    }
}

// MARK: - User Profile

struct UserProfile: Codable, Identifiable {
    // Identity
    let id: String  // Firebase UID
    var username: String
    var displayName: String
    var bio: String  // 140 char max
    var profileImageURL: String?

    // Flow Portrait (auto-generated from sessions)
    var chronotype: Chronotype
    var peakFlowWindows: [TimeWindow]
    var masteryDurationDays: Int  // days since first session
    var gardenAgeDays: Int

    // Stats
    var thirtyDayTrajectory: Double  // percentage improvement
    var consistencyPercentile: Int  // 0-100
    var totalPlantsGrown: Int
    var speciesUnlocked: Int

    // Social
    var connectionCounts: ConnectionCounts
    var gardenVisibility: GardenVisibility

    // Current Focus
    var currentIntention: String?
    var currentProtocolId: String?

    // Achievements
    var skillBadges: [SkillBadge]

    // Settings
    var comparisonMode: ComparisonMode
    var philosophyMomentsEnabled: Bool

    // Social Onboarding
    var socialOnboardingCompleted: Bool
    var socialOnboardingCompletedAt: Date?

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    var experienceLevel: ExperienceLevel {
        switch masteryDurationDays {
        case 0..<30: return .beginner
        case 30..<90: return .developing
        case 90..<180: return .intermediate
        case 180..<365: return .advanced
        default: return .expert
        }
    }

    var experienceLevelDescription: String {
        experienceLevel.description
    }

    var trajectoryDescription: String {
        if thirtyDayTrajectory > 0 {
            return "+\(Int(thirtyDayTrajectory))% improvement"
        } else if thirtyDayTrajectory < 0 {
            return "\(Int(thirtyDayTrajectory))% change"
        } else {
            return "Steady progress"
        }
    }

    enum ExperienceLevel: String, Codable {
        case beginner
        case developing
        case intermediate
        case advanced
        case expert

        var description: String {
            switch self {
            case .beginner: return "Beginner (< 1 month)"
            case .developing: return "Developing (1-3 months)"
            case .intermediate: return "Intermediate (3-6 months)"
            case .advanced: return "Advanced (6-12 months)"
            case .expert: return "Expert (1+ years)"
            }
        }

        var icon: String {
            switch self {
            case .beginner: return "leaf"
            case .developing: return "leaf.fill"
            case .intermediate: return "tree"
            case .advanced: return "tree.fill"
            case .expert: return "crown.fill"
            }
        }
    }

    // MARK: - Initializer

    init(
        id: String,
        username: String,
        displayName: String,
        bio: String = "",
        profileImageURL: String? = nil,
        chronotype: Chronotype = .flexible,
        peakFlowWindows: [TimeWindow] = [],
        masteryDurationDays: Int = 0,
        gardenAgeDays: Int = 0,
        thirtyDayTrajectory: Double = 0,
        consistencyPercentile: Int = 50,
        totalPlantsGrown: Int = 0,
        speciesUnlocked: Int = 0,
        connectionCounts: ConnectionCounts = ConnectionCounts(),
        gardenVisibility: GardenVisibility = .friendsOnly,
        currentIntention: String? = nil,
        currentProtocolId: String? = nil,
        skillBadges: [SkillBadge] = [],
        comparisonMode: ComparisonMode = .inspiration,
        philosophyMomentsEnabled: Bool = true,
        socialOnboardingCompleted: Bool = false,
        socialOnboardingCompletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.chronotype = chronotype
        self.peakFlowWindows = peakFlowWindows
        self.masteryDurationDays = masteryDurationDays
        self.gardenAgeDays = gardenAgeDays
        self.thirtyDayTrajectory = thirtyDayTrajectory
        self.consistencyPercentile = consistencyPercentile
        self.totalPlantsGrown = totalPlantsGrown
        self.speciesUnlocked = speciesUnlocked
        self.connectionCounts = connectionCounts
        self.gardenVisibility = gardenVisibility
        self.currentIntention = currentIntention
        self.currentProtocolId = currentProtocolId
        self.skillBadges = skillBadges
        self.comparisonMode = comparisonMode
        self.philosophyMomentsEnabled = philosophyMomentsEnabled
        self.socialOnboardingCompleted = socialOnboardingCompleted
        self.socialOnboardingCompletedAt = socialOnboardingCompletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Firebase Extension

extension UserProfile {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.username = data["username"] as? String ?? ""
        self.displayName = data["displayName"] as? String ?? ""
        self.bio = data["bio"] as? String ?? ""
        self.profileImageURL = data["profileImageURL"] as? String

        // Decode chronotype
        if let chronotypeRaw = data["chronotype"] as? String {
            self.chronotype = Chronotype(rawValue: chronotypeRaw) ?? .flexible
        } else {
            self.chronotype = .flexible
        }

        // Decode peak windows
        if let windowsData = data["peakFlowWindows"] as? [[String: Int]] {
            self.peakFlowWindows = windowsData.compactMap { dict in
                guard let start = dict["startHour"], let end = dict["endHour"] else { return nil }
                return TimeWindow(startHour: start, endHour: end)
            }
        } else {
            self.peakFlowWindows = []
        }

        self.masteryDurationDays = data["masteryDurationDays"] as? Int ?? 0
        self.gardenAgeDays = data["gardenAgeDays"] as? Int ?? 0
        self.thirtyDayTrajectory = data["thirtyDayTrajectory"] as? Double ?? 0
        self.consistencyPercentile = data["consistencyPercentile"] as? Int ?? 50
        self.totalPlantsGrown = data["totalPlantsGrown"] as? Int ?? 0
        self.speciesUnlocked = data["speciesUnlocked"] as? Int ?? 0

        // Connection counts
        if let counts = data["connectionCounts"] as? [String: Int] {
            self.connectionCounts = ConnectionCounts(
                observers: counts["observers"] ?? 0,
                friends: counts["friends"] ?? 0,
                flowPartners: counts["flowPartners"] ?? 0,
                mentors: counts["mentors"] ?? 0,
                mentees: counts["mentees"] ?? 0
            )
        } else {
            self.connectionCounts = ConnectionCounts()
        }

        // Visibility
        if let visibilityRaw = data["gardenVisibility"] as? String {
            self.gardenVisibility = GardenVisibility(rawValue: visibilityRaw) ?? .friendsOnly
        } else {
            self.gardenVisibility = .friendsOnly
        }

        self.currentIntention = data["currentIntention"] as? String
        self.currentProtocolId = data["currentProtocolId"] as? String

        // Badges - simplified for now
        self.skillBadges = []

        // Comparison mode
        if let modeRaw = data["comparisonMode"] as? String {
            self.comparisonMode = ComparisonMode(rawValue: modeRaw) ?? .inspiration
        } else {
            self.comparisonMode = .inspiration
        }

        self.philosophyMomentsEnabled = data["philosophyMomentsEnabled"] as? Bool ?? true

        // Social onboarding
        self.socialOnboardingCompleted = data["socialOnboardingCompleted"] as? Bool ?? false
        if let timestamp = data["socialOnboardingCompletedAt"] as? Timestamp {
            self.socialOnboardingCompletedAt = timestamp.dateValue()
        } else {
            self.socialOnboardingCompletedAt = nil
        }

        // Timestamps
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        if let timestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = Date()
        }
    }

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "username": username,
            "displayName": displayName,
            "bio": bio,
            "chronotype": chronotype.rawValue,
            "peakFlowWindows": peakFlowWindows.map { ["startHour": $0.startHour, "endHour": $0.endHour] },
            "masteryDurationDays": masteryDurationDays,
            "gardenAgeDays": gardenAgeDays,
            "thirtyDayTrajectory": thirtyDayTrajectory,
            "consistencyPercentile": consistencyPercentile,
            "totalPlantsGrown": totalPlantsGrown,
            "speciesUnlocked": speciesUnlocked,
            "connectionCounts": [
                "observers": connectionCounts.observers,
                "friends": connectionCounts.friends,
                "flowPartners": connectionCounts.flowPartners,
                "mentors": connectionCounts.mentors,
                "mentees": connectionCounts.mentees
            ],
            "gardenVisibility": gardenVisibility.rawValue,
            "comparisonMode": comparisonMode.rawValue,
            "philosophyMomentsEnabled": philosophyMomentsEnabled,
            "socialOnboardingCompleted": socialOnboardingCompleted,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: Date())
        ]

        if let profileImageURL = profileImageURL {
            data["profileImageURL"] = profileImageURL
        }
        if let currentIntention = currentIntention {
            data["currentIntention"] = currentIntention
        }
        if let currentProtocolId = currentProtocolId {
            data["currentProtocolId"] = currentProtocolId
        }
        if let socialOnboardingCompletedAt = socialOnboardingCompletedAt {
            data["socialOnboardingCompletedAt"] = Timestamp(date: socialOnboardingCompletedAt)
        }

        return data
    }
}
