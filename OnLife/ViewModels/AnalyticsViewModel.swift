import Foundation
import Combine
import SwiftUI

class AnalyticsViewModel: ObservableObject {
    @Published var sessions: [FocusSession] = []
    @Published var gardens: [Garden] = []
    @Published var isLoading = false
    @Published var cachedInsights: [Insight] = []
    @Published var lastInsightGeneration: Date?

    // AI Insights
    @Published var aiInsight: String?
    @Published var aiInsightLoading = false
    @Published var aiInsightError: String?

    private let insightsCacheKey = "cached_insights"
    private let insightsCacheDateKey = "insights_cache_date"
    private let gemini = GeminiService.shared

    init() {
        loadData()
        loadCachedInsights()
    }

    func loadData() {
        sessions = GardenDataManager.shared.loadSessions()
        gardens = GardenDataManager.shared.loadGardens()
    }

    func refreshInsights() {
        let newInsights = insights
        cachedInsights = newInsights
        lastInsightGeneration = Date()
        saveCachedInsights()
    }

    private func loadCachedInsights() {
        if let data = UserDefaults.standard.data(forKey: insightsCacheKey),
           let decoded = try? JSONDecoder().decode([CachedInsight].self, from: data) {
            cachedInsights = decoded.map { Insight(from: $0) }
        }

        if let timestamp = UserDefaults.standard.object(forKey: insightsCacheDateKey) as? Date {
            lastInsightGeneration = timestamp
        }
    }

    private func saveCachedInsights() {
        let cacheable = cachedInsights.map { CachedInsight(from: $0) }
        if let encoded = try? JSONEncoder().encode(cacheable) {
            UserDefaults.standard.set(encoded, forKey: insightsCacheKey)
        }

        if let date = lastInsightGeneration {
            UserDefaults.standard.set(date, forKey: insightsCacheDateKey)
        }
    }

    // MARK: - Total Stats

    var totalSessions: Int {
        sessions.count
    }

    var totalFocusTime: TimeInterval {
        sessions.reduce(0) { $0 + $1.actualDuration }
    }

    var totalFocusTimeFormatted: String {
        formatDuration(totalFocusTime)
    }

