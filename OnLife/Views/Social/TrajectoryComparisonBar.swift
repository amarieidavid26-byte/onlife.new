import SwiftUI

// MARK: - Trajectory Comparison Bar

struct TrajectoryComparisonBar: View {
    let yourTrajectory: Double      // e.g., +23%
    let theirTrajectory: Double     // e.g., +34%
    let yourName: String
    let theirName: String
    let animated: Bool

    @State private var animationProgress: CGFloat = 0

    private var maxTrajectory: Double {
        max(abs(yourTrajectory), abs(theirTrajectory), 1)
    }

    private var yourBarWidth: CGFloat {
        CGFloat(abs(yourTrajectory) / maxTrajectory) * animationProgress
    }

    private var theirBarWidth: CGFloat {
        CGFloat(abs(theirTrajectory) / maxTrajectory) * animationProgress
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            HStack {
                Text("Learning Velocity")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                Text("30-day improvement")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            // Your trajectory bar
            trajectoryBarRow(
                name: yourName,
                trajectory: yourTrajectory,
                barWidth: yourBarWidth,
                color: OnLifeColors.socialTeal,
                isYou: true
            )

            // Their trajectory bar
            trajectoryBarRow(
                name: theirName,
                trajectory: theirTrajectory,
                barWidth: theirBarWidth,
                color: OnLifeColors.amber,
                isYou: false
            )

            // Comparison insight
            comparisonInsight
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .onAppear {
            if animated {
                withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }

    // MARK: - Trajectory Bar Row

    private func trajectoryBarRow(
        name: String,
        trajectory: Double,
        barWidth: CGFloat,
        color: Color,
        isYou: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Name and value
            HStack {
                HStack(spacing: Spacing.xs) {
                    if isYou {
                        Text("You")
                            .font(OnLifeFont.label())
                            .foregroundColor(OnLifeColors.textPrimary)
                    } else {
                        Text(name)
                            .font(OnLifeFont.label())
                            .foregroundColor(OnLifeColors.textPrimary)
                    }
                }

                Spacer()

                // Trajectory value
                HStack(spacing: Spacing.xs) {
                    Image(systemName: trajectory >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))

                    Text(trajectory >= 0 ? "+\(Int(trajectory))%" : "\(Int(trajectory))%")
                        .font(OnLifeFont.heading3())
                }
                .foregroundColor(trajectory >= 0 ? color : OnLifeColors.warning)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.cardBackgroundElevated)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.6), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * barWidth)
                }
            }
            .frame(height: 12)
        }
    }

    // MARK: - Comparison Insight

    private var comparisonInsight: some View {
        let diff = theirTrajectory - yourTrajectory

        return HStack(spacing: Spacing.sm) {
            Image(systemName: insightIcon)
                .font(.system(size: 14))
                .foregroundColor(insightColor)

            Text(insightText)
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textSecondary)

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(insightColor.opacity(0.1))
        )
    }

    private var insightIcon: String {
        let diff = theirTrajectory - yourTrajectory
        if abs(diff) < 5 {
            return "equal.circle"
        } else if diff > 0 {
            return "lightbulb.fill"
        } else {
            return "star.fill"
        }
    }

    private var insightColor: Color {
        let diff = theirTrajectory - yourTrajectory
        if abs(diff) < 5 {
            return OnLifeColors.socialTeal
        } else if diff > 0 {
            return OnLifeColors.amber
        } else {
            return OnLifeColors.healthy
        }
    }

    private var insightText: String {
        let diff = theirTrajectory - yourTrajectory
        if abs(diff) < 5 {
            return "You're both improving at similar rates!"
        } else if diff > 0 {
            return "They're improving \(Int(diff))% faster. Check their protocols for ideas."
        } else {
            return "You're improving \(Int(abs(diff)))% faster. Keep it up!"
        }
    }
}

// MARK: - Mini Trajectory Comparison (for lists)

struct MiniTrajectoryComparison: View {
    let yourTrajectory: Double
    let theirTrajectory: Double

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Your bar
            VStack(spacing: 2) {
                Text("You")
                    .font(OnLifeFont.labelSmall())
                    .foregroundColor(OnLifeColors.textTertiary)

                trajectoryPill(yourTrajectory, color: OnLifeColors.socialTeal)
            }

