import SwiftUI

struct AppFont {
    // MARK: - Headings (Playfair Display)
    static func heading1() -> Font {
        .custom("PlayfairDisplay-Bold", size: 32)
    }

    static func heading2() -> Font {
        .custom("PlayfairDisplay-Bold", size: 24)
    }

    static func heading3() -> Font {
        .custom("PlayfairDisplay-SemiBold", size: 20)
    }

    // MARK: - Body (Inter)
    static func body() -> Font {
        .custom("Inter-Regular", size: 16)
    }

    static func bodySmall() -> Font {
        .custom("Inter-Regular", size: 14)
    }

    static func bodyLarge() -> Font {
        .custom("Inter-Regular", size: 18)
    }

    // MARK: - Labels
    static func label() -> Font {
        .custom("Inter-Medium", size: 12)
    }

    static func labelSmall() -> Font {
        .custom("Inter-Medium", size: 10)
    }

    // MARK: - Buttons
    static func button() -> Font {
        .custom("Inter-SemiBold", size: 16)
    }

    static func buttonSmall() -> Font {
        .custom("Inter-SemiBold", size: 14)
    }

    // MARK: - Special
    static func timer() -> Font {
        .system(size: 72, weight: .thin, design: .monospaced)
    }

    static func timerSmall() -> Font {
        .system(size: 48, weight: .thin, design: .monospaced)
    }
}
