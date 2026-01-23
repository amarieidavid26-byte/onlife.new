import Foundation
import FirebaseFirestore

// MARK: - Substance Entry

struct SubstanceEntry: Codable, Identifiable, Hashable {
    let id: String
    let substanceName: String  // "Caffeine", "L-theanine"
    let doseMg: Int
    let timingMinutes: Int  // Minutes before/after session start (negative = before)

    var timingDescription: String {
        if timingMinutes == 0 {
            return "At session start"
        } else if timingMinutes < 0 {
            return "\(abs(timingMinutes)) min before"
        } else {
            return "\(timingMinutes) min after start"
        }
    }

    var formattedDose: String {
        if doseMg >= 1000 {
            let grams = Double(doseMg) / 1000.0
            return String(format: "%.1fg", grams)
        }
        return "\(doseMg)mg"
    }

    init(
        id: String = UUID().uuidString,
        substanceName: String,
        doseMg: Int,
        timingMinutes: Int
    ) {
        self.id = id
        self.substanceName = substanceName
        self.doseMg = doseMg
        self.timingMinutes = timingMinutes
    }
}

// MARK: - Protocol Activity Type

enum ProtocolActivityType: String, Codable, CaseIterable {
    case coding = "coding"
    case writing = "writing"
    case design = "design"
    case reading = "reading"
    case studying = "studying"
    case creative = "creative"
    case administrative = "administrative"
    case other = "other"

