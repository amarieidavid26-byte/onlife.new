import Foundation
import SwiftUI
import Combine

/// Manages plant health states for loss aversion mechanics
/// Research: Soft penalties (reversible) outperform hard penalties (permanent)
/// 3-7 day grace period prevents anxiety while maintaining engagement
class PlantHealthManager: ObservableObject {
    static let shared = PlantHealthManager()

    @Published var plantHealthStates: [String: PlantHealth] = [:]
    @Published var gardenHealthSummary: GardenHealthSummary?

    private let userDefaults = UserDefaults.standard
    private let healthKey = "plantHealthStates_v1"

    private init() {
        loadHealthStates()
        updateAllPlantHealth()
    }

    // MARK: - Garden Health Summary

    struct GardenHealthSummary {
        let totalPlants: Int
        let thrivingPlants: Int
        let healthyPlants: Int
        let wiltingPlants: Int
        let criticalPlants: Int
        let overallHealth: OverallHealthLevel

        enum OverallHealthLevel {
            case excellent  // All thriving/healthy
            case good       // Mostly healthy, some wilting
            case warning    // Multiple wilting
            case danger     // Any critical

            var color: Color {
                switch self {
                case .excellent: return OnLifeColors.thriving
                case .good: return OnLifeColors.healthy
                case .warning: return OnLifeColors.warning
                case .danger: return OnLifeColors.error
                }
            }

            var emoji: String {
                switch self {
                case .excellent: return "🌟"
                case .good: return "✨"
                case .warning: return "⚠️"
                case .danger: return "🚨"
                }
            }

            var label: String {
                switch self {
                case .excellent: return "Excellent"
                case .good: return "Good"
                case .warning: return "Warning"
                case .danger: return "Danger!"
                }
            }
        }

        var healthPercentage: Double {
            guard totalPlants > 0 else { return 100 }
            let healthyCount = thrivingPlants + healthyPlants
            return Double(healthyCount) / Double(totalPlants) * 100
        }
    }

    // MARK: - Plant Tracking

    func trackPlant(_ plantId: String) {
        if plantHealthStates[plantId] == nil {
            plantHealthStates[plantId] = PlantHealth(
                plantId: plantId,
                lastCaredFor: Date(),
                healthState: .thriving,
                daysNeglected: 0,
                rescueCount: 0
            )
            saveHealthStates()
            updateGardenSummary()
        }
    }

    func trackPlant(id: UUID) {
        trackPlant(id.uuidString)
    }

    func careForPlant(_ plantId: String) {
        guard var health = plantHealthStates[plantId] else {
            // If plant not tracked, start tracking it
            trackPlant(plantId)
            return
        }

        let wasRescue = health.isInDanger
        health.revive()
        plantHealthStates[plantId] = health

        saveHealthStates()
        updateGardenSummary()

        // Trigger haptic feedback
        if wasRescue {
            HapticManager.shared.notification(type: .success)
        } else {
            HapticManager.shared.impact(style: .light)
        }
    }

    func careForPlant(id: UUID) {
        careForPlant(id.uuidString)
    }

    func careForAllPlants() {
        for plantId in plantHealthStates.keys {
            careForPlant(plantId)
        }
    }

    // MARK: - Health Updates

    func updateAllPlantHealth() {
        for id in plantHealthStates.keys {
            plantHealthStates[id]?.updateHealth()
        }

        saveHealthStates()
        updateGardenSummary()
    }

    func updateGardenSummary() {
        let states = Array(plantHealthStates.values)

        guard !states.isEmpty else {
            gardenHealthSummary = nil
            return
        }

        let thriving = states.filter { $0.healthState == .thriving || $0.healthState == .rescued }.count
        let healthy = states.filter { $0.healthState == .healthy }.count
        let wilting = states.filter { $0.healthState == .wilting }.count
        let critical = states.filter { $0.healthState == .critical }.count

        let overallLevel: GardenHealthSummary.OverallHealthLevel
        if critical > 0 {
            overallLevel = .danger
        } else if wilting >= 2 {
            overallLevel = .warning
        } else if wilting > 0 {
            overallLevel = .good
        } else {
            overallLevel = .excellent
        }

        gardenHealthSummary = GardenHealthSummary(
            totalPlants: states.count,
            thrivingPlants: thriving,
            healthyPlants: healthy,
            wiltingPlants: wilting,
            criticalPlants: critical,
            overallHealth: overallLevel
        )
    }

    // MARK: - Queries

    func getPlantsNeedingCare() -> [PlantHealth] {
        plantHealthStates.values
            .filter { $0.needsAttention }
            .sorted { $0.daysNeglected > $1.daysNeglected }
    }

    func getCriticalPlants() -> [PlantHealth] {
        plantHealthStates.values
            .filter { $0.isInDanger }
            .sorted { $0.daysNeglected > $1.daysNeglected }
    }

    func getHealthState(for plantId: String) -> PlantHealthState? {
        plantHealthStates[plantId]?.healthState
    }

    func getHealthState(for id: UUID) -> PlantHealthState? {
        getHealthState(for: id.uuidString)
    }

    var hasPlantInDanger: Bool {
        plantHealthStates.values.contains { $0.isInDanger }
    }

    var hasPlantsNeedingCare: Bool {
        plantHealthStates.values.contains { $0.needsAttention }
    }

    // MARK: - Persistence

    private func saveHealthStates() {
        if let encoded = try? JSONEncoder().encode(plantHealthStates) {
            userDefaults.set(encoded, forKey: healthKey)
        }
    }

    private func loadHealthStates() {
        if let data = userDefaults.data(forKey: healthKey),
           let decoded = try? JSONDecoder().decode([String: PlantHealth].self, from: data) {
            plantHealthStates = decoded
        }
    }

    // MARK: - Debug Helpers

    #if DEBUG
    func simulateNeglect(plantId: String, days: Int) {
        guard var health = plantHealthStates[plantId] else { return }

        let calendar = Calendar.current
        health.lastCaredFor = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        health.updateHealth()
        plantHealthStates[plantId] = health

        saveHealthStates()
        updateGardenSummary()
    }

    func resetAllHealth() {
        for id in plantHealthStates.keys {
            plantHealthStates[id]?.revive()
        }
        saveHealthStates()
        updateGardenSummary()
    }
    #endif
}