    var averageSessionDuration: TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        return totalFocusTime / Double(sessions.count)
    }

    var averageSessionFormatted: String {
        formatDuration(averageSessionDuration)
    }

    var longestSession: TimeInterval {
        sessions.map { $0.actualDuration }.max() ?? 0
    }

    var longestSessionFormatted: String {
        formatDuration(longestSession)
    }

    // MARK: - This Week Stats

    var thisWeekSessions: [FocusSession] {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!

        return sessions.filter { $0.startTime >= weekAgo }
    }

    var thisWeekFocusTime: TimeInterval {
        thisWeekSessions.reduce(0) { $0 + $1.actualDuration }
    }

    var thisWeekFocusTimeFormatted: String {
        formatDuration(thisWeekFocusTime)
    }

    var totalFocusTimeThisWeek: TimeInterval {
        thisWeekFocusTime
    }

    var totalFocusTimeLastWeek: TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!

        let lastWeekSessions = sessions.filter { $0.startTime >= twoWeeksAgo && $0.startTime < weekAgo }
        return lastWeekSessions.reduce(0) { $0 + $1.actualDuration }
    }

    // Alias for AI insights
    var sessionsThisWeek: [FocusSession] {
        thisWeekSessions
    }

    // MARK: - Streak Analysis

    func calculateCurrentStreak() -> Int? {
        guard !sessions.isEmpty else { return nil }

        let calendar = Calendar.current
        let sortedSessions = sessions.sorted { $0.startTime > $1.startTime }

        // Get unique days with sessions
        var daysWithSessions: Set<Date> = []
        for session in sortedSessions {
            let startOfDay = calendar.startOfDay(for: session.startTime)
            daysWithSessions.insert(startOfDay)
        }

        let sortedDays = Array(daysWithSessions).sorted(by: >)
        guard !sortedDays.isEmpty else { return nil }

        // Check if today or yesterday has a session
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        guard sortedDays[0] == today || sortedDays[0] == yesterday else {
            return nil // Streak is broken
        }

        // Count consecutive days
        var streak = 1
        for i in 0..<(sortedDays.count - 1) {
            let currentDay = sortedDays[i]
            let nextDay = sortedDays[i + 1]

            if let daysBetween = calendar.dateComponents([.day], from: nextDay, to: currentDay).day,
               daysBetween == 1 {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Day of Week Analysis

    func calculateBestDayOfWeek() -> (name: String, avgMinutes: Double)? {
        guard sessions.count >= 7 else { return nil }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session -> Int in
            calendar.component(.weekday, from: session.startTime)
        }

        let averages = grouped.map { weekday, sessionList -> (Int, Double) in
            let avgSeconds = sessionList.map { $0.actualDuration }.average()
            return (weekday, avgSeconds / 60.0) // Convert to minutes
        }

        guard let best = averages.max(by: { $0.1 < $1.1 }) else { return nil }

        let dayName = calendar.weekdaySymbols[best.0 - 1]
        return (name: dayName, avgMinutes: best.1)
    }

    // MARK: - AI Insights

    func generateAIInsight() async {
        // Don't generate if already loading
        guard !aiInsightLoading else { return }

        // Check cache (don't regenerate more than once per hour)
        if let cached = UserDefaults.standard.string(forKey: "ai_insight"),
           let cacheDate = UserDefaults.standard.object(forKey: "ai_insight_date") as? Date,
           Date().timeIntervalSince(cacheDate) < 3600 {
            await MainActor.run {
                aiInsight = cached
            }
            return
        }

        await MainActor.run {
            aiInsightLoading = true
            aiInsightError = nil
        }

        do {
            // Prepare data
            let completionRate = calculateCompletionRate()
            let streak = calculateCurrentStreak() ?? 0
            let bestEnv = bestEnvironment?.environment.displayName ?? "Unknown"
            let peakTimeStr = bestTimeOfDay?.time.displayName ?? "Unknown"

            // Call Gemini
            let insight = try await gemini.generateDailyInsight(
                weeklySessionCount: sessionsThisWeek.count,
                avgDuration: averageSessionDuration,
                completionRate: completionRate,
                currentStreak: streak,
                bestEnvironment: bestEnv,
                peakTime: peakTimeStr
            )

            // Cache result
            UserDefaults.standard.set(insight, forKey: "ai_insight")
            UserDefaults.standard.set(Date(), forKey: "ai_insight_date")

            await MainActor.run {
                aiInsight = insight
                aiInsightLoading = false
            }

        } catch {
            await MainActor.run {
                aiInsightError = error.localizedDescription
                aiInsightLoading = false

                // Fallback to template insight
                aiInsight = generateFallbackInsight()
            }
        }
    }

    private func calculateCompletionRate() -> Double {
        let completed = sessions.filter { $0.wasCompleted }.count
        guard !sessions.isEmpty else { return 0 }
        return Double(completed) / Double(sessions.count)
    }

    private func generateFallbackInsight() -> String {
        let totalMinutes = totalFocusTime.isFinite ? max(0, Int(totalFocusTime / 60)) : 0
        let sessionCount = sessions.count

        if sessionCount >= 10 {
            return "You've completed \(sessionCount) sessions this week! Your focus practice is building real momentum 💪"
        } else if totalMinutes >= 60 {
            return "You've focused for \(totalMinutes) minutes this week. Every session strengthens your focus muscle 🌱"
        } else {
            return "Keep growing! Every focus session is building lasting habits 🌟"
        }
    }

    // MARK: - Testing (DEBUG only)

    #if DEBUG
    func testAIInsight() async {
        // For testing without real API key
        await MainActor.run {
            aiInsightLoading = true
        }

        // Simulate API delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        let mockInsight = "You focus 45% longer in coffee shops - schedule deep work there! ☕"

        await MainActor.run {
            aiInsight = mockInsight
            aiInsightLoading = false
        }
    }
    #endif

    // MARK: - Environment Analysis

    var bestEnvironment: (environment: FocusEnvironment, avgDuration: TimeInterval)? {
        guard !sessions.isEmpty else { return nil }

        let grouped = Dictionary(grouping: sessions) { $0.environment }

        let averages = grouped.map { env, sessionList -> (FocusEnvironment, TimeInterval) in
            let avg = sessionList.reduce(0.0) { $0 + $1.actualDuration } / Double(sessionList.count)
            return (env, avg)
        }

        return averages.max { $0.1 < $1.1 }
    }

    var worstEnvironment: (environment: FocusEnvironment, avgDuration: TimeInterval)? {
        guard !sessions.isEmpty else { return nil }

        let grouped = Dictionary(grouping: sessions) { $0.environment }

        let averages = grouped.map { env, sessionList -> (FocusEnvironment, TimeInterval) in
            let avg = sessionList.reduce(0.0) { $0 + $1.actualDuration } / Double(sessionList.count)
            return (env, avg)
        }

        return averages.min { $0.1 < $1.1 }
    }

    var environmentBreakdown: [(environment: FocusEnvironment, avgDuration: TimeInterval, sessionCount: Int)] {
        guard !sessions.isEmpty else { return [] }

        let grouped = Dictionary(grouping: sessions) { $0.environment }

        let result = grouped.map { (env, sessionList) -> (FocusEnvironment, TimeInterval, Int) in
            let avg = sessionList.reduce(0.0) { $0 + $1.actualDuration } / Double(sessionList.count)
            return (env, avg, sessionList.count)
        }

        return result.sorted { $0.1 > $1.1 } // Sort by average duration descending
    }

    // MARK: - Time of Day Analysis

    var bestTimeOfDay: (time: TimeOfDay, avgDuration: TimeInterval)? {
        guard !sessions.isEmpty else { return nil }

        let grouped = Dictionary(grouping: sessions) { $0.timeOfDay }

        let averages = grouped.map { time, sessions -> (TimeOfDay, TimeInterval) in
            let avg = sessions.reduce(0.0) { $0 + $1.actualDuration } / Double(sessions.count)
            return (time, avg)
        }

        return averages.max { $0.1 < $1.1 }
    }

    var timeOfDayBreakdown: [(time: TimeOfDay, avgDuration: TimeInterval, sessionCount: Int)] {
        guard !sessions.isEmpty else { return [] }

        let grouped = Dictionary(grouping: sessions) { $0.timeOfDay }

        return grouped.map { time, sessions -> (TimeOfDay, TimeInterval, Int) in
            let avg = sessions.reduce(0.0) { $0 + $1.actualDuration } / Double(sessions.count)
            return (time, avg, sessions.count)
        }.sorted { $0.1 > $1.1 }
    }

    // MARK: - Garden Analysis

    func sessionsForGarden(_ gardenId: UUID) -> [FocusSession] {
        sessions.filter { $0.gardenId == gardenId }
    }

    func totalFocusTimeForGarden(_ gardenId: UUID) -> TimeInterval {
        sessionsForGarden(gardenId).reduce(0) { $0 + $1.actualDuration }
    }

    var gardenBreakdown: [(garden: Garden, focusTime: TimeInterval, sessionCount: Int)] {
        gardens.map { garden in
            let gardenSessions = sessionsForGarden(garden.id)
            let totalTime = gardenSessions.reduce(0.0) { $0 + $1.actualDuration }
            return (garden, totalTime, gardenSessions.count)
        }.sorted { $0.1 > $1.1 }
    }

    // MARK: - Insights Generation

    var insights: [Insight] {
        var generatedInsights: [Insight] = []

        // Need minimum sessions for meaningful insights
        guard sessions.count >= 5 else {
            return [Insight(
                icon: "chart.bar.fill",
                title: "Keep Building Data",
                description: "Complete at least 5 focus sessions to unlock personalized insights about your productivity patterns.",
                type: .neutral
            )]
        }

        // Streak momentum insight
        if let streak = calculateCurrentStreak(), streak >= 3 {
            generatedInsights.append(Insight(
                icon: "flame.fill",
                title: "\(streak)-Day Streak!",
                description: "You're on fire! You've focused for \(streak) consecutive days. Keep this momentum going to build lasting habits.",
                type: .positive
            ))
        }

        // Week growth insight
        let thisWeek = totalFocusTimeThisWeek
        let lastWeek = totalFocusTimeLastWeek
        if lastWeek > 0 {
            let growth = ((thisWeek - lastWeek) / lastWeek * 100)
            if growth > 10 {
                generatedInsights.append(Insight(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Week-Over-Week Growth",
                    description: "You focused \(Int(abs(growth)))% more this week than last week. Your dedication is paying off!",
                    type: .positive
                ))
            } else if growth < -10 {
                generatedInsights.append(Insight(
                    icon: "chart.line.downtrend.xyaxis",
                    title: "Focus Dip This Week",
                    description: "Your focus time dropped \(Int(abs(growth)))% this week. Let's get back on track - schedule a session today!",
                    type: .suggestion
                ))
            }
        }

        // Session quality insight (completion rate)
        let completedSessions = sessions.filter { $0.wasCompleted }.count
        let completionRate = Double(completedSessions) / Double(sessions.count) * 100
        if completionRate >= 90 {
            generatedInsights.append(Insight(
                icon: "checkmark.seal.fill",
                title: "Excellent Completion Rate",
                description: "You complete \(Int(completionRate))% of your sessions! This consistency is building powerful focus habits.",
                type: .positive
            ))
        } else if completionRate < 70 {
            generatedInsights.append(Insight(
                icon: "exclamationmark.triangle.fill",
                title: "Session Completion",
                description: "Only \(Int(completionRate))% of sessions are completed. Try shorter sessions or remove distractions to improve your completion rate.",
                type: .suggestion
            ))
        }

        // Best day insight
        if let bestDay = calculateBestDayOfWeek(), bestDay.avgMinutes.isFinite {
            let avgMins = max(0, Int(bestDay.avgMinutes))
            generatedInsights.append(Insight(
                icon: "calendar.badge.clock",
                title: "Best Day: \(bestDay.name)",
                description: "You average \(avgMins) minutes on \(bestDay.name)s. Consider scheduling your most important work on this day!",
                type: .positive
            ))
        }

        // Environment insight
        if let best = bestEnvironment, let worst = worstEnvironment, worst.avgDuration > 0 {
            let improvement = ((best.avgDuration - worst.avgDuration) / worst.avgDuration * 100)
            // Safety check for NaN/infinity before Int conversion
            if improvement.isFinite {
                let clampedImprovement = max(0, min(999, Int(improvement)))
                generatedInsights.append(Insight(
                    icon: best.environment.icon,
                    title: "Best Focus Environment",
                    description: "You focus \(clampedImprovement)% longer at \(best.environment.displayName) compared to \(worst.environment.displayName). Try scheduling important work there!",
                    type: .positive
                ))
            }
        }

        // Time of day insight
        if let bestTime = bestTimeOfDay, bestTime.avgDuration.isFinite {
            let hours = max(0, Int(bestTime.avgDuration / 3600))
            let minutes = max(0, Int((bestTime.avgDuration.truncatingRemainder(dividingBy: 3600)) / 60))
            generatedInsights.append(Insight(
                icon: timeIcon(for: bestTime.time),
                title: "Peak Focus Time",
                description: "Your \(bestTime.time.rawValue) sessions average \(hours)h \(minutes)m. This is your peak performance window - protect this time!",
                type: .positive
            ))
        }

        // Consistency insight
        let recentSessions = sessions.suffix(7)
        if recentSessions.count >= 5 && calculateCurrentStreak() ?? 0 < 3 {
            generatedInsights.append(Insight(
                icon: "calendar.badge.checkmark",
                title: "Building Momentum",
                description: "You've completed \(recentSessions.count) sessions this week. Consistency is key to forming lasting habits!",
                type: .positive
            ))
        }

        // Average duration insight
        let avgMinutes = averageSessionDuration.isFinite ? max(0, Int(averageSessionDuration / 60)) : 0
        if avgMinutes < 25 && avgMinutes > 0 {
            generatedInsights.append(Insight(
                icon: "clock.arrow.circlepath",
                title: "Try Longer Sessions",
                description: "Your average session is \(avgMinutes) minutes. Research shows 25-45 minute sessions maximize deep work. Gradually extend your focus time!",
                type: .suggestion
            ))
        } else if avgMinutes >= 45 {
            generatedInsights.append(Insight(
                icon: "star.fill",
                title: "Deep Work Master",
                description: "Your average session is \(avgMinutes) minutes - you're crushing deep work! Keep up this excellent focus.",
                type: .positive
            ))
        }

        // Prioritize and limit insights
        return prioritizeInsights(generatedInsights)
    }

    private func prioritizeInsights(_ insights: [Insight]) -> [Insight] {
        // Sort by type: positive > suggestion > neutral
        let sorted = insights.sorted { insight1, insight2 in
            let priority1 = priorityValue(for: insight1.type)
            let priority2 = priorityValue(for: insight2.type)
            return priority1 > priority2
        }

        // Limit to top 5 insights
        return Array(sorted.prefix(5))
    }

    private func priorityValue(for type: Insight.InsightType) -> Int {
        switch type {
        case .positive: return 4
        case .warning: return 3
        case .suggestion: return 2
        case .neutral: return 1
        }
    }

    // MARK: - Helper Methods

    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration.isFinite else { return "0m" }
        let hours = max(0, Int(duration / 3600))
        let minutes = max(0, Int((duration.truncatingRemainder(dividingBy: 3600)) / 60))

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func timeIcon(for time: TimeOfDay) -> String {
        switch time {
        case .earlyMorning: return "sunrise.fill"
        case .morning: return "sun.and.horizon"
        case .midday: return "sun.max.fill"
        case .afternoon: return "sun.haze"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        case .lateNight: return "moon.fill"
        }
    }
}

// MARK: - Insight Model

struct Insight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let type: InsightType

    enum InsightType {
        case positive
        case suggestion
        case warning
        case neutral

        var color: Color {
            switch self {
            case .positive: return OnLifeColors.sage
            case .suggestion: return OnLifeColors.amber
            case .warning: return OnLifeColors.terracotta
            case .neutral: return OnLifeColors.textSecondary
            }
        }
    }

    init(icon: String, title: String, description: String, type: InsightType) {
        self.icon = icon
        self.title = title
        self.description = description
        self.type = type
    }

    init(from cached: CachedInsight) {
        self.icon = cached.icon
        self.title = cached.title
        self.description = cached.description
        self.type = InsightType(rawValue: cached.typeRawValue) ?? .neutral
    }
}

extension Insight.InsightType: Codable {
    enum CodingKeys: String, CodingKey {
        case positive, suggestion, warning, neutral
    }

    init?(rawValue: String) {
        switch rawValue {
        case "positive": self = .positive
        case "suggestion": self = .suggestion
        case "warning": self = .warning
        case "neutral": self = .neutral
        default: return nil
        }
    }

    var rawValue: String {
        switch self {
        case .positive: return "positive"
        case .suggestion: return "suggestion"
        case .warning: return "warning"
        case .neutral: return "neutral"
        }
    }
}

// MARK: - Cached Insight

struct CachedInsight: Codable {
    let icon: String
    let title: String
    let description: String
    let typeRawValue: String

    init(from insight: Insight) {
        self.icon = insight.icon
        self.title = insight.title
        self.description = insight.description
        self.typeRawValue = insight.type.rawValue
    }
}

// MARK: - Array Extension

extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
