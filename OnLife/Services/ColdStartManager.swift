import Foundation
import Combine

// MARK: - Cold Start Manager
/// Handles new users without historical data by providing reasonable defaults
/// and gradually transitioning to personalized baselines.
/// Research: Cold-start transfer learning can achieve 70% hit rate with new users.
class ColdStartManager: ObservableObject {
    static let shared = ColdStartManager()

    @Published var calibrationProgress: CalibrationProgress?
    @Published var hasCompletedOnboarding: Bool = false

    private let onboardingCompletedKey = "onlife_onboarding_completed"
    private let assessmentKey = "onlife_onboarding_assessment"

    // Population baselines by age bracket (from research)
    private let populationBaselines: [AgeRange: PopulationBaseline] = [
        .young: PopulationBaseline(     // 18-25
            avgSessionDuration: 25 * 60,
            avgCompletionRate: 0.65,
            chronotypeBias: .moderateEvening,  // Young skew evening
            avgRMSSD: 45,
            sleepNeed: 8.5
        ),
        .youngAdult: PopulationBaseline( // 26-35
            avgSessionDuration: 30 * 60,
            avgCompletionRate: 0.70,
            chronotypeBias: .intermediate,
            avgRMSSD: 40,
            sleepNeed: 8.0
        ),
        .adult: PopulationBaseline(      // 36-50
            avgSessionDuration: 35 * 60,
            avgCompletionRate: 0.75,
            chronotypeBias: .moderateMorning,
            avgRMSSD: 35,
            sleepNeed: 7.5
        ),
        .olderAdult: PopulationBaseline( // 51+
            avgSessionDuration: 30 * 60,
            avgCompletionRate: 0.80,
            chronotypeBias: .moderateMorning,  // Older skew morning
            avgRMSSD: 30,
            sleepNeed: 7.0
        )
    ]

