import SwiftUI
import UIKit
import Combine

/// Provides accessibility support for the 3D garden
/// Handles VoiceOver descriptions, announcements, and reduced motion
@MainActor
class GardenAccessibilityHelper: ObservableObject {

    // MARK: - Singleton

    static let shared = GardenAccessibilityHelper()

    // MARK: - Published State

    @Published private(set) var isVoiceOverRunning: Bool = false
    @Published private(set) var prefersReducedMotion: Bool = false
    @Published private(set) var prefersReducedTransparency: Bool = false

    // MARK: - Initialization

    private init() {
        updateAccessibilityState()
        setupNotifications()
    }

    // MARK: - Setup

    private func setupNotifications() {
        // VoiceOver status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )

        // Reduced motion preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityStatusChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )

        // Reduced transparency preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityStatusChanged),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
    }

    @objc private func accessibilityStatusChanged() {
        updateAccessibilityState()
    }

    private func updateAccessibilityState() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        prefersReducedMotion = UIAccessibility.isReduceMotionEnabled
        prefersReducedTransparency = UIAccessibility.isReduceTransparencyEnabled
    }

    // MARK: - Garden Description

    /// Generate VoiceOver description for the garden
    func gardenDescription(for viewModel: GardenViewModel) -> String {
        let plantCount = viewModel.plants.count
        let gardenName = viewModel.selectedGarden?.name ?? "My Garden"

        if plantCount == 0 {
            return "\(gardenName). Empty garden. Complete focus sessions to grow plants."
        }

        // Summarize plants by species
        var speciesCounts: [String: Int] = [:]
        for plant in viewModel.plants {
            speciesCounts[plant.species.displayName, default: 0] += 1
        }

        let plantSummary = speciesCounts.map { "\($0.value) \($0.key)\($0.value > 1 ? "s" : "")" }
            .joined(separator: ", ")

        // Include health summary
        let healthyCount = viewModel.plants.filter { $0.healthLevel >= 0.7 }.count
        let healthStatus: String
        if healthyCount == plantCount {
            healthStatus = "All plants are healthy."
        } else if healthyCount > plantCount / 2 {
            healthStatus = "Most plants are healthy."
        } else {
            healthStatus = "Some plants need attention."
        }

        return "\(gardenName). \(plantCount) plants: \(plantSummary). \(healthStatus)"
    }

    /// Generate description for a specific plant
    func plantDescription(_ plant: Plant) -> String {
        let growth = Int(plant.growthProgress * 100)
        let health = Int(plant.healthLevel * 100)
        let stageName = growthStageName(for: plant.growthStage)

        var description = "\(plant.species.displayName), \(stageName) stage, \(growth)% grown"

        if health < 50 {
            description += ", needs care"
        } else if health >= 90 {
            description += ", thriving"
        }

        return description
    }

    // MARK: - Announcements

    /// Post an accessibility announcement
    func announceChange(_ message: String) {
        guard isVoiceOverRunning else { return }

        UIAccessibility.post(
            notification: .announcement,
            argument: message
        )
    }

    /// Announce plant growth
    func announcePlantGrowth(_ plant: Plant) {
        let stageName = growthStageName(for: plant.growthStage)
        let message = "\(plant.species.displayName) is now \(stageName)"
        announceChange(message)
    }

    /// Convert growth stage Int to readable name
    private func growthStageName(for stage: Int) -> String {
        switch stage {
        case 0: return "seed"
        case 1: return "sprout"
        case 2: return "young"
        case 3: return "mature"
        case 4: return "blooming"
        default: return "growing"
        }
    }

    /// Announce new plant added
    func announceNewPlant(_ plant: Plant) {
        let message = "New \(plant.species.displayName) planted in garden"
        announceChange(message)
    }

    /// Announce performance change
    func announcePerformanceChange(_ level: PerformanceMonitor.PerformanceLevel) {
        guard level == .low || level == .critical else { return }

        let message = level == .critical
            ? "Visual effects reduced to preserve battery"
            : "Some effects reduced for performance"

        announceChange(message)
    }

    /// Announce time of day change
    func announceTimeChange(_ phase: DayNightSystem.DayPhase) {
        let message = "Garden is now in \(phase.rawValue.lowercased())"
        announceChange(message)
    }

    // MARK: - Motion Adaptations

    /// Animation duration adjusted for reduced motion preference
    func animationDuration(_ standardDuration: Double) -> Double {
        prefersReducedMotion ? 0 : standardDuration
    }

    /// Whether to use spring animations
    var shouldUseSpringAnimations: Bool {
        !prefersReducedMotion
    }

    /// Whether wind effects should be enabled
    var shouldEnableWindEffects: Bool {
        !prefersReducedMotion
    }

    /// Whether particle effects should be enabled
    var shouldEnableParticleEffects: Bool {
        !prefersReducedMotion
    }

    // MARK: - Visual Adaptations

    /// Background opacity for overlays
    var overlayBackgroundOpacity: Double {
        prefersReducedTransparency ? 0.95 : 0.85
    }

    /// Whether to use blur effects
    var shouldUseBlurEffects: Bool {
        !prefersReducedTransparency
    }

    // MARK: - Accessibility Actions

    /// Custom accessibility actions for a plant
    func plantAccessibilityActions(for plant: Plant, onWater: @escaping () -> Void, onDetails: @escaping () -> Void) -> [AccessibilityActionItem] {
        var actions: [AccessibilityActionItem] = []

        if plant.healthLevel < 1.0 {
            actions.append(AccessibilityActionItem(name: "Water plant", action: onWater))
        }

        actions.append(AccessibilityActionItem(name: "View details", action: onDetails))

        return actions
    }

    // MARK: - Focus Management

    /// Request VoiceOver focus on a specific element
    func focusOn(_ element: Any?) {
        guard isVoiceOverRunning else { return }

        UIAccessibility.post(
            notification: .screenChanged,
            argument: element
        )
    }
}

// MARK: - Accessibility Action Item

struct AccessibilityActionItem {
    let name: String
    let action: () -> Void
}

// MARK: - SwiftUI Accessibility Modifiers

extension View {
    /// Apply garden-specific accessibility settings
    func gardenAccessibility(_ helper: GardenAccessibilityHelper) -> some View {
        self
            .animation(
                helper.shouldUseSpringAnimations
                    ? .spring(response: 0.4, dampingFraction: 0.8)
                    : .linear(duration: 0.1),
                value: UUID()
            )
    }
}

// MARK: - Accessibility Labels for System States

extension PerformanceMonitor.PerformanceLevel {
    var accessibilityLabel: String {
        switch self {
        case .high:
            return "Full visual quality"
        case .medium:
            return "Reduced particle effects"
        case .low:
            return "Minimal visual effects"
        case .critical:
            return "Basic visuals only"
        }
    }
}

extension DayNightSystem.DayPhase {
    var accessibilityLabel: String {
        switch self {
        case .dawn:
            return "Dawn, early morning light"
        case .morning:
            return "Morning, bright daylight"
        case .day:
            return "Midday, full sunlight"
        case .evening:
            return "Evening, golden light"
        case .dusk:
            return "Dusk, sunset colors"
        case .twilight:
            return "Twilight, fading light"
        case .night:
            return "Night, moonlit garden"
        }
    }
}
