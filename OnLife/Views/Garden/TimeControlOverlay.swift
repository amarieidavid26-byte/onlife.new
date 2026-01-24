import SwiftUI

/// Overlay for controlling day/night time during demos
/// Allows manual time adjustment and time-lapse mode
struct TimeControlOverlay: View {
    @ObservedObject var dayNightSystem = DayNightSystem.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Binding var isVisible: Bool

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Header
            HStack {
                // Phase icon with glow
                ZStack {
                    Circle()
                        .fill(phaseColor.opacity(0.3))
                        .frame(width: 44, height: 44)

                    Image(systemName: dayNightSystem.currentPhase.icon)
                        .font(.title2)
                        .foregroundColor(phaseColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(dayNightSystem.currentPhase.rawValue)
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(timeString)
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }

            // Time slider
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.purple.opacity(0.7))
                        .font(.caption)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track background with gradient
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.purple.opacity(0.3),
                                            Color.orange.opacity(0.3),
                                            Color.blue.opacity(0.3),
                                            Color.orange.opacity(0.3),
                                            Color.purple.opacity(0.3)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 8)

                            // Time indicator
                            Circle()
                                .fill(phaseColor)
                                .frame(width: 20, height: 20)
                                .shadow(color: phaseColor.opacity(0.5), radius: 4)
                                .offset(x: CGFloat(dayNightSystem.timeOfDay) * (geo.size.width - 20))
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let newTime = Float(value.location.x / geo.size.width)
                                            dayNightSystem.setTime(max(0, min(1, newTime)))
                                        }
                                )
                        }
                    }
                    .frame(height: 20)

                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.yellow.opacity(0.8))
                        .font(.caption)
                }
            }

            Divider()
                .background(OnLifeColors.textTertiary.opacity(0.3))

            // Phase quick-select buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(displayPhases, id: \.self) { phase in
                        PhaseQuickButton(
                            phase: phase,
                            isSelected: dayNightSystem.currentPhase == phase
                        ) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                dayNightSystem.jumpToPhase(phase)
                            }
                            HapticManager.shared.impact(style: .light)
                        }
                    }
                }
            }

            Divider()
                .background(OnLifeColors.textTertiary.opacity(0.3))

            // Control buttons
            HStack(spacing: Spacing.md) {
                // Real time button
                Button {
                    dayNightSystem.returnToRealTime()
                    HapticManager.shared.impact(style: .light)
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "clock")
                        Text("Real Time")
                            .font(OnLifeFont.bodySmall())
                    }
                    .foregroundColor(dayNightSystem.followRealTime ? .white : OnLifeColors.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(dayNightSystem.followRealTime ? OnLifeColors.sage : OnLifeColors.surface)
                    .cornerRadius(12)
                }

                // Time-lapse button
                Button {
                    if dayNightSystem.followRealTime {
                        dayNightSystem.startTimeLapse(speed: 120)
                    } else {
                        dayNightSystem.returnToRealTime()
                    }
                    HapticManager.shared.impact(style: .light)
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "forward.fill")
                        Text("Time-lapse")
                            .font(OnLifeFont.bodySmall())
                    }
                    .foregroundColor(!dayNightSystem.followRealTime ? .white : OnLifeColors.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(!dayNightSystem.followRealTime ? OnLifeColors.sage : OnLifeColors.surface)
                    .cornerRadius(12)
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, y: -5)
        )
    }

    // MARK: - Computed Properties

    private var displayPhases: [DayNightSystem.DayPhase] {
        [.dawn, .morning, .day, .evening, .dusk, .night]
    }

    private var timeString: String {
        let totalHours = dayNightSystem.timeOfDay * 24
        let hours = Int(totalHours)
        let minutes = Int((totalHours - Float(hours)) * 60)
        let period = hours < 12 ? "AM" : "PM"
        let displayHour = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours)
        return String(format: "%d:%02d %@", displayHour, minutes, period)
    }

    private var phaseColor: Color {
        switch dayNightSystem.currentPhase {
        case .night, .twilight: return .purple
        case .dawn: return .orange
        case .morning: return .yellow
        case .day: return .blue
        case .evening: return .orange
        case .dusk: return Color(red: 1.0, green: 0.4, blue: 0.3)
        }
    }
}

// MARK: - Phase Quick Button

struct PhaseQuickButton: View {
    let phase: DayNightSystem.DayPhase
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? phaseColor : OnLifeColors.surface)
                        .frame(width: 44, height: 44)

                    if isSelected {
                        Circle()
                            .strokeBorder(phaseColor.opacity(0.5), lineWidth: 2)
                            .frame(width: 52, height: 52)
                    }

                    Image(systemName: phase.icon)
                        .font(.body)
                        .foregroundColor(isSelected ? .white : OnLifeColors.textSecondary)
                }

                Text(phase.rawValue)
                    .font(OnLifeFont.caption())
                    .foregroundColor(isSelected ? phaseColor : OnLifeColors.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var phaseColor: Color {
        switch phase {
        case .night, .twilight: return .purple
        case .dawn: return .orange
        case .morning: return .yellow
        case .day: return .blue
        case .evening: return .orange
        case .dusk: return Color(red: 1.0, green: 0.4, blue: 0.3)
        }
    }
}

// MARK: - Compact Time Indicator

/// Small indicator showing current time (for header bar)
struct TimeIndicator: View {
    @ObservedObject var dayNightSystem = DayNightSystem.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: dayNightSystem.currentPhase.icon)
                .font(.caption)
                .foregroundColor(phaseColor)

            if !dayNightSystem.followRealTime {
                // Show time-lapse indicator
                Image(systemName: "forward.fill")
                    .font(.caption2)
                    .foregroundColor(OnLifeColors.amber)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(OnLifeColors.surface.opacity(0.8))
        .cornerRadius(CornerRadius.small)
    }

    private var phaseColor: Color {
        switch dayNightSystem.currentPhase {
        case .night, .twilight: return .purple
        case .dawn, .dusk: return .orange
        default: return .yellow
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TimeControlOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.orange.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                TimeControlOverlay(isVisible: .constant(true))
                    .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
