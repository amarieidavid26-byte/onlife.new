import Foundation

struct Garden: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var name: String
    var icon: String
    var createdAt: Date
    var plants: [Plant]

    init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        icon: String,
        createdAt: Date = Date(),
        plants: [Plant] = []
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.icon = icon
        self.createdAt = createdAt
        self.plants = plants
    }

    // Computed properties
    var plantsCount: Int {
        plants.count
    }

    var healthyPlantsCount: Int {
        plants.filter { $0.healthStatus == .healthy || $0.healthStatus == .thriving }.count
    }

    var totalFocusTime: TimeInterval {
        plants.reduce(0) { $0 + $1.totalFocusTime }
    }

    var healthLevel: Int {
        guard !plants.isEmpty else { return 100 }
        let avgHealth = plants.reduce(0.0) { $0 + $1.health } / Double(plants.count)
        return Int(avgHealth)
    }
}
