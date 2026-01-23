import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Protocol Filter

struct ProtocolFilter {
    var chronotype: Chronotype?
    var activityType: ProtocolActivityType?
    var minRating: Double?
    var minTryCount: Int?
    var sortBy: ProtocolSortOption = .popularity

    static var `default`: ProtocolFilter {
        ProtocolFilter()
    }
}

enum ProtocolSortOption: String, CaseIterable {
    case popularity = "Most Tried"
    case rating = "Highest Rated"
    case newest = "Newest"
    case improvement = "Best Results"

    var icon: String {
        switch self {
        case .popularity: return "flame"
        case .rating: return "star"
        case .newest: return "clock"
        case .improvement: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Protocol Service

@MainActor
class ProtocolService: ObservableObject {

    static let shared = ProtocolService()

    private let db = Firestore.firestore()
    private let socialService = SocialService.shared

    // MARK: - Published State

    @Published var publicProtocols: [FlowProtocol] = []
    @Published var myProtocols: [FlowProtocol] = []
    @Published var savedProtocols: [FlowProtocol] = []
    @Published var currentProtocol: FlowProtocol?
    @Published var recommendedProtocols: [FlowProtocol] = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Collections

    private var protocolsCollection: CollectionReference {
        db.collection("protocols")
    }

    private var trialsCollection: CollectionReference {
        db.collection("protocolTrials")
    }

    private var savedProtocolsCollection: CollectionReference {
        db.collection("savedProtocols")
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Protocol CRUD

    /// Create a new protocol
    func createProtocol(
        title: String,
        description: String,
        substances: [SubstanceEntry],
        sessionDurationMinutes: Int,
        breakDurationMinutes: Int? = nil,
        blocksPerSession: Int = 1,
        targetChronotype: Chronotype? = nil,
        bestForActivities: [ProtocolActivityType] = [],
        isPublic: Bool = true
    ) async throws -> FlowProtocol {

        guard let userId = Auth.auth().currentUser?.uid,
              let profile = socialService.currentUserProfile else {
            throw ProtocolError.notAuthenticated
        }

        let protocolId = UUID().uuidString

        let newProtocol = FlowProtocol(
            id: protocolId,
            creatorId: userId,
            creatorUsername: profile.username,
            title: title,
            description: description,
            substances: substances,
            sessionDurationMinutes: sessionDurationMinutes,
            breakDurationMinutes: breakDurationMinutes,
            blocksPerSession: blocksPerSession,
            targetChronotype: targetChronotype,
            bestForActivities: bestForActivities,
            forkedFromId: nil,
            forkCount: 0,
            tryCount: 0,
            averageFlowImprovement: 0,
            averageRating: 0,
            ratingsCount: 0,
            isPublic: isPublic,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await protocolsCollection.document(protocolId).setData(newProtocol.toFirestoreData())

        await loadMyProtocols()

        return newProtocol
    }

    /// Update an existing protocol
    func updateProtocol(_ protocol: FlowProtocol, updates: [String: Any]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProtocolError.notAuthenticated
        }

        // Verify ownership
        guard `protocol`.creatorId == userId else {
            throw ProtocolError.notOwner
        }

        var updatedData = updates
        updatedData["updatedAt"] = Timestamp(date: Date())

        try await protocolsCollection.document(`protocol`.id).updateData(updatedData)

        await loadMyProtocols()
    }

    /// Delete a protocol
    func deleteProtocol(_ protocolId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProtocolError.notAuthenticated
        }

        // Verify ownership
        let doc = try await protocolsCollection.document(protocolId).getDocument()
        guard let protocolData = doc.data(),
              let creatorId = protocolData["creatorId"] as? String,
              creatorId == userId else {
            throw ProtocolError.notOwner
        }

        try await protocolsCollection.document(protocolId).delete()

        await loadMyProtocols()
    }

    /// Fork a protocol (create a copy with modifications)
    func forkProtocol(_ originalProtocol: FlowProtocol) async throws -> FlowProtocol {
        guard let userId = Auth.auth().currentUser?.uid,
              let profile = socialService.currentUserProfile else {
            throw ProtocolError.notAuthenticated
        }

        let forkedId = UUID().uuidString

        let forkedProtocol = FlowProtocol(
            id: forkedId,
            creatorId: userId,
            creatorUsername: profile.username,
            title: "\(originalProtocol.title) (Fork)",
            description: originalProtocol.description,
            substances: originalProtocol.substances,
            sessionDurationMinutes: originalProtocol.sessionDurationMinutes,
            breakDurationMinutes: originalProtocol.breakDurationMinutes,
            blocksPerSession: originalProtocol.blocksPerSession,
            targetChronotype: originalProtocol.targetChronotype,
            bestForActivities: originalProtocol.bestForActivities,
            forkedFromId: originalProtocol.id,
            forkCount: 0,
            tryCount: 0,
            averageFlowImprovement: 0,
            averageRating: 0,
            ratingsCount: 0,
            isPublic: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await protocolsCollection.document(forkedId).setData(forkedProtocol.toFirestoreData())

        // Increment fork count on original
        try await protocolsCollection.document(originalProtocol.id).updateData([
            "forkCount": FieldValue.increment(Int64(1))
        ])

        await loadMyProtocols()

        return forkedProtocol
    }

    // MARK: - Protocol Loading

    /// Load protocols created by current user
    func loadMyProtocols() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            let snapshot = try await protocolsCollection
                .whereField("creatorId", isEqualTo: userId)
                .order(by: "updatedAt", descending: true)
                .getDocuments()

            self.myProtocols = snapshot.documents.compactMap { FlowProtocol(document: $0) }
        } catch {
            self.error = "Failed to load your protocols: \(error.localizedDescription)"
        }
    }

    /// Load public protocols with optional filtering
    func loadPublicProtocols(filter: ProtocolFilter = .default, limit: Int = 50) async {
        isLoading = true
        defer { isLoading = false }

        do {
            var query: Query = protocolsCollection
                .whereField("isPublic", isEqualTo: true)

            // Apply filters
            if let chronotype = filter.chronotype {
                query = query.whereField("targetChronotype", isEqualTo: chronotype.rawValue)
            }

            if let minRating = filter.minRating {
                query = query.whereField("averageRating", isGreaterThanOrEqualTo: minRating)
            }

            if let minTryCount = filter.minTryCount {
                query = query.whereField("tryCount", isGreaterThanOrEqualTo: minTryCount)
            }

            // Apply sorting
            switch filter.sortBy {
            case .popularity:
                query = query.order(by: "tryCount", descending: true)
            case .rating:
                query = query.order(by: "averageRating", descending: true)
            case .newest:
                query = query.order(by: "createdAt", descending: true)
            case .improvement:
                query = query.order(by: "averageFlowImprovement", descending: true)
            }

            let snapshot = try await query.limit(to: limit).getDocuments()

            var protocols = snapshot.documents.compactMap { FlowProtocol(document: $0) }

            // Filter by activity type in memory (Firestore doesn't support array-contains with other where clauses well)
            if let activityType = filter.activityType {
                protocols = protocols.filter { $0.bestForActivities.contains(activityType) }
            }

            self.publicProtocols = protocols

        } catch {
            self.error = "Failed to load protocols: \(error.localizedDescription)"
        }
    }

    /// Load protocols saved by current user
    func loadSavedProtocols() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            let savedSnapshot = try await savedProtocolsCollection
                .whereField("userId", isEqualTo: userId)
                .getDocuments()

            let protocolIds = savedSnapshot.documents.compactMap { $0.data()["protocolId"] as? String }

            var protocols: [FlowProtocol] = []
            for protocolId in protocolIds {
                let doc = try await protocolsCollection.document(protocolId).getDocument()
                if let proto = FlowProtocol(document: doc) {
                    protocols.append(proto)
                }
            }

            self.savedProtocols = protocols

        } catch {
            self.error = "Failed to load saved protocols: \(error.localizedDescription)"
        }
    }

