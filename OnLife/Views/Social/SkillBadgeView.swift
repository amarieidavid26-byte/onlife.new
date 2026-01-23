import SwiftUI

// MARK: - Skill Badge View

struct SkillBadgeView: View {
    let badge: SkillBadge
    let onPhilosophyTap: ((PhilosophyMoment) -> Void)?

    @State private var isPressed = false
    @State private var showingDetail = false

    init(badge: SkillBadge, onPhilosophyTap: ((PhilosophyMoment) -> Void)? = nil) {
        self.badge = badge
        self.onPhilosophyTap = onPhilosophyTap
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(spacing: Spacing.sm) {
                // Badge icon
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: badge.icon)
                        .font(.system(size: 22))
                        .foregroundColor(categoryColor)
                }

                // Badge name
                Text(badge.name)
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Badge description
                Text(badge.description)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(OnLifeColors.cardBackgroundElevated)
            )
        }
        .buttonStyle(PressableCardStyle())
        .sheet(isPresented: $showingDetail) {
            SkillBadgeDetailSheet(
                badge: badge,
                onPhilosophyTap: onPhilosophyTap
            )
        }
    }

    private var categoryColor: Color {
        switch badge.category {
        case .initiation:
            return OnLifeColors.socialTeal
        case .depth:
            return Color(hex: "7B68EE") // Purple
        case .consistency:
            return OnLifeColors.amber
        case .optimization:
            return OnLifeColors.healthy
        case .mastery:
            return Color(hex: "FFD700") // Gold
        }
    }
}

// MARK: - Skill Badge Detail Sheet

struct SkillBadgeDetailSheet: View {
    let badge: SkillBadge
    let onPhilosophyTap: ((PhilosophyMoment) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Handle
            Capsule()
                .fill(OnLifeColors.textMuted)
                .frame(width: 36, height: 4)
                .padding(.top, Spacing.md)

            // Badge icon (large)
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 100, height: 100)

                Circle()
                    .stroke(categoryColor, lineWidth: 3)
                    .frame(width: 100, height: 100)

                Image(systemName: badge.icon)
                    .font(.system(size: 44))
                    .foregroundColor(categoryColor)
            }

            // Badge info
            VStack(spacing: Spacing.sm) {
                Text(badge.name)
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(badge.category.rawValue)
                    .font(OnLifeFont.label())
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule()
                            .fill(categoryColor.opacity(0.15))
                    )

                Text(badge.description)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            // Earned date
            HStack(spacing: Spacing.xs) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))

                Text("Earned \(badge.earnedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(OnLifeFont.bodySmall())
            }
            .foregroundColor(OnLifeColors.textTertiary)

            // Philosophy moment button
            if let onPhilosophyTap = onPhilosophyTap {
                Button(action: {
                    dismiss()
                    onPhilosophyTap(PhilosophyMomentsLibrary.skillsNotHours)
                }) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(OnLifeColors.amber)

                        Text("Why skills matter more than hours")
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.amber.opacity(0.1))
                    )
                }
            }

            Spacer()

            // Done button
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(OnLifeFont.button())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.socialTeal)
                    )
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .background(OnLifeColors.cardBackground.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private var categoryColor: Color {
        switch badge.category {
        case .initiation:
            return OnLifeColors.socialTeal
        case .depth:
            return Color(hex: "7B68EE")
        case .consistency:
            return OnLifeColors.amber
        case .optimization:
            return OnLifeColors.healthy
        case .mastery:
            return Color(hex: "FFD700")
        }
    }
}

// MARK: - Skill Badge Compact

struct SkillBadgeCompact: View {
    let badge: SkillBadge

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: badge.icon)
                .font(.system(size: 14))
                .foregroundColor(categoryColor)

            Text(badge.name)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(categoryColor.opacity(0.15))
        )
    }

    private var categoryColor: Color {
        switch badge.category {
        case .initiation: return OnLifeColors.socialTeal
        case .depth: return Color(hex: "7B68EE")
        case .consistency: return OnLifeColors.amber
        case .optimization: return OnLifeColors.healthy
        case .mastery: return Color(hex: "FFD700")
        }
    }
}

// MARK: - Badge Progress View

struct BadgeProgressView: View {
    let badge: SkillBadge.BadgeCategory
    let progress: Double // 0.0 to 1.0
    let title: String
    let requirement: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: badge.icon)
                    .font(.system(size: 16))
                    .foregroundColor(categoryColor)

                Text(title)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(OnLifeFont.label())
                    .foregroundColor(categoryColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.cardBackgroundElevated)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [categoryColor.opacity(0.7), categoryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)

            Text(requirement)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private var categoryColor: Color {
        switch badge {
        case .initiation: return OnLifeColors.socialTeal
        case .depth: return Color(hex: "7B68EE")
        case .consistency: return OnLifeColors.amber
        case .optimization: return OnLifeColors.healthy
        case .mastery: return Color(hex: "FFD700")
        }
    }
}

// MARK: - Badges Grid View

struct BadgesGridView: View {
    let badges: [SkillBadge]
    let onPhilosophyTap: (PhilosophyMoment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                Text("Skills Earned")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                PhilosophyButton {
                    onPhilosophyTap(PhilosophyMomentsLibrary.skillsNotHours)
                }

                Spacer()

                Text("\(badges.count) badges")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            if badges.isEmpty {
                // Empty state
                VStack(spacing: Spacing.md) {
                    Image(systemName: "star.circle")
                        .font(.system(size: 40))
                        .foregroundColor(OnLifeColors.textMuted)

                    Text("No badges earned yet")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textTertiary)

                    Text("Complete flow sessions to unlock skills")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.xl)
            } else {
                // Badges grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: Spacing.md) {
                    ForEach(badges) { badge in
                        SkillBadgeView(badge: badge, onPhilosophyTap: onPhilosophyTap)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct SkillBadgeView_Previews: PreviewProvider {
    static let sampleBadges = [
        SkillBadge(
            id: "1",
            name: "Flow Initiation",
            description: "Can enter flow within 5 minutes",
            icon: "bolt.fill",
            earnedDate: Date(),
            category: .initiation
        ),
        SkillBadge(
            id: "2",
            name: "Extended Flow",
            description: "Maintained 2hr+ sessions",
            icon: "clock.fill",
            earnedDate: Date(),
            category: .depth
        ),
        SkillBadge(
            id: "3",
            name: "Protocol Scientist",
            description: "Optimized personal substance timing",
            icon: "flask.fill",
            earnedDate: Date(),
            category: .optimization
        ),
        SkillBadge(
            id: "4",
            name: "Flow Master",
            description: "Achieved 90%+ flow score 10 times",
            icon: "star.fill",
            earnedDate: Date(),
            category: .mastery
        )
    ]

    static var previews: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Grid view
                BadgesGridView(
                    badges: sampleBadges,
                    onPhilosophyTap: { _ in }
                )

                // Individual badge
                SkillBadgeView(
                    badge: sampleBadges[0],
                    onPhilosophyTap: { _ in }
                )

                // Compact badges
                HStack {
                    ForEach(sampleBadges.prefix(3)) { badge in
                        SkillBadgeCompact(badge: badge)
                    }
                }

                // Progress view
                BadgeProgressView(
                    badge: .consistency,
                    progress: 0.65,
                    title: "Streak Master",
                    requirement: "Maintain a 30-day streak"
                )
            }
            .padding()
        }
        .background(OnLifeColors.deepForest)
        .preferredColorScheme(.dark)
    }
}
#endif
