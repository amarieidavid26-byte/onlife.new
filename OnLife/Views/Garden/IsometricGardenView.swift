import SwiftUI
import RealityKit
import Combine

/// Premium isometric 3D garden view with real USDZ models
struct IsometricGardenView: View {
    @ObservedObject var gardenViewModel: GardenViewModel
    @StateObject private var sceneController = IsometricGardenController()

    var body: some View {
        ZStack {
            // 3D Garden
            IsometricARViewContainer(
                controller: sceneController,
                plants: gardenViewModel.plants
            )
            .ignoresSafeArea()

            // Loading overlay
            if sceneController.isLoading {
                loadingOverlay
            }
        }
        .onAppear {
            sceneController.syncPlants(gardenViewModel.plants)
        }
        .onChange(of: gardenViewModel.plants) { _, newPlants in
            sceneController.syncPlants(newPlants)
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading Garden...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

// MARK: - ARView Container

struct IsometricARViewContainer: UIViewRepresentable {
    let controller: IsometricGardenController
    let plants: [Plant]

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Non-AR mode for controlled camera
        arView.cameraMode = .nonAR

        // Set up the scene
        controller.setupScene(in: arView)

        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        // Updates handled through controller
    }
}

// MARK: - Scene Controller

@MainActor
class IsometricGardenController: ObservableObject {
    @Published var isLoading = false

    private var arView: ARView?
    private let rootAnchor = AnchorEntity(world: .zero)
    private var plantEntities: [UUID: Entity] = [:]
    private var groundEntity: ModelEntity?

    private let assetLoader = GardenAssetLoader.shared
    private let windSystem = WindSystem.shared

    // Fixed isometric camera settings
    private let cameraDistance: Float = 6.0
    private let cameraAngle: Float = .pi / 6  // 30 degrees from horizontal
    private let cameraRotation: Float = .pi / 4  // 45 degrees around Y

    func setupScene(in arView: ARView) {
        self.arView = arView

        // Add root anchor to scene
        arView.scene.addAnchor(rootAnchor)

        // Setup ground
        setupGround()

        // Setup lighting
        setupLighting()

        // Setup fixed isometric camera
        setupCamera()

        // Attach wind system
        windSystem.attach(to: rootAnchor)
        windSystem.windPreset = .breeze
        windSystem.start()

        print("🌳 [IsometricGarden] Scene initialized")
    }

    private func setupGround() {
        // Create circular garden bed
        let groundMesh = MeshResource.generatePlane(width: 8, depth: 8, cornerRadius: 4)

        var groundMaterial = SimpleMaterial()
        groundMaterial.color = .init(
            tint: UIColor(red: 0.18, green: 0.28, blue: 0.15, alpha: 1.0),
            texture: nil
        )
        groundMaterial.roughness = .float(0.95)
        groundMaterial.metallic = .float(0.0)

        let ground = ModelEntity(mesh: groundMesh, materials: [groundMaterial])
        ground.name = "Ground"
        ground.position = .zero

        // Add decorative ring
        addGroundRing(to: ground)

        rootAnchor.addChild(ground)
        groundEntity = ground

        print("🌳 [IsometricGarden] Ground created")
    }

    private func addGroundRing(to ground: ModelEntity) {
        // Create outer ring for visual definition
        let ringMesh = MeshResource.generatePlane(width: 8.5, depth: 8.5, cornerRadius: 4.25)

        var ringMaterial = SimpleMaterial()
        ringMaterial.color = .init(
            tint: UIColor(red: 0.12, green: 0.18, blue: 0.10, alpha: 1.0),
            texture: nil
        )
        ringMaterial.roughness = .float(0.9)

        let ring = ModelEntity(mesh: ringMesh, materials: [ringMaterial])
        ring.position = SIMD3<Float>(0, -0.01, 0)  // Slightly below
        ground.addChild(ring)
    }

    private func setupLighting() {
        // Main directional light (sun)
        let sun = DirectionalLight()
        sun.light.color = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
        sun.light.intensity = 10000
        sun.shadow = DirectionalLightComponent.Shadow(
            maximumDistance: 20,
            depthBias: 0.5
        )
        sun.look(at: .zero, from: SIMD3<Float>(4, 8, 4), relativeTo: nil)
        rootAnchor.addChild(sun)

        // Fill light from opposite side
        let fill = PointLight()
        fill.light.color = UIColor(red: 0.7, green: 0.75, blue: 0.85, alpha: 1.0)
        fill.light.intensity = 3000
        fill.light.attenuationRadius = 30
        fill.position = SIMD3<Float>(-3, 5, -3)
        rootAnchor.addChild(fill)

        // Ambient fill
        let ambient = PointLight()
        ambient.light.color = UIColor(red: 0.5, green: 0.55, blue: 0.6, alpha: 1.0)
        ambient.light.intensity = 2000
        ambient.light.attenuationRadius = 40
        ambient.position = SIMD3<Float>(0, 6, 0)
        rootAnchor.addChild(ambient)

        print("💡 [IsometricGarden] Lighting configured")
    }

    private func setupCamera() {
        // Calculate fixed isometric camera position
        let x = cameraDistance * sin(cameraRotation) * cos(cameraAngle)
        let y = cameraDistance * sin(cameraAngle) + 2.0
        let z = cameraDistance * cos(cameraRotation) * cos(cameraAngle)

        let cameraPosition = SIMD3<Float>(x, y, z)

        // Move root anchor to simulate camera position
        // (In nonAR mode, we move the scene inversely)
        var transform = Transform.identity
        transform.translation = -cameraPosition * 0.15
        transform.rotation = simd_quatf(angle: -cameraRotation, axis: SIMD3<Float>(0, 1, 0))

        rootAnchor.transform = transform

        print("📷 [IsometricGarden] Camera set to isometric view")
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
                print("🗑️ [IsometricGarden] Removed plant: \(id)")
            }
        }

        // Add new plants
        for plant in plants where !currentIDs.contains(plant.id) {
            Task {
                await addPlant(plant)
            }
        }

        // Update existing plants
        for plant in plants where currentIDs.contains(plant.id) {
            Task {
                await updatePlant(plant)
            }
        }
    }

