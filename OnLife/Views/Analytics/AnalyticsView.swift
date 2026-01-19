import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var appeared = false
    @State private var peakWindows: [PerformanceAnalyzer.PerformanceWindow] = []
    @State private var chronotypeAlignment: ChronotypeAlignment?
    @State private var completionPattern: CompletionPattern?
    @State private var earlyQuitAnalysis: EarlyQuitAnalysis?

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [OnLifeColors.deepForest, OnLifeColors.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if viewModel.sessions.count < 3 {
                EmptyAnalyticsView()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Header
                        Text("Your Progress")
                            .font(OnLifeFont.display())
                            .foregroundColor(OnLifeColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.lg)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -10)

                        // Stats Grid
                        StatsGridView(viewModel: viewModel, appeared: appeared)
                            .padding(.horizontal, Spacing.lg)

                        // Flow Score History Chart
                        FlowScoreChartView(sessions: viewModel.sessions)
                            .padding(.horizontal, Spacing.lg)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(OnLifeAnimation.elegant.delay(0.08), value: appeared)

                        // Weekly Stats Dashboard
                        WeeklyStatsSummary(sessions: viewModel.sessions, appeared: appeared)
                            .padding(.horizontal, Spacing.lg)

                        // AI Insight Card
                        AIInsightCardView(viewModel: viewModel)
                            .padding(.horizontal, Spacing.lg)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)

                        // Peak Performance Windows
                        PeakPerformanceCard(
                            windows: peakWindows,
                            alignment: chronotypeAlignment
                        )
                        .padding(.horizontal, Spacing.lg)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(OnLifeAnimation.elegant.delay(0.12), value: appeared)

                        // Completion Pattern Analysis
                        CompletionPatternCard(
                            pattern: completionPattern,
                            earlyQuitAnalysis: earlyQuitAnalysis,
                            appeared: appeared
                        )
                        .padding(.horizontal, Spacing.lg)

                        // Smart Insights Section
                        if !viewModel.cachedInsights.isEmpty {
                            InsightsSection(insights: viewModel.cachedInsights, appeared: appeared)
                                .padding(.horizontal, Spacing.lg)
                        }

                        // Environment Breakdown
                        if !viewModel.environmentBreakdown.isEmpty {
                            EnvironmentBreakdownView(
                                environments: viewModel.environmentBreakdown,
                                appeared: appeared
                            )
                            .padding(.horizontal, Spacing.lg)
                        }

                        // Time of Day Breakdown
                        if !viewModel.timeOfDayBreakdown.isEmpty {
                            TimeOfDayBreakdownView(
                                timeSlots: viewModel.timeOfDayBreakdown,
                                appeared: appeared
                            )
                            .padding(.horizontal, Spacing.lg)
                        }

                        // Garden Distribution
                        if !viewModel.gardenBreakdown.isEmpty {
                            GardenDistributionView(
                                gardens: viewModel.gardenBreakdown,
                                appeared: appeared
                            )
                            .padding(.horizontal, Spacing.lg)
                        }

                        Spacer(minLength: Spacing.xxl)
                    }
                    .padding(.top, Spacing.lg)
                }
                .refreshable {
                    Haptics.light()
                    viewModel.loadData()
                }
                .task {
                    #if DEBUG
                    await viewModel.testAIInsight()
                    #else
                    await viewModel.generateAIInsight()
                    #endif
                }
            }
        }
        .onAppear {
            // Note: loadData() is already called in ViewModel init(), no need to call again
            withAnimation(OnLifeAnimation.elegant) {
                appeared = true
            }
            analyzePeakPerformance()
            analyzeCompletionPatterns()
        }
    }

    // MARK: - Peak Performance Analysis

    private func analyzePeakPerformance() {
        peakWindows = PerformanceAnalyzer.shared.identifyPeakWindows(
            sessions: viewModel.sessions
        )

        // Get stored chronotype and compare
        if let chronotypeResult = ChronotypeInferenceEngine.shared.storedResult {
            chronotypeAlignment = PerformanceAnalyzer.shared.compareToChronotype(
                peakWindows: peakWindows,
                chronotype: chronotypeResult.chronotype
            )
        }
    }

    // MARK: - Completion Pattern Analysis

    private func analyzeCompletionPatterns() {
        completionPattern = CompletionPatternAnalyzer.shared.analyzeCompletionPatterns(
            sessions: viewModel.sessions
        )

        earlyQuitAnalysis = CompletionPatternAnalyzer.shared.identifyEarlyQuitPattern(
            sessions: viewModel.sessions
        )
    }
}

