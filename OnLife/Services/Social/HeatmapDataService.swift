import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Heatmap Day Data

struct HeatmapDayData: Identifiable, Equatable {
    let id: String
    let date: Date
    let sessionCount: Int
    let flowAchieved: Bool
    let flowQuality: Double?         // 0.0-1.0 if flow was achieved
    let totalMinutes: Int
    let bestSessionScore: Double?

    var hasActivity: Bool {
        sessionCount > 0
    }

    var intensityLevel: HeatmapIntensity {
        if !hasActivity {
            return .none
        }

        guard flowAchieved, let quality = flowQuality else {
            return .activityOnly
        }

        if quality >= 0.8 {
            return .deepFlow
        } else if quality >= 0.5 {
            return .moderateFlow
        } else {
            return .lightFlow
        }
    }

    static func empty(for date: Date) -> HeatmapDayData {
        HeatmapDayData(
            id: date.heatmapId,
            date: date,
            sessionCount: 0,
            flowAchieved: false,
            flowQuality: nil,
            totalMinutes: 0,
            bestSessionScore: nil
        )
    }
}

// MARK: - Heatmap Intensity

enum HeatmapIntensity: Int, CaseIterable {
    case none = 0
    case activityOnly = 1
    case lightFlow = 2
    case moderateFlow = 3
    case deepFlow = 4

    var description: String {
        switch self {
        case .none: return "No session"
        case .activityOnly: return "Session, no flow"
        case .lightFlow: return "Light flow"
        case .moderateFlow: return "Moderate flow"
        case .deepFlow: return "Deep flow"
        }
    }
}

// MARK: - Heatmap Week

struct HeatmapWeek: Identifiable {
    let id: String
    let days: [HeatmapDayData]
    let weekNumber: Int
    let year: Int

    var startDate: Date? {
        days.first?.date
    }

    var endDate: Date? {
        days.last?.date
    }
}

// MARK: - Heatmap Month

struct HeatmapMonth: Identifiable {
    let id: String
    let month: Int
    let year: Int
    let weeks: [HeatmapWeek]

