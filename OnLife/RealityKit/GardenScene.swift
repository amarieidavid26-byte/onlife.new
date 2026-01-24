import RealityKit
import Combine
import UIKit

@MainActor
class GardenScene: ObservableObject {
    // Root anchor for all garden content
    let rootAnchor: AnchorEntity

    // Key entities
    private var groundEntity: ModelEntity?
    private var cameraAnchor: AnchorEntity?
    private var sunLight: DirectionalLight?
    private var moonLight: DirectionalLight?
    private var ambientLight: PointLight?

    // Plant management (internal for extension access)
    var plantEntities: [UUID: Entity] = [:]
    private let plantFactory = PlantEntityFactory()

    // Systems
    private let windSystem = WindSystem.shared
    private let dayNightSystem = DayNightSystem.shared
    private let particleManager = ParticleManager.shared

    // Camera state
    private(set) var currentZoom: Float = 1.0
    private var cameraOrbitAngle: Float = 0.0
    private var cameraPitchAngle: Float = Float.pi / 6  // 30 degrees
    private let cameraDistance: Float = 8.0

    // ARView reference for camera manipulation
    private weak var arView: ARView?

    // Update subscription
    private var updateSubscription: Cancellable?

    init() {
        // Create root anchor at world origin
        rootAnchor = AnchorEntity(world: .zero)

        setupGround()
        setupLighting()
        setupWind()
        setupParticles()
        setupNotifications()

        print("🌳 [Garden3D] Scene initialized")
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .focusOnPlant,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let plantID = notification.object as? UUID {
                Task { @MainActor in
                    self?.focusOnPlant(plantID)
                }
            }
        }
    }

    // MARK: - Wind Setup

    private func setupWind() {
        windSystem.attach(to: rootAnchor)
        windSystem.start()

        // Set default breeze
        windSystem.windPreset = .breeze

        print("🌬️ [Garden3D] Wind system active")
    }

    // MARK: - Setup

    private func setupGround() {
        // Create stylized ground plane
        let groundMesh = MeshResource.generatePlane(width: 20, depth: 20, cornerRadius: 0.5)

        // Ground material - earthy green (forest floor)
        var groundMaterial = SimpleMaterial()
        groundMaterial.color = .init(
            tint: UIColor(red: 0.15, green: 0.25, blue: 0.12, alpha: 1.0),
            texture: nil
        )
        groundMaterial.roughness = .float(0.95)
        groundMaterial.metallic = .float(0.0)

        let ground = ModelEntity(mesh: groundMesh, materials: [groundMaterial])
        ground.name = "Ground"
        ground.position = .zero

        // Add subtle grid tiles for visual interest
        addGroundTiles(to: ground)

        rootAnchor.addChild(ground)
        groundEntity = ground

        print("🌳 [Garden3D] Ground created")
    }

    private func addGroundTiles(to ground: ModelEntity) {
        let tileSize: Float = 1.6
        let tileSpacing: Float = 1.8
        let gridSize = 6

        for x in -gridSize/2..<gridSize/2 {
            for z in -gridSize/2..<gridSize/2 {
                let tileMesh = MeshResource.generatePlane(width: tileSize, depth: tileSize, cornerRadius: 0.15)

                // Slight color variation for organic feel
                let variation = Float.random(in: 0.85...1.15)
                var tileMaterial = SimpleMaterial()
                tileMaterial.color = .init(
                    tint: UIColor(
                        red: CGFloat(0.18 * Double(variation)),
                        green: CGFloat(0.30 * Double(variation)),
                        blue: CGFloat(0.14 * Double(variation)),
                        alpha: 1.0
                    ),
                    texture: nil
                )
                tileMaterial.roughness = .float(0.9)

                let tile = ModelEntity(mesh: tileMesh, materials: [tileMaterial])
                tile.position = SIMD3<Float>(
                    Float(x) * tileSpacing,
                    0.002,  // Slightly above ground to prevent z-fighting
                    Float(z) * tileSpacing
                )

                ground.addChild(tile)
            }
        }
    }

    private func setupLighting() {
        // Directional light (sun)
        let sun = DirectionalLight()
        sun.light.color = UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
        sun.light.intensity = 12000

        // Enable shadows for depth
        sun.shadow = DirectionalLightComponent.Shadow(
            maximumDistance: 25,
            depthBias: 0.5
        )

        // Position sun for pleasant shadows
        sun.look(at: .zero, from: SIMD3<Float>(5, 10, 5), relativeTo: nil)

        rootAnchor.addChild(sun)
        sunLight = sun

        // Moon light (for night)
        let moon = DirectionalLight()
        moon.light.color = UIColor(red: 0.7, green: 0.75, blue: 0.9, alpha: 1.0)
        moon.light.intensity = 2000
        moon.shadow = DirectionalLightComponent.Shadow(
            maximumDistance: 15,
            depthBias: 0.5
        )
        moon.isEnabled = false
        moon.look(at: .zero, from: SIMD3<Float>(-5, 8, -5), relativeTo: nil)

        rootAnchor.addChild(moon)
        moonLight = moon

        // Ambient/fill light
        let ambient = PointLight()
        ambient.light.color = UIColor(red: 0.6, green: 0.65, blue: 0.7, alpha: 1.0)
        ambient.light.intensity = 4000
        ambient.light.attenuationRadius = 50
        ambient.position = SIMD3<Float>(0, 8, 0)

        rootAnchor.addChild(ambient)
        ambientLight = ambient

        // Secondary fill from opposite side
        let fill = PointLight()
        fill.light.color = UIColor(red: 0.5, green: 0.55, blue: 0.6, alpha: 1.0)
        fill.light.intensity = 2000
        fill.light.attenuationRadius = 30
        fill.position = SIMD3<Float>(-5, 5, -5)

        rootAnchor.addChild(fill)

        // Setup day/night system with lights
        dayNightSystem.setup(
            sunLight: sun,
            moonLight: moon,
            ambientLight: ambient
        )

        print("🌅 [Garden3D] Lighting + Day/Night configured")
    }

    // MARK: - Particles Setup

    private func setupParticles() {
        particleManager.attach(to: rootAnchor)
        print("✨ [Garden3D] Particle system active")
    }

    func setupCamera(in arView: ARView) {
        self.arView = arView

        // In nonAR mode, we manipulate the scene's transform to simulate camera movement
        // Set initial camera position
        updateCameraPosition()

        print("🌳 [Garden3D] Camera configured")
    }

    // MARK: - Camera Control

    func updateCameraPosition() {
        // Calculate camera position on orbit around origin
        let distance = cameraDistance * currentZoom
        let x = distance * sin(cameraOrbitAngle) * cos(cameraPitchAngle)
        let y = distance * sin(cameraPitchAngle) + 2.0  // Add height offset
        let z = distance * cos(cameraOrbitAngle) * cos(cameraPitchAngle)

        // In RealityKit nonAR mode, we rotate the entire scene inversely
        // to simulate camera orbiting
        let cameraPosition = SIMD3<Float>(x, y, z)

        // Calculate rotation to look at center
        let lookAtTarget = SIMD3<Float>(0, 0.5, 0)  // Look slightly above ground
        _ = normalize(lookAtTarget - cameraPosition)  // Direction for future use

        // Apply inverse transform to root anchor
        // This creates the illusion of camera movement
        var transform = Transform.identity
        transform.translation = -cameraPosition * 0.1  // Scale down movement
        transform.rotation = simd_quatf(angle: -cameraOrbitAngle, axis: SIMD3<Float>(0, 1, 0))

        rootAnchor.transform = transform
    }

    func orbitCamera(deltaX: Float, deltaY: Float) {
        let sensitivity: Float = 0.008

        cameraOrbitAngle += deltaX * sensitivity
        cameraPitchAngle = max(0.15, min(Float.pi / 2.5, cameraPitchAngle - deltaY * sensitivity))

        updateCameraPosition()
    }

    func setZoom(_ zoom: Float) {
        currentZoom = max(0.5, min(2.5, zoom))
        updateCameraPosition()
    }

    func resetCamera() {
        // Animate back to default position
        cameraOrbitAngle = 0
        cameraPitchAngle = Float.pi / 6
        currentZoom = 1.0
        updateCameraPosition()
        print("🌳 [Garden3D] Camera reset")
    }

    // MARK: - Plant Management

    func syncPlants(_ plants: [Plant]) {
        let currentIDs = Set(plantEntities.keys)
        let newIDs = Set(plants.map { $0.id })

        // Remove deleted plants
        for id in currentIDs.subtracting(newIDs) {
            if let entity = plantEntities[id] {
                entity.removeFromParent()
                plantEntities.removeValue(forKey: id)
                print("🌳 [Garden3D] Removed plant: \(id)")
            }
        }

        // Add new plants
        for plant in plants where !currentIDs.contains(plant.id) {
            addPlant(plant)
        }

        // Update existing plants (growth, health)
        for plant in plants where currentIDs.contains(plant.id) {
            updatePlant(plant)
        }
    }

    private func addPlant(_ plant: Plant) {
        let entity = plantFactory.createPlant(for: plant)

        // Position in garden using spiral pattern
        let index = plantEntities.count
        let position = calculatePlantPosition(index: index)
        entity.position = position
        entity.name = plant.id.uuidString

        // Spawn animation - start tiny
        entity.scale = SIMD3<Float>(repeating: 0.01)
        rootAnchor.addChild(entity)

        // Animate scale up with bounce
        var targetTransform = entity.transform
        targetTransform.scale = SIMD3<Float>(repeating: 1.0)
        entity.move(to: targetTransform, relativeTo: entity.parent, duration: 0.6, timingFunction: .easeOut)

        plantEntities[plant.id] = entity

        // Re-initialize wind for the new plant
        windSystem.reinitialize()

        // Add plant-specific particles (disabled for stability)
        particleManager.addPlantParticles(to: entity, species: plant.species)

        print("🌱 [Garden3D] Added plant: \(plant.species.rawValue) at position \(position)")
        print("🌱 [Garden3D] Total entities in scene: \(rootAnchor.children.count)")
        print("🌱 [Garden3D] Plant entities tracked: \(plantEntities.count)")
    }

    /// Called when a plant grows - triggers celebration sparkles
    func onPlantGrew(plantID: UUID) {
        if let entity = plantEntities[plantID] {
            let position = entity.position(relativeTo: nil)
            particleManager.triggerSparkles(at: position + SIMD3<Float>(0, 0.5, 0))
        }
    }

    /// Trigger celebration effect for achievements
    func triggerCelebration(at plantID: UUID? = nil) {
        if let id = plantID, let entity = plantEntities[id] {
            let position = entity.position(relativeTo: nil)
            particleManager.triggerCelebration(at: position + SIMD3<Float>(0, 0.3, 0))
        } else {
            // Celebrate at center of garden
            particleManager.triggerCelebration(at: SIMD3<Float>(0, 1, 0))
        }
    }

    private func updatePlant(_ plant: Plant) {
        guard let entity = plantEntities[plant.id] else { return }

        // Scale based on growth (0.6 to 1.2)
        let growthScale = Float(0.6 + plant.growthProgress * 0.6)

        // Apply updates with animation
        var targetTransform = entity.transform
        targetTransform.scale = SIMD3<Float>(repeating: growthScale)
        entity.move(to: targetTransform, relativeTo: entity.parent, duration: 0.3)

        // Update plant appearance based on health
        plantFactory.updatePlantHealth(entity: entity, health: plant.healthLevel)
    }

    private func calculatePlantPosition(index: Int) -> SIMD3<Float> {
        // Golden angle spiral for organic placement
        let goldenAngle: Float = 2.39996  // ~137.5 degrees in radians
        let angle = Float(index) * goldenAngle
        let radius = 0.8 + sqrt(Float(index)) * 0.6

        let x = cos(angle) * min(radius, 5.0)
        let z = sin(angle) * min(radius, 5.0)

        // Add slight randomness for natural look
        let jitterX = Float.random(in: -0.15...0.15)
        let jitterZ = Float.random(in: -0.15...0.15)

        return SIMD3<Float>(x + jitterX, 0, z + jitterZ)
    }

    func animatePlantSelection(_ plantID: UUID) {
        guard let entity = plantEntities[plantID] else { return }

        // Pulse animation
        let originalScale = entity.scale
        var biggerTransform = entity.transform
        biggerTransform.scale = originalScale * 1.2

        // Scale up
        entity.move(to: biggerTransform, relativeTo: entity.parent, duration: 0.1, timingFunction: .easeOut)

        // Scale back down
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            var returnTransform = entity.transform
            returnTransform.scale = originalScale
            entity.move(to: returnTransform, relativeTo: entity.parent, duration: 0.15, timingFunction: .easeIn)
        }
    }

    // MARK: - Plant Focus

    /// Focus camera on a specific plant with sparkle effect
    func focusOnPlant(_ plantID: UUID) {
        guard let entity = plantEntities[plantID] else { return }

        // Get plant position
        let plantPosition = entity.position(relativeTo: rootAnchor)

        // Calculate orbit angle to face the plant
        cameraOrbitAngle = atan2(plantPosition.x, plantPosition.z)

        // Zoom in slightly
        currentZoom = 0.7

        // Update camera
        updateCameraPosition()

        // Animate plant selection (pulse)
        animatePlantSelection(plantID)

        // Trigger sparkles on the focused plant
        let worldPosition = entity.position(relativeTo: nil)
        particleManager.triggerSparkles(at: worldPosition + SIMD3<Float>(0, 0.3, 0), count: 15)

        print("🌳 [Garden3D] Focused on plant: \(plantID)")
    }

    // MARK: - Wind Control

    /// Set wind preset (Calm, Breeze, Windy, Stormy)
    func setWindPreset(_ preset: WindSystem.WindPreset) {
        windSystem.windPreset = preset
    }

    /// Get current wind preset
    var currentWindPreset: WindSystem.WindPreset {
        windSystem.windPreset
    }

    /// Trigger a manual gust (e.g., when plant is watered)
    func triggerGust(strength: Float = 0.5) {
        windSystem.triggerGust(strength: strength)
    }

    /// Stop wind animation
    func stopWind() {
        windSystem.stop()
    }

    /// Re-initialize wind after adding new plants
    func refreshWind() {
        windSystem.reinitialize()
    }

    // MARK: - Day/Night Control

    /// Get current time of day phase
    var currentTimePhase: DayNightSystem.DayPhase {
        dayNightSystem.currentPhase
    }

    /// Jump to specific time phase
    func jumpToTimePhase(_ phase: DayNightSystem.DayPhase) {
        dayNightSystem.jumpToPhase(phase)
    }

    /// Start time-lapse demo mode
    func startTimeLapse(speed: Float = 120) {
        dayNightSystem.startTimeLapse(speed: speed)
    }

    /// Return to real time
    func returnToRealTime() {
        dayNightSystem.returnToRealTime()
    }

    // MARK: - Particle Control

    /// Enable/disable particle effects
    func setParticlesEnabled(_ enabled: Bool) {
        particleManager.setEnabled(enabled)
    }

    // MARK: - App Lifecycle

    /// Pause animations when app enters background
    func onEnterBackground() {
        windSystem.pause()
        print("🌬️ [Garden3D] Paused (background)")
    }

    /// Resume animations when app returns to foreground
    func onEnterForeground() {
        windSystem.resume()
        dayNightSystem.syncToRealTime()
        print("🌬️ [Garden3D] Resumed (foreground)")
    }

    /// Full cleanup
    func cleanup() {
        windSystem.stop()
        dayNightSystem.stop()
        particleManager.removeAllParticles()
    }
}