// MARK: - Stats Grid

struct StatsGridView: View {
    let viewModel: AnalyticsViewModel
    let appeared: Bool

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)],
            spacing: Spacing.md
        ) {
            AnalyticsStatCard(
                icon: "flame.fill",
                value: "\(viewModel.totalSessions)",
                label: "Total Sessions",
                delay: 0.0,
                appeared: appeared
            )

            AnalyticsStatCard(
                icon: "clock.fill",
                value: viewModel.totalFocusTimeFormatted,
                label: "Total Focus",
                delay: 0.05,
                appeared: appeared
            )

            AnalyticsStatCard(
                icon: "chart.line.uptrend.xyaxis",
                value: viewModel.averageSessionFormatted,
                label: "Avg Session",
                delay: 0.1,
                appeared: appeared
            )

            AnalyticsStatCard(
                icon: "star.fill",
                value: viewModel.longestSessionFormatted,
                label: "Longest Session",
                delay: 0.15,
                appeared: appeared
            )
        }
    }
}

struct AnalyticsStatCard: View {
    let icon: String
    let value: String
    let label: String
    let delay: Double
    let appeared: Bool
    @State private var cardAppeared = false

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(OnLifeColors.sage)

            Text(value)
                .font(OnLifeFont.heading1())
                .foregroundColor(OnLifeColors.textPrimary)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .shadow(
            color: Color.black.opacity(0.15),
            radius: 8,
            y: 4
        )
        .scaleEffect(cardAppeared ? 1.0 : 0.9)
        .opacity(cardAppeared ? 1 : 0)
        .onAppear {
            withAnimation(OnLifeAnimation.standard.delay(delay)) {
                cardAppeared = true
            }
        }
    }
}

// MARK: - AI Insight Card

struct AIInsightCardView: View {
    @ObservedObject var viewModel: AnalyticsViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(OnLifeColors.amber)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(OnLifeColors.amber)

                    Text("AI Insight")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Spacer()

                    if viewModel.aiInsightLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(OnLifeColors.sage)
                    }
                }

                if let insight = viewModel.aiInsight {
                    Text(insight)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                } else if viewModel.aiInsightError != nil {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(OnLifeColors.terracotta)
                            .font(.caption)
                        Text("Using pattern-based insights")
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }

                } else if viewModel.sessions.count < 5 {
                    Text("Complete 5+ sessions to unlock AI-powered insights!")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }
            .padding(Spacing.lg)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackgroundElevated)
        )
        .shadow(
            color: OnLifeColors.amber.opacity(0.15),
            radius: 12,
            y: 4
        )
    }
}

// MARK: - Insights Section

struct InsightsSection: View {
    let insights: [Insight]
    let appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Smart Insights")
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(.top, Spacing.md)

            ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                InsightCard(insight: insight, delay: Double(index) * 0.05, appeared: appeared)
            }
        }
    }
}

struct InsightCard: View {
    let insight: Insight
    let delay: Double
    let appeared: Bool
    @State private var cardAppeared = false

    var iconBackgroundColor: Color {
        switch insight.type {
        case .positive:
            return OnLifeColors.sage.opacity(0.2)
        case .suggestion:
            return OnLifeColors.amber.opacity(0.2)
        case .warning:
            return OnLifeColors.terracotta.opacity(0.2)
        case .neutral:
            return OnLifeColors.textTertiary.opacity(0.2)
        }
    }

    var iconColor: Color {
        switch insight.type {
        case .positive:
            return OnLifeColors.sage
        case .suggestion:
            return OnLifeColors.amber
        case .warning:
            return OnLifeColors.terracotta
        case .neutral:
            return OnLifeColors.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 44, height: 44)

                Image(systemName: insight.icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(insight.title)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(insight.description)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .scaleEffect(cardAppeared ? 1.0 : 0.95)
        .opacity(cardAppeared ? 1 : 0)
        .onAppear {
            withAnimation(OnLifeAnimation.standard.delay(delay)) {
                cardAppeared = true
            }
        }
    }
}

// MARK: - Environment Breakdown

struct EnvironmentBreakdownView: View {
    let environments: [(environment: FocusEnvironment, avgDuration: TimeInterval, sessionCount: Int)]
    let appeared: Bool
    @State private var cardAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Focus by Environment")
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(.top, Spacing.md)

