import SwiftUI

/*
 Metabolism Profile Onboarding Flow

 Multi-step onboarding to collect user metabolism profile data for personalized substance tracking.

 Steps:
 1. Welcome - Explain personalization benefits
 2. Demographics - Age, weight, height, sex
 3. Health Status - Contraceptives, smoking, pregnancy, medications (safety-critical)
 4. Caffeine Tolerance - Daily caffeine intake habits
 5. Lifestyle - Sleep quality
 6. Metabolism Speed - Self-assessed metabolic rate
 7. Summary - Review and confirm profile

 SCIENTIFIC NOTE:
 - Oral contraceptives: 1.7× longer caffeine half-life (Abernethy & Todd 1985)
 - Smoking: 1.67× faster clearance (PubMed 15289794)
 - Pregnancy: Up to 2× longer half-life by third trimester (PMC5564294)
 - Fluvoxamine: 5-6× longer half-life (PubMed 8807660)
 */

struct MetabolismOnboardingFlow: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var profileManager = MetabolismProfileManager.shared

    @State private var currentStep = 0
    @State private var profile = UserMetabolismProfile.defaultProfile

    // Validation states
    @State private var ageError: String?
    @State private var weightError: String?
    @State private var heightError: String?

    let totalSteps = 7  // Updated: Added Health Status screen

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Indicator
                ProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.horizontal)
                    .padding(.top, Spacing.md)

                // Content
                TabView(selection: $currentStep) {
                    MetabolismWelcomeScreen()
                        .tag(0)

                    DemographicsScreen(
                        profile: $profile,
                        ageError: $ageError,
                        weightError: $weightError,
                        heightError: $heightError
                    )
                    .tag(1)

                    // NEW: Health Status screen (safety-critical factors)
                    HealthStatusScreen(profile: $profile)
                        .tag(2)

                    CaffeineToleranceScreen(profile: $profile)
                        .tag(3)

                    LifestyleScreen(profile: $profile)
                        .tag(4)

                    MetabolismSpeedScreen(profile: $profile)
                        .tag(5)

                    SummaryScreen(profile: $profile)
                        .tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation Buttons
                HStack(spacing: Spacing.md) {
                    if currentStep > 0 {
                        Button(action: previousStep) {
                            Text("Back")
                                .font(OnLifeFont.button())
                                .foregroundColor(OnLifeColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .fill(OnLifeColors.cardBackground)
                                )
                        }
                    }

                    Button(action: nextStep) {
                        Text(currentStep == totalSteps - 1 ? "Complete" : (currentStep == 0 ? "Get Started" : "Continue"))
                            .font(OnLifeFont.button())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .fill(canProceed ? OnLifeColors.sage : OnLifeColors.cardBackground)
                            )
                    }
                    .disabled(!canProceed)
                }
                .padding()
                .background(OnLifeColors.surface)
            }
            .background(OnLifeColors.deepForest)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Navigation Logic

    func nextStep() {
        // Update error messages for current step before proceeding
        if currentStep == 1 {
            updateDemographicsErrors()
        }

        // Only proceed if validation passes
        guard canProceed else { return }

        if currentStep == totalSteps - 1 {
            // Complete onboarding
            profileManager.updateProfile(profile)
            dismiss()
        } else {
            withAnimation {
                currentStep += 1
            }
        }
    }

    func previousStep() {
        withAnimation {
            currentStep -= 1
        }
    }

    var canProceed: Bool {
        switch currentStep {
        case 0: return true // Welcome screen
        case 1: return isDemographicsValid() // Demographics - pure validation, no state modification
        case 2: return true // Health status
        case 3: return true // Caffeine tolerance
        case 4: return true // Lifestyle
        case 5: return true // Metabolism speed
        case 6: return true // Summary
        default: return false
        }
    }

    // MARK: - Pure Validation (no state modification)

    /// Pure validation function - safe to call during view body computation
    func isDemographicsValid() -> Bool {
        let ageValid = profile.age >= 13 && profile.age <= 120
        let weightValid = profile.weight >= 30 && profile.weight <= 300
        let heightValid = profile.height == nil || (profile.height! >= 100 && profile.height! <= 250)
        return ageValid && weightValid && heightValid
    }

    // MARK: - Error State Updates (call on user action only)

    /// Updates error messages - call this on button tap or onChange, NOT during body computation
    func updateDemographicsErrors() {
        // Age validation
        if profile.age < 13 || profile.age > 120 {
            ageError = "Age must be between 13 and 120"
        } else {
            ageError = nil
        }

        // Weight validation
        if profile.weight < 30 || profile.weight > 300 {
            weightError = "Weight must be between 30 and 300 kg"
        } else {
            weightError = nil
        }

        // Height validation (optional but if provided must be valid)
        if let height = profile.height {
            if height < 100 || height > 250 {
                heightError = "Height must be between 100 and 250 cm"
            } else {
                heightError = nil
            }
        } else {
            heightError = nil
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Progress dots
            HStack(spacing: Spacing.xs) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? OnLifeColors.sage : OnLifeColors.cardBackground)
                        .frame(width: 8, height: 8)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(OnLifeColors.cardBackground)
                        .frame(height: 4)

                    Rectangle()
                        .fill(OnLifeColors.sage)
                        .frame(width: geometry.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 4)
                        .animation(.easeInOut, value: currentStep)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Metabolism Welcome Screen

struct MetabolismWelcomeScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Spacer()
                    .frame(height: Spacing.xl)

                // Icon
                Image(systemName: "person.fill.checkmark")
                    .font(.system(size: 80))
                    .foregroundColor(OnLifeColors.sage)

                // Title
                VStack(spacing: Spacing.sm) {
                    Text("Personalize Your Experience")
                        .font(OnLifeFont.heading1())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Help us understand your metabolism for accurate substance tracking")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Features
                VStack(alignment: .leading, spacing: Spacing.md) {
                    MetabolismFeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Personalized Tracking",
                        description: "Get accurate predictions based on your unique metabolism"
                    )

                    MetabolismFeatureRow(
                        icon: "clock.fill",
                        title: "Optimal Timing",
                        description: "Learn the best times to consume substances for peak focus"
                    )

                    MetabolismFeatureRow(
                        icon: "brain.head.profile",
                        title: "Smart Insights",
                        description: "Discover synergies and patterns in your substance use"
                    )

                    MetabolismFeatureRow(
                        icon: "lock.shield.fill",
                        title: "Private & Secure",
                        description: "Your data stays on your device - complete privacy"
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(OnLifeColors.cardBackground)
                )
                .padding(.horizontal)

                Spacer()
            }
        }
    }
}

