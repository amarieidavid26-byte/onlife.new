import Foundation
import SwiftUI
import Combine

// MARK: - Focus Session ViewModel
/// Manages focus session state with integrated flow detection, biometrics, and gamification

class FocusSessionViewModel: ObservableObject {

    // MARK: - Session State

    @Published var isSessionActive = false
    @Published var isPaused = false
    @Published var sessionPhase: SessionPhase = .input

    // MARK: - Session Configuration

    @Published var taskDescription: String = ""
    @Published var selectedSeedType: SeedType = .oneTime
    @Published var selectedDuration: Int = 30
    @Published var selectedEnvironment: FocusEnvironment = .home
    @Published var selectedPlantSpecies: PlantSpecies = .oak
    @Published var currentGarden: Garden?

    // MARK: - Timer State

    @Published var elapsedTime: TimeInterval = 0
    @Published var plannedDuration: TimeInterval = 1800 // 30 min default

    // MARK: - Plant Growth

    @Published var plantGrowthStage: Int = 0
    @Published var plantHealth: Double = 100.0

    // MARK: - Flow Detection (NEW)

    @Published var currentFlowScore: Double = 0
    @Published var currentFlowState: UnifiedFlowAssessment.FlowState = .baseline
    @Published var flowConfidence: UnifiedFlowAssessment.ConfidenceLevel = .low

    // MARK: - Biometrics from Watch (NEW)

    @Published var currentHeartRate: Double = 0
    @Published var currentHRV: Double = 0
    @Published var isWatchConnected: Bool = false

    // MARK: - Fatigue & Warnings (NEW)

    @Published var fatigueWarning: String? = nil
    @Published var preSessionFatigueLevel: FatigueLevel.Level = .fresh

    // MARK: - Session Rewards (NEW)

    @Published var sessionReward: SessionRewardResult? = nil

    // MARK: - Private State

    private var timer: Timer?
    private var flowUpdateTimer: Timer?
    private var sessionStartTime: Date?
    private var pauseCount: Int = 0
    private var totalPauseTime: TimeInterval = 0
    private var pauseStartTime: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Algorithm Engines (NEW)

    private let fusionEngine = MultiModalFusionEngine.shared
    private let gamificationEngine = GamificationEngine.shared
    private let fatigueEngine = FatigueDetectionEngine.shared
    private let watchBridge = WatchDataBridge.shared
    private let sleepCalculator = SleepQualityIndexCalculator.shared
    private let pharmacoEngine = CorrectedPharmacokineticsEngine.shared
    private let behavioralCollector = BehavioralFeatureCollector.shared

    // MARK: - Flow Score History (for averaging)

    private var flowScoreHistory: [Double] = []

    // MARK: - Initialization

    init() {
        setupWatchDataSubscription()
        setupConnectionStatusSubscription()
    }

    // MARK: - Watch Data Subscription

