//
//  WHOOPAuthService.swift
//  OnLife
//
//  WHOOP OAuth 2.0 authentication service using ASWebAuthenticationSession
//

import Foundation
import AuthenticationServices
import Combine

/// Manages WHOOP OAuth 2.0 authentication flow
///
/// OAuth Flow:
/// 1. User taps "Connect WHOOP"
/// 2. App opens ASWebAuthenticationSession with WHOOP authorization URL
/// 3. User logs in on WHOOP's website
/// 4. WHOOP redirects to onlife://auth/callback?code=XXX&state=XXX
/// 5. App intercepts callback and extracts authorization code
/// 6. App POSTs code to token endpoint with credentials
/// 7. WHOOP returns access_token + refresh_token
/// 8. App stores tokens securely in Keychain
/// 9. App uses access_token for API calls
/// 10. When token expires, app uses refresh_token to get new tokens
@MainActor
final class WHOOPAuthService: NSObject, ObservableObject, @unchecked Sendable {

    // MARK: - Singleton

    static let shared = WHOOPAuthService()

    // MARK: - Published Properties

    /// Current authentication state
    @Published private(set) var authState: WHOOPAuthState = .disconnected

    /// Whether user is currently authenticated with WHOOP
    @Published private(set) var isAuthenticated: Bool = false

    // MARK: - OAuth Configuration

    private enum Config {
        static let clientId = "2b0edc70-a586-4edf-b9f7-c8eb601fcd19"
        static let redirectUri = "onlife://auth/callback"
        static let authorizationUrl = "https://api.prod.whoop.com/oauth/oauth2/auth"
        static let tokenUrl = "https://api.prod.whoop.com/oauth/oauth2/token"
        static let scopes = "read:recovery read:cycles read:sleep read:workout read:body_measurement"

        // SECURITY NOTE: Client secret should be moved to backend proxy in production
        // For development, store in secure location (not in source control)
        static let clientSecret = "be9bf7f731c4ab1257cc1e8daa300dae2875b9b3ec780d1de8091990fcacad9f"

        // State parameter must be exactly 8 characters per WHOOP spec
        static let stateLength = 8
    }

    // MARK: - Private Properties

    private let tokenManager = WHOOPTokenManager.shared
    private var currentState: String?
    private var authSession: ASWebAuthenticationSession?
    private var authContinuation: CheckedContinuation<Void, Error>?

    // MARK: - Initialization

    private override init() {
        super.init()
        print("🔐 [WHOOP] WHOOPAuthService initialized")
        // Check if user was previously authenticated
        updateAuthenticationStatus()
    }

    // MARK: - Public Methods

    /// Starts the OAuth authentication flow
    /// Opens WHOOP login page in a secure browser session
    /// - Throws: WHOOPAuthError on failure
    func startAuthentication() async throws {
        print("🔐 [WHOOP] ========== startAuthentication() BEGIN ==========")
        print("🔐 [WHOOP] Current authState: \(authState)")

        guard authState != .authenticating else {
            print("🔐 [WHOOP] ERROR: Authentication already in progress")
            return
        }

        authState = .authenticating
        print("🔐 [WHOOP] Set authState to .authenticating")

        do {
            // Generate cryptographically random state parameter
            currentState = generateSecureState()
            print("🔐 [WHOOP] Generated state: \(currentState ?? "nil")")

            // Construct authorization URL
            guard let authURL = buildAuthorizationURL() else {
                print("🔐 [WHOOP] ERROR: Failed to build authorization URL")
                throw WHOOPAuthError.urlConstructionFailed
            }
            print("🔐 [WHOOP] Authorization URL: \(authURL.absoluteString)")

            // Start ASWebAuthenticationSession
            print("🔐 [WHOOP] Starting web authentication session...")
            try await performWebAuthentication(url: authURL)

            print("🔐 [WHOOP] Web authentication completed, updating status...")
            updateAuthenticationStatus()
            print("🔐 [WHOOP] ========== startAuthentication() SUCCESS ==========")
        } catch {
            print("🔐 [WHOOP] ========== startAuthentication() FAILED ==========")
            print("🔐 [WHOOP] Error: \(error)")
            print("🔐 [WHOOP] Error type: \(type(of: error))")
            if let whoopError = error as? WHOOPAuthError {
                print("🔐 [WHOOP] WHOOPAuthError: \(whoopError.localizedDescription)")
            }
            authState = .error(error.localizedDescription)
            throw error
        }
    }

