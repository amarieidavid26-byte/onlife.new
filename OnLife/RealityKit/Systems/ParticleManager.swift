import RealityKit
import Combine
import UIKit

/// Manages particle effects throughout the garden
/// Handles ambient particles, plant-specific effects, and triggered bursts
@MainActor
class ParticleManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ParticleManager()

    // MARK: - Published State

    @Published var particlesEnabled: Bool = true
    @Published var particleIntensity: Float = 1.0  // 0-2 scale

    // MARK: - Scene Reference

    private weak var rootEntity: Entity?
    private var particleEntities: [String: Entity] = [:]

    // MARK: - Dependencies

    private let dayNightSystem = DayNightSystem.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        observeDayNight()
    }

    // MARK: - Setup

    func attach(to root: Entity) {
        self.rootEntity = root
        setupAmbientParticles()
        print("✨ [Particles] Attached to scene")
    }

    // MARK: - Ambient Particles

    private func setupAmbientParticles() {
        guard let root = rootEntity else { return }

        // Floating dust motes (always present, subtle)
        let dustEmitter = createDustParticles()
        dustEmitter.name = "ambient_dust"
        dustEmitter.position = SIMD3<Float>(0, 2, 0)
        root.addChild(dustEmitter)
        particleEntities["dust"] = dustEmitter

        // Fireflies (night only)
        let firefliesEmitter = createFireflyParticles()
        firefliesEmitter.name = "fireflies"
        firefliesEmitter.position = SIMD3<Float>(0, 1, 0)
        firefliesEmitter.isEnabled = false
        root.addChild(firefliesEmitter)
        particleEntities["fireflies"] = firefliesEmitter

        // Sparkles (magical effect - triggered)
        let sparklesEmitter = createSparkleParticles()
        sparklesEmitter.name = "sparkles"
        sparklesEmitter.position = SIMD3<Float>(0, 0.5, 0)
        sparklesEmitter.isEnabled = false
        root.addChild(sparklesEmitter)
        particleEntities["sparkles"] = sparklesEmitter
    }

    // MARK: - Day/Night Observer

    private func observeDayNight() {
        dayNightSystem.$currentPhase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                self?.updateParticlesForPhase(phase)
            }
            .store(in: &cancellables)
    }

    private func updateParticlesForPhase(_ phase: DayNightSystem.DayPhase) {
        guard particlesEnabled else { return }

        // Fireflies at night/twilight
        let isNight = phase == .night || phase == .twilight || phase == .dusk
        particleEntities["fireflies"]?.isEnabled = isNight

        // Adjust dust intensity based on lighting
        if var dust = particleEntities["dust"]?.components[ParticleEmitterComponent.self] {
            // More visible dust motes during golden hour when sun is low
            let isGoldenHour = phase == .dawn || phase == .dusk || phase == .evening
            dust.mainEmitter.birthRate = Float(isGoldenHour ? 30 : 15) * particleIntensity
            particleEntities["dust"]?.components[ParticleEmitterComponent.self] = dust
        }

        print("✨ [Particles] Updated for phase: \(phase.rawValue)")
    }

    // MARK: - Plant-Specific Particles

    /// Add particle effect for a specific plant
    func addPlantParticles(to plantEntity: Entity, species: PlantSpecies) {
        guard let definition = PlantAssetManifest.definition(for: species),
              let effectType = definition.particleEffect else { return }

        let emitter = createParticleEmitter(for: effectType, intensity: definition.particleIntensity)
        emitter.name = "plant_particles_\(plantEntity.name)"

        // Position above the plant
        emitter.position = SIMD3<Float>(0, 0.5, 0)

        plantEntity.addChild(emitter)

        print("✨ [Particles] Added \(effectType.rawValue) to \(species.rawValue)")
    }

    private func createParticleEmitter(for type: PlantAssetManifest.ParticleEffectType, intensity: Float = 1.0) -> Entity {
        switch type {
        case .pollen:
            return createPollenParticles(intensity: intensity)
        case .butterflies:
            return createButterflyParticles(intensity: intensity)
        case .fireflies:
            return createFireflyParticles()
        case .fallingLeaves:
            return createFallingLeavesParticles(intensity: intensity)
        case .sparkles:
            return createSparkleParticles()
        case .petals:
            return createPetalParticles(intensity: intensity)
        }
    }

    // MARK: - Particle Creators

    private func createDustParticles() -> Entity {
        let entity = Entity()

        var emitter = ParticleEmitterComponent.Presets.rain
        emitter.mainEmitter.birthRate = 2  // Very subtle dust motes
        emitter.emitterShape = .box
        emitter.emitterShapeSize = SIMD3<Float>(10, 4, 10)

        // Particle properties
        emitter.mainEmitter.lifeSpan = 8.0
        emitter.mainEmitter.size = 0.006
        emitter.mainEmitter.color = .constant(.single(UIColor.white.withAlphaComponent(0.25)))

        // Gentle upward drift
        emitter.mainEmitter.acceleration = SIMD3<Float>(0, 0.008, 0)

        entity.components[ParticleEmitterComponent.self] = emitter

        return entity
    }

    private func createFireflyParticles() -> Entity {
        let entity = Entity()

        var emitter = ParticleEmitterComponent.Presets.fireworks
        emitter.mainEmitter.birthRate = 0.5  // Rare, magical fireflies
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = SIMD3<Float>(8, 3, 8)

        // Firefly properties
        emitter.mainEmitter.lifeSpan = 5.0
        emitter.mainEmitter.size = 0.018
        emitter.mainEmitter.color = .constant(.single(UIColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 1.0)))

        // Random wandering
        emitter.mainEmitter.acceleration = SIMD3<Float>(0.02, 0, 0.02)

        entity.components[ParticleEmitterComponent.self] = emitter

        // Add subtle glow light
        let glow = PointLight()
        glow.light.color = UIColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 1.0)
        glow.light.intensity = 80
        glow.light.attenuationRadius = 3
        entity.addChild(glow)

        return entity
    }

    private func createSparkleParticles() -> Entity {
        let entity = Entity()

        var emitter = ParticleEmitterComponent.Presets.fireworks
        emitter.mainEmitter.birthRate = 1  // Occasional sparkles
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = SIMD3<Float>(0.5, 0.5, 0.5)

        // Sparkle properties
        emitter.mainEmitter.lifeSpan = 1.5
        emitter.mainEmitter.size = 0.012

        // Rainbow sparkle colors - evolving from pink to blue
        emitter.mainEmitter.color = .evolving(
            start: .single(UIColor(red: 1.0, green: 0.85, blue: 0.95, alpha: 1.0)),
            end: .single(UIColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 1.0))
        )

        entity.components[ParticleEmitterComponent.self] = emitter

        return entity
    }

    private func createPollenParticles(intensity: Float = 1.0) -> Entity {
        let entity = Entity()

        var emitter = ParticleEmitterComponent.Presets.rain
        emitter.mainEmitter.birthRate = 0.3 * intensity  // Gentle pollen drift
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = SIMD3<Float>(0.25, 0.1, 0.25)

        // Pollen properties
        emitter.mainEmitter.lifeSpan = 6.0
        emitter.mainEmitter.size = 0.005

        // Golden yellow pollen
        emitter.mainEmitter.color = .constant(.single(UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 0.85)))

        // Drift with wind
        emitter.mainEmitter.acceleration = SIMD3<Float>(0.008, 0.003, 0.005)

        entity.components[ParticleEmitterComponent.self] = emitter

        return entity
    }

    private func createButterflyParticles(intensity: Float = 1.0) -> Entity {
        let entity = Entity()

        var emitter = ParticleEmitterComponent.Presets.fireworks
        emitter.mainEmitter.birthRate = 0.2 * intensity  // Very rare butterflies
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = SIMD3<Float>(1.5, 1.0, 1.5)

        // Butterfly-like particles
        emitter.mainEmitter.lifeSpan = 10.0
        emitter.mainEmitter.size = 0.025

        // Colorful - evolving from pink to blue
        emitter.mainEmitter.color = .evolving(
            start: .single(UIColor(red: 1.0, green: 0.6, blue: 0.8, alpha: 0.9)),
            end: .single(UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 0.9))
        )

        // Erratic movement
        emitter.mainEmitter.acceleration = SIMD3<Float>(0.015, 0.008, 0.015)

        entity.components[ParticleEmitterComponent.self] = emitter

        return entity
    }

    private func createFallingLeavesParticles(intensity: Float = 1.0) -> Entity {
        let entity = Entity()

        var emitter = ParticleEmitterComponent.Presets.rain
        emitter.mainEmitter.birthRate = 0.5 * intensity  // Gentle falling leaves
        emitter.emitterShape = .box
        emitter.emitterShapeSize = SIMD3<Float>(1.0, 0.1, 1.0)

        // Leaf properties
        emitter.mainEmitter.lifeSpan = 7.0
        emitter.mainEmitter.size = 0.02

        // Autumn colors - evolving from orange to brown
        emitter.mainEmitter.color = .evolving(
            start: .single(UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 0.9)),
            end: .single(UIColor(red: 0.8, green: 0.4, blue: 0.15, alpha: 0.9))
        )

        // Falling with sway
        emitter.mainEmitter.acceleration = SIMD3<Float>(0.01, -0.015, 0.008)

        // Tumbling
        emitter.mainEmitter.angularSpeed = 0.8

        entity.components[ParticleEmitterComponent.self] = emitter

        return entity
    }

    private func createPetalParticles(intensity: Float = 1.0) -> Entity {
        let entity = Entity()

        var emitter = ParticleEmitterComponent.Presets.rain
        emitter.mainEmitter.birthRate = 0.5 * intensity  // Gentle cherry blossom petals
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = SIMD3<Float>(0.8, 0.3, 0.8)

        // Petal properties
        emitter.mainEmitter.lifeSpan = 8.0
        emitter.mainEmitter.size = 0.018

        // Pink cherry blossom petals - subtle color variation
        emitter.mainEmitter.color = .evolving(
            start: .single(UIColor(red: 1.0, green: 0.8, blue: 0.85, alpha: 0.95)),
            end: .single(UIColor(red: 1.0, green: 0.9, blue: 0.92, alpha: 0.95))
        )

        // Gentle falling spiral
        emitter.mainEmitter.acceleration = SIMD3<Float>(0.008, -0.012, 0.006)
        emitter.mainEmitter.angularSpeed = 0.6

        entity.components[ParticleEmitterComponent.self] = emitter

        return entity
    }

    // MARK: - Triggered Effects

    /// Trigger a burst of sparkles (e.g., when plant grows)
    func triggerSparkles(at position: SIMD3<Float>, count: Int = 12) {
        guard let root = rootEntity else { return }

        let burst = Entity()
        burst.name = "sparkle_burst"

        var emitter = ParticleEmitterComponent.Presets.fireworks
        emitter.mainEmitter.birthRate = Float(count)  // Elegant burst
        emitter.emitterShape = .point

        // Burst properties - short lifespan for burst effect
        emitter.mainEmitter.lifeSpan = 1.0
        emitter.mainEmitter.size = 0.015

        // Golden sparkles
        emitter.mainEmitter.color = .constant(.single(UIColor(red: 1.0, green: 0.92, blue: 0.6, alpha: 1.0)))

        // Stop emitting after brief burst
        emitter.timing = .once(warmUp: 0, emit: ParticleEmitterComponent.Timing.VariableDuration(duration: 0.1))

        burst.components[ParticleEmitterComponent.self] = emitter
        burst.position = position

        root.addChild(burst)

        // Remove after particles die
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            burst.removeFromParent()
        }

        print("✨ [Particles] Triggered sparkle burst at \(position)")
    }

    /// Trigger celebration effect (multiple bursts)
    func triggerCelebration(at position: SIMD3<Float>) {
        // Multiple sparkle bursts in sequence - elegant, not overwhelming
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                let offset = SIMD3<Float>(
                    Float.random(in: -0.2...0.2),
                    Float.random(in: 0...0.3),
                    Float.random(in: -0.2...0.2)
                )
                self.triggerSparkles(at: position + offset, count: 8)
            }
        }
    }

    // MARK: - Control

    /// Enable/disable all particles
    func setEnabled(_ enabled: Bool) {
        particlesEnabled = enabled

        for (_, entity) in particleEntities {
            if var emitter = entity.components[ParticleEmitterComponent.self] {
                emitter.isEmitting = enabled
                entity.components[ParticleEmitterComponent.self] = emitter
            }
        }
    }

    /// Set global particle intensity
    func setIntensity(_ intensity: Float) {
        particleIntensity = max(0, min(2, intensity))

        // Update existing emitters
        for (_, entity) in particleEntities {
            if var emitter = entity.components[ParticleEmitterComponent.self] {
                // Scale birth rate
                emitter.mainEmitter.birthRate *= intensity
                entity.components[ParticleEmitterComponent.self] = emitter
            }
        }
    }

    // MARK: - Cleanup

    func removeAllParticles() {
        for (_, entity) in particleEntities {
            entity.removeFromParent()
        }
        particleEntities.removeAll()
    }
}
