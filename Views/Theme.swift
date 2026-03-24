import SwiftUI

// Bloomberg-inspired dark theme
extension Color {
    static let bgMain     = Color(hex: "#0c1018")
    static let bgPanel    = Color(hex: "#111825")
    static let bgHeader   = Color(hex: "#0e1520")
    static let bgItem     = Color(hex: "#131c2a")
    static let bgItemAlt  = Color(hex: "#111825")
    static let bgHover    = Color(hex: "#1c2d45")
    static let bgSelected = Color(hex: "#1a3560")

    static let borderMain = Color(hex: "#2a3f58")
    static let borderDim  = Color(hex: "#1e2f42")
    static let borderLt   = Color(hex: "#3a5578")

    static let textMain   = Color(hex: "#f0f6ff")
    static let textDim    = Color(hex: "#8ab0d0")
    static let textMuted  = Color(hex: "#506880")
    static let textHead   = Color.white

    static let bzGreen    = Color(hex: "#4ade80")
    static let bzRed      = Color(hex: "#f87171")
    static let bzYellow   = Color(hex: "#fbbf24")
    static let bzOrange   = Color(hex: "#fb923c")
    static let bzBlue     = Color(hex: "#60a5fa")
    static let bzCyan     = Color(hex: "#67e8f9")
    static let bzPurple   = Color(hex: "#c084fc")

    static func scoreColor(_ score: Double) -> Color {
        if score >= 9 { return bzRed }
        if score >= 8 { return bzOrange }
        if score >= 7 { return bzYellow }
        if score >= 5 { return bzBlue }
        return textDim
    }

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xff) / 255
        let g = Double((int >>  8) & 0xff) / 255
        let b = Double( int        & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}

let terminalFont = Font.system(.body, design: .monospaced)
let terminalFontSmall = Font.system(.caption, design: .monospaced)
let terminalFontLarge = Font.system(.title3, design: .monospaced).weight(.bold)

struct PanelHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.caption, design: .monospaced).weight(.bold))
            .foregroundColor(.textDim)
            .textCase(.uppercase)
            .tracking(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgHeader)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderMain), alignment: .bottom)
    }
}

extension View {
    func panelHeader() -> some View { modifier(PanelHeaderStyle()) }
}
