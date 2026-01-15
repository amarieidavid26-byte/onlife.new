import SwiftUI
import WatchKit

struct WatchGardenPickerView: View {
    @StateObject private var connectivity = WatchConnectivityManager.shared

    @State private var gardens: [Garden] = []
    @State private var selectedGarden: Garden?
    @State private var showingConfirmation = false
    @State private var isLoading = false
    @State private var fetchError: String?
    @State private var fetchTask: Task<Void, Never>?

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
            } else if let error = fetchError {
                errorState(message: error)
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

            Button(action: {
                loadGardens()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Error State

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Unable to Load")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                fetchError = nil
                loadGardens()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
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
        // Cancel any existing fetch
        fetchTask?.cancel()
        fetchError = nil
        isLoading = true
        print("Loading gardens from iPhone...")

        // Check connectivity first
        guard connectivity.isReachable else {
            isLoading = false
            fetchError = "iPhone not connected. Please ensure your iPhone is nearby."
            WKInterfaceDevice.current().play(.failure)
            return
        }

        var didReceiveResponse = false

        // Set up timeout
        fetchTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds

            await MainActor.run {
                if !didReceiveResponse && isLoading {
                    isLoading = false
                    fetchError = "Request timed out. Please check your iPhone connection and try again."
                    WKInterfaceDevice.current().play(.failure)
                    print("⚠️ Garden fetch timed out")
                }
            }
        }

        connectivity.requestGardenList { receivedGardens in
            didReceiveResponse = true

            DispatchQueue.main.async {
                self.fetchTask?.cancel()
                self.gardens = receivedGardens
                self.isLoading = false

                if receivedGardens.isEmpty {
                    print("No gardens found on iPhone")
                } else {
                    print("Loaded \(receivedGardens.count) gardens")
                }
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
