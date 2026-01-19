import SwiftUI

/*
 Substance Tracking System

 Features:
 - One-tap logging of common substances (caffeine, L-theanine, water)
 - Pharmacokinetic modeling with corrected half-lives:
   * Caffeine: 5 hours (base, varies by individual)
   * L-theanine: 60 minutes (Scheid et al. 2012)
   * Water: 1 hour (simplified model)
 - Real-time active level calculation
 - Synergy detection (50mg caffeine + 100mg L-theanine minimum)
 - Safety warning system based on EFSA/AAP/ACOG guidelines
 - Decay visualization via progress bars

 Based on peer-reviewed pharmacokinetic research.
 */

struct SubstanceTrackingView: View {
    @ObservedObject private var tracker = SubstanceTracker.shared
    @State private var showingCustomLog = false
    @State private var showingScanner = false
    @State private var scannedBarcode: String?
    @State private var contentAppeared = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [OnLifeColors.deepForest, OnLifeColors.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // MARK: - Header
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Track & Optimize")
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textSecondary)

                        Text("Substances")
                            .font(OnLifeFont.display())
                            .foregroundColor(OnLifeColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : -10)

                    // SAFETY WARNINGS - Display at top when present
                    let warnings = tracker.getAllWarnings()
                    if !warnings.isEmpty {
                        WarningBannerView(
                            warnings: warnings,
                            warningLevel: tracker.getCaffeineWarningLevel()
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // SYNERGY INDICATOR - Prominent display when active
                    if tracker.calculateSynergy() > 1.0 {
                        SynergyIndicatorCard()
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 20)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: tracker.calculateSynergy())
                    }

