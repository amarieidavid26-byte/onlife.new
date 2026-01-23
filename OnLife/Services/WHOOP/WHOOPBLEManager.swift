//
//  WHOOPBLEManager.swift
//  OnLife
//
//  Real-time heart rate and HRV via BLE Heart Rate Broadcast
//
//  Research basis:
//  - Shaffer et al. 2017: HRV metrics and measurement standards
//  - Peifer et al. 2014: Flow state and HRV relationship (inverted-U model)
//  - Marco Altini: WHOOP BLE accuracy analysis
//  - Bluetooth SIG GATT: Heart Rate Service (180D) specification
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - BLE Heart Rate Constants (Bluetooth SIG GATT Spec)

enum HeartRateBLE {
    // Computed properties avoid MainActor isolation inference
    static var serviceUUID: CBUUID { CBUUID(string: "180D") }
    static var measurementCharacteristicUUID: CBUUID { CBUUID(string: "2A37") }
    static var bodySensorLocationUUID: CBUUID { CBUUID(string: "2A38") }

    // Flags byte bit masks (primitives are fine as let)
    static let hrFormatMask: UInt8 = 0x01       // Bit 0: 0=UINT8, 1=UINT16
    static let sensorContactMask: UInt8 = 0x06  // Bits 1-2
    static let energyExpendedMask: UInt8 = 0x08 // Bit 3
    static let rrIntervalMask: UInt8 = 0x10     // Bit 4: RR-Intervals present
}

// MARK: - Heart Rate Measurement Data

struct HeartRateMeasurement {
    let heartRate: Int                    // BPM
    let sensorContactDetected: Bool?      // nil if not supported
    let energyExpended: Int?              // kJ, nil if not present
    let rrIntervals: [Double]             // RR intervals in MILLISECONDS
    let timestamp: Date

    var hasRRIntervals: Bool { !rrIntervals.isEmpty }
}

// MARK: - Real-time HRV Calculation

struct RealTimeHRV {
    let rmssd: Double           // Root Mean Square of Successive Differences (ms)
    let meanRR: Double          // Mean RR interval (ms)
    let meanHR: Double          // Calculated from meanRR
    let sdnn: Double            // Standard deviation of RR intervals
    let rrCount: Int            // Number of RR intervals used
    let windowDuration: TimeInterval  // Actual duration of data window
    let timestamp: Date

    /// Minimum requirements per Shaffer et al. 2017
    var isValid: Bool {
        rrCount >= 30 && windowDuration >= 30
    }

    /// Ideal: 60+ seconds, 60+ RR intervals
    var isHighQuality: Bool {
        rrCount >= 60 && windowDuration >= 60
    }
}

// MARK: - Connection State

enum WHOOPBLEState: String {
    case disconnected = "Disconnected"
    case scanning = "Scanning..."
    case connecting = "Connecting..."
    case connected = "Connected"
    case receiving = "Receiving HR"
    case error = "Error"
}

// MARK: - WHOOP BLE Manager