    var displayName: String {
        switch self {
        case .coding: return "Coding"
        case .writing: return "Writing"
        case .design: return "Design"
        case .reading: return "Reading"
        case .studying: return "Studying"
        case .creative: return "Creative Work"
        case .administrative: return "Admin Tasks"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .writing: return "pencil.line"
        case .design: return "paintbrush"
        case .reading: return "book"
        case .studying: return "text.book.closed"
        case .creative: return "sparkles"
        case .administrative: return "doc.text"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Flow Protocol

struct FlowProtocol: Codable, Identifiable {
    let id: String
    let creatorId: String
    var creatorUsername: String

    var title: String
    var description: String

    // Protocol details
    var substances: [SubstanceEntry]
    var sessionDurationMinutes: Int
    var breakDurationMinutes: Int?
    var blocksPerSession: Int

    // Targeting
    var targetChronotype: Chronotype?
    var bestForActivities: [ProtocolActivityType]

    // Forking
    var forkedFromId: String?  // If this is a fork
    var forkCount: Int

    // Results (aggregated from users who tried)
    var tryCount: Int
    var averageFlowImprovement: Double  // Percentage
    var averageRating: Double  // 1-5
    var ratingsCount: Int

    // Visibility
    var isPublic: Bool

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    var ratingStars: String {
        let fullStars = Int(averageRating)
        let hasHalf = averageRating - Double(fullStars) >= 0.5
        var result = ""
        for _ in 0..<fullStars {
            result += "★"
        }
        if hasHalf {
            result += "½"
        }
        let emptyStars = 5 - fullStars - (hasHalf ? 1 : 0)
        for _ in 0..<emptyStars {
            result += "☆"
        }
        return result
    }

    var formattedDuration: String {
        if sessionDurationMinutes >= 60 {
            let hours = sessionDurationMinutes / 60
            let minutes = sessionDurationMinutes % 60
            if minutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(minutes)m"
        }
        return "\(sessionDurationMinutes)m"
    }

    var totalSessionTime: Int {
        let breakTime = (breakDurationMinutes ?? 0) * max(0, blocksPerSession - 1)
        return (sessionDurationMinutes * blocksPerSession) + breakTime
    }

    var formattedTotalTime: String {
        let total = totalSessionTime
        if total >= 60 {
            let hours = total / 60
            let minutes = total % 60
            if minutes == 0 {
                return "\(hours)h total"
            }
            return "\(hours)h \(minutes)m total"
        }
        return "\(total)m total"
    }

    var improvementDescription: String {
        if averageFlowImprovement > 0 {
            return "+\(Int(averageFlowImprovement))% flow improvement"
        } else if averageFlowImprovement < 0 {
            return "\(Int(averageFlowImprovement))% flow change"
        }
        return "No change reported"
    }

    // MARK: - Initializer

    init(
        id: String = UUID().uuidString,
        creatorId: String,
        creatorUsername: String,
        title: String,
        description: String,
        substances: [SubstanceEntry] = [],
        sessionDurationMinutes: Int = 60,
        breakDurationMinutes: Int? = nil,
        blocksPerSession: Int = 1,
        targetChronotype: Chronotype? = nil,
        bestForActivities: [ProtocolActivityType] = [],
        forkedFromId: String? = nil,
        forkCount: Int = 0,
        tryCount: Int = 0,
        averageFlowImprovement: Double = 0,
        averageRating: Double = 0,
        ratingsCount: Int = 0,
        isPublic: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.creatorId = creatorId
        self.creatorUsername = creatorUsername
        self.title = title
        self.description = description
        self.substances = substances
        self.sessionDurationMinutes = sessionDurationMinutes
        self.breakDurationMinutes = breakDurationMinutes
        self.blocksPerSession = blocksPerSession
        self.targetChronotype = targetChronotype
        self.bestForActivities = bestForActivities
        self.forkedFromId = forkedFromId
        self.forkCount = forkCount
        self.tryCount = tryCount
        self.averageFlowImprovement = averageFlowImprovement
        self.averageRating = averageRating
        self.ratingsCount = ratingsCount
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Protocol Trial (User's experience with a protocol)

struct ProtocolTrial: Codable, Identifiable {
    let id: String
    let userId: String
    let protocolId: String
    let sessionId: String

    // Results
    var flowScoreAchieved: Int?
    var flowImprovement: Double?  // vs user's baseline
    var rating: Int?  // 1-5
    var notes: String?

    var triedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        protocolId: String,
        sessionId: String,
        flowScoreAchieved: Int? = nil,
        flowImprovement: Double? = nil,
        rating: Int? = nil,
        notes: String? = nil,
        triedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.protocolId = protocolId
        self.sessionId = sessionId
        self.flowScoreAchieved = flowScoreAchieved
        self.flowImprovement = flowImprovement
        self.rating = rating
        self.notes = notes
        self.triedAt = triedAt
    }
}

// MARK: - Firebase Extensions

extension FlowProtocol {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.creatorId = data["creatorId"] as? String ?? ""
        self.creatorUsername = data["creatorUsername"] as? String ?? "Unknown"
        self.title = data["title"] as? String ?? ""
        self.description = data["description"] as? String ?? ""

        // Substances
        if let substancesData = data["substances"] as? [[String: Any]] {
            self.substances = substancesData.compactMap { dict in
                guard let id = dict["id"] as? String,
                      let name = dict["substanceName"] as? String,
                      let dose = dict["doseMg"] as? Int,
                      let timing = dict["timingMinutes"] as? Int else { return nil }
                return SubstanceEntry(id: id, substanceName: name, doseMg: dose, timingMinutes: timing)
            }
        } else {
            self.substances = []
        }

        self.sessionDurationMinutes = data["sessionDurationMinutes"] as? Int ?? 60
        self.breakDurationMinutes = data["breakDurationMinutes"] as? Int
        self.blocksPerSession = data["blocksPerSession"] as? Int ?? 1

        if let chronotypeRaw = data["targetChronotype"] as? String {
            self.targetChronotype = Chronotype(rawValue: chronotypeRaw)
        } else {
            self.targetChronotype = nil
        }

        if let activitiesRaw = data["bestForActivities"] as? [String] {
            self.bestForActivities = activitiesRaw.compactMap { ProtocolActivityType(rawValue: $0) }
        } else {
            self.bestForActivities = []
        }

        self.forkedFromId = data["forkedFromId"] as? String
        self.forkCount = data["forkCount"] as? Int ?? 0
        self.tryCount = data["tryCount"] as? Int ?? 0
        self.averageFlowImprovement = data["averageFlowImprovement"] as? Double ?? 0
        self.averageRating = data["averageRating"] as? Double ?? 0
        self.ratingsCount = data["ratingsCount"] as? Int ?? 0
        self.isPublic = data["isPublic"] as? Bool ?? true

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
        var data: [String: Any] = [
            "creatorId": creatorId,
            "creatorUsername": creatorUsername,
            "title": title,
            "description": description,
            "substances": substances.map { [
                "id": $0.id,
                "substanceName": $0.substanceName,
                "doseMg": $0.doseMg,
                "timingMinutes": $0.timingMinutes
            ] },
            "sessionDurationMinutes": sessionDurationMinutes,
            "blocksPerSession": blocksPerSession,
            "bestForActivities": bestForActivities.map { $0.rawValue },
            "forkCount": forkCount,
            "tryCount": tryCount,
            "averageFlowImprovement": averageFlowImprovement,
            "averageRating": averageRating,
            "ratingsCount": ratingsCount,
            "isPublic": isPublic,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: Date())
        ]

        if let breakDurationMinutes = breakDurationMinutes {
            data["breakDurationMinutes"] = breakDurationMinutes
        }
        if let targetChronotype = targetChronotype {
            data["targetChronotype"] = targetChronotype.rawValue
        }
        if let forkedFromId = forkedFromId {
            data["forkedFromId"] = forkedFromId
        }

        return data
    }
}

extension ProtocolTrial {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.protocolId = data["protocolId"] as? String ?? ""
        self.sessionId = data["sessionId"] as? String ?? ""
        self.flowScoreAchieved = data["flowScoreAchieved"] as? Int
        self.flowImprovement = data["flowImprovement"] as? Double
        self.rating = data["rating"] as? Int
        self.notes = data["notes"] as? String

        if let timestamp = data["triedAt"] as? Timestamp {
            self.triedAt = timestamp.dateValue()
        } else {
            self.triedAt = Date()
        }
    }

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "protocolId": protocolId,
            "sessionId": sessionId,
            "triedAt": Timestamp(date: triedAt)
        ]

        if let flowScoreAchieved = flowScoreAchieved {
            data["flowScoreAchieved"] = flowScoreAchieved
        }
        if let flowImprovement = flowImprovement {
            data["flowImprovement"] = flowImprovement
        }
        if let rating = rating {
            data["rating"] = rating
        }
        if let notes = notes {
            data["notes"] = notes
        }

        return data
    }
}
