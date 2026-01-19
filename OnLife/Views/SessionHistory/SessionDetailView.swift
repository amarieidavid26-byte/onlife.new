import SwiftUI

/// Detailed view showing full analytics breakdown for a completed focus session
struct SessionDetailView: View {
    let session: FocusSession
    let gardenName: String
    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed Properties

    private var completionStatus: String {
        if session.wasAbandoned {
            return "Abandoned"
        } else if session.wasCompleted {
            return "Completed"
        } else {
            return "Ended Early"
        }
    }

    private var statusColor: Color {
        if session.wasAbandoned {
            return OnLifeColors.terracotta
        } else if session.wasCompleted {
            return OnLifeColors.sage
        } else {
            return OnLifeColors.amber
        }
    }

    private var completionPercent: Int {
        guard session.plannedDuration > 0 else { return 0 }
        return min(100, Int((session.actualDuration / session.plannedDuration) * 100))
    }

    private var orbsEarned: Int {
        var orbs = Int(session.actualDuration / 60) // 1 orb per minute

        if session.wasCompleted {
            orbs += 5 // Completion bonus
        }

        if session.focusQuality >= 0.9 {
            orbs += 10 // Perfect session bonus
        }

        // Growth stage bonus
        orbs += session.growthStageAchieved * 2

        return orbs
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [OnLifeColors.deepForest, OnLifeColors.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Header Summary
                        sessionSummaryCard

                        // Flow Score Breakdown (if from Watch with biometrics)
                        if let biometrics = session.biometrics, biometrics.averageFlowScore > 0 {
                            flowScoreCard(biometrics: biometrics)
                        }

                        // Biometric Data (if from Watch)
                        if let biometrics = session.biometrics, biometrics.averageHR > 0 {
                            biometricsCard(data: biometrics)
                        }

                        // Flow Timeline (if available)
                        if let flowTimeline = session.flowTimeline, !flowTimeline.isEmpty {
                            flowTimelineCard(timeline: flowTimeline)
                        }

                        // Session Stats
                        sessionStatsCard

                        // Rewards Breakdown
                        rewardsCard
                    }
                    .padding(Spacing.lg)
                    .padding(.bottom, Spacing.xxl)
                }
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OnLifeColors.deepForest, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(OnLifeColors.sage)
                }
            }
        }
    }

    // MARK: - Summary Card

    private var sessionSummaryCard: some View {
        VStack(spacing: Spacing.lg) {
            // Plant emoji and status
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 120, height: 120)

                Text(session.plantSpecies.icon)
                    .font(.system(size: 64))
            }

            VStack(spacing: Spacing.sm) {
                Text(completionStatus)
                    .font(OnLifeFont.heading1())
                    .foregroundColor(statusColor)

                Text(session.taskDescription)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Basic stats row
            HStack(spacing: Spacing.xl) {
                DetailStatItem(
                    icon: "clock.fill",
                    value: session.formattedDuration,
                    label: "Duration",
                    color: OnLifeColors.sage
                )

                DetailStatItem(
                    icon: "percent",
                    value: "\(completionPercent)%",
                    label: "Complete",
                    color: statusColor
                )

                if let biometrics = session.biometrics, biometrics.averageFlowScore > 0 {
                    DetailStatItem(
                        icon: "brain.head.profile",
                        value: "\(biometrics.averageFlowScore)",
                        label: "Flow Score",
                        color: flowScoreColor(biometrics.averageFlowScore)
                    )
                }
            }

            // Garden & Plant info
            HStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12))
                    Text(gardenName)
                        .font(OnLifeFont.caption())
                }

                HStack(spacing: Spacing.xs) {
                    Text(session.plantSpecies.icon)
                        .font(.system(size: 14))
                    Text(session.plantSpecies.displayName)
                        .font(OnLifeFont.caption())
                }

                HStack(spacing: Spacing.xs) {
                    Image(systemName: session.source == .watch ? "applewatch" : "iphone")
                        .font(.system(size: 12))
                    Text(session.source.rawValue)
                        .font(OnLifeFont.caption())
                }
            }
            .foregroundColor(OnLifeColors.textTertiary)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Flow Score Card

    private func flowScoreCard(biometrics: BiometricSessionData) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("Flow Score Breakdown")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            // Overall score with gauge
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Average Score")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                    Text("\(biometrics.averageFlowScore)/100")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(flowScoreColor(biometrics.averageFlowScore))
                }

                Spacer()

                CircularProgressView(
                    progress: Double(biometrics.averageFlowScore) / 100.0,
                    color: flowScoreColor(biometrics.averageFlowScore),
                    lineWidth: 8
                )
                .frame(width: 70, height: 70)
            }

            Divider()
                .background(OnLifeColors.surface)

            // Component scores
            VStack(spacing: Spacing.sm) {
                FlowComponentRow(
                    label: "HRV Score",
                    value: biometrics.hrvScore,
                    maxValue: 40,
                    color: .purple
                )

                FlowComponentRow(
                    label: "Heart Rate Score",
                    value: biometrics.hrScore,
                    maxValue: 30,
                    color: .red
                )

                FlowComponentRow(
                    label: "Sleep Quality",
                    value: biometrics.sleepScore,
                    maxValue: 20,
                    color: .blue
                )

                FlowComponentRow(
                    label: "Substance Timing",
                    value: biometrics.substanceScore,
                    maxValue: 10,
                    color: OnLifeColors.sage
                )
            }

            // Peak flow score
            if biometrics.peakFlowScore > biometrics.averageFlowScore {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                    Text("Peak: \(biometrics.peakFlowScore)")
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

    // MARK: - Biometrics Card

    private func biometricsCard(data: BiometricSessionData) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.red)
                Text("Biometric Data")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                // Watch badge
                HStack(spacing: 4) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 12))
                    Text("Watch")
                        .font(OnLifeFont.caption())
                }
                .foregroundColor(OnLifeColors.textTertiary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .fill(OnLifeColors.surface)
                )
            }

            VStack(spacing: Spacing.sm) {
                BiometricRow(
                    icon: "heart.fill",
                    label: "Average Heart Rate",
                    value: "\(Int(data.averageHR)) bpm",
                    subvalue: "Peak: \(Int(data.peakHR)) bpm",
                    color: .red
                )

                BiometricRow(
                    icon: "waveform.path.ecg",
                    label: "Average HRV",
                    value: "\(Int(data.averageHRV)) ms",
                    subvalue: "Peak: \(Int(data.peakHRV)) ms",
                    color: .green
                )

                if data.timeInFlowState > 0 {
                    BiometricRow(
                        icon: "brain.head.profile",
                        label: "Time in Flow",
                        value: formatDuration(data.timeInFlowState),
                        subvalue: "\(Int((data.timeInFlowState / session.actualDuration) * 100))% of session",
                        color: .purple
                    )
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Flow Timeline Card

    private func flowTimelineCard(timeline: [FlowDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(OnLifeColors.sage)
                Text("Flow Timeline")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            // Simple bar chart of flow scores over time
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(timeline.prefix(30)) { point in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(flowStateColor(point.flowState))
                            .frame(width: 8, height: CGFloat(point.flowScore) * 0.6)
                    }
                }
            }
            .frame(height: 70)
            .frame(maxWidth: .infinity)

            // Legend
            HStack(spacing: Spacing.md) {
                FlowStateLegendItem(color: .purple, label: "Flow")
                FlowStateLegendItem(color: .blue, label: "Pre-Flow")
                FlowStateLegendItem(color: .orange, label: "Calibrating")
            }
            .font(OnLifeFont.caption())
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Session Stats Card

    private var sessionStatsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(OnLifeColors.amber)
                Text("Session Stats")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            VStack(spacing: Spacing.sm) {
                SessionStatRow(
                    label: "Planned Duration",
                    value: formatDuration(session.plannedDuration)
                )

                SessionStatRow(
                    label: "Actual Duration",
                    value: formatDuration(session.actualDuration)
                )

                SessionStatRow(
                    label: "Pauses",
                    value: "\(session.pauseCount)"
                )

                if session.totalPauseTime > 0 {
                    SessionStatRow(
                        label: "Total Pause Time",
                        value: formatDuration(session.totalPauseTime)
                    )
                }

                SessionStatRow(
                    label: "Growth Stage",
                    value: "\(session.growthStageAchieved)/10"
                )

                SessionStatRow(
                    label: "Focus Quality",
                    value: "\(Int(session.focusQuality * 100))%"
                )

                SessionStatRow(
                    label: "Environment",
                    value: "\(session.environment.icon) \(session.environment.displayName)"
                )

                SessionStatRow(
                    label: "Time of Day",
                    value: session.timeOfDay.displayName
                )
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Rewards Card

    private var rewardsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(OnLifeColors.amber)
                Text("Rewards Earned")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            VStack(spacing: Spacing.sm) {
                RewardRow(
                    label: "Base Duration",
                    value: "+\(Int(session.actualDuration / 60)) orbs",
                    calculation: "\(Int(session.actualDuration / 60)) minutes"
                )

                RewardRow(
                    label: "Growth Bonus",
                    value: "+\(session.growthStageAchieved * 2) orbs",
                    calculation: "Stage \(session.growthStageAchieved) reached"
                )

                if session.wasCompleted {
                    RewardRow(
                        label: "Completion Bonus",
                        value: "+5 orbs",
                        calculation: "Finished on time"
                    )
                }

                if session.focusQuality >= 0.9 {
                    RewardRow(
                        label: "Perfect Session",
                        value: "+10 orbs",
                        calculation: "\(Int(session.focusQuality * 100))% quality"
                    )
                }

                Divider()
                    .background(OnLifeColors.surface)

                HStack {
                    Text("Total Earned")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)
                    Spacer()
                    Text("+\(orbsEarned) orbs")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(OnLifeColors.amber)
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Helper Functions

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func flowScoreColor(_ score: Int) -> Color {
        if score >= 70 { return .green }
        if score >= 40 { return .blue }
        return .orange
    }

    private func flowStateColor(_ state: String) -> Color {
        switch state.lowercased() {
        case "flow": return .purple
        case "pre-flow", "preflow": return .blue
        case "post-flow", "postflow": return .cyan
        default: return .orange
        }
    }
}

// MARK: - Supporting Views

struct DetailStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
    }
}

struct FlowComponentRow: View {
    let label: String
    let value: Int
    let maxValue: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(label)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
                Spacer()
                Text("\(value)/\(maxValue)")
                    .font(OnLifeFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(OnLifeColors.surface)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(
                            width: geometry.size.width * CGFloat(value) / CGFloat(maxValue),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }
}

struct BiometricRow: View {
    let icon: String
    let label: String
    let value: String
    let subvalue: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
                Text(subvalue)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()

            Text(value)
                .font(OnLifeFont.body())
                .fontWeight(.semibold)
                .foregroundColor(OnLifeColors.textPrimary)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                .fill(OnLifeColors.surface.opacity(0.5))
        )
    }
}

struct SessionStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
            Spacer()
            Text(value)
                .font(OnLifeFont.body())
                .fontWeight(.medium)
                .foregroundColor(OnLifeColors.textPrimary)
        }
    }
}

struct RewardRow: View {
    let label: String
    let value: String
    let calculation: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)
                Text(calculation)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()

            Text(value)
                .font(OnLifeFont.body())
                .fontWeight(.semibold)
                .foregroundColor(OnLifeColors.sage)
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(OnLifeColors.surface, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

struct FlowStateLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(OnLifeColors.textTertiary)
        }
    }
}
