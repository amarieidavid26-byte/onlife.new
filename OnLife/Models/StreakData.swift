import Foundation
import SwiftUI

/// Streak data model for tracking daily focus habits
/// Research: Duolingo streak freeze increased 30-day retention by 18%
struct StreakData: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastSessionDate: Date?
    var freezesAvailable: Int
    var freezesUsedThisMonth: Int
    var lastFreezeDate: Date?
    var monthlyFreezeAllowance: Int
    var lastMonthChecked: Int? // Track which month we last checked for refresh

    init() {
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastSessionDate = nil
        self.freezesAvailable = 2 // Start with 2 freezes
        self.freezesUsedThisMonth = 0
        self.lastFreezeDate = nil
        self.monthlyFreezeAllowance = 2 // 2 freezes per month
        self.lastMonthChecked = nil
    }

    var streakStatus: StreakStatus {
        guard let lastDate = lastSessionDate else {
            return .noStreak
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)

        if lastDay == today {
            return .active // Completed today
        } else if lastDay == calendar.date(byAdding: .day, value: -1, to: today) {
            return .atRisk // Last session was yesterday, need to complete today
        } else {
            return .broken // Missed more than 1 day
        }
    }

    enum StreakStatus: String, Codable {
        case noStreak
        case active
        case atRisk
        case broken

        var color: Color {
            switch self {
            case .noStreak: return OnLifeColors.textTertiary
            case .active: return OnLifeColors.sage
            case .atRisk: return OnLifeColors.warning
            case .broken: return OnLifeColors.error
            }
        }

        var emoji: String {
            switch self {
            case .noStreak: return "🔥"
            case .active: return "🔥"
            case .atRisk: return "⚠️"
            case .broken: return "💔"
            }
        }

        var label: String {
            switch self {
            case .noStreak: return "Start your streak"
            case .active: return "Streak active"
            case .atRisk: return "Complete today to keep streak"
            case .broken: return "Streak broken"
            }
        }
    }

    var canUseFreeze: Bool {
        freezesAvailable > 0
    }

    var daysUntilFreezeRefresh: Int {
        let calendar = Calendar.current
        let now = Date()

        if let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
           let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) {
            return calendar.dateComponents([.day], from: now, to: nextMonth).day ?? 0
        }

        return 0
    }

    var streakMilestone: StreakMilestone? {
        StreakMilestone.milestone(for: currentStreak)
    }

    var nextMilestone: StreakMilestone? {
        StreakMilestone.nextMilestone(after: currentStreak)
    }

    var daysToNextMilestone: Int? {
        guard let next = nextMilestone else { return nil }
        return next.days - currentStreak
    }
}

// MARK: - Streak Milestones

enum StreakMilestone: Int, CaseIterable {
    case week = 7
    case twoWeeks = 14
    case month = 30
    case twoMonths = 60
    case quarter = 90
    case halfYear = 180
    case year = 365

    var days: Int { rawValue }

    var emoji: String {
        switch self {
        case .week: return "🌱"
        case .twoWeeks: return "🌿"
        case .month: return "🌳"
        case .twoMonths: return "⭐"
        case .quarter: return "🏆"
        case .halfYear: return "💎"
        case .year: return "👑"
        }
    }

    var label: String {
        switch self {
        case .week: return "1 Week"
        case .twoWeeks: return "2 Weeks"
        case .month: return "1 Month"
        case .twoMonths: return "2 Months"
        case .quarter: return "3 Months"
        case .halfYear: return "6 Months"
        case .year: return "1 Year"
        }
    }

    var celebrationMessage: String {
        switch self {
        case .week: return "First week complete!"
        case .twoWeeks: return "Two weeks of focus!"
        case .month: return "A whole month! Incredible!"
        case .twoMonths: return "Two months strong!"
        case .quarter: return "Quarter year champion!"
        case .halfYear: return "Half year hero!"
        case .year: return "LEGENDARY! One full year!"
        }
    }

    static func milestone(for days: Int) -> StreakMilestone? {
        allCases.first { $0.days == days }
    }

    static func nextMilestone(after days: Int) -> StreakMilestone? {
        allCases.first { $0.days > days }
    }

    static func currentMilestone(for days: Int) -> StreakMilestone? {
        allCases.reversed().first { $0.days <= days }
    }
}
