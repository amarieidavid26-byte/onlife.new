import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        ZStack {
            AppColors.richSoil
                .ignoresSafeArea()

            if viewModel.sessions.count < 3 {
                EmptyAnalyticsView()
            } else {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Stats Header
                        StatsHeaderView(viewModel: viewModel)
                            .padding(.horizontal, Spacing.xl)

                        // AI Insight Card
                        AIInsightCardView(viewModel: viewModel)
                            .padding(.horizontal, Spacing.xl)

                        // Template Insights Section
                        InsightsSection(insights: viewModel.insights)
                            .padding(.horizontal, Spacing.xl)

                        // Environment Breakdown
                        if !viewModel.environmentBreakdown.isEmpty {
                            EnvironmentBreakdownView(environments: viewModel.environmentBreakdown)
                                .padding(.horizontal, Spacing.xl)
                        }

                        // Time of Day Breakdown
                        if !viewModel.timeOfDayBreakdown.isEmpty {
                            TimeOfDayBreakdownView(timeSlots: viewModel.timeOfDayBreakdown)
                                .padding(.horizontal, Spacing.xl)
                        }

                        // Garden Distribution
                        if !viewModel.gardenBreakdown.isEmpty {
                            GardenDistributionView(gardens: viewModel.gardenBreakdown)
                                .padding(.horizontal, Spacing.xl)
                        }

                        Spacer(minLength: Spacing.xxxl)
                    }
                    .padding(.top, Spacing.xl)
                }
                .task {
                    // Generate AI insight when view appears
                    #if DEBUG
                    // Test AI insight without real API key
                    await viewModel.testAIInsight()
                    #else
                    await viewModel.generateAIInsight()
                    #endif
                }
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}

// MARK: - Stats Header
struct StatsHeaderView: View {
    let viewModel: AnalyticsViewModel

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("Your Progress")
                .font(AppFont.heading2())
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                AnalyticsStatCard(
                    icon: "flame.fill",
                    value: "\(viewModel.totalSessions)",
                    label: "Total Sessions"
                )

                AnalyticsStatCard(
                    icon: "clock.fill",
                    value: viewModel.totalFocusTimeFormatted,
                    label: "Total Focus"
                )

                AnalyticsStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    value: viewModel.averageSessionFormatted,
                    label: "Avg Session"
                )

                AnalyticsStatCard(
                    icon: "star.fill",
                    value: viewModel.longestSessionFormatted,
                    label: "Longest Session"
                )
            }
        }
    }
}

struct AnalyticsStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        CardView {
            VStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.healthy)

                Text(value)
                    .font(AppFont.heading3())
                    .foregroundColor(AppColors.textPrimary)

                Text(label)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Spacing.lg)
        }
    }
}

// MARK: - Insights Section
struct InsightsSection: View {
    let insights: [Insight]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Smart Insights")
                .font(AppFont.heading2())
                .foregroundColor(AppColors.textPrimary)

            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
    }
}

struct InsightCard: View {
    let insight: Insight

