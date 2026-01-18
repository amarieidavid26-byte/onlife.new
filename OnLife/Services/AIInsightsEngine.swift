import Foundation
import Combine

// MARK: - Design Notes
/*
 AI Insights Engine

 Purpose: Transform raw biometric, behavioral, and contextual data into
 personalized, actionable insights using Gemini API.

 Principles:
 1. Data-driven: Every insight must cite specific user data
 2. Actionable: Most insights should have a clear next step
 3. Confidence-aware: Reflect uncertainty when data is limited
 4. Non-medical: Focus on productivity, never health diagnoses
 5. Personalized: No generic advice that ignores user context

 API: Google Gemini 2.0 Flash (fast, cost-effective for this use case)
*/

// MARK: - Insight Types

/// A personalized insight generated from user data
struct AIInsight: Identifiable, Codable, Equatable {
    let id: UUID
    let type: InsightType
    let title: String
    let body: String
    let confidence: Double       // 0-1, based on data availability
    let actionable: Bool
    let action: String?          // Specific action to take
    let dataPoints: [String]     // Evidence supporting the insight
    let generatedAt: Date
    let expiresAt: Date?         // Some insights are time-sensitive

    enum InsightType: String, Codable, CaseIterable {
        case peakTiming = "Peak Timing"
        case caffeineOptimization = "Caffeine"
        case sleepImpact = "Sleep Impact"
        case patternDiscovery = "Pattern"
        case flowTrigger = "Flow Trigger"
        case warningAlert = "Warning"
        case weeklyReview = "Weekly Review"
        case streakMotivation = "Streak"
        case improvementOpportunity = "Improvement"

        var icon: String {
            switch self {
            case .peakTiming: return "clock.badge.checkmark"
            case .caffeineOptimization: return "cup.and.saucer"
            case .sleepImpact: return "moon.zzz"
            case .patternDiscovery: return "chart.line.uptrend.xyaxis"
            case .flowTrigger: return "brain.head.profile"
            case .warningAlert: return "exclamationmark.triangle"
            case .weeklyReview: return "calendar"
            case .streakMotivation: return "flame"
            case .improvementOpportunity: return "arrow.up.circle"
            }
        }

        var color: String {
            switch self {
            case .peakTiming: return "blue"
            case .caffeineOptimization: return "brown"
            case .sleepImpact: return "indigo"
            case .patternDiscovery: return "purple"
            case .flowTrigger: return "green"
            case .warningAlert: return "orange"
            case .weeklyReview: return "teal"
            case .streakMotivation: return "red"
            case .improvementOpportunity: return "mint"
            }
        }
    }

    static func == (lhs: AIInsight, rhs: AIInsight) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - User Context for Insights

/// Aggregated user data for insight generation
struct InsightContext: Codable {
    let userProfile: UserProfileSummary
    let recentSessions: [SessionSummary]
    let recentSleep: [SleepSummary]
    let recentSubstances: [SubstanceSummary]
    let currentStats: CurrentStats
    let environmentalFactors: EnvironmentalFactors?

    struct UserProfileSummary: Codable {
        let age: Int
        let chronotype: String
        let caffeineMetabolism: String      // fast/normal/slow
        let daysUsingApp: Int
        let dailyGoal: Int
        let preferredSessionDuration: Int   // minutes
    }

    struct SessionSummary: Codable {
        let date: Date
        let duration: TimeInterval
        let flowScore: Double
        let completed: Bool
        let hourOfDay: Int
        let dayOfWeek: Int
        let interruptionCount: Int?
    }

    struct SleepSummary: Codable {
        let date: Date
        let duration: TimeInterval
        let quality: Double                 // 0-100 SQI
        let bedtime: Date?
        let wakeTime: Date?
    }

    struct SubstanceSummary: Codable {
        let date: Date
        let type: String                    // caffeine, lTheanine, water
        let amount: Double
        let timingRelativeToSession: TimeInterval?  // negative = before session
    }

    struct CurrentStats: Codable {
        let avgFlowScore: Double
        let avgSessionDuration: TimeInterval
        let completionRate: Double
        let peakHour: Int
        let worstHour: Int
        let currentStreak: Int
        let longestStreak: Int
        let totalSessions: Int
        let totalFocusHours: Double
        let weekOverWeekChange: Double?     // % change in flow score
    }