struct MetabolismFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(OnLifeColors.sage)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OnLifeFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(description)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
            }
        }
    }
}

// MARK: - Demographics Screen

struct DemographicsScreen: View {
    @Binding var profile: UserMetabolismProfile
    @Binding var ageError: String?
    @Binding var weightError: String?
    @Binding var heightError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Header
                VStack(spacing: Spacing.sm) {
                    Text("Basic Demographics")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("This helps us calculate your personalized metabolism rate")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xl)

                // Age Input
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(OnLifeColors.sage)
                        Text("Age")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    TextField("Enter your age", value: $profile.age, format: .number)
                        .keyboardType(.numberPad)
                        .font(OnLifeFont.bodyLarge())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(OnLifeColors.surface)
                        )

                    if let error = ageError {
                        Text(error)
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(.red)
                    }

                    Text("Metabolism slows ~1-2% per decade after 30")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(OnLifeColors.cardBackground)
                )

                // Weight Input
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "scalemass")
                            .foregroundColor(OnLifeColors.sage)
                        Text("Weight (kg)")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    TextField("Enter your weight", value: $profile.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .font(OnLifeFont.bodyLarge())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(OnLifeColors.surface)
                        )

                    if let error = weightError {
                        Text(error)
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(.red)
                    }

                    Text("Used for allometric scaling (metabolism ∝ mass^0.75)")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(OnLifeColors.cardBackground)
                )

                // Height Input (Optional)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "ruler")
                            .foregroundColor(OnLifeColors.sage)
                        Text("Height (cm) - Optional")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    TextField("Enter your height", value: $profile.height, format: .number)
                        .keyboardType(.decimalPad)
                        .font(OnLifeFont.bodyLarge())
                        .foregroundColor(OnLifeColors.textPrimary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(OnLifeColors.surface)
                        )

                    if let error = heightError {
                        Text(error)
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(.red)
                    }

                    Text("Used to calculate BMI for better insights")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(OnLifeColors.cardBackground)
                )

                // Sex Picker
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "person.2")
                            .foregroundColor(OnLifeColors.sage)
                        Text("Biological Sex")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    Picker("Biological Sex", selection: $profile.sex) {
                        ForEach(BiologicalSex.allCases, id: \.self) { sex in
                            Text(sex.rawValue).tag(sex)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Males typically have 10-15% faster basal metabolic rate")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(OnLifeColors.cardBackground)
                )

                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Health Status Screen (Safety-Critical)

struct HealthStatusScreen: View {
    @Binding var profile: UserMetabolismProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Health Factors")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("These factors significantly affect caffeine metabolism and safety limits")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, Spacing.xl)

                // Smoking Status
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "smoke.fill")
                            .foregroundColor(OnLifeColors.sage)
                        Text("Smoking Status")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    ForEach(SmokingStatus.allCases, id: \.self) { status in
                        HealthStatusOption(
                            icon: status.icon,
                            title: status.rawValue,
                            subtitle: status.displayName,
                            isSelected: profile.smokingStatus == status,
                            onSelect: { profile.smokingStatus = status }
                        )
                    }

                    Text("Smoking significantly speeds up caffeine metabolism (1.67× faster)")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding()
                .background(OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Hormonal Contraceptives (only for female users)
                if profile.sex == .female {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Image(systemName: "pills.fill")
                                .foregroundColor(OnLifeColors.sage)
                            Text("Hormonal Contraceptives")
                                .font(OnLifeFont.body())
                                .fontWeight(.semibold)
                                .foregroundColor(OnLifeColors.textPrimary)
                        }

                        Toggle(isOn: $profile.usesHormonalContraceptives) {
                            Text("I use hormonal birth control")
                                .font(OnLifeFont.body())
                                .foregroundColor(OnLifeColors.textPrimary)
                        }
                        .tint(OnLifeColors.sage)

                        Text("Oral contraceptives nearly double caffeine half-life (1.7× longer)")
                            .font(OnLifeFont.bodySmall())
                            .foregroundColor(OnLifeColors.textTertiary)
                    }
                    .padding()
                    .background(OnLifeColors.cardBackground)
                    .cornerRadius(CornerRadius.medium)
                    .padding(.horizontal)
                }

                // Pregnancy Status (only for female users)
                if profile.sex == .female {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(OnLifeColors.sage)
                            Text("Pregnancy Status")
                                .font(OnLifeFont.body())
                                .fontWeight(.semibold)
                                .foregroundColor(OnLifeColors.textPrimary)
                        }

                        Toggle(isOn: $profile.isPregnant) {
                            Text("I am currently pregnant")
                                .font(OnLifeFont.body())
                                .foregroundColor(OnLifeColors.textPrimary)
                        }
                        .tint(OnLifeColors.sage)

                        if profile.isPregnant {
                            Text("Which trimester?")
                                .font(OnLifeFont.body())
                                .foregroundColor(OnLifeColors.textSecondary)
                                .padding(.top, Spacing.xs)

                            ForEach(PregnancyTrimester.allCases, id: \.self) { trimester in
                                HealthStatusOption(
                                    icon: "calendar",
                                    title: "Trimester \(trimester.rawValue)",
                                    subtitle: trimester.displayName,
                                    isSelected: profile.pregnancyTrimester == trimester,
                                    onSelect: { profile.pregnancyTrimester = trimester }
                                )
                            }
                        }

                        // Pregnancy warning
                        if profile.isPregnant {
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("ACOG/WHO recommends limiting caffeine to 200mg/day during pregnancy. Consult your healthcare provider.")
                                    .font(OnLifeFont.bodySmall())
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(CornerRadius.small)
                        }
                    }
                    .padding()
                    .background(OnLifeColors.cardBackground)
                    .cornerRadius(CornerRadius.medium)
                    .padding(.horizontal)
                }

                // Medication Interactions
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "cross.case.fill")
                            .foregroundColor(OnLifeColors.sage)
                        Text("Medications")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    Toggle(isOn: $profile.takesFluvoxamine) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fluvoxamine (Luvox)")
                                .font(OnLifeFont.body())
                                .foregroundColor(OnLifeColors.textPrimary)
                            Text("SSRI antidepressant")
                                .font(OnLifeFont.bodySmall())
                                .foregroundColor(OnLifeColors.textSecondary)
                        }
                    }
                    .tint(OnLifeColors.sage)

                    // Fluvoxamine warning
                    if profile.takesFluvoxamine {
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                            Text("⚠️ CRITICAL: Fluvoxamine increases caffeine half-life 5-6×. This is a severe interaction. Consult your healthcare provider before using this app.")
                                .font(OnLifeFont.bodySmall())
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(CornerRadius.small)
                    }

                    Text("Other medications that may interact: ciprofloxacin, clozapine, some antifungals")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                .padding()
                .background(OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Privacy note
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.blue)
                        Text("Privacy Note")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    Text("This health information is stored only on your device and is never shared. You can skip any question by leaving it as default.")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(OnLifeColors.deepForest)
    }
}

