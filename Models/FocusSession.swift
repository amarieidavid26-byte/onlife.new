import Foundation

// MARK: - Session Source
enum SessionSource: String, Codable {
    case iphone = "iPhone"
    case watch = "Watch"
    case handoff = "Handoff"  // Started on one device, continued on another
}

// MARK: - Biometric Data
struct BiometricSessionData: Codable {
    var averageHR: Double = 0
    var peakHR: Double = 0
    var minimumHR: Double = 0
    var averageHRV: Double = 0  // RMSSD
    var peakHRV: Double = 0
    var averageFlowScore: Int = 0
    var peakFlowScore: Int = 0
    var timeInFlowState: TimeInterval = 0  // Seconds where state == .flow

    // Detailed breakdown (Flow Score components)
    var hrvScore: Int = 0      // Out of 40
    var hrScore: Int = 0       // Out of 30
    var sleepScore: Int = 0    // Out of 20
    var substanceScore: Int = 0 // Out of 10
}

// MARK: - Flow Data Point (for timeline)
struct FlowDataPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let hr: Double
    let hrv: Double
    let flowScore: Int
    let flowState: String  // "Calibrating", "Pre-Flow", "Flow", etc.

    init(id: UUID = UUID(), timestamp: Date, hr: Double, hrv: Double, flowScore: Int, flowState: String) {
        self.id = id
        self.timestamp = timestamp
        self.hr = hr
        self.hrv = hrv
        self.flowScore = flowScore
        self.flowState = flowState
    }
}

// MARK: - Focus Session
struct FocusSession: Codable, Identifiable {
    let id: UUID
    let gardenId: UUID
    var plantId: UUID?
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

    // New properties for Watch integration
    var source: SessionSource
    var biometrics: BiometricSessionData?
    var flowTimeline: [FlowDataPoint]?

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
        growthStageAchieved: Int = 0,
        source: SessionSource = .iphone,
        biometrics: BiometricSessionData? = nil,
        flowTimeline: [FlowDataPoint]? = nil
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
        self.source = source
        self.biometrics = biometrics
        self.flowTimeline = flowTimeline
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
