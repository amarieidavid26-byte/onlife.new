import SwiftUI

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(ComponentSize.cardPadding)
            .background(AppColors.lightSoil)
            .cornerRadius(ComponentSize.cardCornerRadius)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}
