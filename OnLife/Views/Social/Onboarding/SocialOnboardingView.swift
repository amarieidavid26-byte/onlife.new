import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Social Onboarding Flow

struct SocialOnboardingFlow: View {
    @StateObject private var viewModel = SocialOnboardingFlowViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            backgroundGradient

            VStack(spacing: 0) {
                // Header with progress
                headerView

                // Page content
                TabView(selection: $viewModel.currentPage) {
                    ForEach(SocialOnboardingScreen.allCases) { screen in
                        OnboardingPageView(
                            config: screen.config,
                            onContinue: {
                                viewModel.nextPage()
                            }
                        )
                        .tag(screen)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentPage)
            }
        }
        .onChange(of: viewModel.isComplete) { _, complete in
            if complete {
                dismiss()
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                OnLifeColors.deepForest,
                Color(hex: "1A2520"),
                OnLifeColors.surface
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: Spacing.md) {
            // Skip button (debug only)
            HStack {
                Spacer()

                #if DEBUG
                Button("Skip") {
                    viewModel.skipOnboarding()
                }
                .font(OnLifeFont.label())
                .foregroundColor(OnLifeColors.textTertiary)
                .padding(.trailing, Spacing.md)
                #endif
            }
            .frame(height: 44)

            // Progress dots
            HStack(spacing: Spacing.sm) {
                ForEach(SocialOnboardingScreen.allCases) { screen in
                    Circle()
                        .fill(screen == viewModel.currentPage
                              ? OnLifeColors.socialTeal
                              : OnLifeColors.textMuted)
                        .frame(width: 8, height: 8)
                        .scaleEffect(screen == viewModel.currentPage ? 1.2 : 1.0)
                        .animation(.spring(duration: 0.3), value: viewModel.currentPage)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(OnLifeColors.cardBackground)
                        .frame(height: 3)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [OnLifeColors.socialTeal, OnLifeColors.socialTealLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * viewModel.progress, height: 3)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, Spacing.xl)
        }
        .padding(.top, Spacing.md)
    }
}

// MARK: - Onboarding Screens Enum

enum SocialOnboardingScreen: Int, CaseIterable, Identifiable {
    case introduction = 0
    case socialLearning = 1
    case comparison = 2
    case ready = 3

    var id: Int { rawValue }

    var config: OnboardingPageConfig {
        switch self {
        case .introduction:
            return OnboardingPageConfig(
                icon: "person.3.fill",
                iconColor: OnLifeColors.socialTeal,
                title: "OnLife Social Is Different",
                subtitle: "A different kind of social",
                bodyContent: .bullets([
                    .init(icon: "chart.line.uptrend.xyaxis", text: "We show trajectories, not just scores"),
                    .init(icon: "lightbulb", text: "We explain the psychology behind every feature"),
                    .init(icon: "arrow.triangle.2.circlepath", text: "We help your friends help you (and vice versa)"),
                    .init(icon: "graduationcap", text: "We designed for graduation, not addiction")
                ]),
                citation: nil,
                buttonTitle: "Show Me the Science"
            )

        case .socialLearning:
            return OnboardingPageConfig(
                icon: "brain.head.profile",
                iconColor: OnLifeColors.socialTeal,
                title: "The Science of Social Learning",
                subtitle: nil,
                bodyContent: .text("That's why OnLife shows you HOW others achieve flow, not just THAT they achieved it.\n\nYour friends' strategies become your shortcuts."),
                citation: OnboardingPageConfig.OnboardingCitation(
                    quote: "People learn fastest by observing models who are similar to themselves succeeding at what they want to achieve.",
                    source: "Bandura, Social Learning Theory (1977)"
                ),
                buttonTitle: "This Makes Sense"
            )

        case .comparison:
            return OnboardingPageConfig(
                icon: "arrow.left.arrow.right",
                iconColor: OnLifeColors.socialTeal,
                title: "Why Comparison Can Heal or Harm",
                subtitle: nil,
                bodyContent: .comparison(
                    toxic: OnboardingPageConfig.OnboardingBodyContent.ComparisonBox(
                        title: "TOXIC",
                        emoji: "😔",
                        example: "\"They're better than me\"",
                        points: ["Compares states", "Creates anxiety", "Focuses on ego"],
                        color: OnLifeColors.error
                    ),
                    healthy: OnboardingPageConfig.OnboardingBodyContent.ComparisonBox(
                        title: "HEALTHY",
                        emoji: "🌱",
                        example: "\"They improved 23% last month\"",
                        points: ["Compares growth", "Creates learning", "Focuses on skill"],
                        color: OnLifeColors.socialTeal
                    )
                ),
                citation: nil,
                buttonTitle: "I Want Healthy Comparison"
            )

        case .ready:
            return OnboardingPageConfig(
                icon: "sparkles",
                iconColor: OnLifeColors.amber,
                title: "You're Ready",
                subtitle: nil,
                bodyContent: .custom(AnyView(ReadyScreenContent())),
                citation: OnboardingPageConfig.OnboardingCitation(
                    quote: "The unexamined life is not worth living.",
                    source: "Socrates"
                ),
                buttonTitle: "Enter the Social Garden"
            )
        }
    }
}

// MARK: - Ready Screen Custom Content

private struct ReadyScreenContent: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("You now understand more about social psychology than most app designers.")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
                .multilineTextAlignment(.center)

