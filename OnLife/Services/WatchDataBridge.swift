import Foundation
import WatchConnectivity
import Combine

// MARK: - Watch Biometric Data
/// Real-time biometric data received from Apple Watch.
/// Contains heart rate, HRV metrics, and session state.
struct WatchBiometricData: Codable {
    let timestamp: Date
    let heartRate: Double
    let sdnn: Double?           // From HealthKit heartRateVariabilitySDNN
    let rrIntervals: [Double]?  // From HKHeartbeatSeriesSample (ms)
    let calculatedRMSSD: Double?
    let isInWorkoutSession: Bool
    let sessionDuration: TimeInterval?
    let batteryLevel: Double?
    let signalQuality: Double?  // 0-1, based on artifact rate

    /// Whether this reading has usable HRV data
    var hasHRVData: Bool {
        return (sdnn != nil && sdnn! > 0) ||
               (calculatedRMSSD != nil && calculatedRMSSD! > 0) ||
               (rrIntervals != nil && !rrIntervals!.isEmpty)
    }

    /// Best available RMSSD value
    var bestRMSSD: Double? {
        if let rmssd = calculatedRMSSD, rmssd > 0 {
            return rmssd
        }
        if let sdnn = sdnn, sdnn > 0 {
            // Approximate RMSSD from SDNN (r ≈ 0.90 at rest)
            return sdnn * 1.4
        }
        return nil
    }
}

// MARK: - Watch Command
/// Commands that can be sent to the Watch app.
enum WatchCommand: String, Codable {
    case startSession = "startSession"
    case stopSession = "stopSession"
    case pauseSession = "pauseSession"
    case resumeSession = "resumeSession"
    case requestData = "requestData"
    case syncBaseline = "syncBaseline"
}

// MARK: - Connection Status
enum WatchConnectionStatus: String {
    case disconnected = "Not Connected"
    case connecting = "Connecting..."
    case connected = "Connected"
    case sessionActive = "Session Active"
    case notSupported = "Watch Not Supported"
    case notPaired = "Watch Not Paired"
    case notInstalled = "App Not Installed"

    var icon: String {
        switch self {
        case .disconnected: return "applewatch.slash"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .connected: return "applewatch"
        case .sessionActive: return "applewatch.radiowaves.left.and.right"
        case .notSupported: return "xmark.circle"
        case .notPaired: return "applewatch.slash"
        case .notInstalled: return "arrow.down.circle"
        }
    }

    var isUsable: Bool {
        return self == .connected || self == .sessionActive
    }
}

// MARK: - Watch Data Bridge (iPhone Side)
/// Manages real-time communication with Apple Watch for biometric data.
/// Receives HRV and heart rate data for flow state detection.
class WatchDataBridge: NSObject, ObservableObject {
    static let shared = WatchDataBridge()

    // MARK: - Published Properties

    @Published var isWatchConnected: Bool = false
    @Published var isWatchReachable: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var latestBiometricData: WatchBiometricData?
    @Published var liveHeartRate: Double = 0
    @Published var liveRMSSD: Double = 0
    @Published var connectionStatus: WatchConnectionStatus = .disconnected
    @Published var lastDataReceived: Date?

    // MARK: - Data History

    /// History of RR intervals for HRV processing
    private var rrIntervalHistory: [(timestamp: Date, rr: Double)] = []

    /// History of heart rate readings
    private var heartRateHistory: [(timestamp: Date, hr: Double)] = []

    /// Maximum history duration (2 minutes for HRV window)
    private let maxHistoryDuration: TimeInterval = 120

    // MARK: - Processing Engines

    private let hrvProcessingEngine = HRVProcessingEngine.shared

    // MARK: - Combine Publishers

    /// Publisher for real-time biometric data
    let biometricDataPublisher = PassthroughSubject<WatchBiometricData, Never>()

    /// Publisher for processed HRV metrics
    let hrvMetricsPublisher = PassthroughSubject<HRVMetrics, Never>()

    /// Publisher for connection status changes
    let connectionStatusPublisher = PassthroughSubject<WatchConnectionStatus, Never>()

    // MARK: - WatchConnectivity Session

    private var session: WCSession?

    // MARK: - Initialization

