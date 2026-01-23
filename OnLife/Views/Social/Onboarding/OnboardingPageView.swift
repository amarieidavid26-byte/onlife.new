import SwiftUI

// MARK: - Onboarding Page Configuration

struct OnboardingPageConfig {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let bodyContent: OnboardingBodyContent
    let citation: OnboardingCitation?
    let buttonTitle: String

    struct OnboardingCitation {
        let quote: String
        let source: String
    }

    enum OnboardingBodyContent {
        case text(String)
        case bullets([BulletPoint])
        case comparison(toxic: ComparisonBox, healthy: ComparisonBox)
        case custom(AnyView)

        struct BulletPoint: Identifiable {
            let id = UUID()
            let icon: String
            let text: String
        }

        struct ComparisonBox {
            let title: String
            let emoji: String
            let example: String
            let points: [String]
            let color: Color
        }
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let config: OnboardingPageConfig
    let onContinue: () -> Void

    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    Spacer()
                        .frame(height: Spacing.xl)

                    // Icon/Illustration
                    illustrationSection
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)

                    // Title Section
                    titleSection
                        .opacity(contentOpacity)
                        .offset(y: contentOffset)

                    // Citation (if exists)
                    if let citation = config.citation {
                        citationCard(citation)
                            .opacity(contentOpacity)
                            .offset(y: contentOffset)
                    }

                    // Body Content
                    bodySection
                        .opacity(contentOpacity)
                        .offset(y: contentOffset)

                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.lg)
            }

            // Bottom button (fixed)
            continueButton
                .opacity(contentOpacity)
        }
        .onAppear {
            animateIn()
        }
    }

    // MARK: - Illustration Section

    private var illustrationSection: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(config.iconColor.opacity(0.1))
                .frame(width: 160, height: 160)

            // Inner circle
            Circle()
                .fill(config.iconColor.opacity(0.2))
                .frame(width: 120, height: 120)

            // Icon
            Image(systemName: config.icon)
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [config.iconColor, config.iconColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: Spacing.sm) {
            Text(config.title)
                .font(OnLifeFont.heading1())
                .foregroundColor(OnLifeColors.textPrimary)
                .multilineTextAlignment(.center)

            if let subtitle = config.subtitle {
                Text(subtitle)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.socialTeal)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Citation Card

    private func citationCard(_ citation: OnboardingPageConfig.OnboardingCitation) -> some View {
        VStack(spacing: Spacing.md) {
            Text("\"\(citation.quote)\"")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)
                .italic()
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("— \(citation.source)")
                .font(OnLifeFont.labelSmall())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .stroke(OnLifeColors.socialTeal.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Body Section

    @ViewBuilder
    private var bodySection: some View {
        switch config.bodyContent {
        case .text(let text):
            Text(text)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, Spacing.md)

        case .bullets(let bullets):
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(bullets) { bullet in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        Image(systemName: bullet.icon)
                            .font(.system(size: 16))
                            .foregroundColor(OnLifeColors.socialTeal)
                            .frame(width: 24)

                        Text(bullet.text)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textSecondary)

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, Spacing.md)

        case .comparison(let toxic, let healthy):
            HStack(spacing: Spacing.md) {
                comparisonBox(toxic)
                comparisonBox(healthy)
            }

        case .custom(let view):
            view
        }
    }

    // MARK: - Comparison Box

    private func comparisonBox(_ box: OnboardingPageConfig.OnboardingBodyContent.ComparisonBox) -> some View {
        VStack(spacing: Spacing.sm) {
            Text(box.title)
                .font(OnLifeFont.label())
                .foregroundColor(box.color)

            Text(box.emoji)
                .font(.system(size: 32))

            Text(box.example)
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(box.points, id: \.self) { point in
                    Text("• \(point)")
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
                        .stroke(box.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onContinue()
        }) {
            HStack(spacing: Spacing.sm) {
                Text(config.buttonTitle)
                    .font(OnLifeFont.button())

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(OnLifeColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(OnLifeColors.socialTeal)
            )
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xxxl)
    }

    // MARK: - Animation

    private func animateIn() {
        withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            contentOpacity = 1.0
            contentOffset = 0
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingPageView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingPageView(
            config: OnboardingPageConfig(
                icon: "brain.head.profile",
                iconColor: OnLifeColors.socialTeal,
                title: "OnLife Social Is Different",
                subtitle: "A different kind of social",
                bodyContent: .bullets([
                    .init(icon: "chart.line.uptrend.xyaxis", text: "We show trajectories, not just scores"),
                    .init(icon: "lightbulb", text: "We explain the psychology behind every feature"),
                    .init(icon: "arrow.triangle.2.circlepath", text: "We help your friends help you"),
                    .init(icon: "graduationcap", text: "We designed for graduation, not addiction")
                ]),
                citation: nil,
                buttonTitle: "Show Me the Science"
            ),
            onContinue: {}
        )
        .background(OnLifeColors.deepForest.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
#endif
