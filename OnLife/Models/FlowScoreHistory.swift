import Foundation
import SwiftUI
import Combine

// MARK: - Flow Score Data Point

/// Represents aggregated flow data for a single day
struct FlowScoreDataPoint: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let averageFlowScore: Double
    let peakFlowScore: Int
    let sessionCount: Int
    let totalMinutes: Int
    let timeInFlowMinutes: Int

    init(
        id: UUID = UUID(),
        date: Date,
        averageFlowScore: Double,
        peakFlowScore: Int = 0,
        sessionCount: Int,
        totalMinutes: Int,
        timeInFlowMinutes: Int = 0
    ) {
        self.id = id
        self.date = date
        self.averageFlowScore = averageFlowScore
        self.peakFlowScore = peakFlowScore
        self.sessionCount = sessionCount
        self.totalMinutes = totalMinutes
        self.timeInFlowMinutes = timeInFlowMinutes
    }

    /// Color coding based on score
    var scoreCategory: FlowScoreCategory {
        switch averageFlowScore {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        default: return .needsWork
        }
    }

    /// Formatted date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Score Category

enum FlowScoreCategory: String, Codable {
    case excellent  // 80-100: Deep flow
    case good       // 60-80: Productive focus
    case fair       // 40-60: Distracted
    case needsWork  // <40: Very distracted

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return OnLifeColors.sage
        case .fair: return OnLifeColors.amber
        case .needsWork: return OnLifeColors.terracotta
        }
    }

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .needsWork: return "Needs Work"
        }
    }

    var emoji: String {
        switch self {
        case .excellent: return "🔥"
        case .good: return "✨"
        case .fair: return "💪"
        case .needsWork: return "🌱"
        }
    }
}

// MARK: - Time Range

enum FlowHistoryTimeRange: String, CaseIterable {
    case week = "7 Days"
    case month = "30 Days"
    case quarter = "90 Days"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }

    var strideInterval: Int {
        switch self {
        case .week: return 1
        case .month: return 5
        case .quarter: return 15
        }
    }
}

// MARK: - Flow Score History Manager

class FlowScoreHistoryManager: ObservableObject {
    @Published var dataPoints: [FlowScoreDataPoint] = []
    @Published var selectedTimeRange: FlowHistoryTimeRange = .week
    @Published var isLoading = false

    // MARK: - Fetch History

    func fetchHistory(sessions: [FocusSession]) {
        isLoading = true

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) else {
            isLoading = false
            return
        }

        // Filter sessions within date range
        let relevantSessions = sessions.filter { session in
            session.startTime >= startDate && session.startTime <= endDate
        }

        // Group sessions by day
        var dailyData: [Date: DailyFlowAggregate] = [:]

        for session in relevantSessions {
            let dayStart = calendar.startOfDay(for: session.startTime)

            if dailyData[dayStart] == nil {
                dailyData[dayStart] = DailyFlowAggregate()
            }

            dailyData[dayStart]!.sessionCount += 1
            dailyData[dayStart]!.totalMinutes += Int(session.actualDuration / 60)

            // Add flow score data if available from Watch
            if let biometrics = session.biometrics, biometrics.averageFlowScore > 0 {
                dailyData[dayStart]!.flowScores.append(Double(biometrics.averageFlowScore))
                dailyData[dayStart]!.peakFlowScore = max(
                    dailyData[dayStart]!.peakFlowScore,
                    biometrics.peakFlowScore
                )
                dailyData[dayStart]!.timeInFlowMinutes += Int(biometrics.timeInFlowState / 60)
            } else {
                // Estimate flow score from focus quality if no biometrics
                let estimatedScore = session.focusQuality * 100
                dailyData[dayStart]!.flowScores.append(estimatedScore)
            }
        }

