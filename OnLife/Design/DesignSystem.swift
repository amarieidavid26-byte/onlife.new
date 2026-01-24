import SwiftUI
import UIKit

// MARK: - Design System for OnLife
// Based on Attention Restoration Theory research and biophilic design principles
// Color distribution: 60% sage/greens, 30% earth accents, 10% warm highlights

// MARK: - Color Palette

/// Dynamic color palette that reads from the current theme
/// All colors update automatically when the theme changes
struct OnLifeColors {

    // MARK: - Theme Access

    /// Access to current theme (internal use)
    private static var theme: AppTheme { ThemeManager.shared.currentTheme }

    // MARK: Primary Colors

    /// Primary color (theme-aware)
    static var sage: Color { theme.success }

    /// Soft mint (maps to secondary)
    static var mint: Color { theme.primaryLight }

    /// Deep forest (maps to backgroundTertiary)
    static var forest: Color { theme.backgroundTertiary }

    /// Deepest forest (maps to backgroundPrimary)
    static var deepForest: Color { theme.backgroundPrimary }

    /// Fresh leaf green (maps to healthy)
    static var leaf: Color { theme.healthy }

    // MARK: Secondary - Earth Accents

    /// Rich soil brown (maps to surfaceCard darkened)
    static var soil: Color { theme.surfaceCard }

    /// Warm bark (maps to surfaceElevated)
    static var bark: Color { theme.surfaceElevated }

    /// Soft earth (maps to textMuted)
    static var earth: Color { theme.textMuted }

    // MARK: Accent - Warm Highlights

    /// Golden amber (maps to accent)
    static var amber: Color { theme.accent }

    /// Warm terracotta (maps to accentSecondary)
    static var terracotta: Color { theme.accentSecondary }

    /// Sunlight gold (maps to accentGlow)
    static var sunlight: Color { theme.accentGlow }

    // MARK: Semantic - Plant Health States

    /// Thriving plant (theme-aware)
    static var thriving: Color { theme.thriving }

    /// Healthy plant (theme-aware)
    static var healthy: Color { theme.healthy }

    /// Stressed plant (theme-aware)
    static var stressed: Color { theme.stressed }

    /// Thirsty plant (alias for stressed)
    static var thirsty: Color { theme.stressed }

    /// Wilting plant (theme-aware)
    static var wilting: Color { theme.wilting }

    /// Dormant plant (theme-aware)
    static var dormant: Color { theme.dormant }

    /// Dead plant (theme-aware)
    static var dead: Color { theme.dead }

    /// Withered plant (alias for dead)
    static var withered: Color { theme.dead }

    // MARK: Surface Colors

    /// Primary card background (theme-aware)
    static var cardBackground: Color { theme.surfaceCard }

    /// Elevated card background (theme-aware)
    static var cardBackgroundElevated: Color { theme.surfaceElevated }

    /// Base surface (theme-aware)
    static var surface: Color { theme.backgroundSecondary }

    /// Surface elevated (theme-aware)
    static var surfaceElevated: Color { theme.backgroundTertiary }

    /// Overlay (theme-aware)
    static var overlay: Color { theme.backgroundPrimary.opacity(0.95) }

    // MARK: Text Colors

    /// Primary text (theme-aware)
    static var textPrimary: Color { theme.textPrimary }

    /// Secondary text (theme-aware)
    static var textSecondary: Color { theme.textSecondary }

    /// Tertiary text (theme-aware)
    static var textTertiary: Color { theme.textTertiary }

    /// Muted text (theme-aware)
    static var textMuted: Color { theme.textMuted }

    // MARK: Semantic UI Colors

    /// Success state (theme-aware)
    static var success: Color { theme.success }

    /// Warning state (theme-aware)
    static var warning: Color { theme.warning }

    /// Error state (theme-aware)
    static var error: Color { theme.error }

    /// Info state (theme-aware)
    static var info: Color { theme.info }

    // MARK: Social Feature Colors

    /// Social teal (theme-aware)
    static var socialTeal: Color { theme.socialTeal }

    /// Social teal light (theme-aware)
    static var socialTealLight: Color { theme.socialTealLight }

    // MARK: Light Mode Variants (if needed)
    // Note: These remain static as they're rarely used