    override init() {
        super.init()
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            connectionStatus = .notSupported
            print("⌚ [WatchBridge] WatchConnectivity not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()

        print("⌚ [WatchBridge] WatchConnectivity session activating...")
    }

    // MARK: - Public API

    /// Check if Watch is available for use
    var isWatchAvailable: Bool {
        guard let session = session else { return false }
        return session.isPaired && session.isWatchAppInstalled && session.isReachable
    }

    /// Start a focus session on the Watch
    /// - Parameter duration: Target session duration in seconds
    func startWatchSession(duration: TimeInterval) {
        guard let session = session, session.isReachable else {
            print("⌚ [WatchBridge] Cannot start session - Watch not reachable")
            connectionStatus = .disconnected
            return
        }

        let message: [String: Any] = [
            "command": WatchCommand.startSession.rawValue,
            "duration": duration,
            "timestamp": Date()
        ]

        session.sendMessage(message, replyHandler: { [weak self] response in
            DispatchQueue.main.async {
                if let success = response["success"] as? Bool, success {
                    self?.connectionStatus = .sessionActive
                    print("⌚ [WatchBridge] Watch session started successfully")
                }
            }
        }, errorHandler: { [weak self] error in
            print("⌚ [WatchBridge] Error starting watch session: \(error)")
            self?.connectionStatus = .connected
        })
    }

    /// Stop the current focus session on the Watch
    func stopWatchSession() {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "command": WatchCommand.stopSession.rawValue,
            "timestamp": Date()
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("⌚ [WatchBridge] Error stopping watch session: \(error)")
        }

        DispatchQueue.main.async {
            self.connectionStatus = .connected
        }
    }

    /// Pause the current focus session on the Watch
    func pauseWatchSession() {
        sendCommand(.pauseSession)
    }

    /// Resume a paused focus session on the Watch
    func resumeWatchSession() {
        sendCommand(.resumeSession)
    }

    /// Request latest biometric data from Watch
    func requestLatestData() {
        sendCommand(.requestData)
    }

    /// Sync baseline data to Watch for local processing
    func syncBaseline(_ baseline: BiometricBaseline) {
        guard let session = session, session.isReachable else { return }

        if let data = try? JSONEncoder().encode(baseline) {
            let message: [String: Any] = [
                "command": WatchCommand.syncBaseline.rawValue,
                "baseline": data,
                "timestamp": Date()
            ]
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
    }

    // MARK: - Private Helpers

    private func sendCommand(_ command: WatchCommand) {
        guard let session = session, session.isReachable else {
            print("⌚ [WatchBridge] Cannot send command - Watch not reachable")
            return
        }

        let message: [String: Any] = [
            "command": command.rawValue,
            "timestamp": Date()
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("⌚ [WatchBridge] Error sending command \(command): \(error)")
        }
    }

    // MARK: - Process Incoming Biometric Data

    private func processIncomingData(_ data: WatchBiometricData) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.latestBiometricData = data
            self.lastDataReceived = Date()
            self.liveHeartRate = data.heartRate

            // Add to heart rate history
            self.heartRateHistory.append((timestamp: data.timestamp, hr: data.heartRate))
            self.pruneHistory()

            // Process RR intervals for RMSSD
            if let rrIntervals = data.rrIntervals, !rrIntervals.isEmpty {
                // Add to history
                for rr in rrIntervals {
                    self.rrIntervalHistory.append((timestamp: data.timestamp, rr: rr))
                }
                self.pruneHistory()

                // Calculate HRV if we have enough data
                if self.rrIntervalHistory.count >= 30 {
                    self.calculateAndPublishHRV()
                }
            } else if let calculatedRMSSD = data.calculatedRMSSD, calculatedRMSSD > 0 {
                // Use pre-calculated RMSSD from Watch
                self.liveRMSSD = calculatedRMSSD
            } else if let sdnn = data.sdnn, sdnn > 0 {
                // Approximate RMSSD from SDNN
                self.liveRMSSD = self.hrvProcessingEngine.approximateRMSSDFromSDNN(sdnn)
            }

            // Publish for subscribers
            self.biometricDataPublisher.send(data)

            print("⌚ [WatchBridge] Data received - HR: \(String(format: "%.0f", data.heartRate)), RMSSD: \(String(format: "%.1f", self.liveRMSSD))")
        }
    }

    /// Calculate HRV metrics from accumulated RR intervals
    private func calculateAndPublishHRV() {
        let rrValues = rrIntervalHistory.map { $0.rr }
        let timestamps = rrIntervalHistory.map { $0.timestamp }

        guard let first = timestamps.first, let last = timestamps.last else { return }
        let duration = last.timeIntervalSince(first)

        let hrvMetrics = hrvProcessingEngine.calculateMetrics(
            from: rrValues,
            windowDuration: duration
        )

        liveRMSSD = hrvMetrics.rmssd
        hrvMetricsPublisher.send(hrvMetrics)
    }

    /// Remove old data from history buffers
    private func pruneHistory() {
        let cutoff = Date().addingTimeInterval(-maxHistoryDuration)
        rrIntervalHistory = rrIntervalHistory.filter { $0.timestamp > cutoff }
        heartRateHistory = heartRateHistory.filter { $0.timestamp > cutoff }
    }

    /// Clear all history (call at session start)
    func clearHistory() {
        rrIntervalHistory.removeAll()
        heartRateHistory.removeAll()
        liveRMSSD = 0
        liveHeartRate = 0
    }

    // MARK: - Data Quality

    /// Get average heart rate over recent window
    func getAverageHeartRate(windowSeconds: TimeInterval = 60) -> Double? {
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        let recent = heartRateHistory.filter { $0.timestamp > cutoff }
        guard !recent.isEmpty else { return nil }
        return recent.map { $0.hr }.reduce(0, +) / Double(recent.count)
    }

    /// Get data freshness (seconds since last update)
    var dataFreshness: TimeInterval? {
        guard let last = lastDataReceived else { return nil }
        return Date().timeIntervalSince(last)
    }

    /// Check if data is stale (>30 seconds old)
    var isDataStale: Bool {
        guard let freshness = dataFreshness else { return true }
        return freshness > 30
    }
}

