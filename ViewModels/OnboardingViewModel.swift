import Foundation
import SwiftUI
import Combine

class OnboardingViewModel: ObservableObject {
    @Published var currentScreen: OnboardingScreen = .welcome
    @Published var gardenName: String = ""
    @Published var selectedIcon: String = "🌻"
    @Published var selectedPlantSpecies: PlantSpecies = .oak
    @Published var selectedDuration: Int = 30

    let availableIcons = ["🌻", "🌿", "🌳", "🌺", "🌸", "🌼", "🌷", "🌹", "🪴", "💐", "🌾", "🌱"]

    var progress: Double {
        let total = 8.0
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

        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        print("✅ Onboarding completed")
        print("   Garden created: \(newGarden.name) \(newGarden.icon)")
        print("   Garden ID: \(newGarden.id)")
        print("   Default plant: \(selectedPlantSpecies.rawValue)")
        print("   Default duration: \(selectedDuration) min")
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
    case readyToStart = 7
}
