import Foundation
import SwiftUI
import Combine

class SessionAnalyticsViewModel: ObservableObject {
    @Published var selectedPeriod: AnalyticsPeriod = .week
    @Published var stats: SessionStats?
    @Published var isLoading = false

    enum AnalyticsPeriod: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case allTime = "All Time"

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .allTime: return nil
            }
        }
    }

    func calculateStats(from sessions: [FocusSession]) {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let filteredSessions = self.filterSessions(sessions)
            let stats = SessionStats(sessions: filteredSessions)

            DispatchQueue.main.async {
                self.stats = stats
                self.isLoading = false
            }
        }
    }

    private func filterSessions(_ sessions: [FocusSession]) -> [FocusSession] {
        guard let days = selectedPeriod.days else { return sessions }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return sessions.filter { session in
            return session.startTime >= cutoffDate
        }
    }
}

// MARK: - Session Stats

struct SessionStats {
    let totalSessions: Int
    let completedSessions: Int
    let totalMinutes: Int
    let averageSessionLength: Int
    let completionRate: Double
    let bestDayOfWeek: String
    let bestHourOfDay: Int
    let currentStreak: Int
    let longestStreak: Int
    let activeDays: Int
    let timeOfDayDistribution: [Int: Int] // hour: session_count
    let dayOfWeekDistribution: [Int: Int] // 1=Sunday, 7=Saturday: session_count
    let averageFlowScore: Double

    init(sessions: [FocusSession]) {
        let completed = sessions.filter { $0.wasCompleted }

        self.totalSessions = sessions.count
        self.completedSessions = completed.count
        self.totalMinutes = completed.reduce(0) { $0 + Int($1.actualDuration / 60) }
        self.averageSessionLength = completed.isEmpty ? 0 : totalMinutes / completed.count
        self.completionRate = totalSessions > 0 ? Double(completedSessions) / Double(totalSessions) : 0
        self.averageFlowScore = completed.isEmpty ? 0 : completed.reduce(0.0) { $0 + $1.focusQuality * 100 } / Double(completed.count)

        // Calculate day of week distribution
        var dayCount: [Int: Int] = [:]
        for session in completed {
            let weekday = Calendar.current.component(.weekday, from: session.startTime)
            dayCount[weekday, default: 0] += 1
        }
        self.dayOfWeekDistribution = dayCount

        // Find best day
        let bestDay = dayCount.max(by: { $0.value < $1.value })?.key ?? 1
        let dayFormatter = DateFormatter()
        let weekdaySymbols = dayFormatter.weekdaySymbols ?? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        self.bestDayOfWeek = bestDay >= 1 && bestDay <= 7 ? weekdaySymbols[bestDay - 1] : "Monday"

        // Calculate hour of day distribution
        var hourCount: [Int: Int] = [:]
        for session in completed {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourCount[hour, default: 0] += 1
        }
        self.timeOfDayDistribution = hourCount

        // Find best hour
        self.bestHourOfDay = hourCount.max(by: { $0.value < $1.value })?.key ?? 9

        // Calculate streaks
        let streakData = Self.calculateStreaks(sessions: completed)
        self.currentStreak = streakData.current
        self.longestStreak = streakData.longest

        // Calculate active days
        let uniqueDays = Set(completed.map {
            Calendar.current.startOfDay(for: $0.startTime)
        })
        self.activeDays = uniqueDays.count
    }

    private static func calculateStreaks(sessions: [FocusSession]) -> (current: Int, longest: Int) {
        guard !sessions.isEmpty else { return (0, 0) }

        let calendar = Calendar.current
        let sortedDates = sessions
            .map { calendar.startOfDay(for: $0.startTime) }
            .sorted()

        let uniqueDates = Array(Set(sortedDates)).sorted()

        guard !uniqueDates.isEmpty else { return (0, 0) }

        var currentStreak = 0
        var longestStreak = 0
        var tempStreak = 1

        // Calculate streaks
        for i in 0..<uniqueDates.count - 1 {
            let dayDiff = calendar.dateComponents([.day], from: uniqueDates[i], to: uniqueDates[i + 1]).day ?? 0

            if dayDiff == 1 {
                tempStreak += 1
            } else {
                longestStreak = max(longestStreak, tempStreak)
                tempStreak = 1
            }
        }

        longestStreak = max(longestStreak, tempStreak)

        // Check if current streak is active
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        if let lastDate = uniqueDates.last {
            if lastDate == today || lastDate == yesterday {
                // Count back from last date
                currentStreak = 1
                for i in stride(from: uniqueDates.count - 2, through: 0, by: -1) {
                    let dayDiff = calendar.dateComponents([.day], from: uniqueDates[i], to: uniqueDates[i + 1]).day ?? 0
                    if dayDiff == 1 {
                        currentStreak += 1
                    } else {
                        break
                    }
                }
            }
        }

        return (currentStreak, longestStreak)
    }

    var completionRatePercentage: String {
        String(format: "%.0f%%", completionRate * 100)
    }

    var averageFlowScoreFormatted: String {
        String(format: "%.0f", averageFlowScore)
    }
}
