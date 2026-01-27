import SwiftUI
import FirebaseCore
import WatchConnectivity
import GoogleSignIn

// MARK: - App Delegate for Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        print("✅ [Firebase] Configured in AppDelegate")
        return true
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        print("⚠️ [Memory] Memory warning received - triggering cleanup")

        // Clear caches
        URLCache.shared.removeAllCachedResponses()
    }
}

// MARK: - Main App

@main
struct OnLifeApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedAuthentication") private var hasCompletedAuthentication = false
    @StateObject private var decayManager = PlantDecayManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    // Asset preloading state
    @State private var isPreloadingAssets = true

    // Theme refresh ID - changing this forces entire view hierarchy to rebuild
    @State private var themeRefreshID = UUID()

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
            Group {
                // Step 0: Preload 3D assets (only once at app launch)
                if isPreloadingAssets {
                    AssetPreloadView {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPreloadingAssets = false
                        }
                    }
                }
                // Step 1: Authentication (first-time only)
                else if !hasCompletedAuthentication {
                    AuthenticationView()
                        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                            if isAuthenticated {
                                hasCompletedAuthentication = true
                            }
                        }
                }
                // Step 2: Onboarding (after auth)
                else if !hasCompletedOnboarding {
                    OnboardingContainerView()
                }
                // Step 3: Main app (or re-auth if signed out)
                else if !authManager.isAuthenticated {
                    SignInView()
                }
                // Step 4: Main app
                else {
                    MainTabView()
                }
            }
            .id(themeRefreshID)  // Changing this rebuilds entire view hierarchy
            .environmentObject(themeManager)
            .environment(\.theme, themeManager.currentTheme)
            .preferredColorScheme(.dark)  // Force dark mode for all themes
            .onReceive(NotificationCenter.default.publisher(for: .themeDidChange)) { _ in
                // Force complete view hierarchy rebuild when theme changes
                themeRefreshID = UUID()
                print("🎨 [OnLifeApp] Theme changed - refreshing view hierarchy")
            }
            .onOpenURL { url in
                print("📱 [OnLifeApp] ===== onOpenURL RECEIVED =====")
                print("📱 [OnLifeApp] Full URL: \(url.absoluteString)")
                print("📱 [OnLifeApp] Scheme: \(url.scheme ?? "nil")")
                print("📱 [OnLifeApp] Host: \(url.host ?? "nil")")
                print("📱 [OnLifeApp] Path: \(url.path)")
                print("📱 [OnLifeApp] Query: \(url.query ?? "nil")")

                // Handle Google Sign-In callback
                if GIDSignIn.sharedInstance.handle(url) {
                    print("📱 [OnLifeApp] URL handled by Google Sign-In")
                    return
                }

                // Handle WHOOP OAuth callback
                if WHOOPAuthService.canHandle(url: url) {
                    print("📱 [OnLifeApp] URL recognized as WHOOP callback, routing to WHOOPAuthService...")
                    Task {
                        do {
                            try await WHOOPAuthService.shared.handleCallback(url: url)
                            print("📱 [OnLifeApp] WHOOP callback handled successfully ✓")
                        } catch {
                            print("📱 [OnLifeApp] ❌ WHOOP OAuth callback error: \(error)")
                            print("📱 [OnLifeApp] Error type: \(type(of: error))")
                            if let whoopError = error as? WHOOPAuthError {
                                print("📱 [OnLifeApp] WHOOPAuthError description: \(whoopError.localizedDescription)")
                            }
                        }
                    }
                    return
                }

                print("📱 [OnLifeApp] ⚠️ URL not handled by any handler: \(url)")
            }
        }
    }
}