    struct EnvironmentalFactors: Codable {
        let currentHour: Int
        let dayOfWeek: Int
        let isWeekend: Bool
        let weather: String?
        let locationContext: String?        // home, office, etc.
    }
}

// MARK: - Raw Insight for Parsing

private struct RawInsight: Codable {
    let type: String
    let title: String
    let body: String
    let confidence: Double
    let actionable: Bool
    let action: String?
    let dataPoints: [String]
}

// MARK: - Insight Errors

enum InsightError: LocalizedError {
    case noAPIKey
    case networkError(Error)
    case apiError(Int, String)
    case rateLimited
    case noContent
    case parsingError(String)
    case blockedContent(String)
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Gemini API key not configured"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .noContent:
            return "No insights generated"
        case .parsingError(let detail):
            return "Failed to parse insights: \(detail)"
        case .blockedContent(let reason):
            return "Content blocked: \(reason)"
        case .insufficientData:
            return "Not enough data for meaningful insights"
        }
    }
}

// MARK: - AI Insights Engine

/// Generates personalized insights using Gemini API
class AIInsightsEngine: ObservableObject {

    static let shared = AIInsightsEngine()

    // MARK: - Published Properties

    @Published private(set) var insights: [AIInsight] = []
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var lastError: InsightError?
    @Published private(set) var lastGeneratedAt: Date?

    // MARK: - Configuration

    private var geminiAPIKey: String?
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    /// Minimum sessions required for meaningful insights
    private let minimumSessionsForInsights = 3

    /// Cache duration for insights (regenerate after this time)
    private let insightCacheDuration: TimeInterval = 6 * 3600  // 6 hours

    // MARK: - Rate Limiting

    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 60  // 1 minute between requests

    // MARK: - Initialization

    init() {
        loadAPIKey()
    }

    /// Configure with API key
    func configure(apiKey: String) {
        self.geminiAPIKey = apiKey
        saveAPIKey(apiKey)
    }

    private func loadAPIKey() {
        // 1. Check UserDefaults (user-configured)
        geminiAPIKey = UserDefaults.standard.string(forKey: "gemini_api_key")

        // 2. Check environment variable (Xcode scheme)
        if geminiAPIKey == nil || geminiAPIKey?.isEmpty == true {
            if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
               !envKey.isEmpty, envKey != "PLACEHOLDER_KEY" {
                geminiAPIKey = envKey
            }
        }

        // 3. Check compiled APIKeys (from APIKeys.swift)
        if geminiAPIKey == nil || geminiAPIKey?.isEmpty == true {
            let compiledKey = APIKeys.geminiAPIKey
            if !compiledKey.isEmpty && compiledKey != "PLACEHOLDER_KEY" {
                geminiAPIKey = compiledKey
                print("🔑 [AIInsights] Loaded API key from APIKeys.swift")
            }
        }
    }