    private func addPlant(_ plant: Plant) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load the appropriate model for this plant's growth stage
            let entity = try await assetLoader.loadEntity(for: plant)

            // Calculate position in garden (spiral pattern)
            let index = plantEntities.count
            let position = calculatePlantPosition(index: index)
            entity.position = position
            entity.name = plant.id.uuidString

            // Apply scale based on species and growth
            let stage = GardenAssetLoader.GrowthStage.from(progress: plant.growthProgress)
            let scale = assetLoader.scaleFactor(for: plant.species, stage: stage)
            entity.scale = SIMD3<Float>(repeating: 0.01)  // Start tiny for animation

            // Add wind component for sway
            addWindComponent(to: entity, species: plant.species)

            // Add to scene
            rootAnchor.addChild(entity)
            plantEntities[plant.id] = entity

            // Animate scale up
            var targetTransform = entity.transform
            targetTransform.scale = SIMD3<Float>(repeating: scale)
            entity.move(to: targetTransform, relativeTo: entity.parent, duration: 0.5, timingFunction: .easeOut)

            // Reinitialize wind for new entity
            windSystem.reinitialize()

            print("🌱 [IsometricGarden] Added \(plant.species.rawValue) at \(position)")
            print("🌱 [IsometricGarden] Total plants: \(plantEntities.count)")

        } catch {
            print("❌ [IsometricGarden] Failed to add plant: \(error)")
            // Fallback: create simple placeholder
            addPlaceholder(for: plant)
        }
    }

    private func updatePlant(_ plant: Plant) async {
        guard let currentEntity = plantEntities[plant.id] else { return }

        // Check if growth stage changed
        let currentStage = GardenAssetLoader.GrowthStage.from(progress: plant.growthProgress)
        let expectedAsset = assetLoader.assetName(for: plant.species, stage: currentStage)

        // For simplicity, just update scale. Full model swap would be more complex.
        let scale = assetLoader.scaleFactor(for: plant.species, stage: currentStage)

        var targetTransform = currentEntity.transform
        targetTransform.scale = SIMD3<Float>(repeating: scale)
        currentEntity.move(to: targetTransform, relativeTo: currentEntity.parent, duration: 0.3)
    }

    private func addWindComponent(to entity: Entity, species: PlantSpecies) {
        // Determine sway amount based on plant type
        let swayAmount: Float
        let stiffness: Float

        switch species {
        case .oak, .cherry, .bonsai:
            swayAmount = 0.3
            stiffness = 0.7
        case .bamboo:
            swayAmount = 0.8
            stiffness = 0.2
        case .fern:
            swayAmount = 0.6
            stiffness = 0.3
        case .sunflower, .rose, .lavender, .tulip:
            swayAmount = 0.5
            stiffness = 0.4
        case .cactus:
            swayAmount = 0.1
            stiffness = 0.9
        }

        let windComponent = WindComponent(
            swayAmount: swayAmount,
            stiffness: stiffness,
            phaseOffset: Float.random(in: 0...Float.pi * 2)
        )

        entity.components[WindComponent.self] = windComponent

        // Also add to children for more realistic movement
        for child in entity.children {
            var childWind = windComponent
            childWind.phaseOffset = Float.random(in: 0...Float.pi * 2)
            childWind.swayAmount *= 1.2  // Children sway more
            child.components[WindComponent.self] = childWind
        }
    }

    private func addPlaceholder(for plant: Plant) {
        // Simple sphere placeholder if asset loading fails
        let mesh = MeshResource.generateSphere(radius: 0.15)
        var material = SimpleMaterial()
        material.color = .init(tint: plant.species.color, texture: nil)

        let placeholder = ModelEntity(mesh: mesh, materials: [material])
        placeholder.name = plant.id.uuidString

        let index = plantEntities.count
        placeholder.position = calculatePlantPosition(index: index)

        rootAnchor.addChild(placeholder)
        plantEntities[plant.id] = placeholder

        print("⚠️ [IsometricGarden] Added placeholder for \(plant.species.rawValue)")
    }

    private func calculatePlantPosition(index: Int) -> SIMD3<Float> {
        // Golden angle spiral for organic placement
        let goldenAngle: Float = 2.39996
        let angle = Float(index) * goldenAngle
        let radius = 0.6 + sqrt(Float(index)) * 0.5

        let x = cos(angle) * min(radius, 3.0)
        let z = sin(angle) * min(radius, 3.0)

        // Add slight randomness
        let jitterX = Float.random(in: -0.1...0.1)
        let jitterZ = Float.random(in: -0.1...0.1)

        return SIMD3<Float>(x + jitterX, 0, z + jitterZ)
    }

    // MARK: - Cleanup

    func cleanup() {
        windSystem.stop()
        plantEntities.removeAll()
        rootAnchor.children.removeAll()
    }
}

// MARK: - PlantSpecies Color Extension

extension PlantSpecies {
    var color: UIColor {
        switch self {
        case .oak: return UIColor(red: 0.3, green: 0.5, blue: 0.2, alpha: 1.0)
        case .rose: return UIColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1.0)
        case .cactus: return UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        case .sunflower: return UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)
        case .fern: return UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        case .bamboo: return UIColor(red: 0.5, green: 0.8, blue: 0.3, alpha: 1.0)
        case .lavender: return UIColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1.0)
        case .bonsai: return UIColor(red: 0.4, green: 0.6, blue: 0.3, alpha: 1.0)
        case .cherry: return UIColor(red: 1.0, green: 0.7, blue: 0.8, alpha: 1.0)
        case .tulip: return UIColor(red: 1.0, green: 0.4, blue: 0.5, alpha: 1.0)
        }
    }
}

// MARK: - Preview

#Preview {
    IsometricGardenView(gardenViewModel: GardenViewModel())
}
