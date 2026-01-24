import SwiftUI

struct HomeView: View {
    @StateObject private var sessionViewModel = FocusSessionViewModel()
    @StateObject private var gardenViewModel = GardenViewModel()
    @StateObject private var decayManager = PlantDecayManager.shared

    // Algorithm Engine Integrations
    private let gamificationEngine = GamificationEngine.shared
    @ObservedObject private var fatigueEngine = FatigueDetectionEngine.shared
    @ObservedObject private var healthKitManager = HealthKitManager.shared
    @ObservedObject private var plantHealthManager = PlantHealthManager.shared
    @ObservedObject private var streakManager = StreakManager.shared

    @State private var showSessionInput = false
    @State private var showRescueSheet = false
    @State private var selectedPlant: Plant? = nil
    @State private var showCreateGarden = false
    @State private var editingGarden: Garden? = nil
    @State private var showDeleteAlert = false
    @State private var gardenToDelete: Garden? = nil
    @State private var headerAppeared = false
    @State private var currentInsight: String? = nil
    @State private var flowReadiness: Int = 0
    @State private var behavioralAssessment: BehavioralFlowDetector.ReadinessAssessment?
    @State private var showingSettings = false

    // Biometric source upgrade banner
    @State private var pendingSourceChange: BiometricSourceChange?
    @State private var showSourceBanner = false

