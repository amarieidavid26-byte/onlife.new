import SwiftUI
import RealityKit

struct Garden3DView: View {
    @ObservedObject var gardenViewModel: GardenViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var selectedPlantID: UUID?
    @State private var showPlantDetail = false
    @State private var gardenScene: GardenScene?
    @State private var showWindControls = false
    @State private var showTimeControls = false

    // Dynamic sky colors (updated by DayNightSystem)
    @State private var skyTopColor: Color = Color(red: 0.3, green: 0.55, blue: 0.95)
    @State private var skyBottomColor: Color = Color(red: 0.6, green: 0.8, blue: 1.0)

    var body: some View {
        ZStack {
            // Dynamic sky gradient background
            LinearGradient(
                colors: [skyTopColor, skyBottomColor],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 3D Scene (with transparent background)
            Garden3DSceneView(
                gardenViewModel: gardenViewModel,
                gardenScene: $gardenScene,
                onPlantTapped: { plantID in
                    selectedPlantID = plantID
                    showPlantDetail = true
                    HapticManager.shared.impact(style: .light)
                }
            )
            .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top gradient with garden info
                gardenHeader

                Spacer()

                // Empty state or controls
                if gardenViewModel.plants.isEmpty {
                    emptyGardenPrompt
                }
            }

            // Control panels (slides up from bottom)
            VStack {
                Spacer()

                if showWindControls {
                    WindControlOverlay(isVisible: $showWindControls)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, 100)
                }

                if showTimeControls {
                    TimeControlOverlay(isVisible: $showTimeControls)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, 100)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showWindControls)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showTimeControls)
        }
        // Listen for sky color changes from DayNightSystem
        .onReceive(NotificationCenter.default.publisher(for: .skyColorsDidChange)) { notification in
            if let colors = notification.object as? SkyColors {
                withAnimation(.easeInOut(duration: 2.0)) {
                    skyTopColor = Color(colors.top)
                    skyBottomColor = Color(colors.bottom)
                }
            }
        }
        // Handle app lifecycle for wind pause/resume
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            gardenScene?.onEnterBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            gardenScene?.onEnterForeground()
        }
        .sheet(isPresented: $showPlantDetail) {
            if let plantID = selectedPlantID,
               let plant = gardenViewModel.plants.first(where: { $0.id == plantID }) {
                PlantDetailSheet(plant: plant)
            }
        }
    }

    private var gardenHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(gardenViewModel.selectedGarden?.name ?? "My Garden")
                    .font(OnLifeFont.heading2())
                    .foregroundColor(.white)

                Text("\(gardenViewModel.plants.count) plants growing")
                    .font(OnLifeFont.caption())
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Camera reset button
            Button {
                gardenScene?.resetCamera()
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }

            // Wind control toggle button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showWindControls.toggle()
                    showTimeControls = false
                }
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: showWindControls ? "wind.circle.fill" : "wind")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(showWindControls ? OnLifeColors.sage : .white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }

            // Time control toggle button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showTimeControls.toggle()
                    showWindControls = false
                }
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: DayNightSystem.shared.currentPhase.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(showTimeControls ? timePhaseColor : .white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false),
            alignment: .top
        )
    }

    private var emptyGardenPrompt: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [OnLifeColors.sage, OnLifeColors.healthy],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Your garden awaits")
                .font(OnLifeFont.heading3())
                .foregroundColor(.white)

            Text("Complete focus sessions to grow plants")
                .font(OnLifeFont.bodySmall())
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.card))
        .padding(.bottom, 60)
    }

    // MARK: - Computed Properties

    private var timePhaseColor: Color {
        switch DayNightSystem.shared.currentPhase {
        case .night, .twilight: return .purple
        case .dawn, .dusk: return .orange
        case .morning, .evening: return .yellow
        case .day: return .blue
        }
    }
}

// MARK: - Preview

#if DEBUG
struct Garden3DView_Previews: PreviewProvider {
    static var previews: some View {
        Garden3DView(gardenViewModel: GardenViewModel())
            .preferredColorScheme(.dark)
    }
}
#endif
