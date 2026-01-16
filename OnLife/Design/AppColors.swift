import SwiftUI

// Note: Color.init(hex:) extension is defined in DesignSystem.swift

// MARK: - Legacy AppColors (for backward compatibility)
// New code should use OnLifeColors from DesignSystem.swift

struct AppColors {
    // Background colors (earth tones)
    static let richSoil = Color(hex: "#3D2F1F")      // Deep brown background
    static let lightSoil = Color(hex: "#5C4A3A")     // Medium brown for cards
    static let darkSoil = Color(hex: "#2A1F15")      // Darker brown for tab bar

    // Plant health colors
    static let thriving = Color(hex: "#6BA176")      // Darker green
    static let healthy = Color(hex: "#8AB892")       // Medium green
    static let stressed = Color(hex: "#C9B892")      // Yellow-brown
    static let wilting = Color(hex: "#8B6F47")       // Brown
    static let dead = Color(hex: "#4A3F35")          // Dark brown/gray

    // Text colors
    static let textPrimary = Color(hex: "#F5F1ED")   // Off-white
    static let textSecondary = Color(hex: "#D4CFC8") // Light gray
    static let textTertiary = Color(hex: "#9B9388")  // Medium gray

    // Accent colors
    static let accent = Color(hex: "#8AB892")        // Same as healthy green
    static let error = Color(hex: "#C65D4F")         // Muted red

    // Semantic colors
    static let success = healthy
    static let warning = stressed
    static let danger = error
}
