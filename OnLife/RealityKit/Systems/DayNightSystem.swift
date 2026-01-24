import RealityKit
import Combine
import UIKit
import os.log

/// Controls day/night cycle lighting and atmosphere
/// Syncs to user's real time or can be controlled manually for demos
@MainActor
class DayNightSystem: ObservableObject {

    // MARK: - Singleton

    static let shared = DayNightSystem()

    // MARK: - Published State

    /// Time of day (0.0 = midnight, 0.5 = noon, 1.0 = midnight)
    @Published var timeOfDay: Float = 0.5 {
        didSet { updateLighting() }
    }

    /// Current phase name
    @Published private(set) var currentPhase: DayPhase = .day

    /// Whether to follow real time or manual control
    @Published var followRealTime: Bool = true {
        didSet {
            if followRealTime { syncToRealTime() }
        }
    }

    /// Animation speed for demo (1.0 = real time, 60 = 1 day per minute)
    var timeScale: Float = 1.0

    // MARK: - Scene References

    private weak var sunLight: DirectionalLight?
    private weak var moonLight: DirectionalLight?
    private weak var ambientLight: PointLight?
    private weak var skyEntity: Entity?

    // MARK: - Internal State

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    // Logger
    private let logger = Logger(subsystem: "com.onlife", category: "DayNightSystem")

    // MARK: - Day Phases

    enum DayPhase: String, CaseIterable {
        case night = "Night"        // 0.00 - 0.20
        case dawn = "Dawn"          // 0.20 - 0.30
        case morning = "Morning"    // 0.30 - 0.45
        case day = "Day"            // 0.45 - 0.70
        case evening = "Evening"    // 0.70 - 0.80
        case dusk = "Dusk"          // 0.80 - 0.90
        case twilight = "Twilight"  // 0.90 - 1.00

        var icon: String {
            switch self {
            case .night, .twilight: return "moon.stars.fill"
            case .dawn: return "sunrise.fill"
            case .morning: return "sun.haze.fill"
            case .day: return "sun.max.fill"
            case .evening: return "sun.haze.fill"
            case .dusk: return "sunset.fill"
            }
        }

        static func phase(for time: Float) -> DayPhase {
            switch time {
            case 0.00..<0.20: return .night
            case 0.20..<0.30: return .dawn
            case 0.30..<0.45: return .morning
            case 0.45..<0.70: return .day
            case 0.70..<0.80: return .evening
            case 0.80..<0.90: return .dusk
            default: return .twilight
            }
        }
    }

    // MARK: - Initialization

    private init() {
        syncToRealTime()
    }

    // MARK: - Setup

    /// Attach to scene and configure lights
    func setup(
        sunLight: DirectionalLight,
        moonLight: DirectionalLight? = nil,
        ambientLight: PointLight? = nil,
        skyEntity: Entity? = nil
    ) {
        self.sunLight = sunLight
        self.moonLight = moonLight
        self.ambientLight = ambientLight
        self.skyEntity = skyEntity

        updateLighting()
        startUpdateLoop()

        logger.info("DayNight system initialized")
    }

    // MARK: - Time Sync

    /// Sync time of day to user's real local time
    func syncToRealTime() {
        let calendar = Calendar.current
        let now = Date()
        let hour = Float(calendar.component(.hour, from: now))
        let minute = Float(calendar.component(.minute, from: now))

        // Convert to 0-1 range (0 = midnight, 0.5 = noon)
        timeOfDay = (hour + minute / 60.0) / 24.0

        logger.info("DayNight synced to real time: \(Int(hour)):\(Int(minute)) -> \(self.timeOfDay)")
    }

    // MARK: - Update Loop