    private func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "gemini_api_key")
    }

    // MARK: - Generate Insights

    /// Generate personalized insights from user context
    @MainActor
    func generateInsights(context: InsightContext) async throws -> [AIInsight] {
        // Validate API key
        guard let apiKey = geminiAPIKey, !apiKey.isEmpty else {
            throw InsightError.noAPIKey
        }

        // Check for sufficient data
        guard context.recentSessions.count >= minimumSessionsForInsights else {
            throw InsightError.insufficientData
        }

        // Rate limiting
        if let lastRequest = lastRequestTime,
           Date().timeIntervalSince(lastRequest) < minimumRequestInterval {
            throw InsightError.rateLimited
        }

        isGenerating = true
        lastError = nil

        defer {
            isGenerating = false
            lastRequestTime = Date()
        }

        do {
            let prompt = buildInsightPrompt(context: context)
            let insights = try await callGeminiAPI(prompt: prompt, apiKey: apiKey)

            self.insights = insights
            self.lastGeneratedAt = Date()

            print("🤖 [AIInsights] Generated \(insights.count) insights")

            return insights
        } catch let error as InsightError {
            lastError = error
            throw error
        } catch {
            let insightError = InsightError.networkError(error)
            lastError = insightError
            throw insightError
        }
    }

    // MARK: - Build Prompt

    private func buildInsightPrompt(context: InsightContext) -> String {
        // Format sessions for the prompt
        let sessionsData = context.recentSessions.map { session -> [String: Any] in
            return [
                "date": ISO8601DateFormatter().string(from: session.date),
                "duration_min": Int(session.duration / 60),
                "flow_score": Int(session.flowScore),
                "completed": session.completed,
                "hour": session.hourOfDay,
                "day": session.dayOfWeek
            ]
        }

        let sessionsJSON = (try? JSONSerialization.data(withJSONObject: sessionsData, options: .prettyPrinted))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        // Format sleep data
        let sleepData = context.recentSleep.map { sleep -> [String: Any] in
            return [
                "date": ISO8601DateFormatter().string(from: sleep.date),
                "duration_hours": sleep.duration / 3600,
                "quality": Int(sleep.quality)
            ]
        }

        let sleepJSON = (try? JSONSerialization.data(withJSONObject: sleepData, options: .prettyPrinted))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        // Format substance data
        let substanceData = context.recentSubstances.map { sub -> [String: Any] in
            var dict: [String: Any] = [
                "date": ISO8601DateFormatter().string(from: sub.date),
                "type": sub.type,
                "amount": sub.amount
            ]
            if let timing = sub.timingRelativeToSession {
                dict["minutes_before_session"] = Int(-timing / 60)
            }
            return dict
        }

        let substanceJSON = (try? JSONSerialization.data(withJSONObject: substanceData, options: .prettyPrinted))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        return """
        You are an AI focus optimization coach for OnLife, a biometric-integrated productivity app that helps users achieve flow states. Analyze the user's data and generate 3-5 personalized, actionable insights.

        IMPORTANT RULES:
        1. Every insight MUST reference specific data from the user's history
        2. Do NOT give generic advice like "stay hydrated" or "get more sleep" without data support
        3. Confidence score (0-1) reflects how much data supports the insight
        4. Actions must be specific and immediately implementable
        5. Never give medical advice or diagnoses
        6. Focus on productivity patterns, not health conditions
        7. Use encouraging but professional tone

        USER PROFILE:
        - Age: \(context.userProfile.age)
        - Chronotype: \(context.userProfile.chronotype)
        - Caffeine metabolism: \(context.userProfile.caffeineMetabolism)
        - Days using app: \(context.userProfile.daysUsingApp)
        - Daily session goal: \(context.userProfile.dailyGoal)
        - Preferred session length: \(context.userProfile.preferredSessionDuration) minutes

        RECENT SESSIONS (last 7 days):
        \(sessionsJSON)

        RECENT SLEEP DATA:
        \(sleepJSON)

        RECENT SUBSTANCE INTAKE:
        \(substanceJSON)

        CURRENT STATS:
        - Average flow score: \(String(format: "%.1f", context.currentStats.avgFlowScore))
        - Average session duration: \(Int(context.currentStats.avgSessionDuration / 60)) minutes
        - Completion rate: \(Int(context.currentStats.completionRate * 100))%
        - Peak performance hour: \(context.currentStats.peakHour):00
        - Worst performance hour: \(context.currentStats.worstHour):00
        - Current streak: \(context.currentStats.currentStreak) days
        - Longest streak: \(context.currentStats.longestStreak) days
        - Total sessions: \(context.currentStats.totalSessions)
        - Total focus hours: \(String(format: "%.1f", context.currentStats.totalFocusHours))
        \(context.currentStats.weekOverWeekChange.map { "- Week-over-week change: \(String(format: "%+.1f", $0 * 100))%" } ?? "")

        ENVIRONMENT:
        \(context.environmentalFactors.map { "- Current hour: \($0.currentHour):00\n- Day: \($0.isWeekend ? "Weekend" : "Weekday")" } ?? "Not available")

        Generate insights in this exact JSON format (no markdown, just raw JSON array):
        [
            {
                "type": "peakTiming|caffeineOptimization|sleepImpact|patternDiscovery|flowTrigger|warningAlert|weeklyReview|streakMotivation|improvementOpportunity",
                "title": "Short, engaging title (max 40 chars)",
                "body": "2-3 sentence explanation citing specific data from above. Include numbers.",
                "confidence": 0.0-1.0,
                "actionable": true|false,
                "action": "Specific action to take right now (if actionable, otherwise null)",
                "dataPoints": ["specific evidence 1", "specific evidence 2"]
            }
        ]

        INSIGHT TYPE GUIDELINES:
        - peakTiming: When user performs best/worst
        - caffeineOptimization: Caffeine timing relative to sessions
        - sleepImpact: How sleep affects next-day performance
        - patternDiscovery: Interesting correlations in data
        - flowTrigger: What conditions lead to high flow scores
        - warningAlert: Concerning patterns (declining scores, missed days)
        - weeklyReview: Summary of the week's performance
        - streakMotivation: Streak-related encouragement
        - improvementOpportunity: Specific area to improve

        Generate 3-5 insights as a raw JSON array (no markdown formatting):
        """
    }

    // MARK: - Call Gemini API

    private func callGeminiAPI(prompt: String, apiKey: String) async throws -> [AIInsight] {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw InsightError.apiError(0, "Invalid URL")
        }

        // Build request body using existing GeminiRequest type
        let requestBody = GeminiRequest(
            contents: [
                GeminiRequest.Content(
                    parts: [GeminiRequest.Content.Part(text: prompt)]
                )
            ],
            generationConfig: GeminiRequest.GenerationConfig(
                temperature: 0.7,
                maxOutputTokens: 2500,
                topP: 0.95,
                topK: 40
            )
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InsightError.networkError(URLError(.badServerResponse))
        }

        // Handle HTTP errors
        if httpResponse.statusCode == 429 {
            throw InsightError.rateLimited
        }

        if httpResponse.statusCode != 200 {
            // Try to parse error from response
            if let responseStr = String(data: data, encoding: .utf8) {
                throw InsightError.apiError(httpResponse.statusCode, responseStr.prefix(200).description)
            }
            throw InsightError.apiError(httpResponse.statusCode, "Request failed")
        }

        // Parse response using existing GeminiResponse type
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let candidates = geminiResponse.candidates,
              let firstCandidate = candidates.first,
              let text = firstCandidate.content.parts.first?.text else {
            throw InsightError.noContent
        }

        return parseInsights(from: text)
    }

    // MARK: - Parse Response

    private func parseInsights(from text: String) -> [AIInsight] {
        // Extract JSON from response (may have markdown code blocks)
        var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }

        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find JSON array bounds
        guard let startIndex = jsonString.firstIndex(of: "["),
              let endIndex = jsonString.lastIndex(of: "]") else {
            print("🤖 [AIInsights] Could not find JSON array in response")
            return []
        }

        jsonString = String(jsonString[startIndex...endIndex])

        guard let data = jsonString.data(using: .utf8) else {
            print("🤖 [AIInsights] Could not convert to data")
            return []
        }

        do {
            let rawInsights = try JSONDecoder().decode([RawInsight].self, from: data)

            return rawInsights.compactMap { raw -> AIInsight? in
                let type = AIInsight.InsightType(rawValue: raw.type) ??
                    AIInsight.InsightType.allCases.first(where: {
                        $0.rawValue.lowercased() == raw.type.lowercased()
                    }) ?? .patternDiscovery

                return AIInsight(
                    id: UUID(),
                    type: type,
                    title: raw.title,
                    body: raw.body,
                    confidence: max(0, min(1, raw.confidence)),
                    actionable: raw.actionable,
                    action: raw.action,
                    dataPoints: raw.dataPoints,
                    generatedAt: Date(),
                    expiresAt: Date().addingTimeInterval(insightCacheDuration)
                )
            }
        } catch {
            print("🤖 [AIInsights] JSON parsing error: \(error)")
            return []
        }
    }

    // MARK: - Quick Insight (Single Topic)

    /// Generate a quick, focused insight on a specific topic
    @MainActor
    func generateQuickInsight(topic: AIInsight.InsightType, context: InsightContext) async throws -> AIInsight? {
        guard let apiKey = geminiAPIKey, !apiKey.isEmpty else {
            throw InsightError.noAPIKey
        }

        let prompt = """
        Generate ONE focused insight about "\(topic.rawValue)" for this user.

        User's average flow score: \(context.currentStats.avgFlowScore)
        Peak hour: \(context.currentStats.peakHour):00
        Current streak: \(context.currentStats.currentStreak) days

        Respond with a single JSON object (no array, no markdown):
        {
            "type": "\(topic.rawValue)",
            "title": "Short title",
            "body": "2-3 sentences with specific advice",
            "confidence": 0.7,
            "actionable": true,
            "action": "Specific action",
            "dataPoints": ["evidence"]
        }
        """

        let insights = try await callGeminiAPI(prompt: prompt, apiKey: apiKey)
        return insights.first
    }

    // MARK: - Cache Management

    /// Check if insights need refresh
    var needsRefresh: Bool {
        guard let lastGenerated = lastGeneratedAt else { return true }
        return Date().timeIntervalSince(lastGenerated) > insightCacheDuration
    }

    /// Clear cached insights
    func clearCache() {
        insights = []
        lastGeneratedAt = nil
    }

    // MARK: - Utility

    /// Get insights filtered by type
    func insights(ofType type: AIInsight.InsightType) -> [AIInsight] {
        return insights.filter { $0.type == type }
    }

    /// Get high-confidence insights only
    func highConfidenceInsights(threshold: Double = 0.7) -> [AIInsight] {
        return insights.filter { $0.confidence >= threshold }
    }

    /// Get actionable insights only
    var actionableInsights: [AIInsight] {
        return insights.filter { $0.actionable && $0.action != nil }
    }
}