    var body: some View {
        NavigationView {
            ZStack {
                // MARK: - Background Gradient
                LinearGradient(
                    colors: [OnLifeColors.deepForest, OnLifeColors.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Header
                    headerView
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, Spacing.md)

                    // MARK: - Content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: Spacing.lg) {
                            // MARK: - Stats & Streak Section
                            statsSection
                                .padding(.horizontal, Spacing.lg)

                            // MARK: - Garden Health Card (Loss Aversion)
                            if plantHealthManager.gardenHealthSummary != nil {
                                GardenHealthCard(onTapRescue: {
                                    showRescueSheet = true
                                    Haptics.warning()
                                })
                                .padding(.horizontal, Spacing.lg)
                            }

                            // MARK: - AI Insight Card (if available)
                            if let insight = currentInsight {
                                InsightCardView(insight: insight)
                                    .padding(.horizontal, Spacing.lg)
                            }

                            // MARK: - Flow Readiness Indicator
                            flowReadinessSection
                                .padding(.horizontal, Spacing.lg)

                            if gardenViewModel.gardens.isEmpty {
                                // No gardens - show empty state
                                EmptyGardensCarouselView(onCreateGarden: {
                                    showCreateGarden = true
                                })
                            } else {
                                // Garden Carousel
                                GardenCarouselView(
                                    gardens: gardenViewModel.gardens,
                                    selectedGarden: Binding(
                                        get: { gardenViewModel.selectedGarden },
                                        set: { garden in
                                            if let garden = garden {
                                                gardenViewModel.selectGarden(id: garden.id)
                                            }
                                        }
                                    ),
                                    gardenViewModel: gardenViewModel,
                                    onEdit: { garden in
                                        editingGarden = garden
                                        Haptics.light()
                                    },
                                    onDelete: { garden in
                                        gardenToDelete = garden
                                        showDeleteAlert = true
                                        Haptics.light()
                                    }
                                )
                                .padding(.horizontal, -Spacing.lg) // Allow full bleed for carousel

                                // MARK: - Premium 3D Garden Experience
                                if let selectedGarden = gardenViewModel.selectedGarden {
                                    let plants = gardenViewModel.plants(for: selectedGarden.id)
                                    if !plants.isEmpty {
                                        // Immersive 3D Garden View
                                        GeometryReader { geometry in
                                            GardenExperienceView(gardenViewModel: gardenViewModel)
                                                .frame(height: geometry.size.height)
                                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                                        }
                                        .frame(height: 450) // Fixed height for garden view
                                        .padding(.top, Spacing.sm)
                                    } else {
                                        EmptyGardenPlantsView(
                                            gardenName: selectedGarden.name,
                                            onStartSession: {
                                                showSessionInput = true
                                            }
                                        )
                                        .frame(minHeight: 300)
                                        .padding(.top, Spacing.md)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, 120) // Space for FAB
                    }
                }

                // MARK: - FAB (Floating Action Button)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        fabButton
                            .padding(.trailing, Spacing.lg)
                            .padding(.bottom, Spacing.xxl)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showSessionInput) {
            SessionInputView(viewModel: sessionViewModel, gardenViewModel: gardenViewModel)
        }
        .fullScreenCover(isPresented: $sessionViewModel.isSessionActive) {
            FocusSessionView(viewModel: sessionViewModel)
        }
        .fullScreenCover(isPresented: $sessionViewModel.showBreathingExercise) {
            GuidedBreathingView(
                onComplete: { sessionViewModel.onBreathingComplete() },
                onSkip: { sessionViewModel.onBreathingSkipped() }
            )
        }
        .sheet(item: $selectedPlant) { plant in
            PlantDetailView(plant: plant)
        }
        .sheet(isPresented: $showCreateGarden) {
            CreateGardenSheet(gardenViewModel: gardenViewModel, isPresented: $showCreateGarden)
        }
        .sheet(item: $editingGarden) { garden in
            EditGardenSheet(
                gardenViewModel: gardenViewModel,
                garden: garden,
                isPresented: Binding(
                    get: { editingGarden != nil },
                    set: { if !$0 { editingGarden = nil } }
                )
            )
        }
        .sheet(isPresented: $showRescueSheet) {
            PlantRescueView(
                plantsToRescue: plantHealthManager.getCriticalPlants(),
                onStartSession: {
                    showSessionInput = true
                }
            )
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                SettingsView()
            }
        }
        .overlay {
            // Streak saved alert (freeze used)
            if streakManager.showStreakSavedAlert {
                StreakSavedAlert(
                    isPresented: $streakManager.showStreakSavedAlert,
                    freezesRemaining: streakManager.streakData.freezesAvailable,
                    currentStreak: streakManager.streakData.currentStreak
                )
            }

            // Streak milestone celebration
            if let milestone = streakManager.recentMilestone {
                StreakMilestoneAlert(milestone: milestone) {
                    streakManager.recentMilestone = nil
                }
            }
        }
        .overlay(alignment: .top) {
            // Biometric source upgrade banner
            if showSourceBanner, let change = pendingSourceChange {
                BiometricSourceBanner(
                    change: change,
                    onSwitch: {
                        BiometricSourceManager.shared.setPreferredSource(change.to)
                        withAnimation(OnLifeAnimation.elegant) {
                            showSourceBanner = false
                        }
                        pendingSourceChange = nil
                    },
                    onDismiss: {
                        withAnimation(OnLifeAnimation.elegant) {
                            showSourceBanner = false
                        }
                        pendingSourceChange = nil
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert("Delete Garden", isPresented: $showDeleteAlert, presenting: gardenToDelete) { garden in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                gardenViewModel.deleteGarden(garden)
                Haptics.success()
            }
        } message: { garden in
            Text("Are you sure you want to delete \"\(garden.name)\"? This will also delete all \(gardenViewModel.plants(for: garden.id).count) plants in this garden.")
        }
        .onAppear {
            print("🏠 HomeView appeared")
            gardenViewModel.refreshGardens()
            sessionViewModel.currentGarden = gardenViewModel.selectedGarden

            // Fetch sleep data from HealthKit
            healthKitManager.fetchLastNightSleep()

            // Calculate initial flow readiness
            calculateFlowReadiness()
            updateBehavioralAssessment()

            // Update plant health tracking
            syncPlantHealthTracking()
            plantHealthManager.updateAllPlantHealth()

            // Check for streak freeze refresh (monthly)
            streakManager.checkMonthlyRefresh()

            withAnimation(OnLifeAnimation.elegant) {
                headerAppeared = true
            }
        }
        .onChange(of: healthKitManager.lastNightSleep?.score) { _, _ in
            // Recalculate when sleep data loads
            calculateFlowReadiness()
            updateBehavioralAssessment()
        }
        .onChange(of: sessionViewModel.sessionPhase) { oldValue, newValue in
            if newValue == .input {
                print("🔄 Session completed, refreshing gardens...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    gardenViewModel.refreshGardens()
                }
            }
        }
        .onChange(of: decayManager.needsUpdate) { oldValue, newValue in
            if newValue {
                print("🔄 Decay update detected in HomeView, refreshing gardens...")
                gardenViewModel.refreshGardens()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectGardenFromWatch)) { notification in
            if let gardenId = notification.userInfo?["gardenId"] as? UUID {
                print("🏠 [HomeView] Received garden selection from Watch: \(gardenId)")
                gardenViewModel.selectGarden(id: gardenId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .BiometricSourceUpgradeAvailable)) { notification in
            if let change = notification.object as? BiometricSourceChange {
                print("💓 [HomeView] Better biometric source available: \(change.from.displayName) → \(change.to.displayName)")
                pendingSourceChange = change
                withAnimation(OnLifeAnimation.celebration) {
                    showSourceBanner = true
                }
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Welcome back")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)

                Text("Your Gardens")
                    .font(OnLifeFont.display())
                    .foregroundColor(OnLifeColors.textPrimary)
            }
            .opacity(headerAppeared ? 1 : 0)
            .offset(y: headerAppeared ? 0 : -10)

            Spacer()

            HStack(spacing: Spacing.sm) {
                // Create Garden Button
                Button(action: {
                    showCreateGarden = true
                    Haptics.light()
                }) {
                    ZStack {
                        Circle()
                            .fill(OnLifeColors.sage.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(OnLifeColors.sage)
                    }
                }

                // Settings Button
                Button(action: {
                    showingSettings = true
                    Haptics.light()
                }) {
                    ZStack {
                        Circle()
                            .fill(OnLifeColors.textTertiary.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }
            }
            .opacity(headerAppeared ? 1 : 0)
            .scaleEffect(headerAppeared ? 1 : 0.8)
        }
    }

    // MARK: - FAB Button

    private var fabButton: some View {
        Button(action: {
            Haptics.impact(.medium)
            showSessionInput = true
        }) {
            ZStack {
                Circle()
                    .fill(OnLifeColors.amber)
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: OnLifeColors.amber.opacity(0.4),
                        radius: 16,
                        y: 8
                    )

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(OnLifeColors.deepForest)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Stats Section (Streak & Orbs)

    private var statsSection: some View {
        HStack(spacing: Spacing.md) {
            // Streak Card
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text("🔥")
                        .font(.system(size: 20))
                    Text("\(gamificationEngine.stats.currentStreak)")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)
                }
                Text("day streak")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )

            // Orbs Card
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text("✨")
                        .font(.system(size: 20))
                    Text("\(gamificationEngine.stats.totalLifeOrbs)")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)
                }
                Text("orbs earned")
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
        }
    }

    // MARK: - Flow Readiness Section

    private var flowReadinessSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Flow Readiness")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                // Score badge
                Text("\(flowReadiness)%")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(flowReadinessColor)
            }

            VStack(spacing: Spacing.sm) {
                // Main readiness indicator
                HStack(spacing: Spacing.md) {
                    Text(flowReadinessEmoji)
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(flowReadinessTitle)
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(flowReadinessColor)

                        Text(flowReadinessSubtitle)
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }

                    Spacer()
                }

                Divider()
                    .background(OnLifeColors.textTertiary.opacity(0.3))

                // Contributing factors row
                HStack(spacing: Spacing.md) {
                    // Sleep quality indicator
                    if let sleep = healthKitManager.lastNightSleep, sleep.totalHours > 0 {
                        HStack(spacing: Spacing.xs) {
                            Text(sleep.qualityEmoji)
                                .font(.system(size: 14))
                            Text("\(Int(sleep.score))")
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textSecondary)
                        }
                    } else {
                        HStack(spacing: Spacing.xs) {
                            Text("💤")
                                .font(.system(size: 14))
                            Text("--")
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textTertiary)
                        }
                    }

                    // Fatigue indicator
                    if let fatigue = fatigueEngine.currentFatigueLevel {
                        HStack(spacing: Spacing.xs) {
                            Text(fatigue.level.icon)
                                .font(.system(size: 14))
                            Text(fatigue.level.rawValue)
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textSecondary)
                        }
                    } else {
                        HStack(spacing: Spacing.xs) {
                            Text("⚡️")
                                .font(.system(size: 14))
                            Text("Fresh")
                                .font(OnLifeFont.caption())
                                .foregroundColor(OnLifeColors.textSecondary)
                        }
                    }

                    // Caffeine level
                    let caffeine = CorrectedPharmacokineticsEngine.shared.calculateActiveLevel(for: .caffeine)
                    HStack(spacing: Spacing.xs) {
                        Text("☕️")
                            .font(.system(size: 14))
                        Text(caffeine > 0 ? "\(Int(caffeine))mg" : "0mg")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }

                    Spacer()
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(OnLifeColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .stroke(flowReadinessColor.opacity(0.3), lineWidth: 1)
            )

            // Optimal Focus Time Card (if chronotype available)
            if let chronotypeResult = ChronotypeInferenceEngine.shared.storedResult {
                OptimalFocusTimeCard(chronotypeResult: chronotypeResult)
            }

            // Behavioral Flow Insights (for users building history)
            if let assessment = behavioralAssessment,
               BehavioralFeatureCollector.shared.currentFeatures.consecutiveDays > 0 ||
               BehavioralFeatureCollector.shared.currentFeatures.completionRateLast7Days > 0 {
                BehavioralInsightRow(assessment: assessment, features: BehavioralFeatureCollector.shared.currentFeatures)
            }
        }
    }