            // VS indicator
            Text("vs")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textMuted)

            // Their bar
            VStack(spacing: 2) {
                Text("Them")
                    .font(OnLifeFont.labelSmall())
                    .foregroundColor(OnLifeColors.textTertiary)

                trajectoryPill(theirTrajectory, color: OnLifeColors.amber)
            }
        }
    }

    private func trajectoryPill(_ value: Double, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 8))

            Text(value >= 0 ? "+\(Int(value))%" : "\(Int(value))%")
                .font(OnLifeFont.labelSmall())
        }
        .foregroundColor(value >= 0 ? color : OnLifeColors.warning)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill((value >= 0 ? color : OnLifeColors.warning).opacity(0.15))
        )
    }
}

// MARK: - Dual Trajectory Chart

struct DualTrajectoryChart: View {
    let yourData: [Double]      // Historical trajectory values
    let theirData: [Double]
    let yourName: String
    let theirName: String

    @State private var animationProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Legend
            HStack(spacing: Spacing.lg) {
                legendItem(name: "You", color: OnLifeColors.socialTeal)
                legendItem(name: theirName, color: OnLifeColors.amber)
            }

            // Chart
            GeometryReader { geometry in
                ZStack {
                    // Grid lines
                    gridLines(in: geometry)

                    // Your line
                    trajectoryLine(
                        data: yourData,
                        color: OnLifeColors.socialTeal,
                        in: geometry
                    )

                    // Their line
                    trajectoryLine(
                        data: theirData,
                        color: OnLifeColors.amber,
                        in: geometry
                    )
                }
            }
            .frame(height: 120)

            // Time labels
            HStack {
                Text("30d ago")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textMuted)

                Spacer()

                Text("Today")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textMuted)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animationProgress = 1.0
            }
        }
    }

    private func legendItem(name: String, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(name)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
        }
    }

    private func gridLines(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<4) { _ in
                Spacer()
                Rectangle()
                    .fill(OnLifeColors.textMuted.opacity(0.1))
                    .frame(height: 1)
            }
            Spacer()
        }
    }

    private func trajectoryLine(data: [Double], color: Color, in geometry: GeometryProxy) -> some View {
        let maxValue = max(data.max() ?? 1, 1)
        let minValue = min(data.min() ?? 0, 0)
        let range = maxValue - minValue

        return Path { path in
            guard data.count > 1 else { return }

            let stepX = geometry.size.width / CGFloat(data.count - 1)
            let height = geometry.size.height

            for (index, value) in data.enumerated() {
                let x = CGFloat(index) * stepX
                let normalizedValue = (value - minValue) / range
                let y = height * (1 - CGFloat(normalizedValue))

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .trim(from: 0, to: animationProgress)
        .stroke(
            color,
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct TrajectoryComparisonBar_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Main comparison bar
                TrajectoryComparisonBar(
                    yourTrajectory: 23,
                    theirTrajectory: 34,
                    yourName: "You",
                    theirName: "Sarah",
                    animated: true
                )

                // You're winning
                TrajectoryComparisonBar(
                    yourTrajectory: 45,
                    theirTrajectory: 28,
                    yourName: "You",
                    theirName: "Mike",
                    animated: true
                )

                // Similar rates
                TrajectoryComparisonBar(
                    yourTrajectory: 20,
                    theirTrajectory: 22,
                    yourName: "You",
                    theirName: "Alex",
                    animated: true
                )

                // Mini comparison
                MiniTrajectoryComparison(
                    yourTrajectory: 23,
                    theirTrajectory: 34
                )
                .padding()
                .background(OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)

                // Dual chart
                DualTrajectoryChart(
                    yourData: [10, 12, 15, 14, 18, 20, 23],
                    theirData: [8, 15, 18, 22, 28, 30, 34],
                    yourName: "You",
                    theirName: "Sarah"
                )
            }
            .padding()
        }
        .background(OnLifeColors.deepForest)
        .preferredColorScheme(.dark)
    }
}
#endif
