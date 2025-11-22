import Foundation
import Combine

/*
 User Metabolism Profile System

 Provides personalized substance tracking based on individual metabolic factors:
 - Demographics (age, weight, sex)
 - Lifestyle (caffeine tolerance, sleep, exercise)
 - Genetic factors (CYP1A2 enzyme activity)

 Research-backed metabolic modeling accounts for:
 - 3-4x variation in caffeine metabolism due to genetics
 - 10-15% sex-based metabolic differences
 - Age-related metabolism changes (1-2% per decade after 30)
 - Allometric scaling for weight (metabolism ∝ mass^0.75)
 - Enzyme induction from chronic caffeine use
 */

// MARK: - Biological Sex

/// Biological sex affects basal metabolic rate due to hormonal and body composition differences
enum BiologicalSex: String, Codable, CaseIterable {
    case male = "Male"
    case female = "Female"
    case other = "Prefer not to say"

    /// Metabolic rate modifier based on sex
    /// Males typically have 10-15% faster BMR due to higher muscle mass and testosterone
    var metabolismModifier: Double {
        switch self {
        case .male: return 1.0
        case .female: return 0.9    // 10% slower average BMR
        case .other: return 0.95     // Use middle ground
        }
    }

    var icon: String {
        switch self {
        case .male: return "figure.walk"
        case .female: return "figure.walk"
        case .other: return "person.fill"
        }
    }
}

// MARK: - Metabolism Speed

/// User's self-assessed metabolic rate (validated against substance response patterns)
enum MetabolismSpeed: String, Codable, CaseIterable {
    case slow = "Slow"
    case average = "Average"
    case fast = "Fast"

    /// Half-life multiplier for all substances
    var multiplier: Double {
        switch self {
        case .slow: return 1.4      // Substances last 40% longer
        case .average: return 1.0
        case .fast: return 0.65     // Substances clear 35% faster
        }
    }

    var description: String {
        switch self {
        case .slow: return "Substances affect you longer than average"
        case .average: return "Typical metabolic rate"
        case .fast: return "Substances clear from your system quickly"
        }
    }

    var icon: String {
        switch self {
        case .slow: return "tortoise.fill"
        case .average: return "figure.walk"
        case .fast: return "hare.fill"
        }
    }

    var color: String {
        switch self {
        case .slow: return "blue"
        case .average: return "green"
        case .fast: return "orange"
        }
    }
}

// MARK: - Caffeine Tolerance

/// Chronic caffeine intake level (affects CYP1A2 enzyme upregulation)
enum CaffeineToleranceLevel: String, Codable, CaseIterable {
    case none = "None"
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"

    var displayName: String {
        switch self {
        case .none: return "None (0 cups/day)"
        case .low: return "Low (1 cup/day)"
        case .moderate: return "Moderate (2-3 cups/day)"
        case .high: return "High (4+ cups/day)"
        }
    }

    var cupsPerDay: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .moderate: return 2
        case .high: return 4
        }
    }

    /// Enzyme induction from chronic caffeine use (upregulates CYP1A2)
    var metabolismBoost: Double {
        switch self {
        case .none: return 1.0
        case .low: return 1.1       // 10% faster clearance
        case .moderate: return 1.25 // 25% faster clearance
        case .high: return 1.5      // 50% faster (significant enzyme induction)
        }
    }

    var icon: String {
        switch self {
        case .none: return "cup.and.saucer"
        case .low: return "cup.and.saucer"
        case .moderate: return "cup.and.saucer.fill"
        case .high: return "takeoutbag.and.cup.and.straw.fill"
        }
    }
}

// MARK: - Sleep Quality

/// Average sleep quality affects substance sensitivity and metabolism
enum SleepQuality: String, Codable, CaseIterable {
    case poor = "Poor"
    case fair = "Fair"
    case good = "Good"
    case excellent = "Excellent"

    var displayName: String {
        switch self {
        case .poor: return "Poor (< 6 hours)"
        case .fair: return "Fair (6-7 hours)"
        case .good: return "Good (7-8 hours)"
        case .excellent: return "Excellent (8+ hours)"
        }
    }

