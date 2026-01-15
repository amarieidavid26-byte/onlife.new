import Foundation
import Combine

class PlantDecayManager: ObservableObject {
    static let shared = PlantDecayManager()

    @Published var needsUpdate: Bool = false
    private var timer: Timer?

    private init() {
        startDecayTimer()
    }

    // Check for decay updates every hour
    func startDecayTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.checkAndUpdateDecay()
        }
    }

    func checkAndUpdateDecay() {
        print("🕐 Checking for plant decay...")

        // Get all gardens
        var gardens = GardenDataManager.shared.loadGardens()
        var needsSave = false

        for gardenIndex in gardens.indices {
            for plantIndex in gardens[gardenIndex].plants.indices {
                var plant = gardens[gardenIndex].plants[plantIndex]

                // Only update recurring plants
                if plant.seedType == .recurring {
                    let oldHealth = plant.health
                    plant.updateDecay()

                    if plant.health != oldHealth {
                        gardens[gardenIndex].plants[plantIndex] = plant
                        needsSave = true
                        print("🥀 Plant \(plant.species.rawValue) decayed: \(Int(oldHealth))% → \(Int(plant.health))%")
                    }
                }
            }

            if needsSave {
                GardenDataManager.shared.saveGarden(gardens[gardenIndex])
            }
        }

        if needsSave {
            needsUpdate = true
        }
    }

    // Force immediate decay check (for testing)
    func forceDecayCheck() {
        checkAndUpdateDecay()
    }

    // MARK: - Testing Methods

    func testDecaySimulation(daysAgo: Int) {
        print("🧪 TESTING: Simulating \(daysAgo) days of decay...")

        var gardens = GardenDataManager.shared.loadGardens()
        var changesCount = 0

        for gardenIndex in gardens.indices {
            for plantIndex in gardens[gardenIndex].plants.indices {
                var plant = gardens[gardenIndex].plants[plantIndex]

                if plant.seedType == .recurring {
                    let oldHealth = plant.health

                    // Set watering date to X days ago
                    let testDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
                    plant.lastWateredDate = testDate
                    plant.updateDecay()

                    gardens[gardenIndex].plants[plantIndex] = plant
                    changesCount += 1

                    print("🧪 Plant: \(plant.species.rawValue)")
                    print("   Health: \(Int(oldHealth))% → \(Int(plant.health))%")
                    print("   Status: \(plant.healthStatus)")
                    print("   Days since watering: \(plant.daysSinceWatering)")
                }
            }

            if changesCount > 0 {
                GardenDataManager.shared.saveGarden(gardens[gardenIndex])
            }
        }

        print("🧪 Test complete! \(changesCount) recurring plants updated")
        needsUpdate = true
    }

    func revertDecayTest() {
        print("⏪ REVERTING: Resetting all plants to healthy state...")

        var gardens = GardenDataManager.shared.loadGardens()
        var revertedCount = 0

        for gardenIndex in gardens.indices {
            for plantIndex in gardens[gardenIndex].plants.indices {
                var plant = gardens[gardenIndex].plants[plantIndex]

                if plant.seedType == .recurring {
                    // Reset to healthy state
                    plant.lastWateredDate = Date()
                    plant.health = 100.0
                    plant.hasScar = false

                    gardens[gardenIndex].plants[plantIndex] = plant
                    revertedCount += 1

                    print("⏪ Reverted: \(plant.species.rawValue) back to 100% health")
                }
            }

            if revertedCount > 0 {
                GardenDataManager.shared.saveGarden(gardens[gardenIndex])
            }
        }

        print("⏪ Revert complete! \(revertedCount) plants restored to healthy state")
        needsUpdate = true
    }
}
