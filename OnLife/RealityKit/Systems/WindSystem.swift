import RealityKit
import QuartzCore
import Combine
import os.log

/// System that animates wind sway on all entities with WindComponent
/// Uses CADisplayLink for smooth 60fps updates
@MainActor
class WindSystem: ObservableObject {

    // MARK: - Singleton

    static let shared = WindSystem()

    // MARK: - Published State

    @Published private(set) var isRunning = false
    @Published var windPreset: WindPreset = .breeze {
        didSet { applyPreset(windPreset) }
    }

    // MARK: - Wind Parameters

    /// Base wind strength (0-1)
    var windStrength: Float = 0.3

    /// Wind oscillation speed
    var windSpeed: Float = 1.5

    /// Wind direction (normalized XZ vector)
    var windDirection: SIMD2<Float> = normalize(SIMD2<Float>(1, 0.3))

    /// Gust parameters
    var gustStrength: Float = 0.15
    var gustFrequency: Float = 0.3  // Gusts per second average
    var gustDuration: Float = 0.8   // How long a gust lasts

    // MARK: - Internal State

    private var time: Float = 0
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    // Gust state
    private var currentGust: Float = 0
    private var gustTimer: Float = 0
    private var targetGust: Float = 0
    private var gustAttack: Bool = true

    // Scene reference
    private weak var rootEntity: Entity?

    // Logging
    private let logger = Logger(subsystem: "com.onlife", category: "WindSystem")

    // MARK: - Presets

    enum WindPreset: String, CaseIterable {
        case calm = "Calm"
        case breeze = "Breeze"
        case windy = "Windy"
        case stormy = "Stormy"

