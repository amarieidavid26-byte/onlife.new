import Foundation
import RealityKit

/// Manifest of all plant assets in the app
/// Defines growth stages, LOD levels, and asset naming conventions
struct PlantAssetManifest {

    // MARK: - Growth Stages

    /// Growth stages for plants - determines which model to display
    enum GrowthStage: String, CaseIterable {
        case seed = "seed"
        case sprout = "sprout"
        case young = "young"
        case mature = "mature"
        case blooming = "blooming"  // For flowering plants

        /// Progress range that maps to this stage
        var progressRange: ClosedRange<Double> {
            switch self {
            case .seed: return 0.0...0.15
            case .sprout: return 0.15...0.35
            case .young: return 0.35...0.60
            case .mature: return 0.60...0.85
            case .blooming: return 0.85...1.0
            }
        }

        /// Determine the appropriate stage for a given growth progress
        static func stage(for progress: Double) -> GrowthStage {
            for stage in allCases {
                if stage.progressRange.contains(progress) {
                    return stage
                }
            }
            return .mature
        }

        /// Scale multiplier for this stage
        var scaleMultiplier: Float {
            switch self {
            case .seed: return 0.15
            case .sprout: return 0.35
            case .young: return 0.60
            case .mature: return 0.85
            case .blooming: return 1.0
            }
        }
    }

    // MARK: - LOD Levels

    /// Level of Detail for performance optimization
    enum LODLevel: String, CaseIterable {
        case high = "high"      // < 5 meters from camera - full detail
        case medium = "medium"  // 5-15 meters - reduced detail
        case low = "low"        // > 15 meters - billboard/simple

        /// Maximum camera distance for this LOD
        var maxDistance: Float {
            switch self {
            case .high: return 5.0
            case .medium: return 15.0
            case .low: return .infinity
            }
        }

        /// Target polygon count for this LOD
        var polygonBudget: Int {
            switch self {
            case .high: return 2000
            case .medium: return 500
            case .low: return 50  // Billboard
            }
        }
    }

    // MARK: - Particle Effects

    /// Types of particle effects that can be attached to plants
    enum ParticleEffectType: String, CaseIterable {
        case pollen = "pollen"
        case butterflies = "butterflies"
        case fireflies = "fireflies"
        case fallingLeaves = "fallingLeaves"
        case sparkles = "sparkles"
        case petals = "petals"

        /// Color associated with this effect
        var primaryColor: (r: Float, g: Float, b: Float) {
            switch self {
            case .pollen: return (1.0, 0.9, 0.3)
            case .butterflies: return (0.9, 0.5, 0.8)
            case .fireflies: return (0.9, 1.0, 0.5)
            case .fallingLeaves: return (0.8, 0.5, 0.2)
            case .sparkles: return (1.0, 1.0, 0.9)
            case .petals: return (1.0, 0.7, 0.8)
            }
        }
    }

    // MARK: - Plant Asset Definition

    /// Complete definition for a single plant species' assets
    struct PlantAssetDefinition {
        let species: PlantSpecies
        let displayName: String
        let hasBloomingStage: Bool
        let baseHeight: Float           // Meters at mature stage
        let swayIntensity: Float        // 0-1, how much it sways in wind
        let stiffness: Float            // 0-1, resistance to wind
        let particleEffect: ParticleEffectType?
        let particleIntensity: Float    // 0-1, particle spawn rate

        /// Asset file name for a specific stage and LOD
        /// Format: "PlantName_Stage" or "PlantName_Stage_lod" for lower LODs
        func assetName(for stage: GrowthStage, lod: LODLevel = .high) -> String {
            let baseName = species.rawValue.capitalized
            let stageName = stage.rawValue.capitalized
            let lodSuffix = lod == .high ? "" : "_\(lod.rawValue)"
            return "\(baseName)_\(stageName)\(lodSuffix)"
        }

        /// All asset names needed for this plant (all stages and LODs)
        var allAssetNames: [String] {
            var names: [String] = []
            let stages = hasBloomingStage ? GrowthStage.allCases : GrowthStage.allCases.filter { $0 != .blooming }

            for stage in stages {
                for lod in LODLevel.allCases {
                    names.append(assetName(for: stage, lod: lod))
                }
            }
            return names
        }

