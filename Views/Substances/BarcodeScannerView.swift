import SwiftUI
import AVFoundation

/// Lookup state for barcode scanner
enum ScannerLookupState: Equatable {
    case scanning
    case scanned(String)
    case lookingUp(String)
    case found(String)  // barcode - product found
    case notFound(String)  // barcode - product not found
    case error(String)  // error message
}

/// Full-screen barcode scanner view with camera preview
/// Performs product lookup BEFORE dismissing to prevent cancelled requests
struct BarcodeScannerView: View {
    @StateObject private var viewModel = BarcodeScannerViewModel()
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void

    @State private var showPermissionDenied = false
    @State private var lookupState: ScannerLookupState = .scanning
    @State private var lookupTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(session: viewModel.captureSession)
                .ignoresSafeArea()

            // Overlay
            VStack {
                // Header
                HStack {
                    Button(action: {
                        // Cancel any ongoing lookup
                        lookupTask?.cancel()
                        viewModel.stopScanning()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }

                    Spacer()
                }
                .padding()

                Spacer()

                // Scanning frame with state-dependent UI
                VStack(spacing: Spacing.lg) {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(frameColor, lineWidth: 3)
                        .frame(width: 280, height: 200)
                        .overlay(
                            frameOverlay
                        )

                    // Status message
                    Text(statusMessage)
                        .font(AppFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )

                    // Show barcode if scanned
                    if case .lookingUp(let code) = lookupState {
                        Text(code)
                            .font(AppFont.labelSmall())
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Instructions or retry button
                if case .notFound(let code) = lookupState {
                    VStack(spacing: Spacing.md) {
                        Text("Product not found")
                            .font(AppFont.body())
                            .foregroundColor(.white)

                        Button(action: {
                            // Pass barcode for manual entry
                            onScan(code)
                            dismiss()
                        }) {
                            Text("Enter Manually")
                                .font(AppFont.button())
                                .padding(.horizontal, Spacing.xl)
                                .padding(.vertical, Spacing.sm)
                                .background(AppColors.healthy)
                                .foregroundColor(.white)
                                .cornerRadius(CornerRadius.medium)
                        }

                        Button(action: {
                            // Retry scanning
                            lookupState = .scanning
                            viewModel.scannedCode = nil
                            viewModel.scanSuccess = false
                            viewModel.startScanning()
                        }) {
                            Text("Scan Again")
                                .font(AppFont.body())
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color.black.opacity(0.5))
                    )
                    .padding()
                } else if case .scanning = lookupState {
                    Text("Align barcode within the frame")
                        .font(AppFont.body())
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding()
                }
            }
        }
        .onAppear {
            viewModel.requestCameraPermission { granted in
                if granted {
                    viewModel.startScanning()
                } else {
                    showPermissionDenied = true
                }
            }
        }
        .onChange(of: viewModel.scannedCode) { _, newValue in
            if let code = newValue {
                handleScannedCode(code)
            }
        }
        .alert("Camera Permission Required", isPresented: $showPermissionDenied) {
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("OnLife needs camera access to scan barcodes. Please enable it in Settings.")
        }
        .onDisappear {
            // Clean up
            lookupTask?.cancel()
            viewModel.stopScanning()
        }
    }

    // MARK: - Computed Properties

    private var frameColor: Color {
        switch lookupState {
        case .scanning:
            return .white
        case .scanned, .lookingUp:
            return .yellow
        case .found:
            return .green
        case .notFound, .error:
            return .orange
        }
    }

    private var statusMessage: String {
        switch lookupState {
        case .scanning:
            return "Point camera at barcode"
        case .scanned:
            return "Barcode detected!"
        case .lookingUp:
            return "Looking up product..."
        case .found:
            return "Product found!"
        case .notFound:
            return "Not in database"
        case .error(let message):
            return message
        }
    }

    @ViewBuilder
    private var frameOverlay: some View {
        switch lookupState {
        case .scanning:
            EmptyView()
        case .scanned:
            Image(systemName: "barcode")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
        case .lookingUp:
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
        case .found:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
        case .notFound:
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
        }
    }

    // MARK: - Lookup Logic

    private func handleScannedCode(_ code: String) {
        print("🚨🚨🚨 NEW CODE IS RUNNING - handleScannedCode called with: \(code)")
        // Update state to show barcode detected
        lookupState = .scanned(code)

        // Brief pause to show "detected" state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            lookupState = .lookingUp(code)
            performLookup(code)
        }
    }

    private func performLookup(_ code: String) {
        print("🔍 Starting product lookup for: \(code)")

        lookupTask = Task {
            // 1. Check local database first (instant)
            if let _ = ProductDatabaseManager.shared.findProduct(barcode: code) {
                print("✅ Found in local database")
                await MainActor.run {
                    lookupState = .found(code)
                    // Dismiss after brief success animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onScan(code)
                        dismiss()
                    }
                }
                return
            }

            // 2. Try OpenFoodFacts API
            print("🌐 Checking OpenFoodFacts API...")
            do {
                if let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: code) {
                    // Cache for future use
                    ProductDatabaseManager.shared.addUserProduct(product)
                    print("✅ Found in OpenFoodFacts: \(product.displayName)")

                    await MainActor.run {
                        lookupState = .found(code)
                        // Dismiss after brief success animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onScan(code)
                            dismiss()
                        }
                    }
                    return
                }
            } catch {
                if Task.isCancelled {
                    print("🚫 Lookup cancelled")
                    return
                }
                print("⚠️ API error: \(error.localizedDescription)")
            }

            // 3. Not found
            print("❌ Product not found in any database")
            await MainActor.run {
                lookupState = .notFound(code)
            }
        }
    }
}

// MARK: - Camera Preview

/// UIKit wrapper for AVCaptureVideoPreviewLayer
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = PreviewView()
        view.backgroundColor = .black
        print("📷 CameraPreview makeUIView called, session: \(session != nil ? "exists" : "nil")")

        if let session = session {
            setupPreviewLayer(in: view, with: session, coordinator: context.coordinator)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? PreviewView else { return }

        print("📷 CameraPreview updateUIView called, session: \(session != nil ? "exists" : "nil")")

        // If we have a session but no preview layer yet, create it
        if let session = session, context.coordinator.previewLayer == nil {
            print("📷 Creating preview layer in updateUIView")
            setupPreviewLayer(in: view, with: session, coordinator: context.coordinator)
        }

        // Update frame
        if let previewLayer = context.coordinator.previewLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = view.bounds
            CATransaction.commit()
            print("📷 Preview layer frame updated: \(view.bounds)")
        }
    }

    private func setupPreviewLayer(in view: PreviewView, with session: AVCaptureSession, coordinator: Coordinator) {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        coordinator.previewLayer = previewLayer
        view.previewLayer = previewLayer
        print("📷 Preview layer created and added to view")
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }

    /// Custom UIView that properly sizes the preview layer on layout
    class PreviewView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}
