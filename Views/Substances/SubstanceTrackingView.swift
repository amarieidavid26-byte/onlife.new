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
    /// Use ObservedObject for singleton - StateObject would try to create new instance
    @ObservedObject private var tracker = SubstanceTracker.shared
    @State private var showingCustomLog = false
    @State private var showingScanner = false
    @State private var scannedBarcode: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // SAFETY WARNINGS - Display at top when present
                let warnings = tracker.getAllWarnings()
                if !warnings.isEmpty {
                    WarningBannerView(
                        warnings: warnings,
                        warningLevel: tracker.getCaffeineWarningLevel()
                    )
                }

                // Feature explanation card
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(AppColors.healthy)
                        Text("Track substances to optimize your focus")
                            .font(AppFont.body())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.lightSoil)
                )

                // Active Levels Card with warning level integration and synergy display
                ActiveSubstancesCard(
                    activeLevels: tracker.activeLevels,
                    warningLevel: tracker.getCaffeineWarningLevel(),
                    todaysCaffeine: tracker.getTodaysTotalCaffeine(),
                    dailyLimit: MetabolismProfileManager.shared.profile.recommendedDailyCaffeineLimit,
                    synergyMultiplier: tracker.calculateSynergy()
                )

                // Quick Log Buttons
                QuickLogSection(tracker: tracker, showingScanner: $showingScanner)

                // Today's Logs
                TodayLogSection(logs: todayLogs)

                // Insights (only if there are logs)
                if !tracker.logs.isEmpty {
                    SubstanceInsightsCard(tracker: tracker)
                }
            }
            .padding()
        }
        .background(AppColors.richSoil)
        .navigationTitle("Substances")
        .onAppear {
            // Check and log warnings
            let warnings = tracker.getAllWarnings()
            let warningLevel = tracker.getCaffeineWarningLevel()
            print("⚠️ [SubstanceTracking] onAppear - Warning level: \(warningLevel.rawValue)")
            print("⚠️ [SubstanceTracking] onAppear - \(warnings.count) warnings found")
            for warning in warnings {
                print("⚠️ [SubstanceTracking] Warning: \(warning)")
            }
            print("⚠️ [SubstanceTracking] Today's caffeine: \(tracker.getTodaysTotalCaffeine())mg")
            print("⚠️ [SubstanceTracking] Daily limit: \(MetabolismProfileManager.shared.profile.recommendedDailyCaffeineLimit)mg")

            #if DEBUG
            // Run pharmacokinetics test on first appearance
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
                // Product was logged successfully
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

/// Displays current active substance levels with progress bars showing decay
/// Shows empty state when no substances are above threshold (1.0 mg/ml)
/// Now includes warning level integration for caffeine safety and synergy display
struct ActiveSubstancesCard: View {
    let activeLevels: [SubstanceType: Double]
    let warningLevel: SubstanceTracker.CaffeineWarningLevel
    let todaysCaffeine: Double
    let dailyLimit: Double
    let synergyMultiplier: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(AppColors.healthy)
                Text("Active Levels")
                    .font(AppFont.heading3())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                // Show daily caffeine progress
                if todaysCaffeine > 0 {
                    HStack(spacing: 4) {
                        if warningLevel != .safe {
                            Image(systemName: warningLevel.icon)
                                .foregroundColor(colorForWarningLevel(warningLevel))
                                .font(.caption)
                        }
                        Text("\(Int(todaysCaffeine))/\(Int(dailyLimit))mg")
                            .font(AppFont.bodySmall())
                            .foregroundColor(colorForWarningLevel(warningLevel))
                    }
                }
            }

            // SYNERGY INDICATOR - Prominent display when caffeine + L-theanine synergy is active
            if synergyMultiplier > 1.0 {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.system(size: 18, weight: .semibold))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Synergy Active")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)

                        Text("+15% focus boost from caffeine + L-theanine")
                            .font(AppFont.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Text("+15%")
                        .font(AppFont.heading3())
                        .foregroundColor(.purple)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.purple.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                )
            }

            // Check if caffeine or L-theanine are active
            // NOTE: Water is NOT shown in active levels because:
            // - Biological half-life is 9-14 DAYS (not 1 hour)
            // - Current "1 hour half-life" was a simplified UI model with no scientific basis
            // - Water should use daily intake tracking instead (future feature)
            let substancesToDisplay: [SubstanceType] = [.caffeine, .lTheanine]
            let hasActive = substancesToDisplay.contains { activeLevels[$0] ?? 0 > 1.0 }

            if !hasActive {
                Text("No active substances")
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, Spacing.sm)
            } else {
                // Only display caffeine and L-theanine (NOT water)
                ForEach(substancesToDisplay, id: \.self) { type in
                    if let level = activeLevels[type], level > 1.0 {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Image(systemName: type.iconName)
                                    .foregroundColor(colorForType(type, warningLevel: warningLevel))

                                Text(type.rawValue)
                                    .font(AppFont.body())

                                Spacer()

                                // Warning icon for caffeine if over limit
                                if type == .caffeine && warningLevel != .safe {
                                    Image(systemName: warningLevel.icon)
                                        .foregroundColor(colorForWarningLevel(warningLevel))
                                        .font(.caption)
                                }

                                Text("\(Int(level))mg")
                                    .font(AppFont.heading3())
                                    .foregroundColor(type == .caffeine ? colorForWarningLevel(warningLevel) : AppColors.textPrimary)
                            }

                            // Progress bar showing decay (color-coded for warnings)
                            ProgressView(value: min(1.0, level / (type.defaultAmount * 1.5)))
                                .tint(colorForType(type, warningLevel: warningLevel))
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.lightSoil)
                .overlay(
                    // Add warning border if caffeine is over limit
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(warningLevel != .safe ? colorForWarningLevel(warningLevel).opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
    }

    func colorForType(_ type: SubstanceType, warningLevel: SubstanceTracker.CaffeineWarningLevel) -> Color {
        switch type {
        case .caffeine:
            // Color-code caffeine based on warning level
            return colorForWarningLevel(warningLevel)
        case .lTheanine: return .green
        case .water: return .blue
        }
    }

    func colorForWarningLevel(_ level: SubstanceTracker.CaffeineWarningLevel) -> Color {
        switch level {
        case .safe: return .brown
        case .caution: return .yellow
        case .warning: return .orange
        case .danger: return .red
        case .emergency: return .purple
        }
    }
}

// MARK: - Quick Log Section

/// One-tap buttons for logging substances with default amounts
/// Triggers haptic feedback and immediately updates active levels
struct QuickLogSection: View {
    @ObservedObject var tracker: SubstanceTracker
    @Binding var showingScanner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(AppColors.healthy)
                Text("Quick Log")
                    .font(AppFont.heading3())
                    .foregroundColor(AppColors.textPrimary)
            }

            // Scan button
            Button(action: { showingScanner = true }) {
                HStack {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 24))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Product")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                        Text("Energy drinks, coffee, supplements...")
                            .font(AppFont.bodySmall())
                            .opacity(0.8)
                    }

                    Spacer()

                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(CornerRadius.medium)
            }
            .buttonStyle(PlainButtonStyle())

            // Manual quick log buttons
            HStack(spacing: Spacing.md) {
                ForEach(SubstanceType.allCases, id: \.self) { type in
                    QuickLogButton(
                        type: type,
                        action: { tracker.quickLog(type) }
                    )
                }
            }
        }
    }
}

