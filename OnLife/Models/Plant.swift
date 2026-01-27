import Foundation

// MARK: - Plant Position (for 3D garden)

struct PlantPosition: Codable, Equatable {
    var x: Float
    var y: Float
    var z: Float

    init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - Plant Model

struct Plant: Codable, Identifiable {
    let id: UUID
    let gardenId: UUID
    let sessionId: UUID
    var species: PlantSpecies
    var seedType: SeedType
    var createdAt: Date
    var health: Double // 0-100
    var growthStage: Int // 0-10
    var lastSessionDate: Date
    var hasScar: Bool // if plant was previously wilting but recovered

    // Decay tracking (for recurring plants)
    var lastWateredDate: Date

    // Garden position (x, y, z) - nil means use default placement
    var gardenPosition: PlantPosition?

    init(
        id: UUID = UUID(),
        gardenId: UUID,
        sessionId: UUID,
        species: PlantSpecies,
        seedType: SeedType,
        createdAt: Date = Date(),
        health: Double = 100.0,
        growthStage: Int = 0,
        lastSessionDate: Date = Date(),
        hasScar: Bool = false,
        lastWateredDate: Date = Date(),
        gardenPosition: PlantPosition? = nil
    ) {
        self.id = id
        self.gardenId = gardenId
        self.sessionId = sessionId
        self.species = species
        self.seedType = seedType
        self.createdAt = createdAt
        self.health = health
        self.growthStage = growthStage
        self.lastSessionDate = lastSessionDate
        self.hasScar = hasScar
        self.lastWateredDate = lastWateredDate
        self.gardenPosition = gardenPosition
    }

    // Computed properties
    var healthStatus: HealthStatus {
        switch health {
        case 90...100: return .thriving
        case 70..<90: return .healthy
        case 40..<70: return .stressed
        case 10..<40: return .wilting
        default: return .dead
        }
    }

    var totalFocusTime: TimeInterval {
        // Estimate based on growth progress (0.0-1.0 maps to 0-25 minutes)
        // This prevents the old bug of showing "5h" for a 5-minute session
        // growthProgress of 0.2 (20%) = ~5 minutes of focus
        return TimeInterval(growthProgress * 25 * 60)
    }

    var daysSinceWatering: Int {
        Calendar.current.dateComponents([.day], from: lastWateredDate, to: Date()).day ?? 0
    }

    var daysSinceLastWatering: Int {
        // Legacy property for compatibility
        return daysSinceWatering
    }

    var needsWatering: Bool {
        guard seedType == .recurring else { return false }
        return daysSinceWatering > 3
    }

    var isFullyGrown: Bool {
        return growthStage >= 10
    }

    // MARK: - 3D Garden View Properties

    /// Growth progress from 0.0 (seed) to 1.0 (fully grown)
    var growthProgress: Double {
        return Double(growthStage) / 10.0
    }

    /// Health level from 0.0 (dead) to 1.0 (thriving)
    var healthLevel: Double {
        return health / 100.0
    }

    /// Date the plant was created/planted
    var plantedDate: Date? {
        return createdAt
    }

    /// Total focus time in minutes
    var focusMinutes: Int {
        return Int(totalFocusTime / 60)
    }

    /// Plant type for 3D rendering (alias for species)
    var type: PlantSpecies {
        return species
    }

    /// Optional custom name for the plant
    var name: String? {
        return nil  // Could be extended to allow custom naming
    }

    // MARK: - Decay System

    mutating func updateDecay() {
        // Only decay recurring plants
        guard seedType == .recurring else { return }

        let days = daysSinceWatering

        // Decay algorithm based on days without watering
        switch days {
        case 0...3:
            // Days 1-3: Healthy, slow decay
            health = max(80, 100 - Double(days) * 6.67)
        case 4...7:
            // Days 4-7: Stressed, moderate decay
            health = max(50, 80 - Double(days - 3) * 7.5)
        case 8...14:
            // Days 8-14: Wilting, fast decay
            health = max(20, 50 - Double(days - 7) * 4.29)
        default:
            // Day 15+: Dead
            health = max(0, 20 - Double(days - 14) * 2)
        }
    }

    mutating func water() {
        lastWateredDate = Date()

        // Restore health based on current state
        if health >= 80 {
            health = 100 // Full restore if still healthy
        } else if health >= 50 {
            health = min(100, health + 30) // Partial restore if stressed
            hasScar = true // Mark that it recovered from stress
        } else if health >= 20 {
            health = min(100, health + 20) // Smaller restore if wilting
            hasScar = true
        } else {
            health = min(100, health + 10) // Minimal restore if nearly dead
            hasScar = true
        }
    }
}