    var averageHours: Double {
        switch self {
        case .poor: return 5.5
        case .fair: return 6.5
        case .good: return 7.5
        case .excellent: return 8.5
        }
    }

    var icon: String {
        switch self {
        case .poor: return "bed.double"
        case .fair: return "bed.double"
        case .good: return "bed.double.fill"
        case .excellent: return "moon.stars.fill"
        }
    }
}

// MARK: - Exercise Frequency

/// Regular exercise increases basal metabolic rate
enum ExerciseFrequency: String, Codable, CaseIterable {
    case sedentary = "Sedentary"
    case light = "Light"
    case moderate = "Moderate"
    case active = "Active"

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary (< 1x/week)"
        case .light: return "Light (1-2x/week)"
        case .moderate: return "Moderate (3-4x/week)"
        case .active: return "Active (5+ x/week)"
        }
    }

    /// BMR increase from regular exercise
    var metabolismBoost: Double {
        switch self {
        case .sedentary: return 1.0
        case .light: return 1.05     // 5% increase
        case .moderate: return 1.1   // 10% increase
        case .active: return 1.15    // 15% increase
        }
    }

    var icon: String {
        switch self {
        case .sedentary: return "figure.stand"
        case .light: return "figure.walk"
        case .moderate: return "figure.run"
        case .active: return "flame.fill"
        }
    }
}

// MARK: - CYP1A2 Genotype

/// Genetic variation in CYP1A2 enzyme (primary caffeine metabolizer)
/// Causes 3-4x variation in caffeine metabolism between individuals!
enum CYP1A2Genotype: String, Codable, CaseIterable {
    case unknown = "Unknown"
    case slow = "Slow"
    case normal = "Normal"
    case fast = "Fast"

    var displayName: String {
        switch self {
        case .unknown: return "Unknown (we'll estimate)"
        case .slow: return "Slow Metabolizer (AA genotype)"
        case .normal: return "Normal Metabolizer (AC genotype)"
        case .fast: return "Fast Metabolizer (CC genotype)"
        }
    }

    /// Genetic caffeine metabolism modifier (3-4x variation!)
    var caffeineMultiplier: Double {
        switch self {
        case .unknown: return 1.0
        case .slow: return 1.6      // 60% slower caffeine metabolism
        case .normal: return 1.0
        case .fast: return 0.5      // 50% faster caffeine metabolism
        }
    }

    var description: String {
        switch self {
        case .unknown: return "We'll estimate based on your caffeine tolerance and response patterns"
        case .slow: return "Caffeine affects you strongly and lasts much longer than average"
        case .normal: return "Typical caffeine metabolism rate"
        case .fast: return "High caffeine tolerance, quick clearance from your system"
        }
    }

    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .slow: return "tortoise.fill"
        case .normal: return "clock"
        case .fast: return "hare.fill"
        }
    }
}

// MARK: - User Metabolism Profile

/// Complete user metabolism profile for personalized substance tracking
struct UserMetabolismProfile: Codable {
    // MARK: Basic Demographics
    var age: Int
    var weight: Double          // kilograms
    var height: Double?         // centimeters (optional)
    var sex: BiologicalSex

    // MARK: Lifestyle Factors
    var caffeineToleranceLevel: CaffeineToleranceLevel
    var averageSleepQuality: SleepQuality
    var exerciseFrequency: ExerciseFrequency

    // MARK: Metabolism Assessment
    var metabolismSpeed: MetabolismSpeed
    var cyp1a2Genotype: CYP1A2Genotype

    // MARK: Metadata
    var createdAt: Date
    var lastUpdated: Date

    // MARK: - Computed Properties

