//
//  WHOOPTokenManager.swift
//  OnLife
//
//  Secure token storage for WHOOP OAuth using iOS Keychain
//

import Foundation
import Security

/// Manages secure storage and retrieval of WHOOP OAuth tokens using the iOS Keychain
final class WHOOPTokenManager {

    // MARK: - Singleton

    static let shared = WHOOPTokenManager()

    // MARK: - Constants

    private enum KeychainKey {
        static let service = "com.onlife.whoop"
        static let tokenData = "whoop_token_data"
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Saves token response to Keychain
    /// If a refresh token already exists and the new response doesn't have one,
    /// the existing refresh token is preserved
    /// - Parameter response: The token response from WHOOP OAuth
    /// - Throws: WHOOPAuthError.keychainError if save fails
    func saveTokens(from response: WHOOPTokenResponse) throws {
        print("🔐 [WHOOPTokenManager] saveTokens called")
        print("🔐 [WHOOPTokenManager] Response has refresh token: \(response.refreshToken != nil)")

        // Debug: Log token details
        let token = response.accessToken
        print("🔑 [WHOOPTokenManager] Saving token: \(token.prefix(20))...\(token.suffix(10))")
        print("🔑 [WHOOPTokenManager] Token length: \(token.count)")
        print("🔑 [WHOOPTokenManager] Token contains whitespace: \(token.contains { $0.isWhitespace })")
        print("🔑 [WHOOPTokenManager] Token contains newline: \(token.contains { $0.isNewline })")

        // Check if we have existing tokens with a refresh token to preserve
        if let existingData = getTokenData(), existingData.hasRefreshToken, response.refreshToken == nil {
            print("🔐 [WHOOPTokenManager] Preserving existing refresh token")
            let updatedData = existingData.updated(with: response)
            try saveTokenData(updatedData)
        } else {
            let storedData = WHOOPStoredTokenData(from: response)
            try saveTokenData(storedData)
        }
        print("🔐 [WHOOPTokenManager] Tokens saved successfully")
    }

    /// Saves tokens with explicit values
    /// - Parameters:
    ///   - accessToken: The access token
    ///   - refreshToken: The refresh token (optional)
    ///   - expiresIn: Seconds until expiration
    ///   - scope: The granted scopes
    /// - Throws: WHOOPAuthError.keychainError if save fails
    func saveTokens(
        accessToken: String,
        refreshToken: String?,
        expiresIn: Int,
        scope: String = ""
    ) throws {
        let response = WHOOPTokenResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            tokenType: "Bearer",
            scope: scope
        )
        try saveTokens(from: response)
    }

    /// Updates tokens from a new response, preserving existing refresh token if new one is nil
    /// - Parameter response: The new token response
    /// - Throws: WHOOPAuthError.keychainError if save fails
    func updateTokens(from response: WHOOPTokenResponse) throws {
        // If we have existing token data and the new response has no refresh token,
        // preserve the existing refresh token
        if let existingData = getTokenData() {
            let updatedData = existingData.updated(with: response)
            try saveTokenData(updatedData)
            print("🔐 [WHOOPTokenManager] Updated tokens, preserved refresh token: \(updatedData.hasRefreshToken)")
        } else {
            // No existing data, just save the new response
            let storedData = WHOOPStoredTokenData(from: response)
            try saveTokenData(storedData)
            print("🔐 [WHOOPTokenManager] Saved new tokens, has refresh token: \(storedData.hasRefreshToken)")
        }
    }

    /// Retrieves the current access token if available
    /// - Returns: The access token or nil if not stored
    func getAccessToken() -> String? {
        guard let tokenData = getTokenData() else {
            print("🔑 [WHOOPTokenManager] getAccessToken: No token data found")
            return nil
        }
        let token = tokenData.accessToken
        print("🔑 [WHOOPTokenManager] Retrieved token: \(token.prefix(20))...\(token.suffix(10))")
        print("🔑 [WHOOPTokenManager] Retrieved token length: \(token.count)")
        print("🔑 [WHOOPTokenManager] Retrieved token contains whitespace: \(token.contains { $0.isWhitespace })")
        print("🔑 [WHOOPTokenManager] Retrieved token contains newline: \(token.contains { $0.isNewline })")
        return token
    }

    /// Retrieves the current refresh token if available
    /// - Returns: The refresh token or nil if not stored
    func getRefreshToken() -> String? {
        guard let tokenData = getTokenData() else { return nil }
        return tokenData.refreshToken
    }

    /// Retrieves the complete stored token data
    /// - Returns: The stored token data or nil if not stored
    func getTokenData() -> WHOOPStoredTokenData? {
        guard let data = readFromKeychain(key: KeychainKey.tokenData) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(WHOOPStoredTokenData.self, from: data)
        } catch {
            // Corrupted data, clear it
            try? clearTokens()
            return nil
        }
    }

    /// Checks if the current access token is expired
    /// - Parameter buffer: Buffer time in seconds before actual expiration (default 5 minutes)
    /// - Returns: true if token is expired or will expire within buffer time
    func isTokenExpired(buffer: TimeInterval = 300) -> Bool {
        guard let tokenData = getTokenData() else {
            return true
        }
        return tokenData.isExpired(buffer: buffer)
    }

    /// Checks if tokens are stored (user has authenticated)
    var hasStoredTokens: Bool {
        return getTokenData() != nil
    }

    /// Returns the expiration date of the current access token
    var tokenExpirationDate: Date? {
        return getTokenData()?.expiresAt
    }

    /// Returns the granted scopes
    var grantedScopes: String? {
        return getTokenData()?.scope
    }

    /// Clears all stored tokens from Keychain
    /// - Throws: WHOOPAuthError.keychainError if deletion fails (except item not found)
    func clearTokens() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKey.service,
            kSecAttrAccount as String: KeychainKey.tokenData
        ]

        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound (-25300) is acceptable - means already cleared
        if status != errSecSuccess && status != errSecItemNotFound {
            throw WHOOPAuthError.keychainError(status)
        }
    }

    // MARK: - Private Methods

    /// Saves token data to Keychain
    private func saveTokenData(_ tokenData: WHOOPStoredTokenData) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(tokenData)
        } catch {
            throw WHOOPAuthError.invalidResponse
        }

        // Delete existing item first
        try? clearTokens()

        // Create new item with secure attributes
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKey.service,
            kSecAttrAccount as String: KeychainKey.tokenData,
            kSecValueData as String: data,
            // Accessible only when device is unlocked
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            throw WHOOPAuthError.keychainError(status)
        }
    }

    /// Reads data from Keychain for the given key
    private func readFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKey.service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return data
        }

        return nil
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension WHOOPTokenManager {
    /// Debug method to check token status (never logs actual tokens)
    func debugTokenStatus() -> String {
        guard let tokenData = getTokenData() else {
            return "No tokens stored"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium

        let expiredStatus = tokenData.isExpired() ? "EXPIRED" : "Valid"
        let expiresIn = tokenData.expiresAt.timeIntervalSince(Date())
        let refreshStatus = tokenData.hasRefreshToken ? "Available" : "Not available"

        return """
        Token Status: \(expiredStatus)
        Expires: \(formatter.string(from: tokenData.expiresAt))
        Expires in: \(Int(expiresIn)) seconds
        Refresh Token: \(refreshStatus)
        Scopes: \(tokenData.scope)
        """
    }
}
#endif
