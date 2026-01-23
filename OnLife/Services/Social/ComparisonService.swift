import Foundation
import FirebaseFirestore
import Combine

// MARK: - Comparison Data

struct ComparisonData: Identifiable {
    let id = UUID()
    let yourProfile: UserProfile
    let theirProfile: UserProfile

    // Trajectory comparison (30-day improvement %)
    let yourTrajectory: Double
    let theirTrajectory: Double

    // Consistency (sessions per week)
    let yourSessionsPerWeek: Double
    let theirSessionsPerWeek: Double

    // Flow depth (average quality)
    let yourAvgFlowScore: Int
    let theirAvgFlowScore: Int

    // Context
    let experienceDifferenceMonths: Int
    let yourPercentileForExperience: Int

    // Insights
    var insights: [ComparisonInsight]

    // MARK: - Computed Properties

    var trajectoryWinner: ComparisonWinner {
        if yourTrajectory > theirTrajectory + 2 {
            return .you
        } else if theirTrajectory > yourTrajectory + 2 {
            return .them
        }
        return .tie
    }

    var consistencyWinner: ComparisonWinner {
        if yourSessionsPerWeek > theirSessionsPerWeek + 0.5 {
            return .you
        } else if theirSessionsPerWeek > yourSessionsPerWeek + 0.5 {
            return .them
        }
        return .tie
    }

    var flowDepthWinner: ComparisonWinner {
        if yourAvgFlowScore > theirAvgFlowScore + 5 {
            return .you
        } else if theirAvgFlowScore > yourAvgFlowScore + 5 {
            return .them
        }
        return .tie
    }

    enum ComparisonWinner {
        case you
        case them
        case tie
    }
}

// MARK: - Comparison Insight

struct ComparisonInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let type: InsightType
    let actionable: Bool
    let action: String?

    enum InsightType {
        case positive      // You're doing well
        case learning      // Something to learn from them
        case context       // Contextual information
        case neutral       // Neither good nor bad
    }
}

// MARK: - Comparison Mode

enum ComparisonDisplayMode {
    case inspiration    // Focus on what you can learn
    case competition    // Direct metric comparison

    var title: String {
        switch self {
        case .inspiration: return "Inspiration Mode"
        case .competition: return "Competition Mode"
        }
    }

    var description: String {
        switch self {
        case .inspiration:
            return "Focus on trajectories and what you can learn"
        case .competition:
            return "Direct metric comparison and rankings"
        }
    }
}

// MARK: - Comparison Service

@MainActor
class ComparisonService: ObservableObject {

    static let shared = ComparisonService()

    private let db = Firestore.firestore()
    private let socialService = SocialService.shared

    // MARK: - Published State

    @Published var comparisonData: ComparisonData?
    @Published var displayMode: ComparisonDisplayMode = .inspiration
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Initialization

    private init() {
        // Load user's preferred comparison mode
        loadPreferredMode()
    }

    private func loadPreferredMode() {
        if let profile = socialService.currentUserProfile {
            displayMode = profile.comparisonMode == .inspiration ? .inspiration : .competition
        }
    }

    // MARK: - Mode Management

    func setDisplayMode(_ mode: ComparisonDisplayMode) async {
        displayMode = mode

        // Save preference
        let modeValue: ComparisonMode = mode == .inspiration ? .inspiration : .competition
        try? await socialService.updateCurrentProfile([
            "comparisonMode": modeValue.rawValue
        ])
    }

    // MARK: - Comparison Generation

