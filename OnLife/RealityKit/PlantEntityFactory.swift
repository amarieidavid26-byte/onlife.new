import RealityKit
import UIKit
import Combine

/// Factory for creating premium plant entities
/// Uses USDZ models when available, premium procedural fallback otherwise
@MainActor
class PlantEntityFactory {

    // MARK: - Dependencies

    private let assetLoader = PlantAssetLoader.shared

    // MARK: - Configuration

    /// Whether to use procedural fallback when USDZ unavailable
    var useProceduralFallback = true

    /// Global scale multiplier for all plants
    var globalScale: Float = 1.0

    /// Enable detailed logging
    var verboseLogging = false

    // MARK: - Color Palette (Premium)

    private struct PlantColors {
        // Greens
        static let stemGreen = UIColor(red: 0.18, green: 0.42, blue: 0.18, alpha: 1.0)
        static let leafGreen = UIColor(red: 0.22, green: 0.52, blue: 0.22, alpha: 1.0)
        static let darkGreen = UIColor(red: 0.12, green: 0.32, blue: 0.12, alpha: 1.0)
        static let paleGreen = UIColor(red: 0.55, green: 0.75, blue: 0.45, alpha: 1.0)

        // Browns
        static let bark = UIColor(red: 0.38, green: 0.24, blue: 0.14, alpha: 1.0)
        static let darkBark = UIColor(red: 0.28, green: 0.16, blue: 0.08, alpha: 1.0)
        static let soil = UIColor(red: 0.25, green: 0.18, blue: 0.12, alpha: 1.0)

        // Flowers
        static let roseRed = UIColor(red: 0.88, green: 0.22, blue: 0.32, alpha: 1.0)
        static let rosePink = UIColor(red: 0.95, green: 0.45, blue: 0.55, alpha: 1.0)
        static let sunflowerYellow = UIColor(red: 1.0, green: 0.85, blue: 0.12, alpha: 1.0)
        static let lavenderPurple = UIColor(red: 0.58, green: 0.42, blue: 0.75, alpha: 1.0)
        static let cherryPink = UIColor(red: 1.0, green: 0.72, blue: 0.78, alpha: 1.0)
        static let tulipRed = UIColor(red: 0.92, green: 0.25, blue: 0.35, alpha: 1.0)

        // Other
        static let cactusGreen = UIColor(red: 0.32, green: 0.55, blue: 0.32, alpha: 1.0)
        static let bambooGreen = UIColor(red: 0.35, green: 0.55, blue: 0.30, alpha: 1.0)
        static let pollenYellow = UIColor(red: 1.0, green: 0.92, blue: 0.35, alpha: 1.0)
    }

    // MARK: - Plant Creation

    /// Create a plant entity for the given plant data
    func createPlant(for plant: Plant) -> Entity {
        let container = Entity()
        container.name = plant.id.uuidString

        // Determine growth stage from progress
        let stage = PlantAssetManifest.GrowthStage.stage(for: plant.growthProgress)

        // Try to load USDZ model first
        if let modelEntity = loadUSDZPlant(for: plant, stage: stage) {
            container.addChild(modelEntity)
            configureLoadedModel(modelEntity, plant: plant, stage: stage)
            if verboseLogging {
                print("🌳 [PlantFactory] Using USDZ for \(plant.species.rawValue)")
            }
        } else if useProceduralFallback {
            // Fall back to premium procedural
            let proceduralEntity = createProceduralPlant(for: plant, stage: stage)
            container.addChild(proceduralEntity)
            if verboseLogging {
                print("🌳 [PlantFactory] Using procedural for \(plant.species.rawValue)")
            }
        }

        // Add interaction components
        addPlantComponents(to: container, plant: plant, stage: stage)

        // Generate collision shapes for tap detection
        container.generateCollisionShapes(recursive: true)

        print("🌳 [PlantFactory] Created \(plant.species.rawValue) with \(container.children.count) children, stage: \(stage.rawValue)")
        return container
    }

    // MARK: - USDZ Loading

    private func loadUSDZPlant(for plant: Plant, stage: PlantAssetManifest.GrowthStage) -> Entity? {
        // Try exact stage match
        if let entity = assetLoader.getEntity(for: plant.species, stage: stage) {
            return entity
        }

        // Try adjacent stages (graceful degradation)
        return assetLoader.getEntityWithFallback(for: plant.species, stage: stage)
    }

    private func configureLoadedModel(_ entity: Entity, plant: Plant, stage: PlantAssetManifest.GrowthStage) {
        guard let definition = PlantAssetManifest.definition(for: plant.species) else { return }

        // Scale based on growth progress within stage
        let stageProgress = calculateStageProgress(plant.growthProgress, in: stage)
        let scaleMultiplier = 0.85 + (stageProgress * 0.3)  // 85% to 115% within stage

        let baseScale = definition.baseHeight * globalScale
        entity.scale = SIMD3<Float>(repeating: baseScale * scaleMultiplier)

        // Apply health-based visual effects
        applyHealthEffects(to: entity, health: plant.healthLevel)
    }

    private func calculateStageProgress(_ totalProgress: Double, in stage: PlantAssetManifest.GrowthStage) -> Float {
        let range = stage.progressRange
        let normalizedProgress = (totalProgress - range.lowerBound) / (range.upperBound - range.lowerBound)
        return Float(max(0, min(1, normalizedProgress)))
    }

    // MARK: - Health Effects

    func applyHealthEffects(to entity: Entity, health: Double) {
        entity.visit { child in
            if let modelEntity = child as? ModelEntity {
                applyHealthToModel(modelEntity, health: health)
            }
        }
    }

    private func applyHealthToModel(_ model: ModelEntity, health: Double) {
        guard var modelComponent = model.model else { return }

        let healthFactor = Float(0.5 + health * 0.5)  // 50% to 100%
        var newMaterials: [Material] = []

        for material in modelComponent.materials {
            if var simpleMaterial = material as? SimpleMaterial {
                // Desaturate and slightly darken based on health
                let currentTint = simpleMaterial.color.tint
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                currentTint.getRed(&r, green: &g, blue: &b, alpha: &a)

                // Mix with desaturated/brown version when unhealthy
                let gray = (r + g + b) / 3
                let brownTint: CGFloat = 0.1 * CGFloat(1 - healthFactor)

                let newR = r * CGFloat(healthFactor) + gray * CGFloat(1 - healthFactor) + brownTint
                let newG = g * CGFloat(healthFactor) + gray * CGFloat(1 - healthFactor) * 0.8
                let newB = b * CGFloat(healthFactor) + gray * CGFloat(1 - healthFactor) * 0.6

                simpleMaterial.color.tint = UIColor(
                    red: min(1, newR),
                    green: min(1, newG),
                    blue: min(1, newB),
                    alpha: a
                )
                newMaterials.append(simpleMaterial)
            } else {
                newMaterials.append(material)
            }
        }

        modelComponent.materials = newMaterials
        model.model = modelComponent
    }

