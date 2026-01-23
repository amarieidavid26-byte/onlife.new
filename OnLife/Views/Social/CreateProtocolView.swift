import SwiftUI

// MARK: - Create Protocol View

struct CreateProtocolView: View {
    let forkingFrom: FlowProtocol?
    let userProfile: UserProfile?
    let onSave: (FlowProtocol) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var substances: [SubstanceEntry] = []
    @State private var selectedActivities: Set<ProtocolActivityType> = []
    @State private var targetChronotype: Chronotype?
    @State private var optimalTimeOfDay: String = ""
    @State private var recommendedDuration: Int = 90
    @State private var isPublic: Bool = true

    @State private var showingAddSubstance = false
    @State private var editingSubstanceIndex: Int?
    @State private var isSaving = false

    @FocusState private var focusedField: Field?

    enum Field {
        case name, description, timeOfDay
    }

    init(forkingFrom: FlowProtocol? = nil, userProfile: UserProfile?, onSave: @escaping (FlowProtocol) -> Void, onCancel: @escaping () -> Void) {
        self.forkingFrom = forkingFrom
        self.userProfile = userProfile
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize with forked values if applicable
        if let fork = forkingFrom {
            _name = State(initialValue: "\(fork.name) (My Version)")
            _description = State(initialValue: fork.description ?? "")
            _substances = State(initialValue: fork.substances)
            _selectedActivities = State(initialValue: Set(fork.activities))
            _targetChronotype = State(initialValue: fork.targetChronotype)
            _optimalTimeOfDay = State(initialValue: fork.optimalTimeOfDay ?? "")
            _recommendedDuration = State(initialValue: fork.recommendedDurationMinutes)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // Fork attribution
                    if let fork = forkingFrom {
                        forkAttributionBanner(fork)
                    }

                    // Basic info section
                    basicInfoSection

                    // Substances section
                    substancesSection

                    // Activities section
                    activitiesSection

                    // Timing section
                    timingSection

                    // Visibility section
                    visibilitySection

                    Spacer()
                        .frame(height: Spacing.xxl)
                }
                .padding(Spacing.lg)
            }
            .background(OnLifeColors.deepForest.ignoresSafeArea())
            .navigationTitle(forkingFrom != nil ? "Fork Protocol" : "Create Protocol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(OnLifeColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveProtocol) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.socialTeal))
                        } else {
                            Text("Save")
                                .font(OnLifeFont.button())
                                .foregroundColor(canSave ? OnLifeColors.socialTeal : OnLifeColors.textMuted)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .sheet(isPresented: $showingAddSubstance) {
                AddSubstanceSheet(
                    existingSubstance: editingSubstanceIndex != nil ? substances[editingSubstanceIndex!] : nil,
                    onSave: { substance in
                        if let index = editingSubstanceIndex {
                            substances[index] = substance
                        } else {
                            substances.append(substance)
                        }
                        showingAddSubstance = false
                        editingSubstanceIndex = nil
                    },
                    onCancel: {
                        showingAddSubstance = false
                        editingSubstanceIndex = nil
                    }
                )
            }
        }
    }

    // MARK: - Validation

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !substances.isEmpty
    }

    // MARK: - Fork Attribution Banner

    private func forkAttributionBanner(_ fork: FlowProtocol) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 18))
                .foregroundColor(OnLifeColors.socialTeal)

            VStack(alignment: .leading, spacing: 2) {
                Text("Forking from")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textTertiary)

                Text(fork.name)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("by \(fork.creatorName)")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.socialTeal)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.socialTeal.opacity(0.1))
        )
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Basic Info")
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            // Name field
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Protocol Name")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)

                TextField("e.g., Morning Clarity Stack", text: $name)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.cardBackgroundElevated)
                    )
                    .focused($focusedField, equals: .name)
            }

            // Description field
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Description (optional)")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)

                TextEditor(text: $description)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.cardBackgroundElevated)
                    )
                    .focused($focusedField, equals: .description)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Substances Section

    private var substancesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Substances")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Spacer()

                Button(action: {
                    editingSubstanceIndex = nil
                    showingAddSubstance = true
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.socialTeal)
                }
            }

            if substances.isEmpty {
                emptySubstancesState
            } else {
                ForEach(Array(substances.enumerated()), id: \.element.id) { index, substance in
                    substanceRow(substance, index: index)
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private var emptySubstancesState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "flask")
                .font(.system(size: 32))
                .foregroundColor(OnLifeColors.textMuted)

            Text("No substances added yet")
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textTertiary)

            Button(action: {
                editingSubstanceIndex = nil
                showingAddSubstance = true
            }) {
                Text("Add Substance")
                    .font(OnLifeFont.button())
                    .foregroundColor(OnLifeColors.socialTeal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
    }

    private func substanceRow(_ substance: SubstanceEntry, index: Int) -> some View {
        HStack(spacing: Spacing.md) {
            // Icon
            Image(systemName: substanceIcon(substance.substance))
                .font(.system(size: 16))
                .foregroundColor(OnLifeColors.socialTeal)
                .frame(width: 24)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(substance.substance)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)

                HStack(spacing: Spacing.sm) {
                    if let dosage = substance.dosage {
                        Text(dosage)
                            .foregroundColor(OnLifeColors.textTertiary)
                    }

                    Text("•")
                        .foregroundColor(OnLifeColors.textMuted)

                    Text(timingLabel(substance.timing))
                        .foregroundColor(OnLifeColors.textTertiary)

                    if let minutes = substance.minutesBefore {
                        Text("(\(minutes)m before)")
                            .foregroundColor(OnLifeColors.textMuted)
                    }
                }
                .font(OnLifeFont.caption())
            }

            Spacer()

            // Edit button
            Button(action: {
                editingSubstanceIndex = index
                showingAddSubstance = true
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(OnLifeColors.textTertiary)
            }

            // Delete button
            Button(action: {
                withAnimation {
                    substances.remove(at: index)
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(OnLifeColors.error)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(OnLifeColors.cardBackgroundElevated)
        )
    }

    private func substanceIcon(_ substance: String) -> String {
        let lowercased = substance.lowercased()
        if lowercased.contains("caffeine") || lowercased.contains("coffee") {
            return "cup.and.saucer.fill"
        } else if lowercased.contains("theanine") {
            return "leaf.fill"
        } else if lowercased.contains("nicotine") {
            return "smoke.fill"
        } else if lowercased.contains("creatine") {
            return "bolt.fill"
        } else {
            return "pills.fill"
        }
    }

    private func timingLabel(_ timing: SubstanceTiming) -> String {
        switch timing {
        case .prework: return "Pre-work"
        case .duringWork: return "During"
        case .postWork: return "After"
        case .wakeUp: return "Wake-up"
        case .beforeBed: return "Before bed"
        }
    }

    // MARK: - Activities Section

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Best For Activities")
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.sm) {
                ForEach(ProtocolActivityType.allCases, id: \.self) { activity in
                    activityButton(activity)
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func activityButton(_ activity: ProtocolActivityType) -> some View {
        let isSelected = selectedActivities.contains(activity)

        return Button(action: {
            withAnimation(.spring(duration: 0.2)) {
                if isSelected {
                    selectedActivities.remove(activity)
                } else {
                    selectedActivities.insert(activity)
                }
            }
            HapticManager.shared.impact(style: .light)
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: activity.icon)
                    .font(.system(size: 14))

                Text(activity.rawValue)
                    .font(OnLifeFont.bodySmall())
            }
            .foregroundColor(isSelected ? OnLifeColors.textPrimary : OnLifeColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(isSelected ? OnLifeColors.socialTeal : OnLifeColors.cardBackgroundElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isSelected ? Color.clear : OnLifeColors.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timing Section

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Timing")
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            // Target chronotype
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Best for Chronotype")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)

                HStack(spacing: Spacing.sm) {
                    chronotypeButton(nil, label: "Any")
                    ForEach([Chronotype.earlyBird, .nightOwl, .flexible], id: \.self) { chrono in
                        chronotypeButton(chrono, label: chrono.rawValue)
                    }
                }
            }

            // Optimal time of day
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Optimal Time Window")
                    .font(OnLifeFont.label())
                    .foregroundColor(OnLifeColors.textTertiary)

                TextField("e.g., 6-10 AM", text: $optimalTimeOfDay)
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(OnLifeColors.cardBackgroundElevated)
                    )
                    .focused($focusedField, equals: .timeOfDay)
            }

            // Recommended duration
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("Recommended Session Duration")
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.textTertiary)

                    Spacer()

                    Text("\(recommendedDuration) minutes")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                }

                Slider(value: Binding(
                    get: { Double(recommendedDuration) },
                    set: { recommendedDuration = Int($0) }
                ), in: 15...180, step: 15)
                .tint(OnLifeColors.socialTeal)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    private func chronotypeButton(_ chrono: Chronotype?, label: String) -> some View {
        let isSelected = targetChronotype == chrono

        return Button(action: {
            withAnimation(.spring(duration: 0.2)) {
                targetChronotype = chrono
            }
            HapticManager.shared.impact(style: .light)
        }) {
            HStack(spacing: Spacing.xs) {
                if let chrono = chrono {
                    Image(systemName: chrono.icon)
                        .font(.system(size: 12))
                }

                Text(label)
                    .font(OnLifeFont.caption())
            }
            .foregroundColor(isSelected ? OnLifeColors.textPrimary : OnLifeColors.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? chronotypeColor(chrono) : OnLifeColors.cardBackgroundElevated)
            )
        }
        .buttonStyle(.plain)
    }

    private func chronotypeColor(_ chrono: Chronotype?) -> Color {
        guard let chrono = chrono else { return OnLifeColors.socialTeal }
        switch chrono {
        case .earlyBird: return OnLifeColors.amber
        case .nightOwl: return Color(hex: "7B68EE")
        case .flexible: return OnLifeColors.sage
        }
    }

    // MARK: - Visibility Section

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Visibility")
                .font(OnLifeFont.heading3())
                .foregroundColor(OnLifeColors.textPrimary)

            Toggle(isOn: $isPublic) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share with Community")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text(isPublic
                         ? "Others can discover, try, and fork your protocol"
                         : "Only you can see this protocol")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
            }
            .tint(OnLifeColors.socialTeal)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(OnLifeColors.cardBackground)
        )
    }

    // MARK: - Save Protocol

    private func saveProtocol() {
        isSaving = true
        HapticManager.shared.impact(style: .medium)

        let newProtocol = FlowProtocol(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            creatorId: userProfile?.id ?? "",
            creatorName: userProfile?.displayName ?? userProfile?.username ?? "Anonymous",
            description: description.isEmpty ? nil : description,
            substances: substances,
            activities: Array(selectedActivities),
            targetChronotype: targetChronotype,
            optimalTimeOfDay: optimalTimeOfDay.isEmpty ? nil : optimalTimeOfDay,
            recommendedDurationMinutes: recommendedDuration,
            forkedFromId: forkingFrom?.id,
            forkedFromName: forkingFrom?.name,
            isPublic: isPublic,
            createdAt: Date(),
            updatedAt: Date()
        )

        onSave(newProtocol)
    }
}

