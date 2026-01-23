import SwiftUI

// MARK: - Flow Heatmap View

struct FlowHeatmapView: View {
    let userId: String?
    let userName: String?
    let onPhilosophyTap: (PhilosophyMoment) -> Void

    @StateObject private var dataService = HeatmapDataService.shared
    @State private var selectedDay: HeatmapDayData?
    @State private var showingDayDetail = false
    @State private var scrollOffset: CGFloat = 0

    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3
    private let weekDayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            headerView

            if dataService.isLoading {
                loadingView
            } else if let error = dataService.error {
                errorView(error)
            } else {
                // Stats card
                if let stats = dataService.stats {
                    HeatmapStatsCard(stats: stats)
                }

                // Heatmap grid
                heatmapGrid

                // Legend
                HeatmapLegend(
                    onPhilosophyTap: {
                        onPhilosophyTap(PhilosophyMomentsLibrary.skillsNotHours)
                    },
                    cellSize: cellSize
                )
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .sheet(isPresented: $showingDayDetail) {
            if let day = selectedDay {
                dayDetailSheet(day)
            }
        }
        .task {
            await dataService.fetchHeatmapData(for: userId)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.sm) {
                    Text(userName != nil ? "\(userName!)'s Flow Activity" : "Your Flow Activity")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    PhilosophyButton {
                        onPhilosophyTap(PhilosophyMomentsLibrary.skillsNotHours)
                    }
                }

                Text("Flow quality over the past year")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()

            // Refresh button
            Button(action: {
                Task {
                    await dataService.fetchHeatmapData(for: userId)
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
    }

    // MARK: - Heatmap Grid

    private var heatmapGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Month labels
            monthLabelsRow

            // Main grid with weekday labels
            HStack(alignment: .top, spacing: Spacing.sm) {
                // Weekday labels
                weekdayLabelsColumn

                // Scrollable heatmap
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        LazyHStack(alignment: .top, spacing: cellSpacing) {
                            ForEach(allWeeks) { week in
                                weekColumn(week)
                                    .id(week.id)
                            }
                        }
                        .padding(.trailing, Spacing.md)
                        .onAppear {
                            // Scroll to the end (most recent)
                            if let lastWeek = allWeeks.last {
                                proxy.scrollTo(lastWeek.id, anchor: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Month Labels Row

    private var monthLabelsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Spacer for weekday labels
                Color.clear
                    .frame(width: 20)

                ForEach(dataService.months) { month in
                    Text(month.shortName)
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                        .frame(width: calculateMonthWidth(month), alignment: .leading)
                }
            }
        }
    }

    private func calculateMonthWidth(_ month: HeatmapMonth) -> CGFloat {
        let weekCount = CGFloat(month.weeks.count)
        return weekCount * (cellSize + cellSpacing)
    }

    // MARK: - Weekday Labels

    private var weekdayLabelsColumn: some View {
        VStack(spacing: cellSpacing) {
            ForEach(Array(weekDayLabels.enumerated()), id: \.offset) { index, label in
                Text(index % 2 == 1 ? label : "")
                    .font(.system(size: 9))
                    .foregroundColor(OnLifeColors.textMuted)
                    .frame(width: 16, height: cellSize)
            }
        }
    }

    // MARK: - Week Column

    private func weekColumn(_ week: HeatmapWeek) -> some View {
        VStack(spacing: cellSpacing) {
            // Pad to align with weekday (start on correct day)
            if let firstDay = week.days.first {
                ForEach(0..<firstDay.date.dayOfWeek, id: \.self) { _ in
                    Color.clear
                        .frame(width: cellSize, height: cellSize)
                }
            }

            // Days
            ForEach(week.days) { day in
                HeatmapDayCell(
                    dayData: day,
                    cellSize: cellSize,
                    onTap: {
                        selectedDay = day
                        showingDayDetail = true
                        HapticManager.shared.impact(style: .light)
                    }
                )
            }

            // Pad remaining days
            if let lastDay = week.days.last {
                let remaining = 6 - lastDay.date.dayOfWeek
                ForEach(0..<remaining, id: \.self) { _ in
                    Color.clear
                        .frame(width: cellSize, height: cellSize)
                }
            }
        }
    }

    // MARK: - All Weeks

    private var allWeeks: [HeatmapWeek] {
        dataService.months.flatMap { $0.weeks }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.socialTeal))

            Text("Loading flow history...")
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }

    // MARK: - Error View

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(OnLifeColors.warning)

            Text("Couldn't load heatmap")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)

            Text(error.localizedDescription)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .multilineTextAlignment(.center)

            Button(action: {
                Task {
                    await dataService.fetchHeatmapData(for: userId)
                }
            }) {
                Text("Retry")
                    .font(OnLifeFont.button())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(OnLifeColors.socialTeal)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
    }

    // MARK: - Day Detail Sheet

    private func dayDetailSheet(_ day: HeatmapDayData) -> some View {
        VStack(spacing: 0) {
            HeatmapDayDetailPopover(
                dayData: day,
                onDismiss: { showingDayDetail = false }
            )
            .padding()

            Spacer()

            // Philosophy hint
            Button(action: {
                showingDayDetail = false
                onPhilosophyTap(PhilosophyMomentsLibrary.skillsNotHours)
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(OnLifeColors.amber)

                    Text("Why we measure flow, not just time")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(OnLifeColors.amber.opacity(0.1))
                )
            }
            .padding()
        }
        .background(OnLifeColors.deepForest.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}

// MARK: - Compact Heatmap View (for profiles)

struct FlowHeatmapCompact: View {
    let userId: String?
    let weeksToShow: Int

    @StateObject private var dataService = HeatmapDataService.shared

    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Mini grid
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(recentWeeks) { week in
                    VStack(spacing: cellSpacing) {
                        ForEach(week.days) { day in
                            HeatmapDayCellCompact(intensity: day.intensityLevel, size: cellSize)
                        }
                    }
                }
            }

            // Compact legend
            HeatmapLegendCompact(cellSize: cellSize)
        }
        .task {
            if dataService.months.isEmpty {
                await dataService.fetchHeatmapData(for: userId, monthsBack: 3)
            }
        }
    }

