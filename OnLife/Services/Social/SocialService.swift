import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Social Service

@MainActor
class SocialService: ObservableObject {

    static let shared = SocialService()

    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var connectionListeners: [ListenerRegistration] = []

    // MARK: - Published State

    @Published var currentUserProfile: UserProfile?
    @Published var connections: [Connection] = []
    @Published var friends: [UserProfile] = []
    @Published var flowPartners: [UserProfile] = []
    @Published var observers: [UserProfile] = []
    @Published var pendingRequests: [ConnectionRequest] = []
    @Published var sentRequests: [ConnectionRequest] = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Collections

    private var profilesCollection: CollectionReference {
        db.collection("profiles")
    }

    private var connectionsCollection: CollectionReference {
        db.collection("connections")
    }

    private var requestsCollection: CollectionReference {
        db.collection("connectionRequests")
    }

    // MARK: - Initialization

    private init() {
        setupAuthListener()
    }

    private func setupAuthListener() {
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if user != nil {
                    await self?.loadCurrentUserProfile()
                } else {
                    self?.clearState()
                }
            }
        }
    }

    private func clearState() {
        currentUserProfile = nil
        connections = []
        friends = []
        flowPartners = []
        observers = []
        pendingRequests = []
        sentRequests = []

        // Remove listeners
        connectionListeners.forEach { $0.remove() }
        connectionListeners.removeAll()
    }

    // MARK: - Profile Operations

    /// Fetch or create profile for current user
    func loadCurrentUserProfile() async {
        print("👤 [SocialService] loadCurrentUserProfile() called")

        guard let userId = Auth.auth().currentUser?.uid else {
            print("👤 [SocialService] ERROR: Not authenticated")
            error = "Not authenticated"
            return
        }

        print("👤 [SocialService] Loading profile for user: \(userId)")
        isLoading = true
        defer { isLoading = false }

        do {
            let doc = try await profilesCollection.document(userId).getDocument()
            print("👤 [SocialService] Document exists: \(doc.exists)")

            if let profile = UserProfile(document: doc) {
                print("👤 [SocialService] Profile loaded: \(profile.username)")
                self.currentUserProfile = profile
            } else {
                print("👤 [SocialService] No profile found, creating default...")
                // Create new profile
                let email = Auth.auth().currentUser?.email
                let newProfile = createDefaultProfile(userId: userId, email: email)
                try await saveProfile(newProfile)
                self.currentUserProfile = newProfile
            }

            // Load connections after profile is loaded
            await loadConnections()
            await loadPendingRequests()

        } catch {
            print("👤 [SocialService] ERROR: \(error.localizedDescription)")
            self.error = "Failed to load profile: \(error.localizedDescription)"
        }
    }

    /// Save profile to Firestore
    func saveProfile(_ profile: UserProfile) async throws {
        print("👤 [SocialService] saveProfile called for user: \(profile.id)")
        print("👤 [SocialService] Username: \(profile.username), DisplayName: \(profile.displayName)")
        try await profilesCollection.document(profile.id).setData(profile.toFirestoreData())
        print("👤 [SocialService] Profile saved to Firestore successfully")
    }

    /// Update current user's profile with specific fields
    func updateCurrentProfile(_ updates: [String: Any]) async throws {
        guard let userId = currentUserProfile?.id else {
            throw SocialError.notAuthenticated
        }

        var updatedData = updates
        updatedData["updatedAt"] = Timestamp(date: Date())

        try await profilesCollection.document(userId).updateData(updatedData)
        await loadCurrentUserProfile()
    }

    /// Update username (with uniqueness check)
    func updateUsername(_ newUsername: String) async throws {
        guard let userId = currentUserProfile?.id else {
            throw SocialError.notAuthenticated
        }

        let sanitized = newUsername.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate format
        guard sanitized.count >= 3, sanitized.count <= 20 else {
            throw SocialError.invalidUsername("Username must be 3-20 characters")
        }

        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard sanitized.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            throw SocialError.invalidUsername("Username can only contain letters, numbers, and underscores")
        }

        // Check uniqueness
        let existing = try await profilesCollection
            .whereField("username", isEqualTo: sanitized)
            .getDocuments()

        let otherUsers = existing.documents.filter { $0.documentID != userId }
        if !otherUsers.isEmpty {
            throw SocialError.usernameTaken
        }

        try await updateCurrentProfile(["username": sanitized])
    }

    /// Check if a username is available
    func isUsernameAvailable(_ username: String) async -> Bool {
        let sanitized = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard sanitized.count >= 3 else { return false }

        do {
            let existing = try await profilesCollection
                .whereField("username", isEqualTo: sanitized)
                .getDocuments()

            return existing.documents.isEmpty
        } catch {
            return false
        }
    }

    /// Fetch another user's profile
    func fetchProfile(userId: String) async -> UserProfile? {
        do {
            let doc = try await profilesCollection.document(userId).getDocument()
            return UserProfile(document: doc)
        } catch {
            self.error = "Failed to fetch profile: \(error.localizedDescription)"
            return nil
        }
    }

    /// Search profiles by username
    func searchProfiles(query: String) async -> [UserProfile] {
        guard query.count >= 2 else { return [] }

        let searchTerm = query.lowercased()

        do {
            let snapshot = try await profilesCollection
                .whereField("username", isGreaterThanOrEqualTo: searchTerm)
                .whereField("username", isLessThan: searchTerm + "\u{f8ff}")
                .limit(to: 20)
                .getDocuments()

            // Filter out current user
            return snapshot.documents
                .compactMap { UserProfile(document: $0) }
                .filter { $0.id != currentUserProfile?.id }
        } catch {
            self.error = "Search failed: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Connection Request Operations

    /// Send a connection request
    func sendConnectionRequest(toUserId: String, level: ConnectionLevel, message: String? = nil) async throws {
        guard let fromUserId = currentUserProfile?.id else {
            throw SocialError.notAuthenticated
        }

        guard fromUserId != toUserId else {
            throw SocialError.cannotConnectToSelf
        }

        // Check limits
        if let max = level.maxAllowed {
            let currentCount = await countConnections(ofLevel: level)
            if currentCount >= max {
                throw SocialError.connectionLimitReached(level: level)
            }
        }

        // Check if request already exists
        let existingRequest = try await requestsCollection
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .whereField("status", isEqualTo: ConnectionRequestStatus.pending.rawValue)
            .getDocuments()

        if !existingRequest.documents.isEmpty {
            throw SocialError.requestAlreadyPending
        }

        // Check if connection already exists
        let connectionId = Connection.createId(user1: fromUserId, user2: toUserId)
        let existingConnection = try await connectionsCollection.document(connectionId).getDocument()

        if existingConnection.exists {
            throw SocialError.alreadyConnected
        }

        // Get sender info for the request
        let senderProfile = currentUserProfile

        // Create request
        let requestId = UUID().uuidString
        var requestData: [String: Any] = [
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "requestedLevel": level.rawValue,
            "status": ConnectionRequestStatus.pending.rawValue,
            "createdAt": Timestamp(date: Date())
        ]

        if let message = message, !message.isEmpty {
            requestData["message"] = message
        }

        // Include sender display info for easier querying
        if let sender = senderProfile {
            requestData["fromUserDisplayName"] = sender.displayName
            requestData["fromUserUsername"] = sender.username
            if let imageURL = sender.profileImageURL {
                requestData["fromUserProfileImageURL"] = imageURL
            }
        }

        try await requestsCollection.document(requestId).setData(requestData)
    }

    /// Respond to a connection request
    func respondToRequest(_ requestId: String, accept: Bool) async throws {
        guard let currentUserId = currentUserProfile?.id else {
            throw SocialError.notAuthenticated
        }

        let requestDoc = try await requestsCollection.document(requestId).getDocument()
        guard let request = ConnectionRequest(document: requestDoc) else {
            throw SocialError.requestNotFound
        }

        // Verify this request is for current user
        guard request.toUserId == currentUserId else {
            throw SocialError.unauthorized
        }

        // Verify request is still pending
        guard request.status == .pending else {
            throw SocialError.requestAlreadyResponded
        }

        if accept {
            // Check limits before accepting
            if let max = request.requestedLevel.maxAllowed {
                let currentCount = await countConnections(ofLevel: request.requestedLevel)
                if currentCount >= max {
                    throw SocialError.connectionLimitReached(level: request.requestedLevel)
                }
            }

            // Create connection
            let connectionId = Connection.createId(user1: request.fromUserId, user2: request.toUserId)
            let sorted = [request.fromUserId, request.toUserId].sorted()

            let connectionData: [String: Any] = [
                "user1Id": sorted[0],
                "user2Id": sorted[1],
                "level": request.requestedLevel.rawValue,
                "createdAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date())
            ]

            try await connectionsCollection.document(connectionId).setData(connectionData)

            // Update connection counts for both users
            await updateConnectionCounts(for: request.fromUserId)
            await updateConnectionCounts(for: request.toUserId)
        }

        // Update request status
        try await requestsCollection.document(requestId).updateData([
            "status": accept ? ConnectionRequestStatus.accepted.rawValue : ConnectionRequestStatus.declined.rawValue,
            "respondedAt": Timestamp(date: Date())
        ])

        // Refresh local state
        await loadConnections()
        await loadPendingRequests()
    }

    /// Cancel a sent request
    func cancelRequest(_ requestId: String) async throws {
        guard let currentUserId = currentUserProfile?.id else {
            throw SocialError.notAuthenticated
        }

        let requestDoc = try await requestsCollection.document(requestId).getDocument()
        guard let request = ConnectionRequest(document: requestDoc) else {
            throw SocialError.requestNotFound
        }

        // Verify current user sent this request
        guard request.fromUserId == currentUserId else {
            throw SocialError.unauthorized
        }

        // Can only cancel pending requests
        guard request.status == .pending else {
            throw SocialError.requestAlreadyResponded
        }

        try await requestsCollection.document(requestId).updateData([
            "status": ConnectionRequestStatus.cancelled.rawValue,
            "respondedAt": Timestamp(date: Date())
        ])

        await loadSentRequests()
    }

    // MARK: - Connection Operations

    /// Load all connections for current user
    func loadConnections() async {
        guard let userId = currentUserProfile?.id else { return }

        do {
            // Query where user is user1
            let query1 = try await connectionsCollection
                .whereField("user1Id", isEqualTo: userId)
                .getDocuments()

            // Query where user is user2
            let query2 = try await connectionsCollection
                .whereField("user2Id", isEqualTo: userId)
                .getDocuments()

            let allConnections = (query1.documents + query2.documents)
                .compactMap { Connection(document: $0) }

            self.connections = allConnections

            // Fetch profiles for connections and categorize
            var friendProfiles: [UserProfile] = []
            var flowPartnerProfiles: [UserProfile] = []
            var observerProfiles: [UserProfile] = []

            for connection in allConnections {
                let otherUserId = connection.otherUserId(currentUserId: userId)
                if let profile = await fetchProfile(userId: otherUserId) {
                    switch connection.level {
                    case .observer:
                        observerProfiles.append(profile)
                    case .friend:
                        friendProfiles.append(profile)
                    case .flowPartner:
                        flowPartnerProfiles.append(profile)
                    case .mentor, .mentee:
                        // Group mentors/mentees with friends for now
                        friendProfiles.append(profile)
                    }
                }
            }

            self.friends = friendProfiles
            self.flowPartners = flowPartnerProfiles
            self.observers = observerProfiles

        } catch {
            self.error = "Failed to load connections: \(error.localizedDescription)"
        }
    }

    /// Load pending requests for current user (received)
    func loadPendingRequests() async {
        guard let userId = currentUserProfile?.id else { return }

        do {
            let snapshot = try await requestsCollection
                .whereField("toUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: ConnectionRequestStatus.pending.rawValue)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            self.pendingRequests = snapshot.documents.compactMap { ConnectionRequest(document: $0) }
        } catch {
            self.error = "Failed to load requests: \(error.localizedDescription)"
        }
    }

    /// Load sent requests (outgoing)
    func loadSentRequests() async {
        guard let userId = currentUserProfile?.id else { return }

        do {
            let snapshot = try await requestsCollection
                .whereField("fromUserId", isEqualTo: userId)
                .whereField("status", isEqualTo: ConnectionRequestStatus.pending.rawValue)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            self.sentRequests = snapshot.documents.compactMap { ConnectionRequest(document: $0) }
        } catch {
            self.error = "Failed to load sent requests: \(error.localizedDescription)"
        }
    }

    /// Upgrade a connection level
    func upgradeConnection(with userId: String, to newLevel: ConnectionLevel) async throws {
        guard let currentUserId = currentUserProfile?.id else {
            throw SocialError.notAuthenticated
        }

        // Check limits for new level
        if let max = newLevel.maxAllowed {
            let currentCount = await countConnections(ofLevel: newLevel)
            if currentCount >= max {
                throw SocialError.connectionLimitReached(level: newLevel)
            }
        }

        let connectionId = Connection.createId(user1: currentUserId, user2: userId)

        try await connectionsCollection.document(connectionId).updateData([
            "level": newLevel.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])

        await updateConnectionCounts(for: currentUserId)
        await updateConnectionCounts(for: userId)
        await loadConnections()
    }

    /// Remove a connection
    func removeConnection(with userId: String) async throws {
        guard let currentUserId = currentUserProfile?.id else {
            throw SocialError.notAuthenticated
        }

        let connectionId = Connection.createId(user1: currentUserId, user2: userId)
        try await connectionsCollection.document(connectionId).delete()

        // Update counts
        await updateConnectionCounts(for: currentUserId)
        await updateConnectionCounts(for: userId)

        await loadConnections()
    }

    /// Get connection level with a specific user
    func getConnectionLevel(with userId: String) async -> ConnectionLevel? {
        guard let currentUserId = currentUserProfile?.id else { return nil }

        let connectionId = Connection.createId(user1: currentUserId, user2: userId)

        do {
            let doc = try await connectionsCollection.document(connectionId).getDocument()
            guard let connection = Connection(document: doc) else { return nil }
            return connection.level
        } catch {
            return nil
        }
    }

    // MARK: - Real-time Listeners

    /// Start listening for real-time connection updates
    func startListeningForUpdates() {
        guard let userId = currentUserProfile?.id else { return }

        // Listen for incoming requests
        let requestListener = requestsCollection
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: ConnectionRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.pendingRequests = documents.compactMap { ConnectionRequest(document: $0) }
                }
            }

        connectionListeners.append(requestListener)
    }

    /// Stop all listeners
    func stopListening() {
        connectionListeners.forEach { $0.remove() }
        connectionListeners.removeAll()
    }

    // MARK: - Helper Methods

    private func countConnections(ofLevel level: ConnectionLevel) async -> Int {
        guard let userId = currentUserProfile?.id else { return 0 }

        do {
            let query1 = try await connectionsCollection
                .whereField("user1Id", isEqualTo: userId)
                .whereField("level", isEqualTo: level.rawValue)
                .getDocuments()

            let query2 = try await connectionsCollection
                .whereField("user2Id", isEqualTo: userId)
                .whereField("level", isEqualTo: level.rawValue)
                .getDocuments()

            return query1.documents.count + query2.documents.count
        } catch {
            return 0
        }
    }

    private func updateConnectionCounts(for userId: String) async {
        var counts = ConnectionCounts()

        for level in ConnectionLevel.allCases {
            let query1 = try? await connectionsCollection
                .whereField("user1Id", isEqualTo: userId)
                .whereField("level", isEqualTo: level.rawValue)
                .getDocuments()

            let query2 = try? await connectionsCollection
                .whereField("user2Id", isEqualTo: userId)
                .whereField("level", isEqualTo: level.rawValue)
                .getDocuments()

            let count = (query1?.documents.count ?? 0) + (query2?.documents.count ?? 0)

            switch level {
            case .observer: counts.observers = count
            case .friend: counts.friends = count
            case .flowPartner: counts.flowPartners = count
            case .mentor: counts.mentors = count
            case .mentee: counts.mentees = count
            }
        }

        try? await profilesCollection.document(userId).updateData([
            "connectionCounts": [
                "observers": counts.observers,
                "friends": counts.friends,
                "flowPartners": counts.flowPartners,
                "mentors": counts.mentors,
                "mentees": counts.mentees
            ],
            "updatedAt": Timestamp(date: Date())
        ])
    }

    private func createDefaultProfile(userId: String, email: String?) -> UserProfile {
        // Generate username from email or random
        let baseUsername: String
        if let email = email, let atIndex = email.firstIndex(of: "@") {
            baseUsername = String(email[..<atIndex]).lowercased()
                .replacingOccurrences(of: ".", with: "_")
                .replacingOccurrences(of: "+", with: "_")
        } else {
            baseUsername = "user_\(String(userId.prefix(8)))"
        }

        return UserProfile(
            id: userId,
            username: baseUsername,
            displayName: "New User",
            bio: "",
            profileImageURL: nil,
            chronotype: .intermediate,
            peakFlowWindows: [],
            masteryDurationDays: 0,
            gardenAgeDays: 0,
            thirtyDayTrajectory: 0,
            consistencyPercentile: 50,
            totalPlantsGrown: 0,
            speciesUnlocked: 0,
            connectionCounts: ConnectionCounts(),
            gardenVisibility: .friendsOnly,
            currentIntention: nil,
            currentProtocolId: nil,
            skillBadges: [],
            comparisonMode: .inspiration,
            philosophyMomentsEnabled: true,
            socialOnboardingCompleted: false,
            socialOnboardingCompletedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - Social Errors

enum SocialError: LocalizedError {
    case notAuthenticated
    case connectionLimitReached(level: ConnectionLevel)
    case requestAlreadyPending
    case requestAlreadyResponded
    case alreadyConnected
    case requestNotFound
    case unauthorized
    case cannotConnectToSelf
    case usernameTaken
    case invalidUsername(String)
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in"
        case .connectionLimitReached(let level):
            if let max = level.maxAllowed {
                return "You've reached the maximum of \(max) \(level.displayName.lowercased())s"
            }
            return "Connection limit reached"
        case .requestAlreadyPending:
            return "You already have a pending request to this user"
        case .requestAlreadyResponded:
            return "This request has already been responded to"
        case .alreadyConnected:
            return "You're already connected with this user"
        case .requestNotFound:
            return "Request not found"
        case .unauthorized:
            return "You're not authorized for this action"
        case .cannotConnectToSelf:
            return "You cannot connect with yourself"
        case .usernameTaken:
            return "This username is already taken"
        case .invalidUsername(let reason):
            return reason
        case .profileNotFound:
            return "Profile not found"
        }
    }
}