    // MARK: - Flow Readiness Calculation

    private func calculateFlowReadiness() {
        var score = 0.0

        // 1. Sleep Quality (0-40 points) - 40% weight
        if let sleep = healthKitManager.lastNightSleep, sleep.totalHours > 0 {
            let sleepScore = sleep.score * 0.40
            score += sleepScore
            print("🎯 [FlowReadiness] Sleep: \(Int(sleep.score))/100 -> \(String(format: "%.1f", sleepScore)) points")
        } else {
            // Default moderate score if no sleep data
            score += 25.0
            print("🎯 [FlowReadiness] Sleep: No data -> 25 points (default)")
        }

        // 2. Fatigue Level (0-30 points) - 30% weight
        let fatigueScore: Double
        if let fatigue = fatigueEngine.currentFatigueLevel {
            switch fatigue.level {
            case .fresh:
                fatigueScore = 30.0
            case .mild:
                fatigueScore = 25.0
            case .moderate:
                fatigueScore = 15.0
            case .high:
                fatigueScore = 8.0
            case .severe:
                fatigueScore = 3.0
            }
        } else {
            // No fatigue detected = fresh
            fatigueScore = 30.0
        }
        score += fatigueScore
        print("🎯 [FlowReadiness] Fatigue: \(fatigueEngine.currentFatigueLevel?.level.rawValue ?? "Fresh") -> \(String(format: "%.1f", fatigueScore)) points")

        // 3. Caffeine Timing (0-20 points) - 20% weight
        let caffeineLevel = CorrectedPharmacokineticsEngine.shared.calculateActiveLevel(for: .caffeine)
        let caffeineScore: Double
        if caffeineLevel >= 50 && caffeineLevel <= 150 {
            // Peak window - optimal
            caffeineScore = 20.0
        } else if caffeineLevel > 0 && caffeineLevel < 50 {
            // Building up
            caffeineScore = 12.0
        } else if caffeineLevel > 150 && caffeineLevel <= 300 {
            // Slightly too much
            caffeineScore = 12.0
        } else if caffeineLevel > 300 {
            // Too much - jitters
            caffeineScore = 5.0
        } else {
            // No caffeine is fine
            caffeineScore = 15.0
        }
        score += caffeineScore
        print("🎯 [FlowReadiness] Caffeine: \(Int(caffeineLevel))mg -> \(String(format: "%.1f", caffeineScore)) points")

        // 4. Time of Day with Chronotype (0-10 points) - 10% weight
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        var timeScore: Double = 7.0 // Default

        // Use chronotype if available for personalized scoring
        if let chronotypeResult = ChronotypeInferenceEngine.shared.storedResult {
            let chronotype = chronotypeResult.chronotype
            let multiplier = ChronotypeInferenceEngine.shared.getCircadianMultiplier(
                chronotype: chronotype,
                hour: currentHour
            )

            // Base score of 7, adjusted by circadian multiplier (0.75-1.1)
            timeScore = 7.0 * multiplier

            // Bonus if in peak window
            if ChronotypeInferenceEngine.shared.isOptimalTime(chronotype: chronotype) {
                timeScore = 10.0
            }

            print("🎯 [FlowReadiness] Time: \(currentHour):00 (Chronotype: \(chronotype.shortName), multiplier: \(String(format: "%.2f", multiplier))) -> \(String(format: "%.1f", timeScore)) points")
        } else {
            // Fallback to generic time-of-day scoring
            if currentHour >= 9 && currentHour <= 11 {
                timeScore = 10.0
            } else if currentHour >= 14 && currentHour <= 16 {
                timeScore = 10.0
            } else if currentHour >= 12 && currentHour <= 13 {
                timeScore = 5.0
            } else if currentHour >= 7 && currentHour < 9 {
                timeScore = 7.0
            } else if currentHour >= 17 && currentHour <= 19 {
                timeScore = 6.0
            } else if currentHour >= 20 || currentHour <= 6 {
                timeScore = 3.0
            }
            print("🎯 [FlowReadiness] Time: \(currentHour):00 (No chronotype) -> \(String(format: "%.1f", timeScore)) points")
        }
        score += timeScore

        flowReadiness = Int(min(100, max(0, score)))
        print("🎯 [FlowReadiness] TOTAL: \(flowReadiness)/100")
    }

