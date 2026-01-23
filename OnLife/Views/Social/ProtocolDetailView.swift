import SwiftUI

// MARK: - Protocol Detail View

struct ProtocolDetailView: View {
    let flowProtocol: FlowProtocol
    let currentUserProfile: UserProfile?
    let onTryProtocol: () -> Void
    let onFork: () -> Void
    let onSave: () -> Void
    let onPhilosophyTap: (PhilosophyMoment) -> Void
    let onDismiss: () -> Void

    @State private var isSaved = false
    @State private var showingPharmacology = false
    @State private var showingForkSheet = false
    @State private var contentOpacity: Double = 0

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // Header card
                    headerCard

                    // Chronotype match indicator
                    if let userProfile = currentUserProfile {
                        chronotypeMatchCard(userProfile: userProfile)
                    }

                    // Substances section
                    substancesSection

                    // "Why This Works" pharmacology section
                    pharmacologySection

                    // Results section
                    if flowProtocol.trialCount > 0 {
                        resultsSection
                    }

                    // Attribution (if forked)
                    if flowProtocol.forkedFromId != nil {
                        attributionCard
                    }

                    // Action buttons
                    actionButtons

                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(Spacing.lg)
            }
            .background(OnLifeColors.deepForest.ignoresSafeArea())
            .navigationTitle("Protocol Details")
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
                    HStack(spacing: Spacing.md) {
                        // Save button
                        Button(action: {
                            isSaved.toggle()
                            onSave()
                            HapticManager.shared.impact(style: .light)
                        }) {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 16))
                                .foregroundColor(isSaved ? OnLifeColors.amber : OnLifeColors.textSecondary)
                        }

                        // Share button
                        ShareLink(item: "Check out this flow protocol: \(flowProtocol.name)") {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                                .foregroundColor(OnLifeColors.textSecondary)
                        }
                    }
                }
            }
            .opacity(contentOpacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    contentOpacity = 1
                }
            }
        }
        .sheet(isPresented: $showingForkSheet) {
            CreateProtocolView(
                forkingFrom: flowProtocol,
                userProfile: currentUserProfile,
                onSave: { _ in
                    showingForkSheet = false
                    onFork()
                },
                onCancel: { showingForkSheet = false }
            )
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Title and badges
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(flowProtocol.name)
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    HStack(spacing: Spacing.sm) {
                        Text("by")
                            .foregroundColor(OnLifeColors.textTertiary)

                        Text(flowProtocol.creatorName)
                            .foregroundColor(OnLifeColors.socialTeal)

                        if flowProtocol.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(OnLifeColors.socialTeal)
                        }
                    }
                    .font(OnLifeFont.body())
                }

                Spacer()

                // Stats
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.triangle.branch")
                        Text("\(flowProtocol.forkCount)")
                    }
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "bookmark")
                        Text("\(flowProtocol.saveCount)")
                    }
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            // Description
            if let description = flowProtocol.description {
                Text(description)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .lineSpacing(4)
            }

            // Tags
            HStack(spacing: Spacing.sm) {
                if let chronotype = flowProtocol.targetChronotype {
                    tagPill(chronotype.icon, chronotype.rawValue, chronotypeColor(chronotype))
                }

                if let timeOfDay = flowProtocol.optimalTimeOfDay {
                    tagPill("clock", timeOfDay, OnLifeColors.textTertiary)
                }

                tagPill("timer", "\(flowProtocol.recommendedDurationMinutes)m", OnLifeColors.textTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func tagPill(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10))

            Text(text)
                .font(OnLifeFont.caption())
        }
        .foregroundColor(color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }

    private func chronotypeColor(_ chronotype: Chronotype) -> Color {
        switch chronotype {
        case .earlyBird: return OnLifeColors.amber
        case .nightOwl: return Color(hex: "7B68EE")
        case .flexible: return OnLifeColors.sage
        }
    }

    // MARK: - Chronotype Match Card

    private func chronotypeMatchCard(userProfile: UserProfile) -> some View {
        let isMatch = flowProtocol.targetChronotype == nil ||
                      flowProtocol.targetChronotype == userProfile.chronotype

        return HStack(spacing: Spacing.md) {
            Image(systemName: isMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(isMatch ? OnLifeColors.healthy : OnLifeColors.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(isMatch ? "Great match for your profile!" : "Different chronotype")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(isMatch
                     ? "This protocol is optimized for \(userProfile.chronotype.rawValue)s like you"
                     : "You're a \(userProfile.chronotype.rawValue), this is for \(flowProtocol.targetChronotype?.rawValue ?? "all")s. Consider adjusting timing.")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()

            PhilosophyButton {
                onPhilosophyTap(PhilosophyMomentsLibrary.peakWindows)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill((isMatch ? OnLifeColors.healthy : OnLifeColors.warning).opacity(0.1))
        )
    }

    // MARK: - Substances Section

    private var substancesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Substances & Timing")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                PhilosophyButton {
                    onPhilosophyTap(PhilosophyMomentsLibrary.substanceOptimization)
                }
            }

            ProtocolSubstancesList(
                substances: flowProtocol.substances,
                showTiming: true
            )

            // Timing visualization
            substanceTimingVisualization
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private var substanceTimingVisualization: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Timeline")
                .font(OnLifeFont.label())
                .foregroundColor(OnLifeColors.textTertiary)

            // Timeline bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.cardBackgroundElevated)
                        .frame(height: 8)

                    // Work session indicator
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.socialTeal.opacity(0.3))
                        .frame(width: geometry.size.width * 0.6, height: 8)
                        .offset(x: geometry.size.width * 0.3)

                    // Substance markers
                    ForEach(flowProtocol.substances) { substance in
                        if let minutes = substance.minutesBefore {
                            Circle()
                                .fill(OnLifeColors.amber)
                                .frame(width: 12, height: 12)
                                .offset(x: calculateMarkerPosition(minutes: minutes, width: geometry.size.width))
                        }
                    }

                    // Session start marker
                    Rectangle()
                        .fill(OnLifeColors.socialTeal)
                        .frame(width: 2, height: 16)
                        .offset(x: geometry.size.width * 0.3, y: -4)
                }
            }
            .frame(height: 16)

            // Labels
            HStack {
                Text("Substances")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.amber)

                Spacer()

                Text("Session Start")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.socialTeal)

                Spacer()

                Text("Session End")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textMuted)
            }
        }
        .padding(.top, Spacing.sm)
    }

    private func calculateMarkerPosition(minutes: Int, width: CGFloat) -> CGFloat {
        // Assume 60 minutes is the max pre-work time
        let maxPrework: CGFloat = 60
        let sessionStart = width * 0.3
        let offset = CGFloat(minutes) / maxPrework * sessionStart
        return sessionStart - offset - 6 // -6 for centering the circle
    }

    // MARK: - Pharmacology Section

    private var pharmacologySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(OnLifeColors.amber)

                    Text("Why This Works")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)
                }

                Spacer()

                Button(action: { withAnimation { showingPharmacology.toggle() } }) {
                    Image(systemName: showingPharmacology ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            if showingPharmacology {
                pharmacologyContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Preview text
                Text("Tap to learn the pharmacokinetics behind this protocol...")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .italic()
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

    private var pharmacologyContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(flowProtocol.substances) { substance in
                pharmacologyItem(for: substance)
            }

            // Synergy explanation
            if flowProtocol.substances.count > 1 {
                synergyExplanation
            }

            // Learn more link
            Button(action: {
                onPhilosophyTap(PhilosophyMomentsLibrary.substanceOptimization)
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(OnLifeColors.amber)

                    Text("Learn more about substance optimization")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }
        }
    }

    private func pharmacologyItem(for substance: SubstanceEntry) -> some View {
        let explanation = getPharmacologyExplanation(for: substance.substance)

        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(OnLifeColors.socialTeal)
                    .frame(width: 6, height: 6)

                Text(substance.substance)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            Text(explanation)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
                .padding(.leading, Spacing.md + 6)
        }
    }

    private func getPharmacologyExplanation(for substance: String) -> String {
        let lowercased = substance.lowercased()

        if lowercased.contains("caffeine") {
            return "Blocks adenosine receptors, increasing alertness. Peak effect at 30-60 minutes, half-life of 5-6 hours. Best taken 30 minutes before focus work."
        } else if lowercased.contains("theanine") {
            return "Promotes alpha brain waves associated with calm focus. Smooths caffeine's stimulant curve and reduces jitters. 2:1 ratio with caffeine is commonly used."
        } else if lowercased.contains("nicotine") {
            return "Acetylcholine agonist that enhances attention and working memory. Effects peak in 10-15 minutes. Low doses (1-2mg) provide cognitive benefits without addiction risk."
        } else if lowercased.contains("creatine") {
            return "Supports ATP regeneration in brain cells. Improves cognitive performance especially under stress or sleep deprivation. Effects are cumulative over weeks."
        } else {
            return "Consult research for specific pharmacokinetics of this substance."
        }
    }

    private var synergyExplanation: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.triangle.merge")
                    .foregroundColor(OnLifeColors.healthy)

                Text("Synergy Effect")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            Text("These substances work together. The combination creates effects greater than each individually, while timing them properly ensures peak concentrations align with your focus window.")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
                .padding(.leading, Spacing.md + 6)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.healthy.opacity(0.1))
        )
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Community Results")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                Text("\(flowProtocol.trialCount) trials")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            // Results stats
            HStack(spacing: Spacing.lg) {
                resultStat(
                    value: "\(Int((flowProtocol.averageFlowScore ?? 0) * 100))%",
                    label: "Avg Flow Score",
                    icon: "sparkles",
                    color: OnLifeColors.socialTeal
                )

                resultStat(
                    value: "\(Int((flowProtocol.averageRating ?? 0) * 5))/5",
                    label: "User Rating",
                    icon: "star.fill",
                    color: OnLifeColors.amber
                )
            }

            // Rating distribution visualization (placeholder)
            ratingDistribution
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func resultStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16))

                Text(value)
                    .font(OnLifeFont.heading2())
            }
            .foregroundColor(color)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var ratingDistribution: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Effectiveness by Experience Level")
                .font(OnLifeFont.label())
                .foregroundColor(OnLifeColors.textTertiary)

            HStack(spacing: Spacing.sm) {
                distributionBar(label: "Beginner", value: 0.72, color: OnLifeColors.healthy)
                distributionBar(label: "Intermediate", value: 0.81, color: OnLifeColors.socialTeal)
                distributionBar(label: "Advanced", value: 0.76, color: OnLifeColors.amber)
            }
        }
    }

    private func distributionBar(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Text("\(Int(value * 100))%")
                .font(OnLifeFont.labelSmall())
                .foregroundColor(color)

            GeometryReader { geometry in
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: geometry.size.height * value)
                }
            }
            .frame(height: 60)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Attribution Card

    private var attributionCard: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 16))
                .foregroundColor(OnLifeColors.socialTeal)

            VStack(alignment: .leading, spacing: 2) {
                Text("Forked from")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)

                if let originalName = flowProtocol.forkedFromName {
                    Text(originalName)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.socialTeal)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.md) {
            // Try Protocol (primary)
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                onTryProtocol()
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))

                    Text("Try This Protocol")
                        .font(OnLifeFont.button())
                }
                .foregroundColor(OnLifeColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(OnLifeColors.socialTeal)
                )
            }

            // Fork Protocol (secondary)
            Button(action: {
                showingForkSheet = true
                HapticManager.shared.impact(style: .light)
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 14))

                    Text("Fork & Customize")
                        .font(OnLifeFont.button())
                }
                .foregroundColor(OnLifeColors.socialTeal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(OnLifeColors.socialTeal, lineWidth: 2)
                )
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProtocolDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ProtocolDetailView(
            flowProtocol: FlowProtocol(
                id: "1",
                name: "Morning Clarity Stack",
                creatorId: "user1",
                creatorName: "Sarah Chen",
                description: "Optimized caffeine + L-theanine stack for morning deep work sessions. The 2:1 theanine to caffeine ratio smooths out the energy curve and eliminates the crash.",
                substances: [
                    SubstanceEntry(substance: "Caffeine", dosage: "100mg", timing: .prework, minutesBefore: 30),
                    SubstanceEntry(substance: "L-Theanine", dosage: "200mg", timing: .prework, minutesBefore: 30)
                ],
                activities: [.coding, .writing],
                targetChronotype: .earlyBird,
                optimalTimeOfDay: "6-10 AM",
                recommendedDurationMinutes: 90,
                averageFlowScore: 0.78,
                averageRating: 0.85,
                trialCount: 156,
                forkCount: 23,
                saveCount: 89,
                isVerified: true,
                isPublic: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            currentUserProfile: UserProfile(
                id: "me",
                username: "testuser",
                chronotype: .earlyBird,
                thirtyDayTrajectory: 15,
                consistencyPercentile: 70,
                totalPlantsGrown: 20,
                speciesUnlocked: 5,
                gardenAgeDays: 45
            ),
            onTryProtocol: {},
            onFork: {},
            onSave: {},
            onPhilosophyTap: { _ in },
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