    private func setupWatchDataSubscription() {
        // Subscribe to real-time biometric data from Watch
        watchBridge.biometricDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                guard let self = self else { return }
                self.currentHeartRate = data.heartRate

                // Update HRV if available
                if let rmssd = data.bestRMSSD {
                    self.currentHRV = rmssd
                }

                // Trigger flow update when new data arrives
                if self.isSessionActive && !self.isPaused {
                    self.updateFlowScore()
                }
            }
            .store(in: &cancellables)
    }

    private func setupConnectionStatusSubscription() {
        watchBridge.$isWatchConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWatchConnected)

        watchBridge.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isWatchConnected = status.isUsable
            }
            .store(in: &cancellables)
    }

    // MARK: - Session Lifecycle

    func startSession() {
        sessionPhase = .planting

        // Check fatigue before starting
        checkPreSessionFatigue()

        // Play seed planting sequence
        AudioManager.shared.play(.seedMorph, volume: 0.7)
        HapticManager.shared.seedPlantingSequence()

        // After 3.5 seconds, start focus mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            self.beginFocusMode()
        }
    }

    func beginFocusMode() {
        sessionPhase = .focusing
        isSessionActive = true
        sessionStartTime = Date()
        plannedDuration = TimeInterval(selectedDuration * 60)
        pauseCount = 0
        totalPauseTime = 0
        flowScoreHistory = []

        AudioManager.shared.play(.growthTick, volume: 0.4)

        // Start Watch session for biometrics
        watchBridge.startWatchSession(duration: plannedDuration)

        // Clear previous history for fresh behavioral tracking
        watchBridge.clearHistory()

        // Start timers
        startTimer()
        startFlowDetection()

        print("🎯 [Session] Started - Duration: \(selectedDuration)min, Watch: \(isWatchConnected ? "Connected" : "Not Connected")")
    }

    // MARK: - Pre-Session Fatigue Check

    private func checkPreSessionFatigue() {
        // Get session history for fatigue assessment
        let sessionHistory = GardenDataManager.shared.loadSessions()

        // Use default baseline (BehavioralFlowScoreCalculator manages baselines)
        let baseline = UserBehavioralBaseline.default

        let fatigueCheck = fatigueEngine.preSessionCheck(
            sessionHistory: sessionHistory,
            baseline: baseline
        )

        // Get current fatigue level for display
        if let currentFatigue = fatigueEngine.currentFatigueLevel {
            preSessionFatigueLevel = currentFatigue.level

            if currentFatigue.shouldWarn {
                fatigueWarning = currentFatigue.recommendation
                print("⚠️ [Fatigue] Warning: \(currentFatigue.recommendation)")
            } else {
                fatigueWarning = nil
            }
        } else if !fatigueCheck.canProceed {
            // Use pre-session check warning if fatigue level not available
            fatigueWarning = fatigueCheck.warning
            preSessionFatigueLevel = .moderate
        } else {
            fatigueWarning = fatigueCheck.warning
            preSessionFatigueLevel = .fresh
        }
    }

    // MARK: - Flow Detection

    private func startFlowDetection() {
        // Update flow score every 30 seconds
        flowUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.updateFlowScore()
        }

        // Initial update
        updateFlowScore()
    }

    private func updateFlowScore() {
        // Use the behavioral collector's current features (it manages session state)
        let behavioralFeatures = behavioralCollector.currentFeatures

        // Get latest HRV metrics from Watch (if available)
        let hrvMetrics: HRVMetrics? = currentHRV > 0 ? createHRVMetrics() : nil

        // Get sleep quality from last night
        let sleepQuality = getLastNightSleepQuality()

        // Get active substances
        let substances = getActiveSubstances()

        // Get session history for contextual assessment
        let sessionHistory = GardenDataManager.shared.loadSessions()

        // Calculate unified flow score
        let assessment = fusionEngine.calculateUnifiedFlowScore(
            behavioralFeatures: behavioralFeatures,
            hrvMetrics: hrvMetrics,
            currentHR: currentHeartRate > 0 ? currentHeartRate : nil,
            sleepQuality: sleepQuality,
            activeSubstances: substances,
            sessionHistory: sessionHistory
        )

        // Update published properties
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentFlowScore = assessment.score
            self.currentFlowState = assessment.state
            self.flowConfidence = assessment.confidence

            // Add to history for averaging
            self.flowScoreHistory.append(assessment.score)

            // Adjust plant health based on flow
            self.adjustPlantHealthForFlow(assessment.score)
        }

        print("🧠 [Flow] Score: \(String(format: "%.1f", assessment.score)), State: \(assessment.state.rawValue), Confidence: \(assessment.confidence.rawValue)")
    }

    private func createHRVMetrics() -> HRVMetrics {
        // Approximate SDNN from RMSSD (r ≈ 0.90 at rest, SDNN ≈ RMSSD / 1.4)
        let estimatedSDNN = currentHRV / 1.4
        let estimatedMeanRR = 60000 / currentHeartRate  // Convert HR to RR in ms

        return HRVMetrics(
            rmssd: currentHRV,
            sdnn: estimatedSDNN,
            pnn50: 0,
            meanRR: estimatedMeanRR,
            meanHR: currentHeartRate,
            sdsd: 0,
            nn50: 0,
            lfPower: nil,
            hfPower: nil,
            lfHfRatio: nil,
            totalPower: nil,
            vlfPower: nil,
            lfNu: nil,
            hfNu: nil,
            sampleCount: 30,
            artifactCount: 0,
            artifactPercentage: 0,
            windowDuration: 60,
            isValid: true,
            timestamp: Date()
        )
    }

    /// Syncs current session state to the behavioral collector
    private func syncBehavioralState() {
        // The behavioral collector manages its own state via startSession/pauseSession/resumeSession
        // Update session-specific metrics here if needed
        var features = behavioralCollector.currentFeatures
        features.sessionDuration = elapsedTime
        features.pauseCount = pauseCount
        features.pauseTotalDuration = totalPauseTime
        features.sessionCountToday = getSessionCountToday()
    }

    private func getActiveSubstances() -> [String: Double]? {
        let caffeine = pharmacoEngine.calculateActiveLevel(for: .caffeine)
        let lTheanine = pharmacoEngine.calculateActiveLevel(for: .lTheanine)

        guard caffeine > 0 || lTheanine > 0 else { return nil }

        var substances: [String: Double] = [:]
        if caffeine > 0 { substances["caffeine"] = caffeine }
        if lTheanine > 0 { substances["lTheanine"] = lTheanine }

        return substances
    }

    private func getLastNightSleepQuality() -> Double? {
        // Return cached SQI if available
        // In a real implementation, this would query HealthKit
        return nil
    }

    private func adjustPlantHealthForFlow(_ flowScore: Double) {
        // Plant thrives with high flow, suffers with low flow
        if flowScore >= 70 {
            plantHealth = min(100, plantHealth + 0.5)
        } else if flowScore < 40 {
            plantHealth = max(50, plantHealth - 0.2)
        }
    }

    // MARK: - Pause/Resume

    func pauseSession() {
        isPaused = true
        pauseCount += 1
        pauseStartTime = Date()
        timer?.invalidate()
        timer = nil
        HapticManager.shared.impact(style: .medium)

        print("⏸️ [Session] Paused (count: \(pauseCount))")
    }

    func resumeSession() {
        isPaused = false

        // Track pause duration
        if let pauseStart = pauseStartTime {
            totalPauseTime += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil

        startTimer()
        HapticManager.shared.impact(style: .medium)

        print("▶️ [Session] Resumed")
    }

    // MARK: - End Session

    func endSession() {
        timer?.invalidate()
        timer = nil
        flowUpdateTimer?.invalidate()
        flowUpdateTimer = nil

        // Stop Watch session
        watchBridge.stopWatchSession()

        if elapsedTime >= plannedDuration * 0.8 {
            // Session was successful
            sessionPhase = .completed
            AudioManager.shared.play(.bloom, volume: 0.8)
            HapticManager.shared.notification(type: .success)

            // Process rewards
            processSessionRewards(completed: true)
        } else {
            // Session was abandoned
            sessionPhase = .abandoned
            AudioManager.shared.play(.warning, volume: 0.6)
            HapticManager.shared.notification(type: .warning)

            // Partial rewards
            processSessionRewards(completed: false)
        }
    }

    func completeSession() {
        print("🔥 completeSession() called")
        print("🔥 sessionPhase before: \(sessionPhase)")
        print("🔥 currentGarden: \(String(describing: currentGarden))")

        sessionPhase = .completed
        savePlantToGarden()
        endSession()
    }

    // MARK: - Gamification Rewards

    private func processSessionRewards(completed: Bool) {
        // Calculate average flow score
        let avgFlowScore = flowScoreHistory.isEmpty ? 50.0 :
            flowScoreHistory.reduce(0, +) / Double(flowScoreHistory.count)

        // Calculate reward
        let reward = gamificationEngine.calculateSessionReward(
            sessionDuration: elapsedTime,
            flowScore: avgFlowScore,
            completed: completed
        )

        // Store reward for display
        sessionReward = SessionRewardResult(
            baseOrbs: reward.baseReward,
            bonusOrbs: reward.bonusReward,
            totalOrbs: reward.totalOrbs,
            specialRewards: reward.specialRewards,
            showCelebration: reward.showCelebration,
            celebrationMessage: reward.celebrationMessage
        )

        // Update streak if completed
        if completed {
            let streakResult = gamificationEngine.updateStreak(completedToday: true)
            print("🔥 [Gamification] Streak: \(streakResult.currentStreak) days")
        }

        print("🎁 [Gamification] Reward: \(reward.totalOrbs) orbs (base: \(reward.baseReward), bonus: \(reward.bonusReward))")
    }

    // MARK: - Save Plant

    func savePlantToGarden() {
        print("🌱 savePlantToGarden() called")
        print("🌱 currentGarden: \(String(describing: currentGarden))")

        guard let garden = currentGarden else {
            print("❌ No garden selected!")
            return
        }

        print("✅ Garden found: \(garden.name)")

        var plant = Plant(
            id: UUID(),
            gardenId: garden.id,
            sessionId: UUID(),
            species: selectedPlantSpecies,
            seedType: selectedSeedType,
            createdAt: Date(),
            health: plantHealth,
            growthStage: plantGrowthStage,
            lastSessionDate: Date(),
            hasScar: false,
            lastWateredDate: Date()
        )

        // If plant is recurring, mark it as watered
        if plant.seedType == .recurring {
            plant.water()
            print("💧 Recurring plant watered on creation")
        }

        print("🌱 Created plant: \(plant.species.rawValue) (\(plant.seedType.rawValue))")

        GardenDataManager.shared.savePlant(plant, to: garden.id)
        print("✅ Plant saved to garden: \(garden.name)")

        // Calculate average flow score
        let avgFlowScore = flowScoreHistory.isEmpty ? 50 :
            Int(flowScoreHistory.reduce(0, +) / Double(flowScoreHistory.count))

        // Create biometric session data if available
        var biometrics: BiometricSessionData? = nil
        if currentHeartRate > 0 || currentHRV > 0 || !flowScoreHistory.isEmpty {
            biometrics = BiometricSessionData(
                averageHR: currentHeartRate,
                peakHR: currentHeartRate,  // Would need tracking for accurate peak
                minimumHR: currentHeartRate,
                averageHRV: currentHRV,
                peakHRV: currentHRV,
                averageFlowScore: avgFlowScore,
                peakFlowScore: Int(flowScoreHistory.max() ?? 0),
                timeInFlowState: 0  // Would need tracking
            )
        }

        // Save the focus session with flow data
        let session = FocusSession(
            gardenId: garden.id,
            plantId: plant.id,
            taskDescription: taskDescription,
            seedType: selectedSeedType,
            plantSpecies: selectedPlantSpecies,
            environment: selectedEnvironment,
            startTime: sessionStartTime ?? Date(),
            endTime: Date(),
            plannedDuration: plannedDuration,
            actualDuration: elapsedTime,
            wasCompleted: true,
            wasAbandoned: false,
            pauseCount: pauseCount,
            totalPauseTime: totalPauseTime,
            growthStageAchieved: plantGrowthStage,
            biometrics: biometrics
        )

        GardenDataManager.shared.saveSession(session)
        print("⏱️ Session saved: \(session.taskDescription), Flow: \(avgFlowScore)%")
    }

    // MARK: - Reset

    func resetSession() {
        sessionPhase = .input
        isSessionActive = false
        isPaused = false
        elapsedTime = 0
        taskDescription = ""
        plantGrowthStage = 0
        plantHealth = 100.0
        currentFlowScore = 0
        currentFlowState = UnifiedFlowAssessment.FlowState.baseline
        flowConfidence = UnifiedFlowAssessment.ConfidenceLevel.low
        fatigueWarning = nil
        sessionReward = nil
        flowScoreHistory = []
        pauseCount = 0
        totalPauseTime = 0

        timer?.invalidate()
        timer = nil
        flowUpdateTimer?.invalidate()
        flowUpdateTimer = nil
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSession()
        }
    }

    private func updateSession() {
        elapsedTime += 1

        // Update plant growth (grows every 30 seconds)
        if Int(elapsedTime) % 30 == 0 {
            plantGrowthStage = min(plantGrowthStage + 1, 10)
            AudioManager.shared.play(.growthTick, volume: 0.3)
        }

        // Auto-complete when time is up
        if elapsedTime >= plannedDuration {
            completeSession()
        }
    }

    // MARK: - Computed Properties

    var progress: Double {
        guard plannedDuration > 0 else { return 0 }
        return min(elapsedTime / plannedDuration, 1.0)
    }

    var remainingTime: TimeInterval {
        max(0, plannedDuration - elapsedTime)
    }

    var timeString: String {
        let time = isPaused ? elapsedTime : remainingTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var averageFlowScore: Double {
        guard !flowScoreHistory.isEmpty else { return 0 }
        return flowScoreHistory.reduce(0, +) / Double(flowScoreHistory.count)
    }

    // MARK: - Helper Methods

    private func calculateHistoricalCompletionRate() -> Double {
        // TODO: Query from session history
        return 0.75 // Default 75%
    }

    private func getMinutesSinceLastSession() -> TimeInterval {
        // TODO: Query from session history
        return 120 // Default 2 hours
    }

    private func getSessionCountToday() -> Int {
        // TODO: Query from session history
        return 1
    }

    private func getHoursSinceLastSession() -> Double {
        return getMinutesSinceLastSession() / 60
    }

    private func getRecentSessionDurations() -> [TimeInterval] {
        // TODO: Query from session history
        return [25 * 60, 30 * 60]
    }
}

// MARK: - Session Phase

enum SessionPhase {
    case input           // Task input modal
    case planting        // Seed planting animation
    case focusing        // Active focus session
    case completed       // Session completed successfully
    case abandoned       // Session abandoned early
}

// MARK: - Session Reward Result

struct SessionRewardResult {
    let baseOrbs: Int
    let bonusOrbs: Int
    let totalOrbs: Int
    let specialRewards: [RewardType]
    let showCelebration: Bool
    let celebrationMessage: String?

    var hasBonus: Bool {
        return bonusOrbs > 0
    }
}

