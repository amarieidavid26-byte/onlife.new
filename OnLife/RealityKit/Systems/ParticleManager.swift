import RealityKit
import SwiftUI
import Combine

/// Particles disabled - RealityKit ParticleEmitterComponent requires specific setup
@MainActor
class ParticleManager: ObservableObject {
    static let shared = ParticleManager()
    @Published var particlesEnabled: Bool = false

    private init() {}

    func attach(to root: Entity) {
        print("✨ [Particles] Manager attached (effects disabled)")
    }

    func addPlantParticles(to plantEntity: Entity, species: PlantSpecies) {
        // Particles disabled for stability
    }

    func triggerSparkles(at position: SIMD3<Float>, count: Int = 20) {
        // Particles disabled for stability
    }

    func triggerCelebration(at position: SIMD3<Float>) {
        // Particles disabled for stability
    }

    func removeAllParticles() {
        // No particles to remove
    }

    func setEnabled(_ enabled: Bool) {
        particlesEnabled = false  // Always disabled for now
    }

    func setIntensity(_ intensity: Float) {
        // No-op
    }
}