            VStack(spacing: Spacing.md) {
                ForEach(environments.indices, id: \.self) { index in
                    EnvironmentBarRow(
                        environment: environments[index].environment,
                        avgDuration: environments[index].avgDuration,
                        sessionCount: environments[index].sessionCount,
                        maxDuration: environments.first?.avgDuration ?? 1,
                        animationDelay: Double(index) * 0.1,
                        appeared: cardAppeared
                    )

                    if index < environments.count - 1 {
                        Divider()
                            .background(OnLifeColors.textTertiary.opacity(0.2))
                    }
                }
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
            .opacity(cardAppeared ? 1 : 0)
            .offset(y: cardAppeared ? 0 : 20)
            .onAppear {
                withAnimation(OnLifeAnimation.elegant.delay(0.2)) {
                    cardAppeared = true
                }
            }
        }
    }
}

struct EnvironmentBarRow: View {
    let environment: FocusEnvironment
    let avgDuration: TimeInterval
    let sessionCount: Int
    let maxDuration: TimeInterval
    let animationDelay: Double
    let appeared: Bool
    @State private var barWidth: CGFloat = 0

    var percentage: CGFloat {
        guard maxDuration > 0 else { return 0 }
        let ratio = CGFloat(avgDuration / maxDuration)
        return ratio.isNaN || ratio.isInfinite ? 0 : min(ratio, 1.0)
    }

    var durationFormatted: String {
        let minutes = Int(avgDuration / 60)
        return "\(minutes)m avg"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(environment.icon)
                    .font(.system(size: 20))
                    .frame(width: 24)

                Text(environment.displayName)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                Text(durationFormatted)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)

                Text("(\(sessionCount))")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.surface)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.sage)
                        .frame(width: barWidth, height: 8)
                }
                .onAppear {
                    let targetWidth = geometry.size.width * percentage
                    let safeWidth = targetWidth.isNaN || targetWidth.isInfinite ? 0 : max(0, targetWidth)
                    withAnimation(OnLifeAnimation.growth.delay(animationDelay)) {
                        barWidth = safeWidth
                    }
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Time of Day Breakdown

struct TimeOfDayBreakdownView: View {
    let timeSlots: [(time: TimeOfDay, avgDuration: TimeInterval, sessionCount: Int)]
    let appeared: Bool
    @State private var cardAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Focus by Time of Day")
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(.top, Spacing.md)

            VStack(spacing: Spacing.md) {
                ForEach(timeSlots.indices, id: \.self) { index in
                    TimeOfDayBarRow(
                        time: timeSlots[index].time,
                        avgDuration: timeSlots[index].avgDuration,
                        sessionCount: timeSlots[index].sessionCount,
                        maxDuration: timeSlots.first?.avgDuration ?? 1,
                        animationDelay: Double(index) * 0.1,
                        appeared: cardAppeared
                    )

                    if index < timeSlots.count - 1 {
                        Divider()
                            .background(OnLifeColors.textTertiary.opacity(0.2))
                    }
                }
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
            .opacity(cardAppeared ? 1 : 0)
            .offset(y: cardAppeared ? 0 : 20)
            .onAppear {
                withAnimation(OnLifeAnimation.elegant.delay(0.3)) {
                    cardAppeared = true
                }
            }
        }
    }
}

struct TimeOfDayBarRow: View {
    let time: TimeOfDay
    let avgDuration: TimeInterval
    let sessionCount: Int
    let maxDuration: TimeInterval
    let animationDelay: Double
    let appeared: Bool
    @State private var barWidth: CGFloat = 0

    var percentage: CGFloat {
        guard maxDuration > 0 else { return 0 }
        let ratio = CGFloat(avgDuration / maxDuration)
        return ratio.isNaN || ratio.isInfinite ? 0 : min(ratio, 1.0)
    }

    var durationFormatted: String {
        let minutes = Int(avgDuration / 60)
        return "\(minutes)m avg"
    }

