import SwiftUI

struct MetabolismProfileEditView: View {
    @StateObject private var profileManager = MetabolismProfileManager.shared
    @State private var editedProfile: UserMetabolismProfile
    @Environment(\.dismiss) private var dismiss

    init() {
        _editedProfile = State(initialValue: MetabolismProfileManager.shared.profile)
    }

    var body: some View {
        Form {
            Section(header: Text("Demographics")) {
                HStack {
                    Text("Age")
                    Spacer()
                    TextField("Age", value: $editedProfile.age, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Weight (kg)")
                    Spacer()
                    TextField("Weight", value: $editedProfile.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Height (cm)")
                    Spacer()
                    TextField("Height", value: $editedProfile.height, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                Picker("Sex", selection: $editedProfile.sex) {
                    ForEach(BiologicalSex.allCases, id: \.self) { sex in
                        Text(sex.rawValue).tag(sex)
                    }
                }
            }

            Section(header: Text("Lifestyle")) {
                Picker("Caffeine Tolerance", selection: $editedProfile.caffeineToleranceLevel) {
                    ForEach(CaffeineToleranceLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }

                Picker("Sleep Quality", selection: $editedProfile.averageSleepQuality) {
                    ForEach(SleepQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }

                Picker("Exercise Frequency", selection: $editedProfile.exerciseFrequency) {
                    ForEach(ExerciseFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
            }

            Section(header: Text("Metabolism")) {
                Picker("Metabolism Speed", selection: $editedProfile.metabolismSpeed) {
                    ForEach(MetabolismSpeed.allCases, id: \.self) { speed in
                        Text(speed.rawValue).tag(speed)
                    }
                }

                Picker("CYP1A2 Genotype", selection: $editedProfile.cyp1a2Genotype) {
                    ForEach(CYP1A2Genotype.allCases, id: \.self) { genotype in
                        Text(genotype.displayName).tag(genotype)
                    }
                }
            }

            Section(header: Text("Calculated Values")) {
                HStack {
                    Text("Caffeine Half-Life")
                    Spacer()
                    Text(formatDuration(editedProfile.caffeineHalfLife()))
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                HStack {
                    Text("L-Theanine Half-Life")
                    Spacer()
                    Text(formatDuration(editedProfile.lTheanineHalfLife()))
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                HStack {
                    Text("Daily Caffeine Limit")
                    Spacer()
                    Text("\(Int(editedProfile.recommendedDailyCaffeineLimit))mg")
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                HStack {
                    Text("Metabolism Factor")
                    Spacer()
                    Text(String(format: "%.2fx", editedProfile.overallMetabolismMultiplier))
                        .foregroundColor(OnLifeColors.textSecondary)
                }

                HStack {
                    Text("Profile Completeness")
                    Spacer()
                    Text("\(Int(editedProfile.profileCompleteness * 100))%")
                        .foregroundColor(editedProfile.isComplete ? OnLifeColors.sage : .orange)
                }
            }
        }
        .navigationTitle("Metabolism Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(OnLifeColors.textSecondary)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    profileManager.updateProfile(editedProfile)
                    dismiss()
                }
                .foregroundColor(OnLifeColors.sage)
            }
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