    // MARK: - Plant Health Sync

    private func syncPlantHealthTracking() {
        // Sync plant health tracking with actual plants in gardens
        for garden in gardenViewModel.gardens {
            let plants = gardenViewModel.plants(for: garden.id)
            for plant in plants {
                plantHealthManager.trackPlant(id: plant.id)
            }
        }
    }

    // MARK: - Behavioral Flow Assessment

    private func updateBehavioralAssessment() {
        // Collect behavioral features from session history
        BehavioralFeatureCollector.shared.analyzePreSession(
            sessions: GardenDataManager.shared.loadSessions()
        )

        // Generate assessment
        let features = BehavioralFeatureCollector.shared.currentFeatures
        behavioralAssessment = BehavioralFlowDetector.shared.assessReadiness(features: features)

        if let assessment = behavioralAssessment {
            print("📊 [BehavioralFlow] Score: \(Int(assessment.flowProbability)), Level: \(assessment.level.rawValue)")
        }
    }

    // MARK: - Flow Readiness Display Properties

    private var flowReadinessEmoji: String {
        if flowReadiness >= 80 {
            return "⚡️"
        } else if flowReadiness >= 60 {
            return "🟢"
        } else if flowReadiness >= 40 {
            return "🟡"
        } else {
            return "🔴"
        }
    }

