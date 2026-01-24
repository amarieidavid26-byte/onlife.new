import Foundation
import RealityKit
import Combine
import os.log

/// Performance optimizations for GardenScene
/// Handles LOD, culling, and quality adaptations
extension GardenScene {

    // MARK: - LOD System

    /// Level of Detail configuration
    struct LODConfig {
        let highDetailDistance: Float = 3.0
        let mediumDetailDistance: Float = 6.0
        let lowDetailDistance: Float = 10.0

        func levelForDistance(_ distance: Float) -> LODLevel {
            if distance < highDetailDistance {
                return .high
            } else if distance < mediumDetailDistance {
                return .medium
            } else if distance < lowDetailDistance {
                return .low
            } else {
                return .culled
            }
        }
    }

    enum LODLevel: String {
        case high       // Full detail, all effects
        case medium     // Reduced geometry, some effects
        case low        // Simplified, no particle effects
        case culled     // Not rendered

        var particlesEnabled: Bool {
            self == .high || self == .medium
        }

        var windDetailLevel: Float {
            switch self {
            case .high: return 1.0
            case .medium: return 0.5
            case .low: return 0.2
            case .culled: return 0.0
            }
        }
    }

    // MARK: - Performance Adaptation

    /// Adapt scene quality based on performance level
    func adaptQuality(to level: PerformanceMonitor.PerformanceLevel) {
        adaptShadowQuality(for: level)
        adaptParticleQuality(for: level)
        adaptWindQuality(for: level)

        let logger = Logger(subsystem: "com.onlife", category: "GardenPerformance")
        logger.info("Adapted scene quality to: \(level.rawValue)")
    }

    private func adaptShadowQuality(for level: PerformanceMonitor.PerformanceLevel) {
        // Find sun light in scene and adjust shadow quality
        rootAnchor.visitDescendants { entity in
            if let light = entity as? DirectionalLight {
                if level.shadowsEnabled {
                    // Enable shadows with quality based on level
                    let maxDistance: Float = level == .high ? 25 : 15
                    light.shadow = DirectionalLightComponent.Shadow(
                        maximumDistance: maxDistance,
                        depthBias: 0.5
                    )
                } else {
                    // Disable shadows
                    light.shadow = nil
                }
            }
        }
    }

    private func adaptParticleQuality(for level: PerformanceMonitor.PerformanceLevel) {
        let particleManager = ParticleManager.shared
        particleManager.setEnabled(level.particlesEnabled)
        particleManager.setIntensity(level.particleMultiplier)
    }

    private func adaptWindQuality(for level: PerformanceMonitor.PerformanceLevel) {
        let windSystem = WindSystem.shared

        if level.windEnabled {
            windSystem.resume()
        } else {
            windSystem.pause()
        }
    }

    // MARK: - Frustum Culling

    /// Update visibility based on camera frustum
    /// Call this periodically to hide off-screen plants
    func updateFrustumCulling(cameraPosition: SIMD3<Float>, cameraDirection: SIMD3<Float>) {
        let frustumAngle: Float = 60.0 * .pi / 180.0  // 60 degree FOV
        let maxRenderDistance: Float = 15.0

        for (_, entity) in plantEntities {
            let plantPosition = entity.position(relativeTo: rootAnchor)
            let toPlant = plantPosition - cameraPosition
            let distance = length(toPlant)

            // Distance culling
            if distance > maxRenderDistance {
                entity.isEnabled = false
                continue
            }

            // Angle culling (rough frustum check)
            let normalizedToPlant = normalize(toPlant)
            let dotProduct = dot(normalizedToPlant, cameraDirection)
            let angle = acos(dotProduct)

            entity.isEnabled = angle < frustumAngle
        }
    }

    // MARK: - LOD Updates

    /// Update LOD for all plants based on camera distance
    func updateLOD(cameraPosition: SIMD3<Float>) {
        let config = LODConfig()

        for (plantID, entity) in plantEntities {
            let plantPosition = entity.position(relativeTo: rootAnchor)
            let distance = length(plantPosition - cameraPosition)
            let lodLevel = config.levelForDistance(distance)

            applyLOD(lodLevel, to: entity, plantID: plantID)
        }
    }

    private func applyLOD(_ level: LODLevel, to entity: Entity, plantID: UUID) {
        // Update entity visibility
        entity.isEnabled = level != .culled

        guard level != .culled else { return }

        // Update LOD component if present
        if var lodComponent = entity.components[LODComponent.self] {
            guard lodComponent.currentLevel != level else { return }
            lodComponent.currentLevel = level
            entity.components[LODComponent.self] = lodComponent
        }

        // Adjust wind response based on LOD
        entity.visitDescendants { child in
            if var windComponent = child.components[WindComponent.self] {
                windComponent.swayAmount *= level.windDetailLevel
                child.components[WindComponent.self] = windComponent
            }
        }
    }

    // MARK: - Memory Management

    /// Release resources for off-screen plants
    func releaseDistantResources(cameraPosition: SIMD3<Float>, threshold: Float = 12.0) {
        for (_, entity) in plantEntities {
            let distance = length(entity.position(relativeTo: rootAnchor) - cameraPosition)

            if distance > threshold {
                // Remove particle emitters from distant plants
                entity.visitDescendants { child in
                    if child.components.has(ParticleEmitterComponent.self) {
                        child.components.remove(ParticleEmitterComponent.self)
                    }
                }
            }
        }
    }

    /// Restore resources when plants come into view
    func restoreNearbyResources(cameraPosition: SIMD3<Float>, plants: [Plant], threshold: Float = 8.0) {
        for plant in plants {
            guard let entity = plantEntities[plant.id] else { continue }

            let distance = length(entity.position(relativeTo: rootAnchor) - cameraPosition)

            if distance < threshold {
                // Re-add particle effects if needed
                let particleManager = ParticleManager.shared
                particleManager.addPlantParticles(to: entity, species: plant.species)
            }
        }
    }

    // MARK: - Debug Visualization

    /// Show/hide LOD debug visualization
    func setLODDebugVisible(_ visible: Bool) {
        for (_, entity) in plantEntities {
            if let lodComponent = entity.components[LODComponent.self] {
                // Log the state for debugging
                if visible {
                    print("🔍 Plant LOD: \(lodComponent.currentLevel.rawValue)")
                }
            }
        }
    }
}

// MARK: - LOD Component

/// Component to track LOD state per entity
struct LODComponent: Component {
    var currentLevel: GardenScene.LODLevel = .high
    var lastUpdateTime: Double = 0
}

// MARK: - Entity Visitor Extension

extension Entity {
    /// Visit all descendants recursively
    func visitDescendants(_ visitor: (Entity) -> Void) {
        for child in children {
            visitor(child)
            child.visitDescendants(visitor)
        }
    }
}
