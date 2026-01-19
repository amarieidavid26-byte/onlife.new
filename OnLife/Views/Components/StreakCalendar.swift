import SwiftUI

/// Visual calendar showing streak history over the last 30 days
/// Shows completed days, current streak, and freeze usage
struct StreakCalendar: View {
    @ObservedObject var streakManager = StreakManager.shared
    let sessions: [FocusSession]
    let days: Int

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(sessions: [FocusSession], days: Int = 30) {
        self.sessions = sessions
        self.days = days
    }

    private var completedDates: Set<Date> {
        streakManager.getCompletedDates(from: sessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                Text("Last \(days) Days")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                // Legend
                HStack(spacing: Spacing.md) {
                    legendItem(color: OnLifeColors.amber, label: "Completed")
                    legendItem(color: OnLifeColors.textTertiary.opacity(0.3), label: "Missed")
                }
            }

            // Day labels
            HStack(spacing: 4) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<days, id: \.self) { dayOffset in
                    let date = calendar.date(byAdding: .day, value: -(days - dayOffset - 1), to: Date()) ?? Date()
                    let isCompleted = streakManager.isDateCompleted(date, completedDates: completedDates)
                    let isToday = calendar.isDateInToday(date)
                    let isFuture = date > Date()

                    StreakDayCell(
                        date: date,
                        isCompleted: isCompleted,
                        isToday: isToday,
                        isFuture: isFuture
                    )
                }
            }

            // Stats row
            statsRow
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Legend Item

    @ViewBuilder
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
    }

    // MARK: - Stats Row

    @ViewBuilder
    private var statsRow: some View {
        HStack(spacing: Spacing.lg) {
            // Completed sessions
            VStack(alignment: .leading, spacing: 2) {
                Text("\(completedDates.count)")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.sage)

                Text("days active")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Divider()
                .frame(height: 30)
                .background(OnLifeColors.textTertiary.opacity(0.3))

            // Completion rate
            VStack(alignment: .leading, spacing: 2) {
                let rate = Double(completedDates.count) / Double(days) * 100
                Text("\(Int(rate))%")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(rate >= 70 ? OnLifeColors.sage : OnLifeColors.amber)

                Text("completion")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()

            // Longest streak indicator
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                        .foregroundColor(OnLifeColors.amber)

                    Text("\(streakManager.streakData.longestStreak)")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.amber)
                }

                Text("best streak")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
        .padding(.top, Spacing.sm)
    }
}

// MARK: - Day Cell

struct StreakDayCell: View {
    let date: Date
    let isCompleted: Bool
    let isToday: Bool
    let isFuture: Bool

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(backgroundColor)
                .frame(width: 36, height: 36)

            // Today ring
            if isToday {
                Circle()
                    .stroke(OnLifeColors.sage, lineWidth: 2)
                    .frame(width: 40, height: 40)
            }

            // Content
            if isCompleted {
                Text("🔥")
                    .font(.system(size: 14))
            } else if !isFuture {
                Text("\(calendar.component(.day, from: date))")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
        .opacity(isFuture ? 0.3 : 1.0)
    }

    private var backgroundColor: Color {
        if isCompleted {
            return OnLifeColors.amber.opacity(0.3)
        } else if isFuture {
            return OnLifeColors.textTertiary.opacity(0.1)
        } else {
            return OnLifeColors.textTertiary.opacity(0.15)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OnLifeColors.deepForest
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: Spacing.lg) {
                Text("Streak Calendar")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                StreakCalendar(sessions: [])
            }
            .padding()
        }
    }
}
