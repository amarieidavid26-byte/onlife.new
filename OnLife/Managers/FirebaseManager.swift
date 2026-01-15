import Foundation
import FirebaseCore
import Combine

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    @Published var isConfigured: Bool = false

    private init() {}

    func configure() {
        // Check if GoogleService-Info.plist exists
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("⚠️ GoogleService-Info.plist not found. Firebase features disabled.")
            return
        }

        FirebaseApp.configure()
        isConfigured = true
        print("✅ Firebase configured successfully")
    }
}
