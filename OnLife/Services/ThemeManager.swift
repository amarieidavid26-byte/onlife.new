import SwiftUI
import Combine

// MARK: - Theme Manager

/// Singleton manager for app-wide theming
/// Persists theme selection and provides reactive updates
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // MARK: - Published Properties

    @Published private(set) var currentTheme: AppTheme = ForestTheme()
    @Published private(set) var currentThemeType: ThemeType = .forest

    // MARK: - Private Properties

    @AppStorage("selectedTheme") private var selectedThemeRaw: String = ThemeType.forest.rawValue

    // MARK: - Initialization

    private init() {
        loadTheme()
        print("🎨 [Theme] Initialized with: \(currentThemeType.rawValue)")
    }

    // MARK: - Theme Loading

    private func loadTheme() {
        if let themeType = ThemeType(rawValue: selectedThemeRaw) {
            currentThemeType = themeType
            currentTheme = themeType.theme
        } else {
            // Default to forest if stored value is invalid
            currentThemeType = .forest
            currentTheme = ForestTheme()
        }
    }

    // MARK: - Theme Setting

    /// Set the current theme with animation
    func setTheme(_ type: ThemeType) {
        guard type != currentThemeType else { return }

        selectedThemeRaw = type.rawValue
        currentThemeType = type
        currentTheme = type.theme

        // Post notification to force app-wide view refresh
        NotificationCenter.default.post(name: .themeDidChange, object: nil)

        HapticManager.shared.impact(style: .light)
        print("🎨 [Theme] Changed to: \(type.rawValue)")
    }

    // MARK: - Quick Access Computed Properties

    /// Quick access to common colors
    var primary: Color { currentTheme.primary }
    var accent: Color { currentTheme.accent }
    var backgroundPrimary: Color { currentTheme.backgroundPrimary }
    var surfaceCard: Color { currentTheme.surfaceCard }
    var textPrimary: Color { currentTheme.textPrimary }
    var textSecondary: Color { currentTheme.textSecondary }
}

// MARK: - Environment Key

/// Environment key for injecting theme into view hierarchy
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = ForestTheme()
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - View Extension for Theme

extension View {
    /// Apply the current theme to the view hierarchy
    func withTheme() -> some View {
        self.environment(\.theme, ThemeManager.shared.currentTheme)
    }
}

// MARK: - Theme Change Notification

extension Notification.Name {
    /// Posted when the app theme changes - used to force view hierarchy refresh
    static let themeDidChange = Notification.Name("themeDidChange")
}
