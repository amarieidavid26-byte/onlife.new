import SwiftUI
import AVFoundation

// MARK: - QR Code Scanner View

struct QRCodeScannerView: View {
    let onCodeScanned: (String) -> Void
    let onDismiss: () -> Void

    @State private var isScanning = true
    @State private var scannedCode: String?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var torchOn = false
    @State private var cameraPermissionGranted = false

    var body: some View {
        NavigationView {
            ZStack {
                // Camera preview
                if cameraPermissionGranted {
                    QRScannerCameraView(
                        isScanning: $isScanning,
                        torchOn: $torchOn,
                        onCodeFound: handleCodeFound
                    )
                    .ignoresSafeArea()
                } else {
                    permissionDeniedView
                }

                // Overlay
                scannerOverlay

                // Bottom controls
                VStack {
                    Spacer()
                    bottomControls
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { torchOn.toggle() }) {
                        Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 16))
                            .foregroundColor(torchOn ? OnLifeColors.amber : .white)
                    }
                }
            }
            .alert("Scan Error", isPresented: $showingError) {
                Button("Try Again") {
                    isScanning = true
                }
                Button("Cancel", role: .cancel) {
                    onDismiss()
                }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                checkCameraPermission()
            }
        }
    }

    // MARK: - Scanner Overlay

    private var scannerOverlay: some View {
        GeometryReader { geometry in
            let scannerSize = min(geometry.size.width, geometry.size.height) * 0.7

            ZStack {
                // Dimmed area
                Color.black.opacity(0.5)

                // Clear scanning area
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .frame(width: scannerSize, height: scannerSize)
                    .blendMode(.destinationOut)

                // Scanning frame
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(OnLifeColors.socialTeal, lineWidth: 3)
                    .frame(width: scannerSize, height: scannerSize)

                // Corner accents
                scannerCorners(size: scannerSize)

            }
            .compositingGroup()
        }
    }

    private func scannerCorners(size: CGFloat) -> some View {
        let cornerLength: CGFloat = 30
        let cornerWidth: CGFloat = 4

        return ZStack {
            // Top left
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(OnLifeColors.socialTeal)
                        .frame(width: cornerLength, height: cornerWidth)
                    Spacer()
                }
                RoundedRectangle(cornerRadius: 2)
                    .fill(OnLifeColors.socialTeal)
                    .frame(width: cornerWidth, height: cornerLength - cornerWidth)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }

            // Top right
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(OnLifeColors.socialTeal)
                        .frame(width: cornerLength, height: cornerWidth)
                }
                RoundedRectangle(cornerRadius: 2)
                    .fill(OnLifeColors.socialTeal)
                    .frame(width: cornerWidth, height: cornerLength - cornerWidth)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer()
            }

            // Bottom left
            VStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(OnLifeColors.socialTeal)
                    .frame(width: cornerWidth, height: cornerLength - cornerWidth)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(OnLifeColors.socialTeal)
                        .frame(width: cornerLength, height: cornerWidth)
                    Spacer()
                }
            }

            // Bottom right
            VStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(OnLifeColors.socialTeal)
                    .frame(width: cornerWidth, height: cornerLength - cornerWidth)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(OnLifeColors.socialTeal)
                        .frame(width: cornerLength, height: cornerWidth)
                }
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: Spacing.md) {
            // Main instruction
            Text("Align QR code within the frame")
                .font(OnLifeFont.body())
                .foregroundColor(.white)

            // Status indicator
            if isScanning {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: OnLifeColors.socialTeal))
                        .scaleEffect(0.8)

                    Text("Scanning...")
                        .font(OnLifeFont.caption())
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if scannedCode != nil {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(OnLifeColors.healthy)

                    Text("Code found!")
                        .font(OnLifeFont.caption())
                        .foregroundColor(OnLifeColors.healthy)
                }
            }

            // Manual entry option
            Button(action: {
                // Could show manual entry sheet
            }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 14))

                    Text("Enter code manually")
                        .font(OnLifeFont.bodySmall())
                }
                .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, Spacing.sm)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xxl)
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(OnLifeColors.textMuted)

            VStack(spacing: Spacing.sm) {
                Text("Camera Access Required")
                    .font(OnLifeFont.heading3())
                    .foregroundColor(OnLifeColors.textPrimary)

                Text("To scan QR codes, please allow camera access in Settings")
                    .font(OnLifeFont.body())
                    .foregroundColor(OnLifeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: openSettings) {
                Text("Open Settings")
                    .font(OnLifeFont.button())
                    .foregroundColor(OnLifeColors.textPrimary)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(
                        Capsule()
                            .fill(OnLifeColors.socialTeal)
                    )
            }
        }
        .padding(Spacing.xl)
    }

    // MARK: - Helpers

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionGranted = granted
                }
            }
        default:
            cameraPermissionGranted = false
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func handleCodeFound(_ code: String) {
        guard isScanning else { return }

        isScanning = false
        scannedCode = code
        HapticManager.shared.notificationOccurred(.success)

        // Validate it's an OnLife invite link
        if code.contains("onlife.app/invite") {
            onCodeScanned(code)
        } else {
            errorMessage = "This doesn't appear to be a valid OnLife invite code"
            showingError = true
        }
    }
}

// MARK: - QR Scanner Camera View (UIKit wrapper)

struct QRScannerCameraView: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    @Binding var torchOn: Bool
    let onCodeFound: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        if torchOn != uiViewController.isTorchOn {
            uiViewController.setTorch(on: torchOn)
        }

        if isScanning != uiViewController.isScanning {
            if isScanning {
                uiViewController.startScanning()
            } else {
                uiViewController.stopScanning()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeFound: onCodeFound)
    }

    class Coordinator: NSObject, QRScannerViewControllerDelegate {
        let onCodeFound: (String) -> Void

        init(onCodeFound: @escaping (String) -> Void) {
            self.onCodeFound = onCodeFound
        }

        func didFindCode(_ code: String) {
            onCodeFound(code)
        }
    }
}

// MARK: - QR Scanner View Controller

protocol QRScannerViewControllerDelegate: AnyObject {
    func didFindCode(_ code: String)
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRScannerViewControllerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    var isScanning = false
    var isTorchOn = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)

            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }

            let metadataOutput = AVCaptureMetadataOutput()

            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

            startScanning()
        } catch {
            print("Error setting up camera: \(error)")
        }
    }

    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            DispatchQueue.main.async {
                self?.isScanning = true
            }
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
        isScanning = false
    }

    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            isTorchOn = on
        } catch {
            print("Error setting torch: \(error)")
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard isScanning,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else { return }

        delegate?.didFindCode(stringValue)
    }
}

// MARK: - Preview

#if DEBUG
struct QRCodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeScannerView(
            onCodeScanned: { _ in },
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
