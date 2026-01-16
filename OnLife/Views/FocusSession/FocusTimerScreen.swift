import SwiftUI

struct FocusTimerScreen: View {
    @ObservedObject var viewModel: FocusSessionViewModel
    @State private var plantScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: Spacing.xxxl) {
            Spacer()

            // Plant growth indicator with animations
            ZStack {
                // Glow effect
                Circle()
                    .fill(OnLifeColors.sage.opacity(glowOpacity))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                Text(plantEmoji)
                    .font(.system(size: 80))
                    .scaleEffect(plantScale)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.plantGrowthStage)
                    .onChange(of: viewModel.plantGrowthStage) { oldValue, newValue in
                        // Pulse animation on growth
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            plantScale = 1.15
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                            plantScale = 1.0
                        }
                        HapticManager.shared.impact(style: .medium)
                    }
            }
            .transition(.scale)

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

    var plantEmoji: String {
        let stage = viewModel.plantGrowthStage
        if stage < 3 { return "🌱" }
        else if stage < 7 { return "🪴" }
        else { return viewModel.selectedPlantSpecies.icon }
    }

    var glowOpacity: Double {
        // Glow intensity increases with growth stage
        let maxStage = 10.0
        let stage = Double(viewModel.plantGrowthStage)
        return min(stage / maxStage * 0.5, 0.5)
    }
}
