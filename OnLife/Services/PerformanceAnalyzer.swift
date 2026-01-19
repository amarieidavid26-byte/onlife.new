import Foundation
import SwiftUI

/// AI-powered peak performance time identification
/// Research basis: Roenneberg et al. (2007) - Circadian performance varies 20-30% based on time alignment
class PerformanceAnalyzer {
    static let shared = PerformanceAnalyzer()

    private init() {}

    // MARK: - Performance Window

    struct PerformanceWindow: Identifiable, Codable, Equatable {
        let id: UUID
        let startHour: Int
        let endHour: Int
        let averageFlowScore: Double
        let sessionCount: Int
        let confidence: Double // 0-1
        let recommendation: String

        init(
            id: UUID = UUID(),
            startHour: Int,
            endHour: Int,
            averageFlowScore: Double,
            sessionCount: Int,
            confidence: Double,
            recommendation: String
        ) {
            self.id = id
            self.startHour = startHour
            self.endHour = endHour
            self.averageFlowScore = averageFlowScore
            self.sessionCount = sessionCount
            self.confidence = confidence
            self.recommendation = recommendation
        }

        var timeRangeDescription: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "ha"

            let startDate = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: Date()) ?? Date()
            let endDate = Calendar.current.date(bySettingHour: endHour, minute: 0, second: 0, of: Date()) ?? Date()

            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }

        var confidenceLevel: ConfidenceLevel {
            switch confidence {
            case 0.8...1.0: return .high
            case 0.5..<0.8: return .medium
            default: return .low
            }
        }

        var windowDuration: Int {
            endHour - startHour
        }

        enum ConfidenceLevel: String, Codable {
            case high, medium, low

            var label: String {
                switch self {
                case .high: return "High confidence"
                case .medium: return "Medium confidence"
                case .low: return "Low confidence"
                }
            }

            var color: Color {
                switch self {
                case .high: return .green
                case .medium: return OnLifeColors.amber
                case .low: return OnLifeColors.terracotta
                }
            }

            var icon: String {
                switch self {
                case .high: return "checkmark.seal.fill"
                case .medium: return "checkmark.seal"
                case .low: return "exclamationmark.triangle"
                }
            }
        }
    }

    // MARK: - Identify Peak Windows

    /// Analyzes session history to identify 2-3 hour contiguous blocks with high flow scores
    /// - Parameters:
    ///   - sessions: Array of focus sessions to analyze
    ///   - minimumSessions: Minimum sessions required for analysis (default 14)
    /// - Returns: Top 3 performance windows ranked by average flow score
    func identifyPeakWindows(sessions: [FocusSession], minimumSessions: Int = 14) -> [PerformanceWindow] {
        // Filter to completed sessions only
        let completedSessions = sessions.filter { $0.wasCompleted }

        guard completedSessions.count >= minimumSessions else {
            print("📊 [PerformanceAnalyzer] Not enough sessions: \(completedSessions.count)/\(minimumSessions)")
            return []
        }

        // Group sessions by hour of day
        var hourlyData: [Int: HourlyPerformance] = [:]

        for session in completedSessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)

            if hourlyData[hour] == nil {
                hourlyData[hour] = HourlyPerformance()
            }

            // Use biometric flow score if available, otherwise estimate from focus quality
            let flowScore: Double
            if let biometrics = session.biometrics, biometrics.averageFlowScore > 0 {
                flowScore = Double(biometrics.averageFlowScore)
            } else {
                flowScore = session.focusQuality * 100
            }

            hourlyData[hour]!.scores.append(flowScore)
            hourlyData[hour]!.count += 1
        }

        // Find contiguous 2-3 hour windows with high scores
        var windows: [PerformanceWindow] = []

        // Try 3-hour windows first, then 2-hour
        for windowSize in stride(from: 3, through: 2, by: -1) {
            for startHour in 5...21 { // Only consider 5 AM - 9 PM starts
                let endHour = startHour + windowSize

                guard endHour <= 23 else { continue }

                // Calculate window stats
                var windowScores: [Double] = []
                var windowSessions = 0
                var hasAllHours = true

                for hour in startHour..<endHour {
                    if let data = hourlyData[hour], !data.scores.isEmpty {
                        windowScores.append(contentsOf: data.scores)
                        windowSessions += data.count
                    } else {
                        hasAllHours = false
                        break
                    }
                }

                // Skip if missing hours in window or too few sessions
                guard hasAllHours, windowSessions >= 3 else { continue }

                let avgScore = windowScores.reduce(0, +) / Double(windowScores.count)

                // Calculate confidence based on sample size and consistency
                let confidence = calculateConfidence(
                    sessionCount: windowSessions,
                    scores: windowScores,
                    totalSessions: completedSessions.count
                )

                // Only keep high-performing windows (score >= 60)
                guard avgScore >= 60 else { continue }

                let recommendation = generateRecommendation(
                    startHour: startHour,
                    endHour: endHour,
                    score: avgScore,
                    confidence: confidence
                )

                windows.append(PerformanceWindow(
                    startHour: startHour,
                    endHour: endHour,
                    averageFlowScore: avgScore,
                    sessionCount: windowSessions,
                    confidence: confidence,
                    recommendation: recommendation
                ))
            }
        }

        // Remove overlapping windows, keeping highest scoring
        let filteredWindows = removeOverlappingWindows(windows)

        // Sort by score and return top 3
        let result = Array(filteredWindows.sorted { $0.averageFlowScore > $1.averageFlowScore }.prefix(3))
        print("📊 [PerformanceAnalyzer] Found \(result.count) peak windows from \(completedSessions.count) sessions")

        return result
    }

    // MARK: - Confidence Calculation

    private func calculateConfidence(sessionCount: Int, scores: [Double], totalSessions: Int) -> Double {
        guard !scores.isEmpty else { return 0 }

        // Factor 1: Sample size (more sessions = higher confidence)
        // Cap at 20 sessions for this window
        let sampleSizeFactor = min(Double(sessionCount) / 20.0, 1.0)

        // Factor 2: Consistency (low variance = higher confidence)
        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.map { pow($0 - mean, 2) }.reduce(0, +) / Double(scores.count)
        let stdDev = sqrt(variance)
        // Normalize by reasonable std dev (30 points)
        let consistencyFactor = max(0, 1.0 - (stdDev / 30.0))

        // Factor 3: Proportion of total sessions (more representation = higher confidence)
        let proportionFactor = min(Double(sessionCount) / Double(totalSessions), 0.5) * 2.0

        // Weighted average: 40% sample size, 40% consistency, 20% proportion
        return (sampleSizeFactor * 0.4) + (consistencyFactor * 0.4) + (proportionFactor * 0.2)
    }

    // MARK: - Recommendation Generation

    private func generateRecommendation(startHour: Int, endHour: Int, score: Double, confidence: Double) -> String {
        if confidence >= 0.8 {
            return "Your peak performance window. Schedule deep work here."
        } else if confidence >= 0.5 {
            return "Strong focus window. Good for important tasks."
        } else {
            return "Promising time slot. Gather more data to confirm."
        }
    }

    // MARK: - Helper Methods

    private func removeOverlappingWindows(_ windows: [PerformanceWindow]) -> [PerformanceWindow] {
        // Sort by score descending
        let sorted = windows.sorted { $0.averageFlowScore > $1.averageFlowScore }

        var result: [PerformanceWindow] = []

        for window in sorted {
            // Check if this window overlaps with any already selected
            let overlaps = result.contains { existing in
                let existingRange = existing.startHour..<existing.endHour
                let windowRange = window.startHour..<window.endHour
                return existingRange.overlaps(windowRange)
            }

            if !overlaps {
                result.append(window)
            }
        }

        return result
    }

    // MARK: - Chronotype Alignment

    /// Compare identified peak windows with chronotype predictions
    func compareToChronotype(
        peakWindows: [PerformanceWindow],
        chronotype: Chronotype?
    ) -> ChronotypeAlignment? {
        guard let chronotype = chronotype,
              let topWindow = peakWindows.first else {
            return nil
        }

        // Get chronotype's predicted optimal window
        let optimalWindow = chronotype.peakWindow

        // Calculate overlap/alignment
        let windowMidpoint = (topWindow.startHour + topWindow.endHour) / 2
        let chronotypeMidpoint = (optimalWindow.start + optimalWindow.end) / 2

        let hourDifference = abs(windowMidpoint - chronotypeMidpoint)

        let alignment: ChronotypeAlignment.AlignmentLevel
        if hourDifference <= 1 {
            alignment = .perfectMatch
        } else if hourDifference <= 3 {
            alignment = .closeMatch
        } else {
            alignment = .mismatch
        }

        return ChronotypeAlignment(
            level: alignment,
            chronotypeWindow: optimalWindow,
            actualWindow: (topWindow.startHour, topWindow.endHour),
            insight: generateAlignmentInsight(alignment, chronotype: chronotype)
        )
    }

    private func generateAlignmentInsight(_ alignment: ChronotypeAlignment.AlignmentLevel, chronotype: Chronotype) -> String {
        switch alignment {
        case .perfectMatch:
            return "Your peak performance aligns perfectly with your \(chronotype.shortName) chronotype!"
        case .closeMatch:
            return "Your performance is close to your predicted \(chronotype.shortName) peak window."
        case .mismatch:
            return "Interesting! Your peak differs from typical \(chronotype.shortName) patterns. Trust your data."
        }
    }

    // MARK: - Helper Types

    private struct HourlyPerformance {
        var scores: [Double] = []
        var count: Int = 0
    }
}

