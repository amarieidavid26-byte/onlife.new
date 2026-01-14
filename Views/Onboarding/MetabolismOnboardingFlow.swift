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
                                .font(AppFont.button())
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .fill(AppColors.lightSoil)
                                )
                        }
                    }

                    Button(action: nextStep) {
                        Text(currentStep == totalSteps - 1 ? "Complete" : (currentStep == 0 ? "Get Started" : "Continue"))
                            .font(AppFont.button())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .fill(canProceed ? AppColors.healthy : AppColors.lightSoil)
                            )
                    }
                    .disabled(!canProceed)
                }
                .padding()
                .background(AppColors.darkSoil)
            }
            .background(AppColors.richSoil)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Navigation Logic

    func nextStep() {
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
        case 1: return validateDemographics() // Demographics
        case 2: return true // Health status
        case 3: return true // Caffeine tolerance
        case 4: return true // Lifestyle
        case 5: return true // Metabolism speed
        case 6: return true // Summary
        default: return false
        }
    }

    func validateDemographics() -> Bool {
        var isValid = true

        // Age validation
        if profile.age < 13 || profile.age > 120 {
            ageError = "Age must be between 13 and 120"
            isValid = false
        } else {
            ageError = nil
        }

        // Weight validation
        if profile.weight < 30 || profile.weight > 300 {
            weightError = "Weight must be between 30 and 300 kg"
            isValid = false
        } else {
            weightError = nil
        }

        // Height validation (optional but if provided must be valid)
        if let height = profile.height {
            if height < 100 || height > 250 {
                heightError = "Height must be between 100 and 250 cm"
                isValid = false
            } else {
                heightError = nil
            }
        } else {
            heightError = nil
        }

        return isValid
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
                        .fill(step <= currentStep ? AppColors.healthy : AppColors.lightSoil)
                        .frame(width: 8, height: 8)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.lightSoil)
                        .frame(height: 4)

                    Rectangle()
                        .fill(AppColors.healthy)
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
                    .foregroundColor(AppColors.healthy)

                // Title
                VStack(spacing: Spacing.sm) {
                    Text("Personalize Your Experience")
                        .font(AppFont.heading1())
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Help us understand your metabolism for accurate substance tracking")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
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
                        .fill(AppColors.lightSoil)
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
                .foregroundColor(AppColors.healthy)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Text(description)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
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
                        .font(AppFont.heading2())
                        .foregroundColor(AppColors.textPrimary)

                    Text("This helps us calculate your personalized metabolism rate")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xl)

                // Age Input
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(AppColors.healthy)
                        Text("Age")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    TextField("Enter your age", value: $profile.age, format: .number)
                        .keyboardType(.numberPad)
                        .font(AppFont.bodyLarge())
                        .foregroundColor(AppColors.textPrimary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(AppColors.darkSoil)
                        )

                    if let error = ageError {
                        Text(error)
                            .font(AppFont.bodySmall())
                            .foregroundColor(.red)
                    }

                    Text("Metabolism slows ~1-2% per decade after 30")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.lightSoil)
                )

                // Weight Input
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "scalemass")
                            .foregroundColor(AppColors.healthy)
                        Text("Weight (kg)")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    TextField("Enter your weight", value: $profile.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .font(AppFont.bodyLarge())
                        .foregroundColor(AppColors.textPrimary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(AppColors.darkSoil)
                        )

                    if let error = weightError {
                        Text(error)
                            .font(AppFont.bodySmall())
                            .foregroundColor(.red)
                    }

                    Text("Used for allometric scaling (metabolism ∝ mass^0.75)")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.lightSoil)
                )

                // Height Input (Optional)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "ruler")
                            .foregroundColor(AppColors.healthy)
                        Text("Height (cm) - Optional")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    TextField("Enter your height", value: $profile.height, format: .number)
                        .keyboardType(.decimalPad)
                        .font(AppFont.bodyLarge())
                        .foregroundColor(AppColors.textPrimary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .fill(AppColors.darkSoil)
                        )

                    if let error = heightError {
                        Text(error)
                            .font(AppFont.bodySmall())
                            .foregroundColor(.red)
                    }

                    Text("Used to calculate BMI for better insights")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.lightSoil)
                )

                // Sex Picker
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "person.2")
                            .foregroundColor(AppColors.healthy)
                        Text("Biological Sex")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    Picker("Biological Sex", selection: $profile.sex) {
                        ForEach(BiologicalSex.allCases, id: \.self) { sex in
                            Text(sex.rawValue).tag(sex)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Males typically have 10-15% faster basal metabolic rate")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.lightSoil)
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
                        .font(AppFont.heading2())
                        .foregroundColor(AppColors.textPrimary)

                    Text("These factors significantly affect caffeine metabolism and safety limits")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, Spacing.xl)

                // Smoking Status
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "smoke.fill")
                            .foregroundColor(AppColors.healthy)
                        Text("Smoking Status")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
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
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding()
                .background(AppColors.lightSoil)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Hormonal Contraceptives (only for female users)
                if profile.sex == .female {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Image(systemName: "pills.fill")
                                .foregroundColor(AppColors.healthy)
                            Text("Hormonal Contraceptives")
                                .font(AppFont.body())
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                        }

                        Toggle(isOn: $profile.usesHormonalContraceptives) {
                            Text("I use hormonal birth control")
                                .font(AppFont.body())
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .tint(AppColors.healthy)

                        Text("Oral contraceptives nearly double caffeine half-life (1.7× longer)")
                            .font(AppFont.bodySmall())
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding()
                    .background(AppColors.lightSoil)
                    .cornerRadius(CornerRadius.medium)
                    .padding(.horizontal)
                }

                // Pregnancy Status (only for female users)
                if profile.sex == .female {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(AppColors.healthy)
                            Text("Pregnancy Status")
                                .font(AppFont.body())
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                        }

                        Toggle(isOn: $profile.isPregnant) {
                            Text("I am currently pregnant")
                                .font(AppFont.body())
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .tint(AppColors.healthy)

                        if profile.isPregnant {
                            Text("Which trimester?")
                                .font(AppFont.body())
                                .foregroundColor(AppColors.textSecondary)
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
                                    .font(AppFont.bodySmall())
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(CornerRadius.small)
                        }
                    }
                    .padding()
                    .background(AppColors.lightSoil)
                    .cornerRadius(CornerRadius.medium)
                    .padding(.horizontal)
                }

                // Medication Interactions
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "cross.case.fill")
                            .foregroundColor(AppColors.healthy)
                        Text("Medications")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    Toggle(isOn: $profile.takesFluvoxamine) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fluvoxamine (Luvox)")
                                .font(AppFont.body())
                                .foregroundColor(AppColors.textPrimary)
                            Text("SSRI antidepressant")
                                .font(AppFont.bodySmall())
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .tint(AppColors.healthy)

                    // Fluvoxamine warning
                    if profile.takesFluvoxamine {
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                            Text("⚠️ CRITICAL: Fluvoxamine increases caffeine half-life 5-6×. This is a severe interaction. Consult your healthcare provider before using this app.")
                                .font(AppFont.bodySmall())
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(CornerRadius.small)
                    }

                    Text("Other medications that may interact: ciprofloxacin, clozapine, some antifungals")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding()
                .background(AppColors.lightSoil)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Privacy note
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.blue)
                        Text("Privacy Note")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    Text("This health information is stored only on your device and is never shared. You can skip any question by leaving it as default.")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(AppColors.richSoil)
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
                    .foregroundColor(isSelected ? .white : AppColors.healthy)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : AppColors.textPrimary)

                    Text(subtitle)
                        .font(AppFont.bodySmall())
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .background(isSelected ? AppColors.healthy.opacity(0.8) : Color.clear)
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
                        .font(AppFont.heading2())
                        .foregroundColor(AppColors.textPrimary)

                    Text("This helps us understand your caffeine sensitivity (but doesn't affect metabolism speed)")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
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
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    Text("Research shows caffeine tolerance affects how you feel caffeine's effects (sensitivity), but does NOT significantly change how fast your body metabolizes it. We use this to understand your subjective experience, not to adjust clearance rates.")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)

                    Text("Source: PMC3715142")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textTertiary)
                        .italic()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(AppColors.richSoil)
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
                            .foregroundColor(isSelected ? .white : AppColors.healthy)
                        Text(level.rawValue)
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                    }

                    Text(level.displayName)
                        .font(AppFont.body())
                        .foregroundColor(isSelected ? .white.opacity(0.9) : AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? AppColors.healthy : AppColors.lightSoil)
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
                        .font(AppFont.heading2())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Sleep and exercise significantly affect metabolism")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, Spacing.xl)

                // Sleep quality section
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(AppColors.healthy)
                        Text("Average Sleep Quality")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
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
                .background(AppColors.lightSoil)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Exercise frequency section
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(AppColors.healthy)
                        Text("Exercise Frequency")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
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
                .background(AppColors.lightSoil)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(AppColors.richSoil)
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
                    .foregroundColor(isSelected ? .white : AppColors.healthy)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : AppColors.textPrimary)

                    Text(subtitle)
                        .font(AppFont.bodySmall())
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .background(isSelected ? AppColors.healthy.opacity(0.8) : Color.clear)
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
                        .font(AppFont.heading2())
                        .foregroundColor(AppColors.textPrimary)

                    Text("How would you describe your metabolism?")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
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
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("• Fast: Substances wear off quickly, high energy, hard to gain weight")
                        Text("• Average: Typical response to substances, moderate energy")
                        Text("• Slow: Substances last longer, easier to gain weight, steady energy")
                    }
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textSecondary)

                    Text("\nDon't worry - we'll refine this over time based on your actual substance response!")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                        .italic()
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(AppColors.richSoil)
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
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : AppColors.textPrimary)

                        Text(speed.description)
                            .font(AppFont.body())
                            .foregroundColor(isSelected ? .white.opacity(0.9) : AppColors.textSecondary)
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
            .background(isSelected ? colorForSpeed(speed) : AppColors.lightSoil)
            .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func colorForSpeed(_ speed: MetabolismSpeed) -> Color {
        switch speed {
        case .slow: return .blue
        case .average: return AppColors.healthy
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
                        .foregroundColor(AppColors.healthy)

                    Text("Profile Complete!")
                        .font(AppFont.heading2())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Here's your personalized metabolism profile")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, Spacing.xl)

                // Profile completeness
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("Profile Completeness")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Text("\(Int(profile.profileCompleteness * 100))%")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.healthy)
                    }

                    ProgressView(value: profile.profileCompleteness)
                        .tint(AppColors.healthy)
                }
                .padding()
                .background(AppColors.lightSoil)
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
                .background(AppColors.lightSoil)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Personalized insights
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("Your Personalized Parameters")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
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
                .background(AppColors.lightSoil)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Metabolism multiplier
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Overall Metabolism Factor")
                        .font(AppFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    HStack {
                        Text(String(format: "%.2fx", profile.overallMetabolismMultiplier))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.healthy)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if profile.overallMetabolismMultiplier > 1.1 {
                                Text("Fast metabolizer")
                                    .font(AppFont.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                Text("Substances clear quickly")
                                    .font(AppFont.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                            } else if profile.overallMetabolismMultiplier < 0.9 {
                                Text("Slow metabolizer")
                                    .font(AppFont.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                Text("Substances last longer")
                                    .font(AppFont.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Text("Average metabolizer")
                                    .font(AppFont.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                Text("Typical clearance rate")
                                    .font(AppFont.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
                .padding()
                .background(AppColors.lightSoil)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(AppColors.richSoil)
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
                .foregroundColor(AppColors.healthy)
                .frame(width: 24)

            Text(label)
                .font(AppFont.body())
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppFont.body())
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
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
                .foregroundColor(AppColors.healthy)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(AppFont.body())
                    .foregroundColor(AppColors.textPrimary)

                Text(detail)
                    .font(AppFont.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
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
                        .font(AppFont.heading2())
                        .foregroundColor(AppColors.textPrimary)

                    Text("CYP1A2 is an enzyme in your liver responsible for metabolizing caffeine. Genetic variations in this enzyme can cause 3-4x differences in how quickly you process caffeine!")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Your Estimate: \(genotype.rawValue)")
                            .font(AppFont.body())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)

                        Text(genotype.description)
                            .font(AppFont.body())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding()
                    .background(AppColors.lightSoil)
                    .cornerRadius(CornerRadius.medium)

                    Text("How we estimated this:")
                        .font(AppFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    Text("We used your caffeine tolerance level and metabolism speed to estimate your likely genotype. As you use OnLife, we'll refine this estimate based on your actual caffeine response patterns.")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)

                    Text("For a precise measurement, you would need a genetic test (like 23andMe) to determine your actual CYP1A2 genotype.")
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                        .italic()
                }
                .padding()
            }
            .background(AppColors.richSoil)
            .navigationTitle("CYP1A2 Gene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.healthy)
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
                    .foregroundColor(isSelected ? AppColors.healthy : AppColors.textSecondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    Text(description)
                        .font(AppFont.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.healthy)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isSelected ? AppColors.lightSoil : AppColors.darkSoil)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(isSelected ? AppColors.healthy : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
