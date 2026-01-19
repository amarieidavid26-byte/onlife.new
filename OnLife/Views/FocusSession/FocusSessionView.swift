import SwiftUI

struct FocusSessionView: View {
    @ObservedObject var viewModel: FocusSessionViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            OnLifeColors.deepForest
                .ignoresSafeArea()

            switch viewModel.sessionPhase {
            case .input:
                // Input phase is handled by the parent view/sheet
                EmptyView()
            case .planting:
                SeedPlantingAnimation()
            case .focusing:
                FocusTimerScreen(viewModel: viewModel)
            case .completed:
                SessionCompletedScreen(viewModel: viewModel)
            case .abandoned:
                SessionAbandonedScreen(viewModel: viewModel)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Track app backgrounding/foregrounding during focus sessions
            guard viewModel.sessionPhase == .focusing else { return }

            switch newPhase {
            case .background:
                BehavioralFeatureCollector.shared.recordBackground()
            case .active:
                BehavioralFeatureCollector.shared.recordForeground()
            default:
                break
            }
        }
    }
}

// MARK: - Session Abandoned Screen
struct SessionAbandonedScreen: View {
    @ObservedObject var viewModel: FocusSessionViewModel

    var body: some View {
        VStack(spacing: Spacing.xxxl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                // Wilting plant
                Text("🥀")
                    .font(.system(size: 80))

                Text("Session Ended Early")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("You completed \(Int(viewModel.progress * 100))% of your focus time")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: Spacing.md) {
                    StatRow(label: "Task", value: viewModel.taskDescription)
                    StatRow(label: "Time Focused", value: formatDuration(viewModel.elapsedTime))
                    StatRow(label: "Goal", value: "\(viewModel.selectedDuration) min")
                }
                .padding(.horizontal, Spacing.xl)

                // Screen Activity Summary (if any distractions)
                let screenSummary = BehavioralFeatureCollector.shared.getScreenActivitySummary()
                if screenSummary.significantDistractions > 0 {
                    ScreenActivityCompactIndicator(
                        summary: screenSummary,
                        sessionDuration: viewModel.elapsedTime
                    )
                    .padding(.horizontal, Spacing.xl)
                }

                // App Switch Summary (if any switches)
                let appSwitchAnalysis = BehavioralFeatureCollector.shared.getAppSwitchAnalysis()
                if appSwitchAnalysis.totalSwitches > 0 {
                    AppSwitchCompactIndicator(
                        analysis: appSwitchAnalysis,
                        sessionDuration: viewModel.elapsedTime
                    )
                    .padding(.horizontal, Spacing.xl)
                }
            }

            Spacer()

            VStack(spacing: Spacing.md) {
                Text("Keep going! Every focus session helps build your habit.")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)

                PrimaryButton(title: "Back to Garden") {
                    viewModel.resetSession()
                }
                .padding(.horizontal, Spacing.xl)
            }
            .padding(.bottom, Spacing.xxxl)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }
}
