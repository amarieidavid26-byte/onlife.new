import SwiftUI

struct FocusSessionView: View {
    @ObservedObject var viewModel: FocusSessionViewModel

    var body: some View {
        ZStack {
            AppColors.richSoil
                .ignoresSafeArea()

            if viewModel.sessionPhase == .planting {
                SeedPlantingAnimation()
            } else if viewModel.sessionPhase == .focusing {
                FocusTimerScreen(viewModel: viewModel)
            } else if viewModel.sessionPhase == .completed {
                SessionCompletedScreen(viewModel: viewModel)
            }
        }
    }
}