    private init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
    }

    // MARK: - Age Range

    enum AgeRange: String, Codable, CaseIterable {
        case young       // 18-25
        case youngAdult  // 26-35
        case adult       // 36-50
        case olderAdult  // 51+

        init(age: Int) {
            switch age {
            case ..<26: self = .young
            case 26..<36: self = .youngAdult
            case 36..<51: self = .adult
            default: self = .olderAdult
            }
        }

        var displayName: String {
            switch self {
            case .young: return "18-25"
            case .youngAdult: return "26-35"
            case .adult: return "36-50"
            case .olderAdult: return "51+"
            }
        }

        var description: String {
            switch self {
            case .young: return "Young adults often have evening chronotypes and need more sleep."
            case .youngAdult: return "Peak productivity years with flexible chronotype."
            case .adult: return "Established patterns with morning-leaning chronotype."
            case .olderAdult: return "Morning chronotype typical, with efficient focus patterns."
            }
        }
    }

    // MARK: - Population Baseline

    struct PopulationBaseline {
        let avgSessionDuration: TimeInterval
        let avgCompletionRate: Double
        let chronotypeBias: Chronotype
        let avgRMSSD: Double           // Typical HRV for this age group
        let sleepNeed: Double          // Hours of sleep needed

        var peakDeepWorkHours: Double {
            // Research: Declines slightly with age
            switch chronotypeBias {
            case .extremeMorning, .moderateMorning:
                return 4.0
            case .intermediate:
                return 4.5
            case .moderateEvening, .extremeEvening:
                return 4.0
            }
        }
    }

    // MARK: - Onboarding Assessment

    struct OnboardingAssessment: Codable {
        let age: Int
        let preferredWakeTime: Int           // Hour (0-23)
        let preferredSleepTime: Int          // Hour (0-23)
        let selfPerceivedProductivity: ProductivityTime
        let focusExperience: FocusExperience
        let typicalSessionLength: SessionLengthPreference
        let hasWearable: Bool
        let completedAt: Date

        enum ProductivityTime: String, Codable, CaseIterable {
            case morning = "Morning"
            case afternoon = "Afternoon"
            case evening = "Evening"
            case varies = "It varies"

            var icon: String {
                switch self {
                case .morning: return "sunrise.fill"
                case .afternoon: return "sun.max.fill"
                case .evening: return "sunset.fill"
                case .varies: return "clock.fill"
                }
            }
        }

        enum FocusExperience: String, Codable, CaseIterable {
            case beginner = "New to focused work"
            case intermediate = "Some experience"
            case advanced = "Very experienced"

            var multiplier: Double {
                switch self {
                case .beginner: return 0.85
                case .intermediate: return 1.0
                case .advanced: return 1.1
                }
            }

            var icon: String {
                switch self {
                case .beginner: return "leaf.fill"
                case .intermediate: return "leaf.arrow.triangle.circlepath"
                case .advanced: return "star.fill"
                }
            }
        }

        enum SessionLengthPreference: String, Codable, CaseIterable {
            case short = "15-25 minutes"
            case medium = "25-45 minutes"
            case long = "45-90 minutes"

            var duration: TimeInterval {
                switch self {
                case .short: return 20 * 60
                case .medium: return 35 * 60
                case .long: return 60 * 60
                }
            }

            var icon: String {
                switch self {
                case .short: return "hare.fill"
                case .medium: return "figure.walk"
                case .long: return "tortoise.fill"
                }
            }
        }
    }

    // MARK: - Initial Baseline Generation

    /// Generate initial baseline for brand new user
    func generateInitialBaseline(from assessment: OnboardingAssessment) -> UserBehavioralBaseline {
        // Step 1: Get population baseline for age
        let ageRange = AgeRange(age: assessment.age)
        let population = populationBaselines[ageRange] ?? populationBaselines[.youngAdult]!

        // Step 2: Create baseline with adjusted values
        var baseline = UserBehavioralBaseline()

        // Session duration from preference
        baseline.avgSessionDuration = assessment.typicalSessionLength.duration

        // Adjust completion rate by experience
        baseline.avgCompletionRate = min(0.9, population.avgCompletionRate * assessment.focusExperience.multiplier)

        // Set reasonable defaults for touch dynamics
        baseline.avgTouchFrequency = 2.0
        baseline.avgTouchVariance = 1.0
        baseline.avgPauseCount = 1.5

        // Step 3: Infer chronotype from sleep times
        let chronotype = inferChronotypeFromSleep(
            wake: assessment.preferredWakeTime,
            sleep: assessment.preferredSleepTime,
            selfReport: assessment.selfPerceivedProductivity
        )
        baseline.inferredChronotype = chronotype
        baseline.bestPerformanceHour = chronotype.peakWindow.start + 1  // Middle of peak window

        // Step 4: Set typical hours based on chronotype
        let peakStart = chronotype.peakWindow.start
        let peakEnd = chronotype.peakWindow.end
        baseline.typicalSessionHours = Array(peakStart...peakEnd)

        // Step 5: Set calibration status
        baseline.isCalibrated = false
        baseline.daysOfData = 0
        baseline.totalSessions = 0
        baseline.lastUpdated = Date()

        // Save assessment
        saveAssessment(assessment)
        markOnboardingComplete()

        print("🌱 [ColdStart] Initial baseline generated for \(ageRange.displayName) user")
        print("🌱 [ColdStart] Chronotype: \(chronotype.shortName), Peak: \(peakStart):00-\(peakEnd):00")

        return baseline
    }

    /// Infer chronotype from sleep times and self-report
    private func inferChronotypeFromSleep(
        wake: Int,
        sleep: Int,
        selfReport: OnboardingAssessment.ProductivityTime
    ) -> Chronotype {
        // Calculate mid-sleep (MSFsc approximation)
        var adjustedSleep = sleep
        if sleep > wake { adjustedSleep -= 24 }
        let midSleep = (adjustedSleep + wake) / 2
        let normalizedMidSleep = midSleep < 0 ? midSleep + 24 : midSleep

        // Base chronotype from mid-sleep
        // MSFsc research: < 3 AM = extreme morning, 3-4 = moderate morning, etc.
        var baseChronotype: Chronotype
        if normalizedMidSleep < 3 || normalizedMidSleep >= 22 {
            baseChronotype = .extremeMorning
        } else if normalizedMidSleep < 4 {
            baseChronotype = .moderateMorning
        } else if normalizedMidSleep < 5 {
            baseChronotype = .intermediate
        } else if normalizedMidSleep < 6 {
            baseChronotype = .moderateEvening
        } else {
            baseChronotype = .extremeEvening
        }

        // Adjust based on self-report productivity preference
        switch selfReport {
        case .morning:
            if baseChronotype == .intermediate {
                baseChronotype = .moderateMorning
            } else if baseChronotype == .moderateEvening {
                baseChronotype = .intermediate
            }
        case .evening:
            if baseChronotype == .intermediate {
                baseChronotype = .moderateEvening
            } else if baseChronotype == .moderateMorning {
                baseChronotype = .intermediate
            }
        case .afternoon:
            // Afternoon preference suggests intermediate
            if baseChronotype == .moderateMorning || baseChronotype == .moderateEvening {
                baseChronotype = .intermediate
            }
        case .varies:
            // No adjustment for variable productivity
            break
        }

        return baseChronotype
    }

    // MARK: - Calibration Progress

    struct CalibrationProgress: Codable {
        let daysCompleted: Int
        let daysRequired: Int
        let sessionsCompleted: Int
        let percentComplete: Double
        let status: Status
        let message: String
        let nextMilestone: String?

        enum Status: String, Codable {
            case collecting = "Collecting Data"
            case almostReady = "Almost Ready"
            case calibrated = "Calibrated"
        }

        var isComplete: Bool { daysCompleted >= daysRequired }

        var progressDescription: String {
            let percent = Int(percentComplete * 100)
            return "\(percent)% complete"
        }
    }

    func getCalibrationProgress(baseline: UserBehavioralBaseline) -> CalibrationProgress {
        let required = 7
        let completed = baseline.daysOfData
        let sessions = baseline.totalSessions
        let percent = min(1.0, Double(completed) / Double(required))

        let status: CalibrationProgress.Status
        let message: String
        let nextMilestone: String?

        if completed >= required {
            status = .calibrated
            message = "Your baseline is fully calibrated! Insights are now personalized."
            nextMilestone = nil
        } else if completed >= 5 {
            status = .almostReady
            message = "Almost there! \(required - completed) more days for full personalization."
            nextMilestone = "Complete \(required - completed) more day\(required - completed == 1 ? "" : "s") of sessions"
        } else if completed >= 3 {
            status = .collecting
            message = "Building your profile... Patterns are emerging!"
            nextMilestone = "Complete \(5 - completed) more days for better accuracy"
        } else {
            status = .collecting
            message = "Getting to know you... \(completed)/\(required) days collected."
            nextMilestone = "Complete more focus sessions to personalize your experience"
        }

        let progress = CalibrationProgress(
            daysCompleted: completed,
            daysRequired: required,
            sessionsCompleted: sessions,
            percentComplete: percent,
            status: status,
            message: message,
            nextMilestone: nextMilestone
        )

        calibrationProgress = progress
        return progress
    }

    // MARK: - Baseline Update with Transition

    /// Update baseline, transitioning from population to personal data
    /// Uses weighted blending that increases personal weight over time
    func updateBaseline(
        current: inout UserBehavioralBaseline,
        with features: BehavioralFeatures,
        sessionCompleted: Bool
    ) {
        // Skip very short sessions (less than 5 min)
        guard features.sessionDuration > 5 * 60 else { return }

        // Calculate transition weight: More weight to personal data as days increase
        // Day 1-3: 80% population, 20% personal
        // Day 4-7: 50% population, 50% personal
        // Day 8+: 20% population, 80% personal (fully personal after calibration)
        let personalWeight: Double
        switch current.daysOfData {
        case 0...3:
            personalWeight = 0.2
        case 4...7:
            personalWeight = 0.5
        default:
            personalWeight = 0.8
        }

        // Update session duration with weighted average
        current.avgSessionDuration = blend(
            population: current.avgSessionDuration,
            personal: features.sessionDuration,
            personalWeight: personalWeight
        )

        // Update completion rate
        let completionValue = sessionCompleted ? 1.0 : features.sessionCompletionRate
        current.avgCompletionRate = blend(
            population: current.avgCompletionRate,
            personal: completionValue,
            personalWeight: personalWeight
        )

        // Update pause count
        current.avgPauseCount = blend(
            population: current.avgPauseCount,
            personal: Double(features.pauseCount),
            personalWeight: personalWeight
        )

        // Update touch dynamics if available
        if features.touchFrequency > 0 {
            current.avgTouchFrequency = blend(
                population: current.avgTouchFrequency,
                personal: features.touchFrequency,
                personalWeight: personalWeight
            )
        }

        if features.touchIntervalVariance > 0 {
            current.avgTouchVariance = blend(
                population: current.avgTouchVariance,
                personal: features.touchIntervalVariance,
                personalWeight: personalWeight
            )
        }

        // Update typical session hours
        if !current.typicalSessionHours.contains(features.hourOfDay) {
            // Add hour if this was a good session
            if sessionCompleted || features.sessionCompletionRate > 0.7 {
                current.typicalSessionHours.append(features.hourOfDay)
                // Keep only hours with actual sessions (max 8 hours)
                if current.typicalSessionHours.count > 8 {
                    current.typicalSessionHours.removeFirst()
                }
            }
        }

        // Update best performance hour if this was an excellent session
        if sessionCompleted && features.sessionDuration >= current.avgSessionDuration * 0.9 {
            // This hour might be the new best
            current.bestPerformanceHour = features.hourOfDay
        }

        // Increment session count
        current.totalSessions += 1

        // Increment days if this is first session today
        let today = Calendar.current.startOfDay(for: Date())
        let lastUpdate = Calendar.current.startOfDay(for: current.lastUpdated)
        if today > lastUpdate {
            current.daysOfData += 1
            print("🌱 [ColdStart] Day \(current.daysOfData) of calibration complete")
        }

        // Mark as calibrated after 7 days
        if current.daysOfData >= 7 && !current.isCalibrated {
            current.isCalibrated = true
            print("🌱 [ColdStart] Baseline fully calibrated after \(current.totalSessions) sessions!")
        }

        current.lastUpdated = Date()
    }

    /// Blend population and personal values with given weight
    private func blend(population: Double, personal: Double, personalWeight: Double) -> Double {
        return (population * (1 - personalWeight)) + (personal * personalWeight)
    }

    // MARK: - Storage

    func saveAssessment(_ assessment: OnboardingAssessment) {
        if let data = try? JSONEncoder().encode(assessment) {
            UserDefaults.standard.set(data, forKey: assessmentKey)
        }
    }

    func loadAssessment() -> OnboardingAssessment? {
        guard let data = UserDefaults.standard.data(forKey: assessmentKey),
              let assessment = try? JSONDecoder().decode(OnboardingAssessment.self, from: data) else {
            return nil
        }
        return assessment
    }

    func markOnboardingComplete() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: onboardingCompletedKey)
        UserDefaults.standard.removeObject(forKey: assessmentKey)
        calibrationProgress = nil
    }

    // MARK: - Quick Start (Skip Detailed Onboarding)

    /// Generate a minimal baseline for users who skip detailed onboarding
    func generateQuickStartBaseline() -> UserBehavioralBaseline {
        var baseline = UserBehavioralBaseline()

        // Use intermediate defaults
        baseline.avgSessionDuration = 25 * 60
        baseline.avgCompletionRate = 0.7
        baseline.avgPauseCount = 1.5
        baseline.avgTouchFrequency = 2.0
        baseline.avgTouchVariance = 1.0
        baseline.inferredChronotype = .intermediate
        baseline.bestPerformanceHour = 10
        baseline.typicalSessionHours = [9, 10, 11, 14, 15]
        baseline.isCalibrated = false
        baseline.daysOfData = 0
        baseline.totalSessions = 0
        baseline.lastUpdated = Date()

        markOnboardingComplete()

        print("🌱 [ColdStart] Quick start baseline generated (intermediate defaults)")

        return baseline
    }
}

