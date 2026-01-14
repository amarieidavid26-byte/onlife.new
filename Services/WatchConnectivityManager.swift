import Foundation
import WatchConnectivity
import Combine

// MARK: - Message Protocol

/// Commands for Watch <-> iPhone communication
enum WatchMessageCommand: String {
    case sessionStart = "session_start"
    case sessionUpdate = "session_update"
    case sessionEnd = "session_end"
    case requestBaseline = "request_baseline"
    case sendBaseline = "send_baseline"
    case substanceUpdate = "substance_update"
}

/// Session start message payload
struct SessionStartMessage: Codable {
    let sessionID: String
    let taskName: String
    let targetDuration: TimeInterval
    let timestamp: Date
    let seedType: String
    let plantSpecies: String
}

/// Manages bidirectional communication between iPhone and Apple Watch
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    private let session: WCSession
    private var cancellables = Set<AnyCancellable>()

    // Track active Watch sessions to prevent duplicates
    private var activeWatchSessionIDs: Set<String> = []

    // Message queue for when session isn't activated yet
    private var messageQueue: [(message: [String: Any], replyHandler: (([String: Any]) -> Void)?)] = []
    private var isProcessingQueue = false

    // MARK: - Published Properties

    @Published var isSessionActivated = false
    @Published var isReachable = false
    @Published var isPaired = false
    @Published var isWatchAppInstalled = false
    @Published var watchSessionState = WatchSessionState.inactive
    @Published var latestBiometricSample: BiometricSample?
    @Published var latestFlowScore: FlowScore?

    // MARK: - App Group Storage

    private let appGroupID = "group.com.onlife.shared"

    /// Cached UserDefaults instance for App Group
    /// Falls back to standard UserDefaults if App Group is not configured
    private lazy var sharedDefaults: UserDefaults = {
        if let groupDefaults = UserDefaults(suiteName: appGroupID) {
            print("✅ [WatchConnectivity] Using App Group storage: \(appGroupID)")
            return groupDefaults
        } else {
            print("⚠️ [WatchConnectivity] App Group not available, using standard UserDefaults")
            return UserDefaults.standard
        }
    }()

    // MARK: - Initialization

    private override init() {
        self.session = WCSession.default
        super.init()

        guard WCSession.isSupported() else {
            print("⚠️ [WatchConnectivity] WCSession not supported on this device")
            return
        }

        // CRITICAL: Ensure we're on the main thread
        // WCSession.delegate MUST be set on the main thread
        if Thread.isMainThread {
            setupSession()
        } else {
            print("⚠️ [WatchConnectivity] Not on main thread! Dispatching setup...")
            DispatchQueue.main.sync {
                self.setupSession()
            }
        }
    }
    
    private func setupSession() {
        // CRITICAL: Set delegate BEFORE activate
        session.delegate = self

        print("🔧 [WatchConnectivity] Activating WCSession...")
        print("   Thread: \(Thread.isMainThread ? "MAIN ✅" : "BACKGROUND ❌")")
        print("   Delegate set: \(session.delegate != nil ? "✅" : "❌")")

        // Activate synchronously
        session.activate()

        // Check state immediately after activate
        print("   State after activate(): \(session.activationState.rawValue)")
        print("   (0=notActivated, 1=inactive, 2=activated)")

        // Print additional diagnostic info
        #if os(iOS)
        print("   isPaired: \(session.isPaired)")
        print("   isWatchAppInstalled: \(session.isWatchAppInstalled)")
        #endif
        print("   isReachable: \(session.isReachable)")

        // Fallback: Check state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            print("⏱️ [WatchConnectivity] 2-second status check:")
            print("   Activation state: \(self.session.activationState.rawValue)")
            print("   isSessionActivated flag: \(self.isSessionActivated)")
            print("   isReachable: \(self.session.isReachable)")
            #if os(iOS)
            print("   isPaired: \(self.session.isPaired)")
            print("   isWatchAppInstalled: \(self.session.isWatchAppInstalled)")
            #endif

            // If state is activated but our flag isn't set, the delegate missed
            if self.session.activationState == .activated && !self.isSessionActivated {
                print("🔧 [WatchConnectivity] Fixing missed delegate callback!")
                self.isSessionActivated = true
                self.updateReachabilityStatus()
                self.processMessageQueue()
            } else if self.session.activationState == .notActivated {
                print("❌ [WatchConnectivity] STILL NOT ACTIVATED after 2 seconds!")
                print("   This usually means:")
                print("   1. Watch app not properly installed")
                print("   2. Watch not paired")
                print("   3. Bundle IDs mismatch")
                #if os(iOS)
                if !self.session.isPaired {
                    print("   → Watch is NOT PAIRED!")
                }
                if !self.session.isWatchAppInstalled {
                    print("   → Watch app NOT INSTALLED!")
                }
                #endif
            }
        }
    }

    // MARK: - Send Methods

    /// Send real-time data (use for HR, flow score during session)
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        // If not activated yet, queue the message
        guard isSessionActivated else {
            print("⏳ [WatchConnectivity] Session not activated yet, queueing message: \(message["command"] ?? "unknown")")
            messageQueue.append((message, replyHandler))

            // Try to force activation after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.forceActivationCheck()
            }
            return
        }

        guard session.isReachable else {
            print("⚠️ [WatchConnectivity] Counterpart not reachable, using applicationContext")
            updateApplicationContext(message)
            return
        }

        session.sendMessage(message, replyHandler: replyHandler) { error in
            print("❌ [WatchConnectivity] Failed to send message: \(error.localizedDescription)")
        }
    }

    /// Manually check and process queue if activation was missed
    func forceActivationCheck() {
        guard !isSessionActivated else { return }

        print("🔍 [WatchConnectivity] Force checking activation state...")
        print("   WCSession.activationState: \(session.activationState.rawValue)")

        if session.activationState == .activated {
            print("✅ [WatchConnectivity] Session IS activated, updating flag...")
            DispatchQueue.main.async {
                self.isSessionActivated = true
                self.updateReachabilityStatus()
                if !self.messageQueue.isEmpty {
                    print("📤 [WatchConnectivity] Force processing \(self.messageQueue.count) queued messages")
                    self.processMessageQueue()
                }
            }
        } else {
            print("⚠️ [WatchConnectivity] Session not activated yet, state: \(session.activationState.rawValue)")
        }
    }

    /// Process queued messages after session activates
    private func processMessageQueue() {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true

        let queuedMessages = messageQueue
        messageQueue.removeAll()

        for item in queuedMessages {
            print("  ↳ Sending queued message: \(item.message["command"] ?? "unknown")")
            sendMessage(item.message, replyHandler: item.replyHandler)
        }

        isProcessingQueue = false
        print("✅ [WatchConnectivity] Processed \(queuedMessages.count) queued messages")
    }

    /// Update application context (persisted, delivered when counterpart wakes)
    func updateApplicationContext(_ context: [String: Any]) {
        guard isSessionActivated else {
            print("⚠️ [WatchConnectivity] Cannot update context - session not activated")
            return
        }

        do {
            try session.updateApplicationContext(context)
            print("✅ [WatchConnectivity] Context updated")
        } catch {
            print("❌ [WatchConnectivity] Context update failed: \(error)")
        }
    }

    /// Send biometric sample to iPhone
    func sendBiometricSample(_ sample: BiometricSample) {
        guard let data = try? JSONEncoder().encode(sample) else { return }
        sendMessage(["biometricSample": data])
    }

    /// Send flow score update
    func sendFlowScore(_ score: FlowScore) {
        guard let data = try? JSONEncoder().encode(score) else { return }
        sendMessage(["flowScore": data])
    }

    /// Sync session state
    func syncSessionState(_ state: WatchSessionState) {
        guard isSessionActivated else {
            print("⚠️ [WatchConnectivity] Session not activated yet, skipping state sync")
            return
        }
        guard let data = try? JSONEncoder().encode(state) else { return }
        updateApplicationContext(["sessionState": data])
    }

    /// Sync baseline from iPhone to Watch
    func syncBaseline(_ baseline: PersonalBaseline) {
        guard let data = try? JSONEncoder().encode(baseline) else { return }

        // Always save to local storage regardless of session state
        sharedDefaults.set(data, forKey: "personalBaseline")

        guard isSessionActivated else {
            print("⚠️ [WatchConnectivity] Session not activated yet, baseline saved locally only")
            return
        }

        updateApplicationContext(["baseline": data])
        print("✅ [WatchConnectivity] Baseline synced to Watch")
    }

    /// Sync substance levels to Watch
    func syncSubstanceLevels(caffeine: Double, lTheanine: Double) {
        guard isSessionActivated else {
            print("⚠️ [WatchConnectivity] Session not activated yet, skipping substance sync")
            return
        }
        updateApplicationContext([
            "activeCaffeine": caffeine,
            "activeLTheanine": lTheanine,
            "substanceTimestamp": Date().timeIntervalSince1970
        ])
    }

    /// Sync sleep score to Watch
    func syncSleepScore(_ score: Double) {
        guard isSessionActivated else {
            print("⚠️ [WatchConnectivity] Session not activated yet, skipping sleep score sync")
            return
        }
        updateApplicationContext(["sleepScore": score])
    }

    // MARK: - Retrieve Shared Data

    func getStoredBaseline() -> PersonalBaseline? {
        guard let data = sharedDefaults.data(forKey: "personalBaseline"),
              let baseline = try? JSONDecoder().decode(PersonalBaseline.self, from: data) else {
            return nil
        }
        return baseline
    }

    func saveBaseline(_ baseline: PersonalBaseline) {
        guard let data = try? JSONEncoder().encode(baseline) else { return }
        sharedDefaults.set(data, forKey: "personalBaseline")
    }

    // MARK: - Session Commands

    /// Request Watch to start a focus session
    func requestStartSession(task: String, durationMinutes: Int) {
        sendMessage([
            "command": "startSession",
            "task": task,
            "duration": durationMinutes
        ])
    }

    /// Request Watch to end current session
    func requestEndSession() {
        sendMessage(["command": "endSession"])
    }

    // MARK: - Test Message

    /// Send test message to Watch and receive reply (for debugging connectivity)
    func sendTestMessage() {
        guard session.isReachable else {
            print("❌ [Test] Watch not reachable")
            return
        }

        print("📤 [Test] Sending message to Watch...")
        let message: [String: Any] = ["test": "Hello from iPhone! 📱", "timestamp": Date().timeIntervalSince1970]

        session.sendMessage(message, replyHandler: { reply in
            print("✅ [Test] Got reply from Watch: \(reply)")
        }, errorHandler: { error in
            print("❌ [Test] Send failed: \(error.localizedDescription)")
        })
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // IMMEDIATE logging - before any dispatch
        print("🔔🔔🔔 [WatchConnectivity] activationDidCompleteWith CALLED! 🔔🔔🔔")
        print("   State: \(activationState.rawValue)")
        print("   Error: \(error?.localizedDescription ?? "none")")
        print("   Thread: \(Thread.isMainThread ? "main" : "background")")

        DispatchQueue.main.async {
            if let error = error {
                print("❌ [WatchConnectivity] Activation failed: \(error)")
                self.isSessionActivated = false
            } else {
                self.isSessionActivated = (activationState == .activated)
                print("✅ [WatchConnectivity] Session activated: \(self.isSessionActivated)")

                if self.isSessionActivated {
                    self.updateReachabilityStatus()

                    if !self.messageQueue.isEmpty {
                        print("📤 [WatchConnectivity] Processing \(self.messageQueue.count) queued messages")
                        self.processMessageQueue()
                    }
                }
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.updateReachabilityStatus()
        }
    }

    private func updateReachabilityStatus() {
        isReachable = session.isReachable
        #if os(iOS)
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        print("📱 [WatchConnectivity] Paired: \(isPaired), Installed: \(isWatchAppInstalled), Reachable: \(isReachable)")
        #else
        print("⌚ [WatchConnectivity] Reachable: \(isReachable)")
        #endif
    }

    // MARK: - Receive Messages

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            // Handle test messages with custom reply
            if message["test"] != nil {
                #if os(watchOS)
                print("⌚ [Test] Watch received message: \(message)")
                let reply: [String: Any] = ["response": "Hello from Watch! ⌚", "timestamp": Date().timeIntervalSince1970]
                replyHandler(reply)
                #else
                print("📱 [Test] iPhone received message: \(message)")
                replyHandler(["response": "Hello from iPhone! 📱", "timestamp": Date().timeIntervalSince1970])
                #endif
                return
            }

            #if os(iOS)
            // Handle garden list request from Watch
            if let command = message["command"] as? String, command == "requestGardenList" {
                print("📱 [WatchConnectivity] Received requestGardenList command")
                let gardensData = self.handleGardenListRequest()
                replyHandler(["gardens": gardensData])
                return
            }

            // Handle garden selection with reply
            if let command = message["command"] as? String, command == "selectGarden" {
                self.handleSelectGarden(message)
                replyHandler(["success": true])
                return
            }
            #endif

            self.handleReceivedMessage(message)
            replyHandler(["received": true])
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.handleReceivedContext(applicationContext)
        }
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        print("📨 [WatchConnectivity] Received message with keys: \(message.keys)")

        // Handle biometric sample
        if let sampleData = message["biometricSample"] as? Data,
           let sample = try? JSONDecoder().decode(BiometricSample.self, from: sampleData) {
            latestBiometricSample = sample
            print("💓 [WatchConnectivity] Received HR: \(sample.heartRate ?? 0)")
        }

        // Handle flow score
        if let scoreData = message["flowScore"] as? Data,
           let score = try? JSONDecoder().decode(FlowScore.self, from: scoreData) {
            latestFlowScore = score
            print("🧠 [WatchConnectivity] Received flow score: \(score.total)")
        }

        // Handle commands
        if let commandString = message["command"] as? String {
            #if os(iOS)
            handleiOSCommand(commandString, message: message)
            #elseif os(watchOS)
            handleCommand(commandString, message: message)
            #endif
        }
    }

    #if os(iOS)
    private func handleiOSCommand(_ commandString: String, message: [String: Any]) {
        // Handle garden selection from Watch (custom command, not in enum)
        if commandString == "selectGarden" {
            handleSelectGarden(message)
            return
        }

        // Handle session start from Watch
        if commandString == "sessionStart" {
            handleSessionStart(message)
            return
        }

        // Handle session end from Watch
        if commandString == "sessionEnd" {
            handleSessionEnd(message)
            return
        }

        guard let command = WatchMessageCommand(rawValue: commandString) else {
            print("⚠️ [WatchConnectivity] Unknown command: \(commandString)")
            return
        }

        print("📱 [WatchConnectivity] Handling command: \(command)")

        switch command {
        case .sessionStart:
            handleSessionStart(message)
        case .sessionUpdate:
            handleSessionUpdate(message)
        case .sessionEnd:
            handleSessionEnd(message)
        case .requestBaseline:
            handleBaselineRequest()
        default:
            print("⚠️ [WatchConnectivity] Unhandled iOS command: \(command)")
        }
    }

    // MARK: - Garden Selection Handler

    private func handleSelectGarden(_ message: [String: Any]) {
        guard let gardenIdString = message["gardenId"] as? String,
              let gardenId = UUID(uuidString: gardenIdString) else {
            print("❌ [WatchConnectivity] Invalid selectGarden message - missing gardenId")
            return
        }

        print("📱 [WatchConnectivity] Received selectGarden command for: \(gardenId)")

        // Verify garden exists
        let gardens = GardenDataManager.shared.loadGardens()
        let success = gardens.first(where: { $0.id == gardenId }) != nil

        if success {
            // Post notification to update UI
            NotificationCenter.default.post(
                name: .selectGardenFromWatch,
                object: nil,
                userInfo: ["gardenId": gardenId]
            )
            print("✅ [WatchConnectivity] Garden selection successful")
        } else {
            print("❌ [WatchConnectivity] Garden not found")
        }
    }

    // MARK: - Garden List Handler

    private func handleGardenListRequest() -> [[String: Any]] {
        let gardens = GardenDataManager.shared.loadGardens()
        return gardens.map { garden in
            [
                "id": garden.id.uuidString,
                "name": garden.name,
                "icon": garden.icon,
                "plantsCount": garden.plantsCount
            ]
        }
    }

    // MARK: - Session Start Handler

    private func handleSessionStart(_ message: [String: Any]) {
        print("🚀 [WatchConnectivity] Handling session start from Watch")

        // Parse message - now expects gardenID instead of taskName for garden creation
        guard let sessionID = message["sessionID"] as? String,
              let gardenID = message["gardenID"] as? String,
              let plantDescription = message["plantDescription"] as? String,
              let targetDuration = message["targetDuration"] as? TimeInterval,
              let timestamp = message["timestamp"] as? TimeInterval else {
            print("❌ [WatchConnectivity] Invalid session start message - missing required fields")
            print("   Required: sessionID, gardenID, plantDescription, targetDuration, timestamp")
            print("   Received: \(message.keys)")
            return
        }

        // Check for duplicate session
        guard !activeWatchSessionIDs.contains(sessionID) else {
            print("⚠️ [WatchConnectivity] Session already exists: \(sessionID)")
            return
        }

        // Mark session as active
        activeWatchSessionIDs.insert(sessionID)

        // Optional fields with defaults
        let seedTypeRaw = message["seedType"] as? String ?? "oneTime"
        let plantSpeciesRaw = message["plantSpecies"] as? String ?? "oak"

        // Process in background (works even if app was closed)
        Task.detached(priority: .userInitiated) {
            do {
                try await self.createPlantFromWatch(
                    sessionID: sessionID,
                    gardenID: gardenID,
                    plantDescription: plantDescription,
                    targetDuration: targetDuration,
                    startTime: Date(timeIntervalSince1970: timestamp),
                    seedTypeRaw: seedTypeRaw,
                    plantSpeciesRaw: plantSpeciesRaw
                )
                print("✅ [WatchConnectivity] Successfully created plant from Watch")
            } catch {
                print("❌ [WatchConnectivity] Failed to create plant: \(error)")
                // Remove from active sessions on failure
                await MainActor.run {
                    _ = self.activeWatchSessionIDs.remove(sessionID)
                }
            }
        }
    }

    private func createPlantFromWatch(
        sessionID: String,
        gardenID: String,
        plantDescription: String,
        targetDuration: TimeInterval,
        startTime: Date,
        seedTypeRaw: String,
        plantSpeciesRaw: String
    ) async throws {
        print("🌱 [WatchConnectivity] Creating plant in garden: \(gardenID)")
        print("   Description: '\(plantDescription)'")

        // Parse seed type and plant species
        let seedType = SeedType(rawValue: seedTypeRaw) ?? .oneTime
        let plantSpecies = PlantSpecies(rawValue: plantSpeciesRaw) ?? .oak

        // 1. Verify garden exists (gardens are created on iPhone, not from Watch)
        guard let garden = await findGarden(byID: gardenID) else {
            print("❌ [WatchConnectivity] Garden not found: \(gardenID)")
            throw WatchConnectivityError.gardenNotFound
        }
        print("🏡 [WatchConnectivity] Garden found: '\(garden.name)' (ID: \(garden.id))")

        // 2. Create plant in garden
        let plant = await createPlant(
            in: garden,
            sessionID: sessionID,
            description: plantDescription,
            seedType: seedType,
            plantSpecies: plantSpecies
        )
        print("🌿 [WatchConnectivity] Created plant: \(plant.species.displayName)")

        // 3. Create FocusSession record
        let session = FocusSession(
            id: UUID(uuidString: sessionID) ?? UUID(),
            gardenId: garden.id,
            plantId: plant.id,
            taskDescription: plantDescription,
            seedType: seedType,
            plantSpecies: plantSpecies,
            environment: .other,
            startTime: startTime,
            endTime: nil,
            plannedDuration: targetDuration,
            actualDuration: 0,
            wasCompleted: false,
            wasAbandoned: false,
            source: .watch,
            biometrics: BiometricSessionData(),
            flowTimeline: []
        )

        // 4. Save session
        await MainActor.run {
            GardenDataManager.shared.saveSession(session)
        }

        // 5. Notify UI if app is open
        await MainActor.run {
            NotificationCenter.default.post(
                name: .watchSessionStarted,
                object: session
            )
        }

        print("✅ [WatchConnectivity] Plant created and session saved: \(sessionID)")
    }

    // MARK: - Garden Lookup (no creation - gardens are created on iPhone)

    private func findGarden(byID gardenID: String) async -> Garden? {
        let gardens = await MainActor.run {
            GardenDataManager.shared.loadGardens()
        }

        return gardens.first { $0.id.uuidString == gardenID }
    }

    private func createPlant(
        in garden: Garden,
        sessionID: String,
        description: String,
        seedType: SeedType,
        plantSpecies: PlantSpecies
    ) async -> Plant {
        let plant = Plant(
            id: UUID(),
            gardenId: garden.id,
            sessionId: UUID(uuidString: sessionID) ?? UUID(),
            species: plantSpecies,
            seedType: seedType,
            createdAt: Date(),
            health: 100.0,
            growthStage: 0,
            lastSessionDate: Date(),
            hasScar: false,
            lastWateredDate: Date()
        )

        await MainActor.run {
            GardenDataManager.shared.savePlant(plant, to: garden.id)
        }

        print("   Plant description: '\(description)'")
        return plant
    }

    // MARK: - Errors

    enum WatchConnectivityError: Error, LocalizedError {
        case gardenNotFound
        case invalidMessage

        var errorDescription: String? {
            switch self {
            case .gardenNotFound:
                return "Garden not found on iPhone. Please create a garden first."
            case .invalidMessage:
                return "Invalid message format from Watch"
            }
        }
    }

    // MARK: - Session Update Handler

    private func handleSessionUpdate(_ message: [String: Any]) {
        guard let sessionID = message["sessionID"] as? String else {
            print("⚠️ [WatchConnectivity] Session update missing sessionID")
            return
        }

        print("📊 [WatchConnectivity] Session update for: \(sessionID)")

        // Parse biometric data if present
        if let hr = message["heartRate"] as? Double,
           let hrv = message["hrv"] as? Double,
           let flowScore = message["flowScore"] as? Int,
           let flowState = message["flowState"] as? String {
            print("   HR: \(Int(hr)), HRV: \(Int(hrv)), Flow: \(flowScore) (\(flowState))")

            // TODO: Update session with latest biometric data
        }
    }

    // MARK: - Session End Handler

    private func handleSessionEnd(_ message: [String: Any]) {
        guard let sessionID = message["sessionID"] as? String else {
            print("⚠️ [WatchConnectivity] Session end missing sessionID")
            return
        }

        print("🏁 [WatchConnectivity] Session ended: \(sessionID)")

        // Remove from active sessions
        activeWatchSessionIDs.remove(sessionID)

        // Parse final data
        let actualDuration = message["actualDuration"] as? TimeInterval ?? 0
        let wasCompleted = message["wasCompleted"] as? Bool ?? false
        let peakFlowScore = message["peakFlowScore"] as? Int ?? 0
        let timeInFlow = message["timeInFlow"] as? TimeInterval ?? 0

        print("   Duration: \(Int(actualDuration))s, Completed: \(wasCompleted)")
        print("   Peak Flow: \(peakFlowScore), Time in Flow: \(Int(timeInFlow))s")

        // Notify UI
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .watchSessionEnded,
                object: nil,
                userInfo: [
                    "sessionID": sessionID,
                    "actualDuration": actualDuration,
                    "wasCompleted": wasCompleted,
                    "peakFlowScore": peakFlowScore,
                    "timeInFlow": timeInFlow
                ]
            )
        }
    }

    // MARK: - Baseline Request Handler

    private func handleBaselineRequest() {
        print("📊 [WatchConnectivity] Watch requested baseline")

        // Get baseline from HealthKit and send to Watch
        Task {
            do {
                let baseline = try await HealthKitManager.shared.calculatePersonalBaseline()
                syncBaseline(baseline)
                print("✅ [WatchConnectivity] Sent baseline to Watch")
            } catch {
                print("❌ [WatchConnectivity] Failed to calculate baseline: \(error)")
            }
        }
    }
    #endif

    private func handleReceivedContext(_ context: [String: Any]) {
        // Handle session state
        if let stateData = context["sessionState"] as? Data,
           let state = try? JSONDecoder().decode(WatchSessionState.self, from: stateData) {
            watchSessionState = state
            print("⌚ [WatchConnectivity] Session state updated: \(state.isActive)")
        }

        // Handle baseline sync
        if let baselineData = context["baseline"] as? Data {
            sharedDefaults.set(baselineData, forKey: "personalBaseline")
            print("📊 [WatchConnectivity] Baseline synced to local storage")
        }

        // Handle substance levels (watchOS side)
        #if os(watchOS)
        if let caffeine = context["activeCaffeine"] as? Double,
           let lTheanine = context["activeLTheanine"] as? Double {
            // Notify FlowScoreCalculator about substance update
            NotificationCenter.default.post(
                name: .substanceLevelsUpdated,
                object: nil,
                userInfo: ["caffeine": caffeine, "lTheanine": lTheanine]
            )
            print("💊 [WatchConnectivity] Substance levels: Caffeine=\(caffeine)mg, L-theanine=\(lTheanine)mg")
        }

        if let sleepScore = context["sleepScore"] as? Double {
            NotificationCenter.default.post(
                name: .sleepScoreUpdated,
                object: nil,
                userInfo: ["sleepScore": sleepScore]
            )
            print("😴 [WatchConnectivity] Sleep score: \(sleepScore)")
        }
        #endif
    }

    #if os(watchOS)
    private func handleCommand(_ command: String, message: [String: Any]) {
        switch command {
        case "startSession":
            let task = message["task"] as? String ?? "Focus"
            let duration = message["duration"] as? Int ?? 25
            NotificationCenter.default.post(
                name: .startSessionRequested,
                object: nil,
                userInfo: ["task": task, "duration": duration]
            )
        case "endSession":
            NotificationCenter.default.post(name: .endSessionRequested, object: nil)
        default:
            print("⚠️ [WatchConnectivity] Unknown command: \(command)")
        }
    }

    // MARK: - Garden List Request (Watch -> iPhone)

    func requestGardenList(completion: @escaping ([Garden]) -> Void) {
        guard isReachable else {
            print("❌ [Watch] iPhone not reachable for garden list")
            completion([])
            return
        }

        let message: [String: Any] = ["command": "requestGardenList"]

        session.sendMessage(message, replyHandler: { reply in
            if let gardensData = reply["gardens"] as? [[String: Any]] {
                let gardens = gardensData.compactMap { dict -> Garden? in
                    guard let idString = dict["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let name = dict["name"] as? String,
                          let icon = dict["icon"] as? String else {
                        return nil
                    }

                    // Create basic garden object for display
                    return Garden(id: id, userId: UUID(), name: name, icon: icon, createdAt: Date(), plants: [])
                }
                completion(gardens)
            } else {
                completion([])
            }
        }, errorHandler: { error in
            print("❌ [Watch] Failed to get garden list: \(error.localizedDescription)")
            completion([])
        })
    }
    #endif

    // MARK: - iOS Only Methods

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 [WatchConnectivity] Session inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 [WatchConnectivity] Session deactivated, reactivating...")
        session.activate()
    }
    #endif
}

// MARK: - Notification Names

extension Notification.Name {
    static let substanceLevelsUpdated = Notification.Name("substanceLevelsUpdated")
    static let sleepScoreUpdated = Notification.Name("sleepScoreUpdated")
    static let startSessionRequested = Notification.Name("startSessionRequested")
    static let endSessionRequested = Notification.Name("endSessionRequested")

    // Watch session notifications (iOS side)
    static let watchSessionStarted = Notification.Name("watchSessionStarted")
    static let watchSessionUpdated = Notification.Name("watchSessionUpdated")
    static let watchSessionEnded = Notification.Name("watchSessionEnded")

    // Garden selection from Watch
    static let selectGardenFromWatch = Notification.Name("SelectGardenFromWatch")
}
