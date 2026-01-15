import SwiftUI

struct WatchSessionSummaryView: View {
    let duration: Int
    let avgHeartRate: Double
    let peakFlowScore: Int
    let timeInFlowSeconds: Int
    let flowState: FlowState

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                headerSection

                // Stats
                statsGrid

                // Flow Time
                flowTimeSection

                // Message
                motivationalMessage

                // Done Button
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
        }
        .navigationTitle("Complete")
        .navigationBarBackButtonHidden(true)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: peakFlowScore >= 70 ? "checkmark.circle.fill" : "clock.fill")
                .font(.system(size: 40))
                .foregroundColor(peakFlowScore >= 70 ? .green : .orange)

            Text(peakFlowScore >= 70 ? "Great Session!" : "Session Complete")
                .font(.headline)
        }
    }

    private var statsGrid: some View {
        VStack(spacing: 12) {
            HStack {
                StatBox(title: "Duration", value: formatDuration(duration), icon: "clock")
                StatBox(title: "Avg HR", value: "\(Int(avgHeartRate))", icon: "heart.fill")
            }

            HStack {
                StatBox(title: "Peak Flow", value: "\(peakFlowScore)", icon: "brain.head.profile")
                StatBox(title: "State", value: flowState.displayName, icon: flowState.iconName)
            }
        }
    }

    private var flowTimeSection: some View {
        VStack(spacing: 4) {
            Text("Time in Flow")
                .font(.caption)
                .foregroundColor(.gray)

            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundColor(.green)

                Text(formatDuration(timeInFlowSeconds))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            Text("\(flowTimePercent)% of session")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.15))
        .cornerRadius(8)
    }

    private var flowTimePercent: Int {
        guard duration > 0 else { return 0 }
        return Int((Double(timeInFlowSeconds) / Double(duration)) * 100)
    }

    private var motivationalMessage: some View {
        Text(getMessage())
            .font(.caption)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        if mins == 0 {
            return "\(seconds)s"
        }
        return "\(mins) min"
    }

    private func getMessage() -> String {
        if peakFlowScore >= 70 {
            return "You achieved flow state! Your focus was excellent."
        } else if peakFlowScore >= 50 {
            return "Good session. Try a longer focus period next time."
        } else {
            return "Keep practicing. Flow comes with consistency."
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.gray)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

#if DEBUG
struct WatchSessionSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        WatchSessionSummaryView(
            duration: 1500,
            avgHeartRate: 85,
            peakFlowScore: 78,
            timeInFlowSeconds: 900,
            flowState: .flow
        )
    }
}
#endif
