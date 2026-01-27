import Foundation

/// Loads USDZ assets for the garden
/// Framework-agnostic - provides URLs that SceneKit or RealityKit can load
class GardenAssetLoader {
    static let shared = GardenAssetLoader()

    private init() {}

    // MARK: - Growth Stage

    enum GrowthStage: Int, CaseIterable {
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

    // MARK: - Get Model URL (for SceneKit)

    /// Get the URL for a plant model based on species and growth progress
    func getModelURL(for species: PlantSpecies, growthProgress: Double) -> URL? {
        let stage = GrowthStage.from(progress: growthProgress)
        let modelName = assetName(for: species, stage: stage)
        return getModelURL(named: modelName)
    }

    /// Get the URL for a model by name
    func getModelURL(named name: String) -> URL? {
        // Try various bundle paths for USDZ files
        let searchPaths: [String?] = [
            "GardenAssets",
            "Resources/GardenAssets",
            nil  // Root bundle
        ]

        for subdirectory in searchPaths {
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: subdirectory) {
                return url
            }
        }

        print("⚠️ [AssetLoader] Model not found: \(name).usdz")
        return nil
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
            switch stage {
            case .seedling: return "tree_small"
            case .growing: return "tree_default"
            case .mature: return "tree_detailed"
            }

        case .cherry:
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

    // MARK: - Scale Factors

    /// Get scale factor for species (some models need adjustment)
    func scaleFactor(for species: PlantSpecies, stage: GrowthStage) -> Float {
        let baseScale: Float = 0.3

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

        let stageMultiplier: Float
        switch stage {
        case .seedling: stageMultiplier = 0.6
        case .growing: stageMultiplier = 0.8
        case .mature: stageMultiplier = 1.0
        }

        return baseScale * speciesMultiplier * stageMultiplier
    }

    // MARK: - Available Assets

    /// List all available USDZ files in the bundle
    func listAvailableAssets() -> [String] {
        var assets: [String] = []

        let searchPaths: [String?] = ["GardenAssets", "Resources/GardenAssets", nil]

        for subdirectory in searchPaths {
            if let resourcePath = subdirectory.flatMap({ Bundle.main.path(forResource: nil, ofType: nil, inDirectory: $0) }) ?? Bundle.main.resourcePath {
                let fileManager = FileManager.default
                if let files = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                    let usdzFiles = files.filter { $0.hasSuffix(".usdz") }
                        .map { $0.replacingOccurrences(of: ".usdz", with: "") }
                    assets.append(contentsOf: usdzFiles)
                }
            }
        }

        return Array(Set(assets)).sorted()
    }
}
