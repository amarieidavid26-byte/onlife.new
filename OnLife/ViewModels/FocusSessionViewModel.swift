import Foundation
import SwiftUI
import Combine

class FocusSessionViewModel: ObservableObject {
    @Published var isSessionActive = false
    @Published var isPaused = false
    @Published var sessionPhase: SessionPhase = .input

    // Session data
    @Published var taskDescription: String = ""
    @Published var selectedSeedType: SeedType = .oneTime
    @Published var selectedDuration: Int = 30
    @Published var selectedEnvironment: FocusEnvironment = .home
    @Published var selectedPlantSpecies: PlantSpecies = .oak
    @Published var currentGarden: Garden?

    // Timer
    @Published var elapsedTime: TimeInterval = 0
    @Published var plannedDuration: TimeInterval = 1800 // 30 min default

    // Plant growth
    @Published var plantGrowthStage: Int = 0
    @Published var plantHealth: Double = 100.0

    private var timer: Timer?
    private var sessionStartTime: Date?

    func startSession() {
        sessionPhase = .planting

        // Play seed planting sequence
        AudioManager.shared.play(.seedMorph, volume: 0.7)
        HapticManager.shared.seedPlantingSequence()

        // After 3.5 seconds, start focus mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            self.beginFocusMode()
        }
    }

    func beginFocusMode() {
        sessionPhase = .focusing
        isSessionActive = true
        sessionStartTime = Date()
        plannedDuration = TimeInterval(selectedDuration * 60)

        AudioManager.shared.play(.growthTick, volume: 0.4)

        startTimer()
    }

    func pauseSession() {
        isPaused = true
        timer?.invalidate()
        timer = nil
        HapticManager.shared.impact(style: .medium)
    }

    func resumeSession() {
        isPaused = false
        startTimer()
        HapticManager.shared.impact(style: .medium)
    }

    func endSession() {
        timer?.invalidate()
        timer = nil

        if elapsedTime >= plannedDuration * 0.8 {
            // Session was successful
            sessionPhase = .completed
            AudioManager.shared.play(.bloom, volume: 0.8)
            HapticManager.shared.notification(type: .success)
        } else {
            // Session was abandoned
            sessionPhase = .abandoned
            AudioManager.shared.play(.warning, volume: 0.6)
            HapticManager.shared.notification(type: .warning)
        }

        // BUG FIX: Do NOT set isSessionActive = false here
        // This was causing the completion screen to dismiss immediately
        // The flag is now only set to false in resetSession()
    }

    func completeSession() {
        print("🔥 completeSession() called")
        print("🔥 sessionPhase before: \(sessionPhase)")
        print("🔥 currentGarden: \(String(describing: currentGarden))")

        sessionPhase = .completed
        savePlantToGarden()
        endSession()
    }

    func savePlantToGarden() {
        print("🌱 savePlantToGarden() called")
        print("🌱 currentGarden: \(String(describing: currentGarden))")

        guard let garden = currentGarden else {
            print("❌ No garden selected!")
            return
        }

        print("✅ Garden found: \(garden.name)")

        var plant = Plant(
            id: UUID(),
            gardenId: garden.id,
            sessionId: UUID(),
            species: selectedPlantSpecies,
            seedType: selectedSeedType,
            createdAt: Date(),
            health: plantHealth,
            growthStage: plantGrowthStage,
            lastSessionDate: Date(),
            hasScar: false,
            lastWateredDate: Date()
        )

        // If plant is recurring, mark it as watered
        if plant.seedType == .recurring {
            plant.water()
            print("💧 Recurring plant watered on creation")
        }

        print("🌱 Created plant: \(plant.species.rawValue) (\(plant.seedType.rawValue))")

        GardenDataManager.shared.savePlant(plant, to: garden.id)
        print("✅ Plant saved to garden: \(garden.name)")

        // Save the focus session
        let session = FocusSession(
            gardenId: garden.id,
            plantId: plant.id,
            taskDescription: taskDescription,
            seedType: selectedSeedType,
            plantSpecies: selectedPlantSpecies,
            environment: selectedEnvironment,
            startTime: sessionStartTime ?? Date(),
            endTime: Date(),
            plannedDuration: plannedDuration,
            actualDuration: elapsedTime,
            wasCompleted: true,
            wasAbandoned: false,
            pauseCount: 0,
            totalPauseTime: 0,
            growthStageAchieved: plantGrowthStage
        )

        GardenDataManager.shared.saveSession(session)
        print("⏱️ Session saved: \(session.taskDescription)")
    }

    func resetSession() {
        sessionPhase = .input
        isSessionActive = false  // Only set to false here, when user explicitly returns to garden
        isPaused = false
        elapsedTime = 0
        taskDescription = ""
        plantGrowthStage = 0
        plantHealth = 100.0
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSession()
        }
    }

    private func updateSession() {
        elapsedTime += 1

        // Update plant growth (grows every 30 seconds)
        if Int(elapsedTime) % 30 == 0 {
            plantGrowthStage = min(plantGrowthStage + 1, 10)
            AudioManager.shared.play(.growthTick, volume: 0.3)
        }

        // Auto-complete when time is up
        if elapsedTime >= plannedDuration {
            completeSession()
        }
    }

    var progress: Double {
        guard plannedDuration > 0 else { return 0 }
        return min(elapsedTime / plannedDuration, 1.0)
    }

    var remainingTime: TimeInterval {
        max(0, plannedDuration - elapsedTime)
    }

    var timeString: String {
        let time = isPaused ? elapsedTime : remainingTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

enum SessionPhase {
    case input           // Task input modal
    case planting        // Seed planting animation
    case focusing        // Active focus session
    case completed       // Session completed successfully
    case abandoned       // Session abandoned early
}
