import SwiftUI

struct CardView<Content: View>: View {
    let content: Content
    var elevated: Bool = false

    init(elevated: Bool = false, @ViewBuilder content: () -> Content) {
        self.elevated = elevated
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(elevated ? OnLifeColors.cardBackgroundElevated : OnLifeColors.cardBackground)
            )
            .shadow(
                color: Color.black.opacity(0.15),
                radius: 8,
                y: 4
            )
    }
}

// MARK: - Pressable Card

struct PressableCardView<Content: View>: View {
    let content: Content
    var elevated: Bool = false
    let action: () -> Void

    init(elevated: Bool = false, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.elevated = elevated
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            content
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .fill(elevated ? OnLifeColors.cardBackgroundElevated : OnLifeColors.cardBackground)
                )
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 8,
                    y: 4
                )
        }
        .buttonStyle(PressableCardStyle())
    }
}
