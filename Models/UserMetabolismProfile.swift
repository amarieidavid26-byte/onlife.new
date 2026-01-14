import Foundation
import Combine

/*
 User Metabolism Profile System

 SCIENTIFIC CITATIONS:
 - Caffeine base half-life: Institute of Medicine consensus (3-7h range, 5h mean)
 - CYP1A2 variation: 2-4× documented (Sachse et al., PMC6342244)
 - Oral contraceptives: 1.7× longer half-life (Abernethy & Todd 1985)
 - Smoking: 0.6× half-life / 1.67× clearance (PubMed 15289794)
 - Pregnancy: Progressive increase to 2× by third trimester (PMC5564294)
 - Fluvoxamine: 5-6× longer half-life (PubMed 8807660)
 - Caffeine Tmax (peak): 45-60 min typical (White et al. 2016, Clinical Toxicology)
 - L-theanine half-life: 58-74 min (van der Pijl 2010, Scheid et al. 2012)
 - L-theanine Tmax: 45-50 min (human studies)
 - Synergy: Minimum 50mg caffeine + 100mg L-theanine (Owen 2008, Kelly 2008)
 - Kleiber's Law exponent 0.7: "highly disputed" but acceptable (Clinical Pharmacokinetics 2024)
 - Age effects: NO evidence for adult decline (Blanchard & Sawers 1983)
 - Exercise effects: NO effect on caffeine metabolism (Journal of Applied Physiology)
 - Tolerance: Does NOT induce CYP1A2 in humans (PMC3715142)

 Provides personalized substance tracking based on individual metabolic factors:
 - Demographics (age, weight, sex)
 - Health status (pregnancy, contraceptives, smoking, medications)
 - Genetic factors (CYP1A2 enzyme activity)

 REMOVED (not scientifically supported):
 - Exercise frequency metabolism boost
 - Caffeine tolerance metabolism boost (affects sensitivity, not clearance)
 - Age decline after 30 (no evidence)
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

// MARK: - Smoking Status

/// Smoking status significantly affects caffeine metabolism
/// Smoking induces CYP1A2 ~50% (PMC studies)
enum SmokingStatus: String, Codable, CaseIterable {
    case nonSmoker = "Non-smoker"
    case smoker = "Current smoker"
    case recentlyQuit = "Quit within 6 months"

    var displayName: String {
        switch self {
        case .nonSmoker: return "Non-smoker"
        case .smoker: return "Current smoker (cigarettes or vaping)"
        case .recentlyQuit: return "Recently quit (within 6 months)"
        }
    }

    /// Metabolism multiplier for caffeine clearance
    /// Smoking induces CYP1A2, resulting in faster caffeine metabolism
    var metabolismMultiplier: Double {
        switch self {
        case .smoker: return 1.67       // 0.6× half-life = 1.67× faster clearance
        case .recentlyQuit: return 1.11 // 0.9× half-life (enzyme induction fading)
        case .nonSmoker: return 1.0
        }
    }

    var icon: String {
        switch self {
        case .nonSmoker: return "nosign"
        case .smoker: return "smoke.fill"
        case .recentlyQuit: return "checkmark.circle"
        }
    }
}

// MARK: - Pregnancy Trimester

/// Pregnancy trimester for caffeine metabolism adjustment
/// Pregnancy progressively slows caffeine metabolism (PMC5564294)
enum PregnancyTrimester: Int, Codable, CaseIterable {
    case first = 1
    case second = 2
    case third = 3

    var displayName: String {
        switch self {
        case .first: return "First trimester (weeks 1-12)"
        case .second: return "Second trimester (weeks 13-26)"
        case .third: return "Third trimester (weeks 27-40)"
        }
    }

    /// Metabolism multiplier - pregnancy slows caffeine clearance progressively
    var metabolismMultiplier: Double {
        switch self {
        case .first: return 0.83   // 1.2× longer half-life
        case .second: return 0.67  // 1.5× longer half-life
        case .third: return 0.50   // 2.0× longer half-life
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

    // MARK: Health Status (Safety-Critical)
    /// Oral contraceptives nearly double caffeine half-life (Abernethy & Todd 1985)
    var usesHormonalContraceptives: Bool = false

    /// Smoking induces CYP1A2 ~50% faster clearance (PubMed 15289794)
    var smokingStatus: SmokingStatus = .nonSmoker

    /// Pregnancy progressively slows caffeine metabolism (PMC5564294)
    var isPregnant: Bool = false
    var pregnancyTrimester: PregnancyTrimester? = nil

    /// Fluvoxamine increases caffeine half-life 5-6× (PubMed 8807660)
    var takesFluvoxamine: Bool = false

    // MARK: Lifestyle Factors
    var caffeineToleranceLevel: CaffeineToleranceLevel
    var averageSleepQuality: SleepQuality
    var exerciseFrequency: ExerciseFrequency  // Kept for UI but no longer affects metabolism

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

    /// Overall metabolism multiplier combining all evidence-based factors
    /// REMOVED: age decline after 30 (Blanchard & Sawers 1983 found no difference)
    /// REMOVED: exercise boost (Journal of Applied Physiology: no effect on caffeine)
    /// ADDED: contraceptives, smoking, pregnancy (peer-reviewed evidence)
    var overallMetabolismMultiplier: Double {
        var multiplier = 1.0

        // Base metabolism speed (user's self-assessment)
        multiplier *= metabolismSpeed.multiplier

        // Sex differences (hormonal and body composition)
        multiplier *= sex.metabolismModifier

        // Weight adjustment using allometric scaling
        // Metabolism ∝ mass^0.75 (Kleiber's law - "highly disputed" but acceptable)
        let weightFactor = weight / 70.0  // 70kg baseline
        multiplier *= pow(weightFactor, 0.7)

        // Adolescent boost only (has separate evidence)
        // REMOVED: age decline after 30 - Blanchard & Sawers 1983 found NO difference
        if age < 20 {
            let yearsBefore20 = Double(20 - age)
            multiplier *= (1.0 + yearsBefore20 * 0.02)  // 2% faster per year
        }

        // Oral contraceptives nearly double caffeine half-life (Abernethy & Todd 1985)
        // Critical for 17-25 female demographic
        if sex == .female && usesHormonalContraceptives {
            multiplier *= 0.59  // 1.7× longer half-life = 1/1.7 = 0.59× clearance
        }

        // Smoking induces CYP1A2 ~50% (PubMed 15289794)
        multiplier *= smokingStatus.metabolismMultiplier

        // Pregnancy progressively slows caffeine metabolism (PMC5564294)
        if isPregnant, let trimester = pregnancyTrimester {
            multiplier *= trimester.metabolismMultiplier
        }

        // REMOVED: Exercise boost - Journal of Applied Physiology found NO effect
        // exerciseFrequency kept for UI/tracking but doesn't affect metabolism

        return multiplier
    }

    // MARK: - Substance-Specific Calculations

    /// Calculate personalized caffeine half-life
    /// Base: 5 hours, but can vary 3-4x based on genetics
    /// REMOVED: tolerance boost - PMC3715142 found caffeine does NOT induce CYP1A2 in humans
    func caffeineHalfLife(baseHalfLife: TimeInterval = 5 * 3600) -> TimeInterval {
        var adjusted = baseHalfLife

        // Apply overall metabolism (includes contraceptives, smoking, pregnancy)
        adjusted /= overallMetabolismMultiplier

        // Apply genetic factors (can be 2-4× variation! - Sachse et al., PMC6342244)
        adjusted *= cyp1a2Genotype.caffeineMultiplier

        // REMOVED: caffeineToleranceLevel.metabolismBoost
        // PMC3715142: "caffeine does not induce CYP1A2 in humans"
        // Tolerance affects sensitivity, not clearance rate

        // Fluvoxamine increases caffeine half-life 5-6× (PubMed 8807660)
        // This is a SEVERE interaction - user should consult healthcare provider
        if takesFluvoxamine {
            adjusted *= 5.5  // Middle of 5-6× range
        }

        return adjusted
    }

    /// Calculate personalized L-theanine half-life
    /// Base: 60 minutes (Scheid et al. 2012, Journal of Nutrition; van der Pijl 2010)
    /// CORRECTED: 40min → 60min based on peer-reviewed pharmacokinetic studies
    func lTheanineHalfLife(baseHalfLife: TimeInterval = 60 * 60) -> TimeInterval {
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
    /// Evidence-based limits from EFSA 2015, AAP, ACOG/WHO
    /// REMOVED: tolerance-based increase - tolerance affects sensitivity, not safe limits
    var recommendedDailyCaffeineLimit: Double {
        // Age-specific absolute limits (safety thresholds)
        let maxLimit: Double
        if age < 18 {
            maxLimit = 100.0   // AAP recommendation for adolescents
        } else if isPregnant {
            maxLimit = 200.0   // ACOG/WHO/EFSA pregnancy limit
        } else {
            maxLimit = 400.0   // EFSA adult limit (reduced from 600mg)
        }

        // Start with weight-based calculation
        let mgPerKg = 5.7  // ~400mg for 70kg adult
        var limit = mgPerKg * weight

        // Reduce for slow metabolizers
        if metabolismSpeed == .slow || cyp1a2Genotype == .slow {
            limit *= 0.75
        }

        // Reduce for poor sleep (more sensitive to effects)
        if averageSleepQuality == .poor {
            limit *= 0.8
        }

        // Reduce for fluvoxamine users (5-6× longer half-life!)
        if takesFluvoxamine {
            limit *= 0.2  // Much lower limit due to severe interaction
        }

        // REMOVED: tolerance-based increase
        // EFSA 2015: Tolerance does not increase safe limits
        // High tolerance affects subjective sensitivity, not safety thresholds

        // Apply absolute maximum based on age/pregnancy status
        return min(limit, maxLimit)
    }

    // MARK: - Health Warnings

    /// Get health warnings based on current profile
    /// Returns array of warning messages for display to user
    func getCaffeineWarnings() -> [String] {
        var warnings: [String] = []

        if takesFluvoxamine {
            warnings.append("⚠️ CRITICAL: Fluvoxamine increases caffeine half-life 5-6×. Consult healthcare provider before using this app.")
        }

        if isPregnant {
            warnings.append("Limit caffeine to 200mg/day during pregnancy (ACOG/WHO recommendation)")
        }

        if age < 18 {
            warnings.append("Maximum 100mg caffeine per day recommended for adolescents (AAP guideline)")
        }

        if usesHormonalContraceptives {
            warnings.append("Hormonal contraceptives nearly double caffeine half-life. Effects last longer.")
        }

        return warnings
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
            usesHormonalContraceptives: false,
            smokingStatus: .nonSmoker,
            isPregnant: false,
            pregnancyTrimester: nil,
            takesFluvoxamine: false,
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