    var body: some View {
        CardView {
            HStack(spacing: Spacing.md) {
                Image(systemName: insight.icon)
                    .font(.system(size: 24))
                    .foregroundColor(insight.type.color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(insight.title)
                        .font(AppFont.heading3())
                        .foregroundColor(AppColors.textPrimary)

                    Text(insight.description)
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(Spacing.lg)
        }
    }
}

// MARK: - Environment Breakdown
struct EnvironmentBreakdownView: View {
    let environments: [(environment: FocusEnvironment, avgDuration: TimeInterval, sessionCount: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Focus by Environment")
                .font(AppFont.heading2())
                .foregroundColor(AppColors.textPrimary)

            CardView {
                VStack(spacing: Spacing.md) {
                    ForEach(environments.indices, id: \.self) { index in
                        EnvironmentBarRow(
                            environment: environments[index].environment,
                            avgDuration: environments[index].avgDuration,
                            sessionCount: environments[index].sessionCount,
                            maxDuration: environments.first?.avgDuration ?? 1
                        )

                        if index < environments.count - 1 {
                            Divider()
                                .background(AppColors.textTertiary.opacity(0.3))
                        }
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }
}

struct EnvironmentBarRow: View {
    let environment: FocusEnvironment
    let avgDuration: TimeInterval
    let sessionCount: Int
    let maxDuration: TimeInterval

    var percentage: CGFloat {
        CGFloat(avgDuration / maxDuration)
    }

    var durationFormatted: String {
        let minutes = Int(avgDuration / 60)
        return "\(minutes)m avg"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: environment.icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.healthy)
                    .frame(width: 20)

                Text(environment.displayName)
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(durationFormatted)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textSecondary)

                Text("(\(sessionCount))")
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textTertiary)
            }

            // Bar chart
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.lightSoil)
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(AppColors.healthy)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Time of Day Breakdown
struct TimeOfDayBreakdownView: View {
    let timeSlots: [(time: TimeOfDay, avgDuration: TimeInterval, sessionCount: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Focus by Time of Day")
                .font(AppFont.heading2())
                .foregroundColor(AppColors.textPrimary)

            CardView {
                VStack(spacing: Spacing.md) {
                    ForEach(timeSlots.indices, id: \.self) { index in
                        TimeOfDayBarRow(
                            time: timeSlots[index].time,
                            avgDuration: timeSlots[index].avgDuration,
                            sessionCount: timeSlots[index].sessionCount,
                            maxDuration: timeSlots.first?.avgDuration ?? 1
                        )

                        if index < timeSlots.count - 1 {
                            Divider()
                                .background(AppColors.textTertiary.opacity(0.3))
                        }
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }
}

struct TimeOfDayBarRow: View {
    let time: TimeOfDay
    let avgDuration: TimeInterval
    let sessionCount: Int
    let maxDuration: TimeInterval

    var percentage: CGFloat {
        CGFloat(avgDuration / maxDuration)
    }

    var durationFormatted: String {
        let minutes = Int(avgDuration / 60)
        return "\(minutes)m avg"
    }

    var timeIcon: String {
        switch time {
        case .earlyMorning: return "sunrise.fill"
        case .morning: return "sun.and.horizon"
        case .midday: return "sun.max.fill"
        case .afternoon: return "sun.haze"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        case .lateNight: return "moon.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: timeIcon)
                    .font(.system(size: 16))
                    .foregroundColor(Color.orange)
                    .frame(width: 20)

                Text(time.rawValue.capitalized)
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(durationFormatted)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textSecondary)

                Text("(\(sessionCount))")
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textTertiary)
            }

            // Bar chart
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.lightSoil)
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Garden Distribution
struct GardenDistributionView: View {
    let gardens: [(garden: Garden, focusTime: TimeInterval, sessionCount: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Focus by Garden")
                .font(AppFont.heading2())
                .foregroundColor(AppColors.textPrimary)

            CardView {
                VStack(spacing: Spacing.md) {
                    ForEach(gardens.indices, id: \.self) { index in
                        GardenBarRow(
                            garden: gardens[index].garden,
                            focusTime: gardens[index].focusTime,
                            sessionCount: gardens[index].sessionCount,
                            maxTime: gardens.first?.focusTime ?? 1
                        )

                        if index < gardens.count - 1 {
                            Divider()
                                .background(AppColors.textTertiary.opacity(0.3))
                        }
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }
}

struct GardenBarRow: View {
    let garden: Garden
    let focusTime: TimeInterval
    let sessionCount: Int
    let maxTime: TimeInterval

    var percentage: CGFloat {
        CGFloat(focusTime / maxTime)
    }

    var timeFormatted: String {
        let hours = Int(focusTime / 3600)
        let minutes = Int((focusTime.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(garden.icon)
                    .font(.system(size: 20))
                    .frame(width: 24)

                Text(garden.name)
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(timeFormatted)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textSecondary)

                Text("(\(sessionCount))")
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textTertiary)
            }

            // Bar chart
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.lightSoil)
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(AppColors.thriving)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Empty State
struct EmptyAnalyticsView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Text("📊")
                .font(.system(size: 60))

            Text("No Analytics Yet")
                .font(AppFont.heading2())
                .foregroundColor(AppColors.textPrimary)

            Text("Complete at least 3 focus sessions to see your analytics and insights!")
                .font(AppFont.body())
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)

            Spacer()
        }
    }
}

// MARK: - AI Insight Card
struct AIInsightCardView: View {
    @ObservedObject var viewModel: AnalyticsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("AI Insight")
                    .font(AppFont.heading3())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if viewModel.aiInsightLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let insight = viewModel.aiInsight {
                Text(insight)
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

            } else if viewModel.aiInsightError != nil {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Using pattern-based insights")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                }

            } else if viewModel.sessions.count < 5 {
                Text("Complete 5+ sessions to unlock AI-powered insights!")
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.lightSoil)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