    /// Load a single protocol by ID
    func loadProtocol(id: String) async -> FlowProtocol? {
        do {
            let doc = try await protocolsCollection.document(id).getDocument()
            return FlowProtocol(document: doc)
        } catch {
            self.error = "Failed to load protocol: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Protocol Recommendations

    /// Get recommended protocols based on user's profile
    func loadRecommendedProtocols() async {
        guard let profile = socialService.currentUserProfile else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Get protocols matching user's chronotype
            let chronotypeQuery = try await protocolsCollection
                .whereField("isPublic", isEqualTo: true)
                .whereField("targetChronotype", isEqualTo: profile.chronotype.rawValue)
                .whereField("tryCount", isGreaterThan: 5)
                .order(by: "tryCount", descending: true)
                .order(by: "averageRating", descending: true)
                .limit(to: 10)
                .getDocuments()

            var recommended = chronotypeQuery.documents.compactMap { FlowProtocol(document: $0) }

            // If not enough, fill with high-rated protocols
            if recommended.count < 5 {
                let topRated = try await protocolsCollection
                    .whereField("isPublic", isEqualTo: true)
                    .whereField("ratingsCount", isGreaterThan: 10)
                    .order(by: "ratingsCount", descending: true)
                    .order(by: "averageRating", descending: true)
                    .limit(to: 10)
                    .getDocuments()

                let additional = topRated.documents
                    .compactMap { FlowProtocol(document: $0) }
                    .filter { proto in !recommended.contains { $0.id == proto.id } }

                recommended.append(contentsOf: additional.prefix(5 - recommended.count))
            }

            self.recommendedProtocols = recommended

        } catch {
            self.error = "Failed to load recommendations: \(error.localizedDescription)"
        }
    }

    // MARK: - Protocol Saving

    /// Save a protocol to user's collection
    func saveProtocol(_ protocolId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProtocolError.notAuthenticated
        }

        let saveId = "\(userId)_\(protocolId)"

        try await savedProtocolsCollection.document(saveId).setData([
            "userId": userId,
            "protocolId": protocolId,
            "savedAt": Timestamp(date: Date())
        ])

        await loadSavedProtocols()
    }

    /// Unsave a protocol
    func unsaveProtocol(_ protocolId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProtocolError.notAuthenticated
        }

