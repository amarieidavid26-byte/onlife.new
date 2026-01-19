import SwiftUI
import Charts

/// Interactive chart showing flow score history over time
struct FlowScoreChartView: View {
    @StateObject private var historyManager = FlowScoreHistoryManager()
    @State private var selectedDataPoint: FlowScoreDataPoint?
    @State private var contentAppeared = false

    let sessions: [FocusSession]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Flow Performance")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    HStack(spacing: Spacing.sm) {
                        Image(systemName: historyManager.trend.icon)
                            .foregroundColor(historyManager.trend.color)
                        Text(historyManager.trend.label)
                            .font(OnLifeFont.caption())
                            .foregroundColor(historyManager.trend.color)
                    }
                }

                Spacer()

                // Average score badge
                if historyManager.averageScore > 0 {
                    VStack(spacing: 2) {
                        Text("\(Int(historyManager.averageScore))")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(historyManager.scoreCategory.color)
                        Text("avg")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                }
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 10)

            // Time range picker
            Picker("Time Range", selection: $historyManager.selectedTimeRange) {
                ForEach(FlowHistoryTimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: historyManager.selectedTimeRange) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    historyManager.fetchHistory(sessions: sessions)
                }
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 10)
            .animation(OnLifeAnimation.elegant.delay(0.05), value: contentAppeared)

            // Stats row
            HStack(spacing: Spacing.md) {
                FlowStatMiniCard(
                    value: "\(historyManager.totalSessions)",
                    label: "Sessions",
                    icon: "flame.fill",
                    color: OnLifeColors.amber
                )

                FlowStatMiniCard(
                    value: formatMinutes(historyManager.totalMinutes),
                    label: "Focus Time",
                    icon: "clock.fill",
                    color: OnLifeColors.sage
                )

                FlowStatMiniCard(
                    value: "\(historyManager.daysWithSessions)",
                    label: "Active Days",
                    icon: "calendar",
                    color: .purple
                )
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 10)
            .animation(OnLifeAnimation.elegant.delay(0.1), value: contentAppeared)

            // Chart
            if !historyManager.dataPoints.isEmpty && historyManager.totalSessions > 0 {
                flowChart
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(OnLifeAnimation.elegant.delay(0.15), value: contentAppeared)

                // Selected point details
                if let selected = selectedDataPoint, selected.sessionCount > 0 {
                    selectedPointDetails(selected)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            } else {
                emptyState
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(OnLifeAnimation.elegant.delay(0.15), value: contentAppeared)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .onAppear {
            historyManager.fetchHistory(sessions: sessions)
            withAnimation(OnLifeAnimation.elegant) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Flow Chart

    private var flowChart: some View {
        Chart {
            ForEach(historyManager.dataPoints) { point in
                // Area fill
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.sessionCount > 0 ? point.averageFlowScore : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [OnLifeColors.sage.opacity(0.4), OnLifeColors.sage.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                // Line
                if point.sessionCount > 0 {
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.averageFlowScore)
                    )
                    .foregroundStyle(OnLifeColors.sage)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    // Data point markers
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.averageFlowScore)
                    )
                    .foregroundStyle(point.scoreCategory.color)
                    .symbolSize(point == selectedDataPoint ? 100 : 40)
                }
            }

            // Selected point highlight
            if let selected = selectedDataPoint {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(OnLifeColors.textTertiary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .frame(height: 180)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: historyManager.selectedTimeRange.strideInterval)) { _ in
                AxisGridLine()
                    .foregroundStyle(OnLifeColors.surface)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(OnLifeColors.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                    .foregroundStyle(OnLifeColors.surface)
                AxisValueLabel()
                    .foregroundStyle(OnLifeColors.textTertiary)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelectedPoint(at: value.location, proxy: proxy, geometry: geometry)
                            }
                            .onEnded { _ in
                                // Keep selection visible for a moment
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedDataPoint = nil
                                    }
                                }
                            }
                    )
            }
        }
    }

    // MARK: - Selected Point Details

    private func selectedPointDetails(_ point: FlowScoreDataPoint) -> some View {
        HStack(spacing: Spacing.md) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(point.formattedDate)
                    .font(OnLifeFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("\(point.sessionCount) session\(point.sessionCount == 1 ? "" : "s")")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            Spacer()

            // Score
            HStack(spacing: Spacing.sm) {
                Text(point.scoreCategory.emoji)
                    .font(.system(size: 20))

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(point.averageFlowScore))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(point.scoreCategory.color)

                    Text(point.scoreCategory.label)
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            // Duration
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatMinutes(point.totalMinutes))
                    .font(OnLifeFont.body())
                    .fontWeight(.medium)
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("focus time")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.surface)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(OnLifeColors.textTertiary)

            Text("No flow data yet")
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            Text("Complete focus sessions to see your performance trends")
                .font(OnLifeFont.bodySmall())
                .foregroundColor(OnLifeColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    // MARK: - Helpers

    private func updateSelectedPoint(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let xPosition = location.x - geometry[proxy.plotAreaFrame].origin.x
        guard let date: Date = proxy.value(atX: xPosition) else { return }

        // Find closest data point with sessions
        let pointsWithData = historyManager.dataPoints.filter { $0.sessionCount > 0 }
        guard !pointsWithData.isEmpty else { return }

        let closest = pointsWithData.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })

        if closest != selectedDataPoint {
            Haptics.light()
            withAnimation(.easeOut(duration: 0.15)) {
                selectedDataPoint = closest
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Flow Stat Mini Card

struct FlowStatMiniCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)

                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        FlowScoreChartView(sessions: [])
            .padding()
    }
}