    struct Light {
        static let surface = Color(hex: "F8FAF5")
        static let surfaceElevated = Color(hex: "FFFFFF")
        static let cardBackground = Color(hex: "FFFFFF")
        static let textPrimary = Color(hex: "1A2E1E")
        static let textSecondary = Color(hex: "4A5A44")
        static let textTertiary = Color(hex: "7A8A74")
    }
}

// MARK: - Animation Presets

/// Animation presets following Apple WWDC23 spring animation guidelines
struct OnLifeAnimation {

    /// Standard UI transitions - brisk and polished
    /// Use for: tab changes, view transitions, list updates
    static let standard = Animation.spring(duration: 0.5, bounce: 0.15)

    /// Elegant state changes - smooth with no bounce
    /// Use for: mode switches, state transitions, progress updates
    static let elegant = Animation.spring(duration: 0.6, bounce: 0.0)

    /// Plant growth animation - organic and natural feeling
    /// Use for: plant growth, XP gains, level ups
    static let growth = Animation.spring(duration: 0.8, bounce: 0.15)

    /// Celebration animation - playful with noticeable bounce
    /// Use for: achievements, milestones, session completion
    static let celebration = Animation.spring(duration: 0.4, bounce: 0.3)

    /// Quick micro-interactions - snappy feedback
    /// Use for: button presses, toggles, selections
    static let quick = Animation.spring(duration: 0.3, bounce: 0.2)

    /// Gentle settle - soft landing for dragged items
    /// Use for: drag and drop, reordering, placement
    static let settle = Animation.spring(duration: 0.5, bounce: 0.1)

    /// Slow reveal - gradual appearance
    /// Use for: onboarding, tooltips, information reveals
    static let reveal = Animation.spring(duration: 0.7, bounce: 0.05)

    /// Bounce - fun, attention-grabbing
    /// Use for: notifications, badges, alerts
    static let bounce = Animation.spring(duration: 0.5, bounce: 0.4)
}

// MARK: - Spacing System (8-point grid)

/// Consistent spacing values based on 8-point grid system
struct Spacing {
    /// 4pt - Tight spacing, icon padding
    static let xs: CGFloat = 4

    /// 8pt - Small gaps, inline elements
    static let sm: CGFloat = 8

    /// 16pt - Standard spacing, form fields
    static let md: CGFloat = 16

    /// 24pt - Section spacing, card padding
    static let lg: CGFloat = 24

    /// 32pt - Large gaps, major sections
    static let xl: CGFloat = 32

    /// 48pt - Extra large, page margins
    static let xxl: CGFloat = 48

    /// 64pt - Extra extra extra large (legacy compatibility)
    static let xxxl: CGFloat = 64

    /// 80pt - Maximum spacing (legacy compatibility)
    static let xxxxl: CGFloat = 80

    /// 64pt - Hero spacing, major visual breaks
    static let hero: CGFloat = 64

    /// 96pt - Maximum spacing for hero sections
    static let heroLarge: CGFloat = 96
}

// MARK: - Corner Radius

/// Corner radius values using continuous curves for biophilic design
struct CornerRadius {
    /// 8pt - Small elements, chips, tags
    static let small: CGFloat = 8

    /// 12pt - Medium elements, buttons
    static let medium: CGFloat = 12

    /// 16pt - Large elements, input fields
    static let large: CGFloat = 16

    /// 20pt - Extra large (legacy compatibility)
    static let extraLarge: CGFloat = 20

    /// 20pt - Cards and containers
    static let card: CGFloat = 20

    /// 24pt - Modals and sheets
    static let modal: CGFloat = 24

    /// 32pt - Large modals, hero cards
    static let hero: CGFloat = 32

    /// Full circle
    static let full: CGFloat = 9999
}

// MARK: - Typography

/// Text styles using SF Pro with semantic naming
struct OnLifeFont {

    // MARK: Display

    /// Large display - hero sections, splash screens
    static func displayLarge() -> Font {
        .system(size: 40, weight: .bold, design: .rounded)
    }

    /// Display - major headings, garden titles
    static func display() -> Font {
        .system(size: 34, weight: .bold, design: .rounded)
    }

    // MARK: Headings

