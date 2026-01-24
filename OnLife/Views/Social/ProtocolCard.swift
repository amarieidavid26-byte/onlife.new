import SwiftUI

// MARK: - Protocol Card

struct ProtocolCard: View {
    let flowProtocol: FlowProtocol
    let onTap: () -> Void
    let onFork: (() -> Void)?
    let onPhilosophyTap: ((PhilosophyMoment) -> Void)?

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header
                headerRow

                // Description (if short)
                if !flowProtocol.description.isEmpty && flowProtocol.description.count < 100 {
                    Text(flowProtocol.description)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .lineLimit(2)
                }

                // Substances
                if !flowProtocol.substances.isEmpty {
                    substancesRow
                }

                // Timing info
                timingRow

                // Results (if available)
                if flowProtocol.tryCount > 0 {
                    resultsRow
                }

                // Footer with stats
                footerRow
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .stroke(borderColor, lineWidth: isVerified ? 2 : 0)
            )
        }
        .buttonStyle(PressableCardStyle())
    }

    // Computed property for verified status (based on ratings)
    private var isVerified: Bool {
        flowProtocol.ratingsCount >= 10 && flowProtocol.averageRating >= 4.0
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                // Protocol name
                Text(flowProtocol.title)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .lineLimit(2)

                // Creator
                HStack(spacing: Spacing.xs) {
                    Text("by")
                        .foregroundColor(OnLifeColors.textTertiary)

                    Text(flowProtocol.creatorUsername)
                        .foregroundColor(OnLifeColors.socialTeal)
                }
                .font(OnLifeFont.caption())
            }

            Spacer()

            // Badges
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                if isVerified {
                    verifiedBadge
                }

                if let chronotype = flowProtocol.targetChronotype {
                    chronotypeBadge(chronotype)
                }
            }
        }
    }

    private var verifiedBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10))

            Text("Verified")
                .font(OnLifeFont.labelSmall())
        }
        .foregroundColor(OnLifeColors.socialTeal)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(OnLifeColors.socialTeal.opacity(0.15))
        )
    }

    private func chronotypeBadge(_ chronotype: Chronotype) -> some View {
        HStack(spacing: 2) {
            Image(systemName: chronotype.sfSymbol)
                .font(.system(size: 10))

            Text(chronotype.shortName)
                .font(OnLifeFont.labelSmall())
        }
        .foregroundColor(chronotypeColor(chronotype))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(chronotypeColor(chronotype).opacity(0.15))
        )
    }

    private func chronotypeColor(_ chronotype: Chronotype) -> Color {
        switch chronotype {
        case .extremeMorning, .moderateMorning: return OnLifeColors.amber
        case .moderateEvening, .extremeEvening: return Color(hex: "7B68EE")
        case .intermediate: return OnLifeColors.sage
        }
    }

    private var borderColor: Color {
        isVerified ? OnLifeColors.socialTeal.opacity(0.5) : Color.clear
    }

    // MARK: - Substances Row

    private var substancesRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Substances")
                .font(OnLifeFont.label())
                .foregroundColor(OnLifeColors.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(flowProtocol.substances) { substance in
                        substancePill(substance)
                    }
                }
            }
        }
    }

    private func substancePill(_ substance: SubstanceEntry) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: substanceIcon(substance.substanceName))
                .font(.system(size: 12))

            Text(substance.substanceName)
                .font(OnLifeFont.bodySmall())

            Text("•")
                .foregroundColor(OnLifeColors.textMuted)
            Text(substance.formattedDose)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .foregroundColor(OnLifeColors.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(OnLifeColors.cardBackgroundElevated)
        )
    }

    private func substanceIcon(_ substance: String) -> String {
        let lowercased = substance.lowercased()
        if lowercased.contains("caffeine") || lowercased.contains("coffee") {
            return "cup.and.saucer.fill"
        } else if lowercased.contains("theanine") {
            return "leaf.fill"
        } else if lowercased.contains("nicotine") {
            return "smoke.fill"
        } else if lowercased.contains("creatine") {
            return "bolt.fill"
        } else {
            return "pills.fill"
        }
    }

    // MARK: - Timing Row

    private var timingRow: some View {
        HStack(spacing: Spacing.lg) {
            // Duration
            HStack(spacing: Spacing.xs) {
                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundColor(OnLifeColors.textTertiary)

                Text(flowProtocol.formattedDuration)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            // Blocks
            if flowProtocol.blocksPerSession > 1 {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "square.stack")
                        .font(.system(size: 12))
                        .foregroundColor(OnLifeColors.textTertiary)

                    Text("\(flowProtocol.blocksPerSession) blocks")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }

            // Activities
            if !flowProtocol.bestForActivities.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: flowProtocol.bestForActivities.first?.icon ?? "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(OnLifeColors.textTertiary)

                    Text(flowProtocol.bestForActivities.first?.displayName ?? "")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Results Row

    private var resultsRow: some View {
        HStack(spacing: Spacing.md) {
            // Average improvement
            if flowProtocol.averageFlowImprovement > 0 {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14))
                        .foregroundColor(OnLifeColors.socialTeal)

                    Text("+\(Int(flowProtocol.averageFlowImprovement))% flow")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                }
            }

            // Rating
            if flowProtocol.ratingsCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(OnLifeColors.amber)

                    Text(String(format: "%.1f", flowProtocol.averageRating))
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                }
            }

            // Trial count
            Text("•")
                .foregroundColor(OnLifeColors.textMuted)

            Text("\(flowProtocol.tryCount) trials")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)

            Spacer()
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.socialTeal.opacity(0.1))
        )
    }

    // MARK: - Footer Row

    private var footerRow: some View {
        HStack {
            // Fork count
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12))

                Text("\(flowProtocol.forkCount) forks")
                    .font(OnLifeFont.caption())
            }
            .foregroundColor(OnLifeColors.textTertiary)

            Spacer()

            // Fork button (if available)
            if let onFork = onFork {
                Button(action: onFork) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 12))

                        Text("Fork")
                            .font(OnLifeFont.label())
                    }
                    .foregroundColor(OnLifeColors.socialTeal)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule()
                            .stroke(OnLifeColors.socialTeal, lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - Protocol Card Compact

struct ProtocolCardCompact: View {
    let flowProtocol: FlowProtocol
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(OnLifeColors.socialTeal.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "flask.fill")
                        .font(.system(size: 18))
                        .foregroundColor(OnLifeColors.socialTeal)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(flowProtocol.title)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: Spacing.sm) {
                        Text("by \(flowProtocol.creatorUsername)")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)

                        if flowProtocol.averageFlowImprovement > 0 {
                            Text("•")
                                .foregroundColor(OnLifeColors.textMuted)

                            HStack(spacing: 2) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 10))

                                Text("+\(Int(flowProtocol.averageFlowImprovement))%")
                                    .font(OnLifeFont.caption())
                            }
                            .foregroundColor(OnLifeColors.socialTeal)
                        }
                    }
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

