import Foundation
import HealthKit
import WatchConnectivity
import Combine

// MARK: - Watch Session Manager
/// Manages biometric data collection and session state on Apple Watch.
/// Communicates with iPhone app for real-time flow detection.
class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    // MARK: - Published Properties

    @Published var isSessionActive: Bool = false
    @Published var currentHeartRate: Double = 0
    @Published var currentRMSSD: Double = 0
    @Published var sessionDuration: TimeInterval = 0
    @Published var isPaused: Bool = false
    @Published var batteryLevel: Double = 1.0

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var heartbeatSeriesQuery: HKQuery?
    private var sdnnQuery: HKAnchoredObjectQuery?

    // MARK: - Session State

    private var sessionStartTime: Date?
    private var targetDuration: TimeInterval = 1800  // 30 min default
    private var sessionTimer: Timer?

    // MARK: - Data Buffers

    /// Buffer of RR intervals in milliseconds
    private var rrIntervalBuffer: [Double] = []

    /// Timestamps for RR intervals
    private var rrTimestamps: [Date] = []

    /// Maximum buffer size (5 minutes at ~60 bpm = 300 beats)
    private let maxBufferSize = 300

    // MARK: - WatchConnectivity

    private var wcSession: WCSession?

    /// Timer for periodic data transmission to iPhone
    private var dataTransmitTimer: Timer?

    /// Transmission interval in seconds
    private let transmitInterval: TimeInterval = 5.0

    // MARK: - Initialization

    override init() {
        super.init()
        setupWatchConnectivity()
        requestHealthKitPermissions()
    }

    // MARK: - WatchConnectivity Setup

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("⌚ [WatchSession] WCSession not supported")
            return
        }

        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
    }

    // MARK: - HealthKit Setup

    private func requestHealthKitPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⌚ [WatchSession] HealthKit not available")
            return
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKSeriesType.heartbeat()
        ]

        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            if let error = error {
                print("⌚ [WatchSession] HealthKit auth error: \(error)")
            } else if success {
                print("⌚ [WatchSession] HealthKit authorized")
            }
        }
    }

    // MARK: - Session Management

    /// Start a focus session with biometric collection
    /// - Parameter targetDuration: Target session duration in seconds
    func startFocusSession(targetDuration: TimeInterval) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⌚ [WatchSession] Cannot start - HealthKit unavailable")
            return
        }

        self.targetDuration = targetDuration

        // Create workout configuration for "Mind and Body" (meditation-like)
        // This enables high-frequency heart rate sampling
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()

            workoutSession?.delegate = self
            workoutBuilder?.delegate = self

            // Set data source for live data
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Start the session
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { [weak self] success, error in
                if success {
                    DispatchQueue.main.async {
                        self?.isSessionActive = true
                        self?.sessionStartTime = Date()
                        self?.isPaused = false
                        print("⌚ [WatchSession] Session started successfully")
                    }
                } else if let error = error {
                    print("⌚ [WatchSession] Failed to begin collection: \(error)")
                }
            }

            // Start data queries
            startHeartRateQuery()
            startHeartbeatSeriesQuery()
            startSDNNQuery()

            // Start data transmission timer
            startDataTransmission()

            // Start session duration timer
            startSessionTimer()

            // Notify iPhone
            sendSessionStateToiPhone(state: "active")

        } catch {
            print("⌚ [WatchSession] Failed to create workout session: \(error)")
        }
    }

    /// Stop the current focus session
    func stopFocusSession() {
        workoutSession?.end()
        stopQueries()
        stopDataTransmission()
        sessionTimer?.invalidate()
        sessionTimer = nil

        DispatchQueue.main.async { [weak self] in
            self?.isSessionActive = false
            self?.isPaused = false
        }

        // Send final data to iPhone
        sendDataToiPhone()
        sendSessionStateToiPhone(state: "ended")

        // Clear buffers
        rrIntervalBuffer.removeAll()
        rrTimestamps.removeAll()

        print("⌚ [WatchSession] Session stopped")
    }

    /// Pause the current session
    func pauseSession() {
        workoutSession?.pause()
        DispatchQueue.main.async { [weak self] in
            self?.isPaused = true
        }
        sendSessionStateToiPhone(state: "paused")
    }

    /// Resume a paused session
    func resumeSession() {
        workoutSession?.resume()
        DispatchQueue.main.async { [weak self] in
            self?.isPaused = false
        }
        sendSessionStateToiPhone(state: "active")
    }

    // MARK: - Session Timer

    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.sessionStartTime else { return }
            DispatchQueue.main.async {
                self.sessionDuration = Date().timeIntervalSince(start)
            }
        }
    }

    // MARK: - Heart Rate Query (Continuous)

    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        heartRateQuery = query
        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }

        for sample in samples {
            let heartRate = sample.quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
            DispatchQueue.main.async { [weak self] in
                self?.currentHeartRate = heartRate
            }
        }
    }

    // MARK: - Heartbeat Series Query (R-R Intervals)

    private func startHeartbeatSeriesQuery() {
        let heartbeatType = HKSeriesType.heartbeat()

        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
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

        heartbeatSeriesQuery = query
        healthStore.execute(query)
    }

    private func processHeartbeatSeries(_ samples: [HKSample]?) {
        guard let heartbeatSamples = samples as? [HKHeartbeatSeriesSample] else { return }

        for sample in heartbeatSamples {
            let seriesQuery = HKHeartbeatSeriesQuery(heartbeatSeries: sample) { [weak self] query, timeSinceSeriesStart, precededByGap, done, error in

                guard let self = self else { return }

                // Skip if there was a gap (artifact)
                if precededByGap { return }

                // Skip first beat (no interval yet)
                if timeSinceSeriesStart == 0 { return }

                // Calculate R-R interval in milliseconds
                // timeSinceSeriesStart is cumulative, so we need the difference
                let rrInterval = timeSinceSeriesStart * 1000

                // Validate physiological bounds (300-2000ms = 30-200 bpm)
                guard rrInterval >= 300 && rrInterval <= 2000 else { return }

                // Add to buffer
                self.rrIntervalBuffer.append(rrInterval)
                self.rrTimestamps.append(Date())

                // Prune buffer if too large
                if self.rrIntervalBuffer.count > self.maxBufferSize {
                    self.rrIntervalBuffer.removeFirst(50)
                    self.rrTimestamps.removeFirst(50)
                }
            }
            healthStore.execute(seriesQuery)
        }
    }

    // MARK: - SDNN Query (HealthKit's HRV)

    private func startSDNNQuery() {
        guard let sdnnType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: sdnnType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processSDNNSamples(samples)
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processSDNNSamples(samples)
        }

        sdnnQuery = query
        healthStore.execute(query)
    }

    private func processSDNNSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }

        for sample in samples {
            let sdnn = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            // RMSSD ≈ SDNN × 1.4 for resting measurements
            let approximateRMSSD = sdnn * 1.4
            DispatchQueue.main.async { [weak self] in
                self?.currentRMSSD = approximateRMSSD
            }
        }
    }

    // MARK: - Stop Queries

    private func stopQueries() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        if let query = heartbeatSeriesQuery {
            healthStore.stop(query)
            heartbeatSeriesQuery = nil
        }
        if let query = sdnnQuery {
            healthStore.stop(query)
            sdnnQuery = nil
        }
    }

    // MARK: - RMSSD Calculation

    /// Calculate RMSSD from buffered RR intervals
    private func calculateRMSSD() -> Double {
        guard rrIntervalBuffer.count >= 10 else { return 0 }

        // Use last 60 intervals (approximately 1 minute)
        let recentRR = Array(rrIntervalBuffer.suffix(60))

        var sumSquaredDiffs: Double = 0
        for i in 0..<(recentRR.count - 1) {
            let diff = recentRR[i + 1] - recentRR[i]
            sumSquaredDiffs += diff * diff
        }

        let meanSquaredDiff = sumSquaredDiffs / Double(recentRR.count - 1)
        return sqrt(meanSquaredDiff)
    }

    /// Calculate signal quality based on artifact rate
    private func calculateSignalQuality() -> Double {
        guard rrIntervalBuffer.count >= 10 else { return 0.5 }

        let recentRR = Array(rrIntervalBuffer.suffix(30))
        var artifactCount = 0

        for i in 0..<(recentRR.count - 1) {
            let delta = abs(recentRR[i + 1] - recentRR[i])
            // >300ms change in single beat is likely artifact
            if delta > 300 {
                artifactCount += 1
            }
        }

        let artifactRate = Double(artifactCount) / Double(recentRR.count - 1)
        return 1.0 - artifactRate
    }

    // MARK: - Data Transmission to iPhone

    private func startDataTransmission() {
        dataTransmitTimer?.invalidate()
        dataTransmitTimer = Timer.scheduledTimer(
            withTimeInterval: transmitInterval,
            repeats: true
        ) { [weak self] _ in
            self?.sendDataToiPhone()
        }
    }

    private func stopDataTransmission() {
        dataTransmitTimer?.invalidate()
        dataTransmitTimer = nil
    }

    private func sendDataToiPhone() {
        guard let wcSession = wcSession, wcSession.isReachable else { return }

        // Calculate current RMSSD
        let rmssd = calculateRMSSD()
        DispatchQueue.main.async { [weak self] in
            self?.currentRMSSD = rmssd
        }

        // Build data dictionary
        let dataDict: [String: Any] = [
            "timestamp": Date(),
            "heartRate": currentHeartRate,
            "rrIntervals": Array(rrIntervalBuffer.suffix(30)),
            "calculatedRMSSD": rmssd,
            "isInWorkoutSession": isSessionActive,
            "sessionDuration": sessionDuration,
            "batteryLevel": batteryLevel,
            "signalQuality": calculateSignalQuality()
        ]

        wcSession.sendMessage(["biometricData": dataDict], replyHandler: nil) { error in
            print("⌚ [WatchSession] Error sending data: \(error)")
        }
    }

    private func sendSessionStateToiPhone(state: String) {
        guard let wcSession = wcSession, wcSession.isReachable else { return }

        wcSession.sendMessage(["sessionState": state], replyHandler: nil, errorHandler: nil)
    }

    // MARK: - Battery Monitoring

    func updateBatteryLevel() {
        // WKInterfaceDevice.current().batteryLevel returns -1 if monitoring not enabled
        // Enable battery monitoring in Watch app lifecycle
        #if os(watchOS)
        import WatchKit
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        let level = WKInterfaceDevice.current().batteryLevel
        if level >= 0 {
            batteryLevel = Double(level)
        }
        #endif
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WatchSessionManager: HKWorkoutSessionDelegate {

    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        DispatchQueue.main.async { [weak self] in
            switch toState {
            case .running:
                self?.isSessionActive = true
                self?.isPaused = false
            case .paused:
                self?.isPaused = true
            case .ended, .stopped:
                self?.isSessionActive = false
                self?.isPaused = false
            default:
                break
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("⌚ [WatchSession] Workout session error: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.isSessionActive = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WatchSessionManager: HKLiveWorkoutBuilderDelegate {

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Data collection notification
        for type in collectedTypes {
            if type == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                // Heart rate data collected
            }
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            print("⌚ [WatchSession] WCSession activation error: \(error)")
        } else {
            print("⌚ [WatchSession] WCSession activated: \(activationState.rawValue)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleCommand(message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        handleCommand(message)
        replyHandler(["success": true])
    }

    private func handleCommand(_ message: [String: Any]) {
        guard let commandString = message["command"] as? String else { return }

        DispatchQueue.main.async { [weak self] in
            switch commandString {
            case "startSession":
                let duration = message["duration"] as? TimeInterval ?? 1800
                self?.startFocusSession(targetDuration: duration)

            case "stopSession":
                self?.stopFocusSession()

            case "pauseSession":
                self?.pauseSession()

            case "resumeSession":
                self?.resumeSession()

            case "requestData":
                self?.sendDataToiPhone()

            case "syncBaseline":
                if let baselineData = message["baseline"] as? Data {
                    // Store baseline for local processing
                    UserDefaults.standard.set(baselineData, forKey: "biometric_baseline")
                }

            default:
                print("⌚ [WatchSession] Unknown command: \(commandString)")
            }
        }
    }
}