@MainActor
final class WHOOPBLEManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = WHOOPBLEManager()

    // MARK: - Published Properties

    @Published private(set) var state: WHOOPBLEState = .disconnected
    @Published private(set) var currentHeartRate: Int = 0
    @Published private(set) var latestHRV: RealTimeHRV?
    @Published private(set) var isReceivingRRIntervals: Bool = false
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var signalQuality: Double = 0.0  // 0-1

    /// Current RR intervals in milliseconds (60-second window for HRV calculation)
    var rrIntervals: [Double] {
        let windowStart = Date().addingTimeInterval(-idealWindowForHRV)
        return rrBuffer.filter { $0.timestamp >= windowStart }.map { $0.rrMs }
    }

    // MARK: - CoreBluetooth

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?

    // MARK: - RR Interval Buffer for HRV Calculation
    // Research: Use 60-second rolling window (Shaffer et al. 2017)

    private var rrBuffer: [(timestamp: Date, rrMs: Double)] = []
    private let maxBufferDuration: TimeInterval = 120  // Keep 2 min, use last 60s
    private let minWindowForHRV: TimeInterval = 30     // Minimum for RMSSD
    private let idealWindowForHRV: TimeInterval = 60   // Ideal per research

    // MARK: - Artifact Detection
    // Research: Discard if >5% ectopic beats (Shaffer et al. 2017)

    private let minRR: Double = 300   // 200 BPM max
    private let maxRR: Double = 2000  // 30 BPM min
    private let maxRRChange: Double = 0.20  // 20% change threshold for ectopic

    // MARK: - Callbacks

    var onHeartRateUpdate: ((Int) -> Void)?
    var onHRVUpdate: ((RealTimeHRV) -> Void)?
    var onRRIntervalsReceived: (([Double]) -> Void)?

    // MARK: - Initialization

    private override init() {
        super.init()
        // Initialize on background queue for BLE operations
        centralManager = CBCentralManager(delegate: nil, queue: DispatchQueue(label: "com.onlife.ble"))
        centralManager.delegate = self
        print("💙 [BLE] WHOOPBLEManager initialized")
    }

    // MARK: - Public Methods

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("💙 [BLE] Cannot scan - Bluetooth not powered on (state: \(centralManager.state.rawValue))")
            state = .error
            return
        }

        print("💙 [BLE] Starting scan for Heart Rate devices...")
        state = .scanning

        // Scan specifically for Heart Rate Service
        centralManager.scanForPeripherals(
            withServices: [HeartRateBLE.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Auto-stop scan after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if self?.state == .scanning {
                self?.stopScanning()
                print("💙 [BLE] Scan timeout - no devices found")
            }
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        if state == .scanning {
            state = .disconnected
        }
        print("💙 [BLE] Stopped scanning")
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        resetState()
        print("💙 [BLE] Disconnected")
    }

    /// Check if Bluetooth is ready for scanning
    var isBluetoothReady: Bool {
        centralManager.state == .poweredOn
    }

    /// Clear HRV buffer (call when starting new session)
    func resetHRVBuffer() {
        rrBuffer.removeAll()
        latestHRV = nil
        signalQuality = 0.0
        print("💙 [BLE] HRV buffer reset")
    }

    private func resetState() {
        connectedPeripheral = nil
        heartRateCharacteristic = nil
        connectedDeviceName = nil
        currentHeartRate = 0
        latestHRV = nil
        isReceivingRRIntervals = false
        rrBuffer.removeAll()
        signalQuality = 0.0
        state = .disconnected
    }

    // MARK: - Heart Rate Data Parsing (Bluetooth SIG GATT Spec)

    private func parseHeartRateMeasurement(from data: Data) -> HeartRateMeasurement? {
        guard data.count >= 2 else { return nil }

        let bytes = [UInt8](data)
        let flags = bytes[0]
        var index = 1

        // Parse heart rate value
        let hrFormat16Bit = (flags & HeartRateBLE.hrFormatMask) != 0
        let heartRate: Int

        if hrFormat16Bit {
            guard data.count >= 3 else { return nil }
            heartRate = Int(bytes[1]) | (Int(bytes[2]) << 8)
            index = 3
        } else {
            heartRate = Int(bytes[1])
            index = 2
        }

        // Parse sensor contact (bits 1-2)
        let sensorContactBits = (flags & HeartRateBLE.sensorContactMask) >> 1
        let sensorContactDetected: Bool?
        switch sensorContactBits {
        case 2: sensorContactDetected = false  // Supported, not detected
        case 3: sensorContactDetected = true   // Supported and detected
        default: sensorContactDetected = nil   // Not supported
        }

        // Parse energy expended if present
        var energyExpended: Int?
        if (flags & HeartRateBLE.energyExpendedMask) != 0 {
            guard data.count >= index + 2 else { return nil }
            energyExpended = Int(bytes[index]) | (Int(bytes[index + 1]) << 8)
            index += 2
        }

        // Parse RR intervals if present (CRITICAL FOR HRV)
        var rrIntervals: [Double] = []
        if (flags & HeartRateBLE.rrIntervalMask) != 0 {
            // RR intervals are UINT16, units of 1/1024 seconds
            while index + 1 < data.count {
                let rrRaw = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
                // Convert to milliseconds: rrRaw * 1000 / 1024
                let rrMs = Double(rrRaw) * 1000.0 / 1024.0
                rrIntervals.append(rrMs)
                index += 2
            }
        }

        return HeartRateMeasurement(
            heartRate: heartRate,
            sensorContactDetected: sensorContactDetected,
            energyExpended: energyExpended,
            rrIntervals: rrIntervals,
            timestamp: Date()
        )
    }

    // MARK: - RR Interval Processing & Artifact Detection

    private func processRRIntervals(_ rrIntervals: [Double], timestamp: Date) {
        guard !rrIntervals.isEmpty else { return }

        isReceivingRRIntervals = true
        onRRIntervalsReceived?(rrIntervals)

        // Add to buffer with artifact filtering
        for rr in rrIntervals {
            // Basic physiological bounds check
            guard rr >= minRR && rr <= maxRR else {
                print("💙 [BLE] Rejected RR \(Int(rr))ms - outside bounds [\(Int(minRR))-\(Int(maxRR))]")
                continue
            }

            // Ectopic beat detection (>20% change from previous)
            if let lastRR = rrBuffer.last?.rrMs {
                let changeRatio = abs(rr - lastRR) / lastRR
                if changeRatio > maxRRChange {
                    print("💙 [BLE] Potential ectopic: \(Int(rr))ms (Δ\(Int(changeRatio * 100))% from \(Int(lastRR))ms)")
                    // Still add but could flag for quality scoring
                }
            }

            rrBuffer.append((timestamp: timestamp, rrMs: rr))
        }

        // Trim buffer to max duration
        let cutoff = Date().addingTimeInterval(-maxBufferDuration)
        rrBuffer.removeAll { $0.timestamp < cutoff }

        // Calculate HRV if we have enough data
        calculateRealTimeHRV()
    }

    // MARK: - RMSSD Calculation (Shaffer et al. 2017)

    private func calculateRealTimeHRV() {
        // Use last 60 seconds of data (or 30s minimum)
        let now = Date()
        let windowStart = now.addingTimeInterval(-idealWindowForHRV)
        let minWindowStart = now.addingTimeInterval(-minWindowForHRV)

        // Get RR intervals in window
        var windowRRs = rrBuffer.filter { $0.timestamp >= windowStart }.map { $0.rrMs }

        // Fall back to minimum window if not enough data
        if windowRRs.count < 30 {
            windowRRs = rrBuffer.filter { $0.timestamp >= minWindowStart }.map { $0.rrMs }
        }

        guard windowRRs.count >= 10 else {
            // Not enough data yet - this is normal during initial collection
            return
        }

        // Calculate RMSSD: √(Σ(RRᵢ₊₁ - RRᵢ)² / N)
        var sumSquaredDiffs: Double = 0
        for i in 0..<(windowRRs.count - 1) {
            let diff = windowRRs[i + 1] - windowRRs[i]
            sumSquaredDiffs += diff * diff
        }
        let rmssd = sqrt(sumSquaredDiffs / Double(windowRRs.count - 1))

        // Calculate mean RR and HR
        let meanRR = windowRRs.reduce(0, +) / Double(windowRRs.count)
        let meanHR = 60000.0 / meanRR  // Convert to BPM

        // Calculate SDNN (standard deviation)
        let variance = windowRRs.map { pow($0 - meanRR, 2) }.reduce(0, +) / Double(windowRRs.count)
        let sdnn = sqrt(variance)

        // Determine actual window duration
        let windowData = rrBuffer.filter { $0.timestamp >= windowStart }
        let firstTimestamp = windowData.first?.timestamp ?? now
        let windowDuration = now.timeIntervalSince(firstTimestamp)

        let hrv = RealTimeHRV(
            rmssd: rmssd,
            meanRR: meanRR,
            meanHR: meanHR,
            sdnn: sdnn,
            rrCount: windowRRs.count,
            windowDuration: windowDuration,
            timestamp: now
        )

        latestHRV = hrv
        onHRVUpdate?(hrv)

        // Update signal quality (based on RR interval consistency)
        let expectedRRs = Int(windowDuration)  // ~1 per second
        signalQuality = min(1.0, Double(windowRRs.count) / Double(max(1, expectedRRs)))

        print("💙 [BLE] HRV: RMSSD=\(String(format: "%.1f", rmssd))ms, HR=\(Int(meanHR))bpm, RRs=\(windowRRs.count), Quality=\(Int(signalQuality * 100))%")
    }

    // MARK: - Flow State Detection Integration

    /// Check if current HRV indicates potential flow state
    /// Based on Peifer et al. 2014 inverted-U model
    func getFlowIndicator(baselineRMSSD: Double?) -> (inFlowZone: Bool, message: String) {
        guard let hrv = latestHRV, hrv.isValid else {
            return (false, "Collecting HRV data...")
        }

        guard let baseline = baselineRMSSD else {
            return (false, "No baseline established")
        }

        // Flow zone: RMSSD between 70-95% of baseline (moderate parasympathetic withdrawal)
        let ratio = hrv.rmssd / baseline

        if ratio < 0.50 {
            return (false, "High stress - consider a break")
        } else if ratio < 0.70 {
            return (false, "Building focus...")
        } else if ratio <= 0.95 {
            return (true, "In flow zone!")
        } else if ratio <= 1.10 {
            return (true, "Relaxed focus")
        } else {
            return (false, "Too relaxed - need activation")
        }
    }

    /// Get current HRV as percentage of baseline
    func getHRVRatio(baselineRMSSD: Double) -> Double? {
        guard let hrv = latestHRV else { return nil }
        return hrv.rmssd / baselineRMSSD
    }
}

