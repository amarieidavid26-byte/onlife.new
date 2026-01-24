import RealityKit
import Combine
import os.log
import UIKit

/// Loads and caches plant 3D assets with preloading support
/// Singleton manager that handles USDZ/Reality file loading
@MainActor
class PlantAssetLoader: ObservableObject {

    static let shared = PlantAssetLoader()

    // MARK: - Published State

    @Published private(set) var isPreloading = false
    @Published private(set) var preloadProgress: Double = 0.0
    @Published private(set) var preloadedCount: Int = 0
    @Published private(set) var totalAssets: Int = 0
    @Published private(set) var failedAssets: [String] = []
    @Published private(set) var isReady = false

    // MARK: - Cache

    /// Cached loaded entities by asset name
    private var entityCache: [String: Entity] = [:]

    /// Track which assets exist on disk
    private var availableAssets: Set<String> = []

    /// Track load attempts to avoid retrying missing assets
    private var attemptedAssets: Set<String> = []

    /// Logger for debugging
    private let logger = Logger(subsystem: "com.onlife.garden", category: "PlantAssetLoader")

    // MARK: - Configuration

    /// Maximum concurrent asset loads
    private let maxConcurrentLoads = 4

    /// Whether to log detailed progress
    var verboseLogging = false

    // MARK: - Initialization

    private init() {
        scanAvailableAssets()
        logger.info("📦 [PlantAssetLoader] Initialized")
    }

    // MARK: - Asset Discovery

    /// Scan bundle for available USDZ and Reality files
    private func scanAvailableAssets() {
        guard let resourcePath = Bundle.main.resourcePath else {
            logger.warning("📦 [PlantAssetLoader] Could not access resource path")
            return
        }

        let fileManager = FileManager.default

        do {
            let files = try fileManager.contentsOfDirectory(atPath: resourcePath)
            for file in files {
                if file.hasSuffix(".usdz") {
                    let name = file.replacingOccurrences(of: ".usdz", with: "")
                    availableAssets.insert(name)
                    if verboseLogging {
                        logger.debug("📦 Found USDZ: \(name)")
                    }
                } else if file.hasSuffix(".reality") {
                    let name = file.replacingOccurrences(of: ".reality", with: "")
                    availableAssets.insert(name)
                    if verboseLogging {
                        logger.debug("📦 Found Reality: \(name)")
                    }
                }
            }
        } catch {
            logger.error("📦 [PlantAssetLoader] Failed to scan resources: \(error.localizedDescription)")
        }

        // Also check for bundled Reality Composer Pro projects
        if Bundle.main.url(forResource: "Plants", withExtension: "reality") != nil {
            availableAssets.insert("Plants")
            logger.info("📦 Found Plants.reality bundle")
        }

        logger.info("📦 [PlantAssetLoader] Found \(self.availableAssets.count) available 3D assets")
    }

    /// Check if an asset file exists in the bundle
    func hasAsset(named name: String) -> Bool {
        if availableAssets.contains(name) {
            return true
        }
        // Double check with direct URL lookup
        return Bundle.main.url(forResource: name, withExtension: "usdz") != nil ||
               Bundle.main.url(forResource: name, withExtension: "reality") != nil
    }

    // MARK: - Preloading

