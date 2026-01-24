//
//  BiometricSourceManager.swift
//  OnLife
//
//  Manages biometric data source selection and provides unified access to biometric data.
//  Prioritizes sources by accuracy: WHOOP BLE > WHOOP API > Apple Watch > Behavioral
//
//  Research basis:
//  - WHOOP: 99% HRV accuracy (Marco Altini analysis)
//  - Apple Watch: ~71% HRV accuracy (optical sensor limitations)
//

import Foundation
import Combine
import HealthKit
import SwiftUI

// MARK: - Biometric Source

enum BiometricSource: String, CaseIterable, Identifiable, Codable {
    case whoopBLE = "whoop_ble"
    case whoopAPI = "whoop_api"
    case appleWatch = "apple_watch"
    case behavioral = "behavioral"
    case none = "none"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whoopBLE: return "WHOOP (Real-time)"
        case .whoopAPI: return "WHOOP"
        case .appleWatch: return "Apple Watch"
        case .behavioral: return "Phone Only"
        case .none: return "None"
        }
    }

    var icon: String {
        switch self {
        case .whoopBLE: return "waveform.path.ecg"
        case .whoopAPI: return "heart.circle.fill"
        case .appleWatch: return "applewatch"
        case .behavioral: return "iphone"
        case .none: return "questionmark.circle"
        }
    }

    var accuracy: String {
        switch self {
        case .whoopBLE: return "99% HRV accuracy"
        case .whoopAPI: return "99% HRV accuracy"
        case .appleWatch: return "~71% HRV accuracy"
        case .behavioral: return "No biometrics"
        case .none: return "N/A"
        }
    }

    var priority: Int {
        switch self {
        case .whoopBLE: return 4
        case .whoopAPI: return 3
        case .appleWatch: return 2
        case .behavioral: return 1
        case .none: return 0
        }
    }

    var description: String {
        switch self {
        case .whoopBLE: return "Live heart rate and HRV from WHOOP strap via Bluetooth"
        case .whoopAPI: return "Recovery, sleep, and strain data from WHOOP cloud"
        case .appleWatch: return "Heart rate and HRV from Apple HealthKit"
        case .behavioral: return "Flow detection using phone usage patterns only"
        case .none: return "No data source active"
        }
    }
}

// MARK: - Source Change

struct BiometricSourceChange {
    let from: BiometricSource
    let to: BiometricSource
}

// MARK: - Biometric Sleep Data (Unified)

/// Unified sleep data structure for BiometricSourceManager
/// Named differently from SleepData in SleepQualityIndexCalculator to avoid collision
struct BiometricSleepData {
    let totalDuration: TimeInterval      // Total sleep time
    let quality: Double                  // 0-100
    let deepSleepDuration: TimeInterval?
    let remSleepDuration: TimeInterval?
    let lightSleepDuration: TimeInterval?
    let awakeTime: TimeInterval?
    let efficiency: Double?              // 0-100
    let timestamp: Date
}

// MARK: - Biometric Source Manager

/// Manages biometric data source selection and provides unified access to biometric data
@MainActor
class BiometricSourceManager: ObservableObject {
    static let shared = BiometricSourceManager()

    // MARK: - Published Properties

    @Published private(set) var activeSource: BiometricSource = .none
    @Published private(set) var availableSources: Set<BiometricSource> = []
    @Published var userPreferredSource: BiometricSource? = nil  // nil = auto
    @Published private(set) var isDetectingSource = false

    // Connection status for each source
    @Published private(set) var whoopBLEConnected = false
    @Published private(set) var whoopAPIAuthenticated = false
    @Published private(set) var appleWatchAvailable = false

    // MARK: - User Preferences (persisted)

    @AppStorage("biometricSourcePreference") private var storedPreference: String = "auto"
    @AppStorage("showSourceSwitchPrompt") var showSourceSwitchPrompt: Bool = true

    // MARK: - Dependencies

    private let whoopBLEManager: WHOOPBLEManager
    private let whoopAuthService: WHOOPAuthService
    private let whoopDataProvider: WHOOPDataProvider
    private let healthKitManager: HealthKitManager

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        self.whoopBLEManager = WHOOPBLEManager.shared
        self.whoopAuthService = WHOOPAuthService.shared
        self.whoopDataProvider = WHOOPDataProvider.shared
        self.healthKitManager = HealthKitManager.shared

        loadUserPreference()
        setupObservers()
        detectAvailableSources()

