import SwiftUI

// MARK: - Flow Portrait Card

struct FlowPortraitCard: View {
    let profile: UserProfile
    let onPhilosophyTap: (PhilosophyMoment) -> Void

    @State private var trajectoryAnimated = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            HStack {
                Text("Your Flow Portrait")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                PhilosophyButton {
                    onPhilosophyTap(PhilosophyMomentsLibrary.trajectoriesMatterMore)
                }

                Spacer()
            }

            // Chronotype Row
            chronotypeRow

            // Trajectory Row
            trajectoryRow

            // Garden Age Row
            gardenAgeRow

            // Consistency Row
            consistencyRow
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                trajectoryAnimated = true
            }
        }
    }

    // MARK: - Chronotype Row

    private var chronotypeRow: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(chronotypeColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: profile.chronotype.icon)
                    .font(.system(size: 18))
                    .foregroundColor(chronotypeColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text("Chronotype")
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.textTertiary)

                    PhilosophyButton {
                        onPhilosophyTap(PhilosophyMomentsLibrary.peakWindows)
                    }
                }

                Text(profile.chronotype.rawValue)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                if let peakWindow = profile.peakFlowWindows.first {
                    Text("Peak: \(peakWindow.displayString)")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            Spacer()
        }
    }

    private var chronotypeColor: Color {
        switch profile.chronotype {
        case .earlyBird:
            return OnLifeColors.amber
        case .nightOwl:
            return Color(hex: "7B68EE") // Soft purple
        case .flexible:
            return OnLifeColors.sage
        }
    }

    // MARK: - Trajectory Row

    private var trajectoryRow: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(trajectoryColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18))
                    .foregroundColor(trajectoryColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text("30-Day Trajectory")
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.textTertiary)

                    PhilosophyButton {
                        onPhilosophyTap(PhilosophyMomentsLibrary.trajectoriesMatterMore)
                    }
                }

                HStack(spacing: Spacing.sm) {
                    Text(trajectoryText)
                        .font(OnLifeFont.heading3())
                        .foregroundColor(trajectoryColor)

                    // Mini sparkline
                    TrajectorySparkline(
                        value: profile.thirtyDayTrajectory,
                        animated: trajectoryAnimated
                    )
                }
            }

            Spacer()
        }
    }

    private var trajectoryText: String {
        let value = profile.thirtyDayTrajectory
        if value > 0 {
            return "+\(Int(value))% improvement"
        } else if value < 0 {
            return "\(Int(value))% change"
        }
        return "Steady"
    }

    private var trajectoryColor: Color {
        if profile.thirtyDayTrajectory > 10 {
            return OnLifeColors.socialTeal
        } else if profile.thirtyDayTrajectory > 0 {
            return OnLifeColors.healthy
        } else if profile.thirtyDayTrajectory < 0 {
            return OnLifeColors.warning
        }
        return OnLifeColors.textSecondary
    }

    // MARK: - Garden Age Row

    private var gardenAgeRow: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(OnLifeColors.healthy.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 18))
                    .foregroundColor(OnLifeColors.healthy)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text("Garden Age")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)

                HStack(spacing: Spacing.sm) {
                    Text(gardenAgeText)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("•")
                        .foregroundColor(OnLifeColors.textTertiary)

                    Text("\(profile.totalPlantsGrown) plants grown")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }

            Spacer()
        }
    }

    private var gardenAgeText: String {
        let days = profile.gardenAgeDays
        if days < 30 {
            return "\(days) days"
        } else {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        }
    }

    // MARK: - Consistency Row

    private var consistencyRow: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(consistencyColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 18))
                    .foregroundColor(consistencyColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text("Consistency")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)

                HStack(spacing: Spacing.sm) {
                    Text("Top \(100 - profile.consistencyPercentile)%")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("for your experience level")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                // Consistency bar
                ConsistencyBar(percentile: profile.consistencyPercentile)
            }

            Spacer()
        }
    }

    private var consistencyColor: Color {
        let percentile = profile.consistencyPercentile
        if percentile >= 80 {
            return OnLifeColors.socialTeal
        } else if percentile >= 50 {
            return OnLifeColors.healthy
        } else {
            return OnLifeColors.warning
        }
    }
}

