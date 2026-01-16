import SwiftUI

/// Test view for barcode scanner functionality
/// This is a standalone test view to verify scanner works before integrating
struct BarcodeScannerTestView: View {
    @State private var showScanner = false
    @State private var scannedCode: String?

    var body: some View {
        ZStack {
            OnLifeColors.deepForest
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(OnLifeColors.sage)

                    Text("Barcode Scanner Test")
                        .font(OnLifeFont.heading1())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Test the barcode scanning functionality")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let code = scannedCode {
                    VStack(spacing: Spacing.sm) {
                        Text("Scanned Code:")
                            .font(OnLifeFont.label())
                            .foregroundColor(OnLifeColors.textTertiary)

                        Text(code)
                            .font(OnLifeFont.heading3())
                            .foregroundColor(OnLifeColors.sage)
                            .padding()
                            .background(OnLifeColors.cardBackground)
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
                    .font(OnLifeFont.button())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(OnLifeColors.sage)
                    .cornerRadius(CornerRadius.medium)
                }
                .padding(.horizontal)

                if scannedCode != nil {
                    Button(action: {
                        scannedCode = nil
                    }) {
                        Text("Reset")
                            .font(OnLifeFont.button())
                            .foregroundColor(OnLifeColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(OnLifeColors.cardBackground)
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