// MARK: - CBCentralManagerDelegate

extension WHOOPBLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                print("💙 [BLE] Bluetooth powered on")
            case .poweredOff:
                print("💙 [BLE] Bluetooth powered off")
                self.state = .disconnected
            case .unauthorized:
                print("💙 [BLE] Bluetooth unauthorized - check Settings")
                self.state = .error
            case .unsupported:
                print("💙 [BLE] Bluetooth unsupported on this device")
                self.state = .error
            case .resetting:
                print("💙 [BLE] Bluetooth resetting...")
            case .unknown:
                print("💙 [BLE] Bluetooth state unknown")
            @unknown default:
                print("💙 [BLE] Bluetooth unknown state: \(central.state.rawValue)")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let name = peripheral.name ?? "Unknown HR Device"
            print("💙 [BLE] Discovered: \(name) (RSSI: \(RSSI)dB)")

            // Log advertisement data for debugging
            if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
                print("💙 [BLE] Local name: \(localName)")
            }

            // Connect to first device with HR service (likely WHOOP if HR Broadcast is on)
            self.stopScanning()
            self.connectedPeripheral = peripheral
            self.connectedDeviceName = name
            self.state = .connecting
            central.connect(peripheral, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            print("💙 [BLE] Connected to \(peripheral.name ?? "device")")
            self.state = .connected
            peripheral.delegate = self
            peripheral.discoverServices([HeartRateBLE.serviceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("💙 [BLE] Disconnected with error: \(error.localizedDescription)")
            } else {
                print("💙 [BLE] Disconnected from \(peripheral.name ?? "device")")
            }
            self.resetState()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("💙 [BLE] Failed to connect: \(error?.localizedDescription ?? "unknown error")")
            self.state = .error
            self.connectedPeripheral = nil
            self.connectedDeviceName = nil
        }
    }
}

