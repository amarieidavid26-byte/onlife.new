import SwiftUI

/// Timeline view showing pharmacokinetic data for a substance log
/// Displays peak timing, decay curves, and milestone predictions
struct SubstanceTimelineView: View {
    let substance: SubstanceLog
    let currentLevel: Double

    @State private var expandedDetails = false

    // MARK: - Computed Properties

    private var timeSinceIngestion: TimeInterval {
        Date().timeIntervalSince(substance.timestamp)
    }

    private var timeUntilPeak: TimeInterval {
        max(0, substance.peakTime - timeSinceIngestion)
    }

    private var isPeaking: Bool {
        // Within 5 minutes of peak time
        abs(timeSinceIngestion - substance.peakTime) < 5 * 60
    }

    private var isRising: Bool {
        timeSinceIngestion < substance.peakTime && timeSinceIngestion >= substance.onsetTime
    }

    private var timeUntilHalfLife: TimeInterval {
        // Time until first half-life after peak
        let halfLifeTime = substance.peakTime + substance.halfLife
        return max(0, halfLifeTime - timeSinceIngestion)
    }

    private var percentOfPeak: Int {
        guard substance.amount > 0 else { return 0 }
        return Int((currentLevel / substance.amount) * 100)
    }

    private var statusText: String {
        if timeSinceIngestion < substance.onsetTime {
            let remaining = Int((substance.onsetTime - timeSinceIngestion) / 60)
            return "Absorbing (\(remaining)m to onset)"
        } else if isPeaking {
            return "Peaking now"
        } else if isRising {
            return "Rising to peak in \(formatTimeInterval(timeUntilPeak))"
        } else if currentLevel > 1 {
            return "Declining (\(percentOfPeak)% remaining)"
        } else {
            return "Fully metabolized"
        }
    }

    private var substanceColor: Color {
        switch substance.substanceType {
        case .caffeine: return .brown
        case .lTheanine: return OnLifeColors.sage
        case .water: return .blue
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Main row (always visible)
            Button(action: {
                Haptics.selection()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    expandedDetails.toggle()
                }
            }) {
                HStack(spacing: Spacing.md) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(substanceColor.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: substance.substanceType.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(substanceColor)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Spacing.sm) {
                            Text(substance.substanceType.rawValue)
                                .font(OnLifeFont.body())
                                .fontWeight(.semibold)
                                .foregroundColor(OnLifeColors.textPrimary)

                            if isPeaking {
                                PeakingBadge()
                            }
                        }

                        Text(statusText)
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }

                    Spacer()

                    // Current level
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(currentLevel))\(substance.substanceType == .water ? "ml" : "mg")")
                            .font(OnLifeFont.heading3())
                            .foregroundColor(substanceColor)

                        Text("\(percentOfPeak)%")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }

                    // Chevron
                    Image(systemName: expandedDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding(Spacing.md)
            }
            .buttonStyle(.plain)

            // Expanded details
            if expandedDetails {
                VStack(spacing: Spacing.md) {
                    Divider()
                        .background(OnLifeColors.surface)

                    // Timeline visualization
                    TimelineVisualization(
                        currentLevel: currentLevel,
                        peakLevel: substance.amount,
                        timeSinceIngestion: timeSinceIngestion,
                        substanceType: substance.substanceType
                    )
                    .padding(.horizontal, Spacing.md)

                    // Timeline milestones
                    VStack(spacing: Spacing.sm) {
                        // Peak milestone
                        TimelineMilestone(
                            icon: "arrow.up.circle.fill",
                            title: "Peak",
                            time: timeUntilPeak > 0 ? formatTimeInterval(timeUntilPeak) : "Reached",
                            subtitle: timeUntilPeak > 0 ? "Maximum effect coming" : "Maximum effect reached",
                            color: .green,
                            isComplete: timeUntilPeak == 0
                        )

                        // Half-life milestone
                        TimelineMilestone(
                            icon: "timer",
                            title: "Half-life",
                            time: timeUntilHalfLife > 0 ? formatTimeInterval(timeUntilHalfLife) : "Passed",
                            subtitle: "50% remaining",
                            color: .orange,
                            isComplete: timeUntilHalfLife == 0
                        )

                        // Sleep-safe milestone (caffeine only)
                        if substance.substanceType == .caffeine {
                            let sleepSafeTime = timeUntilSleepSafe
                            TimelineMilestone(
                                icon: "moon.fill",
                                title: "Sleep safe",
                                time: sleepSafeTime > 0 ? formatTimeInterval(sleepSafeTime) : "Now",
                                subtitle: "Won't affect sleep",
                                color: .purple,
                                isComplete: sleepSafeTime == 0
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Helper Methods

    /// Time until caffeine drops below sleep-affecting threshold (~25mg)
    private var timeUntilSleepSafe: TimeInterval {
        // Calculate how long until level drops to ~25mg (sleep-safe threshold)
        // Using the formula: t = t½ × log₂(C₀/C_target)
        guard currentLevel > 25 else { return 0 }

        let halfLivesNeeded = log2(currentLevel / 25.0)
        let timeNeeded = halfLivesNeeded * substance.halfLife

        return max(0, timeNeeded)
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "Now"
        }
    }
}

// MARK: - Peaking Badge

struct PeakingBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10))
            Text("PEAK")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }
}

