import Foundation
import HealthKit
import Combine

// HealthKit type identifiers
private let HKDataTypeIdentifierHeartRateVariabilitySeries = "HKDataTypeIdentifierHeartRateVariabilitySeries"

/// Singleton managing all HealthKit interactions for both iOS and watchOS
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties
    @Published var isAuthorized = false
    @Published var authorizationError: Error?
    @Published var latestHeartRate: Double?
    @Published var latestRMSSD: Double?

    // MARK: - HealthKit Types

    /// All types we need to READ
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKCategoryType(.sleepAnalysis),
            HKSeriesType.heartbeat(),
        ]
        
        // Add HRV series type for watchOS 11+ / iOS 18+
        // This is required when using heartbeat series
        if #available(iOS 18.0, watchOS 11.0, *) {
            if let hrvSeriesType = HKObjectType.seriesType(forIdentifier: HKDataTypeIdentifierHeartRateVariabilitySeries) {
                types.insert(hrvSeriesType)
            }
        }
        
        return types
    }

    /// Types we need to WRITE
    private var writeTypes: Set<HKSampleType> {
        return [
            HKQuantityType(.heartRate),
            HKQuantityType.workoutType(),
        ]
    }

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)

        await MainActor.run {
            self.isAuthorized = true
        }

        print("✅ [HealthKit] Authorization granted")
    }

    private func checkAuthorizationStatus() {
        // Check if we already have authorization
        let heartRateType = HKQuantityType(.heartRate)
        let status = healthStore.authorizationStatus(for: heartRateType)
        isAuthorized = (status == .sharingAuthorized)
    }

    // MARK: - Baseline Queries (14-day historical data)

    /// Query resting heart rate for the last N days
    func queryRestingHeartRate(days: Int = 14) async throws -> [Double] {
        let restingHRType = HKQuantityType(.restingHeartRate)
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: restingHRType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        return samples.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
    }

    /// Query HRV (SDNN) samples for baseline calculation
    func queryHRVSamples(days: Int = 14) async throws -> [(date: Date, sdnn: Double)] {
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))) }
    }

    /// Query sleep analysis for previous night
    func querySleepAnalysis(for date: Date = Date()) async throws -> SleepAnalysisResult {
        let sleepType = HKCategoryType(.sleepAnalysis)

        // Get sleep samples from previous night (6 PM yesterday to noon today)
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let previousEvening = calendar.date(byAdding: .hour, value: -18, to: noon)!

        let predicate = HKQuery.predicateForSamples(withStart: previousEvening, end: noon, options: .strictStartDate)

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        return analyzeSleepSamples(samples)
    }

    private func analyzeSleepSamples(_ samples: [HKCategorySample]) -> SleepAnalysisResult {
        var totalSleepSeconds: TimeInterval = 0
        var deepSleepSeconds: TimeInterval = 0
        var remSleepSeconds: TimeInterval = 0

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)

            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                totalSleepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                totalSleepSeconds += duration
                deepSleepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                totalSleepSeconds += duration
                remSleepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                totalSleepSeconds += duration
            default:
                break
            }
        }

        let totalHours = totalSleepSeconds / 3600
        let deepPercent = totalSleepSeconds > 0 ? (deepSleepSeconds / totalSleepSeconds) * 100 : 0
        let remPercent = totalSleepSeconds > 0 ? (remSleepSeconds / totalSleepSeconds) * 100 : 0

        // Calculate sleep score (0-100)
        // Optimal: 7-9 hours, 15-20% deep, 20-25% REM
        var score: Double = 0

        // Duration score (0-40 points)
        if totalHours >= 7 && totalHours <= 9 {
            score += 40
        } else if totalHours >= 6 && totalHours < 7 {
            score += 30
        } else if totalHours > 9 && totalHours <= 10 {
            score += 35
        } else {
            score += max(0, 40 - abs(totalHours - 8) * 8)
        }

        // Deep sleep score (0-30 points)
        if deepPercent >= 15 && deepPercent <= 25 {
            score += 30
        } else {
            score += max(0, 30 - abs(deepPercent - 20) * 2)
        }

        // REM score (0-30 points)
        if remPercent >= 20 && remPercent <= 30 {
            score += 30
        } else {
            score += max(0, 30 - abs(remPercent - 25) * 2)
        }

        return SleepAnalysisResult(
            totalHours: totalHours,
            deepSleepPercent: deepPercent,
            remSleepPercent: remPercent,
            score: min(100, max(0, score))
        )
    }

    // MARK: - Calculate Personal Baseline

    func calculatePersonalBaseline() async throws -> PersonalBaseline {
        print("📊 [HealthKit] Calculating personal baseline...")

        // Get resting HR samples
        let restingHRs = try await queryRestingHeartRate(days: 14)
        let avgRestingHR = restingHRs.isEmpty ? 70.0 : restingHRs.reduce(0, +) / Double(restingHRs.count)

        // Get HRV samples
        let hrvSamples = try await queryHRVSamples(days: 14)
        // SDNN to RMSSD approximation: RMSSD ≈ SDNN * 1.4 for resting measurements
        // This is a simplification; real RMSSD should come from RR intervals
        let avgSDNN = hrvSamples.isEmpty ? 50.0 : hrvSamples.map { $0.sdnn }.reduce(0, +) / Double(hrvSamples.count)
        let estimatedRMSSD = avgSDNN * 1.4

        // Get sleep score
        let sleepResult = try await querySleepAnalysis()

        let baseline = PersonalBaseline(
            restingHR: avgRestingHR,
            restingHRStdDev: calculateStdDev(restingHRs),
            baselineRMSSD: estimatedRMSSD,
            baselineRMSSDStdDev: calculateStdDev(hrvSamples.map { $0.sdnn * 1.4 }),
            sleepScore: sleepResult.score,
            circadianHRVModifiers: calculateCircadianModifiers(hrvSamples),
            dataPointCount: restingHRs.count + hrvSamples.count,
            lastUpdated: Date(),
            isCalibrated: (restingHRs.count + hrvSamples.count) >= 14
        )

        print("📊 [HealthKit] Baseline calculated: HR=\(avgRestingHR)bpm, RMSSD≈\(estimatedRMSSD)ms, Sleep=\(sleepResult.score)")

        return baseline
    }

    private func calculateStdDev(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSquaredDiffs = values.reduce(0) { $0 + pow($1 - mean, 2) }
        return sqrt(sumSquaredDiffs / Double(values.count - 1))
    }

    private func calculateCircadianModifiers(_ samples: [(date: Date, sdnn: Double)]) -> [Int: Double] {
        // Group HRV samples by hour and calculate average multiplier vs overall mean
        var hourlyValues: [Int: [Double]] = [:]
        let overallMean = samples.map { $0.sdnn }.reduce(0, +) / max(1, Double(samples.count))

        for sample in samples {
            let hour = Calendar.current.component(.hour, from: sample.date)
            hourlyValues[hour, default: []].append(sample.sdnn)
        }

        var modifiers: [Int: Double] = [:]
        for hour in 0..<24 {
            if let values = hourlyValues[hour], !values.isEmpty {
                let hourMean = values.reduce(0, +) / Double(values.count)
                modifiers[hour] = hourMean / overallMean
            } else {
                // Default modifiers based on research (morning HRV ~20% higher)
                if hour >= 6 && hour <= 10 {
                    modifiers[hour] = 1.2
                } else if hour >= 22 || hour <= 5 {
                    modifiers[hour] = 1.1
                } else {
                    modifiers[hour] = 1.0
                }
            }
        }

        return modifiers
    }

    // MARK: - Errors

    enum HealthKitError: Error, LocalizedError {
        case notAvailable
        case notAuthorized
        case queryFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device"
            case .notAuthorized:
                return "HealthKit authorization was denied"
            case .queryFailed(let reason):
                return "HealthKit query failed: \(reason)"
            }
        }
    }
}

// MARK: - Supporting Types

struct SleepAnalysisResult: Codable {
    let totalHours: Double
    let deepSleepPercent: Double
    let remSleepPercent: Double
    let score: Double  // 0-100
}