    /// Update health effects on an existing plant entity
    func updatePlantHealth(entity: Entity, health: Double) {
        applyHealthEffects(to: entity, health: health)
    }

    // MARK: - Components

    private func addPlantComponents(to entity: Entity, plant: Plant, stage: PlantAssetManifest.GrowthStage) {
        guard let definition = PlantAssetManifest.definition(for: plant.species) else { return }

        // Base wind component for entire plant
        var baseWind = WindComponent(
            swayAmount: definition.swayIntensity,
            stiffness: 0.6
        )
        baseWind.baseOrientation = entity.orientation
        entity.components[WindComponent.self] = baseWind

        // Add detailed wind to child parts
        applyDetailedWind(to: entity, species: plant.species, definition: definition)

        // Plant metadata for identification
        entity.components[PlantMetadataComponent.self] = PlantMetadataComponent(
            plantID: plant.id,
            species: plant.species,
            growthStage: stage
        )

        // Input target for tap detection (RealityKit 2+)
        entity.components[InputTargetComponent.self] = InputTargetComponent()
    }

    private func applyDetailedWind(to entity: Entity, species: PlantSpecies, definition: PlantAssetManifest.PlantAssetDefinition) {
        // Traverse children and apply appropriate wind based on part type
        applyWindRecursive(to: entity, species: species, baseIntensity: definition.swayIntensity)
    }

    private func applyWindRecursive(to entity: Entity, species: PlantSpecies, baseIntensity: Float) {
        let name = entity.name.lowercased()

        // Determine wind component based on part name
        var wind: WindComponent?

        if name.contains("trunk") || name.contains("stem_base") || name.contains("body") {
            wind = .trunk()
        } else if name.contains("branch") {
            wind = .branch()
        } else if name.contains("leaf") || name.contains("frond") {
            wind = .leaf()
        } else if name.contains("flower") || name.contains("petal") || name.contains("bloom") || name.contains("blossom") {
            wind = .flower()
        } else if name.contains("canopy") || name.contains("top") || name.contains("foliage") {
            wind = WindComponent(swayAmount: 0.8, stiffness: 0.4, heightFactor: 1.2)
        } else if name.contains("stem") {
            wind = WindComponent(swayAmount: 0.5, stiffness: 0.7, heightFactor: 0.8)
        } else if name.contains("head") {
            wind = WindComponent(swayAmount: 0.9, stiffness: 0.3, heightFactor: 1.5)
        }

        // Apply wind component
        if var w = wind {
            // Scale by base intensity
            w.swayAmount *= baseIntensity
            // Store base orientation
            w.baseOrientation = entity.orientation
            entity.components[WindComponent.self] = w
        }

        // Recurse to children
        for child in entity.children {
            applyWindRecursive(to: child, species: species, baseIntensity: baseIntensity)
        }
    }

    // MARK: - Premium Procedural Plants

    private func createProceduralPlant(for plant: Plant, stage: PlantAssetManifest.GrowthStage) -> Entity {
        let container = Entity()

        // Get definition for sizing
        let definition = PlantAssetManifest.definition(for: plant.species)
        let baseHeight = definition?.baseHeight ?? 0.5

        // Scale based on growth stage
        let scale = baseHeight * stage.scaleMultiplier * globalScale
        let health = plant.healthLevel

        // Create plant based on species
        switch plant.species {
        case .rose:
            createProceduralRose(in: container, stage: stage, scale: scale, health: health)
        case .oak:
            createProceduralOak(in: container, stage: stage, scale: scale, health: health)
        case .sunflower:
            createProceduralSunflower(in: container, stage: stage, scale: scale, health: health)
        case .lavender:
            createProceduralLavender(in: container, stage: stage, scale: scale, health: health)
        case .cactus:
            createProceduralCactus(in: container, stage: stage, scale: scale, health: health)
        case .fern:
            createProceduralFern(in: container, stage: stage, scale: scale, health: health)
        case .bamboo:
            createProceduralBamboo(in: container, stage: stage, scale: scale, health: health)
        case .bonsai:
            createProceduralBonsai(in: container, stage: stage, scale: scale, health: health)
        case .cherry:
            createProceduralCherry(in: container, stage: stage, scale: scale, health: health)
        case .tulip:
            createProceduralTulip(in: container, stage: stage, scale: scale, health: health)
        }

        return container
    }

    // MARK: - Rose (Premium)

    private func createProceduralRose(in container: Entity, stage: PlantAssetManifest.GrowthStage, scale: Float, health: Double) {
        let hf = Float(health)

        // Seed stage - just a seed
        if stage == .seed {
            createSeed(in: container, scale: scale, color: PlantColors.bark)
            return
        }

        // Stem with curve
        let stemHeight = scale * 1.3
        let stemRadius: Float = 0.012 * scale

        let stemMesh = MeshResource.generateCylinder(height: stemHeight, radius: stemRadius)
        var stemMaterial = SimpleMaterial()
        stemMaterial.color = .init(tint: applyHealth(PlantColors.stemGreen, health: hf), texture: nil)
        stemMaterial.roughness = .float(0.75)

        let stem = ModelEntity(mesh: stemMesh, materials: [stemMaterial])
        stem.name = "stem"
        stem.position.y = stemHeight / 2
        container.addChild(stem)

        // Thorns (young+)
        if stage != .sprout {
            for i in 0..<5 {
                let thornMesh = MeshResource.generateCone(height: 0.025 * scale, radius: 0.004 * scale)
                let thorn = ModelEntity(mesh: thornMesh, materials: [stemMaterial])
                let angle = Float(i) * (2 * .pi / 5) + Float.random(in: -0.2...0.2)
                let height = stemHeight * (0.2 + Float(i) * 0.12)
                thorn.position = SIMD3<Float>(cos(angle) * stemRadius * 1.1, height, sin(angle) * stemRadius * 1.1)
                thorn.orientation = simd_quatf(angle: .pi / 3, axis: SIMD3<Float>(sin(angle), 0, -cos(angle)))
                stem.addChild(thorn)
            }
        }

        // Leaves
        if stage != .sprout {
            createRoseLeaves(on: stem, stemHeight: stemHeight, scale: scale, health: hf)
        }

        // Flower (mature/blooming)
        if stage == .mature || stage == .blooming {
            let flowerContainer = createRoseFlower(scale: scale, health: hf, isBlooming: stage == .blooming)
            flowerContainer.position.y = stemHeight
            stem.addChild(flowerContainer)
        }

        // Small bud for young stage
        if stage == .young {
            let budMesh = MeshResource.generateSphere(radius: 0.025 * scale)
            var budMaterial = SimpleMaterial()
            budMaterial.color = .init(tint: applyHealth(PlantColors.darkGreen, health: hf), texture: nil)
            let bud = ModelEntity(mesh: budMesh, materials: [budMaterial])
            bud.position.y = stemHeight
            bud.scale = SIMD3<Float>(0.8, 1.2, 0.8)
            stem.addChild(bud)
        }
    }