    /// Handles the OAuth callback URL from WHOOP
    /// Called when app receives the redirect URL
    /// - Parameter url: The callback URL with authorization code
    /// - Returns: true if URL was handled successfully
    @discardableResult
    func handleCallback(url: URL) async throws -> Bool {
        print("🔐 [WHOOP] ========== handleCallback() BEGIN ==========")
        print("🔐 [WHOOP] Full URL: \(url.absoluteString)")
        print("🔐 [WHOOP] Scheme: \(url.scheme ?? "nil")")
        print("🔐 [WHOOP] Host: \(url.host ?? "nil")")
        print("🔐 [WHOOP] Path: \(url.path)")
        print("🔐 [WHOOP] Query: \(url.query ?? "nil")")

        // Check URL format - handle both formats:
        // onlife://auth/callback (host = "auth", path = "/callback")
        // onlife:///auth/callback (host = nil, path = "/auth/callback")
        let isValidScheme = url.scheme == "onlife"
        let isAuthCallback = (url.host == "auth" && url.path == "/callback") ||
                            (url.host == nil && url.path == "/auth/callback") ||
                            url.path.contains("/callback")

        print("🔐 [WHOOP] isValidScheme: \(isValidScheme), isAuthCallback: \(isAuthCallback)")

        guard isValidScheme && isAuthCallback else {
            print("🔐 [WHOOP] URL doesn't match expected format, returning false")
            return false
        }

        // Parse URL components
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("🔐 [WHOOP] ERROR: Failed to parse URL components")
            throw WHOOPAuthError.invalidResponse
        }

        print("🔐 [WHOOP] Query items: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ", "))")