                    // Feature explanation card
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "drop.fill")
                            .foregroundColor(OnLifeColors.sage)
                            .font(.system(size: 18))

                        Text("Track substances to optimize your focus")
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textSecondary)

                        Spacer()
                    }
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.cardBackground)
                    )
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 20)

                    // Active Levels Card
                    ActiveSubstancesCard(
                        activeLevels: tracker.activeLevels,
                        warningLevel: tracker.getCaffeineWarningLevel(),
                        todaysCaffeine: tracker.getTodaysTotalCaffeine(),
                        todaysLTheanine: tracker.getTodaysTotalLTheanine(),
                        dailyLimit: MetabolismProfileManager.shared.profile.recommendedDailyCaffeineLimit,
                        synergyMultiplier: tracker.calculateSynergy()
                    )
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 20)
                    .animation(OnLifeAnimation.elegant.delay(0.05), value: contentAppeared)

                    // Quick Log Buttons
                    QuickLogSection(tracker: tracker, showingScanner: $showingScanner)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(OnLifeAnimation.elegant.delay(0.1), value: contentAppeared)

                    // Today's Logs
                    TodayLogSection(logs: todayLogs)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(OnLifeAnimation.elegant.delay(0.15), value: contentAppeared)

                    // Insights (only if there are logs)
                    if !tracker.logs.isEmpty {
                        SubstanceInsightsCard(tracker: tracker)
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 20)
                            .animation(OnLifeAnimation.elegant.delay(0.2), value: contentAppeared)
                    }
                }
                .padding(Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
        }
        .toolbarBackground(OnLifeColors.deepForest, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            withAnimation(OnLifeAnimation.elegant) {
                contentAppeared = true
            }

            #if DEBUG
            Task {
                tracker.testPharmacokinetics()
            }
            #endif
        }
        .fullScreenCover(isPresented: $showingScanner) {
            BarcodeScannerView { barcode in
                Task { @MainActor in
                    scannedBarcode = barcode
                }
            }
        }
        .sheet(item: $scannedBarcode) { barcode in
            ProductLookupView(barcode: barcode) {
                Task { @MainActor in
                    tracker.updateActiveLevels()
                }
            }
        }
    }

    // MARK: - Computed Properties

    var todayLogs: [SubstanceLog] {
        let today = Calendar.current.startOfDay(for: Date())
        return tracker.logs
            .filter { $0.timestamp >= today }
            .sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Active Substances Card

struct ActiveSubstancesCard: View {
    let activeLevels: [SubstanceType: Double]
    let warningLevel: SubstanceTracker.CaffeineWarningLevel
    let todaysCaffeine: Double
    let todaysLTheanine: Double
    let dailyLimit: Double
    let synergyMultiplier: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(OnLifeColors.sage)
                    .font(.system(size: 18))

                Text("Active Levels")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()
            }

            // Daily totals row
            HStack(spacing: Spacing.md) {
                // Caffeine total with limit
                if todaysCaffeine > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundColor(colorForWarningLevel(warningLevel))
                            .font(.caption)
                        if warningLevel != .safe {
                            Image(systemName: warningLevel.icon)
                                .foregroundColor(colorForWarningLevel(warningLevel))
                                .font(.caption2)
                        }
                        Text("\(Int(todaysCaffeine))/\(Int(dailyLimit))mg")
                            .font(OnLifeFont.caption())
                            .foregroundColor(colorForWarningLevel(warningLevel))
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            .fill(colorForWarningLevel(warningLevel).opacity(0.1))
                    )
                }

                // L-Theanine total (no limit)
                if todaysLTheanine > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(OnLifeColors.sage)
                            .font(.caption)
                        Text("\(Int(todaysLTheanine))mg")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.sage)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            .fill(OnLifeColors.sage.opacity(0.1))
                    )
                }

                Spacer()
            }

            // SYNERGY INDICATOR
            if synergyMultiplier > 1.0 {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundColor(OnLifeColors.amber)
                        .font(.system(size: 18, weight: .semibold))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Synergy Active")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.amber)

                        Text("+15% focus boost from caffeine + L-theanine")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }

                    Spacer()

                    Text("+15%")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.amber)
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .fill(OnLifeColors.amber.opacity(0.15))
                )
            }

            // Only display caffeine and L-theanine (NOT water)
            let substancesToDisplay: [SubstanceType] = [.caffeine, .lTheanine]
            let hasActive = substancesToDisplay.contains { activeLevels[$0] ?? 0 > 1.0 }

            if !hasActive {
                Text("No active substances")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .padding(.vertical, Spacing.sm)
            } else {
                ForEach(substancesToDisplay, id: \.self) { type in
                    if let level = activeLevels[type], level > 1.0 {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Image(systemName: type.iconName)
                                    .foregroundColor(substanceColor(type, warningLevel: warningLevel))

                                Text(type.rawValue)
                                    .font(OnLifeFont.body())
                                    .foregroundColor(OnLifeColors.textPrimary)

                                Spacer()

                                if type == .caffeine && warningLevel != .safe {
                                    Image(systemName: warningLevel.icon)
                                        .foregroundColor(colorForWarningLevel(warningLevel))
                                        .font(.caption)
                                }

                                Text("\(Int(level))mg")
                                    .font(OnLifeFont.heading3())
                                    .foregroundColor(type == .caffeine ? colorForWarningLevel(warningLevel) : OnLifeColors.textPrimary)
                            }

                            // Progress bar showing decay
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(OnLifeColors.surface)
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(substanceColor(type, warningLevel: warningLevel))
                                        .frame(width: geometry.size.width * min(1.0, level / (type.defaultAmount * 1.5)), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .overlay(
            // Warning border when caffeine is over limit
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .stroke(warningLevel != .safe ? colorForWarningLevel(warningLevel).opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }

    func substanceColor(_ type: SubstanceType, warningLevel: SubstanceTracker.CaffeineWarningLevel) -> Color {
        switch type {
        case .caffeine:
            return colorForWarningLevel(warningLevel)
        case .lTheanine:
            return OnLifeColors.sage
        case .water:
            return OnLifeColors.sage.opacity(0.7)
        }
    }

    func colorForWarningLevel(_ level: SubstanceTracker.CaffeineWarningLevel) -> Color {
        switch level {
        case .safe: return OnLifeColors.sage
        case .caution: return OnLifeColors.amber
        case .warning: return OnLifeColors.terracotta
        case .danger: return Color.red
        case .emergency: return Color.red
        }
    }
}

// MARK: - Quick Log Section

struct QuickLogSection: View {
    @ObservedObject var tracker: SubstanceTracker
    @Binding var showingScanner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(OnLifeColors.sage)
                    .font(.system(size: 18))

                Text("Quick Log")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            // Scan button - solid amber
            Button(action: {
                Haptics.impact(.medium)
                showingScanner = true
            }) {
                HStack {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 24))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Product")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)

                        Text("Energy drinks, coffee, supplements...")
                            .font(OnLifeFont.caption())
                            .opacity(0.8)
                    }

                    Spacer()

                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                }
                .foregroundColor(OnLifeColors.deepForest)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(OnLifeColors.amber)
                )
                .shadow(
                    color: OnLifeColors.amber.opacity(0.3),
                    radius: 8,
                    y: 4
                )
            }
            .buttonStyle(PressableCardStyle())

            // Manual quick log buttons
            HStack(spacing: Spacing.md) {
                ForEach(SubstanceType.allCases, id: \.self) { type in
                    QuickLogButton(
                        type: type,
                        action: {
                            Haptics.selection()
                            tracker.quickLog(type)
                        }
                    )
                }
            }
        }
    }
}

struct QuickLogButton: View {
    let type: SubstanceType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: type.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(OnLifeColors.sage)

                Text(type.rawValue)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("\(Int(type.defaultAmount))\(type == .water ? "ml" : "mg")")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
        }
        .buttonStyle(PressableChipStyle())
    }
}

// MARK: - Today's Log Section

struct TodayLogSection: View {
    let logs: [SubstanceLog]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(OnLifeColors.sage)
                    .font(.system(size: 18))

                Text("Today's Log")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
            }

            if logs.isEmpty {
                Text("No substances logged today")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.cardBackground)
                    )
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(logs) { log in
                        LogEntryRow(log: log)
                    }
                }
            }
        }
    }
}

