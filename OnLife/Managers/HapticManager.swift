import UIKit
import Combine

class HapticManager: ObservableObject {
    static let shared = HapticManager()

    @Published var hapticsEnabled: Bool = true

    private init() {}

    // MARK: - Basic Haptics

    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    func selection() {
        guard hapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Custom Haptic Sequences

    func seedPlantingSequence() {
        guard hapticsEnabled else { return }

        impact(style: .light)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.impact(style: .medium)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.impact(style: .heavy)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.notification(type: .success)
        }
    }

    func plantGrowthTick() {
        guard hapticsEnabled else { return }
        impact(style: .soft)
    }

    func sessionCompleteSequence() {
        guard hapticsEnabled else { return }

        impact(style: .medium)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impact(style: .medium)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.notification(type: .success)
        }
    }

    func sessionAbandonedSequence() {
        guard hapticsEnabled else { return }

        impact(style: .heavy)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.notification(type: .warning)
        }
    }
}
