import SwiftUI

struct FocusSessionView: View {
    @ObservedObject var viewModel: FocusSessionViewModel

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
