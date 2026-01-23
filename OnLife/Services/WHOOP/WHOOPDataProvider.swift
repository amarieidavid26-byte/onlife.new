//
//  WHOOPDataProvider.swift
//  OnLife
//
//  Unified data provider bridging WHOOP BLE real-time data with API historical data.
//  Connects to BiometricFlowScoreCalculator for flow detection during focus sessions.
//
//  References:
//  - Peifer C, et al. (2014): Flow at 70-95% of baseline RMSSD (inverted-U)
//  - Shaffer F, Ginsberg JP (2017): RMSSD calculation standards
//

import Foundation
import Combine

/// Unified WHOOP data provider for flow detection
/// Combines real-time BLE heart rate/HRV with API-derived baselines
@MainActor
final class WHOOPDataProvider: ObservableObject, @unchecked Sendable {

    // MARK: - Singleton

    static let shared = WHOOPDataProvider()

    // MARK: - Published Properties (Real-time from BLE)

    @Published private(set) var currentHeartRate: Int = 0
    @Published private(set) var currentRMSSD: Double?
    @Published private(set) var flowIndicator: FlowIndicator = .unknown
    @Published private(set) var isSessionActive: Bool = false
    @Published private(set) var sessionDuration: TimeInterval = 0

    // MARK: - Published Properties (Historical from API)

    @Published private(set) var baselineRMSSD: Double?      // 7-14 day average from WHOOP recovery
    @Published private(set) var baselineRHR: Double?        // Resting heart rate baseline
    @Published private(set) var recoveryScore: Double?      // Today's recovery percentage
    @Published private(set) var sleepPerformance: Double?   // Last night's sleep performance
    @Published private(set) var isBaselineReady: Bool = false

    // MARK: - Published Properties (Flow Score)

    @Published private(set) var currentFlowResult: BiometricFlowResult?
    @Published private(set) var flowScoreHistory: [BiometricFlowResult] = []

    // MARK: - Dependencies

    private let bleManager = WHOOPBLEManager.shared
    private let apiClient = WHOOPAPIClient.shared
    private let flowCalculator = BiometricFlowScoreCalculator.shared
    private let hrvEngine = HRVProcessingEngine.shared

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var flowUpdateTimer: Timer?
    private var sessionStartTime: Date?

    // Storage keys
    private let baselineStorageKey = "whoop_baseline_data"

    // MARK: - Flow Indicator

    enum FlowIndicator: String {
        case unknown = "Unknown"
        case calibrating = "Calibrating..."
        case buildingFocus = "Building focus..."
        case inFlowZone = "In Flow Zone!"
        case deepFlow = "Deep Flow"
        case highStress = "High stress"
        case lowEngagement = "Low engagement"
        case noData = "No HRV data"

        var color: String {
            switch self {
            case .unknown, .noData: return "gray"
            case .calibrating, .buildingFocus: return "yellow"
            case .inFlowZone, .deepFlow: return "green"
            case .highStress: return "red"
            case .lowEngagement: return "orange"
            }
        }

        var isInFlow: Bool {
            self == .inFlowZone || self == .deepFlow
        }
    }

    // MARK: - Initialization

    private init() {
        print("📊 [WHOOPDataProvider] Initialized")
        loadCachedBaseline()
        setupBLESubscriptions()
    }

    // MARK: - BLE Subscriptions

    private func setupBLESubscriptions() {
        // Subscribe to heart rate updates
        bleManager.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                self?.currentHeartRate = hr
            }
            .store(in: &cancellables)

        // Subscribe to HRV updates
        bleManager.$latestHRV
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hrv in
                self?.currentRMSSD = hrv?.rmssd
                if self?.isSessionActive == true {
                    self?.updateFlowIndicator(hrv: hrv)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Session Management

    /// Start a focus session with BLE heart rate monitoring
    func startSession() {
        guard !isSessionActive else {
            print("📊 [WHOOPDataProvider] Session already active")
            return
        }

        print("📊 [WHOOPDataProvider] Starting focus session")

        isSessionActive = true
        sessionStartTime = Date()
        sessionDuration = 0
        flowScoreHistory.removeAll()
        flowCalculator.resetHistory()

        // Start BLE scanning if not connected
        if bleManager.state == .disconnected || bleManager.state == .error {
            bleManager.startScanning()
        }

        // Start session duration timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let startTime = self.sessionStartTime else { return }
                self.sessionDuration = Date().timeIntervalSince(startTime)
            }
        }