    var timeEmoji: String {
        switch time {
        case .earlyMorning: return "🌅"
        case .morning: return "☀️"
        case .midday: return "🌤️"
        case .afternoon: return "⛅"
        case .evening: return "🌅"
        case .night: return "🌙"
        case .lateNight: return "🌑"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(timeEmoji)
                    .font(.system(size: 20))
                    .frame(width: 24)

                Text(time.rawValue.capitalized)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                Text(durationFormatted)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)

                Text("(\(sessionCount))")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.surface)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.sage)
                        .frame(width: barWidth, height: 8)
                }
                .onAppear {
                    let targetWidth = geometry.size.width * percentage
                    let safeWidth = targetWidth.isNaN || targetWidth.isInfinite ? 0 : max(0, targetWidth)
                    withAnimation(OnLifeAnimation.growth.delay(animationDelay)) {
                        barWidth = safeWidth
                    }
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Garden Distribution

struct GardenDistributionView: View {
    let gardens: [(garden: Garden, focusTime: TimeInterval, sessionCount: Int)]
    let appeared: Bool
    @State private var cardAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Focus by Garden")
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(.top, Spacing.md)

            VStack(spacing: Spacing.md) {
                ForEach(gardens.indices, id: \.self) { index in
                    GardenBarRow(
                        garden: gardens[index].garden,
                        focusTime: gardens[index].focusTime,
                        sessionCount: gardens[index].sessionCount,
                        maxTime: gardens.first?.focusTime ?? 1,
                        animationDelay: Double(index) * 0.1,
                        appeared: cardAppeared
                    )

                    if index < gardens.count - 1 {
                        Divider()
                            .background(OnLifeColors.textTertiary.opacity(0.2))
                    }
                }
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
            .opacity(cardAppeared ? 1 : 0)
            .offset(y: cardAppeared ? 0 : 20)
            .onAppear {
                withAnimation(OnLifeAnimation.elegant.delay(0.4)) {
                    cardAppeared = true
                }
            }
        }
    }
}

struct GardenBarRow: View {
    let garden: Garden
    let focusTime: TimeInterval
    let sessionCount: Int
    let maxTime: TimeInterval
    let animationDelay: Double
    let appeared: Bool
    @State private var barWidth: CGFloat = 0

    var percentage: CGFloat {
        guard maxTime > 0 else { return 0 }
        let ratio = CGFloat(focusTime / maxTime)
        return ratio.isNaN || ratio.isInfinite ? 0 : min(ratio, 1.0)
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(garden.icon)
                    .font(.system(size: 20))
                    .frame(width: 24)

                Text(garden.name)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                Text(timeFormatted)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)

