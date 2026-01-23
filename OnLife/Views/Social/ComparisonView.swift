import SwiftUI

// MARK: - Comparison View

struct ComparisonView: View {
    let yourProfile: UserProfile
    let theirProfile: UserProfile
    let onPhilosophyTap: (PhilosophyMoment) -> Void
    let onProtocolTap: (String) -> Void
    let onDismiss: () -> Void

    @State private var comparisonMode: ComparisonMode = .inspiration
    @State private var showingFullChart = false
    @State private var contentOpacity: Double = 0
    @State private var cardsOffset: CGFloat = 30

    // Sample historical data for chart
    private var yourHistoricalData: [Double] {
        // Generate sample trajectory history based on current value
        let base = yourProfile.thirtyDayTrajectory
        return (0..<7).map { i in
            base * Double(i + 1) / 7.0 + Double.random(in: -3...3)
        }
    }

    private var theirHistoricalData: [Double] {
        let base = theirProfile.thirtyDayTrajectory
        return (0..<7).map { i in
            base * Double(i + 1) / 7.0 + Double.random(in: -3...3)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // Context banner (always visible)
                    contextBanner
                        .opacity(contentOpacity)

                    // Mode toggle
                    ComparisonModeToggle(
                        mode: $comparisonMode,
                        onPhilosophyTap: {
                            onPhilosophyTap(PhilosophyMomentsLibrary.healthyComparison)
                        }
                    )
                    .opacity(contentOpacity)

                    // Main comparison content based on mode
                    Group {
                        if comparisonMode == .inspiration {
                            inspirationModeContent
                        } else {
                            competitionModeContent
                        }
                    }
                    .opacity(contentOpacity)
                    .offset(y: cardsOffset)

                    // Insights section (both modes)
                    insightsSection
                        .opacity(contentOpacity)
                        .offset(y: cardsOffset)

                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }
            .background(OnLifeColors.deepForest.ignoresSafeArea())
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    PhilosophyButton {
                        onPhilosophyTap(PhilosophyMomentsLibrary.trajectoriesMatterMore)
                    }
                }
            }
        }
        .onAppear {
            animateIn()
        }
    }

    // MARK: - Context Banner

    private var contextBanner: some View {
        let experienceDiff = theirProfile.gardenAgeDays - yourProfile.gardenAgeDays
        let contextText: String
        let contextIcon: String

        if abs(experienceDiff) < 14 {
            contextText = "Similar experience levels (\(yourProfile.gardenAgeDays) vs \(theirProfile.gardenAgeDays) days)"
            contextIcon = "equal.circle"
        } else if experienceDiff > 0 {
            let months = experienceDiff / 30
            if months > 0 {
                contextText = "They've trained \(months) month\(months == 1 ? "" : "s") longer"
            } else {
                contextText = "They've trained \(experienceDiff) days longer"
            }
            contextIcon = "clock"
        } else {
            let months = abs(experienceDiff) / 30
            if months > 0 {
                contextText = "You've trained \(months) month\(months == 1 ? "" : "s") longer"
            } else {
                contextText = "You've trained \(abs(experienceDiff)) days longer"
            }
            contextIcon = "clock"
        }

        return ComparisonContextBanner(context: contextText, icon: contextIcon)
    }

    // MARK: - Inspiration Mode Content

    private var inspirationModeContent: some View {
        VStack(spacing: Spacing.lg) {
            // Learning velocity comparison
            TrajectoryComparisonBar(
                yourTrajectory: yourProfile.thirtyDayTrajectory,
                theirTrajectory: theirProfile.thirtyDayTrajectory,
                yourName: "You",
                theirName: theirProfile.displayName ?? theirProfile.username,
                animated: true
            )

            // Their strategies section
            theirStrategiesCard

            // Chronotype comparison
            chronotypeComparisonCard
        }
    }

    // MARK: - Competition Mode Content

    private var competitionModeContent: some View {
        VStack(spacing: Spacing.lg) {
            // Learning velocity (larger in competition mode)
            TrajectoryComparisonBar(
                yourTrajectory: yourProfile.thirtyDayTrajectory,
                theirTrajectory: theirProfile.thirtyDayTrajectory,
                yourName: "You",
                theirName: theirProfile.displayName ?? theirProfile.username,
                animated: true
            )

            // Trajectory chart over time
            if showingFullChart {
                DualTrajectoryChart(
                    yourData: yourHistoricalData,
                    theirData: theirHistoricalData,
                    yourName: "You",
                    theirName: theirProfile.displayName ?? theirProfile.username
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Show/hide chart button
            Button(action: {
                withAnimation(.spring(duration: 0.4)) {
                    showingFullChart.toggle()
                }
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: showingFullChart ? "chart.line.downtrend.xyaxis" : "chart.line.uptrend.xyaxis")
                    Text(showingFullChart ? "Hide Chart" : "View Trajectory Chart")
                }
                .font(OnLifeFont.label())
                .foregroundColor(OnLifeColors.socialTeal)
            }

            // Head-to-head stats
            headToHeadCard
        }
    }

    // MARK: - Their Strategies Card

    private var theirStrategiesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Their Strategies")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                PhilosophyButton {
                    onPhilosophyTap(PhilosophyMomentsLibrary.socialLearning)
                }

                Spacer()
            }

            // Chronotype strategy
            strategyRow(
                icon: theirProfile.chronotype.icon,
                title: theirProfile.chronotype.rawValue,
                subtitle: "Prefers \(theirProfile.chronotype == .earlyBird ? "morning" : theirProfile.chronotype == .nightOwl ? "evening" : "flexible") sessions"
            )

            // Session duration (mock data - would come from their protocols)
            strategyRow(
                icon: "clock",
                title: "90-minute blocks",
                subtitle: "Matches ultradian rhythm"
            )

            // Consistency pattern
            strategyRow(
                icon: "calendar",
                title: "5 sessions/week",
                subtitle: "Top \(100 - theirProfile.consistencyPercentile)% consistency"
            )

            // View protocols button
            Button(action: {
                // Navigate to their protocols
            }) {
                HStack {
                    Text("View their public protocols")
                        .font(OnLifeFont.label())

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                }
                .foregroundColor(OnLifeColors.socialTeal)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func strategyRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(OnLifeColors.amber)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(subtitle)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - Chronotype Comparison Card

    private var chronotypeComparisonCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Peak Windows")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                PhilosophyButton {
                    onPhilosophyTap(PhilosophyMomentsLibrary.peakWindows)
                }

                Spacer()
            }

            HStack(spacing: Spacing.lg) {
                // Your peak
                peakWindowPill(
                    label: "You",
                    chronotype: yourProfile.chronotype,
                    windows: yourProfile.peakFlowWindows,
                    color: OnLifeColors.socialTeal
                )

                // Their peak
                peakWindowPill(
                    label: theirProfile.displayName ?? "Them",
                    chronotype: theirProfile.chronotype,
                    windows: theirProfile.peakFlowWindows,
                    color: OnLifeColors.amber
                )
            }

            // Overlap indicator
            if chronotypesMatch {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(OnLifeColors.healthy)

                    Text("Great match for co-working sessions!")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private var chronotypesMatch: Bool {
        yourProfile.chronotype == theirProfile.chronotype
    }

    private func peakWindowPill(label: String, chronotype: Chronotype, windows: [TimeWindow], color: Color) -> some View {
        VStack(spacing: Spacing.sm) {
            Text(label)
                .font(OnLifeFont.label())
                .foregroundColor(OnLifeColors.textTertiary)

            HStack(spacing: Spacing.sm) {
                Image(systemName: chronotype.icon)
                    .font(.system(size: 16))

                if let window = windows.first {
                    Text(window.displayString)
                        .font(OnLifeFont.bodySmall())
                }
            }
            .foregroundColor(color)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(color.opacity(0.15))
            )
        }
    }

    // MARK: - Head to Head Card

    private var headToHeadCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Head to Head")
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            // Stats comparison
            VStack(spacing: Spacing.sm) {
                statComparisonRow(
                    label: "30-Day Growth",
                    yourValue: "\(yourProfile.thirtyDayTrajectory >= 0 ? "+" : "")\(Int(yourProfile.thirtyDayTrajectory))%",
                    theirValue: "\(theirProfile.thirtyDayTrajectory >= 0 ? "+" : "")\(Int(theirProfile.thirtyDayTrajectory))%",
                    yourWins: yourProfile.thirtyDayTrajectory > theirProfile.thirtyDayTrajectory
                )

                statComparisonRow(
                    label: "Consistency",
                    yourValue: "Top \(100 - yourProfile.consistencyPercentile)%",
                    theirValue: "Top \(100 - theirProfile.consistencyPercentile)%",
                    yourWins: yourProfile.consistencyPercentile > theirProfile.consistencyPercentile
                )

                statComparisonRow(
                    label: "Plants Grown",
                    yourValue: "\(yourProfile.totalPlantsGrown)",
                    theirValue: "\(theirProfile.totalPlantsGrown)",
                    yourWins: yourProfile.totalPlantsGrown > theirProfile.totalPlantsGrown
                )

                statComparisonRow(
                    label: "Species Unlocked",
                    yourValue: "\(yourProfile.speciesUnlocked)",
                    theirValue: "\(theirProfile.speciesUnlocked)",
                    yourWins: yourProfile.speciesUnlocked > theirProfile.speciesUnlocked
                )
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func statComparisonRow(label: String, yourValue: String, theirValue: String, yourWins: Bool) -> some View {
        HStack {
            Text(label)
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textTertiary)

            Spacer()

            // Your value
            Text(yourValue)
                .font(OnLifeFont.body())
                .foregroundColor(yourWins ? OnLifeColors.socialTeal : OnLifeColors.textSecondary)
                .frame(width: 80, alignment: .trailing)

            // Winner indicator
            Image(systemName: yourWins ? "chevron.left" : "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(yourWins ? OnLifeColors.socialTeal : OnLifeColors.amber)
                .frame(width: 20)

            // Their value
            Text(theirValue)
                .font(OnLifeFont.body())
                .foregroundColor(yourWins ? OnLifeColors.textSecondary : OnLifeColors.amber)
                .frame(width: 80, alignment: .leading)
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        ComparisonInsightsStack(
            insights: generateInsights(),
            onActionTap: { destination in
                switch destination {
                case .protocol(let id):
                    onProtocolTap(id)
                case .philosophyMoment(let moment):
                    onPhilosophyTap(moment)
                default:
                    break
                }
            },
            onPhilosophyTap: {
                onPhilosophyTap(PhilosophyMomentsLibrary.healthyComparison)
            }
        )
    }

    // MARK: - Generate Insights

    private func generateInsights() -> [ComparisonInsight] {
        var insights: [ComparisonInsight] = []

        let trajectoryDiff = theirProfile.thirtyDayTrajectory - yourProfile.thirtyDayTrajectory
        let experienceDiff = theirProfile.gardenAgeDays - yourProfile.gardenAgeDays

        // Trajectory insight
        if trajectoryDiff > 10 {
            insights.append(ComparisonInsight(
                type: .learningOpportunity,
                title: "They're improving \(Int(trajectoryDiff))% faster",
                body: "Check their protocols to see what techniques might be driving their faster improvement. Small changes can compound over time.",
                action: .init(
                    label: "View their protocols",
                    destination: .profile(userId: theirProfile.id)
                )
            ))
        } else if trajectoryDiff < -10 {
            insights.append(ComparisonInsight(
                type: .celebration,
                title: "You're improving \(Int(abs(trajectoryDiff)))% faster!",
                body: "Your current strategies are working well. Keep up the momentum and consider sharing what's working with your flow partners.",
                action: nil
            ))
        }

        // Experience context
        if experienceDiff > 60 {
            let months = experienceDiff / 30
            insights.append(ComparisonInsight(
                type: .contextual,
                title: "They have \(months) more months of practice",
                body: "At your current trajectory, you're on track to reach their skill level. Experience matters, but so does deliberate practice.",
                action: .init(
                    label: "Learn about skill development",
                    destination: .philosophyMoment(PhilosophyMomentsLibrary.skillsNotHours)
                )
            ))
        }

        // Consistency insight
        if theirProfile.consistencyPercentile > yourProfile.consistencyPercentile + 20 {
            insights.append(ComparisonInsight(
                type: .actionable,
                title: "Their consistency is exceptional",
                body: "Regular practice is one of the strongest predictors of flow skill development. Even short daily sessions beat sporadic long ones.",
                action: nil
            ))
        }

        // Chronotype match
        if yourProfile.chronotype == theirProfile.chronotype {
            insights.append(ComparisonInsight(
                type: .actionable,
                title: "You share the same chronotype",
                body: "Since you both peak at similar times, consider scheduling co-working flow sessions together for mutual accountability.",
                action: nil
            ))
        }

        return insights
    }

    // MARK: - Animation

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.4)) {
            contentOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            cardsOffset = 0
        }
    }
}

