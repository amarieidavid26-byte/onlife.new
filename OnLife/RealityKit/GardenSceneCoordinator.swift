import Foundation
import RealityKit
import Combine
import UIKit
import os.log

/// Central coordinator managing all 3D garden systems
/// Handles initialization, lifecycle, and inter-system communication
@MainActor
class GardenSceneCoordinator: ObservableObject {

    // MARK: - Singleton

    static let shared = GardenSceneCoordinator()

    // MARK: - Published State

    @Published private(set) var isInitialized = false
    @Published private(set) var initializationProgress: Float = 0
    @Published private(set) var initializationStatus: String = "Preparing..."
    @Published private(set) var currentError: GardenError?

    // MARK: - System References

    let windSystem = WindSystem.shared
    let dayNightSystem = DayNightSystem.shared
    let particleManager = ParticleManager.shared
    let performanceMonitor = PerformanceMonitor.shared
    let assetLoader = PlantAssetLoader.shared

    // MARK: - State

    private(set) var gardenScene: GardenScene?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.onlife", category: "GardenCoordinator")

    // MARK: - Error Types

    enum GardenError: LocalizedError, Equatable {
        case sceneCreationFailed
        case assetLoadingFailed(String)
        case systemInitializationFailed(String)
        case memoryPressure
        case thermalCritical

        var errorDescription: String? {
            switch self {
            case .sceneCreationFailed:
                return "Failed to create garden scene"
            case .assetLoadingFailed(let asset):
                return "Failed to load asset: \(asset)"
            case .systemInitializationFailed(let system):
                return "Failed to initialize \(system)"
            case .memoryPressure:
                return "Low memory - reducing quality"
            case .thermalCritical:
                return "Device overheating - reducing effects"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        setupPerformanceAdaptation()
        setupMemoryWarningHandler()
        logger.info("GardenSceneCoordinator created")
    }

    // MARK: - Async Initialization

    /// Initialize all garden systems
    /// Call this before presenting the garden view
    func initialize() async {
        guard !isInitialized else {
            logger.info("Already initialized, skipping")
            return
        }

        logger.info("Beginning garden initialization")

        do {
            // Step 1: Preload common assets
            updateProgress(0.1, status: "Loading assets...")
            try await preloadAssets()

            // Step 2: Start performance monitoring
            updateProgress(0.3, status: "Starting monitoring...")
            performanceMonitor.startMonitoring()

            // Step 3: Initialize day/night system
            updateProgress(0.5, status: "Configuring lighting...")
            // DayNightSystem starts automatically via setup() in GardenScene
            dayNightSystem.syncToRealTime()

            // Step 4: Prepare particle system
            updateProgress(0.7, status: "Preparing effects...")
            // Particles initialize lazily when attached

            // Step 5: Wind system ready
            updateProgress(0.9, status: "Finalizing...")
            // Wind initializes when attached to scene

            // Complete
            updateProgress(1.0, status: "Ready")
            isInitialized = true
            currentError = nil

            logger.info("Garden initialization complete")

        } catch {
            logger.error("Initialization failed: \(error.localizedDescription)")
            currentError = .systemInitializationFailed(error.localizedDescription)
        }
    }

    private func preloadAssets() async throws {
        // Preload common plant assets for faster scene population
        // Use PlantAssetLoader's preload method
        await assetLoader.preloadAllAssets()
    }

    private func updateProgress(_ progress: Float, status: String) {
        initializationProgress = progress
        initializationStatus = status
    }

    // MARK: - Scene Management

    /// Create a new garden scene
    /// Returns the created scene for use in the view
    func createScene() -> GardenScene {
        let scene = GardenScene()
        self.gardenScene = scene
        logger.info("Garden scene created")
        return scene
    }

    /// Attach coordinator to an existing scene
    func attach(to scene: GardenScene) {
        self.gardenScene = scene
        logger.info("Attached to existing scene")
    }

    // MARK: - Performance Adaptation

    private func setupPerformanceAdaptation() {
        NotificationCenter.default.publisher(for: .performanceLevelDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let level = notification.object as? PerformanceMonitor.PerformanceLevel else { return }
                self?.adaptToPerformanceLevel(level)
            }
            .store(in: &cancellables)
    }

    private func adaptToPerformanceLevel(_ level: PerformanceMonitor.PerformanceLevel) {
        logger.info("Adapting to performance level: \(level.rawValue)")

        // Adapt wind system
        if level.windEnabled {
            windSystem.resume()
        } else {
            windSystem.pause()
        }

        // Adapt particles
        particleManager.setEnabled(level.particlesEnabled)
        particleManager.setIntensity(level.particleMultiplier)

        // Adapt lighting quality
        adaptLightingQuality(for: level)

        // Show warning for critical level
        if level == .critical {
            currentError = .thermalCritical
        } else if currentError == .thermalCritical {
            currentError = nil
        }
    }

    private func adaptLightingQuality(for level: PerformanceMonitor.PerformanceLevel) {
        // Reduce shadow quality at lower performance levels
        // This would require access to the directional light entities
        // For now, we'll signal the scene to handle this
        NotificationCenter.default.post(
            name: .gardenShouldAdaptQuality,
            object: level
        )
    }

    // MARK: - Memory Warning

    private func setupMemoryWarningHandler() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }

    private func handleMemoryWarning() {
        logger.warning("Memory warning received - reducing garden quality")

        // Force low performance mode
        performanceMonitor.forceLevel(.low)

        // Clear asset cache
        assetLoader.clearCache()

        // Remove non-essential particles
        particleManager.removeAllParticles()

        currentError = .memoryPressure

        // Clear error after 5 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if currentError == .memoryPressure {
                currentError = nil
            }
        }
    }

    // MARK: - App Lifecycle

    func onEnterBackground() {
        logger.info("Entering background")

        // Pause all systems to save battery
        windSystem.pause()
        // DayNightSystem doesn't have pause - it will resume on foreground
        particleManager.setEnabled(false)
        performanceMonitor.stopMonitoring()

        gardenScene?.onEnterBackground()
    }

    func onEnterForeground() {
        logger.info("Returning to foreground")

        // Resume systems based on current performance level
        let level = performanceMonitor.performanceLevel
        performanceMonitor.startMonitoring()

        if level.windEnabled {
            windSystem.resume()
        }

        dayNightSystem.syncToRealTime()

        if level.particlesEnabled {
            particleManager.setEnabled(true)
        }

        gardenScene?.onEnterForeground()
    }

    // MARK: - Cleanup

    func cleanup() {
        logger.info("Cleaning up garden systems")

        windSystem.stop()
        dayNightSystem.stop()
        particleManager.removeAllParticles()
        performanceMonitor.stopMonitoring()
        assetLoader.clearCache()

        gardenScene?.cleanup()
        gardenScene = nil

        isInitialized = false
        currentError = nil

        cancellables.removeAll()

        logger.info("Cleanup complete")
    }

    // MARK: - Debug

    var systemStatus: String {
        """
        Initialized: \(isInitialized)
        Performance: \(performanceMonitor.performanceLevel.rawValue)
        FPS: \(String(format: "%.1f", performanceMonitor.averageFPS))
        Memory: \(String(format: "%.1f", performanceMonitor.memoryUsageMB)) MB
        Thermal: \(performanceMonitor.thermalState == .nominal ? "OK" : "Warning")
        Wind: \(windSystem.windPreset.rawValue)
        Time: \(dayNightSystem.currentPhase.rawValue)
        """
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let gardenShouldAdaptQuality = Notification.Name("gardenShouldAdaptQuality")
}
