import SwiftUI
import RealityKit
import Combine

struct Garden3DSceneView: UIViewRepresentable {
    @ObservedObject var gardenViewModel: GardenViewModel
    @Binding var gardenScene: GardenScene?
    let onPlantTapped: (UUID) -> Void

    func makeUIView(context: Context) -> ARView {
        // Create ARView in non-AR mode (virtual camera, no passthrough)
        let arView = ARView(frame: .zero)
        arView.cameraMode = .nonAR

        // Disable AR session completely
        arView.automaticallyConfigureSession = false

        // Transparent background to show SwiftUI sky gradient behind
        arView.environment.background = .color(.clear)
        arView.backgroundColor = .clear

        // Create and configure scene
        let scene = GardenScene()
        context.coordinator.gardenScene = scene

        // Add scene anchor to view
        arView.scene.addAnchor(scene.rootAnchor)

        // Setup camera
        scene.setupCamera(in: arView)

        // Setup tap gesture
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)

        // Setup pan gesture for camera orbit
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        arView.addGestureRecognizer(panGesture)

        // Setup pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        arView.addGestureRecognizer(pinchGesture)

        // Store references
        context.coordinator.arView = arView

        // Update binding
        DispatchQueue.main.async {
            self.gardenScene = scene
        }

        // Initial plant sync
        scene.syncPlants(gardenViewModel.plants)

        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        // Sync plants when view model changes
        context.coordinator.gardenScene?.syncPlants(gardenViewModel.plants)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlantTapped: onPlantTapped)
    }

    class Coordinator: NSObject {
        var arView: ARView?
        var gardenScene: GardenScene?
        let onPlantTapped: (UUID) -> Void

        private var lastPanLocation: CGPoint = .zero
        private var initialPinchScale: Float = 1.0

        init(onPlantTapped: @escaping (UUID) -> Void) {
            self.onPlantTapped = onPlantTapped
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView else { return }

            let location = gesture.location(in: arView)

            // Perform hit test
            let results = arView.hitTest(location)

            for result in results {
                // Walk up entity hierarchy to find plant root
                var entity: Entity? = result.entity
                while let current = entity {
                    if let plantID = UUID(uuidString: current.name) {
                        // Found a plant!
                        onPlantTapped(plantID)

                        // Visual feedback - pulse animation
                        gardenScene?.animatePlantSelection(plantID)
                        return
                    }
                    entity = current.parent
                }
            }

            // Tapped empty space - could deselect or do nothing
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let gardenScene = gardenScene else { return }

            let translation = gesture.translation(in: gesture.view)

            switch gesture.state {
            case .began:
                lastPanLocation = .zero
            case .changed:
                let delta = CGPoint(
                    x: translation.x - lastPanLocation.x,
                    y: translation.y - lastPanLocation.y
                )
                gardenScene.orbitCamera(deltaX: Float(delta.x), deltaY: Float(delta.y))
                lastPanLocation = CGPoint(x: translation.x, y: translation.y)
            default:
                break
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let gardenScene = gardenScene else { return }

            switch gesture.state {
            case .began:
                initialPinchScale = gardenScene.currentZoom
            case .changed:
                let newZoom = initialPinchScale / Float(gesture.scale)
                gardenScene.setZoom(newZoom)
            default:
                break
            }
        }
    }
}