    /// Heading 1 - page titles
    static func heading1() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }

    /// Heading 2 - section titles
    static func heading2() -> Font {
        .system(size: 22, weight: .semibold, design: .rounded)
    }

    /// Heading 3 - card titles, sub-sections
    static func heading3() -> Font {
        .system(size: 18, weight: .semibold, design: .default)
    }

    // MARK: Body

    /// Body large - emphasized body text
    static func bodyLarge() -> Font {
        .system(size: 17, weight: .regular, design: .default)
    }

    /// Body - standard body text
    static func body() -> Font {
        .system(size: 15, weight: .regular, design: .default)
    }

    /// Body small - secondary text
    static func bodySmall() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    // MARK: Labels

    /// Label - form labels, metadata
    static func label() -> Font {
        .system(size: 13, weight: .medium, design: .default)
    }

    /// Label small - timestamps, minor labels
    static func labelSmall() -> Font {
        .system(size: 11, weight: .medium, design: .default)
    }

    // MARK: Special

    /// Timer display - countdown timers
    static func timer() -> Font {
        .system(size: 48, weight: .bold, design: .monospaced)
    }

    /// Timer small - secondary time displays
    static func timerSmall() -> Font {
        .system(size: 24, weight: .semibold, design: .monospaced)
    }

    /// Stat value - numbers, scores
    static func stat() -> Font {
        .system(size: 32, weight: .bold, design: .rounded)
    }

    /// Button text
    static func button() -> Font {
        .system(size: 17, weight: .semibold, design: .default)
    }

    /// Caption - smallest readable text
    static func caption() -> Font {
        .system(size: 11, weight: .regular, design: .default)
    }
}

// MARK: - Haptic Feedback

/// Haptic feedback presets for consistent tactile responses
struct Haptics {

    /// Success feedback - task completion, achievements
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Warning feedback - approaching limits, caution states
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Error feedback - failures, invalid actions
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Selection feedback - picker changes, option selection
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Impact feedback - button presses, UI interactions
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Light impact - subtle taps, minor interactions
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium impact - standard button presses
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Heavy impact - major actions, confirmations
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Soft impact - gentle, organic feeling
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// Rigid impact - crisp, mechanical feeling
    static func rigid() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}

// MARK: - Shadows

/// Shadow presets for depth hierarchy
struct OnLifeShadow {

    /// Subtle shadow for cards
    static let card = Shadow(
        color: Color.black.opacity(0.15),
        radius: 8,
        x: 0,
        y: 4
    )

    /// Elevated shadow for floating elements
    static let elevated = Shadow(
        color: Color.black.opacity(0.2),
        radius: 16,
        x: 0,
        y: 8
    )

    /// Deep shadow for modals
    static let modal = Shadow(
        color: Color.black.opacity(0.25),
        radius: 24,
        x: 0,
        y: 12
    )

    /// Glow effect for highlights
    static func glow(color: Color) -> Shadow {
        Shadow(color: color.opacity(0.4), radius: 12, x: 0, y: 0)
    }

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Color Extension for Hex

extension Color {
    /// Initialize a Color from a hex string
    /// - Parameter hex: Hex string (with or without #), e.g., "A8B5A0" or "#A8B5A0"
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
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Returns hex string representation of the color
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }

        let r = components[0]
        let g = components.count >= 3 ? components[1] : r
        let b = components.count >= 3 ? components[2] : r

        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }
}

// MARK: - View Modifiers

/// Standard card styling modifier
struct OnLifeCardModifier: ViewModifier {
    var elevated: Bool = false
    var padding: CGFloat = Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(elevated ? OnLifeColors.cardBackgroundElevated : OnLifeColors.cardBackground)
            )
    }
}

/// Card with shadow modifier
struct OnLifeCardWithShadowModifier: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(elevated ? OnLifeColors.cardBackgroundElevated : OnLifeColors.cardBackground)
                    .shadow(
                        color: OnLifeShadow.card.color,
                        radius: OnLifeShadow.card.radius,
                        x: OnLifeShadow.card.x,
                        y: OnLifeShadow.card.y
                    )
            )
    }
}

/// Primary button style
struct OnLifePrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OnLifeFont.button())
            .foregroundColor(OnLifeColors.textPrimary)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(isEnabled ? OnLifeColors.amber : OnLifeColors.textMuted)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(OnLifeAnimation.quick, value: configuration.isPressed)
    }
}

/// Secondary button style
struct OnLifeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OnLifeFont.button())
            .foregroundColor(OnLifeColors.textSecondary)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(OnLifeColors.textTertiary, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(OnLifeAnimation.quick, value: configuration.isPressed)
    }
}

