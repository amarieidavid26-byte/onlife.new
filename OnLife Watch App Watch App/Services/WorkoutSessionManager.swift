import Foundation
import HealthKit
import Combine

// HealthKit type identifiers
private let HKDataTypeIdentifierHeartRateVariabilitySeries = "HKDataTypeIdentifierHeartRateVariabilitySeries"

/// Manages HKWorkoutSession and real-time biometric streaming on Apple Watch
final class WorkoutSessionManager: NSObject, ObservableObject {
    static let shared = WorkoutSessionManager()

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    // Queries
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var heartbeatSeriesQuery: HKQuery?

    // Data buffers (2-minute rolling window)
    private var heartRateSamples: [(timestamp: Date, bpm: Double)] = []
    private var rrIntervals: [Double] = []
    private let bufferDuration: TimeInterval = 120  // 2 minutes

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties

    @Published var isSessionActive = false
    @Published var isAuthorized = false
    @Published var currentHeartRate: Double = 0
    @Published var currentRMSSD: Double = 0
    @Published var sessionStartTime: Date?
    @Published var elapsedSeconds: Int = 0
    @Published var error: Error?

    // Session metadata for iPhone sync
    private(set) var currentSessionID: String?
    private(set) var currentTaskName: String?
    private(set) var currentTargetDuration: Int = 25  // minutes
    private(set) var currentSeedType: String = "oneTime"
    private(set) var currentPlantSpecies: String = "oak"

    // Timer for elapsed time
    private var timer: Timer?

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    private var typesToShare: Set<HKSampleType> {
        [HKQuantityType.workoutType()]
    }

