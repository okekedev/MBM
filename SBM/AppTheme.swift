import SwiftUI

// MARK: - App Theme
// Clean, modern light theme - purple, white, gray

struct AppTheme {

    // MARK: - Brand Colors

    static let purple = Color(hex: "6B4EFF")
    static let purpleLight = Color(hex: "8B71FF")

    // MARK: - Gray Scale

    static let gray50 = Color(hex: "FAFAFA")
    static let gray100 = Color(hex: "F5F5F5")
    static let gray200 = Color(hex: "EEEEEE")
    static let gray400 = Color(hex: "BDBDBD")
    static let gray600 = Color(hex: "757575")
    static let gray900 = Color(hex: "212121")

    // MARK: - Semantic Colors

    static let green = Color(hex: "00A86B")
    static let red = Color(hex: "E53935")
    static let orange = Color(hex: "FB8C00")
    static let blue = Color(hex: "1E88E5")
    static let teal = Color(hex: "00897B")

    // MARK: - Gradients

    static let purpleGradient = LinearGradient(
        colors: [purple, purpleLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let grayGradient = LinearGradient(
        colors: [Color(hex: "757575"), Color(hex: "9E9E9E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Semantic Mappings

    static let background = gray50
    static let card = Color.white
    static let text = gray900
    static let textSecondary = gray600
    static let textMuted = gray400
    static let shadow = Color.black.opacity(0.08)

    // MARK: - Sizes

    static let cornerRadius: CGFloat = 16
    static let cornerRadiusSmall: CGFloat = 12

    // MARK: - Aliases (used in code)

    static let primary = purple
    static let danger = red
    static let primaryGradient = purpleGradient
    static let textPrimary = text
    static let secondaryLabel = textSecondary
}

// MARK: - Color from Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
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
}

// MARK: - Gradient Background

struct GradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [AppTheme.purple.opacity(0.05), AppTheme.gray100],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Currency Formatting

func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "$0"
}
