import SwiftUI

struct OnboardingContainerView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            AppColors.richSoil
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with back button and progress bar
                VStack(spacing: Spacing.md) {
                    // Back button
                    HStack {
                        if viewModel.currentScreen != .welcome {
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                viewModel.previousScreen()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                    .frame(width: 44, height: 44)
                            }
                        } else {
                            Spacer()
                                .frame(width: 44, height: 44)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)

                    // Progress bar
                    OnboardingProgressBar(progress: viewModel.progress)
                        .padding(.horizontal, Spacing.xl)
                }
                .padding(.top, Spacing.xl)

                // Screen content
                screenView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentScreen)
    }

    @ViewBuilder
    private var screenView: some View {
        switch viewModel.currentScreen {
        case .welcome:
            WelcomeScreen(viewModel: viewModel)
        case .gardenConcept:
            GardenConceptScreen(viewModel: viewModel)
        case .createGarden:
            CreateGardenScreen(viewModel: viewModel)
        case .seedTypes:
            SeedTypesScreen(viewModel: viewModel)
        case .plantSpecies:
            PlantSpeciesScreen(viewModel: viewModel)
        case .durationPreferences:
            DurationPreferencesScreen(viewModel: viewModel)
        case .trackingIntro:
            TrackingIntroScreen(viewModel: viewModel)
        case .readyToStart:
            ReadyToStartScreen(viewModel: viewModel, hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppColors.lightSoil)
                    .frame(height: 4)

                Rectangle()
                    .fill(AppColors.healthy)
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.easeInOut, value: progress)
            }
        }
        .frame(height: 4)
    }
}
