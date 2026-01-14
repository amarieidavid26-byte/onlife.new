import SwiftUI
import WatchConnectivity

/// Debug view for WatchConnectivity issues
/// Add this to your settings or a debug menu to diagnose pairing problems
struct WatchConnectivityDebugView: View {
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @State private var showingTestResult = false
    @State private var testResult = ""
    
    var body: some View {
        List {
            Section("System Status") {
                InfoRow(label: "WCSession Supported", value: WCSession.isSupported() ? "✅ YES" : "❌ NO", color: WCSession.isSupported() ? .green : .red)
                
                #if os(iOS)
                InfoRow(label: "Watch Paired", value: connectivity.isPaired ? "✅ YES" : "❌ NO", color: connectivity.isPaired ? .green : .red)
                InfoRow(label: "Watch App Installed", value: connectivity.isWatchAppInstalled ? "✅ YES" : "❌ NO", color: connectivity.isWatchAppInstalled ? .green : .red)
                #endif
            }
            
            Section("Connection Status") {
                InfoRow(label: "Session Activated", value: connectivity.isSessionActivated ? "✅ YES" : "❌ NO", color: connectivity.isSessionActivated ? .green : .red)
                InfoRow(label: "Reachable", value: connectivity.isReachable ? "✅ YES" : "❌ NO", color: connectivity.isReachable ? .green : .red)
                InfoRow(label: "Activation State", value: activationStateText, color: activationStateColor)
            }
            
            Section("Delegate Info") {
                InfoRow(label: "Delegate Set", value: WCSession.default.delegate != nil ? "✅ YES" : "❌ NO", color: WCSession.default.delegate != nil ? .green : .red)
                InfoRow(label: "Thread", value: Thread.isMainThread ? "Main ✅" : "Background ⚠️", color: Thread.isMainThread ? .green : .orange)
            }
            
            Section("Actions") {
                Button(action: forceReactivate) {
                    Label("Force Re-Activate Session", systemImage: "arrow.clockwise")
                }
                
                Button(action: sendTestMessage) {
                    Label("Send Test Message", systemImage: "paperplane")
                }
                .disabled(!connectivity.isSessionActivated || !connectivity.isReachable)
                
                Button(action: checkActivationStatus) {
                    Label("Check Activation Status", systemImage: "magnifyingglass")
                }
            }
            
            Section("Bundle IDs") {
                #if os(iOS)
                InfoRow(label: "iPhone Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown", color: .primary)
                if let watchAppURL = WCSession.default.watchDirectoryURL {
                    InfoRow(label: "Watch Directory", value: watchAppURL.path, color: .secondary)
                }
                #elseif os(watchOS)
                InfoRow(label: "Watch Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown", color: .primary)
                InfoRow(label: "Expected Format", value: "{iPhone}.watchkitapp", color: .secondary)
                #endif
            }
            
            if !testResult.isEmpty {
                Section("Test Result") {
                    Text(testResult)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Troubleshooting") {
                VStack(alignment: .leading, spacing: 8) {
                    TroubleshootingStep(number: 1, text: "Force quit both apps")
                    TroubleshootingStep(number: 2, text: "Restart iPhone completely")
                    TroubleshootingStep(number: 3, text: "Restart Apple Watch")
                    TroubleshootingStep(number: 4, text: "Launch iPhone app FIRST")
                    TroubleshootingStep(number: 5, text: "Then launch Watch app")
                    TroubleshootingStep(number: 6, text: "Wait 5-10 seconds")
                }
                .font(.caption)
            }
        }
        .navigationTitle("WatchConnectivity Debug")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private var activationStateText: String {
        switch WCSession.default.activationState {
        case .notActivated: return "0 - Not Activated ❌"
        case .inactive: return "1 - Inactive ⚠️"
        case .activated: return "2 - Activated ✅"
        @unknown default: return "Unknown"
        }
    }
    
    private var activationStateColor: Color {
        switch WCSession.default.activationState {
        case .notActivated: return .red
        case .inactive: return .orange
        case .activated: return .green
        @unknown default: return .gray
        }
    }
    
    private func forceReactivate() {
        print("🔄 [Debug] Force re-activating WCSession...")
        
        // Only reactivate if deactivated (iOS only)
        #if os(iOS)
        if WCSession.default.activationState != .activated {
            WCSession.default.activate()
        }
        #endif
        
        // Force check
        connectivity.forceActivationCheck()
        
        testResult = "Re-activation attempted. Check console logs."
    }
    
    private func sendTestMessage() {
        testResult = "Sending test message..."
        
        connectivity.sendMessage(["test": "ping", "timestamp": Date().timeIntervalSince1970]) { reply in
            DispatchQueue.main.async {
                testResult = "✅ Reply received: \(reply)"
            }
        }
        
        // Timeout after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if testResult == "Sending test message..." {
                testResult = "⚠️ No reply received (timeout)"
            }
        }
    }
    
    private func checkActivationStatus() {
        testResult = """
        Current Status:
        • Supported: \(WCSession.isSupported())
        • State: \(WCSession.default.activationState.rawValue)
        • Reachable: \(WCSession.default.isReachable)
        • Delegate: \(WCSession.default.delegate != nil)
        • Thread: \(Thread.isMainThread ? "Main" : "Background")
        
        #if os(iOS)
        • Paired: \(WCSession.default.isPaired)
        • Watch app: \(WCSession.default.isWatchAppInstalled)
        #endif
        """
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct TroubleshootingStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text("\(number).")
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 20, alignment: .leading)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

#if DEBUG
struct WatchConnectivityDebugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WatchConnectivityDebugView()
        }
    }
}
#endif