struct HealthStatusOption: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : OnLifeColors.sage)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OnLifeFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : OnLifeColors.textPrimary)

                    Text(subtitle)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(isSelected ? .white.opacity(0.8) : OnLifeColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .background(isSelected ? OnLifeColors.sage.opacity(0.8) : Color.clear)
            .cornerRadius(CornerRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Caffeine Tolerance Screen

struct CaffeineToleranceScreen: View {
    @Binding var profile: UserMetabolismProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Caffeine Consumption")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("This helps us understand your caffeine sensitivity (but doesn't affect metabolism speed)")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, Spacing.xl)

                VStack(spacing: Spacing.md) {
                    ForEach(CaffeineToleranceLevel.allCases, id: \.self) { level in
                        CaffeineToleranceOption(
                            level: level,
                            isSelected: profile.caffeineToleranceLevel == level,
                            onSelect: { profile.caffeineToleranceLevel = level }
                        )
                    }
                }
                .padding(.horizontal)

                // Info card - corrected science
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("What the science says")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    Text("Research shows caffeine tolerance affects how you feel caffeine's effects (sensitivity), but does NOT significantly change how fast your body metabolizes it. We use this to understand your subjective experience, not to adjust clearance rates.")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)

                    Text("Source: PMC3715142")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                        .italic()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(OnLifeColors.deepForest)
    }
}

struct CaffeineToleranceOption: View {
    let level: CaffeineToleranceLevel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Image(systemName: level.icon)
                            .foregroundColor(isSelected ? .white : OnLifeColors.sage)
                        Text(level.rawValue)
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : OnLifeColors.textPrimary)
                    }

                    Text(level.displayName)
                        .font(OnLifeFont.body())
                        .foregroundColor(isSelected ? .white.opacity(0.9) : OnLifeColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? OnLifeColors.sage : OnLifeColors.cardBackground)
            .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Lifestyle Screen

