import SwiftUI

// MARK: - Social Colors Extension

extension OnLifeColors {
    /// OnLife's signature teal for social features
    static let socialTeal = Color(hex: "48C9B0")
    static let socialTealLight = Color(hex: "5DD3BC")
    static let socialTealDark = Color(hex: "3AB89E")
}

// MARK: - Social Onboarding View

struct SocialOnboardingView: View {
    @StateObject private var viewModel = SocialOnboardingViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            backgroundGradient

            VStack(spacing: 0) {
                // Header
                headerView

                // Page content
                pageContent
                    .opacity(viewModel.contentOpacity)

                // Bottom area with button
                bottomArea
            }
        }
        .onChange(of: viewModel.hasCompletedOnboarding) { _, completed in
            if completed {
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
            // Back button (only show if not on first page)
            HStack {
                if !viewModel.isFirstPage {
                    Button(action: {
                        viewModel.previousPage()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(OnLifeColors.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                } else {
                    Spacer()
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Page indicator dots
                HStack(spacing: Spacing.sm) {
                    ForEach(SocialOnboardingPage.allCases) { page in
                        Circle()
                            .fill(page == viewModel.currentPage ? OnLifeColors.socialTeal : OnLifeColors.textMuted)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.currentPage)
                    }
                }

                Spacer()

                // Skip button (debug only)
                #if DEBUG
                Button("Skip") {
                    viewModel.skipOnboarding()
                }
                .font(OnLifeFont.label())
                .foregroundColor(OnLifeColors.textTertiary)
                .frame(width: 44, height: 44)
                #else
                Spacer()
                    .frame(width: 44, height: 44)
                #endif
            }
            .padding(.horizontal, Spacing.md)

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
        .padding(.top, Spacing.lg)
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch viewModel.currentPage {
        case .welcome:
            WelcomePageView()
        case .flowIsSacred:
            FlowIsSacredPageView()
        case .learnFromEachOther:
            LearnFromEachOtherPageView()
        case .trajectoriesOverTrophies:
            TrajectoriesPageView()
        case .commitment:
            CommitmentPageView(
                principles: $viewModel.principles,
                onToggle: viewModel.togglePrinciple,
                onAcceptAll: viewModel.acceptAllPrinciples
            )
        }
    }

    // MARK: - Bottom Area

    private var bottomArea: some View {
        VStack(spacing: Spacing.md) {
            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            // Next/Complete button
            Button(action: {
                viewModel.nextPage()
            }) {
                HStack(spacing: Spacing.sm) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.textPrimary))
                    } else {
                        Text(viewModel.nextButtonTitle)
                            .font(OnLifeFont.button())

                        if !viewModel.isLastPage {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                .foregroundColor(OnLifeColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(
                            viewModel.canProceed
                                ? OnLifeColors.socialTeal
                                : OnLifeColors.textMuted
                        )
                )
            }
            .disabled(!viewModel.canProceed || viewModel.isLoading)
            .padding(.horizontal, Spacing.xl)
            .animation(.easeInOut(duration: 0.2), value: viewModel.canProceed)
        }
        .padding(.bottom, Spacing.xxxl)
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePageView: View {
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                Spacer()
                    .frame(height: Spacing.xl)

                // Icon
                ZStack {
                    Circle()
                        .fill(OnLifeColors.socialTeal.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [OnLifeColors.socialTeal, OnLifeColors.socialTealLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                .onAppear {
                    withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                        iconScale = 1.0
                        iconOpacity = 1.0
                    }
                }

                // Title
                VStack(spacing: Spacing.sm) {
                    Text("Welcome to the")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)

                    Text("Flow Community")
                        .font(OnLifeFont.displayLarge())
                        .foregroundColor(OnLifeColors.textPrimary)
                }

                // Subtitle
                Text("A different kind of social")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.socialTeal)

                // Body
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Most apps use social features to keep you addicted. We use them to help you master your own mind.")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        FeaturePoint(icon: "chart.line.uptrend.xyaxis", text: "We show trajectories, not just scores")
                        FeaturePoint(icon: "lightbulb", text: "We explain the psychology behind every feature")
                        FeaturePoint(icon: "arrow.triangle.2.circlepath", text: "We help your friends help you (and vice versa)")
                        FeaturePoint(icon: "graduationcap", text: "We designed for graduation, not addiction")
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .padding(.horizontal, Spacing.lg)

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
        }
    }
}

// MARK: - Page 2: Flow Is Sacred

private struct FlowIsSacredPageView: View {
    @State private var showContent = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                Spacer()
                    .frame(height: Spacing.xl)

                // Icon
                ZStack {
                    Circle()
                        .fill(OnLifeColors.socialTeal.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 44))
                        .foregroundStyle(OnLifeColors.socialTeal)
                }

                // Title
                Text("Flow Is Sacred")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("We protect your focus")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.socialTeal)

                // Quote card
                VStack(spacing: Spacing.md) {
                    Text("\"Flow requires loss of self-consciousness. The moment you're aware of being observed, you shift from flow to performance mode.\"")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .italic()
                        .multilineTextAlignment(.center)

                    Text("— Csikszentmihalyi, \"Flow\" (1990)")
                        .font(OnLifeFont.labelSmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding(Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .fill(OnLifeColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                                .stroke(OnLifeColors.socialTeal.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, Spacing.lg)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                // Explanation
                VStack(spacing: Spacing.md) {
                    Text("That's why OnLife shows zero friend activity during your sessions.")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("We connect you before and after. During, you're alone with your focus.")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)

                    // Mantra
                    Text("Focus alone. Celebrate together.")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.socialTeal)
                        .padding(.top, Spacing.sm)
                }
                .padding(.horizontal, Spacing.xl)

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
            }
        }
    }
}