            // Philosophy moments hint
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(OnLifeColors.amber.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 20))
                        .foregroundColor(OnLifeColors.amber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Look for 💡 icons")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Tap them to learn WHY we designed each feature")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                Spacer()
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )

            Text("You're not just using an app.\nYou're learning how your mind works.")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.sm)
        }
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - View Model

@MainActor
class SocialOnboardingFlowViewModel: ObservableObject {
    @Published var currentPage: SocialOnboardingScreen = .introduction
    @Published var isComplete = false
    @Published var isLoading = false

    private let db = Firestore.firestore()

    var progress: Double {
        let total = Double(SocialOnboardingScreen.allCases.count)
        let current = Double(currentPage.rawValue + 1)
        return current / total
    }

    var isLastPage: Bool {
        currentPage == .ready
    }

    func nextPage() {
        if isLastPage {
            completeOnboarding()
        } else if let nextScreen = SocialOnboardingScreen(rawValue: currentPage.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage = nextScreen
            }
            HapticManager.shared.impact(style: .light)
        }
    }

    func previousPage() {
        if let prevScreen = SocialOnboardingScreen(rawValue: currentPage.rawValue - 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage = prevScreen
            }
        }
    }

    func completeOnboarding() {
        isLoading = true

        Task {
            do {
                try await saveCompletion()
                HapticManager.shared.notificationOccurred(.success)
                isComplete = true
            } catch {
                HapticManager.shared.notificationOccurred(.error)
            }
            isLoading = false
        }
    }

    private func saveCompletion() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let data: [String: Any] = [
            "socialOnboardingCompleted": true,
            "socialOnboardingCompletedAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]

        try await db.collection("profiles").document(userId).setData(data, merge: true)

        // Also save locally
        UserDefaults.standard.set(true, forKey: "socialOnboardingCompleted")
    }

    #if DEBUG
    func skipOnboarding() {
        UserDefaults.standard.set(true, forKey: "socialOnboardingCompleted")
        isComplete = true
    }
    #endif
}

// MARK: - Social Onboarding Wrapper

/// Use this to present social onboarding as a full screen cover
struct SocialOnboardingPresenter: ViewModifier {
    @Binding var isPresented: Bool
    @AppStorage("socialOnboardingCompleted") private var hasCompleted = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                SocialOnboardingFlow()
            }
            .onAppear {
                // Auto-present if not completed
                if !hasCompleted {
                    isPresented = true
                }
            }
    }
}

extension View {
    func socialOnboarding(isPresented: Binding<Bool>) -> some View {
        modifier(SocialOnboardingPresenter(isPresented: isPresented))
    }
}

// MARK: - Preview

#if DEBUG
struct SocialOnboardingFlow_Previews: PreviewProvider {
    static var previews: some View {
        SocialOnboardingFlow()
            .preferredColorScheme(.dark)
    }
}
#endif