// MARK: - Timeline Visualization

struct TimelineVisualization: View {
    let currentLevel: Double
    let peakLevel: Double
    let timeSinceIngestion: TimeInterval
    let substanceType: SubstanceType

    private var substanceColor: Color {
        switch substanceType {
        case .caffeine: return .brown
        case .lTheanine: return OnLifeColors.sage
        case .water: return .blue
        }
    }

    private var fillPercent: CGFloat {
        guard peakLevel > 0 else { return 0 }
        return min(1.0, CGFloat(currentLevel / peakLevel))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Concentration")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)

                Spacer()

                Text("\(Int(currentLevel))/\(Int(peakLevel))\(substanceType == .water ? "ml" : "mg")")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.surface)
                        .frame(height: 10)

                    // Current level fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [substanceColor.opacity(0.6), substanceColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * fillPercent, height: 10)

                    // Peak marker (if past peak)
                    if timeSinceIngestion >= substanceType.peakTime {
                        Circle()
                            .fill(substanceColor)
                            .frame(width: 14, height: 14)
                            .offset(x: geometry.size.width * fillPercent - 7)
                    }
                }
            }
            .frame(height: 14)

            // Time labels
            HStack {
                Text(formatTime(substance: substanceType, elapsed: timeSinceIngestion))
                    .font(.system(size: 11))
                    .foregroundColor(OnLifeColors.textTertiary)

                Spacer()

                Text("Logged at \(Date().addingTimeInterval(-timeSinceIngestion), style: .time)")
                    .font(.system(size: 11))
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
    }

    private func formatTime(substance: SubstanceType, elapsed: TimeInterval) -> String {
        let minutes = Int(elapsed / 60)
        if minutes < 60 {
            return "\(minutes)m ago"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m ago"
        }
    }
}

// MARK: - Timeline Milestone

struct TimelineMilestone: View {
    let icon: String
    let title: String
    let time: String
    let subtitle: String
    let color: Color
    var isComplete: Bool = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isComplete ? color.opacity(0.5) : color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OnLifeFont.body())
                    .fontWeight(.medium)
                    .foregroundColor(isComplete ? OnLifeColors.textTertiary : OnLifeColors.textPrimary)

                Text(subtitle)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()

            Text(time)
                .font(OnLifeFont.body())
                .fontWeight(.semibold)
                .foregroundColor(isComplete ? OnLifeColors.textTertiary : color)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                .fill(color.opacity(isComplete ? 0.03 : 0.08))
        )
    }
}

// MARK: - Next Dose Recommendation

struct NextDoseRecommendation: View {
    let substanceType: SubstanceType
    let recommendedTime: Date
    let reason: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(OnLifeColors.amber.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundColor(OnLifeColors.amber)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Next Dose Suggestion")
                    .font(OnLifeFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Optimal \(substanceType.rawValue.lowercased()) at \(recommendedTime, style: .time)")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)

                Text(reason)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.amber.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(OnLifeColors.amber.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        VStack(spacing: 16) {
            SubstanceTimelineView(
                substance: SubstanceLog(
                    timestamp: Date().addingTimeInterval(-30 * 60), // 30 min ago
                    substanceType: .caffeine,
                    amount: 95,
                    unit: .mg,
                    source: "Coffee"
                ),
                currentLevel: 85
            )

            SubstanceTimelineView(
                substance: SubstanceLog(
                    timestamp: Date().addingTimeInterval(-2 * 3600), // 2 hours ago
                    substanceType: .lTheanine,
                    amount: 200,
                    unit: .mg,
                    source: nil
                ),
                currentLevel: 50
            )

            NextDoseRecommendation(
                substanceType: .caffeine,
                recommendedTime: Date().addingTimeInterval(2 * 3600),
                reason: "Current level will be at 50% for optimal re-dose"
            )
        }
        .padding()
    }
}
