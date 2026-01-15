import SwiftUI
import WatchKit

struct WatchGardenPickerView: View {
    @StateObject private var connectivity = WatchConnectivityManager.shared

    @State private var gardens: [Garden] = []
    @State private var selectedGarden: Garden?
    @State private var showingConfirmation = false
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else if gardens.isEmpty {
                emptyState
            } else {
                gardenList
            }
        }
        .navigationTitle("Choose Garden")
        .onAppear {
            loadGardens()
        }
        .alert("Garden Selected", isPresented: $showingConfirmation) {
            Button("OK") { }
        } message: {
            if let garden = selectedGarden {
                Text("\(garden.icon) \(garden.name) is ready for your focus session")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("No Gardens")
                .font(.headline)

            Text("Create a garden on your iPhone first")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Garden List

    private var gardenList: some View {
        List {
            ForEach(gardens) { garden in
                Button(action: {
                    selectGarden(garden)
                }) {
                    HStack(spacing: 12) {
                        Text(garden.icon)
                            .font(.system(size: 32))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(garden.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Text("\(garden.plantsCount) plants")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        if selectedGarden?.id == garden.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    selectedGarden?.id == garden.id
                        ? Color.green.opacity(0.15)
                        : Color.clear
                )
            }
        }
    }

    // MARK: - Actions

    private func loadGardens() {
        isLoading = true
        print("Loading gardens from iPhone...")

        connectivity.requestGardenList { receivedGardens in
            DispatchQueue.main.async {
                self.gardens = receivedGardens
                self.isLoading = false
                print("Loaded \(receivedGardens.count) gardens")
            }
        }
    }

    private func selectGarden(_ garden: Garden) {
        print("User selected garden: \(garden.name)")

        guard connectivity.isReachable else {
            print("iPhone not reachable")
            return
        }

        let message: [String: Any] = [
            "command": "selectGarden",
            "gardenId": garden.id.uuidString
        ]

        connectivity.sendMessage(message) { reply in
            DispatchQueue.main.async {
                self.selectedGarden = garden
                UserDefaults.standard.set(garden.id.uuidString, forKey: "selectedGardenID")
                UserDefaults.standard.set(garden.name, forKey: "selectedGardenName")
                WKInterfaceDevice.current().play(.success)
                self.showingConfirmation = true
                print("Selection confirmed by iPhone")
            }
        }
    }
}

#if DEBUG
struct WatchGardenPickerView_Previews: PreviewProvider {
    static var previews: some View {
        WatchGardenPickerView()
            .environmentObject(WatchConnectivityManager.shared)
    }
}
#endif