    private func startUpdateLoop() {
        displayLink = CADisplayLink(target: self, selector: #selector(update(_:)))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 30)
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func update(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        let deltaTime = Float(currentTime - lastTimestamp)
        lastTimestamp = currentTime

        guard deltaTime > 0 && deltaTime < 1.0 else { return }  // Skip large jumps

        if followRealTime {
            // Real time: advance very slowly
            timeOfDay += deltaTime / 86400.0  // 24 hours = 86400 seconds
        } else {
            // Demo mode: advance at timeScale
            timeOfDay += (deltaTime / 86400.0) * timeScale
        }

        // Wrap around
        if timeOfDay >= 1.0 { timeOfDay = 0.0 }
        if timeOfDay < 0.0 { timeOfDay = 1.0 }

        // Update phase
        let newPhase = DayPhase.phase(for: timeOfDay)
        if newPhase != currentPhase {
            currentPhase = newPhase
            logger.info("DayNight phase changed to: \(newPhase.rawValue)")
        }
    }

    // MARK: - Lighting Update

    private func updateLighting() {
        updateSunPosition()
        updateSunColor()
        updateAmbientLight()
        updateSkyGradient()
    }

    private func updateSunPosition() {
        guard let sun = sunLight else { return }

        // Sun arc: rises in east (time=0.25), peaks at noon (0.5), sets in west (0.75)
        let sunAngle = (timeOfDay - 0.25) * 2 * .pi
        let elevation = sin(sunAngle)

        // Only show sun when above horizon
        let isDay = timeOfDay > 0.22 && timeOfDay < 0.78
        sun.isEnabled = isDay

        if isDay {
            // Sun position in sky arc
            let altitude = max(0.1, elevation) * Float.pi / 2  // 0 to 90 degrees
            let azimuth = (timeOfDay - 0.5) * Float.pi  // -90 to +90 degrees

            sun.look(
                at: SIMD3<Float>(0, 0, 0),
                from: SIMD3<Float>(
                    sin(azimuth) * 10,
                    sin(altitude) * 10,
                    cos(azimuth) * cos(altitude) * 10
                ),
                relativeTo: nil
            )
        }

        // Moon (opposite of sun)
        if let moon = moonLight {
            moon.isEnabled = !isDay
            if !isDay {
                let moonAzimuth = ((timeOfDay + 0.5).truncatingRemainder(dividingBy: 1.0) - 0.5) * Float.pi
                moon.look(
                    at: SIMD3<Float>(0, 0, 0),
                    from: SIMD3<Float>(sin(moonAzimuth) * 10, 8, cos(moonAzimuth) * 10),
                    relativeTo: nil
                )
            }
        }
    }

    private func updateSunColor() {
        guard let sun = sunLight else { return }

        // Color temperature and intensity based on time
        let config = lightingConfig(for: timeOfDay)

        sun.light.color = config.sunColor
        sun.light.intensity = config.sunIntensity

        // Shadow configuration
        if sun.shadow != nil {
            sun.shadow = DirectionalLightComponent.Shadow(
                maximumDistance: config.shadowDistance,
                depthBias: 0.5
            )
        }

        // Moon
        if let moon = moonLight {
            moon.light.color = config.moonColor
            moon.light.intensity = config.moonIntensity
        }
    }

    private func updateAmbientLight() {
        guard let ambient = ambientLight else { return }

        let config = lightingConfig(for: timeOfDay)
        ambient.light.color = config.ambientColor
        ambient.light.intensity = config.ambientIntensity
    }

    private func updateSkyGradient() {
        // Post notification with sky colors for SwiftUI to pick up
        let config = lightingConfig(for: timeOfDay)

        NotificationCenter.default.post(
            name: .skyColorsDidChange,
            object: SkyColors(top: config.skyTopColor, bottom: config.skyBottomColor)
        )
    }

    // MARK: - Lighting Configuration

    struct LightingConfig {
        let sunColor: UIColor
        let sunIntensity: Float
        let moonColor: UIColor
        let moonIntensity: Float
        let ambientColor: UIColor
        let ambientIntensity: Float
        let shadowDistance: Float
        let skyTopColor: UIColor
        let skyBottomColor: UIColor
    }

    private func lightingConfig(for time: Float) -> LightingConfig {
        switch DayPhase.phase(for: time) {
        case .night:
            return LightingConfig(
                sunColor: .clear,
                sunIntensity: 0,
                moonColor: UIColor(red: 0.7, green: 0.75, blue: 0.9, alpha: 1),
                moonIntensity: 2000,
                ambientColor: UIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1),
                ambientIntensity: 800,
                shadowDistance: 10,
                skyTopColor: UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1),
                skyBottomColor: UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1)
            )

        case .dawn:
            return LightingConfig(
                sunColor: UIColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1),
                sunIntensity: 4000,
                moonColor: .clear,
                moonIntensity: 0,
                ambientColor: UIColor(red: 0.3, green: 0.25, blue: 0.35, alpha: 1),
                ambientIntensity: 2000,
                shadowDistance: 15,
                skyTopColor: UIColor(red: 0.2, green: 0.15, blue: 0.35, alpha: 1),
                skyBottomColor: UIColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 1)
            )

        case .morning:
            return LightingConfig(
                sunColor: UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1),
                sunIntensity: 8000,
                moonColor: .clear,
                moonIntensity: 0,
                ambientColor: UIColor(red: 0.5, green: 0.55, blue: 0.6, alpha: 1),
                ambientIntensity: 3000,
                shadowDistance: 20,
                skyTopColor: UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1),
                skyBottomColor: UIColor(red: 0.7, green: 0.8, blue: 0.95, alpha: 1)
            )

        case .day:
            return LightingConfig(
                sunColor: UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1),
                sunIntensity: 12000,
                moonColor: .clear,
                moonIntensity: 0,
                ambientColor: UIColor(red: 0.6, green: 0.65, blue: 0.7, alpha: 1),
                ambientIntensity: 4000,
                shadowDistance: 25,
                skyTopColor: UIColor(red: 0.3, green: 0.55, blue: 0.95, alpha: 1),
                skyBottomColor: UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1)
            )

        case .evening:
            return LightingConfig(
                sunColor: UIColor(red: 1.0, green: 0.85, blue: 0.7, alpha: 1),
                sunIntensity: 8000,
                moonColor: .clear,
                moonIntensity: 0,
                ambientColor: UIColor(red: 0.55, green: 0.5, blue: 0.5, alpha: 1),
                ambientIntensity: 3000,
                shadowDistance: 20,
                skyTopColor: UIColor(red: 0.35, green: 0.45, blue: 0.7, alpha: 1),
                skyBottomColor: UIColor(red: 0.9, green: 0.7, blue: 0.5, alpha: 1)
            )

        case .dusk:
            return LightingConfig(
                sunColor: UIColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 1),
                sunIntensity: 4000,
                moonColor: .clear,
                moonIntensity: 0,
                ambientColor: UIColor(red: 0.4, green: 0.3, blue: 0.35, alpha: 1),
                ambientIntensity: 2000,
                shadowDistance: 15,
                skyTopColor: UIColor(red: 0.15, green: 0.15, blue: 0.35, alpha: 1),
                skyBottomColor: UIColor(red: 0.95, green: 0.4, blue: 0.3, alpha: 1)
            )

        case .twilight:
            return LightingConfig(
                sunColor: .clear,
                sunIntensity: 0,
                moonColor: UIColor(red: 0.6, green: 0.65, blue: 0.8, alpha: 1),
                moonIntensity: 1500,
                ambientColor: UIColor(red: 0.15, green: 0.12, blue: 0.25, alpha: 1),
                ambientIntensity: 1200,
                shadowDistance: 12,
                skyTopColor: UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1),
                skyBottomColor: UIColor(red: 0.2, green: 0.1, blue: 0.25, alpha: 1)
            )
        }
    }

    // MARK: - Manual Control

    /// Set time manually (for demo)
    func setTime(_ time: Float) {
        followRealTime = false
        timeOfDay = max(0, min(1, time))
    }

    /// Jump to specific phase
    func jumpToPhase(_ phase: DayPhase) {
        followRealTime = false
        switch phase {
        case .night: timeOfDay = 0.1
        case .dawn: timeOfDay = 0.25
        case .morning: timeOfDay = 0.38
        case .day: timeOfDay = 0.55
        case .evening: timeOfDay = 0.75
        case .dusk: timeOfDay = 0.85
        case .twilight: timeOfDay = 0.95
        }
    }

    /// Cycle to next phase (for button tap)
    func cyclePhase() {
        followRealTime = false
        switch currentPhase {
        case .night: jumpToPhase(.dawn)
        case .dawn: jumpToPhase(.morning)
        case .morning: jumpToPhase(.day)
        case .day: jumpToPhase(.evening)
        case .evening: jumpToPhase(.dusk)
        case .dusk: jumpToPhase(.twilight)
        case .twilight: jumpToPhase(.night)
        }
        logger.info("Cycled to phase: \(self.currentPhase.rawValue)")
    }

    /// Start fast time-lapse (for demo)
    func startTimeLapse(speed: Float = 60) {
        followRealTime = false
        timeScale = speed
    }

    /// Return to real time
    func returnToRealTime() {
        followRealTime = true
        timeScale = 1.0
        syncToRealTime()
    }

    // MARK: - Cleanup

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
}

// MARK: - Supporting Types

struct SkyColors {
    let top: UIColor
    let bottom: UIColor
}

extension Notification.Name {
    static let skyColorsDidChange = Notification.Name("skyColorsDidChange")
}