// MARK: - WCSessionDelegate
extension WatchDataBridge: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let error = error {
                print("⌚ [WatchBridge] Activation error: \(error)")
                self.connectionStatus = .disconnected
                return
            }

            switch activationState {
            case .activated:
                self.isWatchConnected = session.isPaired
                self.isWatchAppInstalled = session.isWatchAppInstalled
                self.isWatchReachable = session.isReachable

                if !session.isPaired {
                    self.connectionStatus = .notPaired
                } else if !session.isWatchAppInstalled {
                    self.connectionStatus = .notInstalled
                } else if session.isReachable {
                    self.connectionStatus = .connected
                } else {
                    self.connectionStatus = .disconnected
                }

                print("⌚ [WatchBridge] Activated - Paired: \(session.isPaired), Installed: \(session.isWatchAppInstalled), Reachable: \(session.isReachable)")

            case .inactive, .notActivated:
                self.connectionStatus = .disconnected
                self.isWatchConnected = false

            @unknown default:
                self.connectionStatus = .disconnected
            }

            self.connectionStatusPublisher.send(self.connectionStatus)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isWatchReachable = session.isReachable

            if session.isReachable {
                if self.connectionStatus != .sessionActive {
                    self.connectionStatus = .connected
                }
                print("⌚ [WatchBridge] Watch became reachable")
            } else {
                self.connectionStatus = .disconnected
                print("⌚ [WatchBridge] Watch became unreachable")
            }

            self.connectionStatusPublisher.send(self.connectionStatus)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionStatus = .disconnected
            self?.connectionStatusPublisher.send(.disconnected)
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionStatus = .disconnected
            self?.connectionStatusPublisher.send(.disconnected)
        }
        // Reactivate session for device switching
        session.activate()
    }

    // MARK: - Message Handling

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncomingMessage(message)
        replyHandler(["received": true])
    }

    private func handleIncomingMessage(_ message: [String: Any]) {
        // Handle biometric data
        if let dataDict = message["biometricData"] as? [String: Any] {
            let data = WatchBiometricData(
                timestamp: dataDict["timestamp"] as? Date ?? Date(),
                heartRate: dataDict["heartRate"] as? Double ?? 0,
                sdnn: dataDict["sdnn"] as? Double,
                rrIntervals: dataDict["rrIntervals"] as? [Double],
                calculatedRMSSD: dataDict["calculatedRMSSD"] as? Double,
                isInWorkoutSession: dataDict["isInWorkoutSession"] as? Bool ?? false,
                sessionDuration: dataDict["sessionDuration"] as? TimeInterval,
                batteryLevel: dataDict["batteryLevel"] as? Double,
                signalQuality: dataDict["signalQuality"] as? Double
            )
            processIncomingData(data)
        }

        // Handle session state changes
        if let sessionState = message["sessionState"] as? String {
            DispatchQueue.main.async { [weak self] in
                if sessionState == "active" {
                    self?.connectionStatus = .sessionActive
                } else if sessionState == "ended" {
                    self?.connectionStatus = .connected
                }
            }
        }

        // Handle errors from Watch
        if let error = message["error"] as? String {
            print("⌚ [WatchBridge] Watch reported error: \(error)")
        }
    }

    // MARK: - Application Context (Background Updates)

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Handle background context updates (baseline sync, etc.)
        if let baselineData = applicationContext["baseline"] as? Data {
            if let baseline = try? JSONDecoder().decode(BiometricBaseline.self, from: baselineData) {
                print("⌚ [WatchBridge] Received baseline update from Watch")
                // Update local baseline if needed
            }
        }
    }

    // MARK: - User Info Transfer (Guaranteed Delivery)

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        // Handle guaranteed delivery data (session summaries, etc.)
        if let sessionSummary = userInfo["sessionSummary"] as? [String: Any] {
            print("⌚ [WatchBridge] Received session summary: \(sessionSummary)")
            // Process completed session data
        }
    }
}

// MARK: - Combine Extensions
extension WatchDataBridge {
    /// Publisher that emits every time new biometric data is available
    var biometricUpdates: AnyPublisher<WatchBiometricData, Never> {
        biometricDataPublisher.eraseToAnyPublisher()
    }

    /// Publisher that emits processed HRV metrics
    var hrvUpdates: AnyPublisher<HRVMetrics, Never> {
        hrvMetricsPublisher.eraseToAnyPublisher()
    }

    /// Publisher for connection status
    var connectionUpdates: AnyPublisher<WatchConnectionStatus, Never> {
        connectionStatusPublisher.eraseToAnyPublisher()
    }
}
