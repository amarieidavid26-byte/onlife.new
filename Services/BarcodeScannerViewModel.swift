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

    var captureSession: AVCaptureSession?

    // MARK: - Camera Permission

    /// Request camera access permission
    /// - Parameter completion: Callback with permission status
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Scanning Control

    /// Start the barcode scanning session
    func startScanning() {
        guard captureSession == nil else { return }

        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            errorMessage = "Camera not available"
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)

            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
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
            } else {
                errorMessage = "Could not add metadata output"
                return
            }

            captureSession = session

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }

            isScanning = true
        } catch {
            errorMessage = "Camera setup failed: \(error.localizedDescription)"
        }
    }

    /// Stop the barcode scanning session
    func stopScanning() {
        captureSession?.stopRunning()
        captureSession = nil
        isScanning = false
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
