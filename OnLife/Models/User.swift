import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    var displayName: String
    var email: String?
    var createdAt: Date
    var level: Int
    var experiencePoints: Int
    var preferredEnvironment: FocusEnvironment?
    var dailyFocusGoal: Int // in minutes
    var notificationsEnabled: Bool
    var soundsEnabled: Bool

    init(
        id: UUID = UUID(),
        displayName: String,
        email: String? = nil,
        createdAt: Date = Date(),
        level: Int = 1,
        experiencePoints: Int = 0,
        preferredEnvironment: FocusEnvironment? = nil,
        dailyFocusGoal: Int = 120, // 2 hours default
        notificationsEnabled: Bool = true,
        soundsEnabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.createdAt = createdAt
        self.level = level
        self.experiencePoints = experiencePoints
        self.preferredEnvironment = preferredEnvironment
        self.dailyFocusGoal = dailyFocusGoal
        self.notificationsEnabled = notificationsEnabled
        self.soundsEnabled = soundsEnabled
    }
}
