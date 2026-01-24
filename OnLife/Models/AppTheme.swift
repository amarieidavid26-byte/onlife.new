import SwiftUI

// MARK: - App Theme Protocol

/// Protocol that all themes must conform to
/// Defines a complete color palette for the app
protocol AppTheme {
    var name: String { get }
    var icon: String { get }

    // Primary colors
    var primary: Color { get }
    var primaryLight: Color { get }
    var secondary: Color { get }

    // Backgrounds
    var backgroundPrimary: Color { get }
    var backgroundSecondary: Color { get }
    var backgroundTertiary: Color { get }

    // Surfaces
    var surfaceCard: Color { get }
    var surfaceElevated: Color { get }

    // Text
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var textMuted: Color { get }

    // Accent
    var accent: Color { get }
    var accentGlow: Color { get }
    var accentSecondary: Color { get }

    // Semantic
    var success: Color { get }
    var warning: Color { get }
    var error: Color { get }
    var info: Color { get }

    // Plant health states
    var thriving: Color { get }
    var healthy: Color { get }
    var stressed: Color { get }
    var wilting: Color { get }
    var dormant: Color { get }
    var dead: Color { get }

    // Social
    var socialTeal: Color { get }
    var socialTealLight: Color { get }

    // Gradients
    var gradientPrimary: LinearGradient { get }
    var gradientBackground: LinearGradient { get }
}

// MARK: - Theme Type Enum

enum ThemeType: String, CaseIterable, Codable {
    case forest = "Forest"
    case ocean = "Ocean"
    case night = "Night"

    var theme: AppTheme {
        switch self {
        case .forest: return ForestTheme()
        case .ocean: return OceanTheme()
        case .night: return NightTheme()
        }
    }

    var icon: String {
        switch self {
        case .forest: return "leaf.fill"
        case .ocean: return "drop.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var description: String {
        switch self {
        case .forest: return "Nature & growth"
        case .ocean: return "Calm & focused"
        case .night: return "Dark & minimal"
        }
    }
}

// MARK: - Forest Theme (Default)

/// Evokes growth, nature, calm productivity
/// Based on Attention Restoration Theory and biophilic design
struct ForestTheme: AppTheme {
    let name = "Forest"
    let icon = "leaf.fill"

    // Primary colors - Sage/Mint Greens
    let primary = Color(hex: "2D5A27")           // Deep forest green
    let primaryLight = Color(hex: "4CAF50")      // Vibrant green
    let secondary = Color(hex: "8BC34A")         // Light green

    // Backgrounds - Deep forest tones
    let backgroundPrimary = Color(hex: "1A2E1E")   // Deep forest (deepForest)
    let backgroundSecondary = Color(hex: "1E2D22") // Surface
    let backgroundTertiary = Color(hex: "253329")  // Surface elevated

    // Surface colors
    let surfaceCard = Color(hex: "2A3B2E")         // Card background
    let surfaceElevated = Color(hex: "354539")     // Elevated card

    // Text colors
    let textPrimary = Color(hex: "F5F5F0")         // Off-white
    let textSecondary = Color(hex: "B8C4B0")       // Muted green-gray
    let textTertiary = Color(hex: "7A8A74")        // Dim green-gray
    let textMuted = Color(hex: "5A6A54")           // Disabled

    // Accent colors
    let accent = Color(hex: "C9A87C")              // Golden amber (CTA)
    let accentGlow = Color(hex: "E8D5A3")          // Sunlight gold
    let accentSecondary = Color(hex: "C17F59")     // Terracotta

    // Semantic colors
    let success = Color(hex: "7CB97C")             // Leaf green
    let warning = Color(hex: "D4A84B")             // Warm gold
    let error = Color(hex: "C75F5F")               // Muted red
    let info = Color(hex: "6BA3C7")                // Soft blue

    // Plant health states
    let thriving = Color(hex: "90D890")            // Brightest green
    let healthy = Color(hex: "7CB97C")             // Vibrant green
    let stressed = Color(hex: "C4B176")            // Yellow-green
    let wilting = Color(hex: "B88B6A")             // Warm brown
    let dormant = Color(hex: "8B7355")             // Muted brown
    let dead = Color(hex: "6B6158")                // Grey-brown

    // Social colors
    let socialTeal = Color(hex: "4ECDC4")          // Teal accent
    let socialTealLight = Color(hex: "7EDCD6")     // Light teal

    // Gradients
    var gradientPrimary: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "1B5E20"), Color(hex: "2E7D32")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var gradientBackground: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "1A2E1E"), Color(hex: "1E2D22")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Ocean Theme

/// Evokes depth, calm, infinite focus
/// Perfect for deep work and concentration
struct OceanTheme: AppTheme {
    let name = "Ocean"
    let icon = "drop.fill"

