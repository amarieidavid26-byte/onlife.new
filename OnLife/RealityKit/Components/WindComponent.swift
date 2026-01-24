import RealityKit
import simd

/// Component that marks an entity as affected by wind
/// Attach to any entity that should sway in the breeze
struct WindComponent: Component {

    // MARK: - Sway Parameters

    /// Overall sway intensity (0 = none, 1 = normal, 2 = extreme)
    var swayAmount: Float = 1.0

    /// Stiffness resistance (0 = very flexible like leaves, 1 = rigid like trunk)
    var stiffness: Float = 0.5

    /// Phase offset for desynchronized animation (radians)
    var phaseOffset: Float

    /// Height influence multiplier (taller parts sway more)
    var heightFactor: Float = 1.0

    /// World height of this entity (set automatically)
    var worldHeight: Float = 0.0

    // MARK: - Rotation State

    /// Original rotation before wind applied
    var baseOrientation: simd_quatf

    /// Current wind-applied rotation (for smooth interpolation)
    var currentWindRotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))

    // MARK: - Per-Entity Variation

    /// Random seed for this entity's unique behavior
    let randomSeed: Float

    /// Secondary frequency multiplier (makes each plant feel unique)
    let frequencyVariation: Float

    // MARK: - Initialization

    init(
        swayAmount: Float = 1.0,
        stiffness: Float = 0.5,
        phaseOffset: Float? = nil,
        heightFactor: Float = 1.0
    ) {
        self.swayAmount = swayAmount
        self.stiffness = stiffness
        self.phaseOffset = phaseOffset ?? Float.random(in: 0...(2 * .pi))
        self.heightFactor = heightFactor
        self.baseOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        self.randomSeed = Float.random(in: 0...1000)
        self.frequencyVariation = Float.random(in: 0.8...1.2)
    }

    // MARK: - Presets

    /// Stiff trunk/stem that barely moves
    static func trunk() -> WindComponent {
        WindComponent(swayAmount: 0.3, stiffness: 0.9, heightFactor: 0.5)
    }

    /// Flexible branch that sways moderately
    static func branch() -> WindComponent {
        WindComponent(swayAmount: 0.7, stiffness: 0.6, heightFactor: 1.0)
    }

    /// Very flexible leaf that flutters
    static func leaf() -> WindComponent {
        WindComponent(swayAmount: 1.2, stiffness: 0.2, heightFactor: 1.3)
    }

    /// Flower head that bobs gently
    static func flower() -> WindComponent {
        WindComponent(swayAmount: 1.0, stiffness: 0.3, heightFactor: 1.5)
    }

    /// Grass blade that waves dramatically
    static func grass() -> WindComponent {
        WindComponent(swayAmount: 1.5, stiffness: 0.1, heightFactor: 1.2)
    }

    /// Entire small plant (moderate overall sway)
    static func smallPlant() -> WindComponent {
        WindComponent(swayAmount: 0.8, stiffness: 0.5, heightFactor: 1.0)
    }

    /// Entire tree (subtle sway, stiff trunk)
    static func tree() -> WindComponent {
        WindComponent(swayAmount: 0.4, stiffness: 0.7, heightFactor: 0.8)
    }
}
