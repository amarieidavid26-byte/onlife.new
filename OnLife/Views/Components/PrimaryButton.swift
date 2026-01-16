import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var color: Color = OnLifeColors.sage

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(OnLifeFont.button())
                .foregroundColor(OnLifeColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: ComponentSize.buttonHeight)
                .background(color)
                .cornerRadius(ComponentSize.buttonCornerRadius)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