// MARK: - Page 3: Learn From Each Other

private struct LearnFromEachOtherPageView: View {
    @State private var showContent = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                Spacer()
                    .frame(height: Spacing.xl)

                // Icon
                ZStack {
                    Circle()
                        .fill(OnLifeColors.socialTeal.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 44))
                        .foregroundStyle(OnLifeColors.socialTeal)
                }

                // Title
                Text("Learn From Each Other")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Positive-sum networking")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.socialTeal)

                // Quote card
                VStack(spacing: Spacing.md) {
                    Text("\"Humans learn fastest by observing successful people who are similar to themselves.\"")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .italic()
                        .multilineTextAlignment(.center)

                    Text("— Bandura, Social Learning Theory (1977)")
                        .font(OnLifeFont.labelSmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding(Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .fill(OnLifeColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                                .stroke(OnLifeColors.socialTeal.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, Spacing.lg)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                // Explanation
                VStack(spacing: Spacing.md) {
                    Text("The Protocol Library shows you HOW others achieve flow, not just THAT they achieved it.")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("Your friends' discoveries become your shortcuts.")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("When someone finds what works, everyone benefits.")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.socialTeal)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.sm)
                }
                .padding(.horizontal, Spacing.xl)

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
            }
        }
    }
}

// MARK: - Page 4: Trajectories Over Trophies

private struct TrajectoriesPageView: View {
    @State private var showContent = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                Spacer()
                    .frame(height: Spacing.xl)

                // Icon
                ZStack {
                    Circle()
                        .fill(OnLifeColors.socialTeal.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 44))
                        .foregroundStyle(OnLifeColors.socialTeal)
                }

                // Title
                Text("Trajectories Over Trophies")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Non-toxic comparison")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.socialTeal)

                // Comparison cards
                HStack(spacing: Spacing.md) {
                    // Toxic
                    ComparisonModeCard(
                        title: "TOXIC",
                        emoji: "😔",
                        example: "\"They scored 92, I scored 78\"",
                        bullets: ["Compares states", "Creates anxiety", "Focuses on ego"],
                        accentColor: OnLifeColors.error
                    )

                    // Healthy
                    ComparisonModeCard(
                        title: "HEALTHY",
                        emoji: "🌱",
                        example: "\"They improved 23% last month\"",
                        bullets: ["Compares growth", "Creates learning", "Focuses on skill"],
                        accentColor: OnLifeColors.socialTeal
                    )
                }
                .padding(.horizontal, Spacing.lg)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                // Explanation
                VStack(spacing: Spacing.md) {
                    Text("OnLife defaults to showing trajectories because your growth rate matters more than where you are right now.")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("Where you're going beats where you've been.")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.socialTeal)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.sm)

                    Text("— Dweck, \"Mindset\" (2006)")
                        .font(OnLifeFont.labelSmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding(.horizontal, Spacing.xl)

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
            }
        }
    }
}

// MARK: - Page 5: Commitment

private struct CommitmentPageView: View {
    @Binding var principles: [SocialCommitmentPrinciple]
    let onToggle: (SocialCommitmentPrinciple) -> Void
    let onAcceptAll: () -> Void

    @State private var showContent = false

    private var acceptedCount: Int {
        principles.filter { $0.isAccepted }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                Spacer()
                    .frame(height: Spacing.lg)

                // Icon
                ZStack {
                    Circle()
                        .fill(OnLifeColors.socialTeal.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(OnLifeColors.socialTeal)
                }

                // Title
                Text("Your Commitment")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("By joining the Flow Community, you're agreeing to support a different kind of social experience.")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)

                // Principles checklist
                VStack(spacing: Spacing.md) {
                    ForEach(principles) { principle in
                        PrincipleCheckbox(
                            principle: principle,
                            onToggle: { onToggle(principle) }
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                    }
                }
                .padding(.horizontal, Spacing.lg)

                // Accept all button
                if acceptedCount < principles.count {
                    Button(action: onAcceptAll) {
                        Text("Accept All")
                            .font(OnLifeFont.label())
                            .foregroundColor(OnLifeColors.socialTeal)
                    }
                    .padding(.top, Spacing.sm)
                }

                // Progress indicator
                HStack(spacing: Spacing.xs) {
                    Text("\(acceptedCount)")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.socialTeal)

                    Text("of \(principles.count) principles accepted")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding(.top, Spacing.sm)

                Spacer()
                    .frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
            }
        }
    }
}

// MARK: - Supporting Components

private struct FeaturePoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(OnLifeColors.socialTeal)
                .frame(width: 24)

            Text(text)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)

            Spacer()
        }
    }
}

private struct ComparisonModeCard: View {
    let title: String
    let emoji: String
    let example: String
    let bullets: [String]
    let accentColor: Color

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(title)
                .font(OnLifeFont.label())
                .foregroundColor(accentColor)

            Text(emoji)
                .font(.system(size: 28))

            Text(example)
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(bullets, id: \.self) { bullet in
                    Text("• \(bullet)")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

private struct PrincipleCheckbox: View {
    let principle: SocialCommitmentPrinciple
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.md) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            principle.isAccepted ? OnLifeColors.socialTeal : OnLifeColors.textMuted,
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if principle.isAccepted {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(OnLifeColors.socialTeal)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(OnLifeColors.textPrimary)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: principle.isAccepted)

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(principle.title)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(principle.description)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                Spacer()
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(principle.isAccepted ? OnLifeColors.socialTeal.opacity(0.1) : OnLifeColors.cardBackground)
            )
        }
        .buttonStyle(PressableCardStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct SocialOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        SocialOnboardingView()
            .preferredColorScheme(.dark)
    }
}
#endif