/// Pressable button style - for general buttons with scale feedback
/// Use this instead of simultaneousGesture to avoid scroll conflicts
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(OnLifeAnimation.quick, value: configuration.isPressed)
    }
}

/// Pressable card style - subtle press feedback for cards
/// Use this instead of simultaneousGesture to avoid scroll conflicts
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(OnLifeAnimation.quick, value: configuration.isPressed)
    }
}

/// Pressable chip style - for small interactive chips
struct PressableChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(OnLifeAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {

    /// Apply standard OnLife card styling
    func onLifeCard(elevated: Bool = false, padding: CGFloat = Spacing.lg) -> some View {
        modifier(OnLifeCardModifier(elevated: elevated, padding: padding))
    }

    /// Apply card styling with shadow
    func onLifeCardWithShadow(elevated: Bool = false) -> some View {
        modifier(OnLifeCardWithShadowModifier(elevated: elevated))
    }

    /// Apply standard corner radius with continuous curve
    func continuousCornerRadius(_ radius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Apply shadow preset
    func onLifeShadow(_ shadow: OnLifeShadow.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Preview

#if DEBUG
struct DesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Color Palette
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Color Palette")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    HStack(spacing: Spacing.sm) {
                        colorSwatch(OnLifeColors.sage, "Sage")
                        colorSwatch(OnLifeColors.mint, "Mint")
                        colorSwatch(OnLifeColors.forest, "Forest")
                        colorSwatch(OnLifeColors.deepForest, "Deep")
                    }

                    HStack(spacing: Spacing.sm) {
                        colorSwatch(OnLifeColors.amber, "Amber")
                        colorSwatch(OnLifeColors.terracotta, "Terra")
                        colorSwatch(OnLifeColors.soil, "Soil")
                        colorSwatch(OnLifeColors.bark, "Bark")
                    }

                    HStack(spacing: Spacing.sm) {
                        colorSwatch(OnLifeColors.healthy, "Healthy")
                        colorSwatch(OnLifeColors.thirsty, "Thirsty")
                        colorSwatch(OnLifeColors.wilting, "Wilting")
                        colorSwatch(OnLifeColors.dormant, "Dormant")
                    }
                }
                .padding(Spacing.lg)

                // Typography
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Typography")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Display Large")
                        .font(OnLifeFont.displayLarge())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Heading 1")
                        .font(OnLifeFont.heading1())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Heading 2")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Text("Body text for reading")
                        .font(OnLifeFont.body())
                        .foregroundColor(OnLifeColors.textSecondary)

                    Text("25:00")
                        .font(OnLifeFont.timer())
                        .foregroundColor(OnLifeColors.amber)
                }
                .padding(Spacing.lg)

                // Cards
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Cards")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Standard Card")
                            .font(OnLifeFont.heading3())
                            .foregroundColor(OnLifeColors.textPrimary)
                        Text("This is body text inside a card component.")
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                    .onLifeCard()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Elevated Card")
                            .font(OnLifeFont.heading3())
                            .foregroundColor(OnLifeColors.textPrimary)
                        Text("This card has elevated styling.")
                            .font(OnLifeFont.body())
                            .foregroundColor(OnLifeColors.textSecondary)
                    }
                    .onLifeCard(elevated: true)
                }
                .padding(Spacing.lg)

                // Buttons
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Buttons")
                        .font(OnLifeFont.heading2())
                        .foregroundColor(OnLifeColors.textPrimary)

                    Button("Primary Button") {}
                        .buttonStyle(OnLifePrimaryButtonStyle())

                    Button("Secondary Button") {}
                        .buttonStyle(OnLifeSecondaryButtonStyle())
                }
                .padding(Spacing.lg)
            }
        }
        .background(OnLifeColors.surface)
    }

    private func colorSwatch(_ color: Color, _ name: String) -> some View {
        VStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                .fill(color)
                .frame(width: 60, height: 40)
            Text(name)
                .font(OnLifeFont.caption())
                .foregroundColor(OnLifeColors.textTertiary)
        }
    }
}

struct DesignSystemPreview_Previews: PreviewProvider {
    static var previews: some View {
        DesignSystemPreview()
            .preferredColorScheme(.dark)
    }
}
#endif