struct LogEntryRow: View {
    let log: SubstanceLog

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: log.substanceType.iconName)
                .font(.system(size: 22))
                .foregroundColor(OnLifeColors.sage)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.substanceType.rawValue)
                    .font(OnLifeFont.body())
                    .fontWeight(.medium)
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(log.timestamp, style: .time)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(log.amount))")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(log.unit.rawValue)
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }
}

// MARK: - Substance Insights Card

struct SubstanceInsightsCard: View {
    @ObservedObject var tracker: SubstanceTracker

    var body: some View {
        HStack(spacing: 0) {
            // Amber accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(OnLifeColors.amber)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(OnLifeColors.amber)
                        .font(.system(size: 18))

                    Text("Insights")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // Synergy detection
                    if tracker.calculateSynergy() > 1.0 {
                        InsightRow(
                            icon: "leaf.fill",
                            text: "Caffeine + L-theanine synergy active! 15% focus boost",
                            color: OnLifeColors.sage
                        )
                    }

                    // Caffeine timing
                    if let caffeineLevel = tracker.activeLevels[.caffeine], caffeineLevel > 50 {
                        InsightRow(
                            icon: "clock.fill",
                            text: "Caffeine active: \(Int(caffeineLevel))mg in your system",
                            color: OnLifeColors.amber
                        )
                    }

                    // L-theanine info
                    if let lTheanineLevel = tracker.activeLevels[.lTheanine], lTheanineLevel > 50 {
                        InsightRow(
                            icon: "leaf.fill",
                            text: "L-theanine active: \(Int(lTheanineLevel))mg - smooth focus mode",
                            color: OnLifeColors.sage
                        )
                    }

                    // Hydration check
                    if let waterLevel = tracker.activeLevels[.water], waterLevel < 100 {
                        InsightRow(
                            icon: "drop.fill",
                            text: "Consider drinking water for optimal focus",
                            color: OnLifeColors.sage.opacity(0.7)
                        )
                    }

                    // If no insights
                    if tracker.calculateSynergy() == 1.0 &&
                       (tracker.activeLevels[.caffeine] ?? 0) < 50 &&
                       (tracker.activeLevels[.lTheanine] ?? 0) < 50 {
                        Text("Log substances to see personalized insights")
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }
}

struct InsightRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))

            Text(text)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
        }
    }
}

// MARK: - Warning Banner View

struct WarningBannerView: View {
    let warnings: [String]
    let warningLevel: SubstanceTracker.CaffeineWarningLevel

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: iconForWarning(warning))
                        .foregroundColor(textColorForWarning(warning))
                        .font(.system(size: 16, weight: .semibold))

                    Text(warning)
                        .font(OnLifeFont.caption())
                        .foregroundColor(textColorForWarning(warning))
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(backgroundColorForWarning(warning))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(borderColorForWarning(warning), lineWidth: 1)
                )
            }
        }
    }

    func iconForWarning(_ warning: String) -> String {
        if warning.contains("DANGEROUS") {
            return "staroflife.fill"
        }
        if warning.contains("Very high") {
            return "xmark.octagon.fill"
        }
        if warning.contains("CRITICAL") {
            return "exclamationmark.octagon.fill"
        }
        return "exclamationmark.triangle.fill"
    }

    func backgroundColorForWarning(_ warning: String) -> Color {
        if warning.contains("DANGEROUS") {
            return Color.red.opacity(0.15)
        }
        if warning.contains("Very high") || warning.contains("CRITICAL") {
            return Color.red.opacity(0.15)
        }
        if warning.contains("High") || warning.contains("exceeded") {
            return OnLifeColors.terracotta.opacity(0.15)
        }
        return OnLifeColors.amber.opacity(0.15)
    }

    func borderColorForWarning(_ warning: String) -> Color {
        if warning.contains("DANGEROUS") || warning.contains("Very high") || warning.contains("CRITICAL") {
            return Color.red.opacity(0.5)
        }
        if warning.contains("High") || warning.contains("exceeded") {
            return OnLifeColors.terracotta.opacity(0.5)
        }
        return OnLifeColors.amber.opacity(0.5)
    }

    func textColorForWarning(_ warning: String) -> Color {
        if warning.contains("DANGEROUS") || warning.contains("Very high") || warning.contains("CRITICAL") {
            return Color.red
        }
        if warning.contains("High") || warning.contains("exceeded") {
            return OnLifeColors.terracotta
        }
        return OnLifeColors.amber
    }
}

// MARK: - Synergy Indicator Card

struct SynergyIndicatorCard: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Animated sparkle icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Text content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text("Synergy Active")
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("+15%")
                        .font(OnLifeFont.caption())
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }

                Text("Caffeine + L-theanine working together")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            Spacer()

            // Checkmark indicator
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.08),
                            Color.blue.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - String Extension

@available(iOS 13.0, *)
extension String: @retroactive Identifiable {
    public var id: String { self }
}