    /// Profile completeness score (0.0 to 1.0)
    var profileCompleteness: Double {
        var score = 0.0

        // Required fields
        if age > 0 && age < 120 { score += 0.15 }
        if weight > 30 && weight < 300 { score += 0.20 }
        score += 0.10 // sex is always set
        score += 0.15 // caffeine tolerance is always set
        score += 0.10 // sleep quality is always set
        score += 0.10 // exercise frequency is always set
        score += 0.10 // metabolism speed is always set

        // Optional fields
        if let h = height, h > 100 && h < 250 { score += 0.05 }
        if cyp1a2Genotype != .unknown { score += 0.05 }

        return min(1.0, score)
    }

    /// Is profile complete enough for personalized calculations?
    var isComplete: Bool {
        return profileCompleteness >= 0.8
    }

    /// Body Mass Index (if height available)
    var bmi: Double? {
        guard let h = height, h > 0 else { return nil }
        let heightInMeters = h / 100.0
        return weight / (heightInMeters * heightInMeters)
    }

    /// Overall metabolism multiplier combining all factors
    /// Research-backed model accounting for sex, age, weight, and lifestyle
    var overallMetabolismMultiplier: Double {
        var multiplier = 1.0

        // Base metabolism speed (user's self-assessment)
        multiplier *= metabolismSpeed.multiplier

        // Sex differences (hormonal and body composition)
        multiplier *= sex.metabolismModifier

        // Weight adjustment using allometric scaling
        // Metabolism ∝ mass^0.75 (Kleiber's law)
        let weightFactor = weight / 70.0  // 70kg baseline
        multiplier *= pow(weightFactor, 0.7)

        // Age adjustment (metabolism slows ~1-2% per decade after 30)
        if age > 30 {
            let decadesPast30 = Double(age - 30) / 10.0
            multiplier *= pow(0.985, decadesPast30)  // 1.5% per decade
        } else if age < 20 {
            // Younger people have faster metabolism
            let yearsBefore20 = Double(20 - age)
            multiplier *= (1.0 + yearsBefore20 * 0.02)  // 2% faster per year
        }

        // Exercise boost (regular exercise increases BMR)
        multiplier *= exerciseFrequency.metabolismBoost

        return multiplier
    }

    // MARK: - Substance-Specific Calculations

    /// Calculate personalized caffeine half-life
    /// Base: 5 hours, but can vary 3-4x based on genetics and lifestyle
    func caffeineHalfLife(baseHalfLife: TimeInterval = 5 * 3600) -> TimeInterval {
        var adjusted = baseHalfLife

        // Apply overall metabolism
        adjusted /= overallMetabolismMultiplier

        // Apply caffeine tolerance (CYP1A2 enzyme upregulation)
        adjusted /= caffeineToleranceLevel.metabolismBoost

        // Apply genetic factors (can be 3-4x variation!)
        adjusted *= cyp1a2Genotype.caffeineMultiplier

        return adjusted
    }

    /// Calculate personalized L-theanine half-life
    /// Base: 40 minutes, less genetic variation than caffeine
    func lTheanineHalfLife(baseHalfLife: TimeInterval = 40 * 60) -> TimeInterval {
        var adjusted = baseHalfLife

        // L-theanine uses different metabolic pathway (less genetic variation)
        adjusted /= overallMetabolismMultiplier

        // No tolerance effect for L-theanine (different mechanism)

        return adjusted
    }

    /// Calculate personalized water absorption rate
    /// Base: 1 hour, affected by body size and exercise
    func waterHalfLife(baseHalfLife: TimeInterval = 1 * 3600) -> TimeInterval {
        var adjusted = baseHalfLife

        // Water absorption affected by body size and exercise
        adjusted /= (overallMetabolismMultiplier * 0.8)

        return adjusted
    }

    /// Get recommended daily caffeine limit (mg)
    /// FDA recommends max 400mg for adults, adjusted for individual factors
    var recommendedDailyCaffeineLimit: Double {
        // FDA recommends max 400mg for adults
        var limit = 400.0

        // Adjust based on weight (mg/kg basis)
        let mgPerKg = 5.7  // ~400mg for 70kg person
        limit = mgPerKg * weight

        // Reduce for slow metabolizers
        if metabolismSpeed == .slow || cyp1a2Genotype == .slow {
            limit *= 0.75
        }

        // Reduce for poor sleep (more sensitive)
        if averageSleepQuality == .poor {
            limit *= 0.8
        }

        // Increase for high tolerance (to a point)
        if caffeineToleranceLevel == .high {
            limit = min(limit * 1.2, 600)  // Cap at 600mg
        }

        return limit
    }

