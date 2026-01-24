import Foundation
import QuartzCore
import Combine
import os.log

/// Monitors and adapts to device performance
/// Tracks FPS, memory usage, and thermal state to adjust quality dynamically
@MainActor
class PerformanceMonitor: ObservableObject {

    // MARK: - Singleton

    static let shared = PerformanceMonitor()

    // MARK: - Published State

    @Published private(set) var currentFPS: Double = 60
    @Published private(set) var averageFPS: Double = 60
    @Published private(set) var memoryUsageMB: Double = 0
    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published private(set) var performanceLevel: PerformanceLevel = .high

    // MARK: - Performance Levels

    enum PerformanceLevel: String, CaseIterable {
        case high = "High"           // Full effects
        case medium = "Medium"       // Reduced particles
        case low = "Low"             // Minimal effects
        case critical = "Critical"   // Bare minimum

        var particleMultiplier: Float {
            switch self {
            case .high: return 1.0
            case .medium: return 0.5
            case .low: return 0.2
            case .critical: return 0.0
            }
        }

        var windEnabled: Bool {
            return self != .critical
        }

        var shadowsEnabled: Bool {
            return self == .high || self == .medium
        }

        var particlesEnabled: Bool {
            return self != .critical
        }

        var icon: String {
            switch self {
            case .high: return "gauge.with.dots.needle.100percent"
            case .medium: return "gauge.with.dots.needle.67percent"
            case .low: return "gauge.with.dots.needle.33percent"
            case .critical: return "exclamationmark.triangle"
            }
        }

        var color: String {
            switch self {
            case .high: return "green"
            case .medium: return "yellow"
            case .low: return "orange"
            case .critical: return "red"
            }
        }
    }

    // MARK: - Internal State

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fpsHistory: [Double] = []
    private let fpsHistorySize = 30
    private var memoryTimer: Timer?

    private let logger = Logger(subsystem: "com.onlife", category: "Performance")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Thresholds

    private let lowFPSThreshold: Double = 45
    private let criticalFPSThreshold: Double = 30
    private let highMemoryThresholdMB: Double = 300
    private let criticalMemoryThresholdMB: Double = 450

    // MARK: - Initialization

    private init() {
        setupThermalMonitoring()
    }

    // MARK: - Setup

    func startMonitoring() {
        guard displayLink == nil else { return }

        displayLink = CADisplayLink(target: self, selector: #selector(update(_:)))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)

        // Memory monitoring timer - use target/selector to avoid concurrency issues
        memoryTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(memoryTimerFired), userInfo: nil, repeats: true)

        logger.info("Performance monitoring started")
    }

    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        memoryTimer?.invalidate()
        memoryTimer = nil
        logger.info("Performance monitoring stopped")
    }

    // MARK: - Update Loop

    @objc private func update(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        let deltaTime = currentTime - lastTimestamp

        if deltaTime > 0 && lastTimestamp > 0 {
            frameCount += 1

            // Calculate FPS every 10 frames
            if frameCount >= 10 {
                currentFPS = Double(frameCount) / deltaTime
                frameCount = 0
                lastTimestamp = currentTime

                // Update history
                fpsHistory.append(currentFPS)
                if fpsHistory.count > fpsHistorySize {
                    fpsHistory.removeFirst()
                }

                // Calculate average
                averageFPS = fpsHistory.reduce(0, +) / Double(fpsHistory.count)

                // Evaluate performance level
                evaluatePerformanceLevel()
            }
        } else {
            lastTimestamp = currentTime
        }
    }

    // MARK: - Memory Monitoring

    @objc private func memoryTimerFired() {
        updateMemoryUsage()
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            memoryUsageMB = Double(info.resident_size) / (1024 * 1024)
        }
    }

    // MARK: - Thermal Monitoring

    private func setupThermalMonitoring() {
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.thermalState = ProcessInfo.processInfo.thermalState
                self?.evaluatePerformanceLevel()
            }
            .store(in: &cancellables)

        thermalState = ProcessInfo.processInfo.thermalState
    }

    // MARK: - Performance Evaluation

    private func evaluatePerformanceLevel() {
        let previousLevel = performanceLevel

        // Determine level based on multiple factors
        if thermalState == .critical || averageFPS < criticalFPSThreshold || memoryUsageMB > criticalMemoryThresholdMB {
            performanceLevel = .critical
        } else if thermalState == .serious || averageFPS < lowFPSThreshold || memoryUsageMB > highMemoryThresholdMB {
            performanceLevel = .low
        } else if thermalState == .fair {
            performanceLevel = .medium
        } else {
            performanceLevel = .high
        }

        // Log and notify on changes
        if performanceLevel != previousLevel {
            logger.info("Performance level changed: \(previousLevel.rawValue) → \(self.performanceLevel.rawValue)")

            // Post notification for other systems to adapt
            NotificationCenter.default.post(
                name: .performanceLevelDidChange,
                object: performanceLevel
            )
        }
    }

    // MARK: - Manual Level Override

    /// Force a specific performance level (for testing)
    func forceLevel(_ level: PerformanceLevel) {
        performanceLevel = level
        NotificationCenter.default.post(
            name: .performanceLevelDidChange,
            object: level
        )
        logger.info("Performance level forced to: \(level.rawValue)")
    }

    // MARK: - Debug Info

    var debugDescription: String {
        """
        FPS: \(String(format: "%.1f", currentFPS)) (avg: \(String(format: "%.1f", averageFPS)))
        Memory: \(String(format: "%.1f", memoryUsageMB)) MB
        Thermal: \(thermalStateString)
        Level: \(performanceLevel.rawValue)
        """
    }

    private var thermalStateString: String {
        switch thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let performanceLevelDidChange = Notification.Name("performanceLevelDidChange")
}
