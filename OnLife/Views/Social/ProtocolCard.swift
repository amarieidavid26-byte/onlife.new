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

                // Substances
                substancesRow

                // Timing info
                timingRow

                // Results (if available)
                if let avgScore = flowProtocol.averageFlowScore {
                    resultsRow(avgScore: avgScore)
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
                    .stroke(borderColor, lineWidth: flowProtocol.isVerified ? 2 : 0)
            )
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                // Protocol name
                Text(flowProtocol.name)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .lineLimit(2)

                // Creator
                HStack(spacing: Spacing.xs) {
                    Text("by")
                        .foregroundColor(OnLifeColors.textTertiary)

                    Text(flowProtocol.creatorName)
                        .foregroundColor(OnLifeColors.socialTeal)
                }
                .font(OnLifeFont.caption())
            }

            Spacer()

            // Badges
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                if flowProtocol.isVerified {
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
            Image(systemName: chronotype.icon)
                .font(.system(size: 10))

            Text(chronotype.rawValue)
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
        case .earlyBird: return OnLifeColors.amber
        case .nightOwl: return Color(hex: "7B68EE")
        case .flexible: return OnLifeColors.sage
        }
    }

    private var borderColor: Color {
        flowProtocol.isVerified ? OnLifeColors.socialTeal.opacity(0.5) : Color.clear
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
            Image(systemName: substanceIcon(substance.substance))
                .font(.system(size: 12))

            Text(substance.substance)
                .font(OnLifeFont.bodySmall())

            if let dosage = substance.dosage {
                Text("•")
                    .foregroundColor(OnLifeColors.textMuted)
                Text(dosage)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }
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
            // Optimal time
            if let optimalTime = flowProtocol.optimalTimeOfDay {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(OnLifeColors.textTertiary)

                    Text(optimalTime)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }

            // Duration
            HStack(spacing: Spacing.xs) {
                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundColor(OnLifeColors.textTertiary)

                Text("\(flowProtocol.recommendedDurationMinutes)m session")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Results Row

    private func resultsRow(avgScore: Double) -> some View {
        HStack(spacing: Spacing.md) {
            // Average flow score
            HStack(spacing: Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(OnLifeColors.socialTeal)

                Text("\(Int(avgScore * 100))% avg flow")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            // Trial count
            Text("•")
                .foregroundColor(OnLifeColors.textMuted)

            Text("\(flowProtocol.trialCount) trials")
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

            // Save count
            HStack(spacing: Spacing.xs) {
                Image(systemName: "bookmark")
                    .font(.system(size: 12))

                Text("\(flowProtocol.saveCount)")
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
                    Text(flowProtocol.name)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: Spacing.sm) {
                        Text("by \(flowProtocol.creatorName)")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)

                        if let avgScore = flowProtocol.averageFlowScore {
                            Text("•")
                                .foregroundColor(OnLifeColors.textMuted)

                            HStack(spacing: 2) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))

                                Text("\(Int(avgScore * 100))%")
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
                    Image(systemName: substanceIcon(substance.substance))
                        .font(.system(size: 16))
                        .foregroundColor(OnLifeColors.socialTeal)
                        .frame(width: 24)

                    // Name and dosage
                    VStack(alignment: .leading, spacing: 2) {
                        Text(substance.substance)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textPrimary)

                        if let dosage = substance.dosage {
                            Text(dosage)
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textTertiary)
                        }
                    }

                    Spacer()

                    // Timing
                    if showTiming {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(timingLabel(substance.timing))
                                .font(OnLifeFont.label())
                                .foregroundColor(OnLifeColors.textSecondary)

                            if let minutes = substance.minutesBefore {
                                Text("\(minutes)m before")
                                    .font(OnLifeFont.caption())
                                    .foregroundColor(OnLifeColors.textTertiary)
                            }
                        }
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

    private func timingLabel(_ timing: SubstanceTiming) -> String {
        switch timing {
        case .prework: return "Pre-work"
        case .duringWork: return "During"
        case .postWork: return "After"
        case .wakeUp: return "Wake-up"
        case .beforeBed: return "Before bed"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProtocolCard_Previews: PreviewProvider {
    static let sampleProtocol = FlowProtocol(
        id: "1",
        name: "Morning Clarity Stack",
        creatorId: "user1",
        creatorName: "Sarah Chen",
        description: "Optimized caffeine + L-theanine stack for morning deep work sessions. The 2:1 theanine to caffeine ratio smooths out the energy curve.",
        substances: [
            SubstanceEntry(
                substance: "Caffeine",
                dosage: "100mg",
                timing: .prework,
                minutesBefore: 30
            ),
            SubstanceEntry(
                substance: "L-Theanine",
                dosage: "200mg",
                timing: .prework,
                minutesBefore: 30
            )
        ],
        activities: [.coding, .writing],
        targetChronotype: .earlyBird,
        optimalTimeOfDay: "6-10 AM",
        recommendedDurationMinutes: 90,
        averageFlowScore: 0.78,
        trialCount: 156,
        forkCount: 23,
        saveCount: 89,
        isVerified: true,
        isPublic: true,
        createdAt: Date(),
        updatedAt: Date()
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
