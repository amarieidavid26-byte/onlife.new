import Foundation
import FirebaseFirestore

// MARK: - Connection Level

enum ConnectionLevel: String, Codable, CaseIterable, Comparable {
    case observer = "observer"
    case friend = "friend"
    case flowPartner = "flowPartner"
    case mentor = "mentor"
    case mentee = "mentee"

    var displayName: String {
        switch self {
        case .observer: return "Observer"
        case .friend: return "Friend"
        case .flowPartner: return "Flow Partner"
        case .mentor: return "Mentor"
        case .mentee: return "Mentee"
        }
    }

    var description: String {
        switch self {
        case .observer: return "Can see public activity"
        case .friend: return "Mutual support and visibility"
        case .flowPartner: return "Deep learning partnership (max 5)"
        case .mentor: return "Guides your flow journey"
        case .mentee: return "You guide their journey"
        }
    }

    var icon: String {
        switch self {
        case .observer: return "eye"
        case .friend: return "person.2"
        case .flowPartner: return "person.2.wave.2"
        case .mentor: return "graduationcap"
        case .mentee: return "studentdesk"
        }
    }

    var maxAllowed: Int? {
        switch self {
        case .observer: return nil  // Unlimited
        case .friend: return 150    // Dunbar's number
        case .flowPartner: return 5
        case .mentor: return 3
        case .mentee: return 10
        }
    }

    var visibilityLevel: Int {
        switch self {
        case .observer: return 1
        case .friend: return 2
        case .flowPartner: return 3
        case .mentor, .mentee: return 4
        }
    }

    /// What this connection level can see
    var visibilityPermissions: [VisibilityPermission] {
        switch self {
        case .observer:
            return [.gardenOverview, .badges]
        case .friend:
            return [.gardenOverview, .badges, .flowConsistency, .sessionFrequency, .flowScores, .patterns, .achievements]
        case .flowPartner:
            return [.gardenOverview, .badges, .flowConsistency, .sessionFrequency, .flowScores, .patterns, .achievements, .detailedMetrics, .struggles, .protocols]
        case .mentor, .mentee:
            return VisibilityPermission.allCases
        }
    }

    static func < (lhs: ConnectionLevel, rhs: ConnectionLevel) -> Bool {
        lhs.visibilityLevel < rhs.visibilityLevel
    }
}

// MARK: - Visibility Permission

enum VisibilityPermission: String, Codable, CaseIterable {
    case gardenOverview
    case badges
    case flowConsistency
    case sessionFrequency
    case flowScores
    case patterns
    case achievements
    case detailedMetrics
    case struggles
    case protocols
    case fullDataAccess
    case coachingContext
}

// MARK: - Connection Request Status

enum ConnectionRequestStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case cancelled = "cancelled"
}

// MARK: - Connection Request

struct ConnectionRequest: Codable, Identifiable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let requestedLevel: ConnectionLevel
    let message: String?
    var status: ConnectionRequestStatus
    let createdAt: Date
    var respondedAt: Date?

    // For display purposes (populated by fetch)
    var fromUserDisplayName: String?
    var fromUserUsername: String?
    var fromUserProfileImageURL: String?

    init(
        id: String = UUID().uuidString,
        fromUserId: String,
        toUserId: String,
        requestedLevel: ConnectionLevel,
        message: String? = nil,
        status: ConnectionRequestStatus = .pending,
        createdAt: Date = Date(),
        respondedAt: Date? = nil
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.requestedLevel = requestedLevel
        self.message = message
        self.status = status
        self.createdAt = createdAt
        self.respondedAt = respondedAt
    }
}

// MARK: - Connection (Active relationship)

struct Connection: Codable, Identifiable {
    let id: String
    let user1Id: String  // Alphabetically first
    let user2Id: String  // Alphabetically second
    var level: ConnectionLevel
    let createdAt: Date
    var updatedAt: Date

    // For display purposes (populated by fetch)
    var otherUserProfile: UserProfile?

    func otherUserId(currentUserId: String) -> String {
        return user1Id == currentUserId ? user2Id : user1Id
    }

    static func createId(user1: String, user2: String) -> String {
        // Always use alphabetical order for consistent IDs
        let sorted = [user1, user2].sorted()
        return "\(sorted[0])_\(sorted[1])"
    }

    init(
        id: String? = nil,
        user1Id: String,
        user2Id: String,
        level: ConnectionLevel,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let sorted = [user1Id, user2Id].sorted()
        self.id = id ?? Connection.createId(user1: user1Id, user2: user2Id)
        self.user1Id = sorted[0]
        self.user2Id = sorted[1]
        self.level = level
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Firebase Extensions

extension Connection {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.user1Id = data["user1Id"] as? String ?? ""
        self.user2Id = data["user2Id"] as? String ?? ""

        if let levelRaw = data["level"] as? String {
            self.level = ConnectionLevel(rawValue: levelRaw) ?? .friend
        } else {
            self.level = .friend
        }

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }

        if let timestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = Date()
        }
    }

    func toFirestoreData() -> [String: Any] {
        return [
            "user1Id": user1Id,
            "user2Id": user2Id,
            "level": level.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: Date())
        ]
    }
}

extension ConnectionRequest {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.fromUserId = data["fromUserId"] as? String ?? ""
        self.toUserId = data["toUserId"] as? String ?? ""

        if let levelRaw = data["requestedLevel"] as? String {
            self.requestedLevel = ConnectionLevel(rawValue: levelRaw) ?? .friend
        } else {
            self.requestedLevel = .friend
        }

        self.message = data["message"] as? String

        if let statusRaw = data["status"] as? String {
            self.status = ConnectionRequestStatus(rawValue: statusRaw) ?? .pending
        } else {
            self.status = .pending
        }

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }

        if let timestamp = data["respondedAt"] as? Timestamp {
            self.respondedAt = timestamp.dateValue()
        } else {
            self.respondedAt = nil
        }

        // Display fields (populated separately)
        self.fromUserDisplayName = data["fromUserDisplayName"] as? String
        self.fromUserUsername = data["fromUserUsername"] as? String
        self.fromUserProfileImageURL = data["fromUserProfileImageURL"] as? String
    }

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "requestedLevel": requestedLevel.rawValue,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt)
        ]

        if let message = message {
            data["message"] = message
        }

        if let respondedAt = respondedAt {
            data["respondedAt"] = Timestamp(date: respondedAt)
        }

        return data
    }
}