        var icon: String {
            switch self {
            case .calm: return "wind"
            case .breeze: return "wind"
            case .windy: return "wind.snow"
            case .stormy: return "tornado"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        applyPreset(.breeze)
    }

    // MARK: - Setup

    /// Attach wind system to a scene's root entity
    func attach(to root: Entity) {
        self.rootEntity = root

        // Initialize base orientations for all wind components
        initializeWindComponents(in: root)

        logger.info("Wind system attached to scene")
    }

    /// Recursively initialize wind components
    private func initializeWindComponents(in entity: Entity) {
        if var wind = entity.components[WindComponent.self] {
            // Store current orientation as base
            wind.baseOrientation = entity.orientation

            // Calculate world height for height-based sway
            wind.worldHeight = entity.position(relativeTo: nil).y

            entity.components[WindComponent.self] = wind
        }

        for child in entity.children {
            initializeWindComponents(in: child)
        }
    }

    // MARK: - Control

    /// Start wind animation
    func start() {
        guard !isRunning else { return }

        displayLink = CADisplayLink(target: self, selector: #selector(update(_:)))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)

        isRunning = true
        logger.info("Wind system started")
    }

    /// Stop wind animation
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
        logger.info("Wind system stopped")
    }

    /// Pause when app goes to background
    func pause() {
        displayLink?.isPaused = true
    }

    /// Resume when app comes to foreground
    func resume() {
        displayLink?.isPaused = false
    }

    // MARK: - Update Loop

    @objc private func update(_ displayLink: CADisplayLink) {
        // Calculate delta time
        let currentTime = displayLink.timestamp
        var deltaTime = Float(currentTime - lastTimestamp)
        lastTimestamp = currentTime

        // Clamp delta time to prevent huge jumps
        deltaTime = min(deltaTime, 0.1)

        // Skip first frame (no valid delta)
        guard deltaTime > 0 && deltaTime < 0.1 else { return }

        // Advance time
        time += deltaTime

        // Update gust
        updateGust(deltaTime: deltaTime)

        // Calculate current wind values
        let windValues = calculateWindValues()

        // Update all entities
        guard let root = rootEntity else { return }
        updateEntitiesRecursive(entity: root, wind: windValues)
    }

    // MARK: - Wind Calculation

    private struct WindValues {
        let primarySway: Float      // Slow, large movement
        let secondarySway: Float    // Medium frequency
        let tertiarySway: Float     // Fast flutter
        let gustMultiplier: Float   // Current gust strength
        let time: Float             // For phase calculations
    }

    private func calculateWindValues() -> WindValues {
        // Primary sway: slow, large movement (like whole tree swaying)
        let primarySway = sin(time * windSpeed * 0.7) * windStrength

        // Secondary sway: medium frequency (like branches)
        let secondarySway = sin(time * windSpeed * 1.5) * windStrength * 0.5

        // Tertiary flutter: fast, small movement (like leaves)
        let tertiarySway = sin(time * windSpeed * 4.0) * windStrength * 0.2

        // Gust multiplier
        let gustMultiplier = 1.0 + currentGust

        return WindValues(
            primarySway: primarySway,
            secondarySway: secondarySway,
            tertiarySway: tertiarySway,
            gustMultiplier: gustMultiplier,
            time: time
        )
    }

    // MARK: - Gust System

    private func updateGust(deltaTime: Float) {
        gustTimer += deltaTime

        // Random chance to trigger new gust
        if currentGust < 0.01 && Float.random(in: 0...1) < gustFrequency * deltaTime {
            targetGust = Float.random(in: gustStrength * 0.5...gustStrength * 1.5)
            gustAttack = true
            gustTimer = 0
        }

        // Gust envelope (attack/decay)
        if gustAttack {
            // Quick attack
            currentGust = min(currentGust + deltaTime * 3.0, targetGust)
            if currentGust >= targetGust * 0.95 {
                gustAttack = false
            }
        } else {
            // Slower decay
            currentGust = max(currentGust - deltaTime * 0.8, 0)
        }
    }

    // MARK: - Entity Updates

    private func updateEntitiesRecursive(entity: Entity, wind: WindValues) {
        // Update this entity if it has wind component
        if var windComp = entity.components[WindComponent.self] {
            applyWind(to: entity, component: &windComp, wind: wind)
            entity.components[WindComponent.self] = windComp
        }

        // Recurse to children
        for child in entity.children {
            updateEntitiesRecursive(entity: child, wind: wind)
        }
    }

    private func applyWind(to entity: Entity, component: inout WindComponent, wind: WindValues) {
        // Calculate phase-shifted time for this entity
        let phaseTime = wind.time + component.phaseOffset
        let uniqueTime = phaseTime * component.frequencyVariation

        // Flexibility factor (inverse of stiffness)
        let flexibility = 1.0 - component.stiffness

        // Calculate sway contributions
        let primary = sin(uniqueTime * 0.7 + component.randomSeed) * wind.primarySway
        let secondary = sin(uniqueTime * 1.5 + component.randomSeed * 0.7) * wind.secondarySway * flexibility
        let tertiary = sin(uniqueTime * 4.0 + component.randomSeed * 1.3) * wind.tertiarySway * flexibility * flexibility

        // Combine sway with height factor
        let totalSway = (primary + secondary + tertiary) * component.swayAmount * component.heightFactor * wind.gustMultiplier

        // Create rotation quaternions
        // Main sway around Z axis (side to side)
        let swayAngleZ = totalSway * 0.12  // ~7 degrees max at full sway
        let swayRotationZ = simd_quatf(angle: swayAngleZ, axis: SIMD3<Float>(0, 0, 1))

        // Secondary sway around X axis (forward/back)
        let swayAngleX = totalSway * 0.04 * sin(uniqueTime * 1.2)
        let swayRotationX = simd_quatf(angle: swayAngleX, axis: SIMD3<Float>(1, 0, 0))

        // Slight twist around Y for realism
        let twistAngle = totalSway * 0.02 * sin(uniqueTime * 0.5)
        let twistRotation = simd_quatf(angle: twistAngle, axis: SIMD3<Float>(0, 1, 0))

        // Combine rotations
        let windRotation = swayRotationZ * swayRotationX * twistRotation

        // Smooth interpolation for less jitter
        let smoothing: Float = 0.3
        component.currentWindRotation = simd_slerp(component.currentWindRotation, windRotation, smoothing)

        // Apply final rotation (base + wind)
        entity.orientation = component.baseOrientation * component.currentWindRotation
    }

    // MARK: - Presets

    private func applyPreset(_ preset: WindPreset) {
        switch preset {
        case .calm:
            windStrength = 0.1
            windSpeed = 0.8
            gustStrength = 0.05
            gustFrequency = 0.1

        case .breeze:
            windStrength = 0.3
            windSpeed = 1.5
            gustStrength = 0.15
            gustFrequency = 0.3

        case .windy:
            windStrength = 0.6
            windSpeed = 2.2
            gustStrength = 0.35
            gustFrequency = 0.5

        case .stormy:
            windStrength = 0.9
            windSpeed = 3.0
            gustStrength = 0.6
            gustFrequency = 0.8
        }

        logger.info("Wind preset: \(preset.rawValue)")
    }

    // MARK: - Manual Gust

    /// Trigger a gust manually (e.g., when plant is watered)
    func triggerGust(strength: Float = 0.5) {
        targetGust = strength
        gustAttack = true
        gustTimer = 0
    }

    /// Set wind direction (angle in radians, 0 = East, π/2 = North)
    func setWindDirection(angle: Float) {
        windDirection = SIMD2<Float>(cos(angle), sin(angle))
    }

    // MARK: - Re-initialization

    /// Re-initialize wind components after scene changes
    func reinitialize() {
        guard let root = rootEntity else { return }
        initializeWindComponents(in: root)
        logger.debug("Wind components reinitialized")
    }
}
