import SwiftUI
import SceneKit

/// Nintendo-style isometric garden view using SceneKit
/// Long-press and drag to move plants around the island
struct SceneKitGardenView: UIViewRepresentable {
    let plants: [Plant]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = createGardenScene()

        // Transparent background - let SwiftUI background show through
        scnView.backgroundColor = .clear

        // Reduce GPU load for background rendering
        scnView.antialiasingMode = .none
        scnView.preferredFramesPerSecond = 30
        scnView.allowsCameraControl = true  // Enable pan/zoom/rotate
        scnView.autoenablesDefaultLighting = false

        // LONG PRESS to pick up a plant for moving
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.3
        scnView.addGestureRecognizer(longPressGesture)

        // PAN to move the picked-up plant (only active when dragging)
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        scnView.addGestureRecognizer(panGesture)

        context.coordinator.scnView = scnView

        print("🌿 [Garden] Long-press + drag to move plants")

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {

        // Update plants when data changes
        if let scene = uiView.scene {
            updatePlants(in: scene, plants: plants)
        }
    }

    // MARK: - Coordinator for Gesture Handling

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var scnView: SCNView?

        // Drag-to-move state
        var draggedNode: SCNNode?
        var dragStartPosition: SCNVector3?
        var isDragging: Bool = false

        // MARK: - UIGestureRecognizerDelegate

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow pan gesture to work with long press
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UILongPressGestureRecognizer {
                return true
            }
            if gestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // Only allow pan if we're actively dragging a plant
            if gestureRecognizer is UIPanGestureRecognizer {
                return isDragging
            }
            return true
        }

        // MARK: - Long Press to Pick Up Plant

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let scnView = scnView else { return }

            let location = gesture.location(in: scnView)

            switch gesture.state {
            case .began:
                // Hit test to find if we tapped a plant
                let hitResults = scnView.hitTest(location, options: [
                    .searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue)
                ])

                // Find a plant node
                for hit in hitResults {
                    if let plantNode = findPlantNode(from: hit.node) {
                        draggedNode = plantNode
                        dragStartPosition = plantNode.position
                        isDragging = true

                        // Visual feedback - lift and highlight
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = 0.15
                        plantNode.position.y += 0.5  // Lift up
                        plantNode.scale = SCNVector3(
                            plantNode.scale.x * 1.1,
                            plantNode.scale.y * 1.1,
                            plantNode.scale.z * 1.1
                        )
                        SCNTransaction.commit()

                        print("🌿 [Drag] Picked up plant: \(plantNode.name ?? "unnamed")")
                        break
                    }
                }

            case .ended, .cancelled:
                if let node = draggedNode {
                    // Drop the plant
                    let finalY: Float = 4.6  // Normalize to grass level
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.2
                    node.position.y = finalY
                    node.scale = SCNVector3(
                        node.scale.x / 1.1,
                        node.scale.y / 1.1,
                        node.scale.z / 1.1
                    )
                    SCNTransaction.commit()

                    // Save position to persist across app restarts
                    if let plantIdString = node.name?.replacingOccurrences(of: "plant_", with: ""),
                       let plantId = UUID(uuidString: plantIdString) {
                        let position = PlantPosition(
                            x: node.position.x,
                            y: finalY,
                            z: node.position.z
                        )
                        GardenDataManager.shared.updatePlantPosition(plantId: plantId, position: position)
                        print("💾 [Drag] Saved position for plant \(plantIdString)")
                    }

                    print("🌿 [Drag] Dropped plant at: (\(node.position.x), \(finalY), \(node.position.z))")
                }
                draggedNode = nil
                dragStartPosition = nil
                isDragging = false

            default:
                break
            }
        }

        /// Find the plant node from a hit node (might be a child)
        private func findPlantNode(from node: SCNNode) -> SCNNode? {
            var current: SCNNode? = node
            while let n = current {
                if n.name?.starts(with: "plant_") == true {
                    return n
                }
                current = n.parent
            }
            return nil
        }

        // MARK: - Pan to Move Plant

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard isDragging, let draggedNode = draggedNode, let scnView = scnView else { return }

            let location = gesture.location(in: scnView)

            switch gesture.state {
            case .changed:
                // Project the pan location to get new X,Z
                let hitResults = scnView.hitTest(location, options: [
                    .searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue),
                    .backFaceCulling: NSNumber(value: false)
                ])

                if let hit = hitResults.first {
                    let newX = hit.worldCoordinates.x
                    let newZ = hit.worldCoordinates.z

                    // Check bounds
                    let distance = sqrt(newX * newX + newZ * newZ)
                    if distance < 5.0 {
                        draggedNode.position.x = newX
                        draggedNode.position.z = newZ
                    }
                }

            case .ended:
                // Final position set by long press end
                break

            default:
                break
            }
        }

    }

    // MARK: - Scene Creation

    private func createGardenScene() -> SCNScene {
        let scene = SCNScene()

        // Transparent scene background
        scene.background.contents = UIColor.clear

        // Setup components
        setupCamera(in: scene)
        setupLighting(in: scene)
        setupIsland(in: scene)
        updatePlants(in: scene, plants: plants)

        return scene
    }

    // MARK: - Camera (Fixed Isometric)

    private func setupCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()

        // Orthographic projection for true isometric look
        cameraNode.camera?.usesOrthographicProjection = true
        cameraNode.camera?.orthographicScale = 8.0  // Tighter framing

        // Isometric position: 45° rotation, ~35° elevation LOOKING DOWN
        let distance: Float = 20.0
        let elevation: Float = .pi / 5.0   // ~36 degrees above horizon
        let rotation: Float = .pi / 4.0    // 45 degrees around Y axis

        // Camera position on a sphere around the origin
        let camX = distance * cos(elevation) * sin(rotation)
        let camY = distance * sin(elevation)  // POSITIVE = above island
        let camZ = distance * cos(elevation) * cos(rotation)

        cameraNode.position = SCNVector3(camX, camY, camZ)

        // Look at island center (origin)
        cameraNode.look(at: SCNVector3(0, 0, 0))

        print("📷 [Camera] Position: (\(camX), \(camY), \(camZ))")
        print("📷 [Camera] Looking at origin, elevation ~36°, rotation 45°")

        scene.rootNode.addChildNode(cameraNode)
    }

    // MARK: - Lighting

    private func setupLighting(in scene: SCNScene) {
        // Main directional light (sun) - warm and bright
        let sunLight = SCNNode()
        sunLight.light = SCNLight()
        sunLight.light?.type = .directional
        sunLight.light?.color = UIColor(red: 1.0, green: 0.98, blue: 0.92, alpha: 1.0)
        sunLight.light?.intensity = 1000
        sunLight.light?.castsShadow = true
        sunLight.light?.shadowMode = .deferred
        sunLight.light?.shadowColor = UIColor(white: 0, alpha: 0.25)
        sunLight.light?.shadowRadius = 3.0
        sunLight.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sunLight)

        // Soft ambient fill - slight blue tint for atmosphere
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(red: 0.55, green: 0.65, blue: 0.75, alpha: 1.0)
        ambientLight.light?.intensity = 350
        scene.rootNode.addChildNode(ambientLight)

        // Rim light from behind - adds depth
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.color = UIColor(red: 0.8, green: 0.85, blue: 0.95, alpha: 1.0)
        rimLight.light?.intensity = 300
        rimLight.eulerAngles = SCNVector3(-Float.pi / 6, Float.pi + Float.pi / 4, 0)
        scene.rootNode.addChildNode(rimLight)
    }

    // MARK: - Floating Island

    /// Height of the island's top surface for plant placement
    private static var islandTopY: Float = 0.5
    
    /// Current loaded island node (for theme switching)
    private static var currentIslandNode: SCNNode?

    private func setupIsland(in scene: SCNScene) {
        // List of island files to try (in order of preference)
        let islandFiles: [(name: String, ext: String)] = [
            ("island_sakura", "usdc"),
            ("island_sakura", "usdz"),
            ("floating_island", "usdz")
        ]

        var loadedSuccessfully = false

        for (name, ext) in islandFiles {
            let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "GardenAssets")
                ?? Bundle.main.url(forResource: name, withExtension: ext)

            if let islandURL = url {
                do {
                    let islandScene = try SCNScene(url: islandURL, options: [.checkConsistency: true])

                    let islandNode = SCNNode()
                    islandNode.name = "island"

                    // Copy all children from the loaded scene
                    for child in islandScene.rootNode.childNodes {
                        islandNode.addChildNode(child.clone())
                    }

                    // Disable subdivision surfaces to prevent GPU errors
                    // Name child nodes for raycast identification
                    islandNode.enumerateChildNodes { node, _ in
                        node.geometry?.subdivisionLevel = 0
                        if node.name == nil || node.name?.isEmpty == true {
                            node.name = "island_part"
                        }
                    }

                    // Get raw bounds before rotation
                    let (_, rawMax) = islandNode.boundingBox
                    let rawDepth = rawMax.z - islandNode.boundingBox.min.z

                    // Rotate so grass faces UP (+Y direction)
                    // Unity/Blender FBX exports often have Z-up orientation
                    islandNode.eulerAngles.x = -.pi / 2

                    // Scale down (Unity models are large)
                    let islandScale: Float = 0.5
                    islandNode.scale = SCNVector3(islandScale, islandScale, islandScale)
                    islandNode.position = SCNVector3(0, 0, 0)

                    // Calculate fallback Y for plant placement
                    // After -90° X rotation, old Z becomes new Y
                    Self.islandTopY = rawDepth * islandScale * 0.7

                    scene.rootNode.addChildNode(islandNode)
                    Self.currentIslandNode = islandNode

                    print("🏝️ [Island] Loaded \(name).\(ext)")
                    loadedSuccessfully = true
                    break

                } catch {
                    print("⚠️ [Island] Failed to load \(name).\(ext): \(error)")
                }
            }
        }
        
        if !loadedSuccessfully {
            print("❌ [Island] No island files found, using fallback")
            addFallbackPlatform(to: scene)
        }
    }

    /// Fallback green box platform when USDZ/USDC fails to load
    private func addFallbackPlatform(to scene: SCNScene) {
        let platformGeometry = SCNBox(width: 4.0, height: 0.5, length: 4.0, chamferRadius: 0.15)

        let grassMaterial = SCNMaterial()
        grassMaterial.diffuse.contents = UIColor(red: 0.35, green: 0.65, blue: 0.30, alpha: 1.0)
        grassMaterial.roughness.contents = 0.9

        let dirtMaterial = SCNMaterial()
        dirtMaterial.diffuse.contents = UIColor(red: 0.55, green: 0.38, blue: 0.28, alpha: 1.0)
        dirtMaterial.roughness.contents = 0.95

        platformGeometry.materials = [
            dirtMaterial, dirtMaterial, dirtMaterial, dirtMaterial,
            grassMaterial, dirtMaterial
        ]

        let platformNode = SCNNode(geometry: platformGeometry)
        platformNode.position = SCNVector3(0, 0, 0)
        platformNode.name = "island"
        scene.rootNode.addChildNode(platformNode)
        Self.currentIslandNode = platformNode

        // Set fallback height for plants
        Self.islandTopY = 0.25

        print("📦 [Island] Using fallback box platform")
    }

    // MARK: - Plant Management

    /// Find the ground surface height at given X,Z coordinates using raycasting
    /// Uses scene.rootNode for hit testing to work in WORLD coordinates
    private func findSurfaceHeight(x: Float, z: Float, in scene: SCNScene) -> Float? {
        let rayStart = SCNVector3(x, 50, z)   // High above island
        let rayEnd = SCNVector3(x, -50, z)    // Below island

        let options: [String: Any] = [
            SCNHitTestOption.backFaceCulling.rawValue: false,
            SCNHitTestOption.sortResults.rawValue: true,
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.all.rawValue
        ]

        let hits = scene.rootNode.hitTestWithSegment(from: rayStart, to: rayEnd, options: options)

        // Filter to only island hits (exclude plants, camera, lights)
        let islandHits = hits.filter { hit in
            let name = hit.node.name ?? ""
            return name.contains("island") || name.contains("Scene") || name.isEmpty
        }

        // Find topmost upward-facing surface (grass, not cliff sides)
        if let hit = islandHits.first(where: { $0.worldNormal.y > 0.3 }) {
            return hit.worldCoordinates.y + 0.1  // Offset to sit on surface
        }

        // Fallback: use highest hit point
        if let highestHit = islandHits.max(by: { $0.worldCoordinates.y < $1.worldCoordinates.y }) {
            return highestHit.worldCoordinates.y + 0.1
        }

        // No hits - use fallback Y
        return Self.islandTopY
    }

    private func updatePlants(in scene: SCNScene, plants: [Plant]) {
        // Remove existing plant nodes
        scene.rootNode.childNodes
            .filter { $0.name?.starts(with: "plant_") == true }
            .forEach { $0.removeFromParentNode() }

        // Generate fallback positions for plants without saved positions
        let fallbackPositions = generateOrganicPositions(count: plants.count)

        for (index, plant) in plants.enumerated() {
            let plantNode: SCNNode

            // Try to load USDZ model
            if let usdzURL = GardenAssetLoader.shared.getModelURL(for: plant.species, growthProgress: plant.growthProgress) {
                do {
                    let loadedScene = try SCNScene(url: usdzURL, options: [
                        .checkConsistency: true
                    ])
                    plantNode = SCNNode()
                    plantNode.name = "plant_\(plant.id)"

                    // Copy all children from loaded scene
                    for child in loadedScene.rootNode.childNodes {
                        plantNode.addChildNode(child.clone())
                    }
                } catch {
                    plantNode = createFallbackPlant(for: plant)
                }
            } else {
                plantNode = createFallbackPlant(for: plant)
            }

            plantNode.name = "plant_\(plant.id)"

            // Use saved position if available, otherwise use fallback
            if let savedPosition = plant.gardenPosition {
                plantNode.position = SCNVector3(savedPosition.x, savedPosition.y, savedPosition.z)
                print("📍 [Plant] Loaded saved position for \(plant.species.rawValue): (\(savedPosition.x), \(savedPosition.y), \(savedPosition.z))")
            } else if index < fallbackPositions.count {
                let x = fallbackPositions[index].x
                let z = fallbackPositions[index].z
                let surfaceY = findSurfaceHeight(x: x, z: z, in: scene) ?? Self.islandTopY
                plantNode.position = SCNVector3(x, surfaceY, z)
            } else {
                // Last resort: center of island
                plantNode.position = SCNVector3(0, Self.islandTopY, 0)
            }

            // Scale based on growth progress (0.5 to 1.0 range)
            let baseScale: Float = 0.5
            let growthScale = baseScale * (0.5 + Float(plant.growthProgress) * 0.5)
            plantNode.scale = SCNVector3(growthScale, growthScale, growthScale)

            // Random rotation for natural look (only if no saved position)
            if plant.gardenPosition == nil {
                plantNode.eulerAngles.y = Float.random(in: 0...Float.pi * 2)
            }

            scene.rootNode.addChildNode(plantNode)
        }
    }

    // Fallback positions for existing plants (tap-to-place is preferred for new plants)
    // These are spread around the island perimeter
    private static let fallbackPositions: [(x: Float, z: Float)] = [
        (0.0, 0.0),     // Center (will raycast to find surface)
        (2.0, 2.0),
        (-2.0, 2.0),
        (2.0, -2.0),
        (-2.0, -2.0),
        (3.0, 0.0),
        (-3.0, 0.0),
        (0.0, 3.0),
        (0.0, -3.0),
    ]

    private func generateOrganicPositions(count: Int) -> [(x: Float, z: Float)] {
        // Generate positions for existing plants (new plants use tap-to-place)
        var positions: [(x: Float, z: Float)] = []

        for i in 0..<count {
            let safeIndex = i % Self.fallbackPositions.count
            let basePos = Self.fallbackPositions[safeIndex]

            // Add small random offset
            let offsetX = Float.random(in: -0.3...0.3)
            let offsetZ = Float.random(in: -0.3...0.3)

            positions.append((x: basePos.x + offsetX, z: basePos.z + offsetZ))
        }

        return positions
    }

    // MARK: - Fallback Plant (when USDZ fails)

    private func createFallbackPlant(for plant: Plant) -> SCNNode {
        let node = SCNNode()
        node.name = "plant_\(plant.id)"

        // Determine shape based on species
        switch plant.species {
        case .oak, .cherry, .bonsai:
            // Tree shape: trunk + foliage ball
            let trunkGeometry = SCNCylinder(radius: 0.06, height: 0.35)
            trunkGeometry.firstMaterial?.diffuse.contents = UIColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1.0)
            let trunk = SCNNode(geometry: trunkGeometry)
            trunk.position = SCNVector3(0, 0.175, 0)

            let foliageGeometry = SCNSphere(radius: 0.25)
            foliageGeometry.firstMaterial?.diffuse.contents = speciesColor(plant.species)
            let foliage = SCNNode(geometry: foliageGeometry)
            foliage.position = SCNVector3(0, 0.45, 0)

            node.addChildNode(trunk)
            node.addChildNode(foliage)

        case .bamboo:
            // Tall cylinder
            let stalkGeometry = SCNCylinder(radius: 0.04, height: 0.6)
            stalkGeometry.firstMaterial?.diffuse.contents = speciesColor(plant.species)
            let stalk = SCNNode(geometry: stalkGeometry)
            stalk.position = SCNVector3(0, 0.3, 0)
            node.addChildNode(stalk)

        case .cactus:
            // Cylinder with ball on top
            let bodyGeometry = SCNCylinder(radius: 0.08, height: 0.3)
            bodyGeometry.firstMaterial?.diffuse.contents = speciesColor(plant.species)
            let body = SCNNode(geometry: bodyGeometry)
            body.position = SCNVector3(0, 0.15, 0)
            node.addChildNode(body)

        case .rose, .sunflower, .lavender, .tulip:
            // Flower shape: stem + bloom
            let stemGeometry = SCNCylinder(radius: 0.02, height: 0.25)
            stemGeometry.firstMaterial?.diffuse.contents = UIColor(red: 0.3, green: 0.55, blue: 0.25, alpha: 1.0)
            let stem = SCNNode(geometry: stemGeometry)
            stem.position = SCNVector3(0, 0.125, 0)

            let bloomGeometry = SCNSphere(radius: 0.1)
            bloomGeometry.firstMaterial?.diffuse.contents = speciesColor(plant.species)
            let bloom = SCNNode(geometry: bloomGeometry)
            bloom.position = SCNVector3(0, 0.3, 0)

            node.addChildNode(stem)
            node.addChildNode(bloom)

        case .fern:
            // Flat spread
            let fernGeometry = SCNBox(width: 0.3, height: 0.1, length: 0.3, chamferRadius: 0.05)
            fernGeometry.firstMaterial?.diffuse.contents = speciesColor(plant.species)
            let fern = SCNNode(geometry: fernGeometry)
            fern.position = SCNVector3(0, 0.05, 0)
            node.addChildNode(fern)
        }

        return node
    }

    private func speciesColor(_ species: PlantSpecies) -> UIColor {
        switch species {
        case .oak: return UIColor(red: 0.30, green: 0.55, blue: 0.25, alpha: 1.0)
        case .rose: return UIColor(red: 0.90, green: 0.25, blue: 0.35, alpha: 1.0)
        case .cactus: return UIColor(red: 0.35, green: 0.65, blue: 0.35, alpha: 1.0)
        case .sunflower: return UIColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 1.0)
        case .fern: return UIColor(red: 0.25, green: 0.60, blue: 0.30, alpha: 1.0)
        case .bamboo: return UIColor(red: 0.50, green: 0.75, blue: 0.35, alpha: 1.0)
        case .lavender: return UIColor(red: 0.65, green: 0.45, blue: 0.80, alpha: 1.0)
        case .bonsai: return UIColor(red: 0.35, green: 0.50, blue: 0.30, alpha: 1.0)
        case .cherry: return UIColor(red: 1.0, green: 0.75, blue: 0.80, alpha: 1.0)
        case .tulip: return UIColor(red: 1.0, green: 0.45, blue: 0.55, alpha: 1.0)
        }
    }
}

// MARK: - Preview

#Preview {
    SceneKitGardenView(plants: [])
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
}
