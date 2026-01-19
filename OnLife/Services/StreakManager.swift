import Foundation
import SwiftUI
import Combine

/// Manages user streak data with freeze protection
/// Research: Users with streaks >7 days are 3x more likely to remain active
class StreakManager: ObservableObject {
    static let shared = StreakManager()

    @Published var streakData: StreakData
    @Published var showStreakSavedAlert = false
    @Published var recentMilestone: StreakMilestone?

    private let userDefaults = UserDefaults.standard
    private let streakKey = "userStreakData_v2"

    private init() {
        if let data = userDefaults.data(forKey: streakKey),
           let decoded = try? JSONDecoder().decode(StreakData.self, from: data) {
            streakData = decoded
        } else {
            streakData = StreakData()
        }

        // Check if we need to refresh monthly freezes
        checkMonthlyRefresh()

        // Check streak status on init
        checkStreakOnLaunch()
    }

    // MARK: - Session Recording

    func recordSession(date: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        guard let lastDate = streakData.lastSessionDate else {
            // First session ever
            streakData.currentStreak = 1
            streakData.longestStreak = 1
            streakData.lastSessionDate = today
            checkForMilestone()
            save()
            print("🔥 [Streak] First session! Streak: 1")
            return
        }

        let lastDay = calendar.startOfDay(for: lastDate)

        if lastDay == today {
            // Already completed today, no streak change
            print("🔥 [Streak] Already completed today. Streak: \(streakData.currentStreak)")
            return
        } else if lastDay == calendar.date(byAdding: .day, value: -1, to: today) {
            // Consecutive day - increment streak
            streakData.currentStreak += 1
            streakData.longestStreak = max(streakData.longestStreak, streakData.currentStreak)
            streakData.lastSessionDate = today
            checkForMilestone()
            print("🔥 [Streak] Consecutive day! Streak: \(streakData.currentStreak)")
        } else {
            // Missed day(s) - check for freeze
            let daysMissed = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysMissed == 2 && streakData.canUseFreeze {
                // Auto-use freeze to save streak (missed exactly 1 day)
                useFreeze()
                streakData.currentStreak += 1 // Continue streak
                streakData.longestStreak = max(streakData.longestStreak, streakData.currentStreak)
                streakData.lastSessionDate = today
                checkForMilestone()
                print("🧊 [Streak] Freeze used! Streak saved: \(streakData.currentStreak)")
            } else {
                // Streak broken - reset
                let oldStreak = streakData.currentStreak
                streakData.currentStreak = 1
                streakData.lastSessionDate = today
                print("💔 [Streak] Broken after \(oldStreak) days. Starting fresh.")
            }
        }

        save()
    }

    // MARK: - Freeze Management

    private func useFreeze() {
        guard streakData.canUseFreeze else { return }

        streakData.freezesAvailable -= 1
        streakData.freezesUsedThisMonth += 1
        streakData.lastFreezeDate = Date()

        // Show notification
        DispatchQueue.main.async {
            self.showStreakSavedAlert = true
        }

        // Trigger haptic
        HapticManager.shared.notification(type: .success)

        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.showStreakSavedAlert = false
        }

        print("🧊 [Streak] Freeze used! \(streakData.freezesAvailable) remaining")

        save()
    }

    func checkMonthlyRefresh() {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())

        // Check if we're in a new month
        if let lastMonth = streakData.lastMonthChecked {
            if lastMonth != currentMonth {
                // New month - refresh freezes
                streakData.freezesAvailable = streakData.monthlyFreezeAllowance
                streakData.freezesUsedThisMonth = 0
                streakData.lastMonthChecked = currentMonth
                print("🔄 [Streak] New month! Freezes refreshed: \(streakData.freezesAvailable)")
                save()
            }
        } else {
            // First time - set current month
            streakData.lastMonthChecked = currentMonth
            save()
        }
    }

    // MARK: - Streak Status

    private func checkStreakOnLaunch() {
        // Check if streak should be marked as broken
        guard let lastDate = streakData.lastSessionDate else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)
        let daysSince = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        if daysSince > 2 {
            // More than 1 day missed without a freeze - streak is broken
            // Don't reset yet, just mark status as broken
            // The reset happens when they complete a new session
            print("⚠️ [Streak] Status: Broken (missed \(daysSince - 1) days)")
        } else if daysSince == 2 {
            // Missed 1 day - at risk, freeze available?
            if streakData.canUseFreeze {
                print("⚠️ [Streak] Status: At risk, freeze available")
            } else {
                print("⚠️ [Streak] Status: At risk, no freeze available")
            }
        }
    }

    // MARK: - Milestones

    private func checkForMilestone() {
        if let milestone = StreakMilestone.milestone(for: streakData.currentStreak) {
            recentMilestone = milestone
            HapticManager.shared.notification(type: .success)
            print("🏆 [Streak] Milestone reached: \(milestone.label)")

            // Clear milestone after display
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.recentMilestone = nil
            }
        }
    }

    // MARK: - History

    func getCompletedDates(from sessions: [FocusSession]) -> Set<Date> {
        let calendar = Calendar.current
        var completedDates = Set<Date>()

        for session in sessions where session.wasCompleted {
            let day = calendar.startOfDay(for: session.startTime)
            completedDates.insert(day)
        }

        return completedDates
    }

    func isDateCompleted(_ date: Date, completedDates: Set<Date>) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return completedDates.contains(day)
    }

    // MARK: - Persistence

    private func save() {
        if let encoded = try? JSONEncoder().encode(streakData) {
            userDefaults.set(encoded, forKey: streakKey)
        }
    }

    // MARK: - Debug Helpers

    #if DEBUG
    func simulateMissedDay() {
        let calendar = Calendar.current
        if let yesterday = calendar.date(byAdding: .day, value: -2, to: Date()) {
            streakData.lastSessionDate = yesterday
            save()
            print("🔧 [Debug] Simulated missed day - streak at risk")
        }
    }

    func resetStreak() {
        streakData = StreakData()
        save()
        print("🔧 [Debug] Streak reset")
    }

    func addFreezes(_ count: Int) {
        streakData.freezesAvailable = min(streakData.monthlyFreezeAllowance, streakData.freezesAvailable + count)
        save()
        print("🔧 [Debug] Added freezes: \(streakData.freezesAvailable) available")
    }
    #endif
}
