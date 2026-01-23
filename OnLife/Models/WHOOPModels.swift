//
//  WHOOPModels.swift
//  OnLife
//
//  WHOOP API data models for biometric data
//

import Foundation

// MARK: - Recovery Models

/// Response from WHOOP Recovery API endpoint
struct WHOOPRecoveryResponse: Codable {
    let records: [WHOOPRecovery]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case records
        case nextToken = "next_token"
    }
}

/// Individual recovery record from WHOOP (v2 API)
struct WHOOPRecovery: Codable, Identifiable {
    var id: Int { cycleId }

    let cycleId: Int
    let sleepId: String  // UUID string in v2 (was Int in v1)
    let userId: Int
    let createdAt: String
    let updatedAt: String
    let scoreState: String
    let score: WHOOPRecoveryScore?

    enum CodingKeys: String, CodingKey {
        case cycleId = "cycle_id"
        case sleepId = "sleep_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case scoreState = "score_state"
        case score
    }
}

/// Recovery score details from WHOOP
struct WHOOPRecoveryScore: Codable {
    let userCalibrating: Bool
    let recoveryScore: Double
    let restingHeartRate: Double
    let hrvRmssdMilli: Double
    let spo2Percentage: Double?
    let skinTempCelsius: Double?

    enum CodingKeys: String, CodingKey {
        case userCalibrating = "user_calibrating"
        case recoveryScore = "recovery_score"
        case restingHeartRate = "resting_heart_rate"
        case hrvRmssdMilli = "hrv_rmssd_milli"
        case spo2Percentage = "spo2_percentage"
        case skinTempCelsius = "skin_temp_celsius"
    }
}

// MARK: - Cycle Models

/// Response from WHOOP Cycle API endpoint
struct WHOOPCycleResponse: Codable {
    let records: [WHOOPCycle]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case records
        case nextToken = "next_token"
    }
}

/// Individual cycle (day) record from WHOOP
struct WHOOPCycle: Codable, Identifiable {
    var id: Int { cycleId }

    let cycleId: Int
    let userId: Int
    let createdAt: String
    let updatedAt: String
    let start: String
    let end: String?
    let timezoneOffset: String
    let scoreState: String
    let score: WHOOPCycleScore?

    enum CodingKeys: String, CodingKey {
        case cycleId = "id"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case start
        case end
        case timezoneOffset = "timezone_offset"
        case scoreState = "score_state"
        case score
    }
}

/// Cycle score details (strain) from WHOOP
struct WHOOPCycleScore: Codable {
    let strain: Double
    let kilojoule: Double
    let averageHeartRate: Int
    let maxHeartRate: Int

    enum CodingKeys: String, CodingKey {
        case strain
        case kilojoule
        case averageHeartRate = "average_heart_rate"
        case maxHeartRate = "max_heart_rate"
    }
}

// MARK: - Sleep Models

/// Response from WHOOP Sleep API endpoint
struct WHOOPSleepResponse: Codable {
    let records: [WHOOPSleep]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case records
        case nextToken = "next_token"
    }
}

/// Individual sleep record from WHOOP (v2 API)
struct WHOOPSleep: Codable, Identifiable {
    let id: String  // UUID string in v2 (was Int in v1)

    let userId: Int
    let createdAt: String
    let updatedAt: String
    let start: String
    let end: String
    let timezoneOffset: String
    let nap: Bool
    let scoreState: String
    let score: WHOOPSleepScore?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case start
        case end
        case timezoneOffset = "timezone_offset"
        case nap
        case scoreState = "score_state"
        case score
    }
}

/// Sleep score details from WHOOP
struct WHOOPSleepScore: Codable {
    let stageSummary: WHOOPSleepStageSummary
    let sleepNeeded: WHOOPSleepNeeded
    let respiratoryRate: Double
    let sleepPerformancePercentage: Double?
    let sleepConsistencyPercentage: Double?
    let sleepEfficiencyPercentage: Double?

    enum CodingKeys: String, CodingKey {
        case stageSummary = "stage_summary"
        case sleepNeeded = "sleep_needed"
        case respiratoryRate = "respiratory_rate"
        case sleepPerformancePercentage = "sleep_performance_percentage"
        case sleepConsistencyPercentage = "sleep_consistency_percentage"
        case sleepEfficiencyPercentage = "sleep_efficiency_percentage"
    }
}

