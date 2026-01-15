import SwiftUI

@main
struct OnLifeWatchApp: App {
    @StateObject private var workoutManager = WorkoutSessionManager.shared
    @StateObject private var flowCalculator = FlowScoreCalculator.shared
    @StateObject private var connectivity = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchHomeView()
            }
            .environmentObject(workoutManager)
            .environmentObject(flowCalculator)
            .environmentObject(connectivity)
        }
    }
}