    /// Generate comparison between current user and another user
    func generateComparison(with friendId: String) async {
        guard let myProfile = socialService.currentUserProfile else {
            error = "Your profile not loaded"
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let theirProfile = await socialService.fetchProfile(userId: friendId) else {
            error = "Could not load friend's profile"
            return
        }

        // Fetch actual session data for both users
        let myStats = await fetchUserStats(userId: myProfile.id)
        let theirStats = await fetchUserStats(userId: theirProfile.id)

        // Calculate comparison metrics
        let yourTrajectory = myProfile.thirtyDayTrajectory
        let theirTrajectory = theirProfile.thirtyDayTrajectory

        // Calculate experience difference in months
        let experienceDiff = (theirProfile.masteryDurationDays - myProfile.masteryDurationDays) / 30

        // Generate insights based on comparison mode
        let insights = generateInsights(
            myProfile: myProfile,
            theirProfile: theirProfile,
            myStats: myStats,
            theirStats: theirStats
        )

        self.comparisonData = ComparisonData(
            yourProfile: myProfile,
            theirProfile: theirProfile,
            yourTrajectory: yourTrajectory,
            theirTrajectory: theirTrajectory,
            yourSessionsPerWeek: myStats.sessionsPerWeek,
            theirSessionsPerWeek: theirStats.sessionsPerWeek,
            yourAvgFlowScore: myStats.avgFlowScore,
            theirAvgFlowScore: theirStats.avgFlowScore,
            experienceDifferenceMonths: max(0, experienceDiff),
            yourPercentileForExperience: myProfile.consistencyPercentile,
            insights: insights
        )
    }

    /// Generate comparison between current user and multiple friends
    func generateGroupComparison(with friendIds: [String]) async -> [ComparisonData] {
        var comparisons: [ComparisonData] = []

        for friendId in friendIds {
            await generateComparison(with: friendId)
            if let data = comparisonData {
                comparisons.append(data)
            }
        }

        return comparisons
    }

    // MARK: - Stats Fetching

    private struct UserStats {
        var sessionsPerWeek: Double
        var avgFlowScore: Int
        var totalSessions: Int
        var bestFlowScore: Int
        var currentStreak: Int
    }

    private func fetchUserStats(userId: String) async -> UserStats {
        // Fetch from focus_sessions collection
        do {
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

            let sessionsSnapshot = try await db.collection("focus_sessions")
                .whereField("userId", isEqualTo: userId)
                .whereField("startTime", isGreaterThan: Timestamp(date: thirtyDaysAgo))
                .getDocuments()

            let sessions = sessionsSnapshot.documents
            let totalSessions = sessions.count
            let sessionsPerWeek = Double(totalSessions) / 4.0 // 30 days ≈ 4 weeks

            // Calculate average flow score
            var totalFlowScore = 0
            var bestFlowScore = 0
            var scoredSessions = 0

            for doc in sessions {
                if let flowScore = doc.data()["flowScore"] as? Int {
                    totalFlowScore += flowScore
                    scoredSessions += 1
                    bestFlowScore = max(bestFlowScore, flowScore)
                }
            }

            let avgFlowScore = scoredSessions > 0 ? totalFlowScore / scoredSessions : 0

            return UserStats(
                sessionsPerWeek: sessionsPerWeek,
                avgFlowScore: avgFlowScore,
                totalSessions: totalSessions,
                bestFlowScore: bestFlowScore,
                currentStreak: 0 // Would need separate logic
            )

        } catch {
            // Return default stats if fetch fails
            return UserStats(
                sessionsPerWeek: 0,
                avgFlowScore: 0,
                totalSessions: 0,
                bestFlowScore: 0,
                currentStreak: 0
            )
        }
    }

    // MARK: - Insight Generation

    private func generateInsights(
        myProfile: UserProfile,
        theirProfile: UserProfile,
        myStats: UserStats,
        theirStats: UserStats
    ) -> [ComparisonInsight] {

        var insights: [ComparisonInsight] = []

        // Trajectory insight
        let trajectoryDiff = myProfile.thirtyDayTrajectory - theirProfile.thirtyDayTrajectory

        if trajectoryDiff > 5 {
            insights.append(ComparisonInsight(
                icon: "chart.line.uptrend.xyaxis",
                title: "Learning faster",
                description: "Your improvement rate is \(Int(trajectoryDiff))% higher right now!",
                type: .positive,
                actionable: false,
                action: nil
            ))
        } else if trajectoryDiff < -5 {
            insights.append(ComparisonInsight(
                icon: "lightbulb",
                title: "They're improving faster",
                description: "Their trajectory is \(Int(abs(trajectoryDiff)))% higher—check their protocol",
                type: .learning,
                actionable: true,
                action: "View Protocol"
            ))
        }

        // Experience context (always show if significant)
        let experienceDiff = (theirProfile.masteryDurationDays - myProfile.masteryDurationDays) / 30

        if experienceDiff > 2 {
            insights.append(ComparisonInsight(
                icon: "calendar",
                title: "Experience difference",
                description: "They've been training \(experienceDiff) months longer",
                type: .context,
                actionable: false,
                action: nil
            ))
        } else if experienceDiff < -2 {
            insights.append(ComparisonInsight(
                icon: "calendar",
                title: "You have more experience",
                description: "You've been training \(abs(experienceDiff)) months longer",
                type: .context,
                actionable: false,
                action: nil
            ))
        }

        // Consistency insight
        let consistencyDiff = theirStats.sessionsPerWeek - myStats.sessionsPerWeek

        if consistencyDiff > 1 {
            insights.append(ComparisonInsight(
                icon: "repeat",
                title: "Higher consistency",
                description: "Their \(String(format: "%.1f", theirStats.sessionsPerWeek)) sessions/week might explain better results",
                type: .learning,
                actionable: true,
                action: "Schedule Sessions"
            ))
        } else if consistencyDiff < -1 {
            insights.append(ComparisonInsight(
                icon: "checkmark.circle",
                title: "More consistent",
                description: "Your \(String(format: "%.1f", myStats.sessionsPerWeek)) sessions/week shows great dedication",
                type: .positive,
                actionable: false,
                action: nil
            ))
        }

        // Flow depth insight
        let flowDiff = theirStats.avgFlowScore - myStats.avgFlowScore

        if flowDiff > 10 {
            insights.append(ComparisonInsight(
                icon: "waveform.path",
                title: "Deeper flow states",
                description: "Their average quality is \(flowDiff)% higher",
                type: .learning,
                actionable: true,
                action: "See Their Techniques"
            ))
        }

        // Chronotype insight (if similar)
        if myProfile.chronotype == theirProfile.chronotype {
            insights.append(ComparisonInsight(
                icon: myProfile.chronotype.icon,
                title: "Same chronotype",
                description: "You're both \(myProfile.chronotype.rawValue)s—their strategies may work well for you",
                type: .context,
                actionable: true,
                action: "View Protocol"
            ))
        }

        // Current protocol insight
        if let protocolId = theirProfile.currentProtocolId, !protocolId.isEmpty {
            insights.append(ComparisonInsight(
                icon: "doc.text",
                title: "Active protocol",
                description: "They're currently using a shared protocol",
                type: .neutral,
                actionable: true,
                action: "View Protocol"
            ))
        }

        return insights
    }

    // MARK: - Leaderboard (Competition Mode)

    /// Get ranking among friends for a specific metric
    func getFriendRanking(for metric: RankingMetric) async -> [RankingEntry] {
        guard let myProfile = socialService.currentUserProfile else { return [] }

        var entries: [RankingEntry] = []

        // Add current user
        let myStats = await fetchUserStats(userId: myProfile.id)
        entries.append(RankingEntry(
            profile: myProfile,
            value: getValue(for: metric, profile: myProfile, stats: myStats),
            isCurrentUser: true
        ))

        // Add friends
        for friend in socialService.friends {
            let stats = await fetchUserStats(userId: friend.id)
            entries.append(RankingEntry(
                profile: friend,
                value: getValue(for: metric, profile: friend, stats: stats),
                isCurrentUser: false
            ))
        }

        // Sort by value descending
        entries.sort { $0.value > $1.value }

        // Assign ranks
        for (index, _) in entries.enumerated() {
            entries[index].rank = index + 1
        }

        return entries
    }

    private func getValue(for metric: RankingMetric, profile: UserProfile, stats: UserStats) -> Double {
        switch metric {
        case .trajectory:
            return profile.thirtyDayTrajectory
        case .consistency:
            return stats.sessionsPerWeek
        case .flowDepth:
            return Double(stats.avgFlowScore)
        case .plantsGrown:
            return Double(profile.totalPlantsGrown)
        }
    }

    // MARK: - Clear

    func clearComparison() {
        comparisonData = nil
        error = nil
    }
}

// MARK: - Ranking Types

enum RankingMetric: String, CaseIterable {
    case trajectory = "30-Day Trajectory"
    case consistency = "Sessions/Week"
    case flowDepth = "Avg Flow Score"
    case plantsGrown = "Plants Grown"

    var icon: String {
        switch self {
        case .trajectory: return "chart.line.uptrend.xyaxis"
        case .consistency: return "calendar"
        case .flowDepth: return "waveform.path"
        case .plantsGrown: return "leaf"
        }
    }
}

struct RankingEntry: Identifiable {
    let id = UUID()
    let profile: UserProfile
    let value: Double
    let isCurrentUser: Bool
    var rank: Int = 0

    var formattedValue: String {
        if value == floor(value) {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}
