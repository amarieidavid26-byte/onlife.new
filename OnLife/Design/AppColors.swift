import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

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