struct LifestyleScreen: View {
    @Binding var profile: UserMetabolismProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Lifestyle Factors")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Sleep and exercise significantly affect metabolism")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, Spacing.xl)

                // Sleep quality section
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(OnLifeColors.sage)
                        Text("Average Sleep Quality")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    ForEach(SleepQuality.allCases, id: \.self) { quality in
                        LifestyleOption(
                            icon: quality.icon,
                            title: quality.rawValue,
                            subtitle: quality.displayName,
                            isSelected: profile.averageSleepQuality == quality,
                            onSelect: { profile.averageSleepQuality = quality }
                        )
                    }
                }
                .padding()
                .background(OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Exercise frequency section
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(OnLifeColors.sage)
                        Text("Exercise Frequency")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    ForEach(ExerciseFrequency.allCases, id: \.self) { frequency in
                        LifestyleOption(
                            icon: frequency.icon,
                            title: frequency.rawValue,
                            subtitle: frequency.displayName,
                            isSelected: profile.exerciseFrequency == frequency,
                            onSelect: { profile.exerciseFrequency = frequency }
                        )
                    }
                }
                .padding()
                .background(OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(OnLifeColors.deepForest)
    }
}

struct LifestyleOption: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : OnLifeColors.sage)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OnLifeFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : OnLifeColors.textPrimary)

                    Text(subtitle)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(isSelected ? .white.opacity(0.8) : OnLifeColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .background(isSelected ? OnLifeColors.sage.opacity(0.8) : Color.clear)
            .cornerRadius(CornerRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Metabolism Speed Screen

struct MetabolismSpeedScreen: View {
    @Binding var profile: UserMetabolismProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Your Metabolism")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("How would you describe your metabolism?")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, Spacing.xl)

                VStack(spacing: Spacing.md) {
                    ForEach(MetabolismSpeed.allCases, id: \.self) { speed in
                        MetabolismSpeedOption(
                            speed: speed,
                            isSelected: profile.metabolismSpeed == speed,
                            onSelect: { profile.metabolismSpeed = speed }
                        )
                    }
                }
                .padding(.horizontal)

                // Guidance card
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Not sure?")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("• Fast: Substances wear off quickly, high energy, hard to gain weight")
                        Text("• Average: Typical response to substances, moderate energy")
                        Text("• Slow: Substances last longer, easier to gain weight, steady energy")
                    }
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)

                    Text("\nDon't worry - we'll refine this over time based on your actual substance response!")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .italic()
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(OnLifeColors.deepForest)
    }
}

