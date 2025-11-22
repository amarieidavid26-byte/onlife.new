import Foundation
import Combine
import UIKit

/// Service for tracking substance intake and calculating active levels in real-time
/// Uses pharmacokinetic modeling to estimate current active amounts based on half-life decay
class SubstanceTracker: ObservableObject {
    static let shared = SubstanceTracker()

    // MARK: - Published Properties

    /// All substance logs (persisted to UserDefaults)
    @Published var logs: [SubstanceLog] = []

    /// Current active levels for each substance type (updated every minute)
    /// Values represent estimated active amount in original units (mg/ml)
    @Published var activeLevels: [SubstanceType: Double] = [:]

    // MARK: - Private Properties

    private let logsKey = "substance_logs"
    private var updateTimer: Timer?
    private let profileManager = MetabolismProfileManager.shared

    // MARK: - Initialization

    private init() {
        loadLogs()
        startActiveTracking()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Quick log a substance with default amount
    /// - Parameter type: The substance type to log
    func quickLog(_ type: SubstanceType) {
        let unit: MeasurementUnit
        switch type {
        case .caffeine, .lTheanine:
            unit = .mg
        case .water:
            unit = .ml
        }

        let log = SubstanceLog(
            timestamp: Date(),
            substanceType: type,
            amount: type.defaultAmount,
            unit: unit,
            source: nil
        )

        logs.append(log)
        saveLogs()
        updateActiveLevels()

        #if DEBUG
        print("📝 Logged: \(type.rawValue) \(type.defaultAmount)\(unit.rawValue) at \(log.timestamp.formatted(date: .omitted, time: .shortened))")
        #endif

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    /// Log a substance with custom amount and optional source
    /// - Parameters:
    ///   - type: The substance type
    ///   - amount: Custom amount
    ///   - source: Optional source description (e.g., "Starbucks Cold Brew")
    func log(_ type: SubstanceType, amount: Double, source: String?) {
        let unit: MeasurementUnit
        switch type {
        case .caffeine, .lTheanine:
            unit = .mg
        case .water:
            unit = .ml
        }

        let log = SubstanceLog(
            timestamp: Date(),
            substanceType: type,
            amount: amount,
            unit: unit,
            source: source
        )

        logs.append(log)
        saveLogs()
        updateActiveLevels()

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    /// Updates active levels for all substance types based on pharmacokinetic decay
    /// Uses personalized metabolism profile for accurate calculations
    func updateActiveLevels() {
        let now = Date()
        let parameters = profileManager.getPersonalizedParameters()

        #if DEBUG
        var debugOutput: [String] = []
        #endif

        for type in SubstanceType.allCases {
            let relevantLogs = logs.filter {
                $0.substanceType == type &&
                now.timeIntervalSince($0.timestamp) < (getPersonalizedHalfLife(for: type, parameters: parameters) * 5)
            }

            let totalActive = relevantLogs.reduce(0.0) { sum, log in
                sum + calculatePersonalizedActiveAmount(
                    log: log,
                    at: now,
                    parameters: parameters
                )
            }

            activeLevels[type] = totalActive

            #if DEBUG
            if totalActive > 1.0 {
                debugOutput.append("\(type.rawValue): \(String(format: "%.1f", totalActive))\(type == .water ? "ml" : "mg")")
            }
            #endif
        }

        #if DEBUG
        if !debugOutput.isEmpty {
            print("📊 Active Levels: \(debugOutput.joined(separator: " | "))")
        }
        #endif
    }

    /// Calculates synergistic effect between caffeine and L-theanine
    ///
    /// Research shows L-theanine enhances caffeine's cognitive benefits while reducing jitters.
    /// The combination is particularly effective for sustained focus and reduced anxiety.
    ///
    /// **Mechanism**: L-theanine increases alpha brain wave activity, promoting relaxation
    /// without drowsiness, while caffeine blocks adenosine receptors for alertness.
    /// Together they provide "calm focus" superior to either substance alone.
    ///
    /// **Research References**:
    /// - Haskell et al. (2008): Improved accuracy and alertness in cognitive tasks
    /// - Foxe et al. (2012): Enhanced attention and reduced susceptibility to distraction
    ///
    /// - Returns: Synergy multiplier (1.15 if both active, 1.0 otherwise)
    func calculateSynergy() -> Double {
        let caffeineLevel = activeLevels[.caffeine] ?? 0
        let theanineLevel = activeLevels[.lTheanine] ?? 0

        // Both substances must have meaningful active levels (>10 units)
        if caffeineLevel > 10 && theanineLevel > 10 {
            // 15% synergistic boost based on research showing improved focus
            // and reduced anxiety when combined
            return 1.15
        }

        return 1.0
    }

    /// Get current active caffeine level
    /// - Returns: Active caffeine in mg
    func getActiveCaffeine() -> Double {
        return activeLevels[.caffeine] ?? 0
    }

    /// Get all logs from today
    /// - Returns: Array of today's logs, sorted by timestamp (most recent first)
    func getTodayLogs() -> [SubstanceLog] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        return logs
            .filter { $0.timestamp >= startOfToday }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Private Methods

    /// Get personalized half-life for a substance type
    private func getPersonalizedHalfLife(
        for type: SubstanceType,
        parameters: PersonalizedSubstanceParameters
    ) -> TimeInterval {
        switch type {
        case .caffeine:
            return parameters.caffeineHalfLife
        case .lTheanine:
            return parameters.lTheanineHalfLife
        case .water:
            return parameters.waterHalfLife
        }
    }

    /// Calculate personalized active amount for a log using user's metabolism profile
    private func calculatePersonalizedActiveAmount(
        log: SubstanceLog,
        at time: Date,
        parameters: PersonalizedSubstanceParameters
    ) -> Double {
        let elapsed = time.timeIntervalSince(log.timestamp)
        guard elapsed >= log.onsetTime else { return 0 }

        // Get personalized half-life for this substance
        let personalizedHalfLife = getPersonalizedHalfLife(
            for: log.substanceType,
            parameters: parameters
        )

        // Rising to peak (linear)
        if elapsed < log.peakTime {
            let riseProgress = (elapsed - log.onsetTime) / (log.peakTime - log.onsetTime)
            return log.amount * riseProgress
        }

        // After peak (exponential decay with personalized half-life)
        let decayTime = elapsed - log.peakTime
        let halfLives = decayTime / personalizedHalfLife
        return log.amount * pow(0.5, halfLives)
    }

    /// Starts background timer to update active levels every minute
    private func startActiveTracking() {
        // Update immediately
        updateActiveLevels()

        // Schedule timer for regular updates (every 60 seconds)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateActiveLevels()
        }
    }

    /// Loads persisted logs from UserDefaults
    /// Filters to keep only last 7 days of data to prevent unbounded growth
    private func loadLogs() {
        guard let data = UserDefaults.standard.data(forKey: logsKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            let allLogs = try decoder.decode([SubstanceLog].self, from: data)

            // Keep only last 7 days of data
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
            logs = allLogs.filter { $0.timestamp >= sevenDaysAgo }

            // Update active levels based on loaded logs
            updateActiveLevels()
        } catch {
            print("⚠️ Failed to load substance logs: \(error.localizedDescription)")
            logs = []
        }
    }

    /// Persists current logs to UserDefaults
    private func saveLogs() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(logs)
            UserDefaults.standard.set(data, forKey: logsKey)
        } catch {
            print("⚠️ Failed to save substance logs: \(error.localizedDescription)")
        }
    }

