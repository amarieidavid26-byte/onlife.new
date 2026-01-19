import SwiftUI

struct FocusTimerScreen: View {
    @ObservedObject var viewModel: FocusSessionViewModel

    var body: some View {
        VStack(spacing: Spacing.xxxl) {
            Spacer()

            // Animated plant with organic growth effects
            AnimatedPlantView(
                growthStage: viewModel.plantGrowthStage,
                plantSpecies: viewModel.selectedPlantSpecies,
                isWilting: viewModel.plantHealth < 70,
                isPaused: viewModel.isPaused
            )
            .frame(height: 200)

            // Timer
            ZStack {
                Circle()
                    .stroke(OnLifeColors.surface, lineWidth: ComponentSize.progressRingLineWidth)
                    .frame(width: ComponentSize.progressRingSize, height: ComponentSize.progressRingSize)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(OnLifeColors.sage, style: StrokeStyle(lineWidth: ComponentSize.progressRingLineWidth, lineCap: .round))
                    .frame(width: ComponentSize.progressRingSize, height: ComponentSize.progressRingSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: viewModel.progress)

                VStack(spacing: Spacing.sm) {
                    Text(viewModel.timeString)
                        .font(OnLifeFont.timer())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(viewModel.taskDescription)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, Spacing.xl)
                }
            }

            // Controls
            HStack(spacing: Spacing.xl) {
                Button(action: {
                    if viewModel.isPaused {
                        viewModel.resumeSession()
                    } else {
                        viewModel.pauseSession()
                    }
                }) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 24))
                        .foregroundColor(OnLifeColors.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(OnLifeColors.surface)
                        .cornerRadius(30)
                }

                Button(action: {
                    viewModel.endSession()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 24))
                        .foregroundColor(OnLifeColors.terracotta)
                        .frame(width: 60, height: 60)
                        .background(OnLifeColors.surface)
                        .cornerRadius(30)
                }
            }

            Spacer()
        }
    }
}
