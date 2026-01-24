import Foundation

// MARK: - Plant Species
enum PlantSpecies: String, Codable, CaseIterable {
    case oak = "oak"
    case rose = "rose"
    case cactus = "cactus"
    case sunflower = "sunflower"
    case fern = "fern"
    case bamboo = "bamboo"
    case lavender = "lavender"
    case bonsai = "bonsai"
    case cherry = "cherry"
    case tulip = "tulip"

    var displayName: String {
        switch self {
        case .cherry: return "Cherry Blossom"
        default: return rawValue.capitalized
        }
    }

    var icon: String {
        switch self {
        case .oak: return "🌳"
        case .rose: return "🌹"
        case .cactus: return "🌵"
        case .sunflower: return "🌻"
        case .fern: return "🌿"
        case .bamboo: return "🎋"
        case .lavender: return "💜"
        case .bonsai: return "🪴"
        case .cherry: return "🌸"
        case .tulip: return "🌷"
        }
    }

    /// Alias for icon (used by 3D garden view)
    var emoji: String { icon }

    var description: String {
        switch self {
        case .oak: return "Strong and steadfast, grows slowly but surely"
        case .rose: return "Beautiful and delicate, requires consistent care"
        case .cactus: return "Resilient and low-maintenance"
        case .sunflower: return "Bright and energetic, thrives on regular attention"
        case .fern: return "Peaceful and calming, loves routine"
        case .bamboo: return "Fast-growing and flexible"
        case .lavender: return "Soothing and aromatic, perfect for focus"
        case .bonsai: return "Mindful and meditative, rewards patience"
        case .cherry: return "Graceful and serene, symbolizes renewal"
        case .tulip: return "Elegant and colorful, represents perfect focus"
        }
    }
}

// MARK: - Seed Type
enum SeedType: String, Codable, Equatable {
    case oneTime = "oneTime"
    case recurring = "recurring"

    var displayName: String {
        switch self {
        case .oneTime: return "One-Time"
        case .recurring: return "Recurring"
        }
    }

    var icon: String {
        switch self {
        case .oneTime: return "🌸"
        case .recurring: return "🌿"
        }
    }

    var description: String {
        switch self {
        case .oneTime:
            return "Plant once and watch it grow. Perfect for tasks you'll complete and move on from."
        case .recurring:
            return "A living plant that needs regular watering (focus sessions). Great for habits you want to maintain."
        }
    }
}

// MARK: - Health Status
enum HealthStatus: String, Codable {
    case thriving = "thriving"
    case healthy = "healthy"
    case stressed = "stressed"
    case wilting = "wilting"
    case dead = "dead"

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .thriving: return "✨"
        case .healthy: return "💚"
        case .stressed: return "😰"
        case .wilting: return "🥀"
        case .dead: return "💀"
        }
    }
}

// MARK: - Focus Environment
enum FocusEnvironment: String, Codable, CaseIterable {
    case home = "home"
    case coffeeShop = "coffeeShop"
    case library = "library"
    case office = "office"
    case outdoors = "outdoors"
    case commute = "commute"
    case other = "other"

    var displayName: String {
        switch self {
        case .home: return "Home"
        case .coffeeShop: return "Coffee Shop"
        case .library: return "Library"
        case .office: return "Office"
        case .outdoors: return "Outdoors"
        case .commute: return "Commute"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .home: return "🏠"
        case .coffeeShop: return "☕"
        case .library: return "📚"
        case .office: return "🏢"
        case .outdoors: return "🌳"
        case .commute: return "🚇"
        case .other: return "📍"
        }
    }
}

// MARK: - Time of Day
enum TimeOfDay: String, Codable {
    case earlyMorning = "earlyMorning"     // 5-8am
    case morning = "morning"               // 8-11am
    case midday = "midday"                 // 11am-2pm
    case afternoon = "afternoon"           // 2-5pm
    case evening = "evening"               // 5-8pm
    case night = "night"                   // 8pm-12am
    case lateNight = "lateNight"          // 12am-5am

    var displayName: String {
        switch self {
        case .earlyMorning: return "Early Morning"
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        case .lateNight: return "Late Night"
        }
    }

    static func from(date: Date) -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 5..<8: return .earlyMorning
        case 8..<11: return .morning
        case 11..<14: return .midday
        case 14..<17: return .afternoon
        case 17..<20: return .evening
        case 20..<24: return .night
        default: return .lateNight
        }
    }
}
