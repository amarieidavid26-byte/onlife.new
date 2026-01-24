import SwiftUI
import Combine

// MARK: - Biometric Sources View

struct BiometricSourcesView: View {
    @StateObject private var sourceManager = BiometricSourceManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedInfoSource: BiometricSource?
    @State private var contentAppeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                // Active Source Card
                activeSourceCard
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 20)

                // Available Sources
                availableSourcesSection
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 20)
                    .animation(OnLifeAnimation.elegant.delay(0.1), value: contentAppeared)

                // Source Comparison
                sourceComparisonSection
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 20)
                    .animation(OnLifeAnimation.elegant.delay(0.2), value: contentAppeared)

                // Settings
                settingsSection
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 20)
                    .animation(OnLifeAnimation.elegant.delay(0.3), value: contentAppeared)

                Spacer(minLength: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
        }
        .background(OnLifeColors.deepForest.ignoresSafeArea())
        .navigationTitle("Biometric Sources")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedInfoSource) { source in
            BiometricSourceInfoSheet(source: source)
        }
        .onAppear {
            withAnimation(OnLifeAnimation.elegant) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Active Source Card

    private var activeSourceCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("ACTIVE SOURCE")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .tracking(1.2)

                Spacer()

                if sourceManager.isDetectingSource {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            HStack(spacing: Spacing.md) {
                // Icon with glow
                ZStack {
                    Circle()
                        .fill(OnLifeColors.sage.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Image(systemName: sourceManager.activeSource.icon)
                        .font(.system(size: 24))
                        .foregroundColor(OnLifeColors.sage)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(sourceManager.activeSource.displayName)
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(sourceManager.activeSource.accuracy)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.healthy)

                    if sourceManager.userPreferredSource == nil {
                        Text("Auto-selected (best available)")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    } else {
                        Text("Manually selected")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
        }
    }

    // MARK: - Available Sources

    private var availableSourcesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("SOURCE PRIORITY")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .tracking(1.2)

                Spacer()

                Button {
                    sourceManager.setPreferredSource(nil)
                } label: {
                    Text("Auto")
                        .font(OnLifeFont.caption())
                        .foregroundColor(sourceManager.userPreferredSource == nil ? OnLifeColors.textPrimary : OnLifeColors.textTertiary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            sourceManager.userPreferredSource == nil ?
                                OnLifeColors.sage.opacity(0.3) : OnLifeColors.cardBackground
                        )
                        .cornerRadius(CornerRadius.small)
                }
            }

            Text("Higher sources are prioritized when available")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)

            VStack(spacing: Spacing.sm) {
                ForEach(BiometricSource.allCases.filter { $0 != .none }.sorted { $0.priority > $1.priority }, id: \.self) { source in
                    BiometricSourceRow(
                        source: source,
                        isAvailable: sourceManager.availableSources.contains(source),
                        isActive: sourceManager.activeSource == source,
                        isPreferred: sourceManager.userPreferredSource == source
                    ) {
                        if sourceManager.availableSources.contains(source) {
                            sourceManager.setPreferredSource(source)
                        }
                    } onInfoTap: {
                        selectedInfoSource = source
                    }
                }
            }
        }
    }

    // MARK: - Source Comparison

    private var sourceComparisonSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("WHY SOURCE MATTERS")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .tracking(1.2)

                Spacer()

                Image(systemName: "lightbulb.fill")
                    .foregroundColor(OnLifeColors.amber)
                    .font(.system(size: 14))
            }

            VStack(spacing: Spacing.sm) {
                ComparisonRow(
                    label: "WHOOP",
                    value: "99%",
                    detail: "Medical-grade HRV accuracy",
                    color: OnLifeColors.healthy
                )

                ComparisonRow(
                    label: "Apple Watch",
                    value: "71%",
                    detail: "Good estimate, indirect measurement",
                    color: OnLifeColors.amber
                )

                ComparisonRow(
                    label: "Phone Only",
                    value: "65%",
                    detail: "Behavioral patterns, no biometrics",
                    color: OnLifeColors.textTertiary
                )
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )

            Text("Higher accuracy = better flow detection = faster skill building")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .italic()
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("SETTINGS")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .tracking(1.2)

            Toggle(isOn: $sourceManager.showSourceSwitchPrompt) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Source Upgrade Alerts")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                    Text("Notify when a better source becomes available")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }
            .tint(OnLifeColors.sage)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )

            Button {
                sourceManager.detectAvailableSources()
                HapticManager.shared.impact(style: .light)
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Sources")
                }
                .font(OnLifeFont.button())
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .fill(OnLifeColors.cardBackground)
                )
                .foregroundColor(OnLifeColors.sage)
            }
        }
    }
}