// MARK: - Protocol Substances List

struct ProtocolSubstancesList: View {
    let substances: [SubstanceEntry]
    let showTiming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(substances) { substance in
                HStack(spacing: Spacing.md) {
                    // Icon
                    Image(systemName: substanceIcon(substance.substanceName))
                        .font(.system(size: 16))
                        .foregroundColor(OnLifeColors.socialTeal)
                        .frame(width: 24)

                    // Name and dosage
                    VStack(alignment: .leading, spacing: 2) {
                        Text(substance.substanceName)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textPrimary)

                        Text(substance.formattedDose)
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }

                    Spacer()

                    // Timing
                    if showTiming {
                        Text(substance.timingDescription)
                            .font(OnLifeFont.label())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .fill(OnLifeColors.cardBackgroundElevated)
                )
            }
        }
    }

    private func substanceIcon(_ substance: String) -> String {
        let lowercased = substance.lowercased()
        if lowercased.contains("caffeine") || lowercased.contains("coffee") {
            return "cup.and.saucer.fill"
        } else if lowercased.contains("theanine") {
            return "leaf.fill"
        } else if lowercased.contains("nicotine") {
            return "smoke.fill"
        } else if lowercased.contains("creatine") {
            return "bolt.fill"
        } else {
            return "pills.fill"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProtocolCard_Previews: PreviewProvider {
    static let sampleProtocol = FlowProtocol(
        id: "1",
        creatorId: "user1",
        creatorUsername: "sarah_chen",
        title: "Morning Clarity Stack",
        description: "Optimized caffeine + L-theanine stack for morning deep work sessions. The 2:1 theanine to caffeine ratio smooths out the energy curve.",
        substances: [
            SubstanceEntry(
                substanceName: "Caffeine",
                doseMg: 100,
                timingMinutes: -30
            ),
            SubstanceEntry(
                substanceName: "L-Theanine",
                doseMg: 200,
                timingMinutes: -30
            )
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

    static var previews: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Full card
                ProtocolCard(
                    flowProtocol: sampleProtocol,
                    onTap: {},
                    onFork: {},
                    onPhilosophyTap: nil
                )

                // Compact card
                ProtocolCardCompact(
                    flowProtocol: sampleProtocol,
                    onTap: {}
                )

                // Substances list
                ProtocolSubstancesList(
                    substances: sampleProtocol.substances,
                    showTiming: true
                )
            }
            .padding()
        }
        .background(OnLifeColors.deepForest)
        .preferredColorScheme(.dark)
    }
}
#endif
