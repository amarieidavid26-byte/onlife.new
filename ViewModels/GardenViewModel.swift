import Foundation
import SwiftUI
import Combine

class GardenViewModel: ObservableObject {
    @Published var gardens: [Garden] = []
    @Published var selectedGarden: Garden?
    @Published var plants: [Plant] = []
    @Published var isLoading: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadGardens()
        observeDecayUpdates()
    }

    private func observeDecayUpdates() {
        PlantDecayManager.shared.$needsUpdate
            .sink { [weak self] needsUpdate in
                if needsUpdate {
                    print("🔄 Decay update detected, refreshing gardens...")
                    self?.refreshGardens()
                    PlantDecayManager.shared.needsUpdate = false
                }
            }
            .store(in: &cancellables)
    }

    func loadGardens() {
        print("🌳 GardenViewModel.loadGardens() called")
        isLoading = true

        gardens = GardenDataManager.shared.loadGardens()
        print("🌳 Loaded \(gardens.count) gardens")

        // Select first garden
        selectedGarden = gardens.first
        print("🌳 Selected garden: \(selectedGarden?.name ?? "none")")

        // Load plants for selected garden
        if let garden = selectedGarden {
            plants = garden.plants
            print("🌳 Loaded \(plants.count) plants")
        }

        isLoading = false
    }

    func refreshGardens() {
        print("🔄 GardenViewModel.refreshGardens() called")
        loadGardens()
    }

    // MARK: - Garden Selection (for Watch)

    @discardableResult
    func selectGarden(id: UUID) -> Bool {
        print("🌳 [GardenViewModel] selectGarden called with id: \(id)")

        guard let garden = gardens.first(where: { $0.id == id }) else {
            print("❌ [GardenViewModel] Garden not found with id: \(id)")
            return false
        }

        selectedGarden = garden
        plants = garden.plants

        print("✅ [GardenViewModel] Selected garden: \(garden.name) with \(plants.count) plants")
        return true
    }

    // MARK: - Computed Properties

    var plantCount: Int {
        selectedGarden?.plantsCount ?? 0
    }

    var totalFocusTime: String {
        guard let garden = selectedGarden else { return "0m" }

        let totalSeconds = garden.totalFocusTime
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Garden Management

    func createGarden(name: String, icon: String) {
        let newGarden = Garden(
            userId: UUID(),
            name: name,
            icon: icon
        )

        GardenDataManager.shared.saveGarden(newGarden)
        refreshGardens()
        selectedGarden = gardens.first { $0.id == newGarden.id }

        print("🌳 Created new garden: \(name) \(icon)")
    }

    func isGardenNameValid(_ name: String) -> Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }

        let isUnique = !gardens.contains {
            $0.name.lowercased() == name.trimmingCharacters(in: .whitespaces).lowercased()
        }

        return isUnique
    }

    func validationError(for name: String) -> String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Garden name cannot be empty"
        }

        if !isGardenNameValid(name) {
            return "A garden with this name already exists"
        }

        return nil
    }

    func validationErrorForEdit(name: String, currentGarden: Garden) -> String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Garden name cannot be empty"
        }

        // Allow keeping the same name
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if trimmedName.lowercased() == currentGarden.name.lowercased() {
            return nil
        }

        // Check for duplicates with other gardens
        let isDuplicate = gardens.contains {
            $0.id != currentGarden.id && $0.name.lowercased() == trimmedName.lowercased()
        }

        if isDuplicate {
            return "A garden with this name already exists"
        }

        return nil
    }

    func updateGarden(_ garden: Garden, name: String, icon: String) {
        var updatedGarden = garden
        updatedGarden.name = name
        updatedGarden.icon = icon

        GardenDataManager.shared.updateGarden(updatedGarden)
        refreshGardens()

        print("🌳 Updated garden: \(name) \(icon)")
    }

    func deleteGarden(_ garden: Garden) {
        // Don't allow deleting the last garden
        guard gardens.count > 1 else {
            print("⚠️ Cannot delete last garden")
            return
        }

        GardenDataManager.shared.deleteGarden(garden.id)
        refreshGardens()

        print("🗑️ Deleted garden: \(garden.name)")
    }

    func plants(for gardenId: UUID) -> [Plant] {
        return gardens.first(where: { $0.id == gardenId })?.plants ?? []
    }
}
