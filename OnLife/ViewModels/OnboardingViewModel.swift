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
        let total = 11.0
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

        // Infer and save chronotype from wake/sleep times
        let wakeHour = Calendar.current.component(.hour, from: wakeTime)
        let sleepHour = Calendar.current.component(.hour, from: sleepTime)

        let quickAssessment = ChronotypeQuickAssessment(
            preferredWakeTime: wakeHour,
            preferredSleepTime: sleepHour,
            selfPerceivedType: inferSelfPerception(wakeHour: wakeHour),
            bestFocusTime: inferFocusTimePref(wakeHour: wakeHour)
        )

        let chronotypeResult = ChronotypeInferenceEngine.shared.inferFromQuickAssessment(quickAssessment)

        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        print("✅ Onboarding completed")
        print("   Garden created: \(newGarden.name) \(newGarden.icon)")
        print("   Garden ID: \(newGarden.id)")
        print("   Default plant: \(selectedPlantSpecies.rawValue)")
        print("   Default duration: \(selectedDuration) min")
        print("   Wake time: \(wakeTime)")
        print("   Bedtime: \(sleepTime)")
        print("   Chronotype: \(chronotypeResult.chronotype.rawValue) \(chronotypeResult.chronotype.icon)")
    }

    // MARK: - Chronotype Helpers

    private func inferSelfPerception(wakeHour: Int) -> ChronotypeQuickAssessment.SelfPerception {
        if wakeHour <= 6 {
            return .morning
        } else if wakeHour >= 9 {
            return .evening
        }
        return .neither
    }

    private func inferFocusTimePref(wakeHour: Int) -> ChronotypeQuickAssessment.FocusTimePref {
        if wakeHour <= 6 {
            return .morning
        } else if wakeHour <= 8 {
            return .afternoon
        } else {
            return .evening
        }
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
    case notificationPermission = 9
    case readyToStart = 10
}
