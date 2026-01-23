import SwiftUI

// MARK: - Heatmap Day Cell

struct HeatmapDayCell: View {
    let dayData: HeatmapDayData
    let cellSize: CGFloat
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: cellSize * 0.2, style: .continuous)
                .fill(cellColor)
                .frame(width: cellSize, height: cellSize)
                .overlay(
                    RoundedRectangle(cornerRadius: cellSize * 0.2, style: .continuous)
                        .stroke(borderColor, lineWidth: isToday ? 2 : 0)
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Colors

    private var cellColor: Color {
        switch dayData.intensityLevel {
        case .none:
            return OnLifeColors.cardBackgroundElevated.opacity(0.5)
        case .activityOnly:
            return OnLifeColors.textMuted.opacity(0.4)
        case .lightFlow:
            return OnLifeColors.socialTeal.opacity(0.3)
        case .moderateFlow:
            return OnLifeColors.socialTeal.opacity(0.6)
        case .deepFlow:
            return OnLifeColors.socialTeal
        }
    }

    private var borderColor: Color {
        isToday ? OnLifeColors.textPrimary : Color.clear
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(dayData.date)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        var label = formatter.string(from: dayData.date) + ": "

        if !dayData.hasActivity {
            label += "No session"
        } else if dayData.flowAchieved {
            if let quality = dayData.flowQuality {
                label += "Flow achieved, \(Int(quality * 100))% quality"
            } else {
                label += "Flow achieved"
            }
        } else {
            label += "Session completed, no flow"
        }

        return label
    }
}

// MARK: - Heatmap Day Cell Compact

struct HeatmapDayCellCompact: View {
    let intensity: HeatmapIntensity
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
            .fill(cellColor)
            .frame(width: size, height: size)
    }

    private var cellColor: Color {
        switch intensity {
        case .none:
            return OnLifeColors.cardBackgroundElevated.opacity(0.5)
        case .activityOnly:
            return OnLifeColors.textMuted.opacity(0.4)
        case .lightFlow:
            return OnLifeColors.socialTeal.opacity(0.3)
        case .moderateFlow:
            return OnLifeColors.socialTeal.opacity(0.6)
        case .deepFlow:
            return OnLifeColors.socialTeal
        }
    }
}

// MARK: - Day Detail Popover

struct HeatmapDayDetailPopover: View {
    let dayData: HeatmapDayData
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedDate)
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(dayOfWeek)
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            Divider()
                .background(OnLifeColors.textMuted.opacity(0.3))

            // Status
            HStack(spacing: Spacing.md) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: statusIcon)
                        .font(.system(size: 18))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(statusSubtitle)
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }

                Spacer()
            }

            // Stats (if activity exists)
            if dayData.hasActivity {
                Divider()
                    .background(OnLifeColors.textMuted.opacity(0.3))

                // Session stats
                HStack(spacing: Spacing.xl) {
                    statItem(
                        label: "Sessions",
                        value: "\(dayData.sessionCount)"
                    )

                    statItem(
                        label: "Duration",
                        value: "\(dayData.totalMinutes)m"
                    )

                    if let score = dayData.bestSessionScore {
                        statItem(
                            label: "Best Score",
                            value: "\(Int(score * 100))%"
                        )
                    }
                }

                // Flow quality bar (if flow achieved)
                if dayData.flowAchieved, let quality = dayData.flowQuality {
                    flowQualityBar(quality: quality)
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .frame(width: 260)
    }

    // MARK: - Formatting

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: dayData.date)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: dayData.date)
    }

    // MARK: - Status

    private var statusColor: Color {
        switch dayData.intensityLevel {
        case .none:
            return OnLifeColors.textMuted
        case .activityOnly:
            return OnLifeColors.warning
        case .lightFlow, .moderateFlow, .deepFlow:
            return OnLifeColors.socialTeal
        }
    }

    private var statusIcon: String {
        switch dayData.intensityLevel {
        case .none:
            return "moon.zzz"
        case .activityOnly:
            return "figure.run"
        case .lightFlow:
            return "leaf"
        case .moderateFlow:
            return "leaf.fill"
        case .deepFlow:
            return "sparkles"
        }
    }

    private var statusTitle: String {
        dayData.intensityLevel.description
    }

    private var statusSubtitle: String {
        switch dayData.intensityLevel {
        case .none:
            return "No flow session recorded"
        case .activityOnly:
            return "Activity without entering flow"
        case .lightFlow:
            return "Brief flow state achieved"
        case .moderateFlow:
            return "Solid flow state maintained"
        case .deepFlow:
            return "Deep flow state achieved"
        }
    }

    // MARK: - Stat Item

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            Text(label)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
    }

    // MARK: - Flow Quality Bar

    private func flowQualityBar(quality: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Flow Quality")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)

                Spacer()

                Text("\(Int(quality * 100))%")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.socialTeal)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(OnLifeColors.cardBackgroundElevated)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [OnLifeColors.socialTeal.opacity(0.6), OnLifeColors.socialTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * quality)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HeatmapDayCell_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.lg) {
            // Grid of cells
            HStack(spacing: 4) {
                ForEach(HeatmapIntensity.allCases, id: \.rawValue) { intensity in
                    HeatmapDayCellCompact(intensity: intensity, size: 16)
                }
            }

            // Full cells
            HStack(spacing: 8) {
                HeatmapDayCell(
                    dayData: .empty(for: Date()),
                    cellSize: 24,
                    onTap: {}
                )

                HeatmapDayCell(
                    dayData: HeatmapDayData(
                        id: "test",
                        date: Date(),
                        sessionCount: 1,
                        flowAchieved: false,
                        flowQuality: nil,
                        totalMinutes: 45,
                        bestSessionScore: nil
                    ),
                    cellSize: 24,
                    onTap: {}
                )

                HeatmapDayCell(
                    dayData: HeatmapDayData(
                        id: "test2",
                        date: Date(),
                        sessionCount: 2,
                        flowAchieved: true,
                        flowQuality: 0.85,
                        totalMinutes: 120,
                        bestSessionScore: 0.9
                    ),
                    cellSize: 24,
                    onTap: {}
                )
            }

            // Detail popover
            HeatmapDayDetailPopover(
                dayData: HeatmapDayData(
                    id: "test",
                    date: Date(),
                    sessionCount: 2,
                    flowAchieved: true,
                    flowQuality: 0.78,
                    totalMinutes: 135,
                    bestSessionScore: 0.85
                ),
                onDismiss: {}
            )
        }
        .padding()
        .background(OnLifeColors.deepForest)
        .preferredColorScheme(.dark)
    }
}
#endif
