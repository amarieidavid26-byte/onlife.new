import Foundation
import SwiftUI
import Combine

class OnboardingViewModel: ObservableObject {
    @Published var currentScreen: OnboardingScreen = .welcome
    @Published var gardenName: String = ""
    @Published var selectedIcon: String = "🌻"
    @Published var selectedPlantSpecies: PlantSpecies = .oak
    @Published var selectedDuration: Int = 30
    @Published var wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @Published var sleepTime: Date = Calendar.current.date(from: DateComponents(hour: 23, minute: 0)) ?? Date()

    let availableIcons = ["🌻", "🌿", "🌳", "🌺", "🌸", "🌼", "🌷", "🌹", "🪴", "💐", "🌾", "🌱"]

    var progress: Double {
        let total = 10.0
        let current = Double(currentScreen.rawValue + 1)
        return current / total
    }

    func nextScreen() {
        if let nextScreen = OnboardingScreen(rawValue: currentScreen.rawValue + 1) {
            currentScreen = nextScreen
        }
    }

    func previousScreen() {
        if let previousScreen = OnboardingScreen(rawValue: currentScreen.rawValue - 1) {
            currentScreen = previousScreen
        }
    }

    func completeOnboarding() {
        // Create the garden from onboarding data
        let newGarden = Garden(
            userId: UUID(), // TODO: Replace with actual user ID when auth is implemented
            name: gardenName.isEmpty ? "My Garden" : gardenName,
            icon: selectedIcon
        )

        // Save it using GardenDataManager
        GardenDataManager.shared.saveGarden(newGarden)

        // Save wake/sleep times for chronotype inference
        UserDefaults.standard.set(wakeTime, forKey: "userWakeTime")
        UserDefaults.standard.set(sleepTime, forKey: "userBedtime")

        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        print("✅ Onboarding completed")
        print("   Garden created: \(newGarden.name) \(newGarden.icon)")
        print("   Garden ID: \(newGarden.id)")
        print("   Default plant: \(selectedPlantSpecies.rawValue)")
        print("   Default duration: \(selectedDuration) min")
        print("   Wake time: \(wakeTime)")
        print("   Bedtime: \(sleepTime)")
    }
}

enum OnboardingScreen: Int, CaseIterable {
    case welcome = 0
    case gardenConcept = 1
    case createGarden = 2
    case seedTypes = 3
    case plantSpecies = 4
    case durationPreferences = 5
    case trackingIntro = 6
    case wakeSleepTime = 7
    case healthKitPermission = 8
    case readyToStart = 9
}