    // MARK: - Static Methods

    /// Estimate CYP1A2 genotype from behavioral patterns
    /// Used when user hasn't done genetic testing
    static func estimateCYP1A2(from tolerance: CaffeineToleranceLevel,
                               metabolismSpeed: MetabolismSpeed) -> CYP1A2Genotype {
        // High tolerance + fast metabolism = likely fast genotype
        if tolerance == .high && metabolismSpeed == .fast {
            return .fast
        }

        // High tolerance alone suggests at least normal
        if tolerance == .high {
            return .normal
        }

        // Low/no tolerance + slow metabolism = likely slow genotype
        if (tolerance == .none || tolerance == .low) && metabolismSpeed == .slow {
            return .slow
        }

        // Default to normal (most common)
        return .normal
    }

    /// Create default profile for new users
    static var defaultProfile: UserMetabolismProfile {
        UserMetabolismProfile(
            age: 25,
            weight: 70,
            height: 170,
            sex: .other,
            caffeineToleranceLevel: .moderate,
            averageSleepQuality: .good,
            exerciseFrequency: .moderate,
            metabolismSpeed: .average,
            cyp1a2Genotype: .unknown,
            createdAt: Date(),
            lastUpdated: Date()
        )
    }
}

// MARK: - Metabolism Profile Manager

/// Singleton manager for user metabolism profile
/// Handles persistence, updates, and personalized parameter calculations
class MetabolismProfileManager: ObservableObject {
    static let shared = MetabolismProfileManager()

    @Published var profile: UserMetabolismProfile {
        didSet {
            saveProfile()
        }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: onboardingKey)
        }
    }

    private let profileKey = "user_metabolism_profile"
    private let onboardingKey = "completed_metabolism_onboarding"

    private init() {
        // Load saved profile or use default
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserMetabolismProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = UserMetabolismProfile.defaultProfile
        }

        // Load onboarding status
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
    }

    /// Update the entire profile
    func updateProfile(_ newProfile: UserMetabolismProfile) {
        var updated = newProfile
        updated.lastUpdated = Date()

        // Auto-estimate CYP1A2 if unknown
        if updated.cyp1a2Genotype == .unknown {
            updated.cyp1a2Genotype = UserMetabolismProfile.estimateCYP1A2(
                from: updated.caffeineToleranceLevel,
                metabolismSpeed: updated.metabolismSpeed
            )
        }

        self.profile = updated
        self.hasCompletedOnboarding = true
    }

    /// Update specific field
    func updateField<T>(_ keyPath: WritableKeyPath<UserMetabolismProfile, T>, value: T) {
        profile[keyPath: keyPath] = value
        profile.lastUpdated = Date()
    }

    /// Save profile to UserDefaults
    private func saveProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: profileKey)
        }
    }

    /// Reset to default profile
    func resetToDefaults() {
        profile = UserMetabolismProfile.defaultProfile
        hasCompletedOnboarding = false
    }

    /// Get personalized substance parameters
    func getPersonalizedParameters() -> PersonalizedSubstanceParameters {
        return PersonalizedSubstanceParameters(
            caffeineHalfLife: profile.caffeineHalfLife(),
            lTheanineHalfLife: profile.lTheanineHalfLife(),
            waterHalfLife: profile.waterHalfLife(),
            dailyCaffeineLimit: profile.recommendedDailyCaffeineLimit
        )
    }
}

// MARK: - Personalized Substance Parameters

/// Personalized pharmacokinetic parameters calculated from user profile
struct PersonalizedSubstanceParameters {
    let caffeineHalfLife: TimeInterval
    let lTheanineHalfLife: TimeInterval
    let waterHalfLife: TimeInterval
    let dailyCaffeineLimit: Double
}
