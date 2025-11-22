import SwiftUI

/// Test view for complete barcode scan → lookup → log flow
struct CompleteScanFlowTestView: View {
    @State private var showScanner = false
    @State private var showLookup = false
    @State private var scannedBarcode: String?
    @State private var logsCount = 0

    var body: some View {
        ZStack {
            AppColors.richSoil
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(AppColors.healthy)

                    Text("Complete Scan Flow Test")
                        .font(AppFont.heading1())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Test the entire barcode scanning workflow")
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Current status
                VStack(spacing: Spacing.sm) {
                    HStack {
                        Text("Substance Logs:")
                            .font(AppFont.body())
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("\(logsCount)")
                            .font(AppFont.heading3())
                            .foregroundColor(AppColors.healthy)
                    }

                    if let barcode = scannedBarcode {
                        HStack {
                            Text("Last Scanned:")
                                .font(AppFont.body())
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Text(barcode)
                                .font(AppFont.bodySmall())
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                }
                .padding()
                .background(AppColors.lightSoil)
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
                        .font(AppFont.button())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.healthy)
                        .cornerRadius(CornerRadius.medium)
                    }

                    // Quick test buttons
                    Text("Or test with known barcodes:")
                        .font(AppFont.label())
                        .foregroundColor(AppColors.textTertiary)

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
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textSecondary)
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
                        .font(AppFont.body())
                        .foregroundColor(AppColors.textPrimary)
                    Text(barcode)
                        .font(AppFont.labelSmall())
                        .foregroundColor(AppColors.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(AppColors.healthy)
            }
            .padding()
            .background(AppColors.lightSoil)
            .cornerRadius(CornerRadius.medium)
        }
    }
}

#Preview {
    CompleteScanFlowTestView()
}