/// Sleep stage breakdown from WHOOP
struct WHOOPSleepStageSummary: Codable {
    let totalInBedTimeMilli: Int
    let totalAwakeTimeMilli: Int
    let totalNoDataTimeMilli: Int
    let totalLightSleepTimeMilli: Int
    let totalSlowWaveSleepTimeMilli: Int
    let totalRemSleepTimeMilli: Int
    let sleepCycleCount: Int
    let disturbanceCount: Int

    enum CodingKeys: String, CodingKey {
        case totalInBedTimeMilli = "total_in_bed_time_milli"
        case totalAwakeTimeMilli = "total_awake_time_milli"
        case totalNoDataTimeMilli = "total_no_data_time_milli"
        case totalLightSleepTimeMilli = "total_light_sleep_time_milli"
        case totalSlowWaveSleepTimeMilli = "total_slow_wave_sleep_time_milli"
        case totalRemSleepTimeMilli = "total_rem_sleep_time_milli"
        case sleepCycleCount = "sleep_cycle_count"
        case disturbanceCount = "disturbance_count"
    }
}

/// Sleep need calculation from WHOOP
struct WHOOPSleepNeeded: Codable {
    let baselineMilli: Int
    let needFromSleepDebtMilli: Int
    let needFromRecentStrainMilli: Int
    let needFromRecentNapMilli: Int

    enum CodingKeys: String, CodingKey {
        case baselineMilli = "baseline_milli"
        case needFromSleepDebtMilli = "need_from_sleep_debt_milli"
        case needFromRecentStrainMilli = "need_from_recent_strain_milli"
        case needFromRecentNapMilli = "need_from_recent_nap_milli"
    }
}

// MARK: - Workout Models

/// Response from WHOOP Workout API endpoint
struct WHOOPWorkoutResponse: Codable {
    let records: [WHOOPWorkout]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case records
        case nextToken = "next_token"
    }
}

/// Individual workout record from WHOOP (v2 API)
struct WHOOPWorkout: Codable, Identifiable {
    let id: String  // UUID string in v2 (was Int in v1)

    let userId: Int
    let createdAt: String
    let updatedAt: String
    let start: String
    let end: String
    let timezoneOffset: String
    let sportId: Int
    let sportName: String?  // New in v2
    let scoreState: String
    let score: WHOOPWorkoutScore?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case start
        case end
        case timezoneOffset = "timezone_offset"
        case sportId = "sport_id"
        case sportName = "sport_name"
        case scoreState = "score_state"
        case score
    }
}

/// Workout score details from WHOOP (v2 API)
struct WHOOPWorkoutScore: Codable {
    let strain: Double
    let averageHeartRate: Int
    let maxHeartRate: Int
    let kilojoule: Double
    let percentRecorded: Double
    let distanceMeter: Double?
    let altitudeGainMeter: Double?
    let altitudeChangeMeter: Double?
    let zoneDurations: WHOOPZoneDurations?  // Nested object in v2

    enum CodingKeys: String, CodingKey {
        case strain
        case averageHeartRate = "average_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case kilojoule
        case percentRecorded = "percent_recorded"
        case distanceMeter = "distance_meter"
        case altitudeGainMeter = "altitude_gain_meter"
        case altitudeChangeMeter = "altitude_change_meter"
        case zoneDurations = "zone_durations"
    }
}

/// HR zone durations from WHOOP workout (v2 API)
struct WHOOPZoneDurations: Codable {
    let zoneZeroMilli: Int?
    let zoneOneMilli: Int?
    let zoneTwoMilli: Int?
    let zoneThreeMilli: Int?
    let zoneFourMilli: Int?
    let zoneFiveMilli: Int?

    enum CodingKeys: String, CodingKey {
        case zoneZeroMilli = "zone_zero_milli"
        case zoneOneMilli = "zone_one_milli"
        case zoneTwoMilli = "zone_two_milli"
        case zoneThreeMilli = "zone_three_milli"
        case zoneFourMilli = "zone_four_milli"
        case zoneFiveMilli = "zone_five_milli"
    }
}

// MARK: - User Profile

/// WHOOP user profile data
struct WHOOPUserProfile: Codable {
    let userId: Int
    let email: String
    let firstName: String
    let lastName: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

// MARK: - Body Measurement

/// WHOOP body measurement data
struct WHOOPBodyMeasurement: Codable {
    let heightMeter: Double
    let weightKilogram: Double
    let maxHeartRate: Int

    enum CodingKeys: String, CodingKey {
        case heightMeter = "height_meter"
        case weightKilogram = "weight_kilogram"
        case maxHeartRate = "max_heart_rate"
    }
}
