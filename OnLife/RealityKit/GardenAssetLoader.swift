import RealityKit
import Foundation

/// Loads and caches USDZ assets for the 3D garden
@MainActor
class GardenAssetLoader {
    static let shared = GardenAssetLoader()

    /// Cached loaded entities
    private var entityCache: [String: Entity] = [:]

    /// Asset loading errors
    enum AssetError: Error {
        case assetNotFound(String)
        case loadFailed(String)
    }

    private init() {}

    // MARK: - Growth Stage

    enum GrowthStage: Int {
        case seedling = 0  // 0-33%
        case growing = 1   // 34-66%
        case mature = 2    // 67-100%

        static func from(progress: Double) -> GrowthStage {
            if progress < 0.34 {
                return .seedling
            } else if progress < 0.67 {
                return .growing
            } else {
                return .mature
            }
        }
    }

    // MARK: - Asset Mapping

    /// Returns the USDZ filename for a species at a growth stage
    func assetName(for species: PlantSpecies, stage: GrowthStage) -> String {
        switch species {
        case .oak:
            switch stage {
            case .seedling: return "tree_small"
            case .growing: return "tree_default"
            case .mature: return "tree_oak"
            }

        case .rose:
            switch stage {
            case .seedling: return "flower_redA"
            case .growing: return "flower_redB"
            case .mature: return "flower_redC"
            }

        case .cactus:
            switch stage {
            case .seedling: return "cactus_short"
            case .growing: return "cactus_short"
            case .mature: return "cactus_tall"
            }

        case .sunflower:
            switch stage {
            case .seedling: return "flower_yellowA"
            case .growing: return "flower_yellowB"
            case .mature: return "flower_yellowC"
            }

        case .fern:
            switch stage {
            case .seedling: return "grass_leafs"
            case .growing: return "plant_flatShort"
            case .mature: return "plant_flatTall"
            }

        case .bamboo:
            switch stage {
            case .seedling: return "crops_bambooStageA"
            case .growing: return "crops_bambooStageA"
            case .mature: return "crops_bambooStageB"
            }

        case .lavender:
            switch stage {
            case .seedling: return "flower_purpleA"
            case .growing: return "flower_purpleB"
            case .mature: return "flower_purpleC"
            }

        case .bonsai:
            // Using available tree assets as fallback
            switch stage {
            case .seedling: return "tree_small"
            case .growing: return "tree_default"
            case .mature: return "tree_detailed"
            }

        case .cherry:
            // Using available tree assets as fallback
            switch stage {
            case .seedling: return "tree_small"
            case .growing: return "tree_default"
            case .mature: return "tree_detailed"
            }

        case .tulip:
            switch stage {
            case .seedling: return "flower_redA"
            case .growing: return "flower_yellowA"
            case .mature: return "flower_yellowB"
            }
        }
    }

    // MARK: - Loading

    /// Load entity for a plant based on its species and growth progress
    func loadEntity(for plant: Plant) async throws -> Entity {
        let stage = GrowthStage.from(progress: plant.growthProgress)
        let assetName = assetName(for: plant.species, stage: stage)
        return try await loadEntity(named: assetName)
    }

    /// Load entity by asset name (cached)
    func loadEntity(named name: String) async throws -> Entity {
        // Check cache first
        if let cached = entityCache[name] {
            return cached.clone(recursive: true)
        }

        // Try various bundle paths for USDZ files
        let searchPaths = [
            "GardenAssets",
            "Resources/GardenAssets",
            nil  // Root bundle
        ]

        for subdirectory in searchPaths {
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: subdirectory) {
                return try await loadFromURL(url, name: name)
            }
        }

        print("❌ [AssetLoader] Asset not found: \(name).usdz")
        throw AssetError.assetNotFound(name)
    }

    private func loadFromURL(_ url: URL, name: String) async throws -> Entity {
        do {
            let entity = try await Entity(contentsOf: url)
            entityCache[name] = entity
            print("✅ [AssetLoader] Loaded: \(name).usdz")
            return entity.clone(recursive: true)
        } catch {
            print("❌ [AssetLoader] Failed to load \(name): \(error)")
            throw AssetError.loadFailed(name)
        }
    }

    // MARK: - Preloading

    /// Preload all assets for faster garden loading
    func preloadAllAssets() async {
        let allAssets = Set(PlantSpecies.allCases.flatMap { species in
            GrowthStage.allCases.map { stage in
                assetName(for: species, stage: stage)
            }
        })

        print("🔄 [AssetLoader] Preloading \(allAssets.count) unique assets...")

        for asset in allAssets {
            do {
                _ = try await loadEntity(named: asset)
            } catch {
                print("⚠️ [AssetLoader] Failed to preload: \(asset)")
            }
        }

        print("✅ [AssetLoader] Preloading complete")
    }

    /// Clear the cache
    func clearCache() {
        entityCache.removeAll()
        print("🗑️ [AssetLoader] Cache cleared")
    }

    /// Get scale factor for species (some models need adjustment)
    func scaleFactor(for species: PlantSpecies, stage: GrowthStage) -> Float {
        // Base scale to fit garden nicely
        let baseScale: Float = 0.3

        // Adjust per species
        let speciesMultiplier: Float
        switch species {
        case .oak, .cherry, .bonsai:
            speciesMultiplier = 0.8
        case .bamboo:
            speciesMultiplier = 0.7
        case .sunflower:
            speciesMultiplier = 1.0
        case .rose, .lavender, .tulip:
            speciesMultiplier = 1.2
        case .cactus:
            speciesMultiplier = 0.9
        case .fern:
            speciesMultiplier = 1.1
        }

        // Adjust per growth stage
        let stageMultiplier: Float
        switch stage {
        case .seedling: stageMultiplier = 0.6
        case .growing: stageMultiplier = 0.8
        case .mature: stageMultiplier = 1.0
        }

        return baseScale * speciesMultiplier * stageMultiplier
    }
}

// MARK: - GrowthStage CaseIterable

extension GardenAssetLoader.GrowthStage: CaseIterable {
    static var allCases: [GardenAssetLoader.GrowthStage] {
        [.seedling, .growing, .mature]
    }
}
