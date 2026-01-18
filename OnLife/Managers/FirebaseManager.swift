import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Firebase Manager
/// Centralized Firebase service for authentication and cloud sync

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    // MARK: - Published Properties

    @Published var isConfigured: Bool = false
    @Published var currentUser: FirebaseAuth.User?
    @Published var isAuthenticated: Bool = false
    @Published var isSyncing: Bool = false

    // MARK: - Firebase Services

    private(set) var auth: Auth?
    private(set) var firestore: Firestore?

    // MARK: - Private Properties

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {}

    // MARK: - Configuration

    func configure() {
        // Check if GoogleService-Info.plist exists
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("⚠️ [Firebase] GoogleService-Info.plist not found. Firebase features disabled.")
            return
        }

        // Configure Firebase
        FirebaseApp.configure()
        isConfigured = true

        // Initialize services
        auth = Auth.auth()
        firestore = Firestore.firestore()

        // Configure Firestore settings for offline persistence
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        firestore?.settings = settings

        // Listen for auth state changes
        setupAuthStateListener()

        print("✅ [Firebase] Configured successfully")
    }

    private func setupAuthStateListener() {
        authStateListener = auth?.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil

                if let user = user {
                    print("🔐 [Firebase] Auth state changed - User: \(user.uid) (anonymous: \(user.isAnonymous))")
                } else {
                    print("🔐 [Firebase] Auth state changed - No user")
                }
            }
        }
    }

    // MARK: - Authentication

    /// Sign in anonymously (for MVP - no account required)
    func signInAnonymously() async throws {
        guard let auth = auth else {
            throw FirebaseError.notConfigured
        }

        let result = try await auth.signInAnonymously()
        print("✅ [Firebase] Signed in anonymously: \(result.user.uid)")
    }

    /// Sign in with Apple credential
    func signInWithApple(idToken: String, nonce: String) async throws {
        guard let auth = auth else {
            throw FirebaseError.notConfigured
        }

        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idToken,
            rawNonce: nonce
        )

        let result = try await auth.signIn(with: credential)
        print("✅ [Firebase] Signed in with Apple: \(result.user.uid)")
    }

    /// Link anonymous account to Apple Sign In (upgrade account)
    func linkWithApple(idToken: String, nonce: String) async throws {
        guard let user = currentUser else {
            throw FirebaseError.noUser
        }

        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idToken,
            rawNonce: nonce
        )

        let result = try await user.link(with: credential)
        print("✅ [Firebase] Linked account with Apple: \(result.user.uid)")
    }

    /// Sign out current user
    func signOut() throws {
        guard let auth = auth else {
            throw FirebaseError.notConfigured
        }

        try auth.signOut()
        print("✅ [Firebase] Signed out")
    }

    /// Delete current user account and all data
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw FirebaseError.noUser
        }

        // Delete Firestore data first
        try await deleteUserData(userId: user.uid)

        // Then delete the auth account
        try await user.delete()
        print("✅ [Firebase] Account deleted")
    }

    // MARK: - Firestore Sync

    /// Sync gardens to Firestore
    func syncGardens(_ gardens: [Garden]) async throws {
        guard let userId = currentUser?.uid, let db = firestore else {
            print("⚠️ [Firebase] Cannot sync - no user or Firestore not configured")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let gardensRef = db.collection("users").document(userId).collection("gardens")

        for garden in gardens {
            do {
                let data = try JSONEncoder().encode(garden)
                guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                try await gardensRef.document(garden.id.uuidString).setData(dict, merge: true)
            } catch {
                print("❌ [Firebase] Failed to sync garden \(garden.name): \(error)")
            }
        }

        print("✅ [Firebase] Synced \(gardens.count) gardens")
    }

    /// Fetch gardens from Firestore
    func fetchGardens() async throws -> [Garden] {
        guard let userId = currentUser?.uid, let db = firestore else {
            return []
        }

        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("gardens")
            .getDocuments()

        let gardens = snapshot.documents.compactMap { doc -> Garden? in
            guard let data = try? JSONSerialization.data(withJSONObject: doc.data()),
                  let garden = try? JSONDecoder().decode(Garden.self, from: data)
            else { return nil }
            return garden
        }

        print("✅ [Firebase] Fetched \(gardens.count) gardens")
        return gardens
    }

    /// Sync focus sessions to Firestore
    func syncSessions(_ sessions: [FocusSession]) async throws {
        guard let userId = currentUser?.uid, let db = firestore else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let sessionsRef = db.collection("users").document(userId).collection("sessions")

        for session in sessions {
            do {
                let data = try JSONEncoder().encode(session)
                guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                try await sessionsRef.document(session.id.uuidString).setData(dict, merge: true)
            } catch {
                print("❌ [Firebase] Failed to sync session: \(error)")
            }
        }

        print("✅ [Firebase] Synced \(sessions.count) sessions")
    }

    /// Fetch sessions from Firestore
    func fetchSessions() async throws -> [FocusSession] {
        guard let userId = currentUser?.uid, let db = firestore else {
            return []
        }

        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("sessions")
            .order(by: "startTime", descending: true)
            .limit(to: 100)  // Limit for performance
            .getDocuments()

        let sessions = snapshot.documents.compactMap { doc -> FocusSession? in
            guard let data = try? JSONSerialization.data(withJSONObject: doc.data()),
                  let session = try? JSONDecoder().decode(FocusSession.self, from: data)
            else { return nil }
            return session
        }

        print("✅ [Firebase] Fetched \(sessions.count) sessions")
        return sessions
    }

    /// Sync gamification stats to Firestore
    func syncGamificationStats(_ stats: UserGamificationStats) async throws {
        guard let userId = currentUser?.uid, let db = firestore else {
            return
        }

        let data = try JSONEncoder().encode(stats)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        try await db.collection("users").document(userId).setData(["gamification": dict], merge: true)
        print("✅ [Firebase] Synced gamification stats")
    }

    /// Fetch gamification stats from Firestore
    func fetchGamificationStats() async throws -> UserGamificationStats? {
        guard let userId = currentUser?.uid, let db = firestore else {
            return nil
        }

        let doc = try await db.collection("users").document(userId).getDocument()

        guard let gamificationData = doc.data()?["gamification"] as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: gamificationData),
              let stats = try? JSONDecoder().decode(UserGamificationStats.self, from: data)
        else {
            return nil
        }

        print("✅ [Firebase] Fetched gamification stats")
        return stats
    }

    // MARK: - Data Management

    /// Delete all user data from Firestore
    func deleteUserData(userId: String) async throws {
        guard let db = firestore else { return }

        let userRef = db.collection("users").document(userId)

        // Delete subcollections
        let collections = ["gardens", "sessions"]
        for collection in collections {
            let snapshot = try await userRef.collection(collection).getDocuments()
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
        }

        // Delete user document
        try await userRef.delete()

        print("✅ [Firebase] Deleted all user data")
    }

    // MARK: - Merge Local and Cloud Data

    /// Merge local gardens with cloud gardens (cloud wins on conflict)
    func mergeGardens(local: [Garden], cloud: [Garden]) -> [Garden] {
        var merged = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for cloudGarden in cloud {
            // Cloud version wins on conflict
            merged[cloudGarden.id] = cloudGarden
        }

        return Array(merged.values).sorted { $0.createdAt < $1.createdAt }
    }
}

// MARK: - Firebase Errors

enum FirebaseError: LocalizedError {
    case notConfigured
    case noUser
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firebase is not configured. Please add GoogleService-Info.plist."
        case .noUser:
            return "No user is signed in."
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}