// MARK: - Add Substance Sheet

struct AddSubstanceSheet: View {
    let existingSubstance: SubstanceEntry?
    let onSave: (SubstanceEntry) -> Void
    let onCancel: () -> Void

    @State private var substanceName: String = ""
    @State private var dosage: String = ""
    @State private var timing: SubstanceTiming = .prework
    @State private var minutesBefore: Int = 30

    @State private var showingSuggestions = false

    private let commonSubstances = [
        "Caffeine", "L-Theanine", "Nicotine", "Creatine",
        "Alpha-GPC", "Lion's Mane", "Rhodiola", "Modafinil"
    ]

    init(existingSubstance: SubstanceEntry?, onSave: @escaping (SubstanceEntry) -> Void, onCancel: @escaping () -> Void) {
        self.existingSubstance = existingSubstance
        self.onSave = onSave
        self.onCancel = onCancel

        if let existing = existingSubstance {
            _substanceName = State(initialValue: existing.substance)
            _dosage = State(initialValue: existing.dosage ?? "")
            _timing = State(initialValue: existing.timing)
            _minutesBefore = State(initialValue: existing.minutesBefore ?? 30)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Substance name
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Substance")
                            .font(OnLifeFont.label())
                            .foregroundColor(OnLifeColors.textTertiary)

                        TextField("e.g., Caffeine", text: $substanceName)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textPrimary)
                            .padding(Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                    .fill(OnLifeColors.cardBackgroundElevated)
                            )

                        // Common suggestions
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(commonSubstances, id: \.self) { substance in
                                    Button(action: {
                                        substanceName = substance
                                        HapticManager.shared.impact(style: .light)
                                    }) {
                                        Text(substance)
                                            .font(OnLifeFont.caption())
                                            .foregroundColor(substanceName == substance ? OnLifeColors.textPrimary : OnLifeColors.textTertiary)
                                            .padding(.horizontal, Spacing.sm)
                                            .padding(.vertical, Spacing.xs)
                                            .background(
                                                Capsule()
                                                    .fill(substanceName == substance ? OnLifeColors.socialTeal : OnLifeColors.cardBackground)
                                            )
                                    }
                                }
                            }
                        }
                    }

                    // Dosage
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Dosage")
                            .font(OnLifeFont.label())
                            .foregroundColor(OnLifeColors.textTertiary)

                        TextField("e.g., 100mg", text: $dosage)
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textPrimary)
                            .padding(Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                    .fill(OnLifeColors.cardBackgroundElevated)
                            )
                    }

                    // Timing
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Timing")
                            .font(OnLifeFont.label())
                            .foregroundColor(OnLifeColors.textTertiary)

                        Picker("Timing", selection: $timing) {
                            ForEach(SubstanceTiming.allCases, id: \.self) { t in
                                Text(timingLabel(t)).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Minutes before (if applicable)
                    if timing == .prework {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Text("Minutes Before Session")
                                    .font(OnLifeFont.label())
                                    .foregroundColor(OnLifeColors.textTertiary)

                                Spacer()

                                Text("\(minutesBefore) min")
                                    .font(OnLifeFont.body())
                                    .foregroundColor(OnLifeColors.textPrimary)
                            }

                            Slider(value: Binding(
                                get: { Double(minutesBefore) },
                                set: { minutesBefore = Int($0) }
                            ), in: 5...120, step: 5)
                            .tint(OnLifeColors.socialTeal)
                        }
                    }

                    Spacer()
                }
                .padding(Spacing.lg)
            }
            .background(OnLifeColors.deepForest.ignoresSafeArea())
            .navigationTitle(existingSubstance != nil ? "Edit Substance" : "Add Substance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(OnLifeColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let entry = SubstanceEntry(
                            substance: substanceName,
                            dosage: dosage.isEmpty ? nil : dosage,
                            timing: timing,
                            minutesBefore: timing == .prework ? minutesBefore : nil
                        )
                        onSave(entry)
                    }
                    .font(OnLifeFont.button())
                    .foregroundColor(!substanceName.isEmpty ? OnLifeColors.socialTeal : OnLifeColors.textMuted)
                    .disabled(substanceName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func timingLabel(_ timing: SubstanceTiming) -> String {
        switch timing {
        case .prework: return "Before"
        case .duringWork: return "During"
        case .postWork: return "After"
        case .wakeUp: return "Wake"
        case .beforeBed: return "Bed"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CreateProtocolView_Previews: PreviewProvider {
    static var previews: some View {
        CreateProtocolView(
            forkingFrom: nil,
            userProfile: nil,
            onSave: { _ in },
            onCancel: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