                Text("(\(sessionCount))")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.surface)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnLifeColors.sage)
                        .frame(width: barWidth, height: 8)
                }
                .onAppear {
                    let targetWidth = geometry.size.width * percentage
                    let safeWidth = targetWidth.isNaN || targetWidth.isInfinite ? 0 : max(0, targetWidth)
                    withAnimation(OnLifeAnimation.growth.delay(animationDelay)) {
                        barWidth = safeWidth
                    }
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Weekly Stats Summary

struct WeeklyStatsSummary: View {
    @StateObject private var viewModel = SessionAnalyticsViewModel()
    let sessions: [FocusSession]
    let appeared: Bool
    @State private var sectionAppeared = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Header with period selector
            HStack {
                Text("Detailed Stats")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(SessionAnalyticsViewModel.AnalyticsPeriod.allCases, id: \.self) { period in
                        Text(periodShortLabel(period)).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .opacity(sectionAppeared ? 1 : 0)
            .offset(y: sectionAppeared ? 0 : 10)

            if let stats = viewModel.stats {
                // Streaks row
                HStack(spacing: Spacing.md) {
                    StreakMiniCard(
                        value: stats.currentStreak,
                        label: "Current Streak",
                        icon: "flame.fill",
                        color: OnLifeColors.amber
                    )

                    StreakMiniCard(
                        value: stats.longestStreak,
                        label: "Best Streak",
                        icon: "trophy.fill",
                        color: OnLifeColors.sage
                    )
                }
                .opacity(sectionAppeared ? 1 : 0)
                .offset(y: sectionAppeared ? 0 : 10)
                .animation(OnLifeAnimation.elegant.delay(0.05), value: sectionAppeared)

                // Best times row
                HStack(spacing: Spacing.md) {
                    BestTimeMiniCard(
                        value: stats.bestDayOfWeek,
                        label: "Best Day",
                        icon: "calendar",
                        color: .yellow
                    )

                    BestTimeMiniCard(
                        value: formatHour(stats.bestHourOfDay),
                        label: "Peak Hour",
                        icon: "clock.fill",
                        color: .green
                    )
                }
                .opacity(sectionAppeared ? 1 : 0)
                .offset(y: sectionAppeared ? 0 : 10)
                .animation(OnLifeAnimation.elegant.delay(0.1), value: sectionAppeared)

                // Completion & flow row
                HStack(spacing: Spacing.md) {
                    StatsCard(
                        icon: "percent",
                        title: "Completion",
                        value: stats.completionRatePercentage,
                        subtitle: "\(stats.completedSessions)/\(stats.totalSessions)",
                        color: stats.completionRate >= 0.7 ? .green : OnLifeColors.amber
                    )

                    StatsCard(
                        icon: "waveform.path.ecg",
                        title: "Avg Flow",
                        value: stats.averageFlowScoreFormatted,
                        subtitle: flowLabel(stats.averageFlowScore),
                        color: flowColor(stats.averageFlowScore)
                    )
                }
                .opacity(sectionAppeared ? 1 : 0)
                .offset(y: sectionAppeared ? 0 : 10)
                .animation(OnLifeAnimation.elegant.delay(0.15), value: sectionAppeared)

                // Day of week heatmap
                if !stats.dayOfWeekDistribution.isEmpty {
                    DayOfWeekHeatmap(distribution: stats.dayOfWeekDistribution)
                        .opacity(sectionAppeared ? 1 : 0)
                        .offset(y: sectionAppeared ? 0 : 10)
                        .animation(OnLifeAnimation.elegant.delay(0.2), value: sectionAppeared)
                }

                // Time of day heatmap
                if !stats.timeOfDayDistribution.isEmpty {
                    TimeOfDayHeatmap(distribution: stats.timeOfDayDistribution)
                        .opacity(sectionAppeared ? 1 : 0)
                        .offset(y: sectionAppeared ? 0 : 10)
                        .animation(OnLifeAnimation.elegant.delay(0.25), value: sectionAppeared)
                }
            }
        }
        .onAppear {
            viewModel.calculateStats(from: sessions)
            withAnimation(OnLifeAnimation.elegant.delay(0.1)) {
                sectionAppeared = true
            }
        }
        .onChange(of: viewModel.selectedPeriod) { _, _ in
            viewModel.calculateStats(from: sessions)
        }
    }

    private func periodShortLabel(_ period: SessionAnalyticsViewModel.AnalyticsPeriod) -> String {
        switch period {
        case .week: return "7d"
        case .month: return "30d"
        case .allTime: return "All"
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    private func flowColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return OnLifeColors.sage
        case 40..<60: return OnLifeColors.amber
        default: return OnLifeColors.terracotta
        }
    }

    private func flowLabel(_ score: Double) -> String {
        switch score {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Building"
        }
    }
}

// MARK: - Streak Mini Card

struct StreakMiniCard: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(OnLifeColors.textPrimary)
                Text(label)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }
}

// MARK: - Best Time Mini Card

struct BestTimeMiniCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(OnLifeColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(label)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }
}

// MARK: - Empty State

struct EmptyAnalyticsView: View {
    @State private var appeared = false
    @State private var bouncing = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Text("🌱")
                .font(.system(size: 72))
                .scaleEffect(bouncing ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 1.2),
                    value: bouncing
                )
                .onAppear {
                    startBounceAnimation()
                }
                .onDisappear {
                    bouncing = false
                }

            VStack(spacing: Spacing.sm) {
                Text("No Insights Yet")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Complete at least 3 focus sessions to see your analytics and insights!")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            Text("Start focusing to watch your garden grow")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .padding(.top, Spacing.md)

            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(OnLifeAnimation.elegant) {
                appeared = true
            }
        }
    }

    private func startBounceAnimation() {
        // Use a timer-based approach instead of repeatForever to avoid animation conflicts
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { timer in
            guard appeared else {
                timer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 1.2)) {
                bouncing.toggle()
            }
        }
        // Trigger initial bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 1.2)) {
                bouncing = true
            }
        }
    }
}
