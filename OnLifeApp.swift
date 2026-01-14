import SwiftUI
import FirebaseCore
import WatchConnectivity

@main
struct OnLifeApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var decayManager = PlantDecayManager.shared

    // CRITICAL: Force WatchConnectivityManager initialization at app launch
    // This MUST be a stored property (not computed) to trigger init
    private let watchConnectivity = WatchConnectivityManager.shared

    init() {
        print("📱📱📱 [OnLifeApp] init() STARTING 📱📱📱")
        print("   Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
        
        // CRITICAL: Force WatchConnectivity initialization on MAIN THREAD
        // WCSession.delegate MUST be set on main thread
        if !Thread.isMainThread {
            print("⚠️ [OnLifeApp] WARNING: App init not on main thread! Dispatching to main...")
            DispatchQueue.main.sync {
                _ = WatchConnectivityManager.shared
                print("📱 [OnLifeApp] WatchConnectivityManager initialized (dispatched to main)")
            }
        } else {
            _ = WatchConnectivityManager.shared
            print("📱 [OnLifeApp] WatchConnectivityManager initialized (already on main)")
        }
        
        // Verify WCSession is supported and print detailed status
        if WCSession.isSupported() {
            let session = WCSession.default
            print("📱 [OnLifeApp] WCSession status:")
            print("   Supported: ✅")
            print("   Delegate set: \(session.delegate != nil ? "✅" : "❌")")
            print("   Activation state: \(session.activationState.rawValue)")
            print("   Paired: \(session.isPaired)")
            print("   Watch app installed: \(session.isWatchAppInstalled)")
            print("   Reachable: \(session.isReachable)")
        } else {
            print("❌ [OnLifeApp] WCSession NOT supported!")
        }

        // Check for decay on app launch
        PlantDecayManager.shared.forceDecayCheck()
        print("🌱 PlantDecayManager initialized and initial decay check performed")
        
        print("📱📱📱 [OnLifeApp] init() COMPLETE 📱📱📱\n")
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