        // Check for error response
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value ?? "Unknown"
            print("🔐 [WHOOP] ERROR from WHOOP: \(error) - \(errorDescription)")
            if error == "access_denied" {
                throw WHOOPAuthError.authorizationDenied
            }
            throw WHOOPAuthError.serverError(statusCode: 0, message: "\(error): \(errorDescription)")
        }

        // Extract authorization code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            print("🔐 [WHOOP] ERROR: No authorization code in callback")
            throw WHOOPAuthError.missingAuthorizationCode
        }
        print("🔐 [WHOOP] Got authorization code: \(code.prefix(10))...")

        // Validate state parameter
        guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value else {
            print("🔐 [WHOOP] ERROR: No state parameter in callback")
            throw WHOOPAuthError.invalidState
        }
        print("🔐 [WHOOP] Returned state: \(returnedState)")
        print("🔐 [WHOOP] Expected state: \(currentState ?? "nil")")

        guard returnedState == currentState else {
            print("🔐 [WHOOP] ERROR: State mismatch!")
            throw WHOOPAuthError.invalidState
        }
        print("🔐 [WHOOP] State validated ✓")

        // Exchange code for tokens
        print("🔐 [WHOOP] Exchanging code for tokens...")
        try await exchangeCodeForTokens(code: code)

        print("🔐 [WHOOP] ========== handleCallback() SUCCESS ==========")
        return true
    }

    /// Exchanges authorization code for access and refresh tokens
    /// - Parameter code: The authorization code from callback
    private func exchangeCodeForTokens(code: String) async throws {
        print("🔐 [WHOOP] ========== exchangeCodeForTokens() BEGIN ==========")

        let tokenResponse = try await performTokenRequest(
            grantType: "authorization_code",
            code: code
        )

        print("🔐 [WHOOP] Token response received, saving to Keychain...")
        try tokenManager.saveTokens(from: tokenResponse)
        print("🔐 [WHOOP] Tokens saved ✓")

        authState = .connected
        isAuthenticated = true
        currentState = nil

        print("🔐 [WHOOP] ========== exchangeCodeForTokens() SUCCESS ==========")
    }

    /// Refreshes the access token using the refresh token
    /// Called automatically when access token is expired
    func refreshAccessToken() async throws {
        print("🔐 [WHOOP] ========== refreshAccessToken() BEGIN ==========")

        guard let refreshToken = tokenManager.getRefreshToken() else {
            print("🔐 [WHOOP] ERROR: No refresh token available - user must re-authenticate")
            authState = .error("Session expired")
            isAuthenticated = false
            throw WHOOPAuthError.noRefreshToken
        }

        authState = .refreshing
        print("🔐 [WHOOP] Set authState to .refreshing")

        do {
            let tokenResponse = try await performTokenRequest(
                grantType: "refresh_token",
                refreshToken: refreshToken
            )

            try tokenManager.saveTokens(from: tokenResponse)
            authState = .connected
            print("🔐 [WHOOP] ========== refreshAccessToken() SUCCESS ==========")
        } catch {
            print("🔐 [WHOOP] ERROR: Refresh failed - \(error)")
            // Refresh failed - user needs to re-authenticate
            authState = .error("Session expired")
            isAuthenticated = false
            throw WHOOPAuthError.refreshFailed
        }
    }

    /// Gets a valid access token, refreshing if necessary
    /// - Returns: Valid access token
    /// - Throws: WHOOPAuthError if not authenticated or refresh fails
    func getValidAccessToken() async throws -> String {
        guard let accessToken = tokenManager.getAccessToken() else {
            throw WHOOPAuthError.notAuthenticated
        }

        // Check if expired with 5-minute buffer
        if tokenManager.isTokenExpired(buffer: 300) {
            try await refreshAccessToken()
            guard let newToken = tokenManager.getAccessToken() else {
                throw WHOOPAuthError.refreshFailed
            }
            return newToken
        }

        return accessToken
    }

    /// Logs out and clears all stored tokens
    func logout() {
        print("🔐 [WHOOP] logout() called")
        do {
            try tokenManager.clearTokens()
            print("🔐 [WHOOP] Tokens cleared from Keychain")
        } catch {
            print("🔐 [WHOOP] Warning: Failed to clear tokens - \(error)")
        }

        currentState = nil
        authSession = nil
        authState = .disconnected
        isAuthenticated = false
        print("🔐 [WHOOP] Logout complete")
    }

    /// Convenience property for current access token (may be expired)
    var accessToken: String? {
        return tokenManager.getAccessToken()
    }

    // MARK: - API Methods

    /// Fetches cycles from WHOOP - tests read:cycles scope
    /// - Returns: Raw JSON response string
    /// - Throws: WHOOPAuthError if not authenticated or request fails
    func fetchCycles() async throws -> String {
        print("📊 [WHOOP] ========== fetchCycles() BEGIN ==========")

        // Get valid token (will refresh if needed)
        let token = try await getValidAccessToken()

        // Debug: Log token details
        print("📊 [WHOOP] Token length: \(token.count)")
        print("📊 [WHOOP] Token: \(token.prefix(20))...\(token.suffix(10))")

        guard let url = URL(string: "https://api.prod.whoop.com/developer/v1/cycle") else {
            throw WHOOPAuthError.urlConstructionFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        print("📊 [WHOOP] Request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("📊 [WHOOP] Fetching cycles from: \(url)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("📊 [WHOOP] ERROR: Invalid response type")
            throw WHOOPAuthError.invalidResponse
        }

        let responseString = String(data: data, encoding: .utf8) ?? "nil"
        print("📊 [WHOOP] Cycles API status: \(httpResponse.statusCode)")
        print("📊 [WHOOP] Response: \(responseString.prefix(500))...")

        guard httpResponse.statusCode == 200 else {
            print("📊 [WHOOP] ERROR: API returned status \(httpResponse.statusCode)")
            throw WHOOPAuthError.serverError(statusCode: httpResponse.statusCode, message: responseString)
        }

        print("📊 [WHOOP] ========== fetchCycles() SUCCESS ==========")
        return responseString
    }

    /// Fetches the user profile from WHOOP (simple test endpoint)
    /// - Returns: Raw JSON response string
    /// - Throws: WHOOPAuthError if not authenticated or request fails
    func fetchUserProfile() async throws -> String {
        print("📊 [WHOOP] ========== fetchUserProfile() BEGIN ==========")

        // Get valid token (will refresh if needed)
        let token = try await getValidAccessToken()
        print("📊 [WHOOP] Got valid access token")

        // Debug: Check token for issues
        print("📊 [WHOOP] Token length: \(token.count)")
        print("📊 [WHOOP] Token prefix/suffix: \(token.prefix(20))...\(token.suffix(10))")
        print("📊 [WHOOP] Token contains whitespace: \(token.contains { $0.isWhitespace })")
        print("📊 [WHOOP] Token contains newline: \(token.contains { $0.isNewline })")

        guard let url = URL(string: "https://api.prod.whoop.com/developer/v1/user/profile/basic") else {
            throw WHOOPAuthError.urlConstructionFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Build and log the Authorization header
        let authHeader = "Bearer \(token)"
        print("📊 [WHOOP] Authorization header length: \(authHeader.count)")
        print("📊 [WHOOP] Authorization header: Bearer \(token.prefix(20))...\(token.suffix(10))")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        // DEBUG: Uncomment below to test with hardcoded token (bypass Keychain)
        // let testToken = "PASTE_YOUR_TOKEN_HERE"
        // request.setValue("Bearer \(testToken)", forHTTPHeaderField: "Authorization")
        // print("📊 [WHOOP] ⚠️ USING HARDCODED TEST TOKEN")

        // Log all request headers
        print("📊 [WHOOP] Request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("📊 [WHOOP] Fetching user profile from: \(url)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("📊 [WHOOP] ERROR: Invalid response type")
            throw WHOOPAuthError.invalidResponse
        }

        let responseString = String(data: data, encoding: .utf8) ?? "nil"
        print("📊 [WHOOP] Profile API status: \(httpResponse.statusCode)")
        print("📊 [WHOOP] Response: \(responseString)")

        guard httpResponse.statusCode == 200 else {
            print("📊 [WHOOP] ERROR: API returned status \(httpResponse.statusCode)")
            throw WHOOPAuthError.serverError(statusCode: httpResponse.statusCode, message: responseString)
        }

        print("📊 [WHOOP] ========== fetchUserProfile() SUCCESS ==========")
        return responseString
    }

    /// Fetches the latest recovery data from WHOOP
    /// - Returns: The most recent WHOOPRecovery record
    /// - Throws: WHOOPAuthError if not authenticated or request fails
    func fetchLatestRecovery() async throws -> WHOOPRecovery {
        print("📊 [WHOOP] ========== fetchLatestRecovery() BEGIN ==========")

        // Get valid token (will refresh if needed)
        let token = try await getValidAccessToken()
        print("📊 [WHOOP] Got valid access token")

        // Debug: Check token for issues
        print("📊 [WHOOP] Token length: \(token.count)")
        print("📊 [WHOOP] Token prefix/suffix: \(token.prefix(20))...\(token.suffix(10))")

        guard let url = URL(string: "https://api.prod.whoop.com/developer/v1/recovery") else {
            throw WHOOPAuthError.urlConstructionFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Build and log the Authorization header
        let authHeader = "Bearer \(token)"
        print("📊 [WHOOP] Authorization header: Bearer \(token.prefix(20))...\(token.suffix(10))")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        print("📊 [WHOOP] Request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("📊 [WHOOP] Fetching recovery data from: \(url)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("📊 [WHOOP] ERROR: Invalid response type")
            throw WHOOPAuthError.invalidResponse
        }

        print("📊 [WHOOP] Recovery API status: \(httpResponse.statusCode)")

        // Log response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📊 [WHOOP] Response: \(jsonString.prefix(500))...")
        }

        // Handle non-200 responses
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            print("📊 [WHOOP] ERROR: API returned status \(httpResponse.statusCode)")
            throw WHOOPAuthError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        // Decode response - CodingKeys in models handle snake_case conversion
        let recoveryResponse: WHOOPRecoveryResponse
        do {
            recoveryResponse = try JSONDecoder().decode(WHOOPRecoveryResponse.self, from: data)
        } catch {
            print("📊 [WHOOP] ERROR: Failed to decode response - \(error)")
            throw WHOOPAuthError.invalidResponse
        }

        guard let firstRecovery = recoveryResponse.records.first else {
            print("📊 [WHOOP] ERROR: No recovery records returned")
            throw WHOOPAuthError.invalidResponse
        }

        // Log success details
        if let score = firstRecovery.score {
            print("✅ [WHOOP] Recovery: \(Int(score.recoveryScore))%")
            print("✅ [WHOOP] HRV: \(String(format: "%.1f", score.hrvRmssdMilli)) ms")
            print("✅ [WHOOP] RHR: \(Int(score.restingHeartRate)) bpm")
            print("✅ [WHOOP] Calibrating: \(score.userCalibrating)")
        } else {
            print("⚠️ [WHOOP] Recovery record has no score (scoreState: \(firstRecovery.scoreState))")
        }

        print("📊 [WHOOP] ========== fetchLatestRecovery() SUCCESS ==========")
        return firstRecovery
    }

    // MARK: - Private Methods

    /// Updates authentication status based on stored tokens
    private func updateAuthenticationStatus() {
        print("🔐 [WHOOP] updateAuthenticationStatus() - hasStoredTokens: \(tokenManager.hasStoredTokens)")
        if tokenManager.hasStoredTokens {
            isAuthenticated = true
            let isExpired = tokenManager.isTokenExpired()
            authState = isExpired ? .error("Token expired") : .connected
            print("🔐 [WHOOP] Token status: isExpired=\(isExpired), authState=\(authState)")
        } else {
            isAuthenticated = false
            authState = .disconnected
            print("🔐 [WHOOP] No stored tokens, authState=.disconnected")
        }
    }

    /// Generates a cryptographically secure random state parameter
    /// WHOOP requires exactly 8 characters
    private func generateSecureState() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomBytes = [UInt8](repeating: 0, count: Config.stateLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, Config.stateLength, &randomBytes)

        return String(randomBytes.map { byte in
            characters[characters.index(characters.startIndex, offsetBy: Int(byte) % characters.count)]
        })
    }

    /// Builds the WHOOP authorization URL with required parameters
    private func buildAuthorizationURL() -> URL? {
        var components = URLComponents(string: Config.authorizationUrl)

        components?.queryItems = [
            URLQueryItem(name: "client_id", value: Config.clientId),
            URLQueryItem(name: "redirect_uri", value: Config.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Config.scopes),
            URLQueryItem(name: "state", value: currentState)
        ]

        return components?.url
    }

    /// Performs the OAuth web authentication session
    private func performWebAuthentication(url: URL) async throws {
        print("🔐 [WHOOP] performWebAuthentication() - Creating ASWebAuthenticationSession")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.authContinuation = continuation

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "onlife"
            ) { [weak self] callbackURL, error in
                print("🔐 [WHOOP] ===== ASWebAuthenticationSession COMPLETION =====")
                print("🔐 [WHOOP] Callback URL: \(callbackURL?.absoluteString ?? "nil")")
                print("🔐 [WHOOP] Error: \(error?.localizedDescription ?? "none")")

                if let error = error {
                    let nsError = error as NSError
                    print("🔐 [WHOOP] Error domain: \(nsError.domain)")
                    print("🔐 [WHOOP] Error code: \(nsError.code)")
                }

                guard let self = self else {
                    print("🔐 [WHOOP] ERROR: self is nil in completion handler")
                    return
                }

                Task { @MainActor in
                    if let error = error {
                        let nsError = error as NSError
                        if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            print("🔐 [WHOOP] User cancelled login")
                            self.authContinuation?.resume(throwing: WHOOPAuthError.userCancelled)
                        } else {
                            print("🔐 [WHOOP] Authentication error: \(error.localizedDescription)")
                            self.authContinuation?.resume(throwing: WHOOPAuthError.networkError(error))
                        }
                        self.authContinuation = nil
                        return
                    }

                    guard let callbackURL = callbackURL else {
                        print("🔐 [WHOOP] ERROR: No callback URL received")
                        self.authContinuation?.resume(throwing: WHOOPAuthError.invalidResponse)
                        self.authContinuation = nil
                        return
                    }

                    print("🔐 [WHOOP] Processing callback URL...")
                    do {
                        try await self.handleCallback(url: callbackURL)
                        print("🔐 [WHOOP] Callback processed successfully, resuming continuation")
                        self.authContinuation?.resume()
                    } catch {
                        print("🔐 [WHOOP] ERROR processing callback: \(error)")
                        self.authContinuation?.resume(throwing: error)
                    }
                    self.authContinuation = nil
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            self.authSession = session
            print("🔐 [WHOOP] Starting ASWebAuthenticationSession...")

            if !session.start() {
                print("🔐 [WHOOP] ERROR: Failed to start ASWebAuthenticationSession")
                continuation.resume(throwing: WHOOPAuthError.urlConstructionFailed)
                self.authContinuation = nil
            } else {
                print("🔐 [WHOOP] ASWebAuthenticationSession started successfully")
            }
        }
    }

    /// Performs token exchange or refresh request
    private func performTokenRequest(
        grantType: String,
        code: String? = nil,
        refreshToken: String? = nil
    ) async throws -> WHOOPTokenResponse {
        print("🔐 [WHOOP] ========== performTokenRequest() BEGIN ==========")
        print("🔐 [WHOOP] Grant type: \(grantType)")

        guard let url = URL(string: Config.tokenUrl) else {
            print("🔐 [WHOOP] ERROR: Invalid token URL")
            throw WHOOPAuthError.urlConstructionFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Build request body
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: grantType),
            URLQueryItem(name: "client_id", value: Config.clientId),
            URLQueryItem(name: "client_secret", value: Config.clientSecret),
            URLQueryItem(name: "redirect_uri", value: Config.redirectUri)
        ]

        if let code = code {
            bodyComponents.queryItems?.append(URLQueryItem(name: "code", value: code))
            print("🔐 [WHOOP] Including authorization code: \(code.prefix(10))...")
        }

        if let refreshToken = refreshToken {
            bodyComponents.queryItems?.append(URLQueryItem(name: "refresh_token", value: refreshToken))
            print("🔐 [WHOOP] Including refresh token")
        }

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        print("🔐 [WHOOP] Sending token request to: \(url)")
        print("🔐 [WHOOP] Request body (sanitized): grant_type=\(grantType), client_id=\(Config.clientId), redirect_uri=\(Config.redirectUri)")

        // Perform request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("🔐 [WHOOP] ERROR: Network request failed - \(error)")
            throw WHOOPAuthError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔐 [WHOOP] ERROR: Invalid response type")
            throw WHOOPAuthError.invalidResponse
        }

        print("🔐 [WHOOP] Response status code: \(httpResponse.statusCode)")

        // Log response body (be careful with sensitive data in production)
        if let responseString = String(data: data, encoding: .utf8) {
            // Only log partial response to avoid exposing tokens
            let truncated = responseString.prefix(200)
            print("🔐 [WHOOP] Response body (truncated): \(truncated)...")
        }

        // Handle response status
        switch httpResponse.statusCode {
        case 200:
            do {
                let tokenResponse = try JSONDecoder().decode(WHOOPTokenResponse.self, from: data)
                print("🔐 [WHOOP] Token parsed successfully, expires in: \(tokenResponse.expiresIn) seconds")

                // Debug: Log received token details
                let receivedToken = tokenResponse.accessToken
                print("🔑 [WHOOP] Received token length: \(receivedToken.count)")
                print("🔑 [WHOOP] Received token: \(receivedToken.prefix(20))...\(receivedToken.suffix(10))")
                print("🔑 [WHOOP] Received token contains whitespace: \(receivedToken.contains { $0.isWhitespace })")
                print("🔑 [WHOOP] Received token contains newline: \(receivedToken.contains { $0.isNewline })")

                print("🔐 [WHOOP] ========== performTokenRequest() SUCCESS ==========")
                return tokenResponse
            } catch {
                print("🔐 [WHOOP] ERROR: Failed to decode token response - \(error)")
                throw WHOOPAuthError.invalidResponse
            }

        case 400:
            print("🔐 [WHOOP] ERROR: Bad request (400)")
            // Bad request - likely invalid code or refresh token
            if let errorResponse = try? JSONDecoder().decode(WHOOPOAuthErrorResponse.self, from: data) {
                print("🔐 [WHOOP] Error response: \(errorResponse.error) - \(errorResponse.errorDescription ?? "no description")")
                if errorResponse.error == "invalid_grant" {
                    throw grantType == "refresh_token"
                        ? WHOOPAuthError.refreshFailed
                        : WHOOPAuthError.invalidAuthorizationCode
                }
                throw WHOOPAuthError.serverError(statusCode: 400, message: errorResponse.errorDescription)
            }
            throw WHOOPAuthError.invalidAuthorizationCode

        case 401:
            print("🔐 [WHOOP] ERROR: Unauthorized (401)")
            throw WHOOPAuthError.notAuthenticated

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) }
            print("🔐 [WHOOP] ERROR: Rate limited (429), retry after: \(retryAfter ?? -1)")
            throw WHOOPAuthError.rateLimited(retryAfter: retryAfter)

        default:
            let message = String(data: data, encoding: .utf8)
            print("🔐 [WHOOP] ERROR: Unexpected status code \(httpResponse.statusCode)")
            print("🔐 [WHOOP] Response: \(message ?? "nil")")
            throw WHOOPAuthError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension WHOOPAuthService: ASWebAuthenticationPresentationContextProviding {

    /// Provides the window for presenting the authentication session
    /// Note: This method is called on the main thread by ASWebAuthenticationSession
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        print("🔐 [WHOOP] presentationAnchor called, isMainThread: \(Thread.isMainThread)")

        // ASWebAuthenticationSession always calls this on the main thread
        // Use MainActor.assumeIsolated to safely access main-actor-isolated properties
        return MainActor.assumeIsolated {
            print("🔐 [WHOOP] Getting window on main actor")

            // Try to get existing window from connected scenes
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first {
                print("🔐 [WHOOP] Got existing window: \(window)")
                return window
            }

            // Fallback: create window from first available scene
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let window = UIWindow(windowScene: windowScene)
                print("🔐 [WHOOP] Created window from scene: \(window)")
                return window
            }

            // Last resort: create window from any available scene
            print("🔐 [WHOOP] Using fallback window creation")
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first {
                return UIWindow(windowScene: windowScene)
            }

            // Absolute last resort - should never reach here in practice
            fatalError("No window scene available for WHOOP authentication")
        }
    }
}

// MARK: - URL Handling Extension

extension WHOOPAuthService {
    /// Check if a URL can be handled by this service
    /// Handles both URL formats:
    /// - onlife://auth/callback (host = "auth", path = "/callback")
    /// - onlife:///auth/callback (host = nil, path = "/auth/callback")
    static func canHandle(url: URL) -> Bool {
        guard url.scheme == "onlife" else { return false }

        // Handle both formats
        let isAuthCallback = (url.host == "auth") ||
                            url.path.hasPrefix("/auth") ||
                            url.path.contains("callback")

        print("🔐 [WHOOP] canHandle(\(url)) -> \(isAuthCallback)")
        return isAuthCallback
    }
}
