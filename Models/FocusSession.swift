import Foundation

struct FocusSession: Codable, Identifiable {
    let id: UUID
    let gardenId: UUID
    let plantId: UUID?
    var taskDescription: String
    var seedType: SeedType
    var plantSpecies: PlantSpecies
    var environment: FocusEnvironment
    var startTime: Date
    var endTime: Date?
    var plannedDuration: TimeInterval // in seconds
    var actualDuration: TimeInterval // in seconds
    var wasCompleted: Bool
    var wasAbandoned: Bool
    var pauseCount: Int
    var totalPauseTime: TimeInterval
    var growthStageAchieved: Int

    init(
        id: UUID = UUID(),
        gardenId: UUID,
        plantId: UUID? = nil,
        taskDescription: String,
        seedType: SeedType,
        plantSpecies: PlantSpecies,
        environment: FocusEnvironment,
        startTime: Date = Date(),
        endTime: Date? = nil,
        plannedDuration: TimeInterval,
        actualDuration: TimeInterval = 0,
        wasCompleted: Bool = false,
        wasAbandoned: Bool = false,
        pauseCount: Int = 0,
        totalPauseTime: TimeInterval = 0,
        growthStageAchieved: Int = 0
    ) {
        self.id = id
        self.gardenId = gardenId
        self.plantId = plantId
        self.taskDescription = taskDescription
        self.seedType = seedType
        self.plantSpecies = plantSpecies
        self.environment = environment
        self.startTime = startTime
        self.endTime = endTime
        self.plannedDuration = plannedDuration
        self.actualDuration = actualDuration
        self.wasCompleted = wasCompleted
        self.wasAbandoned = wasAbandoned
        self.pauseCount = pauseCount
        self.totalPauseTime = totalPauseTime
        self.growthStageAchieved = growthStageAchieved
    }

    // Computed properties
    var timeOfDay: TimeOfDay {
        TimeOfDay.from(date: startTime)
    }

    var focusQuality: Double {
        guard plannedDuration > 0 else { return 0 }
        let efficiency = actualDuration / plannedDuration
        let pausePenalty = min(Double(pauseCount) * 0.1, 0.5)
        return min(max(efficiency - pausePenalty, 0), 1.0)
    }

    var formattedDuration: String {
        let minutes = Int(actualDuration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
}