        let saveId = "\(userId)_\(protocolId)"
        try await savedProtocolsCollection.document(saveId).delete()

        await loadSavedProtocols()
    }

    /// Check if a protocol is saved
    func isProtocolSaved(_ protocolId: String) -> Bool {
        savedProtocols.contains { $0.id == protocolId }
    }

    // MARK: - Protocol Trials

    /// Record a trial of a protocol
    func recordTrial(
        protocolId: String,
        sessionId: String,
        flowScoreAchieved: Int?,
        flowImprovement: Double?,
        rating: Int?,
        notes: String?
    ) async throws {

        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProtocolError.notAuthenticated
        }

        let trialId = UUID().uuidString

        var trialData: [String: Any] = [
            "userId": userId,
            "protocolId": protocolId,
            "sessionId": sessionId,
            "triedAt": Timestamp(date: Date())
        ]

        if let flowScore = flowScoreAchieved {
            trialData["flowScoreAchieved"] = flowScore
        }
        if let improvement = flowImprovement {
            trialData["flowImprovement"] = improvement
        }
        if let rating = rating {
            trialData["rating"] = rating
        }
        if let notes = notes, !notes.isEmpty {
            trialData["notes"] = notes
        }

        try await trialsCollection.document(trialId).setData(trialData)

        // Update protocol statistics
        await updateProtocolStats(protocolId: protocolId)
    }

    /// Rate a protocol (or update existing rating)
    func rateProtocol(_ protocolId: String, rating: Int, notes: String? = nil) async throws {
        guard rating >= 1 && rating <= 5 else {
            throw ProtocolError.invalidRating
        }

        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProtocolError.notAuthenticated
        }

        // Check for existing trial to update
        let existingTrials = try await trialsCollection
            .whereField("userId", isEqualTo: userId)
            .whereField("protocolId", isEqualTo: protocolId)
            .order(by: "triedAt", descending: true)
            .limit(to: 1)
            .getDocuments()

        if let existingDoc = existingTrials.documents.first {
            // Update existing trial
            var updateData: [String: Any] = ["rating": rating]
            if let notes = notes {
                updateData["notes"] = notes
            }
            try await trialsCollection.document(existingDoc.documentID).updateData(updateData)
        } else {
            // Create new trial with just rating
            try await recordTrial(
                protocolId: protocolId,
                sessionId: "",
                flowScoreAchieved: nil,
                flowImprovement: nil,
                rating: rating,
                notes: notes
            )
        }

        await updateProtocolStats(protocolId: protocolId)
    }

    /// Get user's trials of a specific protocol
    func getUserTrials(for protocolId: String) async -> [ProtocolTrial] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }

        do {
            let snapshot = try await trialsCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("protocolId", isEqualTo: protocolId)
                .order(by: "triedAt", descending: true)
                .getDocuments()

            return snapshot.documents.compactMap { ProtocolTrial(document: $0) }
        } catch {
            return []
        }
    }

    // MARK: - Statistics

    private func updateProtocolStats(protocolId: String) async {
        do {
            let trials = try await trialsCollection
                .whereField("protocolId", isEqualTo: protocolId)
                .getDocuments()

            let tryCount = trials.documents.count

            // Calculate average rating
            let ratings = trials.documents.compactMap { $0.data()["rating"] as? Int }
            let avgRating = ratings.isEmpty ? 0.0 : Double(ratings.reduce(0, +)) / Double(ratings.count)

            // Calculate average flow improvement
            let improvements = trials.documents.compactMap { $0.data()["flowImprovement"] as? Double }
            let avgImprovement = improvements.isEmpty ? 0.0 : improvements.reduce(0, +) / Double(improvements.count)

            try await protocolsCollection.document(protocolId).updateData([
                "tryCount": tryCount,
                "averageRating": avgRating,
                "ratingsCount": ratings.count,
                "averageFlowImprovement": avgImprovement,
                "updatedAt": Timestamp(date: Date())
            ])

        } catch {
            self.error = "Failed to update protocol stats: \(error.localizedDescription)"
        }
    }

    // MARK: - Current Protocol

    /// Set user's current active protocol
    func setCurrentProtocol(_ protocolId: String?) async throws {
        try await socialService.updateCurrentProfile([
            "currentProtocolId": protocolId as Any
        ])

        if let protocolId = protocolId {
            currentProtocol = await loadProtocol(id: protocolId)
        } else {
            currentProtocol = nil
        }
    }

    /// Load user's current protocol
    func loadCurrentProtocol() async {
        guard let protocolId = socialService.currentUserProfile?.currentProtocolId,
              !protocolId.isEmpty else {
            currentProtocol = nil
            return
        }

        currentProtocol = await loadProtocol(id: protocolId)
    }
}

// MARK: - Protocol Errors

enum ProtocolError: LocalizedError {
    case notAuthenticated
    case notOwner
    case notFound
    case invalidRating

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in"
        case .notOwner:
            return "You can only modify protocols you created"
        case .notFound:
            return "Protocol not found"
        case .invalidRating:
            return "Rating must be between 1 and 5"
        }
    }
}
