import SwiftUI
import Combine
import AVFoundation
import Vision

/// ViewModel for managing barcode scanning with AVFoundation
class BarcodeScannerViewModel: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var scanSuccess = false

    /// Published so SwiftUI updates when session is created
    @Published var captureSession: AVCaptureSession?

    // MARK: - Camera Permission

    /// Request camera access permission
    /// - Parameter completion: Callback with permission status
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📷 Camera authorization status: \(status.rawValue)")

        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("📷 Camera permission granted: \(granted)")
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }

    // MARK: - Scanning Control

    /// Start the barcode scanning session
    func startScanning() {
        guard captureSession == nil else {
            print("📷 Session already exists")
            return
        }

        print("📷 Starting camera setup...")

        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("📷 ERROR: Camera not available")
            errorMessage = "Camera not available"
            return
        }

        print("📷 Camera device found: \(videoCaptureDevice.localizedName)")

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)

            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                print("📷 Video input added")
            } else {
                print("📷 ERROR: Could not add video input")
                errorMessage = "Could not add video input"
                return
            }

            let metadataOutput = AVCaptureMetadataOutput()

            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [
                    .ean8, .ean13, .upce, .code39, .code128, .qr
                ]
                print("📷 Metadata output added with barcode types")
            } else {
                print("📷 ERROR: Could not add metadata output")
                errorMessage = "Could not add metadata output"
                return
            }

            // Update captureSession on main thread to trigger SwiftUI update
            DispatchQueue.main.async { [weak self] in
                self?.captureSession = session
                self?.isScanning = true
                print("📷 Session assigned to published property")
            }

            // Start running on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                print("📷 Session running: \(session.isRunning)")
            }

        } catch {
            print("📷 ERROR: Camera setup failed: \(error.localizedDescription)")
            errorMessage = "Camera setup failed: \(error.localizedDescription)"
        }
    }

    /// Stop the barcode scanning session
    func stopScanning() {
        print("📷 Stopping scanner...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
            DispatchQueue.main.async {
                self?.captureSession = nil
                self?.isScanning = false
                print("📷 Scanner stopped")
            }
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {

            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()

            // Set scanned code
            scannedCode = stringValue
            scanSuccess = true

            // Stop scanning
            stopScanning()
        }
    }
}