// MARK: - Trajectory Sparkline

struct TrajectorySparkline: View {
    let value: Double
    let animated: Bool

    // Sample data points for visualization
    private var dataPoints: [CGFloat] {
        // Generate a smooth curve based on trajectory value
        let trend = CGFloat(value) / 100.0
        return [
            0.3,
            0.35 + trend * 0.1,
            0.4 + trend * 0.15,
            0.5 + trend * 0.2,
            0.55 + trend * 0.25,
            0.65 + trend * 0.3,
            0.75 + trend * 0.35,
            1.0
        ].map { min(1.0, max(0.0, $0)) }
    }

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(dataPoints.count - 1)

                path.move(to: CGPoint(x: 0, y: height * (1 - dataPoints[0])))

                for (index, point) in dataPoints.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height * (1 - point)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .trim(from: 0, to: animated ? 1 : 0)
            .stroke(
                LinearGradient(
                    colors: [OnLifeColors.socialTeal.opacity(0.5), OnLifeColors.socialTeal],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: 60, height: 20)
    }
}

// MARK: - Consistency Bar

struct ConsistencyBar: View {
    let percentile: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(OnLifeColors.cardBackgroundElevated)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [OnLifeColors.socialTeal.opacity(0.7), OnLifeColors.socialTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(percentile) / 100)
            }
        }
        .frame(height: 4)
        .frame(maxWidth: 150)
    }
}

// MARK: - Compact Flow Portrait (for lists)

struct FlowPortraitCompact: View {
    let profile: UserProfile

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Chronotype icon
            Image(systemName: profile.chronotype.icon)
                .font(.system(size: 14))
                .foregroundColor(OnLifeColors.textTertiary)

            // Trajectory
            HStack(spacing: Spacing.xs) {
                Image(systemName: profile.thirtyDayTrajectory >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10))

                Text("\(Int(abs(profile.thirtyDayTrajectory)))%")
                    .font(OnLifeFont.labelSmall())
            }
            .foregroundColor(profile.thirtyDayTrajectory >= 0 ? OnLifeColors.socialTeal : OnLifeColors.warning)

            // Garden age
            HStack(spacing: Spacing.xs) {
                Image(systemName: "leaf")
                    .font(.system(size: 10))

                Text("\(profile.gardenAgeDays)d")
                    .font(OnLifeFont.labelSmall())
            }
            .foregroundColor(OnLifeColors.textTertiary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FlowPortraitCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.lg) {
            FlowPortraitCard(
                profile: UserProfile(
                    id: "preview",
                    username: "sarahflows",
                    displayName: "Sarah Chen",
                    chronotype: .nightOwl,
                    peakFlowWindows: [TimeWindow(startHour: 22, endHour: 2)],
                    masteryDurationDays: 120,
                    gardenAgeDays: 120,
                    thirtyDayTrajectory: 34,
                    consistencyPercentile: 85,
                    totalPlantsGrown: 47,
                    speciesUnlocked: 12
                ),
                onPhilosophyTap: { _ in }
            )

            FlowPortraitCompact(
                profile: UserProfile(
                    id: "preview",
                    username: "test",
                    displayName: "Test",
                    chronotype: .earlyBird,
                    thirtyDayTrajectory: -5,
                    consistencyPercentile: 60,
                    totalPlantsGrown: 10,
                    speciesUnlocked: 3,
                    gardenAgeDays: 45
                )
            )
            .padding()
            .background(OnLifeColors.cardBackground)
        }
        .padding()
        .background(OnLifeColors.deepForest)
        .preferredColorScheme(.dark)
    }
}
#endif
