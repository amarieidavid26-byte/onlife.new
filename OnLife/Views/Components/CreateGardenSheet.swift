import SwiftUI

struct CreateGardenSheet: View {
    @ObservedObject var gardenViewModel: GardenViewModel
    @Binding var isPresented: Bool

    @State private var gardenName: String = ""
    @State private var selectedIcon: String = "🌻"
    @State private var showError: Bool = false

    let availableIcons = ["🌻", "🌿", "🌳", "🌺", "🌸", "🌼", "🌷", "🌹", "🪴", "💐", "🌾", "🌱"]

    var validationError: String? {
        gardenViewModel.validationError(for: gardenName)
    }

    var isValid: Bool {
        validationError == nil && !gardenName.isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                OnLifeColors.deepForest
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Garden Name Input
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("GARDEN NAME")
                                .font(OnLifeFont.label())
                                .foregroundColor(OnLifeColors.textTertiary)

                            TextField("Garden name", text: $gardenName)
                                .font(OnLifeFont.body())
                                .foregroundColor(OnLifeColors.textPrimary)
                                .padding(Spacing.lg)
                                .background(OnLifeColors.cardBackground)
                                .cornerRadius(CornerRadius.medium)
                                .onChange(of: gardenName) { _, _ in
                                    showError = false
                                }
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Error Message
                        if showError, let error = validationError {
                            Text(error)
                                .font(OnLifeFont.bodySmall())
                                .foregroundColor(.red)
                                .padding(.horizontal, Spacing.xl)
                        }

                        // Icon Selector
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("CHOOSE ICON")
                                .font(OnLifeFont.label())
                                .foregroundColor(OnLifeColors.textTertiary)

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
                                .font(OnLifeFont.label())
                                .foregroundColor(OnLifeColors.textTertiary)

                            CardView {
                                HStack {
                                    Text(selectedIcon)
                                        .font(.system(size: 40))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(gardenName.isEmpty ? "My Garden" : gardenName)
                                            .font(OnLifeFont.heading3())
                                            .foregroundColor(OnLifeColors.textPrimary)

                                        Text("0 plants")
                                            .font(OnLifeFont.bodySmall())
                                            .foregroundColor(OnLifeColors.textTertiary)
                                    }

                                    Spacer()
                                }
                                .padding(Spacing.lg)
                            }
                        }
                        .padding(.horizontal, Spacing.xl)

                        // Create Button
                        PrimaryButton(title: "Create Garden") {
                            if isValid {
                                gardenViewModel.createGarden(name: gardenName.trimmingCharacters(in: .whitespaces), icon: selectedIcon)
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
            .navigationTitle("Create New Garden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(OnLifeColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Icon Button
struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(icon)
                .font(.system(size: 40))
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(isSelected ? OnLifeColors.sage : OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)
        }
    }
}