    /// Preload all plant assets at app launch
    /// Call this during splash screen / loading phase
    func preloadAllAssets() async {
        guard !isPreloading else {
            logger.warning("📦 [PlantAssetLoader] Preload already in progress")
            return
        }

        isPreloading = true
        preloadProgress = 0.0
        preloadedCount = 0
        failedAssets = []

        // Gather all asset names we need to load
        var allAssetNames: [String] = []
        for (_, definition) in PlantAssetManifest.plants {
            // Only load high LOD for now (others can be loaded on demand)
            allAssetNames.append(contentsOf: definition.primaryAssetNames)
        }

        totalAssets = allAssetNames.count
        logger.info("📦 [PlantAssetLoader] Starting preload of \(self.totalAssets) assets...")

        let startTime = CFAbsoluteTimeGetCurrent()

        // Load in parallel with concurrency limit
        await withTaskGroup(of: (String, Bool).self) { group in
            var pending = allAssetNames
            var inFlight = 0

            while !pending.isEmpty || inFlight > 0 {
                // Add tasks up to concurrency limit
                while inFlight < maxConcurrentLoads && !pending.isEmpty {
                    let assetName = pending.removeFirst()
                    inFlight += 1

                    group.addTask { [weak self] in
                        guard let self = self else { return (assetName, false) }
                        let success = await self.loadAsset(named: assetName)
                        return (assetName, success)
                    }
                }

                // Wait for one to complete
                if let result = await group.next() {
                    inFlight -= 1
                    preloadedCount += 1
                    preloadProgress = Double(preloadedCount) / Double(totalAssets)

                    if !result.1 && hasAsset(named: result.0) {
                        // Only log as failed if asset was supposed to exist
                        failedAssets.append(result.0)
                    }
                }
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        isPreloading = false
        isReady = true

        logger.info("📦 [PlantAssetLoader] Preload complete in \(String(format: "%.2f", elapsed))s")
        logger.info("📦 [PlantAssetLoader] Loaded: \(self.preloadedCount - self.failedAssets.count)/\(self.totalAssets)")

        if !failedAssets.isEmpty {
            logger.warning("📦 [PlantAssetLoader] Failed assets: \(self.failedAssets.joined(separator: ", "))")
        }
    }

    /// Load a single asset into cache
    @discardableResult
    private func loadAsset(named name: String) async -> Bool {
        // Skip if already cached
        if entityCache[name] != nil {
            return true
        }

        // Skip if we already tried and failed
        if attemptedAssets.contains(name) && !hasAsset(named: name) {
            return false
        }

        attemptedAssets.insert(name)

        // Skip if asset doesn't exist (will use procedural fallback)
        guard hasAsset(named: name) else {
            if verboseLogging {
                logger.debug("📦 Asset not found: \(name) (will use procedural)")
            }
            return false
        }

        do {
            // Try .usdz first
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
                let entity = try await Entity(contentsOf: url)
                entityCache[name] = entity
                if verboseLogging {
                    logger.debug("📦 Loaded: \(name).usdz")
                }
                return true
            }

            // Try .reality file
            if let entity = try? await Entity(named: name, in: nil) {
                entityCache[name] = entity
                if verboseLogging {
                    logger.debug("📦 Loaded: \(name) from .reality")
                }
                return true
            }

            logger.warning("📦 Could not load asset: \(name)")
            return false

        } catch {
            logger.error("📦 Failed to load \(name): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Entity Retrieval

    /// Get a cached entity (cloned for use in scene)
    /// Returns nil if asset not loaded - caller should use procedural fallback
    func getEntity(
        for species: PlantSpecies,
        stage: PlantAssetManifest.GrowthStage,
        lod: PlantAssetManifest.LODLevel = .high
    ) -> Entity? {
        guard let definition = PlantAssetManifest.definition(for: species) else {
            return nil
        }

        let assetName = definition.assetName(for: stage, lod: lod)

        // Return clone of cached entity
        if let cached = entityCache[assetName] {
            return cached.clone(recursive: true)
        }

        // Try without LOD suffix (fallback to high LOD)
        if lod != .high {
            let baseAssetName = definition.assetName(for: stage, lod: .high)
            if let cached = entityCache[baseAssetName] {
                return cached.clone(recursive: true)
            }
        }

        return nil
    }

    /// Get entity with automatic fallback to adjacent stages
    func getEntityWithFallback(
        for species: PlantSpecies,
        stage: PlantAssetManifest.GrowthStage
    ) -> Entity? {
        // Try exact match first
        if let entity = getEntity(for: species, stage: stage) {
            return entity
        }

        // Try adjacent stages
        let allStages = PlantAssetManifest.GrowthStage.allCases
        guard let currentIndex = allStages.firstIndex(of: stage) else {
            return nil
        }

        // Try one stage earlier
        if currentIndex > 0 {
            if let entity = getEntity(for: species, stage: allStages[currentIndex - 1]) {
                return entity
            }
        }

        // Try one stage later
        if currentIndex < allStages.count - 1 {
            if let entity = getEntity(for: species, stage: allStages[currentIndex + 1]) {
                return entity
            }
        }

        return nil
    }

    /// Check if a specific asset is loaded
    func isLoaded(species: PlantSpecies, stage: PlantAssetManifest.GrowthStage) -> Bool {
        guard let definition = PlantAssetManifest.definition(for: species) else {
            return false
        }
        let assetName = definition.assetName(for: stage)
        return entityCache[assetName] != nil
    }

    /// Check if any asset is loaded for a species
    func hasAnyAsset(for species: PlantSpecies) -> Bool {
        guard let definition = PlantAssetManifest.definition(for: species) else {
            return false
        }

        for stage in PlantAssetManifest.GrowthStage.allCases {
            let assetName = definition.assetName(for: stage)
            if entityCache[assetName] != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Memory Management

    /// Clear cache (call on memory warning)
    func clearCache() {
        entityCache.removeAll()
        attemptedAssets.removeAll()
        isReady = false
        logger.info("📦 [PlantAssetLoader] Asset cache cleared")
    }

    /// Clear cache for specific species
    func clearCache(for species: PlantSpecies) {
        guard let definition = PlantAssetManifest.definition(for: species) else { return }

        for name in definition.allAssetNames {
            entityCache.removeValue(forKey: name)
            attemptedAssets.remove(name)
        }

        logger.debug("📦 Cleared cache for \(species.rawValue)")
    }

    /// Get current memory usage estimate (bytes)
    var estimatedMemoryUsage: Int {
        // Rough estimate: ~1-5MB per high-quality USDZ asset
        return entityCache.count * 2_500_000  // 2.5MB average
    }

    /// Get formatted memory usage string
    var formattedMemoryUsage: String {
        let bytes = estimatedMemoryUsage
        if bytes < 1_000_000 {
            return "\(bytes / 1000) KB"
        } else {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        }
    }

    // MARK: - Statistics

    /// Number of cached entities
    var cachedEntityCount: Int {
        return entityCache.count
    }

    /// List of all cached asset names
    var cachedAssetNames: [String] {
        return Array(entityCache.keys).sorted()
    }
}
