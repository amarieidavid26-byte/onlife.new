import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var appeared = false

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

                        // AI Insight Card
                        AIInsightCardView(viewModel: viewModel)
                            .padding(.horizontal, Spacing.lg)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)

                        // Smart Insights Section
                        if !viewModel.insights.isEmpty {
                            InsightsSection(insights: viewModel.insights, appeared: appeared)
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
            viewModel.loadData()
            withAnimation(OnLifeAnimation.elegant) {
                appeared = true
            }
        }
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
    @State private var isPressed = false
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
        .scaleEffect(isPressed ? 0.97 : (cardAppeared ? 1.0 : 0.9))
        .opacity(cardAppeared ? 1 : 0)
        .onAppear {
            withAnimation(OnLifeAnimation.standard.delay(delay)) {
                cardAppeared = true
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = false }
                }
        )
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
    @State private var isPressed = false

    var iconBackgroundColor: Color {
        switch insight.type {
        case .positive:
            return OnLifeColors.sage.opacity(0.2)
        case .suggestion:
            return OnLifeColors.amber.opacity(0.2)
        case .warning:
            return OnLifeColors.terracotta.opacity(0.2)
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
        .scaleEffect(isPressed ? 0.98 : (cardAppeared ? 1.0 : 0.95))
        .opacity(cardAppeared ? 1 : 0)
        .onAppear {
            withAnimation(OnLifeAnimation.standard.delay(delay)) {
                cardAppeared = true
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(OnLifeAnimation.quick) { isPressed = false }
                }
        )
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
        CGFloat(avgDuration / maxDuration)
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
                    withAnimation(OnLifeAnimation.growth.delay(animationDelay)) {
                        barWidth = geometry.size.width * percentage
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
        CGFloat(avgDuration / maxDuration)
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
                    withAnimation(OnLifeAnimation.growth.delay(animationDelay)) {
                        barWidth = geometry.size.width * percentage
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
                    withAnimation(OnLifeAnimation.growth.delay(animationDelay)) {
                        barWidth = geometry.size.width * percentage
                    }
                }
            }
            .frame(height: 8)
        }
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
                .scaleEffect(bouncing ? 1.1 : 1.0)
                .animation(
                    .spring(duration: 0.6, bounce: 0.4)
                    .repeatForever(autoreverses: true),
                    value: bouncing
                )
                .onAppear {
                    bouncing = true
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
}