    private var flowReadinessTitle: String {
        if flowReadiness >= 80 {
            return "Peak Performance"
        } else if flowReadiness >= 60 {
            return "Ready to Focus"
        } else if flowReadiness >= 40 {
            return "Moderate Readiness"
        } else {
            return "Recovery Recommended"
        }
    }

    private var flowReadinessSubtitle: String {
        if flowReadiness >= 80 {
            return "Optimal conditions for deep work"
        } else if flowReadiness >= 60 {
            return "Good time to start a focus session"
        } else if flowReadiness >= 40 {
            return "Consider a caffeine boost or short break"
        } else {
            return "Rest or light tasks recommended"
        }
    }

    private var flowReadinessColor: Color {
        if flowReadiness >= 80 {
            return OnLifeColors.sage
        } else if flowReadiness >= 60 {
            return .blue
        } else if flowReadiness >= 40 {
            return OnLifeColors.amber
        } else {
            return OnLifeColors.terracotta
        }
    }

}

// MARK: - Optimal Focus Time Card

struct OptimalFocusTimeCard: View {
    let chronotypeResult: ChronotypeInferenceResult

    private var isInOptimalWindow: Bool {
        ChronotypeInferenceEngine.shared.isOptimalTime(chronotype: chronotypeResult.chronotype)
    }

    private var focusRecommendation: String {
        if isInOptimalWindow {
            return "Now is your optimal focus time!"
        }

        if let nextWindow = ChronotypeInferenceEngine.shared.getNextOptimalWindow(
            chronotype: chronotypeResult.chronotype
        ) {
            let calendar = Calendar.current
            let now = Date()
            let hoursUntil = calendar.dateComponents([.hour, .minute], from: now, to: nextWindow)

            if let hours = hoursUntil.hour, let minutes = hoursUntil.minute {
                if hours > 0 {
                    return "Optimal window in \(hours)h \(minutes)m"
                } else if minutes > 0 {
                    return "Optimal window in \(minutes)m"
                }
            }
        }

        return "Check back for your next optimal window"
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Chronotype icon
            Text(chronotypeResult.chronotype.icon)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("Optimal Focus Time")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)

