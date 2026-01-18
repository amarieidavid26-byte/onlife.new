import SwiftUI

// MARK: - Scientific Citations
/*
 Guided Breathing View - Research-Validated Parameters

 CITATIONS:
 1. Laborde S, et al. (2022) Frontiers in Psychology - Meta-analysis
    - Optimal rate: 5-6 breaths per minute for HRV improvement
    - Resonance frequency breathing maximizes vagal tone

 2. Bentley T, et al. (2023) Applied Psychophysiology and Biofeedback
    - Minimum duration: 5 minutes for measurable effect
    - Sessions under 5 minutes show no significant benefit

 3. Balban MY, et al. (2023) Cell Reports Medicine - "Cyclic Sighing"
    - Extended exhale (longer than inhale) enhances calming effect
    - 5-minute sessions reduce anxiety and improve mood

 4. Lehrer PM, Gevirtz R (2014) Frontiers in Psychology
    - Resonance frequency (~0.1 Hz / 6 bpm) maximizes baroreflex gain
    - 2-3 minute transition before cognitive task recommended
 */

struct GuidedBreathingView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Research-Validated Configuration

    /// Optimal breathing rate (Laborde 2022 meta-analysis: 5-6 bpm)
    let breathsPerMinute: Double = 5.5

    /// Minimum effective duration (Bentley 2023: <5 min ineffective)
    let minimumDuration: TimeInterval = 300  // 5 minutes

    /// Recommended duration for optimal effect
    let recommendedDuration: TimeInterval = 300

    // MARK: - State

    @State private var isBreathing = false
    @State private var breathPhase: BreathPhase = .idle
    @State private var elapsedTime: TimeInterval = 0
    @State private var breathCount: Int = 0
    @State private var animationScale: CGFloat = 0.6
    @State private var showSkipWarning = false
    @State private var timer: Timer?

    // MARK: - Callbacks

    var onComplete: () -> Void
    var onSkip: () -> Void

    // MARK: - Computed Properties

    /// Duration of one complete breath cycle (~10.9 seconds at 5.5 bpm)
    private var breathCycleDuration: Double {
        60.0 / breathsPerMinute
    }

    /// Inhale duration - 45% of cycle (~4.9 seconds)
    private var inhaleDuration: Double {
        breathCycleDuration * 0.45
    }

    /// Exhale duration - 55% of cycle (~6 seconds)
    /// Research: Extended exhale enhances parasympathetic activation
    private var exhaleDuration: Double {
        breathCycleDuration * 0.55
    }

    /// Progress toward minimum duration (0-1)
    private var progress: Double {
        min(1.0, elapsedTime / minimumDuration)
    }

    /// Whether minimum duration has been reached
    private var canComplete: Bool {
        elapsedTime >= minimumDuration
    }

    // MARK: - Breath Phase

    enum BreathPhase {
        case idle
        case inhale
        case exhale

        var instruction: String {
            switch self {
            case .idle: return "Tap to begin"
            case .inhale: return "Breathe in..."
            case .exhale: return "Breathe out..."
            }
        }

        var color: Color {
            switch self {
            case .idle: return OnLifeColors.textSecondary
            case .inhale: return OnLifeColors.sage        // Calming green on inhale
            case .exhale: return OnLifeColors.deepForest  // Deeper green on exhale
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            OnLifeColors.deepForest
                .ignoresSafeArea()

            VStack(spacing: Spacing.xxxl) {
                // Header
                headerSection

                Spacer()

                // Breathing Circle
                breathingCircle

                Spacer()

                // Timer and controls
                controlsSection
            }
            .padding()
        }
        .alert("Skip Breathing Exercise?", isPresented: $showSkipWarning) {
            Button("Continue Breathing", role: .cancel) { }
            Button("Skip Anyway", role: .destructive) {
                stopBreathing()
                onSkip()
            }
        } message: {
            Text("Research shows breathing exercises under 5 minutes are ineffective for focus preparation. We recommend completing the full session.")
        }
        .onDisappear {
            stopBreathing()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.sm) {
            Text("Prepare Your Mind")
                .font(OnLifeFont.heading1())
                .foregroundColor(OnLifeColors.textPrimary)

            Text("5-6 breaths per minute activates your parasympathetic nervous system")
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
        }
        .padding(.top, Spacing.xl)
    }

    // MARK: - Breathing Circle

    private var breathingCircle: some View {
        ZStack {
            // Outer progress ring
            Circle()
                .stroke(OnLifeColors.cardBackground, lineWidth: 8)
                .frame(width: 250, height: 250)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    OnLifeColors.sage,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)

            // Breathing circle (animates)
            Circle()
                .fill(breathPhase.color.opacity(0.2))
                .frame(width: 200, height: 200)
                .scaleEffect(animationScale)

            Circle()
                .stroke(breathPhase.color, lineWidth: 3)
                .frame(width: 200, height: 200)
                .scaleEffect(animationScale)

            // Center content
            VStack(spacing: Spacing.sm) {
                Text(breathPhase.instruction)
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .animation(.easeInOut(duration: 0.3), value: breathPhase)

                if isBreathing {
                    Text("\(breathCount) breaths")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }
        }
        .onTapGesture {
            if !isBreathing {
                startBreathing()
            }
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: Spacing.lg) {
            // Time display
            HStack(spacing: Spacing.xs) {
                Text(formatTime(elapsedTime))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("/ \(formatTime(minimumDuration))")
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(OnLifeColors.textSecondary)
            }

            // Research note
            if !canComplete && isBreathing {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("Minimum 5 minutes for effectiveness")
                        .font(OnLifeFont.caption())
                }
                .foregroundColor(OnLifeColors.amber)
            }

            // Buttons
            HStack(spacing: Spacing.md) {
                // Skip button
                Button {
                    if elapsedTime < 60 {
                        showSkipWarning = true
                    } else {
                        stopBreathing()
                        onSkip()
                    }
                } label: {
                    Text("Skip")
                        .font(OnLifeFont.button())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .frame(width: 100, height: 50)
                        .background(OnLifeColors.cardBackground)
                        .cornerRadius(CornerRadius.medium)
                }

                // Complete button
                Button {
                    if canComplete {
                        stopBreathing()
                        onComplete()
                    }
                } label: {
                    Text(canComplete ? "I'm Ready" : "Keep Breathing")
                        .font(OnLifeFont.button())
                        .foregroundColor(canComplete ? OnLifeColors.deepForest : OnLifeColors.textSecondary)
                        .frame(width: 160, height: 50)
                        .background(canComplete ? OnLifeColors.sage : OnLifeColors.cardBackground)
                        .cornerRadius(CornerRadius.medium)
                }
                .disabled(!canComplete)
                .animation(.easeInOut, value: canComplete)
            }
        }
        .padding(.bottom, Spacing.xxxl)
    }

    // MARK: - Breathing Logic

    private func startBreathing() {
        isBreathing = true
        breathPhase = .inhale
        breathCount = 0
        elapsedTime = 0
        startBreathCycle()
        startTimer()

        // Initial haptic
        HapticManager.shared.impact(style: .medium)

        print("🌬️ [Breathing] Started - Rate: \(breathsPerMinute) bpm, Cycle: \(String(format: "%.1f", breathCycleDuration))s")
    }

    private func stopBreathing() {
        isBreathing = false
        breathPhase = .idle
        timer?.invalidate()
        timer = nil

        print("🌬️ [Breathing] Stopped - Duration: \(formatTime(elapsedTime)), Breaths: \(breathCount)")
    }

    private func startBreathCycle() {
        guard isBreathing else { return }

        // INHALE PHASE
        breathPhase = .inhale
        withAnimation(.easeInOut(duration: inhaleDuration)) {
            animationScale = 1.0
        }

        // Haptic on inhale start
        HapticManager.shared.impact(style: .light)

        // Schedule exhale
        DispatchQueue.main.asyncAfter(deadline: .now() + inhaleDuration) { [self] in
            guard self.isBreathing else { return }

            // EXHALE PHASE
            self.breathPhase = .exhale
            withAnimation(.easeInOut(duration: self.exhaleDuration)) {
                self.animationScale = 0.6
            }

            // Softer haptic on exhale
            HapticManager.shared.impact(style: .soft)

            self.breathCount += 1

            // Schedule next cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + self.exhaleDuration) {
                self.startBreathCycle()
            }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] t in
            if self.isBreathing {
                self.elapsedTime += 1

                // Celebratory haptic when minimum reached
                if self.elapsedTime == self.minimumDuration {
                    HapticManager.shared.notification(type: .success)
                }
            } else {
                t.invalidate()
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview {
    GuidedBreathingView(
        onComplete: { print("Complete") },
        onSkip: { print("Skip") }
    )
}