// MARK: - CBPeripheralDelegate

extension WHOOPBLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("💙 [BLE] Service discovery error: \(error.localizedDescription)")
            return
        }

        for service in peripheral.services ?? [] {
            print("💙 [BLE] Found service: \(service.uuid)")
            if service.uuid == HeartRateBLE.serviceUUID {
                print("💙 [BLE] Found Heart Rate Service - discovering characteristics...")
                peripheral.discoverCharacteristics(
                    [HeartRateBLE.measurementCharacteristicUUID, HeartRateBLE.bodySensorLocationUUID],
                    for: service
                )
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("💙 [BLE] Characteristic discovery error: \(error.localizedDescription)")
            return
        }

        for characteristic in service.characteristics ?? [] {
            print("💙 [BLE] Found characteristic: \(characteristic.uuid)")

            if characteristic.uuid == HeartRateBLE.measurementCharacteristicUUID {
                print("💙 [BLE] Found Heart Rate Measurement - subscribing to notifications...")
                Task { @MainActor in
                    self.heartRateCharacteristic = characteristic
                }
                // Subscribe to notifications
                peripheral.setNotifyValue(true, for: characteristic)
            }

            if characteristic.uuid == HeartRateBLE.bodySensorLocationUUID {
                // Read body sensor location (optional)
                peripheral.readValue(for: characteristic)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("💙 [BLE] Value update error: \(error.localizedDescription)")
            return
        }

        if characteristic.uuid == HeartRateBLE.bodySensorLocationUUID,
           let data = characteristic.value,
           let locationByte = data.first {
            let locations = ["Other", "Chest", "Wrist", "Finger", "Hand", "Ear Lobe", "Foot"]
            let location = Int(locationByte) < locations.count ? locations[Int(locationByte)] : "Unknown"
            print("💙 [BLE] Sensor location: \(location)")
            return
        }

        guard characteristic.uuid == HeartRateBLE.measurementCharacteristicUUID,
              let data = characteristic.value else {
            return
        }

        Task { @MainActor in
            guard let measurement = self.parseHeartRateMeasurement(from: data) else {
                print("💙 [BLE] Failed to parse heart rate data")
                return
            }

            self.state = .receiving
            self.currentHeartRate = measurement.heartRate
            self.onHeartRateUpdate?(measurement.heartRate)

            // Process RR intervals for HRV
            if measurement.hasRRIntervals {
                self.processRRIntervals(measurement.rrIntervals, timestamp: measurement.timestamp)
            } else {
                // WHOOP stops sending RR during motion (per Marco Altini research)
                self.isReceivingRRIntervals = false
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("💙 [BLE] Notification state error: \(error.localizedDescription)")
            return
        }

        if characteristic.uuid == HeartRateBLE.measurementCharacteristicUUID {
            if characteristic.isNotifying {
                print("💙 [BLE] ✅ Subscribed to Heart Rate notifications - waiting for data...")
            } else {
                print("💙 [BLE] ❌ Unsubscribed from Heart Rate notifications")
            }
        }
    }
}
