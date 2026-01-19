import SwiftUI

/// Comprehensive stats dashboard with weekly/monthly insights
struct WeeklyStatsView: View {
    @StateObject private var viewModel = SessionAnalyticsViewModel()
    @State private var contentAppeared = false
    let sessions: [FocusSession]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                // Period selector
                periodSelector
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 10)

                if let stats = viewModel.stats {
                    // Main stats grid
                    statsGrid(stats: stats)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 10)
                        .animation(OnLifeAnimation.elegant.delay(0.05), value: contentAppeared)

                    // Streaks section
                    streaksCard(stats: stats)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 10)
                        .animation(OnLifeAnimation.elegant.delay(0.1), value: contentAppeared)

                    // Best times section
                    bestTimesCard(stats: stats)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 10)
                        .animation(OnLifeAnimation.elegant.delay(0.15), value: contentAppeared)

                    // Day of week heatmap
                    if !stats.dayOfWeekDistribution.isEmpty {
                        DayOfWeekHeatmap(distribution: stats.dayOfWeekDistribution)
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 10)
                            .animation(OnLifeAnimation.elegant.delay(0.2), value: contentAppeared)
                    }

                    // Time of day heatmap
                    if !stats.timeOfDayDistribution.isEmpty {
                        TimeOfDayHeatmap(distribution: stats.timeOfDayDistribution)
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 10)
                            .animation(OnLifeAnimation.elegant.delay(0.25), value: contentAppeared)
                    }

                } else if viewModel.isLoading {
                    loadingState
                } else {
                    emptyState
                        .opacity(contentAppeared ? 1 : 0)
                        .animation(OnLifeAnimation.elegant.delay(0.1), value: contentAppeared)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
        .onAppear {
            viewModel.calculateStats(from: sessions)
            withAnimation(OnLifeAnimation.elegant) {
                contentAppeared = true
            }
        }
        .onChange(of: viewModel.selectedPeriod) { _, _ in
            viewModel.calculateStats(from: sessions)
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(SessionAnalyticsViewModel.AnalyticsPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Stats Grid

    private func statsGrid(stats: SessionStats) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Spacing.md),
            GridItem(.flexible(), spacing: Spacing.md)
        ], spacing: Spacing.md) {
            StatsCard(
                icon: "checkmark.circle.fill",
                title: "Sessions",
                value: "\(stats.completedSessions)",
                subtitle: "\(stats.totalSessions) started",
                color: OnLifeColors.sage
            )

            StatsCard(
                icon: "clock.fill",
                title: "Focus Time",
                value: formatMinutes(stats.totalMinutes),
                subtitle: "Total focused",
                color: .purple
            )

            StatsCard(
                icon: "percent",
                title: "Completion",
                value: stats.completionRatePercentage,
                subtitle: "Success rate",
                color: stats.completionRate >= 0.7 ? .green : OnLifeColors.amber
            )

            StatsCard(
                icon: "chart.line.uptrend.xyaxis",
                title: "Avg Flow",
                value: stats.averageFlowScoreFormatted,
                subtitle: "Out of 100",
                color: flowScoreColor(stats.averageFlowScore)
            )

            StatsCard(
                icon: "hourglass",
                title: "Avg Session",
                value: "\(stats.averageSessionLength)m",
                subtitle: "Per session",
                color: .cyan
            )

            StatsCard(
                icon: "calendar",
                title: "Active Days",
                value: "\(stats.activeDays)",
                subtitle: "With sessions",
                color: .indigo
            )
        }
    }

    // MARK: - Streaks Card

    private func streaksCard(stats: SessionStats) -> some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(OnLifeColors.amber)
                Text("Streaks")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
                Spacer()
            }

            HStack(spacing: Spacing.md) {
                VStack(spacing: Spacing.xs) {
                    Text("\(stats.currentStreak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(OnLifeColors.amber)
                    Text("Current")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                    Text("days")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(OnLifeColors.amber.opacity(0.15))
                )

                VStack(spacing: Spacing.xs) {
                    Text("\(stats.longestStreak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(OnLifeColors.sage)
                    Text("Longest")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                    Text("days")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(OnLifeColors.sage.opacity(0.15))
                )
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Best Times Card

    private func bestTimesCard(stats: SessionStats) -> some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Your Peak Performance")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
                Spacer()
            }

            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                        Text("Best Day")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                    Text(stats.bestDayOfWeek)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(OnLifeColors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(Color.yellow.opacity(0.1))
                )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        Text("Best Hour")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                    Text(formatHour(stats.bestHourOfDay))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(OnLifeColors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Calculating stats...")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(OnLifeColors.textTertiary)

            Text("No Stats Yet")
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)

            Text("Complete some focus sessions to see your productivity patterns and insights.")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    private func flowScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return OnLifeColors.sage
        case 40..<60: return OnLifeColors.amber
        default: return OnLifeColors.terracotta
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        WeeklyStatsView(sessions: [])
    }
}