// MARK: - Quick Compare Button

struct QuickCompareButton: View {
    let profile: UserProfile
    let yourTrajectory: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Avatar placeholder
                Circle()
                    .fill(OnLifeColors.socialTeal.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(profile.username.prefix(1)).uppercased())
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.socialTeal)
                    )

                // Name and trajectory
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName ?? profile.username)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    MiniTrajectoryComparison(
                        yourTrajectory: yourTrajectory,
                        theirTrajectory: profile.thirtyDayTrajectory
                    )
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
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
struct ComparisonView_Previews: PreviewProvider {
    static let yourProfile = UserProfile(
        id: "you",
        username: "flowmaster",
        displayName: "You",
        chronotype: .earlyBird,
        peakFlowWindows: [TimeWindow(startHour: 6, endHour: 10)],
        masteryDurationDays: 60,
        gardenAgeDays: 60,
        thirtyDayTrajectory: 23,
        consistencyPercentile: 75,
        totalPlantsGrown: 28,
        speciesUnlocked: 8
    )

    static let theirProfile = UserProfile(
        id: "them",
        username: "sarahflows",
        displayName: "Sarah Chen",
        chronotype: .earlyBird,
        peakFlowWindows: [TimeWindow(startHour: 7, endHour: 11)],
        masteryDurationDays: 180,
        gardenAgeDays: 180,
        thirtyDayTrajectory: 34,
        consistencyPercentile: 92,
        totalPlantsGrown: 85,
        speciesUnlocked: 15
    )

    static var previews: some View {
        Group {
            // Full comparison view
            ComparisonView(
                yourProfile: yourProfile,
                theirProfile: theirProfile,
                onPhilosophyTap: { _ in },
                onProtocolTap: { _ in },
                onDismiss: {}
            )

            // Quick compare button
            QuickCompareButton(
                profile: theirProfile,
                yourTrajectory: 23,
                onTap: {}
            )
            .padding()
            .background(OnLifeColors.deepForest)
        }
        .preferredColorScheme(.dark)
    }
}
#endif
