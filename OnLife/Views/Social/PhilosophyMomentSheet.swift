import SwiftUI

// MARK: - Philosophy Moment Sheet

struct PhilosophyMomentSheet: View {
    let moment: PhilosophyMoment
    @Environment(\.dismiss) private var dismiss
    @State private var contentOpacity: Double = 0
    @State private var cardOffset: CGFloat = 50

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Content card
            VStack(spacing: 0) {
                Spacer()

                contentCard
                    .opacity(contentOpacity)
                    .offset(y: cardOffset)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                contentOpacity = 1
                cardOffset = 0
            }
        }
    }

    private var contentCard: some View {
        VStack(spacing: Spacing.lg) {
            // Handle
            Capsule()
                .fill(OnLifeColors.textMuted)
                .frame(width: 36, height: 4)
                .padding(.top, Spacing.md)

            // Icon and category
            HStack(spacing: Spacing.sm) {
                Image(systemName: moment.icon)
                    .font(.system(size: 20))
                    .foregroundColor(OnLifeColors.amber)

                Text(moment.category.rawValue)
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }
            .padding(.horizontal, Spacing.lg)

            // Title
            Text(moment.title)
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            // Scrollable body
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // Body text
                    Text(moment.body)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)

                    // Citation (if exists)
                    if let citation = moment.formattedCitation {
                        HStack {
                            Spacer()
                            Text(citation)
                                .font(OnLifeFont.bodySmall())
                                .foregroundColor(OnLifeColors.textTertiary)
                                .italic()
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .frame(maxHeight: 300)

            // Action button
            VStack(spacing: Spacing.md) {
                Button(action: { dismiss() }) {
                    Text(moment.actionText)
                        .font(OnLifeFont.button())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                .fill(OnLifeColors.amber)
                        )
                }

                // Learn more link (if exists)
                if let url = moment.learnMoreURL {
                    Link(destination: url) {
                        HStack(spacing: Spacing.xs) {
                            Text("Learn more")
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                        }
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.socialTeal)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.modal, style: .continuous)
                .fill(OnLifeColors.cardBackground)
                .ignoresSafeArea(edges: .bottom)
        )
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    }
                }
        )
    }
}

// MARK: - Philosophy Moment Card (Inline version)

struct PhilosophyMomentCard: View {
    let moment: PhilosophyMoment
    var onDismiss: (() -> Void)?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(OnLifeColors.amber)

                Text(moment.title)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                }
            }

            // Body (truncated or full)
            Text(moment.body)
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textSecondary)
                .lineLimit(isExpanded ? nil : 3)
                .lineSpacing(2)

            // Expand/collapse or citation
            HStack {
                if !isExpanded {
                    Button(action: { withAnimation { isExpanded = true } }) {
                        Text("Read more")
                            .font(OnLifeFont.label())
                            .foregroundColor(OnLifeColors.socialTeal)
                    }
                } else if let citation = moment.formattedCitation {
                    Text(citation)
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                        .italic()
                }

                Spacer()
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .stroke(OnLifeColors.amber.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Philosophy Moment Inline Hint

struct PhilosophyHint: View {
    let moment: PhilosophyMoment
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundColor(OnLifeColors.amber)

                Text(moment.title)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(OnLifeColors.amber.opacity(0.1))
            )
        }
    }
}

// MARK: - Philosophy Moments Discovery View

struct PhilosophyMomentsDiscoveryView: View {
    @State private var selectedMoment: PhilosophyMoment?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                // Header
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 40))
                        .foregroundColor(OnLifeColors.amber)

                    Text("Philosophy Moments")
                        .font(OnLifeFont.heading1())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("The science behind OnLife")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
                .padding(.top, Spacing.xl)

                // Categories
                ForEach(PhilosophyMomentCategory.allCases, id: \.self) { category in
                    categorySection(category)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(OnLifeColors.deepForest.ignoresSafeArea())
        .sheet(item: $selectedMoment) { moment in
            PhilosophyMomentSheet(moment: moment)
        }
    }

    private func categorySection(_ category: PhilosophyMomentCategory) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Category header
            HStack(spacing: Spacing.sm) {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(OnLifeColors.amber)

                Text(category.rawValue)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            // Moments in category
            ForEach(PhilosophyMomentsLibrary.moments(in: category)) { moment in
                momentRow(moment)
            }
        }
    }

    private func momentRow(_ moment: PhilosophyMoment) -> some View {
        Button(action: { selectedMoment = moment }) {
            HStack(spacing: Spacing.md) {
                Image(systemName: moment.icon)
                    .font(.system(size: 20))
                    .foregroundColor(OnLifeColors.amber)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(moment.title)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .multilineTextAlignment(.leading)

                    if let citation = moment.citation {
                        Text(citation)
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(OnLifeColors.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
        }
        .buttonStyle(PressableCardStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct PhilosophyMomentSheet_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Sheet preview
            PhilosophyMomentSheet(
                moment: PhilosophyMomentsLibrary.trajectoriesMatterMore
            )

            // Card preview
            PhilosophyMomentCard(
                moment: PhilosophyMomentsLibrary.socialLearning,
                onDismiss: {}
            )
            .padding()
            .background(OnLifeColors.deepForest)

            // Discovery view preview
            PhilosophyMomentsDiscoveryView()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
