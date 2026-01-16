import SwiftUI

struct GardenCarouselView: View {
    let gardens: [Garden]
    @Binding var selectedGarden: Garden?
    let gardenViewModel: GardenViewModel
    let onEdit: (Garden) -> Void
    let onDelete: (Garden) -> Void

    @State private var appeared = false

    // Calculate card width for peek effect (screen width - 80pt for 40pt peek on each side)
    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width - 80
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    // Leading spacer for centering first card
                    Spacer()
                        .frame(width: 24)

                    ForEach(Array(gardens.enumerated()), id: \.element.id) { index, garden in
                        GardenCarouselCard(
                            garden: garden,
                            plantCount: garden.plantsCount,
                            totalFocusTime: formatFocusTime(for: garden),
                            isSelected: selectedGarden?.id == garden.id,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedGarden = garden
                                }
                            },
                            onEdit: {
                                onEdit(garden)
                            },
                            onDelete: gardens.count > 1 ? {
                                onDelete(garden)
                            } : nil
                        )
                        .frame(width: cardWidth)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(
                            OnLifeAnimation.elegant.delay(Double(index) * 0.1),
                            value: appeared
                        )
                    }

                    // Trailing spacer for centering last card
                    Spacer()
                        .frame(width: 24)
                }
            }
            .scrollTargetLayout()
            .scrollTargetBehavior(.viewAligned)

            // Page indicator text
            if gardens.count > 1 {
                pageIndicator
                    .opacity(appeared ? 1 : 0)
                    .animation(OnLifeAnimation.elegant.delay(0.2), value: appeared)
            }
        }
        .onAppear {
            appeared = true
            // Auto-select first garden if none selected
            if selectedGarden == nil, let first = gardens.first {
                selectedGarden = first
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        Group {
            if let selected = selectedGarden,
               let currentIndex = gardens.firstIndex(where: { $0.id == selected.id }) {
                Text("\(currentIndex + 1) of \(gardens.count) gardens")
                    .font(OnLifeFont.caption())
                    .foregroundColor(OnLifeColors.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private func formatFocusTime(for garden: Garden) -> String {
        let sessions = GardenDataManager.shared.loadSessions().filter { $0.gardenId == garden.id }
        let totalSeconds = sessions.reduce(0.0) { $0 + $1.actualDuration }

        let hours = Int(totalSeconds / 3600)
        let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
}

// MARK: - Empty Gardens View

struct EmptyGardensCarouselView: View {
    let onCreateGarden: () -> Void

    @State private var bouncing = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("🏡")
                .font(.system(size: 64))
                .scaleEffect(bouncing ? 1.1 : 1.0)
                .animation(
                    .spring(duration: 0.8, bounce: 0.5)
                    .repeatForever(autoreverses: true),
                    value: bouncing
                )
                .onAppear { bouncing = true }

            VStack(spacing: Spacing.sm) {
                Text("Create Your First Garden")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("Gardens help you organize your focus sessions and track your growth.")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            Button(action: {
                Haptics.impact(.medium)
                onCreateGarden()
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))

                    Text("Create Garden")
                        .font(OnLifeFont.button())
                }
                .foregroundColor(OnLifeColors.deepForest)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(OnLifeColors.amber)
                )
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, Spacing.sm)
        }
        .padding(Spacing.xl)
        .padding(.vertical, Spacing.lg)
    }
}
