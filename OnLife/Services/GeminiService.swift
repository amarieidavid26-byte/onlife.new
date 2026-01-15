import Foundation

// MARK: - Error Types
enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case emptyResponse
    case rateLimited
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing. Please configure your API key."
        case .invalidURL:
            return "Failed to construct a valid URL for the Gemini API."
        case .invalidResponse:
            return "Received an invalid response from the Gemini API."
        case .emptyResponse:
            return "Gemini API returned an empty response."
        case .rateLimited:
            return "Rate limit exceeded. Please wait at least 60 seconds between API calls."
        case .httpError(let statusCode):
            return "HTTP error occurred with status code: \(statusCode)"
        }
    }
}

// MARK: - Response Models
struct GeminiResponse: Codable {
    let candidates: [Candidate]?

    struct Candidate: Codable {
        let content: Content

        struct Content: Codable {
            let parts: [Part]

            struct Part: Codable {
                let text: String
            }
        }
    }
}

// MARK: - Request Models
struct GeminiRequest: Codable {
    let contents: [Content]
    let generationConfig: GenerationConfig

    struct Content: Codable {
        let parts: [Part]

        struct Part: Codable {
            let text: String
        }
    }

    struct GenerationConfig: Codable {
        let temperature: Double
        let maxOutputTokens: Int
        let topP: Double
        let topK: Int
    }
}

// MARK: - Gemini Service
class GeminiService {
    static let shared = GeminiService()

    // Configuration
    // TODO: Get real API key from https://makersuite.google.com/app/apikey
    // Add to Config.xcconfig: GEMINI_API_KEY = your_key_here
    private var apiKey: String {
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty {
            return key
        }
        // Fallback for development
        return "PLACEHOLDER_KEY"
    }

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let model = "gemini-1.5-flash"

    // Rate limiting
    private var lastCallTime: Date?
    private let minimumCallInterval: TimeInterval = 60 // 60 seconds

    private init() {}

    // MARK: - Public Methods

    /// Generates a daily AI-powered insight based on user's focus patterns
    func generateDailyInsight(
        weeklySessionCount: Int,
        avgDuration: TimeInterval,
        completionRate: Double,
        currentStreak: Int,
        bestEnvironment: String,
        peakTime: String
    ) async throws -> String {
        // Check rate limiting
        if let lastCall = lastCallTime {
            let timeSinceLastCall = Date().timeIntervalSince(lastCall)
            if timeSinceLastCall < minimumCallInterval {
                throw GeminiError.rateLimited
            }
        }

        // Convert duration to minutes
        let avgMinutes = Int(avgDuration / 60)
        let completionPercentage = Int(completionRate * 100)

        // Build prompt
        let prompt = """
        You are OnLife, an encouraging focus coach.

        USER DATA:
        - Sessions this week: \(weeklySessionCount)
        - Average duration: \(avgMinutes) minutes
        - Completion rate: \(completionPercentage)%
        - Best environment: \(bestEnvironment)
        - Peak time: \(peakTime)
        - Current streak: \(currentStreak) days

        TASK: Generate ONE specific, encouraging insight.

        RULES:
        - ONE sentence only (max 120 characters)
        - Be specific and actionable
        - Use 0-1 emoji
        - Be encouraging, never critical
        - Focus on ONE pattern

        EXAMPLES:
        - "You focus 45% longer in coffee shops - schedule deep work there! ☕"
        - "Your morning sessions average 65 minutes - that's your sweet spot 🌅"
        - "7-day streak! Consistency is building your focus muscle 💪"

        Generate insight:
        """

        // Call API
        let insight = try await callGeminiAPI(
            prompt: prompt,
            temperature: 0.7,
            maxTokens: 150
        )

        // Update rate limiting
        lastCallTime = Date()

        return insight
    }

    // MARK: - Private Methods

    /// Makes the actual API call to Gemini
    private func callGeminiAPI(
        prompt: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        // Check API key
        guard apiKey != "PLACEHOLDER_KEY" && !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        // Build URL
        let urlString = "\(baseURL)/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build request body
        let requestBody = GeminiRequest(
            contents: [
                GeminiRequest.Content(
                    parts: [
                        GeminiRequest.Content.Part(text: prompt)
                    ]
                )
            ],
            generationConfig: GeminiRequest.GenerationConfig(
                temperature: temperature,
                maxOutputTokens: maxTokens,
                topP: 0.95,
                topK: 40
            )
        )

        // Encode request body
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        // Make API call
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw GeminiError.httpError(statusCode: httpResponse.statusCode)
            }
        }

        // Parse response
        let decoder = JSONDecoder()
        let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)

        // Extract text
        guard let candidates = geminiResponse.candidates,
              let firstCandidate = candidates.first,
              let firstPart = firstCandidate.content.parts.first else {
            throw GeminiError.emptyResponse
        }

        let text = firstPart.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw GeminiError.emptyResponse
        }

        return text
    }
}
