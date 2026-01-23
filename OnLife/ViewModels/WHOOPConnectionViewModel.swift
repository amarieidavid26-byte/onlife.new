//
//  WHOOPConnectionViewModel.swift
//  OnLife
//
//  ViewModel for managing WHOOP connection state in the UI
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for managing WHOOP connection state in the UI
@MainActor
class WHOOPConnectionViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // Test API state
    @Published var isTesting: Bool = false
    @Published var testResult: String?
    @Published var showTestResult: Bool = false

    // MARK: - Private Properties

    private let authService = WHOOPAuthService.shared
    private let apiClient = WHOOPAPIClient.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Check initial authentication state
        isConnected = authService.isAuthenticated

        // Observe auth state changes
        setupAuthStateObserver()
    }

    // MARK: - Public Methods

    /// Start WHOOP OAuth authentication flow
    func connectWHOOP() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authService.startAuthentication()
            isConnected = authService.isAuthenticated
        } catch let error as WHOOPAuthError {
            switch error {
            case .userCancelled:
                // User cancelled - no error message needed
                break
            default:
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            errorMessage = "Failed to connect: \(error.localizedDescription)"
            showError = true
        }

        isLoading = false
    }

    /// Disconnect WHOOP account
    func disconnectWHOOP() {
        authService.logout()
        isConnected = false
    }

    /// Dismiss error alert
    func dismissError() {
        showError = false
        errorMessage = nil
    }

    /// Test WHOOP API by fetching dashboard data
    func testWHOOPConnection() async {
        guard isConnected else { return }

        isTesting = true
        testResult = nil

        // fetchDashboardData never throws - handles 404s gracefully
        let dashboard = await apiClient.fetchDashboardData()
        print("✅ [WHOOP] Dashboard data fetched!")

        var resultParts: [String] = []

        // Cycle/Strain data
        if let cycle = dashboard.cycle?.score {
            resultParts.append("Strain: \(String(format: "%.1f", cycle.strain))")
            resultParts.append("Avg HR: \(cycle.averageHeartRate) bpm")
        }

        // Recovery data
        if let recovery = dashboard.recovery?.score {
            resultParts.append("Recovery: \(Int(recovery.recoveryScore))%")
            resultParts.append("HRV: \(String(format: "%.1f", recovery.hrvRmssdMilli)) ms")
            resultParts.append("RHR: \(Int(recovery.restingHeartRate)) bpm")
        }

        // Sleep data
        if let sleep = dashboard.sleep?.score {
            if let perf = sleep.sleepPerformancePercentage {
                resultParts.append("Sleep: \(Int(perf))%")
            }
        }

        // Build result message
        if resultParts.isEmpty {
            testResult = "WHOOP Connected!\n\n\(dashboard.statusMessage)"
        } else {
            testResult = "WHOOP Data:\n\n" + resultParts.joined(separator: "\n")
        }

        showTestResult = true
        isTesting = false
    }

    /// Dismiss test result alert
    func dismissTestResult() {
        showTestResult = false
        testResult = nil
    }

    // MARK: - Private Methods

    private func setupAuthStateObserver() {
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isConnected = isAuthenticated
            }
            .store(in: &cancellables)
    }
}