/// Individual quick log button with icon, name, and default amount
struct QuickLogButton: View {
    let type: SubstanceType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: type.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(.white)

                Text(type.rawValue)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.white)

                Text("\(Int(type.defaultAmount))\(type == .water ? "ml" : "mg")")
                    .font(AppFont.labelSmall())
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(colorForType(type))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    func colorForType(_ type: SubstanceType) -> Color {
        switch type {
        case .caffeine: return .brown
        case .lTheanine: return .green
        case .water: return .blue
        }
    }
}

// MARK: - Today's Log Section

/// Displays all substances logged today in reverse chronological order
/// Shows empty state when no logs exist for current day
struct TodayLogSection: View {
    let logs: [SubstanceLog]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(AppColors.healthy)
                Text("Today's Log")
                    .font(AppFont.heading3())
                    .foregroundColor(AppColors.textPrimary)
            }

            if logs.isEmpty {
                Text("No substances logged today")
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.lightSoil)
                    )
            } else {
                ForEach(logs) { log in
                    LogEntryRow(log: log)
                }
            }
        }
    }
}

/// Individual log entry showing substance, timestamp, and amount
struct LogEntryRow: View {
    let log: SubstanceLog

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: log.substanceType.iconName)
                .font(.system(size: 24))
                .foregroundColor(colorForType(log.substanceType))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(log.substanceType.rawValue)
                    .font(AppFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Text(log.timestamp, style: .time)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(log.amount))")
                    .font(AppFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Text(log.unit.rawValue)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(AppColors.lightSoil)
        )
    }

    func colorForType(_ type: SubstanceType) -> Color {
        switch type {
        case .caffeine: return .brown
        case .lTheanine: return .green
        case .water: return .blue
        }
    }
}

// MARK: - Substance Insights Card

