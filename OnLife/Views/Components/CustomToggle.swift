import SwiftUI

struct CustomToggle: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppFont.body())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppColors.healthy)
        }
        .padding(Spacing.lg)
        .background(AppColors.lightSoil)
        .cornerRadius(CornerRadius.medium)
    }
}
