//
//  WHOOPAuthModels.swift
//  OnLife
//
//  WHOOP OAuth 2.0 authentication models
//

import Foundation

// MARK: - Token Response

/// Response from WHOOP OAuth token endpoint
/// Received after exchanging authorization code or refreshing tokens
/// Note: refresh_token may not be present in initial authorization response
struct WHOOPTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?  // Optional - WHOOP may not always include this
    let expiresIn: Int
    let tokenType: String?     // Optional - may not always be present
    let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

// MARK: - Auth Error

/// Errors that can occur during WHOOP OAuth flow
enum WHOOPAuthError: LocalizedError {
    case notAuthenticated
    case invalidState
    case authorizationDenied
    case userCancelled
    case networkError(Error)
    case invalidResponse
    case tokenExpired
    case refreshFailed
    case noRefreshToken  // No refresh token available - user must re-authenticate
    case invalidAuthorizationCode
    case rateLimited(retryAfter: Int?)
    case serverError(statusCode: Int, message: String?)
    case keychainError(OSStatus)
    case urlConstructionFailed
    case missingAuthorizationCode

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with WHOOP. Please connect your account."
        case .invalidState:
            return "Security validation failed. Please try again."
        case .authorizationDenied:
            return "Authorization was denied. Please grant access to continue."
        case .userCancelled:
            return "Authentication was cancelled."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received an invalid response from WHOOP."
        case .tokenExpired:
            return "Your session has expired. Please reconnect."
        case .refreshFailed:
            return "Failed to refresh authentication. Please reconnect your WHOOP account."
        case .noRefreshToken:
            return "Session expired and no refresh token available. Please reconnect your WHOOP account."
        case .invalidAuthorizationCode:
            return "Invalid authorization code. Please try again."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Too many requests. Please wait \(seconds) seconds."
            }
            return "Too many requests. Please try again later."
        case .serverError(let statusCode, let message):
            if let msg = message {
                return "Server error (\(statusCode)): \(msg)"
            }
            return "Server error (\(statusCode)). Please try again."
        case .keychainError(let status):
            return "Secure storage error (code: \(status)). Please try again."
        case .urlConstructionFailed:
            return "Failed to construct authentication URL."
        case .missingAuthorizationCode:
            return "No authorization code received from WHOOP."
        }
    }

    /// Determines if this error requires full re-authentication
    var requiresReauthentication: Bool {
        switch self {
        case .notAuthenticated, .tokenExpired, .refreshFailed, .invalidState, .noRefreshToken:
            return true
        default:
            return false
        }
    }
}

// MARK: - OAuth Error Response

/// Error response from WHOOP OAuth endpoints
struct WHOOPOAuthErrorResponse: Codable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - Auth State

/// Current authentication state with WHOOP
enum WHOOPAuthState: Equatable {
    case disconnected
    case authenticating
    case connected
    case refreshing
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isLoading: Bool {
        switch self {
        case .authenticating, .refreshing:
            return true
        default:
            return false
        }
    }
}

// MARK: - Stored Token Data

/// Internal model for storing token data with expiration tracking
struct WHOOPStoredTokenData: Codable {
    let accessToken: String
    let refreshToken: String?  // Optional - may not be provided by WHOOP
    let expiresAt: Date
    let scope: String

    /// Creates stored token data from a token response
    init(from response: WHOOPTokenResponse) {
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken  // May be nil
        self.expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        self.scope = response.scope
    }

    /// Creates stored token data with explicit values
    init(accessToken: String, refreshToken: String?, expiresAt: Date, scope: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.scope = scope
    }

    /// Updates the stored data with a new token response, preserving existing refresh token if new one is nil
    func updated(with response: WHOOPTokenResponse) -> WHOOPStoredTokenData {
        return WHOOPStoredTokenData(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? self.refreshToken,  // Keep existing if new is nil
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope
        )
    }

    /// Check if the access token is expired, with optional buffer time
    func isExpired(buffer: TimeInterval = 0) -> Bool {
        return Date().addingTimeInterval(buffer) >= expiresAt
    }

    /// Whether a refresh token is available
    var hasRefreshToken: Bool {
        return refreshToken != nil && !refreshToken!.isEmpty
    }
}
