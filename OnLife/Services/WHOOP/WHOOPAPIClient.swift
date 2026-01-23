//
//  WHOOPAPIClient.swift
//  OnLife
//
//  REST API client for WHOOP Developer API
//  Handles all data fetching with automatic token management
//

import Foundation

/// WHOOP API client for fetching biometric data
/// Uses WHOOPAuthService for authentication
@MainActor
final class WHOOPAPIClient: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = WHOOPAPIClient()

    // MARK: - Properties

    private let authService = WHOOPAuthService.shared
    private let baseURL = "https://api.prod.whoop.com/developer/v2"

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Note: We use explicit CodingKeys in models, not keyDecodingStrategy
        return decoder
    }()

    // MARK: - Initialization

    private init() {
        print("📊 [WHOOPAPIClient] Initialized")
    }

    // MARK: - Cycle Methods

    /// Fetch physiological cycles (strain, HR data)
    /// - Parameters:
    ///   - limit: Maximum number of records to return (default 25, max 25)
    ///   - nextToken: Pagination token for fetching more results
    /// - Returns: WHOOPCycleResponse with records and optional next token
    func fetchCycles(limit: Int = 25, nextToken: String? = nil) async throws -> WHOOPCycleResponse {
        print("📊 [WHOOPAPIClient] fetchCycles(limit: \(limit))")
        return try await request(endpoint: "/cycle", limit: limit, nextToken: nextToken)
    }

    /// Get today's cycle (most recent)
    /// - Returns: The current/most recent cycle or nil if none exists
    func getTodayCycle() async throws -> WHOOPCycle? {
        let response = try await fetchCycles(limit: 1)
        return response.records.first
    }

    // MARK: - Recovery Methods

    /// Fetch recovery data (HRV, recovery score, RHR)
    /// - Parameters:
    ///   - limit: Maximum number of records to return (default 25, max 25)
    ///   - nextToken: Pagination token for fetching more results
    /// - Returns: WHOOPRecoveryResponse with records and optional next token
    func fetchRecovery(limit: Int = 25, nextToken: String? = nil) async throws -> WHOOPRecoveryResponse {
        print("📊 [WHOOPAPIClient] fetchRecovery(limit: \(limit))")
        return try await request(endpoint: "/recovery", limit: limit, nextToken: nextToken)
    }

    /// Get latest recovery (most recent record)
    /// - Returns: The most recent recovery or nil if none exists
    func getLatestRecovery() async throws -> WHOOPRecovery? {
        let response = try await fetchRecovery(limit: 1)
        return response.records.first
    }

    // MARK: - Sleep Methods

    /// Fetch sleep data (stages, duration, efficiency)
    /// - Parameters:
    ///   - limit: Maximum number of records to return (default 25, max 25)
    ///   - nextToken: Pagination token for fetching more results
    /// - Returns: WHOOPSleepResponse with records and optional next token
    func fetchSleep(limit: Int = 25, nextToken: String? = nil) async throws -> WHOOPSleepResponse {
        print("📊 [WHOOPAPIClient] fetchSleep(limit: \(limit))")
        return try await request(endpoint: "/activity/sleep", limit: limit, nextToken: nextToken)
    }

    /// Get last night's sleep (most recent non-nap sleep)
    /// - Returns: The most recent sleep record or nil if none exists
    func getLastSleep() async throws -> WHOOPSleep? {
        let response = try await fetchSleep(limit: 5)
        // Find the most recent non-nap sleep
        return response.records.first { !$0.nap } ?? response.records.first
    }

    // MARK: - Workout Methods

    /// Fetch workout data
    /// - Parameters:
    ///   - limit: Maximum number of records to return (default 25, max 25)
    ///   - nextToken: Pagination token for fetching more results
    /// - Returns: WHOOPWorkoutResponse with records and optional next token
    func fetchWorkouts(limit: Int = 25, nextToken: String? = nil) async throws -> WHOOPWorkoutResponse {
        print("📊 [WHOOPAPIClient] fetchWorkouts(limit: \(limit))")
        return try await request(endpoint: "/activity/workout", limit: limit, nextToken: nextToken)
    }

    /// Get latest workout
    /// - Returns: The most recent workout or nil if none exists
    func getLatestWorkout() async throws -> WHOOPWorkout? {
        let response = try await fetchWorkouts(limit: 1)
        return response.records.first
    }

    // MARK: - Body Measurement Methods

    /// Fetch body measurements (max HR for cognitive zone calculation)
    /// - Returns: WHOOPBodyMeasurement with height, weight, and max HR
    func fetchBodyMeasurement() async throws -> WHOOPBodyMeasurement {
        print("📊 [WHOOPAPIClient] fetchBodyMeasurement()")
        return try await request(endpoint: "/body_measurement")
    }

    // MARK: - Private Request Methods

    /// Generic request method for paginated endpoints
    private func request<T: Decodable>(
        endpoint: String,
        limit: Int = 25,
        nextToken: String? = nil
    ) async throws -> T {
        var urlComponents = URLComponents(string: baseURL + endpoint)

        // Add query parameters
        var queryItems = [URLQueryItem(name: "limit", value: String(min(limit, 25)))]
        if let token = nextToken {
            queryItems.append(URLQueryItem(name: "nextToken", value: token))
        }
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            print("📊 [WHOOPAPIClient] ERROR: Failed to construct URL for \(endpoint)")
            throw WHOOPAuthError.urlConstructionFailed
        }

        return try await performRequest(url: url)
    }

    /// Generic request method for non-paginated endpoints
    private func request<T: Decodable>(endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            print("📊 [WHOOPAPIClient] ERROR: Failed to construct URL for \(endpoint)")
            throw WHOOPAuthError.urlConstructionFailed
        }

        return try await performRequest(url: url)
    }

    /// Performs the actual HTTP request with authentication
    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        // Get valid token (will refresh if needed)
        let token = try await authService.getValidAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        print("📊 [WHOOPAPIClient] Request: GET \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("📊 [WHOOPAPIClient] ERROR: Invalid response type")
            throw WHOOPAuthError.invalidResponse
        }

        print("📊 [WHOOPAPIClient] Response status: \(httpResponse.statusCode)")

        // Log response for debugging
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📊 [WHOOPAPIClient] Response body: \(jsonString.prefix(300))...")
        }
        #endif

        // Handle error responses
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            print("📊 [WHOOPAPIClient] ERROR: API returned status \(httpResponse.statusCode)")
            print("📊 [WHOOPAPIClient] ERROR body: \(message ?? "nil")")

            switch httpResponse.statusCode {
            case 401:
                throw WHOOPAuthError.notAuthenticated
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
                throw WHOOPAuthError.rateLimited(retryAfter: retryAfter)
            default:
                throw WHOOPAuthError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
        }

        // Decode response
        do {
            let result = try decoder.decode(T.self, from: data)
            print("📊 [WHOOPAPIClient] Successfully decoded response")
            return result
        } catch {
            print("📊 [WHOOPAPIClient] ERROR: Failed to decode response - \(error)")
            throw WHOOPAuthError.invalidResponse
        }
    }
}

