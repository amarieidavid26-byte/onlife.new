import Foundation

class GardenDataManager {
    static let shared = GardenDataManager()

    private let gardensKey = "saved_gardens"
    private let sessionsKey = "saved_sessions"

    private init() {}

    // MARK: - Garden Operations

    func saveGarden(_ garden: Garden) {
        var gardens = loadGardens()

        if let index = gardens.firstIndex(where: { $0.id == garden.id }) {
            gardens[index] = garden
            print("🌳 Updated existing garden: \(garden.name)")
        } else {
            gardens.append(garden)
            print("🌳 Created new garden: \(garden.name)")
        }

        saveGardens(gardens)
    }

    func loadGardens() -> [Garden] {
        guard let data = UserDefaults.standard.data(forKey: gardensKey) else {
            print("🌳 No gardens found in storage")
            return []
        }

        do {
            let gardens = try JSONDecoder().decode([Garden].self, from: data)
            print("🌳 Loaded \(gardens.count) gardens from storage")
            return gardens
        } catch {
            print("❌ Failed to decode gardens: \(error)")
            return []
        }
    }

    func updateGarden(_ garden: Garden) {
        saveGarden(garden)
    }

    func deleteGarden(_ gardenId: UUID) {
        var gardens = loadGardens()
        gardens.removeAll { $0.id == gardenId }
        saveGardens(gardens)
        print("🌳 Deleted garden: \(gardenId)")
    }

    // MARK: - Plant Operations

    func savePlant(_ plant: Plant, to gardenId: UUID) {
        var gardens = loadGardens()

        guard let gardenIndex = gardens.firstIndex(where: { $0.id == gardenId }) else {
            print("❌ Garden not found: \(gardenId)")
            return
        }

        // Check if plant already exists
        if let plantIndex = gardens[gardenIndex].plants.firstIndex(where: { $0.id == plant.id }) {
            gardens[gardenIndex].plants[plantIndex] = plant
            print("🌱 Updated existing plant in garden: \(gardens[gardenIndex].name)")
        } else {
            gardens[gardenIndex].plants.append(plant)
            print("🌱 Added new plant to garden: \(gardens[gardenIndex].name)")
            print("🌱 Garden now has \(gardens[gardenIndex].plants.count) plants")
        }

        saveGardens(gardens)
    }

    func deletePlant(_ plantId: UUID, from gardenId: UUID) {
        var gardens = loadGardens()

        guard let gardenIndex = gardens.firstIndex(where: { $0.id == gardenId }) else {
            print("❌ Garden not found: \(gardenId)")
            return
        }

        gardens[gardenIndex].plants.removeAll { $0.id == plantId }
        saveGardens(gardens)
        print("🌱 Deleted plant: \(plantId)")
    }

    // MARK: - Helper Methods

    private func saveGardens(_ gardens: [Garden]) {
        do {
            let data = try JSONEncoder().encode(gardens)
            UserDefaults.standard.set(data, forKey: gardensKey)
            print("💾 Saved \(gardens.count) gardens to storage")
        } catch {
            print("❌ Failed to encode gardens: \(error)")
        }
    }

    // MARK: - Session Operations

    func saveSession(_ session: FocusSession) {
        var sessions = loadSessions()
        sessions.append(session)
        saveSessions(sessions)
        print("⏱️ Saved session: \(session.taskDescription)")
    }

    func loadSessions() -> [FocusSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey) else {
            print("⏱️ No sessions found in storage")
            return []
        }

        do {
            let sessions = try JSONDecoder().decode([FocusSession].self, from: data)
            print("⏱️ Loaded \(sessions.count) sessions from storage")
            return sessions
        } catch {
            print("❌ Failed to decode sessions: \(error)")
            return []
        }
    }

    func deleteSession(_ sessionId: UUID) {
        var sessions = loadSessions()
        sessions.removeAll { $0.id == sessionId }
        saveSessions(sessions)
        print("⏱️ Deleted session: \(sessionId)")
    }

    private func saveSessions(_ sessions: [FocusSession]) {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: sessionsKey)
            print("💾 Saved \(sessions.count) sessions to storage")
        } catch {
            print("❌ Failed to encode sessions: \(error)")
        }
    }

    func clearAllData() {
        UserDefaults.standard.removeObject(forKey: gardensKey)
        UserDefaults.standard.removeObject(forKey: sessionsKey)
        print("🗑️ Cleared all data (gardens and sessions)")
    }
}