        print("💓 [BiometricSource] Manager initialized")
    }

    // MARK: - Source Detection

    func detectAvailableSources() {
        isDetectingSource = true
        availableSources.removeAll()

        Task {
            // Check WHOOP BLE
            if whoopBLEManager.state == .connected || whoopBLEManager.state == .receiving {
                availableSources.insert(.whoopBLE)
                whoopBLEConnected = true
                print("💓 [BiometricSource] WHOOP BLE available")
            } else {
                whoopBLEConnected = false
            }

            // Check WHOOP API
            if whoopAuthService.isAuthenticated {
                availableSources.insert(.whoopAPI)
                whoopAPIAuthenticated = true
                print("💓 [BiometricSource] WHOOP API available")
            } else {
                whoopAPIAuthenticated = false
            }

            // Check Apple Watch / HealthKit
            if await checkHealthKitAvailability() {
                availableSources.insert(.appleWatch)
                appleWatchAvailable = true
                print("💓 [BiometricSource] Apple Watch available")
            } else {
                appleWatchAvailable = false
            }

            // Always have behavioral as fallback
            availableSources.insert(.behavioral)

            // Select best source
            selectBestSource()

            isDetectingSource = false
        }
    }

    private func checkHealthKitAvailability() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        // Check if HealthKit is authorized
        return healthKitManager.isAuthorized
    }

    // MARK: - Source Selection

    func selectBestSource() {
        let previousSource = activeSource

        // If user has a manual preference and it's available, use it
        if let preferred = userPreferredSource, availableSources.contains(preferred) {
            activeSource = preferred
            print("💓 [BiometricSource] Using user preferred: \(preferred.displayName)")
            notifySourceChangeIfNeeded(from: previousSource, to: activeSource)
            return
        }

        // Auto-select best available (priority order)
        if availableSources.contains(.whoopBLE) {
            activeSource = .whoopBLE
        } else if availableSources.contains(.whoopAPI) {
            activeSource = .whoopAPI
        } else if availableSources.contains(.appleWatch) {
            activeSource = .appleWatch
        } else {
            activeSource = .behavioral
        }

        print("💓 [BiometricSource] Auto-selected: \(activeSource.displayName)")
        notifySourceChangeIfNeeded(from: previousSource, to: activeSource)
    }

    // MARK: - User Preference

    func setPreferredSource(_ source: BiometricSource?) {
        userPreferredSource = source
        storedPreference = source?.rawValue ?? "auto"
        selectBestSource()
        HapticManager.shared.impact(style: .light)
        print("💓 [BiometricSource] User preference set to: \(source?.displayName ?? "Auto")")
    }

    private func loadUserPreference() {
        if storedPreference == "auto" {
            userPreferredSource = nil
        } else if let source = BiometricSource(rawValue: storedPreference) {
            userPreferredSource = source
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        // Observe WHOOP BLE state changes
        whoopBLEManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                let wasConnected = self?.whoopBLEConnected ?? false
                let isNowConnected = state == .connected || state == .receiving

                if wasConnected != isNowConnected {
                    self?.whoopBLEConnected = isNowConnected
                    self?.detectAvailableSources()

                    // Post notification for other parts of app
                    NotificationCenter.default.post(
                        name: .WHOOPBLEConnectionChanged,
                        object: isNowConnected
                    )
                }
            }
            .store(in: &cancellables)

        // Observe WHOOP API auth changes
        whoopAuthService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                let wasAuthenticated = self?.whoopAPIAuthenticated ?? false

                if wasAuthenticated != isAuthenticated {
                    self?.whoopAPIAuthenticated = isAuthenticated
                    self?.detectAvailableSources()

                    // Post notification for other parts of app
                    NotificationCenter.default.post(
                        name: .WHOOPAuthStateChanged,
                        object: isAuthenticated
                    )
                }
            }
            .store(in: &cancellables)

        // Observe HealthKit authorization
        healthKitManager.$isAuthorized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthorized in
                let wasAvailable = self?.appleWatchAvailable ?? false

                if wasAvailable != isAuthorized {
                    self?.appleWatchAvailable = isAuthorized
                    self?.detectAvailableSources()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Source Change Notification

    private func notifySourceChangeIfNeeded(from oldSource: BiometricSource, to newSource: BiometricSource) {
        guard oldSource != newSource, oldSource != .none else { return }
        guard showSourceSwitchPrompt else { return }

        // Only notify if upgrading to a better source
        if newSource.priority > oldSource.priority {
            NotificationCenter.default.post(
                name: .BiometricSourceUpgradeAvailable,
                object: BiometricSourceChange(from: oldSource, to: newSource)
            )
            print("💓 [BiometricSource] Upgrade available: \(oldSource.displayName) → \(newSource.displayName)")
        }
    }

    // MARK: - Data Access (Unified Interface)

    /// Get current HRV from the active source
    func getCurrentHRV() async -> Double? {
        print("💓 [BiometricSource] Getting HRV from: \(activeSource.displayName)")

        switch activeSource {
        case .whoopBLE:
            return whoopDataProvider.currentRMSSD
        case .whoopAPI:
            return whoopDataProvider.baselineRMSSD
        case .appleWatch:
            return healthKitManager.latestRMSSD
        case .behavioral, .none:
            return nil
        }
    }

    /// Get current heart rate from the active source
    func getCurrentHeartRate() async -> Double? {
        print("💓 [BiometricSource] Getting HR from: \(activeSource.displayName)")

        switch activeSource {
        case .whoopBLE:
            return Double(whoopBLEManager.currentHeartRate)
        case .whoopAPI:
            return Double(whoopDataProvider.currentHeartRate)
        case .appleWatch:
            return healthKitManager.latestHeartRate
        case .behavioral, .none:
            return nil
        }
    }

    /// Get sleep data from the active source
    func getSleepData() async -> BiometricSleepData? {
        print("💓 [BiometricSource] Getting sleep from: \(activeSource.displayName)")

        switch activeSource {
        case .whoopBLE, .whoopAPI:
            // WHOOP API has the best sleep data
            return await fetchWHOOPSleepData()
        case .appleWatch:
            return await fetchHealthKitSleepData()
        case .behavioral, .none:
            return nil
        }
    }

    /// Get recovery/readiness score
    func getRecoveryScore() async -> Double? {
        print("💓 [BiometricSource] Getting recovery from: \(activeSource.displayName)")

        switch activeSource {
        case .whoopBLE, .whoopAPI:
            return whoopDataProvider.recoveryScore
        case .appleWatch:
            // Apple Watch doesn't have a direct recovery score
            // Calculate from HRV and sleep
            return await calculateAppleWatchRecovery()
        case .behavioral, .none:
            return nil
        }
    }

    // MARK: - Private Fetch Methods

    private func fetchWHOOPSleepData() async -> BiometricSleepData? {
        guard let sleepPerformance = whoopDataProvider.sleepPerformance else { return nil }

        // Convert WHOOP sleep data to our unified format
        return BiometricSleepData(
            totalDuration: 8 * 3600, // WHOOP doesn't expose raw duration easily
            quality: sleepPerformance,
            deepSleepDuration: nil,
            remSleepDuration: nil,
            lightSleepDuration: nil,
            awakeTime: nil,
            efficiency: sleepPerformance,
            timestamp: Date()
        )
    }

    private func fetchHealthKitSleepData() async -> BiometricSleepData? {
        guard let sleep = healthKitManager.lastNightSleep else { return nil }

        // Convert SleepAnalysisResult to BiometricSleepData
        // SleepAnalysisResult has: totalHours, deepSleepPercent, remSleepPercent, score
        let totalDuration = sleep.totalHours * 3600 // Convert hours to seconds
        let deepSleepDuration = totalDuration * (sleep.deepSleepPercent / 100.0)
        let remSleepDuration = totalDuration * (sleep.remSleepPercent / 100.0)
        let lightSleepDuration = totalDuration - deepSleepDuration - remSleepDuration

        return BiometricSleepData(
            totalDuration: totalDuration,
            quality: sleep.score,
            deepSleepDuration: deepSleepDuration,
            remSleepDuration: remSleepDuration,
            lightSleepDuration: lightSleepDuration,
            awakeTime: nil,
            efficiency: nil,
            timestamp: Date()
        )
    }

    private func calculateSleepQuality(from sleep: SleepAnalysisResult) -> Double {
        // SleepAnalysisResult already has a score, use it directly
        // Or calculate from duration: totalHours (aim for 8 hours)
        let durationScore = min(sleep.totalHours / 8.0, 1.0) * 50
        let qualityScore = sleep.score * 0.5 // score is 0-100, so take half
        return durationScore + qualityScore
    }

    private func calculateAppleWatchRecovery() async -> Double? {
        // Estimate recovery from HRV and sleep
        guard let hrv = healthKitManager.latestRMSSD else { return nil }

        // Simple recovery estimation
        // HRV contributes 60%, sleep contributes 40%
        let hrvScore = min(hrv / 100.0, 1.0) * 60

        var sleepScore: Double = 20 // Default if no sleep data
        if let sleep = healthKitManager.lastNightSleep {
            sleepScore = calculateSleepQuality(from: sleep) * 0.4
        }

        return hrvScore + sleepScore
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let WHOOPBLEConnectionChanged = Notification.Name("WHOOPBLEConnectionChanged")
    static let WHOOPAuthStateChanged = Notification.Name("WHOOPAuthStateChanged")
    static let BiometricSourceUpgradeAvailable = Notification.Name("BiometricSourceUpgradeAvailable")
}