// MARK: - Safe Fetch Methods (Handle 404s for New Users)

extension WHOOPAPIClient {

    /// Fetches a summary of latest WHOOP data for dashboard display
    /// Returns partial data if some endpoints return 404 (normal for new users)
    /// This method never throws - missing data returns nil
    func fetchDashboardData() async -> WHOOPDashboardData {
        print("📊 [WHOOPAPIClient] fetchDashboardData()")

        // Fetch all in parallel, but don't fail if some return 404
        async let cycleResult = fetchCyclesSafe()
        async let recoveryResult = fetchRecoverySafe()
        async let sleepResult = fetchSleepSafe()

        let (cycle, recovery, sleep) = await (cycleResult, recoveryResult, sleepResult)

        return WHOOPDashboardData(
            cycle: cycle,
            recovery: recovery,
            sleep: sleep
        )
    }

    /// Safe version that returns nil instead of throwing on 404
    private func fetchCyclesSafe() async -> WHOOPCycle? {
        do {
            let response = try await fetchCycles(limit: 1)
            return response.records.first
        } catch {
            print("📊 [WHOOPAPIClient] Cycles unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    /// Safe version that returns nil instead of throwing on 404
    private func fetchRecoverySafe() async -> WHOOPRecovery? {
        do {
            let response = try await fetchRecovery(limit: 1)
            return response.records.first
        } catch {
            print("📊 [WHOOPAPIClient] Recovery unavailable (normal for new users): \(error.localizedDescription)")
            return nil
        }
    }

    /// Safe version that returns nil instead of throwing on 404
    private func fetchSleepSafe() async -> WHOOPSleep? {
        do {
            let response = try await fetchSleep(limit: 5)
            // Get most recent non-nap sleep
            return response.records.first { !$0.nap } ?? response.records.first
        } catch {
            print("📊 [WHOOPAPIClient] Sleep unavailable (normal for new users): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Dashboard Data Model

/// Combined data for dashboard display
struct WHOOPDashboardData {
    let cycle: WHOOPCycle?
    let recovery: WHOOPRecovery?
    let sleep: WHOOPSleep?

    /// Whether any data is available
    var hasAnyData: Bool {
        cycle != nil || recovery != nil || sleep != nil
    }

    /// User-friendly status message
    var statusMessage: String {
        if recovery != nil {
            return "Full data available"
        } else if cycle != nil {
            return "Calibrating - sleep with WHOOP tonight for recovery data"
        } else {
            return "No data yet - keep wearing WHOOP"
        }
    }

    /// Recovery score percentage (0-100)
    var recoveryScore: Double? {
        recovery?.score?.recoveryScore
    }

    /// HRV in milliseconds (key metric for flow state)
    var hrvRmssd: Double? {
        recovery?.score?.hrvRmssdMilli
    }

    /// Resting heart rate in BPM
    var restingHeartRate: Double? {
        recovery?.score?.restingHeartRate
    }

    /// Current day strain (0-21)
    var strain: Double? {
        cycle?.score?.strain
    }

    /// Average heart rate from today's cycle
    var averageHeartRate: Int? {
        cycle?.score?.averageHeartRate
    }

    /// Sleep performance percentage
    var sleepPerformance: Double? {
        sleep?.score?.sleepPerformancePercentage
    }

    /// Total sleep time in hours
    var totalSleepHours: Double? {
        guard let stageSummary = sleep?.score?.stageSummary else { return nil }
        let totalSleepMilli = stageSummary.totalInBedTimeMilli - stageSummary.totalAwakeTimeMilli
        return Double(totalSleepMilli) / 3_600_000.0
    }
}
