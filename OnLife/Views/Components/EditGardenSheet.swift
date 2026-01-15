import SwiftUI

struct EditGardenSheet: View {
    @ObservedObject var gardenViewModel: GardenViewModel
    let garden: Garden
    @Binding var isPresented: Bool

    @State private var gardenName: String
    @State private var selectedIcon: String
    @State private var showError: Bool = false

    let availableIcons = ["🌻", "🌿", "🌳", "🌺", "🌸", "🌼", "🌷", "🌹", "🪴", "💐", "🌾", "🌱"]

    init(gardenViewModel: GardenViewModel, garden: Garden, isPresented: Binding<Bool>) {
        self.gardenViewModel = gardenViewModel
        self.garden = garden
        self._isPresented = isPresented

        // Initialize with current values
        self._gardenName = State(initialValue: garden.name)
        self._selectedIcon = State(initialValue: garden.icon)
    }

    var validationError: String? {
        gardenViewModel.validationErrorForEdit(name: gardenName, currentGarden: garden)
    }

    var isValid: Bool {
        validationError == nil && !gardenName.isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.richSoil
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Garden Name Input
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("GARDEN NAME")
                                .font(AppFont.label())
                                .foregroundColor(AppColors.textTertiary)

                            TextField("Garden name", text: $gardenName)
                                .font(AppFont.body())
                                .foregroundColor(AppColors.textPrimary)
                                .padding(Spacing.lg)
                                .background(AppColors.lightSoil)
                                .cornerRadius(CornerRadius.medium)
                                .onChange(of: gardenName) { _, _ in
                                    showError = false
                                }
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Error Message
                        if showError, let error = validationError {
                            Text(error)
                                .font(AppFont.bodySmall())
                                .foregroundColor(.red)
                                .padding(.horizontal, Spacing.xl)
                        }

                        // Icon Selector
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("CHOOSE ICON")
                                .font(AppFont.label())
                                .foregroundColor(AppColors.textTertiary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Spacing.md) {
                                ForEach(availableIcons, id: \.self) { icon in
                                    IconButton(
                                        icon: icon,
                                        isSelected: selectedIcon == icon
                                    ) {
                                        selectedIcon = icon
                                        HapticManager.shared.impact(style: .light)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Preview Card
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("PREVIEW")
                                .font(AppFont.label())
                                .foregroundColor(AppColors.textTertiary)

                            CardView {
                                HStack {
                                    Text(selectedIcon)
                                        .font(.system(size: 40))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(gardenName.isEmpty ? "My Garden" : gardenName)
                                            .font(AppFont.heading3())
                                            .foregroundColor(AppColors.textPrimary)

                                        Text("\(gardenViewModel.plants(for: garden.id).count) plants")
                                            .font(AppFont.bodySmall())
                                            .foregroundColor(AppColors.textTertiary)
                                    }

                                    Spacer()
                                }
                                .padding(Spacing.lg)
                            }
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Save Button
                        PrimaryButton(title: "Save Changes") {
                            if isValid {
                                gardenViewModel.updateGarden(garden, name: gardenName.trimmingCharacters(in: .whitespaces), icon: selectedIcon)
                                HapticManager.shared.impact(style: .medium)
                                AudioManager.shared.play(.success, volume: 0.7)
                                isPresented = false
                            } else {
                                showError = true
                                HapticManager.shared.notification(type: .error)
                            }
                        }
                        .disabled(!isValid)
                        .opacity(isValid ? 1.0 : 0.5)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.bottom, Spacing.xxxl)
                    }
                    .padding(.top, Spacing.xl)
                }
            }
            .navigationTitle("Edit Garden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
}