struct MetabolismSpeedOption: View {
    let speed: MetabolismSpeed
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: Spacing.sm) {
                HStack {
                    Image(systemName: speed.icon)
                        .font(.system(size: 32))
                        .foregroundColor(isSelected ? .white : colorForSpeed(speed))

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(speed.rawValue)
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : OnLifeColors.textPrimary)

                        Text(speed.description)
                            .font(OnLifeFont.body())
                            .foregroundColor(isSelected ? .white.opacity(0.9) : OnLifeColors.textSecondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
            .background(isSelected ? colorForSpeed(speed) : OnLifeColors.cardBackground)
            .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func colorForSpeed(_ speed: MetabolismSpeed) -> Color {
        switch speed {
        case .slow: return .blue
        case .average: return OnLifeColors.sage
        case .fast: return .orange
        }
    }
}

// MARK: - Summary Screen

struct SummaryScreen: View {
    @Binding var profile: UserMetabolismProfile

    @State private var showingCYP1A2Info = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(OnLifeColors.sage)

                    Text("Profile Complete!")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Here's your personalized metabolism profile")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, Spacing.xl)

                // Profile completeness
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("Profile Completeness")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)

                        Spacer()

                        Text("\(Int(profile.profileCompleteness * 100))%")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.sage)
                    }

                    ProgressView(value: profile.profileCompleteness)
                        .tint(OnLifeColors.sage)
                }
                .padding()
                .background(OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Profile summary
                VStack(spacing: Spacing.sm) {
                    ProfileSummaryRow(icon: "person.fill", label: "Age", value: "\(profile.age) years")
                    ProfileSummaryRow(icon: "scalemass", label: "Weight", value: "\(Int(profile.weight)) kg")
                    if let height = profile.height {
                        ProfileSummaryRow(icon: "ruler", label: "Height", value: "\(Int(height)) cm")
                        if let bmi = profile.bmi {
                            ProfileSummaryRow(icon: "heart.text.square", label: "BMI", value: String(format: "%.1f", bmi))
                        }
                    }
                    ProfileSummaryRow(icon: "figure.walk", label: "Sex", value: profile.sex.rawValue)
                    ProfileSummaryRow(icon: "cup.and.saucer.fill", label: "Caffeine Tolerance", value: profile.caffeineToleranceLevel.rawValue)
                    ProfileSummaryRow(icon: "moon.fill", label: "Sleep Quality", value: profile.averageSleepQuality.rawValue)
                    ProfileSummaryRow(icon: "flame.fill", label: "Exercise", value: profile.exerciseFrequency.rawValue)
                    ProfileSummaryRow(icon: profile.metabolismSpeed.icon, label: "Metabolism", value: profile.metabolismSpeed.rawValue)
                }
                .padding()
                .background(OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Personalized insights
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("Your Personalized Parameters")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SummaryInsightRow(
                            icon: "timer",
                            text: "Caffeine half-life: \(formatDuration(profile.caffeineHalfLife()))",
                            detail: "vs. 5 hours average"
                        )

                        SummaryInsightRow(
                            icon: "leaf.fill",
                            text: "L-theanine half-life: \(formatDuration(profile.lTheanineHalfLife()))",
                            detail: "vs. 40 minutes average"
                        )

                        SummaryInsightRow(
                            icon: "cup.and.saucer.fill",
                            text: "Daily caffeine limit: \(Int(profile.recommendedDailyCaffeineLimit))mg",
                            detail: "personalized for your body"
                        )

                        Button(action: { showingCYP1A2Info = true }) {
                            SummaryInsightRow(
                                icon: "info.circle",
                                text: "Estimated CYP1A2: \(profile.cyp1a2Genotype.rawValue)",
                                detail: "Tap for details"
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                .background(OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Metabolism multiplier
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Overall Metabolism Factor")
                        .font(OnLifeFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(OnLifeColors.textPrimary)

                    HStack {
                        Text(String(format: "%.2fx", profile.overallMetabolismMultiplier))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(OnLifeColors.sage)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if profile.overallMetabolismMultiplier > 1.1 {
                                Text("Fast metabolizer")
                                    .font(OnLifeFont.bodySmall())
                                    .foregroundColor(OnLifeColors.textSecondary)
                                Text("Substances clear quickly")
                                    .font(OnLifeFont.bodySmall())
                                    .foregroundColor(OnLifeColors.textSecondary)
                            } else if profile.overallMetabolismMultiplier < 0.9 {
                                Text("Slow metabolizer")
                                    .font(OnLifeFont.bodySmall())
                                    .foregroundColor(OnLifeColors.textSecondary)
                                Text("Substances last longer")
                                    .font(OnLifeFont.bodySmall())
                                    .foregroundColor(OnLifeColors.textSecondary)
                            } else {
                                Text("Average metabolizer")
                                    .font(OnLifeFont.bodySmall())
                                    .foregroundColor(OnLifeColors.textSecondary)
                                Text("Typical clearance rate")
                                    .font(OnLifeFont.bodySmall())
                                    .foregroundColor(OnLifeColors.textSecondary)
                            }
                        }
                    }
                }
                .padding()
                .background(OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(OnLifeColors.deepForest)
        .sheet(isPresented: $showingCYP1A2Info) {
            CYP1A2InfoSheet(genotype: profile.cyp1a2Genotype)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Summary Components

struct ProfileSummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(OnLifeColors.sage)
                .frame(width: 24)

            Text(label)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textSecondary)

            Spacer()

            Text(value)
                .font(OnLifeFont.body())
                .fontWeight(.semibold)
                .foregroundColor(OnLifeColors.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

struct SummaryInsightRow: View {
    let icon: String
    let text: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(OnLifeColors.sage)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text(detail)
                    .font(OnLifeFont.bodySmall())
                    .foregroundColor(OnLifeColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CYP1A2 Info Sheet

struct CYP1A2InfoSheet: View {
    let genotype: CYP1A2Genotype
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("What is CYP1A2?")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("CYP1A2 is an enzyme in your liver responsible for metabolizing caffeine. Genetic variations in this enzyme can cause 3-4x differences in how quickly you process caffeine!")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Your Estimate: \(genotype.rawValue)")
                            .font(OnLifeFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(OnLifeColors.textPrimary)

                        Text(genotype.description)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                    .padding()
                    .background(OnLifeColors.cardBackground)
                    .cornerRadius(CornerRadius.medium)

                    Text("How we estimated this:")
                        .font(OnLifeFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("We used your caffeine tolerance level and metabolism speed to estimate your likely genotype. As you use OnLife, we'll refine this estimate based on your actual caffeine response patterns.")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)

                    Text("For a precise measurement, you would need a genetic test (like 23andMe) to determine your actual CYP1A2 genotype.")
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .italic()
                }
                .padding()
            }
            .background(OnLifeColors.deepForest)
            .navigationTitle("CYP1A2 Gene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(OnLifeColors.sage)
                }
            }
        }
    }
}

// MARK: - Option Card

struct OptionCard: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? OnLifeColors.sage : OnLifeColors.textSecondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(OnLifeFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(description)
                        .font(OnLifeFont.bodySmall())
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(OnLifeColors.sage)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isSelected ? OnLifeColors.cardBackground : OnLifeColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(isSelected ? OnLifeColors.sage : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