    private func createRoseLeaves(on stem: Entity, stemHeight: Float, scale: Float, health: Float) {
        let leafColor = applyHealth(PlantColors.leafGreen, health: health)

        for i in 0..<3 {
            // Compound leaf with leaflets
            let leafGroup = Entity()
            let angle = Float(i) * (2 * .pi / 3) + Float.random(in: -0.3...0.3)
            let height = stemHeight * (0.25 + Float(i) * 0.2)

            // Main leaflet
            let mainLeafMesh = MeshResource.generateBox(width: 0.06 * scale, height: 0.008 * scale, depth: 0.035 * scale, cornerRadius: 0.003 * scale)
            var leafMaterial = SimpleMaterial()
            leafMaterial.color = .init(tint: leafColor, texture: nil)
            leafMaterial.roughness = .float(0.6)

            let mainLeaf = ModelEntity(mesh: mainLeafMesh, materials: [leafMaterial])
            mainLeaf.position.x = 0.04 * scale
            leafGroup.addChild(mainLeaf)

            // Side leaflets
            for side in [-1, 1] {
                let sideLeaf = ModelEntity(mesh: mainLeafMesh, materials: [leafMaterial])
                sideLeaf.scale = SIMD3<Float>(repeating: 0.7)
                sideLeaf.position = SIMD3<Float>(0.02 * scale, 0, Float(side) * 0.02 * scale)
                sideLeaf.orientation = simd_quatf(angle: Float(side) * 0.3, axis: SIMD3<Float>(0, 1, 0))
                leafGroup.addChild(sideLeaf)
            }

            leafGroup.name = "leaf_group_\(i)"
            leafGroup.position = SIMD3<Float>(0, height, 0)
            leafGroup.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0)) *
                                   simd_quatf(angle: -.pi / 5, axis: SIMD3<Float>(0, 0, 1))

            // Wind component for leaves (will be reapplied by applyDetailedWind)
            var leafWind = WindComponent.leaf()
            leafWind.baseOrientation = leafGroup.orientation
            leafGroup.components[WindComponent.self] = leafWind

