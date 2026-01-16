import SwiftUI

struct CustomToggle: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        HStack {
            Text(label)
                .font(OnLifeFont.body())
                .foregroundColor(OnLifeColors.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(OnLifeColors.sage)
        }
        .padding(Spacing.lg)
        .background(OnLifeColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }
}
