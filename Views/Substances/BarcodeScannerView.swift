import SwiftUI
import AVFoundation

/// Full-screen barcode scanner view with camera preview
struct BarcodeScannerView: View {
    @StateObject private var viewModel = BarcodeScannerViewModel()
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void

    @State private var showPermissionDenied = false

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(session: viewModel.captureSession)
                .ignoresSafeArea()

            // Overlay
            VStack {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
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

                // Scanning frame
                VStack(spacing: Spacing.lg) {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            viewModel.scanSuccess ? Color.green : Color.white,
                            lineWidth: 3
                        )
                        .frame(width: 280, height: 200)
                        .overlay(
                            VStack {
                                if viewModel.scanSuccess {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.green)
                                }
                            }
                        )

                    Text(viewModel.scanSuccess ? "Barcode Scanned!" : "Point camera at barcode")
                        .font(AppFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                }

                Spacer()

                // Instructions
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
                // Wait a moment for success animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onScan(code)
                    dismiss()
                }
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
    }
}

// MARK: - Camera Preview

/// UIKit wrapper for AVCaptureVideoPreviewLayer
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        if let session = session {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            DispatchQueue.main.async {
                previewLayer.frame = view.bounds
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}