        // Convert to data points
        var points = dailyData.map { date, data -> FlowScoreDataPoint in
            let avgScore = data.flowScores.isEmpty ? 0 : data.flowScores.reduce(0, +) / Double(data.flowScores.count)

            return FlowScoreDataPoint(
                date: date,
                averageFlowScore: avgScore,
                peakFlowScore: data.peakFlowScore,
                sessionCount: data.sessionCount,
                totalMinutes: data.totalMinutes,
                timeInFlowMinutes: data.timeInFlowMinutes
            )
        }

        // Fill in missing days
        points = fillMissingDays(points: points, from: startDate, to: endDate)

        // Sort by date
        dataPoints = points.sorted { $0.date < $1.date }

        isLoading = false

        print("📊 [FlowHistory] Loaded \(dataPoints.count) days, \(relevantSessions.count) sessions")
    }

    private func fillMissingDays(points: [FlowScoreDataPoint], from startDate: Date, to endDate: Date) -> [FlowScoreDataPoint] {
        let calendar = Calendar.current
        var allDays: [Date] = []
        var currentDate = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while currentDate <= endDay {
            allDays.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        let existingDates = Set(points.map { calendar.startOfDay(for: $0.date) })

        var result = points
        for day in allDays where !existingDates.contains(day) {
            result.append(FlowScoreDataPoint(
                date: day,
                averageFlowScore: 0,
                sessionCount: 0,
                totalMinutes: 0
            ))
        }

        return result
    }

    // MARK: - Computed Stats

    var averageScore: Double {
        let validPoints = dataPoints.filter { $0.sessionCount > 0 }
        guard !validPoints.isEmpty else { return 0 }
        return validPoints.reduce(0) { $0 + $1.averageFlowScore } / Double(validPoints.count)
    }

    var totalSessions: Int {
        dataPoints.reduce(0) { $0 + $1.sessionCount }
    }

    var totalMinutes: Int {
        dataPoints.reduce(0) { $0 + $1.totalMinutes }
    }

    var totalTimeInFlow: Int {
        dataPoints.reduce(0) { $0 + $1.timeInFlowMinutes }
    }

    var peakScore: Int {
        dataPoints.map { $0.peakFlowScore }.max() ?? 0
    }

    var daysWithSessions: Int {
        dataPoints.filter { $0.sessionCount > 0 }.count
    }

    var scoreCategory: FlowScoreCategory {
        switch averageScore {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        default: return .needsWork
        }
    }

    var trend: Trend {
        guard dataPoints.count >= 3 else { return .neutral }

        let validPoints = dataPoints.filter { $0.sessionCount > 0 }
        guard validPoints.count >= 2 else { return .neutral }

        let midpoint = validPoints.count / 2
        let firstHalf = Array(validPoints.prefix(midpoint))
        let secondHalf = Array(validPoints.suffix(midpoint))

        let firstAvg = firstHalf.isEmpty ? 0 : firstHalf.reduce(0) { $0 + $1.averageFlowScore } / Double(firstHalf.count)
        let secondAvg = secondHalf.isEmpty ? 0 : secondHalf.reduce(0) { $0 + $1.averageFlowScore } / Double(secondHalf.count)

        let diff = secondAvg - firstAvg
        if diff > 5 { return .improving }
        if diff < -5 { return .declining }
        return .neutral
    }

    enum Trend {
        case improving, neutral, declining

        var icon: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .neutral: return "arrow.right"
            case .declining: return "arrow.down.right"
            }
        }

        var color: Color {
            switch self {
            case .improving: return .green
            case .neutral: return OnLifeColors.textSecondary
            case .declining: return OnLifeColors.terracotta
            }
        }

        var label: String {
            switch self {
            case .improving: return "Improving"
            case .neutral: return "Steady"
            case .declining: return "Declining"
            }
        }
    }
}

// MARK: - Helper Types

private struct DailyFlowAggregate {
    var flowScores: [Double] = []
    var peakFlowScore: Int = 0
    var sessionCount: Int = 0
    var totalMinutes: Int = 0
    var timeInFlowMinutes: Int = 0
}
