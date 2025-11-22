import SwiftUI

/// Test view for barcode scanner functionality
/// This is a standalone test view to verify scanner works before integrating
struct BarcodeScannerTestView: View {
    @State private var showScanner = false
    @State private var scannedCode: String?

    var body: some View {
        ZStack {
            AppColors.richSoil
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(AppColors.healthy)

                    Text("Barcode Scanner Test")
                        .font(AppFont.heading1())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Test the barcode scanning functionality")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let code = scannedCode {
                    VStack(spacing: Spacing.sm) {
                        Text("Scanned Code:")
                            .font(AppFont.label())
                            .foregroundColor(AppColors.textTertiary)

                        Text(code)
                            .font(AppFont.heading3())
                            .foregroundColor(AppColors.healthy)
                            .padding()
                            .background(AppColors.lightSoil)
                            .cornerRadius(CornerRadius.medium)
                    }
                    .padding()
                }

                Button(action: {
                    showScanner = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Scan Barcode")
                    }
                    .font(AppFont.button())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.healthy)
                    .cornerRadius(CornerRadius.medium)
                }
                .padding(.horizontal)

                if scannedCode != nil {
                    Button(action: {
                        scannedCode = nil
                    }) {
                        Text("Reset")
                            .font(AppFont.button())
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.lightSoil)
                            .cornerRadius(CornerRadius.medium)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showScanner) {
            BarcodeScannerView { code in
                scannedCode = code
            }
        }
    }
}

#Preview {
    BarcodeScannerTestView()
}