// MARK: - Chronotype Alignment

struct ChronotypeAlignment {
    let level: AlignmentLevel
    let chronotypeWindow: (start: Int, end: Int)
    let actualWindow: (start: Int, end: Int)
    let insight: String

    enum AlignmentLevel {
        case perfectMatch
        case closeMatch
        case mismatch

        var color: Color {
            switch self {
            case .perfectMatch: return .green
            case .closeMatch: return OnLifeColors.amber
            case .mismatch: return OnLifeColors.terracotta
            }
        }

        var icon: String {
            switch self {
            case .perfectMatch: return "checkmark.circle.fill"
            case .closeMatch: return "circle.dashed"
            case .mismatch: return "arrow.triangle.branch"
            }
        }

        var label: String {
            switch self {
            case .perfectMatch: return "Perfect Alignment"
            case .closeMatch: return "Close Match"
            case .mismatch: return "Unique Pattern"
            }
        }
    }

    var chronotypeWindowFormatted: String {
        formatTimeRange(start: chronotypeWindow.start, end: chronotypeWindow.end)
    }

    var actualWindowFormatted: String {
        formatTimeRange(start: actualWindow.start, end: actualWindow.end)
    }

    private func formatTimeRange(start: Int, end: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"

        let startDate = Calendar.current.date(bySettingHour: start, minute: 0, second: 0, of: Date()) ?? Date()
        let endDate = Calendar.current.date(bySettingHour: end, minute: 0, second: 0, of: Date()) ?? Date()

        return "\(formatter.string(from: startDate))-\(formatter.string(from: endDate))"
    }
}
