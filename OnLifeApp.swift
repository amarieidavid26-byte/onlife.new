import SwiftUI
import FirebaseCore

@main
struct OnLifeApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var decayManager = PlantDecayManager.shared

    init() {
        // TODO: Add GoogleService-Info.plist from Firebase Console
        // FirebaseManager.configure()

        // Check for decay on app launch
        PlantDecayManager.shared.forceDecayCheck()
        print("🌱 PlantDecayManager initialized and initial decay check performed")
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingContainerView()
            }
        }
    }
}