            stem.addChild(leafGroup)
        }
    }

    private func createRoseFlower(scale: Float, health: Float, isBlooming: Bool) -> Entity {
        let flower = Entity()
        flower.name = "flower"

        let petalCount = isBlooming ? 12 : 7
        let petalSize = (isBlooming ? 0.055 : 0.04) * scale
        let petalColor = applyHealth(PlantColors.roseRed, health: health)
        let innerColor = applyHealth(PlantColors.rosePink, health: health)

        // Outer petals
        for i in 0..<petalCount {
            let angle = Float(i) * (2 * .pi / Float(petalCount))
            let petalMesh = MeshResource.generateSphere(radius: petalSize)
            var petalMaterial = SimpleMaterial()
            petalMaterial.color = .init(tint: petalColor, texture: nil)
            petalMaterial.roughness = .float(0.25)

            let petal = ModelEntity(mesh: petalMesh, materials: [petalMaterial])
            petal.scale = SIMD3<Float>(1.0, 0.35, 0.7)
            petal.position = SIMD3<Float>(
                cos(angle) * petalSize * 0.9,
                petalSize * 0.15,
                sin(angle) * petalSize * 0.9
            )
            petal.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0)) *
                               simd_quatf(angle: -.pi / 6, axis: SIMD3<Float>(0, 0, 1))
            flower.addChild(petal)
        }

        // Inner petals for blooming
        if isBlooming {
            for i in 0..<8 {
                let angle = Float(i) * (2 * .pi / 8) + .pi / 8
                let innerPetalMesh = MeshResource.generateSphere(radius: petalSize * 0.7)
                var innerMaterial = SimpleMaterial()
                innerMaterial.color = .init(tint: innerColor, texture: nil)
                innerMaterial.roughness = .float(0.2)

                let innerPetal = ModelEntity(mesh: innerPetalMesh, materials: [innerMaterial])
                innerPetal.scale = SIMD3<Float>(0.9, 0.4, 0.6)
                innerPetal.position = SIMD3<Float>(
                    cos(angle) * petalSize * 0.5,
                    petalSize * 0.35,
                    sin(angle) * petalSize * 0.5
                )
                flower.addChild(innerPetal)
            }
        }

        // Center
        let centerMesh = MeshResource.generateSphere(radius: petalSize * 0.35)
        var centerMaterial = SimpleMaterial()
        centerMaterial.color = .init(tint: PlantColors.pollenYellow, texture: nil)
        let center = ModelEntity(mesh: centerMesh, materials: [centerMaterial])
        center.position.y = petalSize * 0.4
        flower.addChild(center)

        // Wind for flower
        flower.components[WindComponent.self] = WindComponent(swayAmount: 1.5, stiffness: 0.15)

        return flower
    }

    // MARK: - Oak Tree (Premium)

    private func createProceduralOak(in container: Entity, stage: PlantAssetManifest.GrowthStage, scale: Float, health: Double) {
        let hf = Float(health)

        if stage == .seed {
            createAcorn(in: container, scale: scale)
            return
        }

        // Trunk
        let trunkHeight = scale * 1.6
        let trunkRadius = scale * (stage == .mature ? 0.055 : 0.035)

        let trunkMesh = MeshResource.generateCylinder(height: trunkHeight, radius: trunkRadius)
        var trunkMaterial = SimpleMaterial()
        trunkMaterial.color = .init(tint: PlantColors.bark, texture: nil)
        trunkMaterial.roughness = .float(0.92)

        let trunk = ModelEntity(mesh: trunkMesh, materials: [trunkMaterial])
        trunk.name = "trunk"
        trunk.position.y = trunkHeight / 2
        container.addChild(trunk)

        // Branches (young+)
        if stage != .sprout {
            createOakBranches(on: trunk, trunkHeight: trunkHeight, scale: scale, material: trunkMaterial)
        }

        // Canopy (young+)
        if stage != .sprout {
            createOakCanopy(in: container, trunkHeight: trunkHeight, scale: scale, health: hf, isMature: stage == .mature)
        }

        // Small leaves for sprout
        if stage == .sprout {
            for i in 0..<2 {
                let leafMesh = MeshResource.generateSphere(radius: 0.03 * scale)
                var leafMaterial = SimpleMaterial()
                leafMaterial.color = .init(tint: applyHealth(PlantColors.paleGreen, health: hf), texture: nil)
                let leaf = ModelEntity(mesh: leafMesh, materials: [leafMaterial])
                leaf.scale = SIMD3<Float>(0.5, 0.3, 1.0)
                leaf.position = SIMD3<Float>(Float(i * 2 - 1) * 0.02 * scale, trunkHeight, 0)
                container.addChild(leaf)
            }
        }
    }

    private func createAcorn(in container: Entity, scale: Float) {
        // Acorn body
        let acornMesh = MeshResource.generateSphere(radius: 0.02 * scale)
        var acornMaterial = SimpleMaterial()
        acornMaterial.color = .init(tint: UIColor(red: 0.5, green: 0.35, blue: 0.18, alpha: 1.0), texture: nil)
        let acorn = ModelEntity(mesh: acornMesh, materials: [acornMaterial])
        acorn.scale = SIMD3<Float>(1.0, 1.4, 1.0)
        acorn.position.y = 0.015 * scale
        container.addChild(acorn)

        // Acorn cap
        let capMesh = MeshResource.generateCylinder(height: 0.012 * scale, radius: 0.018 * scale)
        var capMaterial = SimpleMaterial()
        capMaterial.color = .init(tint: PlantColors.darkBark, texture: nil)
        capMaterial.roughness = .float(0.85)
        let cap = ModelEntity(mesh: capMesh, materials: [capMaterial])
        cap.position.y = 0.032 * scale
        container.addChild(cap)
    }

    private func createOakBranches(on trunk: Entity, trunkHeight: Float, scale: Float, material: SimpleMaterial) {
        for i in 0..<3 {
            let branchLength = trunkHeight * 0.35
            let branchMesh = MeshResource.generateCylinder(height: branchLength, radius: scale * 0.018)
            let branch = ModelEntity(mesh: branchMesh, materials: [material])
            branch.name = "branch_\(i)"

            let angle = Float(i) * (2 * .pi / 3) + Float.random(in: -0.4...0.4)
            branch.position = SIMD3<Float>(0, trunkHeight * 0.72, 0)
            branch.orientation = simd_quatf(angle: .pi / 3.5, axis: SIMD3<Float>(sin(angle), 0, cos(angle)))

            trunk.addChild(branch)
        }
    }

    private func createOakCanopy(in container: Entity, trunkHeight: Float, scale: Float, health: Float, isMature: Bool) {
        let canopyColor = applyHealth(PlantColors.leafGreen, health: health)

        let positions: [(x: Float, y: Float, z: Float, size: Float)] = isMature ? [
            (0, 1.0, 0, 1.0),
            (-0.28, 0.88, 0.12, 0.72),
            (0.25, 0.92, -0.18, 0.78),
            (0.12, 0.82, 0.25, 0.68),
            (-0.18, 0.96, -0.22, 0.62),
            (0.05, 0.78, -0.08, 0.55),
        ] : [
            (0, 0.95, 0, 0.8),
            (-0.15, 0.85, 0.1, 0.5),
            (0.12, 0.88, -0.1, 0.55),
        ]

        for (i, pos) in positions.enumerated() {
            let canopySize = scale * 0.38 * pos.size
            let canopyMesh = MeshResource.generateSphere(radius: canopySize)
            var canopyMaterial = SimpleMaterial()

            // Slight color variation for organic look
            let variation = Float.random(in: 0.92...1.08)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            canopyColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            canopyMaterial.color = .init(tint: UIColor(
                red: r * CGFloat(variation),
                green: g * CGFloat(variation),
                blue: b * CGFloat(variation),
                alpha: a
            ), texture: nil)
            canopyMaterial.roughness = .float(0.82)

            let canopy = ModelEntity(mesh: canopyMesh, materials: [canopyMaterial])
            canopy.name = "canopy_\(i)"
            canopy.position = SIMD3<Float>(
                pos.x * scale,
                trunkHeight + pos.y * scale * 0.5,
                pos.z * scale
            )

            // Wind for canopy
            canopy.components[WindComponent.self] = WindComponent(swayAmount: 0.55, stiffness: 0.55)

            container.addChild(canopy)
        }
    }

    // MARK: - Sunflower (Premium)

    private func createProceduralSunflower(in container: Entity, stage: PlantAssetManifest.GrowthStage, scale: Float, health: Double) {
        let hf = Float(health)

        if stage == .seed {
            createSeed(in: container, scale: scale, color: UIColor(red: 0.2, green: 0.18, blue: 0.12, alpha: 1.0))
            return
        }

        // Tall stem
        let stemHeight = scale * 1.5
        let stemMesh = MeshResource.generateCylinder(height: stemHeight, radius: 0.018 * scale)
        var stemMaterial = SimpleMaterial()
        stemMaterial.color = .init(tint: applyHealth(PlantColors.stemGreen, health: hf), texture: nil)

        let stem = ModelEntity(mesh: stemMesh, materials: [stemMaterial])
        stem.name = "stem"
        stem.position.y = stemHeight / 2
        container.addChild(stem)

        // Large leaves
        if stage != .sprout {
            createSunflowerLeaves(on: stem, stemHeight: stemHeight, scale: scale, health: hf)
        }

        // Flower head (mature/blooming)
        if stage == .mature || stage == .blooming {
            let flowerHead = createSunflowerHead(scale: scale, health: hf, isBlooming: stage == .blooming)
            flowerHead.position.y = stemHeight
            // Slight droop
            flowerHead.orientation = simd_quatf(angle: -.pi / 12, axis: SIMD3<Float>(1, 0, 0))
            stem.addChild(flowerHead)
        }

        // Bud for young
        if stage == .young {
            let budMesh = MeshResource.generateSphere(radius: 0.04 * scale)
            var budMaterial = SimpleMaterial()
            budMaterial.color = .init(tint: applyHealth(PlantColors.darkGreen, health: hf), texture: nil)
            let bud = ModelEntity(mesh: budMesh, materials: [budMaterial])
            bud.position.y = stemHeight
            bud.scale = SIMD3<Float>(0.7, 1.0, 0.7)
            stem.addChild(bud)
        }
    }

    private func createSunflowerLeaves(on stem: Entity, stemHeight: Float, scale: Float, health: Float) {
        let leafColor = applyHealth(PlantColors.leafGreen, health: health)

        for i in 0..<3 {
            let leafMesh = MeshResource.generateBox(width: 0.12 * scale, height: 0.008 * scale, depth: 0.08 * scale, cornerRadius: 0.01 * scale)
            var leafMaterial = SimpleMaterial()
            leafMaterial.color = .init(tint: leafColor, texture: nil)

            let leaf = ModelEntity(mesh: leafMesh, materials: [leafMaterial])
            let angle = Float(i) * (2 * .pi / 3) + Float.random(in: -0.3...0.3)
            let height = stemHeight * (0.2 + Float(i) * 0.25)

            leaf.position = SIMD3<Float>(cos(angle) * 0.06 * scale, height, sin(angle) * 0.06 * scale)
            leaf.orientation = simd_quatf(angle: angle + .pi/2, axis: SIMD3<Float>(0, 1, 0)) *
                              simd_quatf(angle: -.pi/4, axis: SIMD3<Float>(1, 0, 0))

            leaf.components[WindComponent.self] = WindComponent(swayAmount: 1.0, stiffness: 0.25)
            stem.addChild(leaf)
        }
    }

    private func createSunflowerHead(scale: Float, health: Float, isBlooming: Bool) -> Entity {
        let head = Entity()
        head.name = "flower_head"

        // Brown center disk
        let diskRadius = (isBlooming ? 0.08 : 0.06) * scale
        let diskMesh = MeshResource.generateCylinder(height: 0.02 * scale, radius: diskRadius)
        var diskMaterial = SimpleMaterial()
        diskMaterial.color = .init(tint: UIColor(red: 0.35, green: 0.22, blue: 0.1, alpha: 1.0), texture: nil)
        diskMaterial.roughness = .float(0.85)

        let disk = ModelEntity(mesh: diskMesh, materials: [diskMaterial])
        head.addChild(disk)

        // Yellow petals
        let petalCount = isBlooming ? 18 : 12
        let petalColor = applyHealth(PlantColors.sunflowerYellow, health: health)

        for i in 0..<petalCount {
            let angle = Float(i) * (2 * .pi / Float(petalCount))
            let petalMesh = MeshResource.generateBox(width: 0.06 * scale, height: 0.006 * scale, depth: 0.025 * scale, cornerRadius: 0.003 * scale)
            var petalMaterial = SimpleMaterial()
            petalMaterial.color = .init(tint: petalColor, texture: nil)
            petalMaterial.roughness = .float(0.3)

            let petal = ModelEntity(mesh: petalMesh, materials: [petalMaterial])
            petal.position = SIMD3<Float>(
                cos(angle) * diskRadius * 1.1,
                0.01 * scale,
                sin(angle) * diskRadius * 1.1
            )
            petal.orientation = simd_quatf(angle: angle + .pi/2, axis: SIMD3<Float>(0, 1, 0)) *
                               simd_quatf(angle: -.pi/8, axis: SIMD3<Float>(0, 0, 1))
            head.addChild(petal)
        }

        head.components[WindComponent.self] = WindComponent(swayAmount: 0.9, stiffness: 0.3)
        return head
    }

    // MARK: - Lavender (Premium)

    private func createProceduralLavender(in container: Entity, stage: PlantAssetManifest.GrowthStage, scale: Float, health: Double) {
        let hf = Float(health)

        if stage == .seed {
            createSeed(in: container, scale: scale * 0.7, color: PlantColors.soil)
            return
        }

        // Multiple stems in a cluster
        let stemCount = stage == .blooming ? 7 : (stage == .mature ? 5 : 3)

        for _ in 0..<stemCount {
            let offsetX = Float.random(in: -0.06...0.06) * scale
            let offsetZ = Float.random(in: -0.06...0.06) * scale
            let stemHeight = Float.random(in: 0.35...0.45) * scale

            // Thin stem
            let stemMesh = MeshResource.generateCylinder(height: stemHeight, radius: 0.006 * scale)
            var stemMaterial = SimpleMaterial()
            stemMaterial.color = .init(tint: applyHealth(PlantColors.stemGreen, health: hf), texture: nil)

            let stem = ModelEntity(mesh: stemMesh, materials: [stemMaterial])
            stem.position = SIMD3<Float>(offsetX, stemHeight / 2, offsetZ)
            stem.orientation = simd_quatf(
                angle: Float.random(in: -0.12...0.12),
                axis: SIMD3<Float>(Float.random(in: -1...1), 0, Float.random(in: -1...1)).normalized
            )
            container.addChild(stem)

            // Flower cluster at top (young+)
            if stage != .sprout {
                let flowerColor = applyHealth(PlantColors.lavenderPurple, health: hf)
                for j in 0..<5 {
                    let flowerMesh = MeshResource.generateSphere(radius: 0.015 * scale)
                    var flowerMaterial = SimpleMaterial()
                    flowerMaterial.color = .init(tint: flowerColor, texture: nil)

                    let flower = ModelEntity(mesh: flowerMesh, materials: [flowerMaterial])
                    flower.position = SIMD3<Float>(
                        offsetX + Float.random(in: -0.008...0.008) * scale,
                        stemHeight * (0.7 + Float(j) * 0.08),
                        offsetZ + Float.random(in: -0.008...0.008) * scale
                    )
                    flower.scale = SIMD3<Float>(0.75, 1.1, 0.75)
                    container.addChild(flower)
                }
            }
        }

        // Wind for whole cluster
        container.components[WindComponent.self] = WindComponent(swayAmount: 0.7, stiffness: 0.3)
    }

    // MARK: - Cactus (Premium)

    private func createProceduralCactus(in container: Entity, stage: PlantAssetManifest.GrowthStage, scale: Float, health: Double) {
        let hf = Float(health)

        if stage == .seed {
            createSeed(in: container, scale: scale * 0.6, color: PlantColors.soil)
            return
        }

        let cactusColor = applyHealth(PlantColors.cactusGreen, health: hf)

        // Main body
        let bodyHeight = scale * (stage == .mature || stage == .blooming ? 0.9 : 0.5)
        let bodyRadius = scale * 0.08

        let bodyMesh = MeshResource.generateCylinder(height: bodyHeight, radius: bodyRadius)
        var bodyMaterial = SimpleMaterial()
        bodyMaterial.color = .init(tint: cactusColor, texture: nil)
        bodyMaterial.roughness = .float(0.7)

        let body = ModelEntity(mesh: bodyMesh, materials: [bodyMaterial])
        body.name = "body"
        body.position.y = bodyHeight / 2
        container.addChild(body)

        // Rounded top
        let topMesh = MeshResource.generateSphere(radius: bodyRadius)
        var topMaterial = SimpleMaterial()
        // Slightly lighter green
        topMaterial.color = .init(tint: UIColor(
            red: cactusColor.cgColor.components![0] * 1.1,
            green: cactusColor.cgColor.components![1] * 1.1,
            blue: cactusColor.cgColor.components![2],
            alpha: 1.0
        ), texture: nil)

        let top = ModelEntity(mesh: topMesh, materials: [topMaterial])
        top.position.y = bodyHeight
        top.scale = SIMD3<Float>(1.0, 0.5, 1.0)
        body.addChild(top)

        // Arms (mature/blooming)
        if stage == .mature || stage == .blooming {
            for side in [-1, 1] {
                let armHeight = bodyHeight * 0.35
                let armMesh = MeshResource.generateCylinder(height: armHeight, radius: bodyRadius * 0.6)
                let arm = ModelEntity(mesh: armMesh, materials: [bodyMaterial])
                arm.position = SIMD3<Float>(Float(side) * bodyRadius * 1.4, bodyHeight * 0.55, 0)
                arm.orientation = simd_quatf(angle: Float(side) * .pi / 3.5, axis: SIMD3<Float>(0, 0, 1))
                body.addChild(arm)

                // Arm top
                let armTop = ModelEntity(mesh: topMesh, materials: [topMaterial])
                armTop.scale = SIMD3<Float>(0.6, 0.3, 0.6)
                armTop.position.y = armHeight / 2
                arm.addChild(armTop)
            }
        }

        // Flower on top (blooming)
        if stage == .blooming {
            let flowerMesh = MeshResource.generateSphere(radius: 0.025 * scale)
            var flowerMaterial = SimpleMaterial()
            flowerMaterial.color = .init(tint: UIColor(red: 1.0, green: 0.35, blue: 0.5, alpha: 1.0), texture: nil)
            let flower = ModelEntity(mesh: flowerMesh, materials: [flowerMaterial])
            flower.position.y = bodyHeight + 0.02 * scale
            body.addChild(flower)
        }
    }

    // MARK: - Fern (Premium)

    private func createProceduralFern(in container: Entity, stage: PlantAssetManifest.GrowthStage, scale: Float, health: Double) {
        let hf = Float(health)

        if stage == .seed {
            // Fern spore
            let sporeMesh = MeshResource.generateSphere(radius: 0.008 * scale)
            var sporeMaterial = SimpleMaterial()
            sporeMaterial.color = .init(tint: PlantColors.darkGreen, texture: nil)
            let spore = ModelEntity(mesh: sporeMesh, materials: [sporeMaterial])
            spore.position.y = 0.005 * scale
            container.addChild(spore)
            return
        }

        let fernColor = applyHealth(PlantColors.leafGreen, health: hf)
        let frondCount = stage == .mature ? 9 : (stage == .young ? 6 : 3)

        for i in 0..<frondCount {
            let angle = Float(i) * (2 * .pi / Float(frondCount)) + Float.random(in: -0.15...0.15)

            // Create frond as series of segments
            let frondLength = 8 + (stage == .mature ? 4 : 0)

            for j in 0..<frondLength {
                let t = Float(j) / Float(frondLength)
                let segmentRadius = (0.018 - t * 0.012) * scale
                let height = 0.03 + t * 0.3 * scale
                let distance = t * 0.35 * scale

                let segmentMesh = MeshResource.generateSphere(radius: segmentRadius)
                var segmentMaterial = SimpleMaterial()
                segmentMaterial.color = .init(tint: fernColor, texture: nil)

                let segment = ModelEntity(mesh: segmentMesh, materials: [segmentMaterial])
                segment.position = SIMD3<Float>(
                    cos(angle) * distance,
                    height,
                    sin(angle) * distance
                )
                segment.scale = SIMD3<Float>(1.0, 0.4, 1.6)
                segment.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))

                container.addChild(segment)
            }
        }

        container.components[WindComponent.self] = WindComponent(swayAmount: 1.0, stiffness: 0.18)
    }

    // MARK: - Bamboo (Premium)

    private func createProceduralBamboo(in container: Entity, stage: PlantAssetManifest.GrowthStage, scale: Float, health: Double) {
        let hf = Float(health)

        if stage == .seed {
            createSeed(in: container, scale: scale * 0.5, color: PlantColors.paleGreen)
            return
        }

        let bambooColor = applyHealth(PlantColors.bambooGreen, health: hf)
        let stalkCount = stage == .mature ? 4 : (stage == .young ? 2 : 1)
        let segmentCount = stage == .mature ? 6 : (stage == .young ? 4 : 2)

        for stalk in 0..<stalkCount {
            let offsetX = (Float(stalk) - Float(stalkCount - 1) / 2) * 0.07 * scale
            let offsetZ = Float.random(in: -0.025...0.025) * scale

            var currentHeight: Float = 0

            for seg in 0..<segmentCount {
                let segmentHeight = (0.11 + Float.random(in: 0...0.03)) * scale
                let segmentMesh = MeshResource.generateCylinder(height: segmentHeight, radius: 0.018 * scale)
                var segmentMaterial = SimpleMaterial()
                segmentMaterial.color = .init(tint: bambooColor, texture: nil)

                let segment = ModelEntity(mesh: segmentMesh, materials: [segmentMaterial])
                segment.position = SIMD3<Float>(offsetX, currentHeight + segmentHeight / 2, offsetZ)
                container.addChild(segment)

                // Node ring
                if seg < segmentCount - 1 {
                    let nodeMesh = MeshResource.generateCylinder(height: 0.012 * scale, radius: 0.022 * scale)
                    var nodeMaterial = SimpleMaterial()
                    // Darker node
                    nodeMaterial.color = .init(tint: UIColor(
                        red: bambooColor.cgColor.components![0] * 0.85,
                        green: bambooColor.cgColor.components![1] * 0.85,
                        blue: bambooColor.cgColor.components![2] * 0.85,
                        alpha: 1.0
                    ), texture: nil)

                    let node = ModelEntity(mesh: nodeMesh, materials: [nodeMaterial])
                    node.position = SIMD3<Float>(offsetX, currentHeight + segmentHeight, offsetZ)
                    container.addChild(node)
                }

                currentHeight += segmentHeight + 0.008 * scale
            }

            // Leaves at top (young+)
            if stage != .sprout {
                let leafColor = applyHealth(PlantColors.leafGreen, health: hf)
                for leaf in 0..<3 {
                    let leafMesh = MeshResource.generateBox(width: 0.06 * scale, height: 0.004 * scale, depth: 0.015 * scale, cornerRadius: 0.002 * scale)
                    var leafMaterial = SimpleMaterial()
                    leafMaterial.color = .init(tint: leafColor, texture: nil)

                    let leafEntity = ModelEntity(mesh: leafMesh, materials: [leafMaterial])
                    let leafAngle = Float(leaf) * (2 * .pi / 3) + Float.random(in: -0.3...0.3)
                    leafEntity.position = SIMD3<Float>(
                        offsetX + cos(leafAngle) * 0.03 * scale,
                        currentHeight,
                        offsetZ + sin(leafAngle) * 0.03 * scale
                    )
                    leafEntity.orientation = simd_quatf(angle: leafAngle, axis: SIMD3<Float>(0, 1, 0)) *
                                            simd_quatf(angle: -.pi/5, axis: SIMD3<Float>(0, 0, 1))

                    leafEntity.components[WindComponent.self] = WindComponent(swayAmount: 1.2, stiffness: 0.15)
                    container.addChild(leafEntity)
                }
            }
        }

        container.components[WindComponent.self] = WindComponent(swayAmount: 0.9, stiffness: 0.22)
    }

    // MARK: - Bonsai (Premium)

    private func createProceduralBonsai(in container: Entity, stage: PlantAssetManifest.GrowthStage, scale: Float, health: Double) {
        let hf = Float(health)

        if stage == .seed {
            createSeed(in: container, scale: scale * 0.6, color: PlantColors.bark)
            return
        }

        // Decorative pot
        let potMesh = MeshResource.generateCylinder(height: 0.045 * scale, radius: 0.08 * scale)
        var potMaterial = SimpleMaterial()
        potMaterial.color = .init(tint: UIColor(red: 0.48, green: 0.32, blue: 0.22, alpha: 1.0), texture: nil)
        potMaterial.roughness = .float(0.55)

        let pot = ModelEntity(mesh: potMesh, materials: [potMaterial])
        pot.position.y = 0.0225 * scale
        container.addChild(pot)

        // Soil
        let soilMesh = MeshResource.generateCylinder(height: 0.008 * scale, radius: 0.072 * scale)
        var soilMaterial = SimpleMaterial()
        soilMaterial.color = .init(tint: PlantColors.soil, texture: nil)
        let soil = ModelEntity(mesh: soilMesh, materials: [soilMaterial])
        soil.position.y = 0.049 * scale
        container.addChild(soil)

        // Curved trunk
        let trunkHeight = scale * 0.22
        let trunkMesh = MeshResource.generateCylinder(height: trunkHeight, radius: 0.018 * scale)
        var trunkMaterial = SimpleMaterial()
        trunkMaterial.color = .init(tint: PlantColors.darkBark, texture: nil)
        trunkMaterial.roughness = .float(0.88)

        let trunk = ModelEntity(mesh: trunkMesh, materials: [trunkMaterial])
        trunk.position = SIMD3<Float>(0.015 * scale, 0.05 * scale + trunkHeight / 2, 0)
        trunk.orientation = simd_quatf(angle: 0.18, axis: SIMD3<Float>(0, 0, 1))
        container.addChild(trunk)

        // Foliage clouds
        if stage != .sprout {
            let foliageColor = applyHealth(PlantColors.darkGreen, health: hf)

            let foliagePositions: [(x: Float, y: Float, z: Float, size: Float)] = stage == .mature ? [
                (0.04, 0.28, 0, 0.065),
                (-0.02, 0.24, 0.025, 0.05),
                (0.065, 0.22, -0.015, 0.045),
                (0.02, 0.2, 0.04, 0.04),
            ] : [
                (0.03, 0.22, 0, 0.05),
                (-0.01, 0.18, 0.02, 0.04),
            ]

            for (i, pos) in foliagePositions.enumerated() {
                let foliageMesh = MeshResource.generateSphere(radius: pos.size * scale)
                var foliageMaterial = SimpleMaterial()
                foliageMaterial.color = .init(tint: foliageColor, texture: nil)
                foliageMaterial.roughness = .float(0.8)

                let foliage = ModelEntity(mesh: foliageMesh, materials: [foliageMaterial])
                foliage.position = SIMD3<Float>(pos.x * scale, pos.y * scale + 0.05 * scale, pos.z * scale)
                foliage.name = "foliage_\(i)"
                container.addChild(foliage)
            }
        }

        container.components[WindComponent.self] = WindComponent(swayAmount: 0.35, stiffness: 0.6)
    }

    // MARK: - Cherry Blossom (Premium)

    private func createProceduralCherry(in container: Entity, stage: PlantAssetManifest.GrowthStage, scale: Float, health: Double) {
        let hf = Float(health)

        if stage == .seed {
            // Cherry pit
            let pitMesh = MeshResource.generateSphere(radius: 0.015 * scale)
            var pitMaterial = SimpleMaterial()
            pitMaterial.color = .init(tint: UIColor(red: 0.45, green: 0.25, blue: 0.15, alpha: 1.0), texture: nil)
            let pit = ModelEntity(mesh: pitMesh, materials: [pitMaterial])
            pit.position.y = 0.01 * scale
            container.addChild(pit)
            return
        }

        // Graceful trunk
        let trunkHeight = scale * 1.4
        let trunkMesh = MeshResource.generateCylinder(height: trunkHeight, radius: 0.04 * scale)
        var trunkMaterial = SimpleMaterial()
        trunkMaterial.color = .init(tint: PlantColors.darkBark, texture: nil)
        trunkMaterial.roughness = .float(0.85)

        let trunk = ModelEntity(mesh: trunkMesh, materials: [trunkMaterial])
        trunk.name = "trunk"
        trunk.position.y = trunkHeight / 2
        container.addChild(trunk)

        // Branches
        if stage != .sprout {
            for i in 0..<4 {
                let branchLength = trunkHeight * 0.4
                let branchMesh = MeshResource.generateCylinder(height: branchLength, radius: 0.015 * scale)
                let branch = ModelEntity(mesh: branchMesh, materials: [trunkMaterial])

                let angle = Float(i) * (2 * .pi / 4) + Float.random(in: -0.2...0.2)
                branch.position = SIMD3<Float>(0, trunkHeight * 0.7, 0)
                branch.orientation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(sin(angle), 0, cos(angle)))

                trunk.addChild(branch)
            }
        }

        // Blossoms (mature/blooming)
        if stage == .mature || stage == .blooming {
            let blossomColor = applyHealth(PlantColors.cherryPink, health: hf)
            let blossomCount = stage == .blooming ? 25 : 15

            for _ in 0..<blossomCount {
                let blossomMesh = MeshResource.generateSphere(radius: (0.025 + Float.random(in: 0...0.015)) * scale)
                var blossomMaterial = SimpleMaterial()
                // Color variation
                let variation = Float.random(in: 0.9...1.1)
                blossomMaterial.color = .init(tint: UIColor(
                    red: blossomColor.cgColor.components![0] * CGFloat(variation),
                    green: blossomColor.cgColor.components![1] * CGFloat(variation),
                    blue: blossomColor.cgColor.components![2] * CGFloat(variation),
                    alpha: 1.0
                ), texture: nil)
                blossomMaterial.roughness = .float(0.25)

                let blossom = ModelEntity(mesh: blossomMesh, materials: [blossomMaterial])

                // Distribute around canopy area
                let angle = Float.random(in: 0...(2 * .pi))
                let radius = Float.random(in: 0.1...0.35) * scale
                let height = trunkHeight + Float.random(in: -0.1...0.25) * scale

                blossom.position = SIMD3<Float>(
                    cos(angle) * radius,
                    height,
                    sin(angle) * radius
                )

                container.addChild(blossom)
            }

            // Some leaves
            let leafColor = applyHealth(PlantColors.paleGreen, health: hf)
            for _ in 0..<8 {
                let leafMesh = MeshResource.generateSphere(radius: 0.035 * scale)
                var leafMaterial = SimpleMaterial()
                leafMaterial.color = .init(tint: leafColor, texture: nil)

                let leaf = ModelEntity(mesh: leafMesh, materials: [leafMaterial])
                leaf.scale = SIMD3<Float>(1.0, 0.3, 0.7)

                let angle = Float.random(in: 0...(2 * .pi))
                let radius = Float.random(in: 0.15...0.3) * scale

                leaf.position = SIMD3<Float>(
                    cos(angle) * radius,
                    trunkHeight + Float.random(in: -0.05...0.15) * scale,
                    sin(angle) * radius
                )

                container.addChild(leaf)
            }
        }

        container.components[WindComponent.self] = WindComponent(swayAmount: 0.65, stiffness: 0.4)
    }

    // MARK: - Tulip (Premium)

    private func createProceduralTulip(in container: Entity, stage: PlantAssetManifest.GrowthStage, scale: Float, health: Double) {
        let hf = Float(health)

        if stage == .seed {
            // Tulip bulb
            let bulbMesh = MeshResource.generateSphere(radius: 0.02 * scale)
            var bulbMaterial = SimpleMaterial()
            bulbMaterial.color = .init(tint: UIColor(red: 0.55, green: 0.45, blue: 0.35, alpha: 1.0), texture: nil)
            let bulb = ModelEntity(mesh: bulbMesh, materials: [bulbMaterial])
            bulb.scale = SIMD3<Float>(1.0, 1.3, 1.0)
            bulb.position.y = 0.015 * scale
            container.addChild(bulb)
            return
        }

        // Stem
        let stemHeight = scale * 0.9
        let stemMesh = MeshResource.generateCylinder(height: stemHeight, radius: 0.01 * scale)
        var stemMaterial = SimpleMaterial()
        stemMaterial.color = .init(tint: applyHealth(PlantColors.stemGreen, health: hf), texture: nil)

        let stem = ModelEntity(mesh: stemMesh, materials: [stemMaterial])
        stem.name = "stem"
        stem.position.y = stemHeight / 2
        container.addChild(stem)

        // Broad leaves
        if stage != .sprout {
            let leafColor = applyHealth(PlantColors.leafGreen, health: hf)

            for side in [-1, 1] {
                let leafMesh = MeshResource.generateBox(width: 0.04 * scale, height: 0.006 * scale, depth: 0.12 * scale, cornerRadius: 0.005 * scale)
                var leafMaterial = SimpleMaterial()
                leafMaterial.color = .init(tint: leafColor, texture: nil)

                let leaf = ModelEntity(mesh: leafMesh, materials: [leafMaterial])
                leaf.position = SIMD3<Float>(Float(side) * 0.025 * scale, stemHeight * 0.2, 0)
                leaf.orientation = simd_quatf(angle: Float(side) * .pi / 6, axis: SIMD3<Float>(0, 0, 1)) *
                                  simd_quatf(angle: Float(side) * .pi / 8, axis: SIMD3<Float>(1, 0, 0))

                stem.addChild(leaf)
            }
        }

        // Cup-shaped flower (mature/blooming)
        if stage == .mature || stage == .blooming {
            let flowerColor = applyHealth(PlantColors.tulipRed, health: hf)
            let petalCount = 6
            let openAmount: Float = stage == .blooming ? 0.4 : 0.2

            for i in 0..<petalCount {
                let angle = Float(i) * (2 * .pi / Float(petalCount))
                let petalMesh = MeshResource.generateSphere(radius: 0.035 * scale)
                var petalMaterial = SimpleMaterial()
                petalMaterial.color = .init(tint: flowerColor, texture: nil)
                petalMaterial.roughness = .float(0.28)

                let petal = ModelEntity(mesh: petalMesh, materials: [petalMaterial])
                petal.scale = SIMD3<Float>(0.5, 1.2, 0.7)
                petal.position = SIMD3<Float>(
                    cos(angle) * 0.02 * scale * openAmount,
                    stemHeight + 0.03 * scale,
                    sin(angle) * 0.02 * scale * openAmount
                )
                petal.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0)) *
                                   simd_quatf(angle: openAmount * .pi / 4, axis: SIMD3<Float>(0, 0, 1))

                stem.addChild(petal)
            }

            // Center
            let centerMesh = MeshResource.generateCylinder(height: 0.02 * scale, radius: 0.008 * scale)
            var centerMaterial = SimpleMaterial()
            centerMaterial.color = .init(tint: PlantColors.pollenYellow, texture: nil)
            let center = ModelEntity(mesh: centerMesh, materials: [centerMaterial])
            center.position.y = stemHeight + 0.025 * scale
            stem.addChild(center)
        }

        // Bud for young
        if stage == .young {
            let budMesh = MeshResource.generateSphere(radius: 0.025 * scale)
            var budMaterial = SimpleMaterial()
            budMaterial.color = .init(tint: applyHealth(PlantColors.darkGreen, health: hf), texture: nil)
            let bud = ModelEntity(mesh: budMesh, materials: [budMaterial])
            bud.scale = SIMD3<Float>(0.6, 1.1, 0.6)
            bud.position.y = stemHeight
            stem.addChild(bud)
        }

        container.components[WindComponent.self] = WindComponent(swayAmount: 0.8, stiffness: 0.28)
    }

    // MARK: - Helper Methods

    private func createSeed(in container: Entity, scale: Float, color: UIColor) {
        let seedMesh = MeshResource.generateSphere(radius: 0.015 * scale)
        var seedMaterial = SimpleMaterial()
        seedMaterial.color = .init(tint: color, texture: nil)
        seedMaterial.roughness = .float(0.7)

        let seed = ModelEntity(mesh: seedMesh, materials: [seedMaterial])
        seed.position.y = 0.01 * scale
        seed.scale = SIMD3<Float>(1.0, 0.8, 1.0)
        container.addChild(seed)
    }

    private func applyHealth(_ color: UIColor, health: Float) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Desaturate and brown-tint when unhealthy
        let gray = (r + g + b) / 3
        let healthFactor = CGFloat(0.5 + health * 0.5)

        return UIColor(
            red: r * healthFactor + gray * (1 - healthFactor),
            green: g * healthFactor + gray * (1 - healthFactor) * 0.85,
            blue: b * healthFactor + gray * (1 - healthFactor) * 0.7,
            alpha: a
        )
    }
}

// MARK: - Supporting Types

/// Metadata component for plant identification in scene
struct PlantMetadataComponent: Component {
    let plantID: UUID
    let species: PlantSpecies
    let growthStage: PlantAssetManifest.GrowthStage
}


// MARK: - Entity Extensions

extension Entity {
    /// Visit all descendants recursively
    func visit(_ block: (Entity) -> Void) {
        block(self)
        for child in children {
            child.visit(block)
        }
    }
}

extension SIMD3 where Scalar == Float {
    /// Normalize a vector, returning zero vector if magnitude is zero
    var normalized: SIMD3<Float> {
        let mag = sqrt(x * x + y * y + z * z)
        guard mag > 0 else { return SIMD3<Float>(0, 1, 0) }
        return self / mag
    }
}