        /// Primary asset names (high LOD only)
        var primaryAssetNames: [String] {
            let stages = hasBloomingStage ? GrowthStage.allCases : GrowthStage.allCases.filter { $0 != .blooming }
            return stages.map { assetName(for: $0, lod: .high) }
        }
    }

    // MARK: - Plant Definitions

    /// All plant definitions indexed by species
    static let plants: [PlantSpecies: PlantAssetDefinition] = [
        .rose: PlantAssetDefinition(
            species: .rose,
            displayName: "Rose",
            hasBloomingStage: true,
            baseHeight: 0.6,
            swayIntensity: 0.7,
            stiffness: 0.4,
            particleEffect: .butterflies,
            particleIntensity: 0.3
        ),
        .oak: PlantAssetDefinition(
            species: .oak,
            displayName: "Oak Tree",
            hasBloomingStage: false,
            baseHeight: 2.0,
            swayIntensity: 0.4,
            stiffness: 0.7,
            particleEffect: .fallingLeaves,
            particleIntensity: 0.4
        ),
        .sunflower: PlantAssetDefinition(
            species: .sunflower,
            displayName: "Sunflower",
            hasBloomingStage: true,
            baseHeight: 1.2,
            swayIntensity: 0.8,
            stiffness: 0.3,
            particleEffect: .pollen,
            particleIntensity: 0.5
        ),
        .lavender: PlantAssetDefinition(
            species: .lavender,
            displayName: "Lavender",
            hasBloomingStage: true,
            baseHeight: 0.4,
            swayIntensity: 0.6,
            stiffness: 0.35,
            particleEffect: .butterflies,
            particleIntensity: 0.4
        ),
        .cactus: PlantAssetDefinition(
            species: .cactus,
            displayName: "Cactus",
            hasBloomingStage: true,
            baseHeight: 0.5,
            swayIntensity: 0.1,  // Cacti don't sway much
            stiffness: 0.9,
            particleEffect: nil,
            particleIntensity: 0.0
        ),
        .fern: PlantAssetDefinition(
            species: .fern,
            displayName: "Fern",
            hasBloomingStage: false,
            baseHeight: 0.5,
            swayIntensity: 0.9,  // Very swayable
            stiffness: 0.2,
            particleEffect: .sparkles,
            particleIntensity: 0.2
        ),
        .bamboo: PlantAssetDefinition(
            species: .bamboo,
            displayName: "Bamboo",
            hasBloomingStage: false,
            baseHeight: 1.8,
            swayIntensity: 0.85,
            stiffness: 0.25,
            particleEffect: nil,
            particleIntensity: 0.0
        ),
        .bonsai: PlantAssetDefinition(
            species: .bonsai,
            displayName: "Bonsai",
            hasBloomingStage: false,
            baseHeight: 0.4,
            swayIntensity: 0.3,
            stiffness: 0.6,
            particleEffect: .sparkles,
            particleIntensity: 0.3
        ),
        .cherry: PlantAssetDefinition(
            species: .cherry,
            displayName: "Cherry Blossom",
            hasBloomingStage: true,
            baseHeight: 1.5,
            swayIntensity: 0.6,
            stiffness: 0.45,
            particleEffect: .petals,
            particleIntensity: 0.6
        ),
        .tulip: PlantAssetDefinition(
            species: .tulip,
            displayName: "Tulip",
            hasBloomingStage: true,
            baseHeight: 0.35,
            swayIntensity: 0.75,
            stiffness: 0.3,
            particleEffect: nil,
            particleIntensity: 0.0
        )
    ]

    // MARK: - Accessors

    /// Get definition for a species
    static func definition(for species: PlantSpecies) -> PlantAssetDefinition? {
        return plants[species]
    }

    /// Total number of assets to preload (all species, stages, LODs)
    static var totalAssetCount: Int {
        return plants.values.reduce(0) { $0 + $1.allAssetNames.count }
    }

    /// Total number of primary assets (high LOD only)
    static var primaryAssetCount: Int {
        return plants.values.reduce(0) { $0 + $1.primaryAssetNames.count }
    }

    /// All species that have particle effects
    static var speciesWithParticles: [PlantSpecies] {
        return plants.filter { $0.value.particleEffect != nil }.map { $0.key }
    }
}