    // MARK: - Debug Testing

    #if DEBUG
    func testPharmacokinetics() {
        let parameters = profileManager.getPersonalizedParameters()

        print("\n🧪 === Testing Personalized Pharmacokinetics ===")
        print("👤 Profile: \(profileManager.profile.metabolismSpeed.rawValue) metabolizer")
        print("⚖️  Weight: \(Int(profileManager.profile.weight))kg")
        print("☕ Caffeine tolerance: \(profileManager.profile.caffeineToleranceLevel.rawValue)")
        print("")

        // Test caffeine
        let caffeineLog = SubstanceLog(
            timestamp: Date().addingTimeInterval(-60 * 60),
            substanceType: .caffeine,
            amount: 95,
            unit: .mg,
            source: "Test"
        )

        let personalizedActive = calculatePersonalizedActiveAmount(
            log: caffeineLog,
            at: Date(),
            parameters: parameters
        )

        let standardActive = caffeineLog.activeAmount(at: Date())

        print("☕ Caffeine after 1 hour:")
        print("   Personalized: \(String(format: "%.1f", personalizedActive))mg")
        print("   Standard: \(String(format: "%.1f", standardActive))mg")
        print("   Your half-life: \(formatDuration(parameters.caffeineHalfLife))")
        print("   Standard half-life: 5h")
        print("")

        // Test L-theanine
        let theanineLog = SubstanceLog(
            timestamp: Date().addingTimeInterval(-40 * 60),
            substanceType: .lTheanine,
            amount: 200,
            unit: .mg,
            source: "Test"
        )

        let theaninePersonalized = calculatePersonalizedActiveAmount(
            log: theanineLog,
            at: Date(),
            parameters: parameters
        )

        let theanineStandard = theanineLog.activeAmount(at: Date())

        print("🍃 L-theanine after 40 min:")
        print("   Personalized: \(String(format: "%.1f", theaninePersonalized))mg")
        print("   Standard: \(String(format: "%.1f", theanineStandard))mg")
        print("   Your half-life: \(formatDuration(parameters.lTheanineHalfLife))")
        print("   Standard half-life: 40m")
        print("")

        print("💊 Daily caffeine limit: \(Int(parameters.dailyCaffeineLimit))mg")
        print("🧬 Estimated CYP1A2: \(profileManager.profile.cyp1a2Genotype.rawValue)")
        print("=== Test Complete ===\n")
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
    #endif
}
