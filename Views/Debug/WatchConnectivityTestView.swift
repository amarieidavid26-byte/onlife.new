import SwiftUI

struct WatchConnectivityTestView: View {
    @StateObject private var connectivity = WatchConnectivityManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Watch Connectivity Test")
                .font(.title)

            VStack(alignment: .leading) {
                Text("Status:")
                Text("- Paired: \(connectivity.isPaired ? "Yes" : "No")")
                Text("- Installed: \(connectivity.isWatchAppInstalled ? "Yes" : "No")")
                Text("- Reachable: \(connectivity.isReachable ? "Yes" : "No")")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            Button("Send Test Message") {
                connectivity.sendTestMessage()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!connectivity.isReachable)

            Text("Check Xcode console for results")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
}