    private var recentWeeks: [HeatmapWeek] {
        let allWeeks = dataService.months.flatMap { $0.weeks }
        return Array(allWeeks.suffix(weeksToShow))
    }
}

// MARK: - Heatmap Year View

struct FlowHeatmapYearView: View {
    let userId: String?
    let onPhilosophyTap: (PhilosophyMoment) -> Void

    @StateObject private var dataService = HeatmapDataService.shared
    @State private var selectedMonth: HeatmapMonth?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Year summary
                if let stats = dataService.stats {
                    yearSummaryCard(stats)
                }

                // Month-by-month breakdown
                ForEach(dataService.months.reversed()) { month in
                    monthCard(month)
                }
            }
            .padding(Spacing.lg)
        }
        .background(OnLifeColors.deepForest.ignoresSafeArea())
        .navigationTitle("Flow History")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await dataService.fetchHeatmapData(for: userId)
        }
    }

    // MARK: - Year Summary

    private func yearSummaryCard(_ stats: HeatmapStats) -> some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Year in Review")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                PhilosophyButton {
                    onPhilosophyTap(PhilosophyMomentsLibrary.skillsNotHours)
                }
            }

            // Big stats
            HStack(spacing: Spacing.xl) {
                bigStatItem(
                    value: "\(stats.flowDays)",
                    label: "Flow Days",
                    color: OnLifeColors.socialTeal
                )

                bigStatItem(
                    value: "\(stats.longestStreak)",
                    label: "Best Streak",
                    color: OnLifeColors.amber
                )

                if let avgQuality = stats.averageFlowQuality {
                    bigStatItem(
                        value: "\(Int(avgQuality * 100))%",
                        label: "Avg Quality",
                        color: OnLifeColors.healthy
                    )
                }
            }

            // Flow rate bar
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("Flow Rate")
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.textTertiary)

                    Spacer()

                    Text("\(Int(stats.flowRate * 100))% of sessions achieved flow")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(OnLifeColors.cardBackgroundElevated)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [OnLifeColors.socialTeal.opacity(0.6), OnLifeColors.socialTeal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * stats.flowRate)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func bigStatItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(OnLifeFont.heading1())
                .foregroundColor(color)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Month Card

    private func monthCard(_ month: HeatmapMonth) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Month header
            HStack {
                Text(month.displayName)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                HStack(spacing: Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))

                    Text("\(month.totalFlowDays) flow days")
                        .font(OnLifeFont.label())
                }
                .foregroundColor(OnLifeColors.socialTeal)
            }

            // Mini heatmap for month
            monthMiniHeatmap(month)

            // Month stats
            HStack(spacing: Spacing.lg) {
                monthStat(label: "Sessions", value: "\(month.totalSessionDays)")

                if let avgQuality = month.averageFlowQuality {
                    monthStat(label: "Avg Quality", value: "\(Int(avgQuality * 100))%")
                }

                Spacer()
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func monthMiniHeatmap(_ month: HeatmapMonth) -> some View {
        let allDays = month.weeks.flatMap { $0.days }
        let rows = 7
        let cols = (allDays.count + rows - 1) / rows

        return LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(12), spacing: 2), count: cols),
            spacing: 2
        ) {
            ForEach(allDays) { day in
                HeatmapDayCellCompact(intensity: day.intensityLevel, size: 12)
            }
        }
    }

    private func monthStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textMuted)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FlowHeatmapView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Main heatmap
                FlowHeatmapView(
                    userId: nil,
                    userName: nil,
                    onPhilosophyTap: { _ in }
                )

                // Compact version
                FlowHeatmapCompact(userId: nil, weeksToShow: 12)
                    .padding()
                    .background(OnLifeColors.cardBackground)
                    .cornerRadius(CornerRadius.card)
            }
            .padding()
        }
        .background(OnLifeColors.deepForest)
        .preferredColorScheme(.dark)
    }
}
#endif
