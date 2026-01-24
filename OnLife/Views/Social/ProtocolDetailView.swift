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

    // Computed property for verified status
    private var isVerified: Bool {
        flowProtocol.ratingsCount >= 10 && flowProtocol.averageRating >= 4.0
    }

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
                    if !flowProtocol.substances.isEmpty {
                        substancesSection
                    }

                    // "Why This Works" pharmacology section
                    pharmacologySection

                    // Results section
                    if flowProtocol.tryCount > 0 {
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
                        ShareLink(item: "Check out this flow protocol: \(flowProtocol.title)") {
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
                    Text(flowProtocol.title)
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    HStack(spacing: Spacing.sm) {
                        Text("by")
                            .foregroundColor(OnLifeColors.textTertiary)

                        Text(flowProtocol.creatorUsername)
                            .foregroundColor(OnLifeColors.socialTeal)

                        if isVerified {
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

                    if flowProtocol.ratingsCount > 0 {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "star.fill")
                            Text(String(format: "%.1f", flowProtocol.averageRating))
                        }
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.amber)
                    }
                }
            }

            // Description
            if !flowProtocol.description.isEmpty {
                Text(flowProtocol.description)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .lineSpacing(4)
            }

            // Tags
            HStack(spacing: Spacing.sm) {
                if let chronotype = flowProtocol.targetChronotype {
                    tagPill(chronotype.sfSymbol, chronotype.shortName, chronotypeColor(chronotype))
                }

                tagPill("timer", flowProtocol.formattedDuration, OnLifeColors.textTertiary)

                if flowProtocol.blocksPerSession > 1 {
                    tagPill("square.stack", "\(flowProtocol.blocksPerSession) blocks", OnLifeColors.textTertiary)
                }
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
        case .extremeMorning, .moderateMorning: return OnLifeColors.amber
        case .moderateEvening, .extremeEvening: return Color(hex: "7B68EE")
        case .intermediate: return OnLifeColors.sage
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
                Text(isMatch ? "Good match for you" : "Different chronotype")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(isMatch
                    ? "This protocol is optimized for your chronotype"
                    : "This protocol is designed for \(flowProtocol.targetChronotype?.shortName ?? "different") chronotypes")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()
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
                Text("Substances")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                PhilosophyButton {
                    onPhilosophyTap(PhilosophyMomentsLibrary.socialLearning)
                }

                Spacer()

                Button(action: { showingPharmacology.toggle() }) {
                    Text(showingPharmacology ? "Hide science" : "Show science")
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.socialTeal)
                }
            }

            // Substances list
            ProtocolSubstancesList(
                substances: flowProtocol.substances,
                showTiming: true
            )
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Pharmacology Section

    private var pharmacologySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16))
                    .foregroundColor(OnLifeColors.socialTeal)

                Text("Why This Works")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                PhilosophyButton {
                    onPhilosophyTap(PhilosophyMomentsLibrary.socialLearning)
                }
            }

            // Generate pharmacology explanation based on substances
            ForEach(flowProtocol.substances) { substance in
                pharmacologyCard(substance)
            }

            // Synergy note (if multiple substances)
            if flowProtocol.substances.count > 1 {
                synergyNote
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func pharmacologyCard(_ substance: SubstanceEntry) -> some View {
        let info = pharmacologyInfo(for: substance.substanceName)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: info.icon)
                    .font(.system(size: 14))
                    .foregroundColor(OnLifeColors.socialTeal)

                Text(substance.substanceName)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                Text(substance.formattedDose)
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Text(info.mechanism)
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textSecondary)

            if !info.timing.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(info.timing)
                        .font(OnLifeFont.caption())
                }
                .foregroundColor(OnLifeColors.textTertiary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackgroundElevated)
        )
    }

    private struct PharmacologyInfo {
        let icon: String
        let mechanism: String
        let timing: String
    }

    private func pharmacologyInfo(for substance: String) -> PharmacologyInfo {
        let lowercased = substance.lowercased()
        if lowercased.contains("caffeine") {
            return PharmacologyInfo(
                icon: "cup.and.saucer.fill",
                mechanism: "Blocks adenosine receptors, increasing alertness and dopamine signaling. Enhances focus and reduces perceived effort.",
                timing: "Peak effects 30-60 minutes after consumption"
            )
        } else if lowercased.contains("theanine") {
            return PharmacologyInfo(
                icon: "leaf.fill",
                mechanism: "Promotes alpha brain waves associated with relaxed focus. Smooths caffeine's effects by reducing jitters and anxiety.",
                timing: "Best taken with caffeine for synergistic effect"
            )
        } else if lowercased.contains("creatine") {
            return PharmacologyInfo(
                icon: "bolt.fill",
                mechanism: "Supports brain ATP production, improving cognitive endurance during demanding tasks.",
                timing: "Consistent daily use recommended for benefits"
            )
        } else {
            return PharmacologyInfo(
                icon: "pills.fill",
                mechanism: "Supports cognitive function through various pathways.",
                timing: ""
            )
        }
    }

    private var synergyNote: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(OnLifeColors.amber)

            Text("These substances work synergistically to enhance focus while reducing side effects.")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.amber.opacity(0.1))
        )
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Results")
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            HStack(spacing: Spacing.lg) {
                // Flow improvement
                if flowProtocol.averageFlowImprovement > 0 {
                    resultStat(
                        value: "+\(Int(flowProtocol.averageFlowImprovement))%",
                        label: "Avg Flow Improvement",
                        icon: "chart.line.uptrend.xyaxis",
                        color: OnLifeColors.healthy
                    )
                }

                // Rating
                if flowProtocol.ratingsCount > 0 {
                    resultStat(
                        value: String(format: "%.1f", flowProtocol.averageRating),
                        label: "Avg Rating",
                        icon: "star.fill",
                        color: OnLifeColors.amber
                    )
                }

                // Trials
                resultStat(
                    value: "\(flowProtocol.tryCount)",
                    label: "Trials",
                    icon: "person.2",
                    color: OnLifeColors.socialTeal
                )
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func resultStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Attribution Card

    private var attributionCard: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 16))
                .foregroundColor(OnLifeColors.textTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Forked from another protocol")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("This protocol was adapted from a community protocol")
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
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.md) {
            // Try Protocol button
            Button(action: onTryProtocol) {
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

            // Fork button
            Button(action: { showingForkSheet = true }) {
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
                        .stroke(OnLifeColors.socialTeal, lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProtocolDetailView_Previews: PreviewProvider {
    static let sampleProtocol = FlowProtocol(
        id: "1",
        creatorId: "user1",
        creatorUsername: "sarah_chen",
        title: "Morning Clarity Stack",
        description: "Optimized caffeine + L-theanine stack for morning deep work sessions. The 2:1 theanine to caffeine ratio smooths out the energy curve while maintaining alertness.",
        substances: [
            SubstanceEntry(substanceName: "Caffeine", doseMg: 100, timingMinutes: -30),
            SubstanceEntry(substanceName: "L-Theanine", doseMg: 200, timingMinutes: -30)
        ],
        sessionDurationMinutes: 90,
        blocksPerSession: 2,
        targetChronotype: .moderateMorning,
        bestForActivities: [.coding, .writing],
        forkCount: 23,
        tryCount: 156,
        averageFlowImprovement: 18,
        averageRating: 4.5,
        ratingsCount: 42
    )

    static let userProfile = UserProfile(
        id: "me",
        username: "flowmaster",
        displayName: "You",
        chronotype: .moderateMorning,
        gardenAgeDays: 90,
        thirtyDayTrajectory: 23,
        consistencyPercentile: 75,
        totalPlantsGrown: 28,
        speciesUnlocked: 8
    )

    static var previews: some View {
        ProtocolDetailView(
            flowProtocol: sampleProtocol,
            currentUserProfile: userProfile,
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