    var displayName: String {
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = Calendar.current.date(from: dateComponents) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    var shortName: String {
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = Calendar.current.date(from: dateComponents) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    var totalFlowDays: Int {
        weeks.flatMap { $0.days }.filter { $0.flowAchieved }.count
    }

    var totalSessionDays: Int {
        weeks.flatMap { $0.days }.filter { $0.hasActivity }.count
    }

    var averageFlowQuality: Double? {
        let flowDays = weeks.flatMap { $0.days }.filter { $0.flowAchieved }
        guard !flowDays.isEmpty else { return nil }
        let totalQuality = flowDays.compactMap { $0.flowQuality }.reduce(0, +)
        return totalQuality / Double(flowDays.count)
    }
}

// MARK: - Heatmap Stats

struct HeatmapStats {
    let totalDays: Int
    let activeDays: Int
    let flowDays: Int
    let currentStreak: Int
    let longestStreak: Int
    let averageFlowQuality: Double?

    var activityRate: Double {
        guard totalDays > 0 else { return 0 }
        return Double(activeDays) / Double(totalDays)
    }

    var flowRate: Double {
        guard activeDays > 0 else { return 0 }
        return Double(flowDays) / Double(activeDays)
    }
}

// MARK: - Heatmap Data Service

@MainActor
class HeatmapDataService: ObservableObject {
    static let shared = HeatmapDataService()

    @Published var months: [HeatmapMonth] = []
    @Published var stats: HeatmapStats?
    @Published var isLoading = false
    @Published var error: Error?

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    private init() {}

    // MARK: - Fetch Heatmap Data

    func fetchHeatmapData(for userId: String? = nil, monthsBack: Int = 12) async {
        isLoading = true
        error = nil

        do {
            let targetUserId = userId ?? Auth.auth().currentUser?.uid
            guard let uid = targetUserId else {
                throw HeatmapError.notAuthenticated
            }

            let endDate = Date()
            guard let startDate = calendar.date(byAdding: .month, value: -monthsBack, to: endDate) else {
                throw HeatmapError.invalidDateRange
            }

            // Fetch sessions from Firestore
            let sessions = try await fetchSessions(userId: uid, from: startDate, to: endDate)

            // Aggregate into daily data
            let dailyData = aggregateSessionsIntoDays(sessions: sessions, from: startDate, to: endDate)

            // Organize into months
            months = organizeIntoMonths(dailyData: dailyData)

            // Calculate stats
            stats = calculateStats(dailyData: dailyData)

        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Fetch Sessions

    private func fetchSessions(userId: String, from startDate: Date, to endDate: Date) async throws -> [FlowSessionData] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("sessions")
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("startTime", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()

        return snapshot.documents.compactMap { doc -> FlowSessionData? in
            let data = doc.data()
            guard let startTimestamp = data["startTime"] as? Timestamp else { return nil }

            return FlowSessionData(
                id: doc.documentID,
                date: startTimestamp.dateValue(),
                durationMinutes: data["durationMinutes"] as? Int ?? 0,
                flowAchieved: data["flowAchieved"] as? Bool ?? false,
                flowScore: data["flowScore"] as? Double
            )
        }
    }

    // MARK: - Aggregate Sessions

    private func aggregateSessionsIntoDays(sessions: [FlowSessionData], from startDate: Date, to endDate: Date) -> [HeatmapDayData] {
        // Group sessions by day
        var sessionsByDay: [String: [FlowSessionData]] = [:]

        for session in sessions {
            let dayId = session.date.heatmapId
            sessionsByDay[dayId, default: []].append(session)
        }

        // Generate all days in range
        var dailyData: [HeatmapDayData] = []
        var currentDate = calendar.startOfDay(for: startDate)

        while currentDate <= endDate {
            let dayId = currentDate.heatmapId

            if let daySessions = sessionsByDay[dayId], !daySessions.isEmpty {
                let flowSessions = daySessions.filter { $0.flowAchieved }
                let bestScore = daySessions.compactMap { $0.flowScore }.max()
                let avgFlowQuality = flowSessions.isEmpty ? nil :
                    flowSessions.compactMap { $0.flowScore }.reduce(0, +) / Double(flowSessions.count)

                dailyData.append(HeatmapDayData(
                    id: dayId,
                    date: currentDate,
                    sessionCount: daySessions.count,
                    flowAchieved: !flowSessions.isEmpty,
                    flowQuality: avgFlowQuality,
                    totalMinutes: daySessions.reduce(0) { $0 + $1.durationMinutes },
                    bestSessionScore: bestScore
                ))
            } else {
                dailyData.append(.empty(for: currentDate))
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return dailyData
    }

    // MARK: - Organize Into Months

    private func organizeIntoMonths(dailyData: [HeatmapDayData]) -> [HeatmapMonth] {
        // Group by month
        var monthsDict: [String: [HeatmapDayData]] = [:]

        for day in dailyData {
            let components = calendar.dateComponents([.year, .month], from: day.date)
            let monthKey = "\(components.year!)-\(components.month!)"
            monthsDict[monthKey, default: []].append(day)
        }

        // Convert to HeatmapMonth objects
        var result: [HeatmapMonth] = []

        for (key, days) in monthsDict.sorted(by: { $0.key < $1.key }) {
            let parts = key.split(separator: "-")
            guard let year = Int(parts[0]), let month = Int(parts[1]) else { continue }

            // Organize days into weeks
            let weeks = organizeIntoWeeks(days: days.sorted { $0.date < $1.date })

            result.append(HeatmapMonth(
                id: key,
                month: month,
                year: year,
                weeks: weeks
            ))
        }

        return result
    }

    // MARK: - Organize Into Weeks

    private func organizeIntoWeeks(days: [HeatmapDayData]) -> [HeatmapWeek] {
        var weeks: [HeatmapWeek] = []
        var currentWeekDays: [HeatmapDayData] = []
        var currentWeekNumber: Int?

        for day in days {
            let weekNumber = calendar.component(.weekOfYear, from: day.date)
            let year = calendar.component(.yearForWeekOfYear, from: day.date)

            if currentWeekNumber == nil {
                currentWeekNumber = weekNumber
            }

            if weekNumber != currentWeekNumber && !currentWeekDays.isEmpty {
                // Save current week
                weeks.append(HeatmapWeek(
                    id: "\(year)-W\(currentWeekNumber!)",
                    days: currentWeekDays,
                    weekNumber: currentWeekNumber!,
                    year: year
                ))
                currentWeekDays = []
                currentWeekNumber = weekNumber
            }

            currentWeekDays.append(day)
        }

        // Don't forget the last week
        if !currentWeekDays.isEmpty, let weekNum = currentWeekNumber {
            let year = calendar.component(.yearForWeekOfYear, from: currentWeekDays[0].date)
            weeks.append(HeatmapWeek(
                id: "\(year)-W\(weekNum)",
                days: currentWeekDays,
                weekNumber: weekNum,
                year: year
            ))
        }

        return weeks
    }

    // MARK: - Calculate Stats

    private func calculateStats(dailyData: [HeatmapDayData]) -> HeatmapStats {
        let activeDays = dailyData.filter { $0.hasActivity }
        let flowDays = dailyData.filter { $0.flowAchieved }

        // Calculate current streak
        var currentStreak = 0
        for day in dailyData.reversed() {
            if day.hasActivity {
                currentStreak += 1
            } else if currentStreak > 0 {
                break
            }
        }

        // Calculate longest streak
        var longestStreak = 0
        var tempStreak = 0
        for day in dailyData {
            if day.hasActivity {
                tempStreak += 1
                longestStreak = max(longestStreak, tempStreak)
            } else {
                tempStreak = 0
            }
        }

        // Average flow quality
        let flowQualities = flowDays.compactMap { $0.flowQuality }
        let avgQuality = flowQualities.isEmpty ? nil : flowQualities.reduce(0, +) / Double(flowQualities.count)

        return HeatmapStats(
            totalDays: dailyData.count,
            activeDays: activeDays.count,
            flowDays: flowDays.count,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            averageFlowQuality: avgQuality
        )
    }

    // MARK: - Get Day Detail

    func getDayDetail(for date: Date) -> HeatmapDayData? {
        let dayId = date.heatmapId
        return months.flatMap { $0.weeks.flatMap { $0.days } }.first { $0.id == dayId }
    }
}

// MARK: - Supporting Types

struct FlowSessionData {
    let id: String
    let date: Date
    let durationMinutes: Int
    let flowAchieved: Bool
    let flowScore: Double?
}

enum HeatmapError: LocalizedError {
    case notAuthenticated
    case invalidDateRange
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidDateRange:
            return "Invalid date range"
        case .fetchFailed:
            return "Failed to fetch session data"
        }
    }
}

// MARK: - Date Extension

extension Date {
    var heatmapId: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }

    var dayOfWeek: Int {
        // Returns 0 for Sunday, 6 for Saturday
        let weekday = Calendar.current.component(.weekday, from: self)
        return weekday - 1
    }

    var shortDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }

    var dayNumber: Int {
        Calendar.current.component(.day, from: self)
    }
}
