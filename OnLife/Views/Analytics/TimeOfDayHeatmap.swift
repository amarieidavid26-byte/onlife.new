import SwiftUI

/// Heatmap visualization showing focus session distribution by hour of day
struct TimeOfDayHeatmap: View {
    let distribution: [Int: Int]

    private let hours = Array(0...23)
    private var maxSessions: Int {
        distribution.values.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(OnLifeColors.sage)
                Text("Focus Time by Hour")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            VStack(spacing: Spacing.xs) {
                // Hour labels row
                HStack(spacing: 0) {
                    ForEach([0, 6, 12, 18], id: \.self) { hour in
                        Text(hourLabel(hour))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(OnLifeColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: hour == 0 ? .leading : (hour == 18 ? .trailing : .center))
                    }
                }
                .padding(.horizontal, 2)

                // Heatmap bars
                HStack(spacing: 2) {
                    ForEach(hours, id: \.self) { hour in
                        let sessionCount = distribution[hour] ?? 0
                        let intensity = maxSessions > 0 ? Double(sessionCount) / Double(maxSessions) : 0

                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(heatColor(for: intensity))
                                .frame(height: 44)
                                .cornerRadius(3)
                                .overlay(
                                    Group {
                                        if sessionCount > 0 && intensity > 0.5 {
                                            Text("\(sessionCount)")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                    }
                                )
                        }
                    }
                }

                // Time period labels
                HStack {
                    Text("Night")
                        .frame(maxWidth: .infinity)
                    Text("Morning")
                        .frame(maxWidth: .infinity)
                    Text("Afternoon")
                        .frame(maxWidth: .infinity)
                    Text("Evening")
                        .frame(maxWidth: .infinity)
                }
                .font(.system(size: 9))
                .foregroundColor(OnLifeColors.textTertiary)
            }

            // Legend
            HStack(spacing: Spacing.md) {
                legendItem(color: heatColor(for: 0), label: "None")
                legendItem(color: heatColor(for: 0.3), label: "Low")
                legendItem(color: heatColor(for: 0.6), label: "Medium")
                legendItem(color: heatColor(for: 1.0), label: "High")
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

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

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    private func heatColor(for intensity: Double) -> Color {
        switch intensity {
        case 0.8...1.0: return OnLifeColors.sage
        case 0.5..<0.8: return OnLifeColors.sage.opacity(0.7)
        case 0.2..<0.5: return OnLifeColors.amber.opacity(0.6)
        case 0.01..<0.2: return OnLifeColors.surface.opacity(0.8)
        default: return OnLifeColors.surface.opacity(0.4)
        }
    }
}

// MARK: - Day of Week Heatmap

struct DayOfWeekHeatmap: View {
    let distribution: [Int: Int] // 1=Sunday, 7=Saturday

    private let days = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"),
        (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]

    private var maxSessions: Int {
        distribution.values.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(OnLifeColors.sage)
                Text("Focus by Day of Week")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            HStack(spacing: Spacing.sm) {
                ForEach(days, id: \.0) { day in
                    let sessionCount = distribution[day.0] ?? 0
                    let intensity = maxSessions > 0 ? Double(sessionCount) / Double(maxSessions) : 0

                    VStack(spacing: Spacing.xs) {
                        Text(day.1)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(OnLifeColors.textSecondary)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(dayHeatColor(for: intensity))
                                .frame(height: 50)

                            if sessionCount > 0 {
                                Text("\(sessionCount)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(intensity > 0.5 ? .white : OnLifeColors.textPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func dayHeatColor(for intensity: Double) -> Color {
        switch intensity {
        case 0.8...1.0: return OnLifeColors.sage
        case 0.5..<0.8: return OnLifeColors.sage.opacity(0.6)
        case 0.2..<0.5: return OnLifeColors.amber.opacity(0.5)
        case 0.01..<0.2: return OnLifeColors.surface
        default: return OnLifeColors.surface.opacity(0.5)
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
                TimeOfDayHeatmap(distribution: [
                    8: 3, 9: 5, 10: 8, 11: 6, 14: 4, 15: 7, 16: 5, 17: 2, 20: 1
                ])

                DayOfWeekHeatmap(distribution: [
                    1: 2, 2: 5, 3: 8, 4: 6, 5: 7, 6: 3, 7: 1
                ])
            }
            .padding()
        }
    }
}