    private var typesToRead: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKCategoryType(.sleepAnalysis),
            HKSeriesType.heartbeat()
        ]

        // Add HRV series type for watchOS 11+ / iOS 18+
        if #available(iOS 18.0, watchOS 11.0, *) {
            if let hrvSeriesType = HKObjectType.seriesType(forIdentifier: HKDataTypeIdentifierHeartRateVariabilitySeries) {
                types.insert(hrvSeriesType)
            }
        }

        return types
    }

    func checkAuthorizationStatus() {
        let heartRateType = HKQuantityType(.heartRate)
        let status = healthStore.authorizationStatus(for: heartRateType)
        DispatchQueue.main.async {
            self.isAuthorized = (status == .sharingAuthorized)
            print("⌚ [WorkoutSession] Authorization status: \(self.isAuthorized)")
        }
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WorkoutError.healthKitNotAvailable
        }

        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)

        // Give HealthKit a moment to update authorization state on physical device
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second delay

        await MainActor.run {
            self.isAuthorized = true
            print("✅ [WorkoutSession] Authorization granted")
        }
    }

    // MARK: - Session Configuration

    /// Configure session metadata before starting
    func configureSession(
        taskName: String,
        targetDurationMinutes: Int,
        seedType: String = "oneTime",
        plantSpecies: String = "oak"
    ) {
        currentTaskName = taskName
        currentTargetDuration = targetDurationMinutes
        currentSeedType = seedType
        currentPlantSpecies = plantSpecies
        print("⌚ [WorkoutSession] Configured: '\(taskName)', \(targetDurationMinutes)min, \(seedType), \(plantSpecies)")
    }

    // MARK: - Session Control

    func startSession() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WorkoutError.healthKitNotAvailable
        }

        guard !isSessionActive else {
            throw WorkoutError.sessionAlreadyActive
        }

        // Use our maintained authorization state instead of querying HealthKit
        // This avoids simulator timing issues where authorizationStatus lags
        guard isAuthorized else {
            print("❌ [WorkoutSession] Not authorized - please grant HealthKit permissions")
            throw WorkoutError.notAuthorized
        }

        // Generate session ID
        currentSessionID = UUID().uuidString

        // Configure workout session
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody  // Best for focus sessions
        configuration.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()

            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Start session
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            try await workoutBuilder?.beginCollection(at: startDate)

            await MainActor.run {
                self.isSessionActive = true
                self.sessionStartTime = startDate
                self.startHeartRateQuery()
                self.startHeartbeatSeriesQuery()
                self.startTimer()
            }

            // Notify iPhone about session start
            sendSessionStartToiPhone()

            print("✅ [WorkoutSession] Started successfully")

        } catch {
            print("❌ [WorkoutSession] Failed to start: \(error)")
            currentSessionID = nil
            throw error
        }
    }

    // MARK: - iPhone Communication

    private func sendSessionStartToiPhone() {
        guard let sessionID = currentSessionID,
              let startTime = sessionStartTime else {
            print("⚠️ [WorkoutSession] Cannot send to iPhone - missing session data")
            return
        }

        let taskName = currentTaskName ?? "Focus Session"

        // Get selected garden from iPhone (assume it was already set via Phase 1B)
        let gardenID = UserDefaults.standard.string(forKey: "selectedGardenID") ?? "8CD3EAB5-6C0A-4328-9B6D-92605377102B"

        let message: [String: Any] = [
            "command": "sessionStart",  // ✅ camelCase to match iPhone
            "sessionID": sessionID,
            "gardenID": gardenID,  // ✅ Required by iPhone
            "plantDescription": taskName,  // ✅ iPhone expects this name
            "targetDuration": Double(currentTargetDuration * 60),
            "timestamp": startTime.timeIntervalSince1970
        ]

        WatchConnectivityManager.shared.sendMessage(message) { reply in
            print("✅ [WorkoutSession] iPhone acknowledged session start")
        }

        print("📤 [WorkoutSession] Sent session start to iPhone: '\(taskName)' (ID: \(sessionID))")
    }

    /// Send session end notification to iPhone
    func sendSessionEndToiPhone(wasCompleted: Bool, peakFlowScore: Int, timeInFlowSeconds: Int) {
        guard let sessionID = currentSessionID else {
            print("⚠️ [WorkoutSession] Cannot send end to iPhone - no session ID")
            return
        }

        let message: [String: Any] = [
            "command": "sessionEnd",  // ✅ camelCase
            "sessionID": sessionID,
            "actualDuration": Double(elapsedSeconds),
            "wasCompleted": wasCompleted,
            "peakFlowScore": peakFlowScore,
            "timeInFlow": Double(timeInFlowSeconds)
        ]

        WatchConnectivityManager.shared.sendMessage(message) { reply in
            print("✅ [WorkoutSession] iPhone acknowledged session end")
        }

        print("📤 [WorkoutSession] Sent session end to iPhone: \(elapsedSeconds)s, completed: \(wasCompleted)")

        // Clear session ID
        currentSessionID = nil
    }

    func endSession() async {
        workoutSession?.end()

        // Stop queries
        if let hrQuery = heartRateQuery {
            healthStore.stop(hrQuery)
        }
        if let hbQuery = heartbeatSeriesQuery {
            healthStore.stop(hbQuery)
        }

        // End builder collection
        if let builder = workoutBuilder {
            do {
                try await builder.endCollection(at: Date())
                try await builder.finishWorkout()
            } catch {
                print("⚠️ [WorkoutSession] Error finishing workout: \(error)")
            }
        }

        await MainActor.run {
            self.isSessionActive = false
            self.stopTimer()
            self.clearBuffers()
        }

        print("✅ [WorkoutSession] Ended")
    }

    // MARK: - Heart Rate Query

    private func startHeartRateQuery() {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: sessionStartTime ?? Date(),
            end: nil,
            options: .strictStartDate
        )

        heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        heartRateQuery?.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        if let query = heartRateQuery {
            healthStore.execute(query)
            print("💓 [WorkoutSession] Heart rate query started")
        }
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample] else { return }

        for sample in quantitySamples {
            let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            let timestamp = sample.startDate

            DispatchQueue.main.async {
                self.heartRateSamples.append((timestamp, bpm))
                self.currentHeartRate = bpm
                self.pruneOldSamples()

                // Send to iPhone
                let biometricSample = BiometricSample(
                    timestamp: timestamp,
                    heartRate: bpm,
                    rmssd: self.currentRMSSD
                )
                WatchConnectivityManager.shared.sendBiometricSample(biometricSample)

                print("💓 [WorkoutSession] HR: \(Int(bpm)) bpm")
            }
        }
    }

    // MARK: - Heartbeat Series Query (for RR intervals)

    private func startHeartbeatSeriesQuery() {
        let heartbeatType = HKSeriesType.heartbeat()
        let predicate = HKQuery.predicateForSamples(
            withStart: sessionStartTime ?? Date(),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: heartbeatType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartbeatSeries(samples)
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartbeatSeries(samples)
        }

        healthStore.execute(query)
        heartbeatSeriesQuery = query
        print("💗 [WorkoutSession] Heartbeat series query started")
    }

    private func processHeartbeatSeries(_ samples: [HKSample]?) {
        guard let seriesSamples = samples as? [HKHeartbeatSeriesSample] else { return }

        for series in seriesSamples {
            var previousTime: TimeInterval = 0

            let seriesQuery = HKHeartbeatSeriesQuery(heartbeatSeries: series) { [weak self] query, timeSinceSeriesStart, precedes, done, error in
                guard error == nil else { return }

                DispatchQueue.main.async {
                    // Calculate RR interval from successive heartbeat times
                    if previousTime > 0 {
                        let rrInterval = (timeSinceSeriesStart - previousTime) * 1000  // Convert to ms
                        if rrInterval > 300 && rrInterval < 2000 {  // Sanity check (30-200 bpm range)
                            self?.rrIntervals.append(rrInterval)
                            self?.calculateRMSSD()
                        }
                    }
                    previousTime = timeSinceSeriesStart
                }
            }

            healthStore.execute(seriesQuery)
        }
    }

    // MARK: - RMSSD Calculation

    /// Calculate RMSSD from RR intervals (Root Mean Square of Successive Differences)
    private func calculateRMSSD() {
        // Use last 30 intervals (~30 seconds of data at 60 bpm)
        let recentIntervals = Array(rrIntervals.suffix(30))

        guard recentIntervals.count >= 2 else { return }

        var sumSquaredDiffs: Double = 0
        for i in 1..<recentIntervals.count {
            let diff = recentIntervals[i] - recentIntervals[i-1]
            sumSquaredDiffs += diff * diff
        }

        let rmssd = sqrt(sumSquaredDiffs / Double(recentIntervals.count - 1))

        DispatchQueue.main.async {
            self.currentRMSSD = rmssd
            print("📊 [WorkoutSession] RMSSD: \(Int(rmssd))ms (from \(recentIntervals.count) intervals)")
        }
    }

    // MARK: - Buffer Management

    private func pruneOldSamples() {
        let cutoff = Date().addingTimeInterval(-bufferDuration)
        heartRateSamples.removeAll { $0.timestamp < cutoff }

        // Keep last 120 RR intervals (~2 min at 60 bpm)
        if rrIntervals.count > 120 {
            rrIntervals.removeFirst(rrIntervals.count - 120)
        }
    }

    private func clearBuffers() {
        heartRateSamples.removeAll()
        rrIntervals.removeAll()
        currentHeartRate = 0
        currentRMSSD = 0
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.sessionStartTime else { return }
            self.elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        elapsedSeconds = 0
    }

    // MARK: - Public Accessors

    func getRecentHeartRates() -> [Double] {
        return heartRateSamples.map { $0.bpm }
    }

    func getAverageHeartRate() -> Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        return heartRateSamples.map { $0.bpm }.reduce(0, +) / Double(heartRateSamples.count)
    }

    func getAverageRMSSD() -> Double {
        return currentRMSSD  // Use current calculated RMSSD
    }

    // MARK: - Errors

    enum WorkoutError: Error, LocalizedError {
        case healthKitNotAvailable
        case notAuthorized
        case sessionAlreadyActive
        case sessionNotActive

        var errorDescription: String? {
            switch self {
            case .healthKitNotAvailable:
                return "HealthKit is not available"
            case .notAuthorized:
                return "HealthKit authorization required"
            case .sessionAlreadyActive:
                return "A workout session is already active"
            case .sessionNotActive:
                return "No workout session is currently active"
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("⌚ [WorkoutSession] State: \(fromState.rawValue) → \(toState.rawValue)")

        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isSessionActive = true
            case .ended, .stopped:
                self.isSessionActive = false
            default:
                break
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ [WorkoutSession] Error: \(error)")
        DispatchQueue.main.async {
            self.error = error
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Data collected - could trigger flow score recalculation
        for type in collectedTypes {
            print("📥 [WorkoutSession] Collected data for: \(type.identifier)")
        }
    }
}
