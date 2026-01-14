import Foundation

// MARK: - Substance Log

/// Represents a single log entry for substance intake (caffeine, L-theanine, water, etc.)
struct SubstanceLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let substanceType: SubstanceType
    let amount: Double
    let unit: MeasurementUnit
    let source: String? // Optional source like "Starbucks Cold Brew"

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        substanceType: SubstanceType,
        amount: Double,
        unit: MeasurementUnit,
        source: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.substanceType = substanceType
        self.amount = amount
        self.unit = unit
        self.source = source
    }

    // MARK: - Computed Properties

    /// Half-life of the substance in seconds
    var halfLife: TimeInterval {
        substanceType.halfLife
    }

    /// Time until substance effects begin (onset) in seconds
    var onsetTime: TimeInterval {
        substanceType.onsetTime
    }

    /// Time until substance reaches peak concentration in seconds
    var peakTime: TimeInterval {
        substanceType.peakTime
    }

    // MARK: - Pharmacokinetic Calculations

    /**
     Calculates the active amount of substance in the system at a given time.

     Uses a three-phase pharmacokinetic model:
     1. **Lag Phase** (before onset): No active substance (absorption not yet started)
     2. **Absorption Phase** (onset → peak): Linear rise to peak concentration
     3. **Elimination Phase** (after peak): Exponential decay following first-order kinetics

     The exponential decay follows the formula:
     ```
     C(t) = C₀ × (1/2)^(t/t½)
     ```
     Where:
     - C(t) = concentration at time t
     - C₀ = initial concentration (peak amount)
     - t = time since peak
     - t½ = half-life of the substance

     - Parameter time: The time at which to calculate active amount
     - Returns: Active amount of substance (in original units)
     */
    func activeAmount(at time: Date) -> Double {
        let elapsed = time.timeIntervalSince(timestamp)

        // Phase 1: Before onset - no active substance yet
        guard elapsed >= onsetTime else {
            return 0
        }

        // Phase 2: Rising to peak (linear absorption)
        if elapsed < peakTime {
            let riseProgress = (elapsed - onsetTime) / (peakTime - onsetTime)
            return amount * riseProgress
        }

        // Phase 3: After peak (exponential decay)
        let decayTime = elapsed - peakTime
        let halfLives = decayTime / halfLife
        return amount * pow(0.5, halfLives)
    }

    /**
     Calculates the active amount of substance using personalized metabolism profile.

     Uses the same three-phase pharmacokinetic model as `activeAmount(at:)`, but with
     personalized half-life values based on the user's metabolism profile instead of
     standard population averages.

     This provides more accurate estimates by accounting for individual factors:
     - CYP1A2 genotype (caffeine metabolism enzyme)
     - Body weight (via allometric scaling)
     - Metabolism speed (fast/average/slow)
     - Caffeine tolerance level
     - Sleep quality and exercise frequency

     - Parameters:
       - time: The time at which to calculate active amount
       - profile: User's metabolism profile containing personalized parameters
     - Returns: Active amount of substance (in original units) based on personalized half-life
     */
    func personalizedActiveAmount(at time: Date, profile: UserMetabolismProfile) -> Double {
        let elapsed = time.timeIntervalSince(timestamp)

        // Phase 1: Before onset - no active substance yet
        guard elapsed >= onsetTime else {
            return 0
        }

        // Get personalized half-life for this substance
        let personalizedHalfLife: TimeInterval
        switch substanceType {
        case .caffeine:
            personalizedHalfLife = profile.caffeineHalfLife()
        case .lTheanine:
            personalizedHalfLife = profile.lTheanineHalfLife()
        case .water:
            personalizedHalfLife = profile.waterHalfLife()
        }

        // Phase 2: Rising to peak (linear absorption - same for all metabolizers)
        if elapsed < peakTime {
            let riseProgress = (elapsed - onsetTime) / (peakTime - onsetTime)
            return amount * riseProgress
        }

        // Phase 3: After peak (exponential decay with personalized half-life)
        let decayTime = elapsed - peakTime
        let halfLives = decayTime / personalizedHalfLife
        return amount * pow(0.5, halfLives)
    }
}

// MARK: - Substance Type

/// Types of substances that can be tracked
///
/// SCIENTIFIC CITATIONS:
/// - Caffeine half-life: Institute of Medicine consensus (3-7h range, 5h mean)
/// - Caffeine Tmax: 45-60 min (White et al. 2016, Clinical Toxicology)
/// - L-theanine half-life: 58-74 min (van der Pijl 2010, Scheid et al. 2012)
/// - L-theanine Tmax: 45-50 min (human pharmacokinetic studies)
/// - Water: Simple daily intake model (biological half-life is 9-14 DAYS, not 1 hour)
enum SubstanceType: String, CaseIterable, Codable {
    case caffeine = "Caffeine"
    case lTheanine = "L-Theanine"
    case water = "Water"

    /// Half-life of substance elimination (time for concentration to reduce by 50%)
    var halfLife: TimeInterval {
        switch self {
        case .caffeine:
            return 5 * 3600 // 5 hours (Institute of Medicine consensus, varies 3-7h)
        case .lTheanine:
            // CORRECTED: 40min → 60min (Scheid et al. 2012, Journal of Nutrition)
            return 60 * 60 // 60 minutes (58-74 min range in studies)
        case .water:
            // NOTE: This is a simplified model for UI tracking purposes
            // True biological half-life of water is 9-14 DAYS
            return 1 * 3600 // 1 hour (simplified for daily intake tracking)
        }
    }

    /// Time from ingestion to peak blood concentration (Tmax)
    var peakTime: TimeInterval {
        switch self {
        case .caffeine:
            // CORRECTED: 30min → 45min (White et al. 2016, Clinical Toxicology)
            return 45 * 60 // 45 minutes (45-60 min typical)
        case .lTheanine:
            // CORRECTED: 16min → 50min (van der Pijl 2010)
            return 50 * 60 // 50 minutes (45-50 min in human studies)
        case .water:
            return 20 * 60 // 20 minutes (gastric emptying + absorption)
        }
    }

    /// Time from ingestion to onset of effects
    var onsetTime: TimeInterval {
        switch self {
        case .caffeine:
            return 12.5 * 60 // 12.5 minutes (validated - noticeable alertness)
        case .lTheanine:
            return 15 * 60 // 15 minutes (validated - calming effects begin)
        case .water:
            return 20 * 60 // 20 minutes (hydration effects)
        }
    }

    /// Default amount for this substance
    var defaultAmount: Double {
        switch self {
        case .caffeine:
            return 95.0 // Standard 8oz cup of coffee (mg)
        case .lTheanine:
            return 200.0 // Standard supplement dose (mg)
        case .water:
            return 250.0 // One cup / 8oz (ml)
        }
    }

    /// SF Symbol icon name for this substance
    var iconName: String {
        switch self {
        case .caffeine:
            return "cup.and.saucer.fill"
        case .lTheanine:
            return "leaf.fill"
        case .water:
            return "drop.fill"
        }
    }

    /// Color identifier for UI representation
    var color: String {
        switch self {
        case .caffeine:
            return "brown"
        case .lTheanine:
            return "green"
        case .water:
            return "blue"
        }
    }
}

// MARK: - Measurement Unit

/// Units of measurement for substance amounts
enum MeasurementUnit: String, Codable {
    case mg = "mg"   // Milligrams (for caffeine, l-theanine)
    case ml = "ml"   // Milliliters (for water, liquid caffeine)
    case cups = "cups" // Cups (for water)
}
