import Foundation
import SwiftUI

/// Plant health state for loss aversion mechanics
/// Research basis: Kahneman & Tversky - losses feel 2.25x more impactful than gains
/// Uses "soft" loss aversion - plants wilt but can always be rescued
enum PlantHealthState: String, Codable {
    case thriving      // Actively maintained (0-2 days since last session)
    case healthy       // Recent care (2-4 days)
    case wilting       // Needs attention (4-6 days)
    case critical      // Urgent (6-7 days)
    case rescued       // Just revived from critical

    var emoji: String {
        switch self {
        case .thriving: return "🌟"
        case .healthy: return "🌱"
        case .wilting: return "🍂"
        case .critical: return "💀"
        case .rescued: return "💚"
        }
    }

    var label: String {
        switch self {
        case .thriving: return "Thriving"
        case .healthy: return "Healthy"
        case .wilting: return "Wilting"
        case .critical: return "Critical"
        case .rescued: return "Rescued!"
        }
    }

    var color: Color {
        switch self {
        case .thriving: return OnLifeColors.thriving
        case .healthy: return OnLifeColors.healthy
        case .wilting: return OnLifeColors.wilting
        case .critical: return OnLifeColors.error
        case .rescued: return OnLifeColors.sage
        }
    }

    var description: String {
        switch self {
        case .thriving:
            return "Your garden is flourishing! Keep up the great work."
        case .healthy:
            return "Plants are doing well. Visit soon to keep them thriving."
        case .wilting:
            return "Plants need attention. Complete a session to revive them."
        case .critical:
            return "Garden in danger! Focus now to save your plants."
        case .rescued:
            return "Amazing comeback! Your plants are recovering."
        }
    }

    var motivationalMessage: String {
        switch self {
        case .thriving:
            return "You're on fire!"
        case .healthy:
            return "Great consistency!"
        case .wilting:
            return "Don't lose your progress!"
        case .critical:
            return "One session to save your garden!"
        case .rescued:
            return "You saved them! Keep going!"
        }
    }

    var visualOpacity: Double {
        switch self {
        case .thriving: return 1.0
        case .healthy: return 1.0
        case .wilting: return 0.7
        case .critical: return 0.4
        case .rescued: return 1.0
        }
    }

    var saturation: Double {
        switch self {
        case .thriving: return 1.2
        case .healthy: return 1.0
        case .wilting: return 0.5
        case .critical: return 0.2
        case .rescued: return 1.1
        }
    }
}

// MARK: - Plant Health Tracking

struct PlantHealth: Codable, Identifiable {
    var id: String { plantId }
    let plantId: String
    var lastCaredFor: Date
    var healthState: PlantHealthState
    var daysNeglected: Int
    var rescueCount: Int // How many times rescued from critical

    init(
        plantId: String,
        lastCaredFor: Date = Date(),
        healthState: PlantHealthState = .thriving,
        daysNeglected: Int = 0,
        rescueCount: Int = 0
    ) {
        self.plantId = plantId
        self.lastCaredFor = lastCaredFor
        self.healthState = healthState
        self.daysNeglected = daysNeglected
        self.rescueCount = rescueCount
    }

    mutating func updateHealth() {
        let daysSince = Calendar.current.dateComponents([.day], from: lastCaredFor, to: Date()).day ?? 0
        daysNeglected = daysSince

        // Don't override rescued state immediately
        if healthState == .rescued && daysSince <= 1 {
            return
        }

        // Update state based on neglect
        healthState = calculateHealthState(daysSince: daysSince)
    }

    private func calculateHealthState(daysSince: Int) -> PlantHealthState {
        switch daysSince {
        case 0...2:
            return .thriving
        case 3...4:
            return .healthy
        case 5...6:
            return .wilting
        default:
            return .critical
        }
    }

    mutating func revive() {
        let wasCritical = healthState == .critical

        lastCaredFor = Date()
        daysNeglected = 0

        // If was critical, mark as rescued for special celebration
        if wasCritical {
            rescueCount += 1
            healthState = .rescued
        } else {
            healthState = .thriving
        }
    }

    var needsAttention: Bool {
        healthState == .wilting || healthState == .critical
    }

    var isInDanger: Bool {
        healthState == .critical
    }
}
