import SwiftUI
import RealityKit

/// Main container view for the 3D garden experience
/// Handles initialization, loading states, and error display
struct Garden3DContainerView: View {
    @ObservedObject var gardenViewModel: GardenViewModel
    @StateObject private var coordinator = GardenSceneCoordinator.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared

    // Access helper via shared singleton (not @StateObject - it's a utility class)
    private var accessibilityHelper: GardenAccessibilityHelper { GardenAccessibilityHelper.shared }

    @State private var isLoading = true
    @State private var showDebugOverlay = false

    var body: some View {
        ZStack {
            if isLoading {
                loadingView
            } else if let error = coordinator.currentError {
                errorBanner(error)
            }

            // Main 3D garden view
            Garden3DView(gardenViewModel: gardenViewModel)
                .opacity(isLoading ? 0 : 1)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(accessibilityHelper.gardenDescription(for: gardenViewModel))

            // Performance indicator (top-right, subtle)
            if performanceMonitor.performanceLevel != .high {
                VStack {
                    HStack {
                        Spacer()
                        performanceIndicator
                    }
                    Spacer()
                }
                .padding(.top, 60)
                .padding(.trailing, Spacing.md)
            }

            // Debug overlay (triple-tap to show)
            if showDebugOverlay {
                debugOverlay
            }
        }
        .task {
            await initializeGarden()
        }
        .onTapGesture(count: 3) {
            withAnimation {
                showDebugOverlay.toggle()
            }
        }
        // Accessibility announcements
        .onChange(of: gardenViewModel.plants.count) { _, newCount in
            accessibilityHelper.announceChange("Garden now has \(newCount) plants")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            coordinator.onEnterBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            coordinator.onEnterForeground()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.25, blue: 0.12),
                    Color(red: 0.2, green: 0.35, blue: 0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                // Animated plant icon
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [OnLifeColors.sage, OnLifeColors.healthy],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)

                Text("Growing your garden...")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(.white)

                // Progress bar
                VStack(spacing: Spacing.sm) {
                    ProgressView(value: coordinator.initializationProgress)
                        .progressViewStyle(GardenProgressStyle())
                        .frame(width: 200)

                    Text(coordinator.initializationStatus)
                        .font(OnLifeFont.caption())
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: GardenSceneCoordinator.GardenError) -> some View {
        VStack {
            HStack(spacing: Spacing.sm) {
                Image(systemName: errorIcon(for: error))
                    .foregroundColor(errorColor(for: error))

                Text(error.localizedDescription)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(.white)

                Spacer()

                Button {
                    // Dismiss or retry
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(errorColor(for: error).opacity(0.9))
            )
            .padding(.horizontal, Spacing.md)
            .padding(.top, 60)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func errorIcon(for error: GardenSceneCoordinator.GardenError) -> String {
        switch error {
        case .memoryPressure:
            return "memorychip"
        case .thermalCritical:
            return "thermometer.high"
        default:
            return "exclamationmark.triangle"
        }
    }

    private func errorColor(for error: GardenSceneCoordinator.GardenError) -> Color {
        switch error {
        case .memoryPressure, .thermalCritical:
            return .orange
        default:
            return .red
        }
    }

    // MARK: - Performance Indicator

    private var performanceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: performanceMonitor.performanceLevel.icon)
                .font(.caption)

            if performanceMonitor.performanceLevel == .critical {
                Text("Limited")
                    .font(OnLifeFont.caption())
            }
        }
        .foregroundColor(performanceLevelColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityLabel("Performance: \(performanceMonitor.performanceLevel.rawValue)")
    }

    private var performanceLevelColor: Color {
        switch performanceMonitor.performanceLevel {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        case .critical: return .red
        }
    }

    // MARK: - Debug Overlay

    private var debugOverlay: some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Debug Info")
                    .font(.caption.bold())
                    .foregroundColor(.white)

                Text(coordinator.systemStatus)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))

                Divider()
                    .background(Color.white.opacity(0.3))

                // Quick actions
                HStack(spacing: Spacing.md) {
                    Button("Force Low") {
                        performanceMonitor.forceLevel(.low)
                    }
                    .buttonStyle(DebugButtonStyle())

                    Button("Force High") {
                        performanceMonitor.forceLevel(.high)
                    }
                    .buttonStyle(DebugButtonStyle())

                    Button("Celebrate") {
                        coordinator.gardenScene?.triggerCelebration()
                    }
                    .buttonStyle(DebugButtonStyle())
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(Color.black.opacity(0.85))
            )
            .padding(Spacing.md)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Initialization

    private func initializeGarden() async {
        await coordinator.initialize()

        withAnimation(.easeOut(duration: 0.5)) {
            isLoading = false
        }
    }
}

// MARK: - Custom Progress Style

struct GardenProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [OnLifeColors.sage, OnLifeColors.healthy],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * (configuration.fractionCompleted ?? 0), height: 8)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Debug Button Style

struct DebugButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OnLifeFont.caption())
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(OnLifeColors.sage.opacity(configuration.isPressed ? 0.5 : 0.8))
            .cornerRadius(CornerRadius.small)
    }
}

// MARK: - Preview

#if DEBUG
struct Garden3DContainerView_Previews: PreviewProvider {
    static var previews: some View {
        Garden3DContainerView(gardenViewModel: GardenViewModel())
            .preferredColorScheme(.dark)
    }
}
#endif