    // Primary colors - Deep blues
    let primary = Color(hex: "1565C0")           // Deep ocean blue
    let primaryLight = Color(hex: "42A5F5")      // Bright blue
    let secondary = Color(hex: "4FC3F7")         // Light cyan

    // Backgrounds - Deep ocean dark
    let backgroundPrimary = Color(hex: "0A1929")   // Deep ocean
    let backgroundSecondary = Color(hex: "0D2137") // Navy
    let backgroundTertiary = Color(hex: "132F4C")  // Lighter navy

    // Surface colors
    let surfaceCard = Color(hex: "0F2744")
    let surfaceElevated = Color(hex: "173A5E")

    // Text colors
    let textPrimary = Color(hex: "E3F2FD")       // Almost white with blue tint
    let textSecondary = Color(hex: "90CAF9")     // Light blue
    let textTertiary = Color(hex: "5C8DB8")      // Muted blue
    let textMuted = Color(hex: "3D6A8F")         // Disabled blue

    // Accent colors
    let accent = Color(hex: "00BCD4")            // Cyan
    let accentGlow = Color(hex: "4DD0E1")        // Light cyan glow
    let accentSecondary = Color(hex: "FF7043")   // Coral accent

    // Semantic colors
    let success = Color(hex: "26A69A")           // Teal
    let warning = Color(hex: "FFCA28")           // Amber
    let error = Color(hex: "EF5350")             // Red
    let info = Color(hex: "29B6F6")              // Light blue

    // Plant health states - Ocean-themed
    let thriving = Color(hex: "4DD0E1")          // Bright cyan
    let healthy = Color(hex: "26A69A")           // Teal
    let stressed = Color(hex: "FFF176")          // Yellow
    let wilting = Color(hex: "FFAB91")           // Coral
    let dormant = Color(hex: "90A4AE")           // Blue-gray
    let dead = Color(hex: "546E7A")              // Dark blue-gray

    // Social colors
    let socialTeal = Color(hex: "00BCD4")        // Cyan
    let socialTealLight = Color(hex: "4DD0E1")   // Light cyan

    // Gradients
    var gradientPrimary: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "0D47A1"), Color(hex: "1976D2")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var gradientBackground: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "0A1929"), Color(hex: "0D2137")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Night Theme

/// Evokes night owl energy, deep work, minimal distraction
/// OLED-friendly with deep blacks and purple accents
struct NightTheme: AppTheme {
    let name = "Night"
    let icon = "moon.stars.fill"

    // Primary colors - Deep purples
    let primary = Color(hex: "7C4DFF")           // Deep purple
    let primaryLight = Color(hex: "B388FF")      // Light purple
    let secondary = Color(hex: "E040FB")         // Magenta accent

    // Backgrounds - Near black
    let backgroundPrimary = Color(hex: "0A0A0F")   // Near black
    let backgroundSecondary = Color(hex: "12121A") // Very dark purple
    let backgroundTertiary = Color(hex: "1A1A2E")  // Dark purple

    // Surface colors
    let surfaceCard = Color(hex: "16162A")
    let surfaceElevated = Color(hex: "1E1E3F")

    // Text colors
    let textPrimary = Color(hex: "F3E5F5")       // Almost white with purple tint
    let textSecondary = Color(hex: "CE93D8")     // Light purple
    let textTertiary = Color(hex: "8E6B99")      // Muted purple
    let textMuted = Color(hex: "5C4A66")         // Disabled purple

    // Accent colors
    let accent = Color(hex: "E040FB")            // Vibrant magenta
    let accentGlow = Color(hex: "EA80FC")        // Light magenta glow
    let accentSecondary = Color(hex: "64FFDA")   // Cyan contrast

    // Semantic colors
    let success = Color(hex: "69F0AE")           // Neon green
    let warning = Color(hex: "FFD54F")           // Amber
    let error = Color(hex: "FF5252")             // Bright red
    let info = Color(hex: "40C4FF")              // Cyan

    // Plant health states - Night-themed
    let thriving = Color(hex: "69F0AE")          // Neon green
    let healthy = Color(hex: "B388FF")           // Light purple
    let stressed = Color(hex: "FFD54F")          // Amber
    let wilting = Color(hex: "FF8A65")           // Coral
    let dormant = Color(hex: "9575CD")           // Muted purple
    let dead = Color(hex: "5C5C7A")              // Gray-purple

    // Social colors
    let socialTeal = Color(hex: "64FFDA")        // Cyan
    let socialTealLight = Color(hex: "A7FFEB")   // Light cyan

    // Gradients
    var gradientPrimary: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "4A148C"), Color(hex: "7B1FA2")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var gradientBackground: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "0A0A0F"), Color(hex: "1A1A2E")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
