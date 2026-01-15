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
        print("💊 [SubstanceTracker] Initializing singleton...")
        loadLogs()
        startActiveTracking()
        print("💊 [SubstanceTracker] Init complete. Loaded \(logs.count) logs.")
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

        // Sync to Apple Watch
        syncToWatch()

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
        print("💊 [SubstanceTracker] log() called: \(type.rawValue) \(amount)\(type == .water ? "ml" : "mg") from: \(source ?? "unknown")")

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

        print("💊 [SubstanceTracker] Log created: id=\(log.id), timestamp=\(log.timestamp)")

        logs.append(log)
        print("💊 [SubstanceTracker] Total logs now: \(logs.count)")

        saveLogs()
        updateActiveLevels()

        // Sync to Apple Watch
        syncToWatch()

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    /// Updates active levels for all substance types based on pharmacokinetic decay
    /// Uses personalized metabolism profile for accurate calculations
    func updateActiveLevels() {
        let now = Date()
        let parameters = profileManager.getPersonalizedParameters()

        print("📊 [SubstanceTracker] updateActiveLevels() called with \(logs.count) total logs")

        for type in SubstanceType.allCases {
            let relevantLogs = logs.filter {
                $0.substanceType == type &&
                now.timeIntervalSince($0.timestamp) < (getPersonalizedHalfLife(for: type, parameters: parameters) * 5)
            }

            let totalActive = relevantLogs.reduce(0.0) { sum, log in
                let activeAmount = calculatePersonalizedActiveAmount(
                    log: log,
                    at: now,
                    parameters: parameters
                )
                return sum + activeAmount
            }

            let oldValue = activeLevels[type] ?? 0
            activeLevels[type] = totalActive

            // Always log changes for debugging
            if totalActive != oldValue || totalActive > 0 {
                print("📊 [SubstanceTracker] \(type.rawValue): \(String(format: "%.1f", totalActive))\(type == .water ? "ml" : "mg") (from \(relevantLogs.count) logs)")
            }
        }

        // Force UI update by triggering objectWillChange
        objectWillChange.send()

        print("📊 [SubstanceTracker] Active levels updated: Caffeine=\(String(format: "%.1f", activeLevels[.caffeine] ?? 0))mg, L-theanine=\(String(format: "%.1f", activeLevels[.lTheanine] ?? 0))mg, Water=\(String(format: "%.0f", activeLevels[.water] ?? 0))ml")
    }

    /// Calculates synergistic effect between caffeine and L-theanine
    ///
    /// EVIDENCE-BASED THRESHOLDS (Owen 2008, Giesbrecht 2010, Kelly 2008):
    /// - Minimum effective doses: 50mg caffeine + 100mg L-theanine
    /// - Optimal ratio: 1:2 (caffeine:L-theanine)
    /// - Studies report Cohen's d ≈ 1.0 (large effect size)
    ///
    /// **Mechanism**: L-theanine increases alpha brain wave activity, promoting relaxation
    /// without drowsiness, while caffeine blocks adenosine receptors for alertness.
    /// Together they provide "calm focus" superior to either substance alone.
    ///
    /// CORRECTED: Previous threshold of >10mg had no scientific basis
    ///
    /// - Returns: Synergy multiplier (1.15 if both at effective doses, 1.0 otherwise)
    func calculateSynergy() -> Double {
        let caffeineLevel = activeLevels[.caffeine] ?? 0
        let theanineLevel = activeLevels[.lTheanine] ?? 0

        print("☯️ [SubstanceTracker] Synergy check: Caffeine=\(String(format: "%.1f", caffeineLevel))mg, L-theanine=\(String(format: "%.1f", theanineLevel))mg")

        // CORRECTED: Minimum effective doses from peer-reviewed RCTs
        // Previous >10mg threshold had no scientific basis
        let meetsMinimumDose = caffeineLevel >= 50.0 && theanineLevel >= 100.0
        print("☯️ [SubstanceTracker] Meets minimum dose (≥50mg caffeine + ≥100mg L-theanine): \(meetsMinimumDose)")

        // Optimal ratio: 1:2 (caffeine:L-theanine) ± tolerance
        let ratio = theanineLevel / max(caffeineLevel, 1.0)
        let isOptimalRatio = ratio >= 1.5 && ratio <= 2.5  // 1:2 ± 0.5
        print("☯️ [SubstanceTracker] Ratio: \(String(format: "%.2f", ratio)), Optimal (1.5-2.5): \(isOptimalRatio)")

        if meetsMinimumDose && isOptimalRatio {
            // Studies report Cohen's d ≈ 1.0 (large effect)
            // Representing as qualitative boost
            print("☯️ [SubstanceTracker] ✅ SYNERGY ACTIVE - 15% boost!")
            return 1.15
        }

        // Partial synergy if minimum doses met but ratio is off
        if meetsMinimumDose {
            print("☯️ [SubstanceTracker] ⚡ Partial synergy - 8% boost (suboptimal ratio)")
            return 1.08
        }

        print("☯️ [SubstanceTracker] ❌ No synergy (thresholds not met)")
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

    /// Get total caffeine consumed today
    /// - Returns: Total caffeine in mg from all today's logs
    func getTodaysTotalCaffeine() -> Double {
        let todayLogs = getTodayLogs()
        return todayLogs
            .filter { $0.substanceType == .caffeine }
            .reduce(0.0) { $0 + $1.amount }
    }

    // MARK: - Warning System

    /// Caffeine intake warning levels based on evidence-based thresholds
    /// Sources: EFSA 2015, AAP, ACOG/WHO
    enum CaffeineWarningLevel: String {
        case safe       // Below recommended limit
        case caution    // 100-125% of limit
        case warning    // 125-150% of limit
        case danger     // 150-200% of limit
        case emergency  // >200% of limit (potential toxicity)

        var color: String {
            switch self {
            case .safe: return "green"
            case .caution: return "yellow"
            case .warning: return "orange"
            case .danger: return "red"
            case .emergency: return "purple"
            }
        }

        var icon: String {
            switch self {
            case .safe: return "checkmark.circle.fill"
            case .caution: return "exclamationmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .danger: return "xmark.octagon.fill"
            case .emergency: return "staroflife.fill"
            }
        }
    }

    /// Get current caffeine warning level based on today's intake
    /// Uses personalized daily limit from metabolism profile
    func getCaffeineWarningLevel() -> CaffeineWarningLevel {
        let todaysCaffeine = getTodaysTotalCaffeine()
        let dailyLimit = profileManager.profile.recommendedDailyCaffeineLimit

        let percentage = todaysCaffeine / dailyLimit

        if percentage > 2.0 {
            return .emergency
        } else if percentage > 1.5 {
            return .danger
        } else if percentage > 1.25 {
            return .warning
        } else if percentage > 1.0 {
            return .caution
        } else {
            return .safe
        }
    }

    /// Get warning message for current caffeine level
    /// - Returns: Warning message string, or nil if safe
    func getWarningMessage() -> String? {
        let level = getCaffeineWarningLevel()
        let profile = profileManager.profile

        switch level {
        case .safe:
            return nil
        case .caution:
            return "⚠️ You've exceeded your recommended daily limit. Consider reducing caffeine intake."
        case .warning:
            return "⚠️ High caffeine intake detected. You may experience anxiety, jitters, or sleep disruption."
        case .danger:
            return "🔴 Very high caffeine levels. Risk of adverse effects. Avoid additional caffeine today."
        case .emergency:
            var message = "🚨 DANGEROUS caffeine levels detected."
            if profile.isPregnant {
                message += " Pregnant individuals should not exceed 200mg/day."
            }
            if profile.age < 18 {
                message += " Adolescents should not exceed 100mg/day."
            }
            message += " If experiencing rapid heart rate, tremors, or confusion, seek medical attention."
            return message
        }
    }

    /// Get all active health warnings (combines profile warnings + intake warnings)
    func getAllWarnings() -> [String] {
        var warnings = profileManager.profile.getCaffeineWarnings()

        if let intakeWarning = getWarningMessage() {
            warnings.insert(intakeWarning, at: 0)
        }

        return warnings
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

        // For immediate feedback, show partial amount even before onset
        // This prevents the "nothing shows up for 12+ minutes" UX issue
        if elapsed < 0 {
            return 0  // Future log (shouldn't happen)
        }

        // Get personalized half-life for this substance
        let personalizedHalfLife = getPersonalizedHalfLife(
            for: log.substanceType,
            parameters: parameters
        )

        // Pre-onset: Show absorption progress (0% to 50% of amount)
        if elapsed < log.onsetTime {
            let absorptionProgress = elapsed / log.onsetTime
            return log.amount * absorptionProgress * 0.5  // Max 50% before onset
        }

        // Rising to peak (linear from 50% to 100%)
        if elapsed < log.peakTime {
            let riseProgress = (elapsed - log.onsetTime) / (log.peakTime - log.onsetTime)
            return log.amount * (0.5 + riseProgress * 0.5)  // 50% to 100%
        }

        // After peak (exponential decay with personalized half-life)
        let decayTime = elapsed - log.peakTime
        let halfLives = decayTime / personalizedHalfLife
        return log.amount * pow(0.5, halfLives)
    }

    /// Starts background timer to update active levels every minute
    private func startActiveTracking() {
        print("⏰ [SubstanceTracker] startActiveTracking() called")

        // Update immediately
        updateActiveLevels()

        // Schedule timer for regular updates (every 60 seconds)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            print("⏰ [SubstanceTracker] Timer fired - updating active levels")
            self?.updateActiveLevels()
        }

        // Ensure timer runs on main run loop
        if let timer = updateTimer {
            RunLoop.main.add(timer, forMode: .common)
            print("⏰ [SubstanceTracker] Timer scheduled on main run loop")
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
            print("💾 [SubstanceTracker] Saved \(logs.count) logs to UserDefaults")
        } catch {
            print("⚠️ [SubstanceTracker] Failed to save substance logs: \(error.localizedDescription)")
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

    // MARK: - Apple Watch Sync

    /// Get current active substance levels for Watch sync
    /// - Returns: Tuple of (caffeine, lTheanine) in mg
    func getActiveLevelsForWatch() -> (caffeine: Double, lTheanine: Double) {
        return (activeLevels[.caffeine] ?? 0, activeLevels[.lTheanine] ?? 0)
    }

    /// Sync current substance levels to Apple Watch
    /// Call this after logging new substances or periodically during active sessions
    func syncToWatch() {
        let levels = getActiveLevelsForWatch()
        WatchConnectivityManager.shared.syncSubstanceLevels(
            caffeine: levels.caffeine,
            lTheanine: levels.lTheanine
        )
        print("⌚ [SubstanceTracker] Synced to Watch: Caffeine=\(String(format: "%.1f", levels.caffeine))mg, L-theanine=\(String(format: "%.1f", levels.lTheanine))mg")
    }
}