// MARK: - Source Row

struct BiometricSourceRow: View {
    let source: BiometricSource
    let isAvailable: Bool
    let isActive: Bool
    let isPreferred: Bool
    let onTap: () -> Void
    let onInfoTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                // Priority indicator
                Text("\(source.priority)")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
                    .frame(width: 20)

                // Icon
                Image(systemName: source.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isAvailable ? OnLifeColors.sage : OnLifeColors.textTertiary)
                    .frame(width: 28)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(source.displayName)
                            .font(OnLifeFont.body())
                            .foregroundColor(isAvailable ? OnLifeColors.textPrimary : OnLifeColors.textTertiary)

                        if isActive {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(OnLifeColors.deepForest)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(OnLifeColors.healthy)
                                .cornerRadius(4)
                        }
                    }

                    Text(source.accuracy)
                        .font(OnLifeFont.caption())
                        .foregroundColor(isAvailable ? OnLifeColors.textSecondary : OnLifeColors.textTertiary)
                }

                Spacer()

                // Status
                if !isAvailable {
                    Text("Not connected")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                } else if isPreferred {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(OnLifeColors.sage)
                }

                // Info button
                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(isActive ? OnLifeColors.sage.opacity(0.1) : OnLifeColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isActive ? OnLifeColors.sage : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(isAvailable ? 1 : 0.6)
        .disabled(!isAvailable)
    }
}

// MARK: - Comparison Row

struct ComparisonRow: View {
    let label: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(OnLifeFont.heading3())
                    .foregroundColor(color)

                Text(detail)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
    }
}

// MARK: - Info Sheet

struct BiometricSourceInfoSheet: View {
    let source: BiometricSource
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(OnLifeColors.sage.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: source.icon)
                            .font(.system(size: 36))
                            .foregroundColor(OnLifeColors.sage)
                    }
                    .padding(.top, Spacing.lg)

                    // Title
                    Text(source.displayName)
                        .font(OnLifeFont.heading1())
                        .foregroundColor(OnLifeColors.textPrimary)

                    // Accuracy badge
                    Text(source.accuracy)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.healthy)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(OnLifeColors.healthy.opacity(0.2))
                        .cornerRadius(CornerRadius.medium)

                    // Description
                    Text(source.description)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)

                    // Details based on source
                    sourceSpecificInfo

                    Spacer(minLength: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.lg)
            }
            .background(OnLifeColors.deepForest.ignoresSafeArea())
            .navigationTitle("About This Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(OnLifeColors.sage)
                }
            }
        }
    }

    @ViewBuilder
    private var sourceSpecificInfo: some View {
        switch source {
        case .whoopBLE:
            InfoSection(title: "Real-time Monitoring", items: [
                "Live heart rate every second",
                "RMSSD calculated from R-R intervals",
                "Instant flow state detection",
                "Requires WHOOP Heart Rate Broadcast enabled"
            ])
        case .whoopAPI:
            InfoSection(title: "Daily Metrics", items: [
                "Recovery score (0-100%)",
                "Sleep stages and quality",
                "Strain accumulation",
                "Syncs every few hours"
            ])
        case .appleWatch:
            InfoSection(title: "HealthKit Data", items: [
                "Heart rate samples",
                "HRV (SDNN) measurements",
                "Sleep analysis",
                "Requires Apple Watch paired"
            ])
        case .behavioral:
            InfoSection(title: "Phone Patterns", items: [
                "Screen on/off times",
                "App switching frequency",
                "Session completion rates",
                "No wearable required"
            ])
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Info Section

struct InfoSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title.uppercased())
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
                .tracking(1.2)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(OnLifeColors.healthy)
                            .font(.system(size: 14))

                        Text(item)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textPrimary)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BiometricSourcesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            BiometricSourcesView()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
