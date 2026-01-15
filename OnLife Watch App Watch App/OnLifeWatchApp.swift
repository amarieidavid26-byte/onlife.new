import SwiftUI
import WatchConnectivity

@main
struct OnLife_Watch_App_Watch_AppApp: App {
    // CRITICAL: Force initialization BEFORE @StateObject evaluation
    // Using stored property ensures init() runs at app launch
    private let forceConnectivity = WatchConnectivityManager.shared
    private let forceWorkoutManager = WorkoutSessionManager.shared
    private let forceFlowCalculator = FlowScoreCalculator.shared

    // @StateObject for SwiftUI observation (these reference the same singletons)
    @StateObject private var workoutManager = WorkoutSessionManager.shared
    @StateObject private var flowCalculator = FlowScoreCalculator.shared
    @StateObject private var connectivity = WatchConnectivityManager.shared

    init() {
        print("⌚⌚⌚ [OnLifeWatchApp] init() STARTING ⌚⌚⌚")
        print("   Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
        
        // CRITICAL: Force WatchConnectivity initialization on MAIN THREAD
        // WCSession.delegate MUST be set on main thread
        if !Thread.isMainThread {
            print("⚠️ [OnLifeWatchApp] WARNING: App init not on main thread! Dispatching to main...")
            DispatchQueue.main.sync {
                _ = WatchConnectivityManager.shared
                print("⌚ [OnLifeWatchApp] WatchConnectivityManager initialized (dispatched to main)")
            }
        } else {
            _ = WatchConnectivityManager.shared
            print("⌚ [OnLifeWatchApp] WatchConnectivityManager initialized (already on main)")
        }
        
        // Verify WCSession is supported and print detailed status
        if WCSession.isSupported() {
            let session = WCSession.default
            print("⌚ [OnLifeWatchApp] WCSession status:")
            print("   Supported: ✅")
            print("   Delegate set: \(session.delegate != nil ? "✅" : "❌")")
            print("   Activation state: \(session.activationState.rawValue)")
            print("   Reachable: \(session.isReachable)")
        } else {
            print("❌ [OnLifeWatchApp] WCSession NOT supported!")
        }
        
        print("⌚⌚⌚ [OnLifeWatchApp] init() COMPLETE ⌚⌚⌚\n")
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchHomeView()
                    .environmentObject(workoutManager)
                    .environmentObject(flowCalculator)
                    .environmentObject(connectivity)
            }
        }
    }
}
