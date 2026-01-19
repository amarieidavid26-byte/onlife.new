import SwiftUI

struct WakeSleepTimeScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var showingWakePicker = false
    @State private var showingBedtimePicker = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Header
            VStack(spacing: Spacing.md) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Your Sleep Schedule")
                    .font(OnLifeFont.heading1())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Help us recommend your best focus times based on your natural rhythm.")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            // Time Pickers
            VStack(spacing: Spacing.md) {
                // Wake Time Card
                WakeSleepTimeCard(
                    icon: "sunrise.fill",
                    iconColor: .orange,
                    title: "Wake Up Time",
                    subtitle: "When do you typically wake up?",
                    time: viewModel.wakeTime,
                    isEditing: showingWakePicker,
                    onTap: {
                        withAnimation(.spring()) {
                            showingWakePicker.toggle()
                            showingBedtimePicker = false
                        }
                    }
                )

                if showingWakePicker {
                    DatePicker(
                        "Wake Time",
                        selection: $viewModel.wakeTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(OnLifeColors.cardBackground)
                    .cornerRadius(CornerRadius.medium)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Bedtime Card
                WakeSleepTimeCard(
                    icon: "moon.stars.fill",
                    iconColor: .purple,
                    title: "Bedtime",
                    subtitle: "When do you usually go to bed?",
                    time: viewModel.sleepTime,
                    isEditing: showingBedtimePicker,
                    onTap: {
                        withAnimation(.spring()) {
                            showingBedtimePicker.toggle()
                            showingWakePicker = false
                        }
                    }
                )

                if showingBedtimePicker {
                    DatePicker(
                        "Bedtime",
                        selection: $viewModel.sleepTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(OnLifeColors.cardBackground)
                    .cornerRadius(CornerRadius.medium)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Sleep Duration Info
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)

                    Text(sleepDurationText)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)

                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(CornerRadius.small)
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            // Continue Button
            PrimaryButton(title: "Continue") {
                // Dismiss any open pickers
                showingWakePicker = false
                showingBedtimePicker = false
                viewModel.nextScreen()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)
        }
    }

    private var sleepDurationText: String {
        let calendar = Calendar.current

        // Extract hour and minute components
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: viewModel.wakeTime)
        let sleepComponents = calendar.dateComponents([.hour, .minute], from: viewModel.sleepTime)

        let wakeMinutes = (wakeComponents.hour ?? 0) * 60 + (wakeComponents.minute ?? 0)
        var sleepMinutes = (sleepComponents.hour ?? 0) * 60 + (sleepComponents.minute ?? 0)

        // If bedtime is "before" wake time (like 11 PM vs 7 AM), add 24 hours
        if sleepMinutes > wakeMinutes {
            sleepMinutes -= 24 * 60
        }

        let durationMinutes = wakeMinutes - sleepMinutes
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60

        if hours < 6 {
            return "You're getting \(hours)h \(minutes)m of sleep. Consider 7-9 hours for optimal focus."
        } else if hours >= 10 {
            return "\(hours)h \(minutes)m is quite a lot! Most adults need 7-9 hours."
        } else {
            return "Great! \(hours)h \(minutes)m is within the optimal 7-9 hour range."
        }
    }
}

struct WakeSleepTimeCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let time: Date
    let isEditing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(iconColor)
                    .frame(width: 50)

                // Text
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(OnLifeFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(subtitle)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                Spacer()

                // Time Display
                Text(time, style: .time)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(isEditing ? OnLifeColors.sage : OnLifeColors.textPrimary)

                Image(systemName: isEditing ? "chevron.up" : "chevron.down")
                    .foregroundColor(OnLifeColors.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(OnLifeColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(isEditing ? OnLifeColors.sage : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