/// Shows personalized insights based on active substance levels
/// Includes synergy detection, timing recommendations, and hydration reminders
struct SubstanceInsightsCard: View {
    @ObservedObject var tracker: SubstanceTracker

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Insights")
                    .font(AppFont.heading3())
                    .foregroundColor(AppColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Synergy detection
                if tracker.calculateSynergy() > 1.0 {
                    InsightRow(
                        icon: "leaf.fill",
                        text: "Caffeine + L-theanine synergy active! 15% focus boost",
                        color: .green
                    )
                }

                // Caffeine timing
                if let caffeineLevel = tracker.activeLevels[.caffeine], caffeineLevel > 50 {
                    InsightRow(
                        icon: "clock.fill",
                        text: "Caffeine active: \(Int(caffeineLevel))mg in your system",
                        color: .brown
                    )
                }

                // L-theanine info
                if let lTheanineLevel = tracker.activeLevels[.lTheanine], lTheanineLevel > 50 {
                    InsightRow(
                        icon: "leaf.fill",
                        text: "L-theanine active: \(Int(lTheanineLevel))mg - smooth focus mode",
                        color: .green
                    )
                }

                // Hydration check
                if let waterLevel = tracker.activeLevels[.water], waterLevel < 100 {
                    InsightRow(
                        icon: "drop.fill",
                        text: "Consider drinking water for optimal focus",
                        color: .blue
                    )
                }

                // If no insights
                if tracker.calculateSynergy() == 1.0 &&
                   (tracker.activeLevels[.caffeine] ?? 0) < 50 &&
                   (tracker.activeLevels[.lTheanine] ?? 0) < 50 {
                    Text("Log substances to see personalized insights")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.lightSoil)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.yellow.opacity(0.6), lineWidth: 2)
                )
        )
    }
}

/// Individual insight row with icon and text
struct InsightRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)

            Text(text)
                .font(AppFont.body())
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Warning Banner View

/// Displays safety warnings prominently at top of view
/// Color-coded based on severity: yellow (caution) → orange (warning) → red (danger) → purple (emergency)
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
                        .font(AppFont.bodySmall())
                        .foregroundColor(textColorForWarning(warning))
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(backgroundColorForWarning(warning))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(borderColorForWarning(warning), lineWidth: 1)
                )
            }
        }
    }

    func iconForWarning(_ warning: String) -> String {
        if warning.contains("🚨") || warning.contains("DANGEROUS") {
            return "staroflife.fill"
        }
        if warning.contains("🔴") || warning.contains("Very high") {
            return "xmark.octagon.fill"
        }
        if warning.contains("CRITICAL") {
            return "exclamationmark.octagon.fill"
        }
        if warning.contains("⚠️") {
            return "exclamationmark.triangle.fill"
        }
        return "info.circle.fill"
    }

    func backgroundColorForWarning(_ warning: String) -> Color {
        if warning.contains("🚨") || warning.contains("DANGEROUS") {
            return Color.purple.opacity(0.15)
        }
        if warning.contains("🔴") || warning.contains("Very high") {
            return Color.red.opacity(0.15)
        }
        if warning.contains("CRITICAL") {
            return Color.red.opacity(0.2)
        }
        if warning.contains("⚠️") && (warning.contains("High") || warning.contains("exceeded")) {
            return Color.orange.opacity(0.15)
        }
        if warning.contains("⚠️") {
            return Color.yellow.opacity(0.15)
        }
        return Color.blue.opacity(0.1)
    }

    func borderColorForWarning(_ warning: String) -> Color {
        if warning.contains("🚨") || warning.contains("DANGEROUS") {
            return Color.purple.opacity(0.5)
        }
        if warning.contains("🔴") || warning.contains("Very high") {
            return Color.red.opacity(0.5)
        }
        if warning.contains("CRITICAL") {
            return Color.red.opacity(0.6)
        }
        if warning.contains("⚠️") && (warning.contains("High") || warning.contains("exceeded")) {
            return Color.orange.opacity(0.5)
        }
        if warning.contains("⚠️") {
            return Color.yellow.opacity(0.5)
        }
        return Color.blue.opacity(0.3)
    }

    func textColorForWarning(_ warning: String) -> Color {
        if warning.contains("🚨") || warning.contains("DANGEROUS") {
            return Color.purple
        }
        if warning.contains("🔴") || warning.contains("Very high") {
            return Color.red
        }
        if warning.contains("CRITICAL") {
            return Color.red
        }
        if warning.contains("⚠️") && (warning.contains("High") || warning.contains("exceeded")) {
            return Color.orange
        }
        if warning.contains("⚠️") {
            return Color(red: 0.6, green: 0.5, blue: 0.0)  // Dark yellow
        }
        return Color.blue
    }
}

// MARK: - String Extension

@available(iOS 13.0, *)
extension String: @retroactive Identifiable {
    public var id: String { self }
}