// MARK: - Onboarding UI Model
extension ColdStartManager {

    /// Questions for onboarding flow
    static let onboardingQuestions: [OnboardingQuestion] = [
        OnboardingQuestion(
            id: "age",
            question: "What's your age?",
            subtitle: "This helps us set realistic expectations",
            type: .number(min: 13, max: 100),
            icon: "person.fill"
        ),
        OnboardingQuestion(
            id: "wake_time",
            question: "What time do you usually wake up?",
            subtitle: "On a typical day",
            type: .timePicker,
            icon: "sunrise.fill"
        ),
        OnboardingQuestion(
            id: "sleep_time",
            question: "What time do you usually go to sleep?",
            subtitle: "When you're ready to sleep, not just in bed",
            type: .timePicker,
            icon: "moon.fill"
        ),
        OnboardingQuestion(
            id: "productivity_time",
            question: "When do you feel most productive?",
            subtitle: "When does focused work come easiest?",
            type: .singleChoice(options: OnboardingAssessment.ProductivityTime.allCases.map { $0.rawValue }),
            icon: "bolt.fill"
        ),
        OnboardingQuestion(
            id: "experience",
            question: "How experienced are you with focused work?",
            subtitle: "Think: Pomodoro, deep work, flow states",
            type: .singleChoice(options: OnboardingAssessment.FocusExperience.allCases.map { $0.rawValue }),
            icon: "graduationcap.fill"
        ),
        OnboardingQuestion(
            id: "session_length",
            question: "How long do you usually work without breaks?",
            subtitle: "Your natural rhythm, not an aspiration",
            type: .singleChoice(options: OnboardingAssessment.SessionLengthPreference.allCases.map { $0.rawValue }),
            icon: "timer"
        ),
        OnboardingQuestion(
            id: "wearable",
            question: "Do you have an Apple Watch?",
            subtitle: "Enables biometric flow detection for higher accuracy",
            type: .boolean,
            icon: "applewatch"
        )
    ]

    struct OnboardingQuestion: Identifiable {
        let id: String
        let question: String
        let subtitle: String
        let type: QuestionType
        let icon: String

        enum QuestionType {
            case number(min: Int, max: Int)
            case timePicker
            case singleChoice(options: [String])
            case boolean
        }
    }
}

// MARK: - Calibration Status Extension
extension UserBehavioralBaseline {
    /// Get a human-readable calibration status
    var calibrationStatusDescription: String {
        if isCalibrated {
            return "Fully personalized"
        } else if daysOfData >= 5 {
            return "Almost calibrated (\(daysOfData)/7 days)"
        } else if daysOfData >= 1 {
            return "Calibrating (\(daysOfData)/7 days)"
        } else {
            return "Using population defaults"
        }
    }
}