        // Start flow score update timer (every 30 seconds)
        flowUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.calculateFlowScore()
            }
        }

        // Initial flow calculation after 30 seconds warmup
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self else { return }
            self.calculateFlowScore()
        }
    }

    /// End the current focus session
    func endSession() -> FocusSessionBiometrics? {
        guard isSessionActive else {
            print("📊 [WHOOPDataProvider] No active session to end")
            return nil
        }

        print("📊 [WHOOPDataProvider] Ending focus session")

        isSessionActive = false
        sessionTimer?.invalidate()
        sessionTimer = nil
        flowUpdateTimer?.invalidate()
        flowUpdateTimer = nil

        // Optionally disconnect BLE to save battery
        // bleManager.disconnect()

        // Calculate session summary
        let summary = calculateSessionSummary()
        sessionStartTime = nil
        flowIndicator = .unknown

        return summary
    }

    // MARK: - Baseline Management

    /// Fetch baseline RMSSD from WHOOP API recovery data (7-14 day average)
    func updateBaseline() async {
        print("📊 [WHOOPDataProvider] Fetching baseline from WHOOP API...")

        do {
            // Fetch recovery data (contains baseline RMSSD from last 7-14 days)
            let recoveryResponse = try await apiClient.fetchRecovery(limit: 14)
            let recoveries = recoveryResponse.records

            guard !recoveries.isEmpty else {
                print("📊 [WHOOPDataProvider] No recovery data available")
                return
            }

            // Calculate 7-14 day average RMSSD
            let validScores = recoveries.compactMap { $0.score }
            guard !validScores.isEmpty else {
                print("📊 [WHOOPDataProvider] No valid recovery scores")
                return
            }

            // Extract RMSSD values (in milliseconds)
            let rmssdValues = validScores.map { $0.hrvRmssdMilli }
            let avgRMSSD = rmssdValues.reduce(0, +) / Double(rmssdValues.count)

            // Extract RHR values
            let rhrValues = validScores.map { $0.restingHeartRate }
            let avgRHR = rhrValues.reduce(0, +) / Double(rhrValues.count)

            // Get latest recovery score
            let latestRecovery = validScores.first?.recoveryScore

            baselineRMSSD = avgRMSSD
            baselineRHR = avgRHR
            recoveryScore = latestRecovery
            isBaselineReady = true

            // Update flow calculator baseline
            updateFlowCalculatorBaseline(rmssd: avgRMSSD, rhr: avgRHR)

            // Cache for offline use
            cacheBaseline()

            print("📊 [WHOOPDataProvider] Baseline updated:")
            print("   - RMSSD: \(String(format: "%.1f", avgRMSSD))ms (from \(rmssdValues.count) days)")
            print("   - RHR: \(String(format: "%.1f", avgRHR)) bpm")
            print("   - Recovery: \(latestRecovery.map { String(format: "%.0f%%", $0) } ?? "N/A")")

        } catch {
            print("📊 [WHOOPDataProvider] Failed to fetch baseline: \(error)")
            // Continue with cached baseline if available
        }

        // Fetch sleep data for sleep performance
        await updateSleepData()
    }

    /// Fetch latest sleep performance
    private func updateSleepData() async {
        do {
            if let sleep = try await apiClient.getLastSleep() {
                sleepPerformance = sleep.score?.sleepPerformancePercentage
                print("📊 [WHOOPDataProvider] Sleep performance: \(sleepPerformance.map { String(format: "%.0f%%", $0) } ?? "N/A")")
            }
        } catch {
            print("📊 [WHOOPDataProvider] Failed to fetch sleep data: \(error)")
        }
    }

    // MARK: - Flow Calculation

    /// Calculate current flow score from BLE data
    private func calculateFlowScore() {
        guard isSessionActive else { return }

        // Convert BLE data to HRVMetrics
        guard let hrvMetrics = buildHRVMetrics() else {
            print("📊 [WHOOPDataProvider] Insufficient HRV data for flow calculation")
            flowIndicator = .noData
            return
        }

        // Get sleep quality (normalized 0-1)
        let sleepQuality = (sleepPerformance ?? 70.0) / 100.0

        // Calculate flow score using existing calculator
        let result = flowCalculator.calculateFlowScore(
            hrvMetrics: hrvMetrics,
            currentHR: Double(currentHeartRate),
            sleepQuality: sleepQuality
        )

        currentFlowResult = result
        flowScoreHistory.append(result)

        // Update flow indicator based on result
        updateFlowIndicatorFromResult(result)

        print("📊 [WHOOPDataProvider] Flow: \(result.summary)")
    }

    /// Build HRVMetrics from current BLE data
    private func buildHRVMetrics() -> HRVMetrics? {
        // Get RR intervals from BLE manager
        let rrIntervals = bleManager.rrIntervals

        guard rrIntervals.count >= 30 else {
            // Need at least 30 RR intervals (~30 seconds of data)
            return nil
        }

        // Use HRV Processing Engine to calculate full metrics
        let windowDuration = bleManager.latestHRV?.windowDuration ?? 60.0
        let metrics = hrvEngine.calculateMetrics(from: rrIntervals, windowDuration: windowDuration)

        return metrics
    }

    /// Update flow indicator from BLE HRV data (quick check)
    private func updateFlowIndicator(hrv: RealTimeHRV?) {
        guard let hrv = hrv, hrv.isValid else {
            flowIndicator = .noData
            return
        }

        guard let baseline = baselineRMSSD, baseline > 0 else {
            flowIndicator = .calibrating
            return
        }

        // Flow detection based on Peifer et al. 2014
        // Flow zone: RMSSD between 70-95% of baseline
        let ratio = hrv.rmssd / baseline

        switch ratio {
        case ..<0.50:
            flowIndicator = .highStress
        case 0.50..<0.70:
            flowIndicator = .buildingFocus
        case 0.70..<0.95:
            flowIndicator = .inFlowZone
        case 0.95..<1.10:
            flowIndicator = .buildingFocus
        default:
            flowIndicator = .lowEngagement
        }
    }

    /// Update flow indicator from BiometricFlowResult
    private func updateFlowIndicatorFromResult(_ result: BiometricFlowResult) {
        switch result.state {
        case .deepFlow:
            flowIndicator = .deepFlow
        case .lightFlow:
            flowIndicator = .inFlowZone
        case .preFlow:
            flowIndicator = .buildingFocus
        case .baseline:
            flowIndicator = .calibrating
        case .overload:
            flowIndicator = .highStress
        case .boredom:
            flowIndicator = .lowEngagement
        }
    }

    // MARK: - Flow Calculator Baseline Update

    /// Update the BiometricFlowScoreCalculator baseline with WHOOP data
    private func updateFlowCalculatorBaseline(rmssd: Double, rhr: Double) {
        // Update existing baseline with WHOOP data
        // Weight WHOOP data at 60% since it's research-grade
        let whoopWeight = 0.6
        let existingWeight = 0.4

        let existingRMSSD = flowCalculator.baseline.restingRMSSD
        let existingRHR = flowCalculator.baseline.restingHR

        flowCalculator.baseline.restingRMSSD = (rmssd * whoopWeight) + (existingRMSSD * existingWeight)
        flowCalculator.baseline.restingHR = (rhr * whoopWeight) + (existingRHR * existingWeight)
        flowCalculator.baseline.isCalibrated = true
        flowCalculator.baseline.lastUpdated = Date()

        print("📊 [WHOOPDataProvider] Flow calculator baseline updated:")
        print("   - RMSSD: \(String(format: "%.1f", flowCalculator.baseline.restingRMSSD))ms")
        print("   - RHR: \(String(format: "%.1f", flowCalculator.baseline.restingHR)) bpm")
    }

    // MARK: - Session Summary

    /// Calculate session summary biometrics
    private func calculateSessionSummary() -> FocusSessionBiometrics {
        let duration = sessionDuration

        // Calculate averages from flow history
        let avgFlowScore = flowScoreHistory.isEmpty ? 0.0 :
            flowScoreHistory.map { $0.score }.reduce(0, +) / Double(flowScoreHistory.count)

        let peakFlowScore = flowScoreHistory.map { $0.score }.max() ?? 0

        // Calculate time in flow
        let flowStates: [BiometricFlowResult.FlowState] = [.deepFlow, .lightFlow]
        let flowReadings = flowScoreHistory.filter { flowStates.contains($0.state) }.count
        let timeInFlow = Double(flowReadings) * 30.0 // 30 seconds per reading

        // Calculate average heart rate from flow readings
        let avgHR = flowScoreHistory.isEmpty ? Double(currentHeartRate) :
            flowScoreHistory.compactMap { $0.breakdown.hrZoneScore * (baselineRHR ?? 70) * 1.2 }
                .reduce(0, +) / Double(max(1, flowScoreHistory.count))

        return FocusSessionBiometrics(
            sessionDuration: duration,
            averageFlowScore: avgFlowScore,
            peakFlowScore: peakFlowScore,
            timeInFlowSeconds: Int(timeInFlow),
            averageHeartRate: avgHR,
            averageRMSSD: currentRMSSD ?? 0,
            flowScoreHistory: flowScoreHistory.map { $0.score },
            peakFlowState: flowScoreHistory.max(by: { $0.score < $1.score })?.state ?? .baseline
        )
    }

    // MARK: - Caching

    private func cacheBaseline() {
        let data = CachedBaseline(
            rmssd: baselineRMSSD,
            rhr: baselineRHR,
            recoveryScore: recoveryScore,
            sleepPerformance: sleepPerformance,
            timestamp: Date()
        )

        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: baselineStorageKey)
        }
    }

    private func loadCachedBaseline() {
        guard let data = UserDefaults.standard.data(forKey: baselineStorageKey),
              let cached = try? JSONDecoder().decode(CachedBaseline.self, from: data) else {
            return
        }

        // Only use cache if less than 24 hours old
        let age = Date().timeIntervalSince(cached.timestamp)
        guard age < 24 * 3600 else {
            print("📊 [WHOOPDataProvider] Cached baseline expired (\(Int(age/3600))h old)")
            return
        }

        baselineRMSSD = cached.rmssd
        baselineRHR = cached.rhr
        recoveryScore = cached.recoveryScore
        sleepPerformance = cached.sleepPerformance
        isBaselineReady = cached.rmssd != nil

        if isBaselineReady {
            print("📊 [WHOOPDataProvider] Loaded cached baseline:")
            print("   - RMSSD: \(baselineRMSSD.map { String(format: "%.1f", $0) } ?? "N/A")ms")
            print("   - RHR: \(baselineRHR.map { String(format: "%.1f", $0) } ?? "N/A") bpm")

            // Update flow calculator
            if let rmssd = cached.rmssd, let rhr = cached.rhr {
                updateFlowCalculatorBaseline(rmssd: rmssd, rhr: rhr)
            }
        }
    }

    // MARK: - Convenience Accessors

    /// Get flow zone status based on current RMSSD
    var flowZoneStatus: (inZone: Bool, message: String) {
        guard let current = currentRMSSD, let baseline = baselineRMSSD else {
            return (false, "Waiting for HRV data...")
        }

        let ratio = current / baseline
        switch ratio {
        case 0.70..<0.95:
            return (true, "In flow zone (\(Int(ratio * 100))% of baseline)")
        case ..<0.70:
            return (false, "Below flow zone - possible stress")
        default:
            return (false, "Above flow zone - building focus")
        }
    }

    /// Whether BLE connection is active and receiving data
    var isBLEActive: Bool {
        bleManager.state == .connected || bleManager.state == .receiving
    }

    /// Connection state description
    var connectionStatus: String {
        switch bleManager.state {
        case .disconnected: return "Not connected"
        case .scanning: return "Scanning for WHOOP..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .receiving: return "Receiving data"
        case .error: return "Connection error"
        }
    }
}

// MARK: - Supporting Types

/// Cached baseline data for offline use
private struct CachedBaseline: Codable {
    let rmssd: Double?
    let rhr: Double?
    let recoveryScore: Double?
    let sleepPerformance: Double?
    let timestamp: Date
}

/// Biometrics summary for a focus session
struct FocusSessionBiometrics: Codable {
    let sessionDuration: TimeInterval
    let averageFlowScore: Double
    let peakFlowScore: Double
    let timeInFlowSeconds: Int
    let averageHeartRate: Double
    let averageRMSSD: Double
    let flowScoreHistory: [Double]
    let peakFlowState: BiometricFlowResult.FlowState

    var timeInFlowPercent: Double {
        guard sessionDuration > 0 else { return 0 }
        return (Double(timeInFlowSeconds) / sessionDuration) * 100
    }

    var summary: String {
        """
        Session: \(Int(sessionDuration / 60))min
        Flow Score: \(Int(averageFlowScore)) avg / \(Int(peakFlowScore)) peak
        Time in Flow: \(Int(timeInFlowPercent))%
        HR: \(Int(averageHeartRate)) bpm avg
        """
    }
}
