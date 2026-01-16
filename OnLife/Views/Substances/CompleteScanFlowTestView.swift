import SwiftUI

/// Test view for complete barcode scan → lookup → log flow
struct CompleteScanFlowTestView: View {
    @State private var showScanner = false
    @State private var showLookup = false
    @State private var scannedBarcode: String?
    @State private var logsCount = 0

    var body: some View {
        ZStack {
            OnLifeColors.deepForest
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(OnLifeColors.sage)

                    Text("Complete Scan Flow Test")
                        .font(OnLifeFont.heading1())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Test the entire barcode scanning workflow")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Current status
                VStack(spacing: Spacing.sm) {
                    HStack {
                        Text("Substance Logs:")
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textSecondary)
                        Spacer()
                        Text("\(logsCount)")
                            .font(OnLifeFont.heading3())
                            .foregroundColor(OnLifeColors.sage)
                    }

                    if let barcode = scannedBarcode {
                        HStack {
                            Text("Last Scanned:")
                                .font(OnLifeFont.body())
                                .foregroundColor(OnLifeColors.textSecondary)
                            Spacer()
                            Text(barcode)
                                .font(OnLifeFont.bodySmall())
                                .foregroundColor(OnLifeColors.textPrimary)
                        }
                    }
                }
                .padding()
                .background(OnLifeColors.cardBackground)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal)

                // Test buttons
                VStack(spacing: Spacing.md) {
                    Button(action: {
                        showScanner = true
                    }) {
                        HStack {
                            Image(systemName: "barcode.viewfinder")
                            Text("Start Barcode Scanner")
                        }
                        .font(OnLifeFont.button())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(OnLifeColors.sage)
                        .cornerRadius(CornerRadius.medium)
                    }

                    // Quick test buttons
                    Text("Or test with known barcodes:")
                        .font(OnLifeFont.label())
                        .foregroundColor(OnLifeColors.textTertiary)

                    QuickTestButton(
                        title: "Monster Ultra (Local DB)",
                        barcode: "070847811800",
                        onTap: testBarcode
                    )

                    QuickTestButton(
                        title: "Red Bull (Local DB)",
                        barcode: "9002490100070",
                        onTap: testBarcode
                    )

                    QuickTestButton(
                        title: "Unknown Product",
                        barcode: "999999999999",
                        onTap: testBarcode
                    )
                }
                .padding(.horizontal)

                Spacer()

                // Reset button
                Button(action: resetTest) {
                    Text("Reset Test")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)
                }
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showScanner) {
            BarcodeScannerView { code in
                handleScannedBarcode(code)
            }
        }
        .fullScreenCover(isPresented: $showLookup) {
            if let barcode = scannedBarcode {
                ProductLookupView(barcode: barcode) {
                    handleProductLogged()
                }
            }
        }
        .onAppear {
            updateLogsCount()
        }
    }

    private func testBarcode(_ barcode: String) {
        handleScannedBarcode(barcode)
    }

    private func handleScannedBarcode(_ barcode: String) {
        scannedBarcode = barcode
        showLookup = true
    }

    private func handleProductLogged() {
        updateLogsCount()
    }

    private func updateLogsCount() {
        logsCount = SubstanceTracker.shared.logs.count
    }

    private func resetTest() {
        scannedBarcode = nil
        updateLogsCount()
    }
}

struct QuickTestButton: View {
    let title: String
    let barcode: String
    let onTap: (String) -> Void

    var body: some View {
        Button(action: { onTap(barcode) }) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textPrimary)
                    Text(barcode)
                        .font(OnLifeFont.labelSmall())
                        .foregroundColor(OnLifeColors.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(OnLifeColors.sage)
            }
            .padding()
            .background(OnLifeColors.cardBackground)
            .cornerRadius(CornerRadius.medium)
        }
    }
}

#Preview {
    CompleteScanFlowTestView()
}