                    if isInOptimalWindow {
                        Text("NOW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(OnLifeColors.sage)
                            )
                    }
                }

                Text(focusRecommendation)
                    .font(OnLifeFont.body())
                    .fontWeight(.medium)
                    .foregroundColor(isInOptimalWindow ? OnLifeColors.sage : OnLifeColors.textPrimary)
            }

            Spacer()

            // Arrow or checkmark
            Image(systemName: isInOptimalWindow ? "checkmark.circle.fill" : "clock")
                .font(.system(size: 20))
                .foregroundColor(isInOptimalWindow ? OnLifeColors.sage : OnLifeColors.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(isInOptimalWindow ? OnLifeColors.sage.opacity(0.1) : OnLifeColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .stroke(isInOptimalWindow ? OnLifeColors.sage.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Behavioral Insight Row

struct BehavioralInsightRow: View {
    let assessment: BehavioralFlowDetector.ReadinessAssessment
    let features: BehavioralFeatures

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Behavioral score indicator
            ZStack {
                Circle()
                    .fill(assessment.level.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Text(assessment.level.emoji)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.sm) {
                    Text("Behavioral Flow")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)

                    Text("\(Int(assessment.flowProbability))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(assessment.level.color)
                }

                // Show key positive factor
                if features.consecutiveDays >= 3 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(OnLifeColors.amber)
                        Text("\(features.consecutiveDays) day streak")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                } else if features.completionRateLast7Days >= 0.7 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(OnLifeColors.sage)
                        Text("\(Int(features.completionRateLast7Days * 100))% completion rate")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                } else if features.sameTimeOfDayAsUsual {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 10))
                            .foregroundColor(OnLifeColors.sage)
                        Text("Consistent timing")
                            .font(OnLifeFont.caption())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                }
            }

            Spacer()

            // Level indicator
            Text(assessment.level.rawValue)
                .font(OnLifeFont.caption())
                .foregroundColor(assessment.level.color)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }
}

// MARK: - Insight Card View

struct InsightCardView: View {
    let insight: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("💡")
                    .font(.system(size: 18))
                Text("Insight")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)
                Spacer()
            }

            Text(insight)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)
                .lineLimit(3)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.sage.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .stroke(OnLifeColors.sage.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Garden Card

struct GardenCard: View {
    let garden: Garden
    let plantCount: Int
    let totalFocusTime: String
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var scale: CGFloat = 0.95
    @State private var opacity: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                // Garden icon
                Text(garden.icon)
                    .font(.system(size: 44))

                VStack(alignment: .leading, spacing: 4) {
                    Text(garden.name)
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("\(plantCount) plants")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                Spacer()

                // Focus time
                VStack(alignment: .trailing, spacing: 4) {
                    Text(totalFocusTime)
                        .font(OnLifeFont.heading3())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("total focus")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
        .shadow(
            color: Color.black.opacity(0.15),
            radius: 8,
            y: 4
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(OnLifeAnimation.elegant) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .contextMenu {
            Button(action: {
                onEdit?()
            }) {
                Label("Edit Garden", systemImage: "pencil")
            }

            if onDelete != nil {
                Button(role: .destructive, action: {
                    onDelete?()
                }) {
                    Label("Delete Garden", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Plants Grid View

struct PlantsGridView: View {
    let plants: [Plant]
    var gardenName: String = "Your"
    @Binding var selectedPlant: Plant?

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            Text("Plants in \(gardenName)")
                .font(OnLifeFont.heading2())
                .foregroundColor(OnLifeColors.textPrimary)
                .padding(.leading, Spacing.xs)

            // Grid with 2 columns
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(Array(plants.enumerated()), id: \.element.id) { index, plant in
                    PlantGridCard(plant: plant) {
                        selectedPlant = plant
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05),
                        value: plants.count
                    )
                }
            }
        }
    }
}

