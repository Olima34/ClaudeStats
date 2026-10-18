import SwiftUI
import AppKit

// MARK: - Colors

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(nsColor: NSColor(hex: hex, alpha: alpha))
    }

    /// A color that follows the light / dark appearance.
    static func adaptive(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: dark, alpha: alpha)
                : NSColor(hex: light, alpha: alpha)
        })
    }
}

enum Theme {
    // Surfaces, a shade darker than the Claude desktop app.
    static let bg = Color.adaptive(light: 0xF4F3EF, dark: 0x141413)
    static let sidebar = Color.adaptive(light: 0xEBE9E2, dark: 0x0F0F0E)
    static let card = Color.adaptive(light: 0xFCFBF9, dark: 0x1B1B1A)
    static let cardRaised = Color.adaptive(light: 0xFFFFFF, dark: 0x222221)
    static let hover = Color.adaptive(light: 0xE2E0D8, dark: 0x222221)
    static let selected = Color.adaptive(light: 0xDCD9D0, dark: 0x2A2A28)
    static let border = Color.adaptive(light: 0xDEDBD1, dark: 0x2A2A28)
    static let borderStrong = Color.adaptive(light: 0xCCC8BC, dark: 0x3A3A37)
    static let track = Color.adaptive(light: 0xE6E3DA, dark: 0x252523)

    // Text
    static let text = Color.adaptive(light: 0x1F1E1D, dark: 0xF4F2EC)
    static let text2 = Color.adaptive(light: 0x5F5D57, dark: 0xB4B1A7)
    static let text3 = Color.adaptive(light: 0x8C897F, dark: 0x7F7C73)

    // Accent (Claude blue)
    static let accentHex: UInt32 = 0x4C9AE6
    static let accent = Color.adaptive(light: 0x2C84DB, dark: accentHex)
    static let accentDeep = Color.adaptive(light: 0x1F6CC0, dark: 0x2C84DB)
    static let accentSoft = Color.adaptive(light: 0xDCE9F7, dark: 0x16222F)
    /// Claude's own orange, kept for the logo and the pixel mascot.
    static let brandHex: UInt32 = 0xD97757
    static let brand = Color(hex: brandHex)
    static let matrix = Color.adaptive(light: 0x9A9488, dark: 0x4F6577)

    /// Palette for categorical charts, led by the Claude blue.
    static let palette: [Color] = [
        accent,               // blue
        Color(hex: 0x5BA3A0), // teal
        Color(hex: 0x8DA47E), // sage
        Color(hex: 0xD4A27F), // kraft
        Color(hex: 0x9B87C4), // lavender
        Color(hex: 0xC46686), // rose
        Color(hex: 0x7C83D6), // indigo
        Color(hex: 0xCBB26A), // ochre
        Color(hex: 0x8E8B82), // stone
        Color(hex: 0xB0856A)  // clay
    ]

    static func color(_ c: Category) -> Color {
        switch c {
        case .dev: return palette[0]
        case .study: return palette[1]
        case .business: return palette[2]
        case .writing: return palette[3]
        case .design: return palette[5]
        case .data: return palette[6]
        case .research: return palette[4]
        case .automation: return palette[7]
        case .personal: return palette[9]
        case .other: return palette[8]
        }
    }

    static func color(index: Int) -> Color { palette[abs(index) % palette.count] }

    /// Heat scale from the track color to full blue.
    static func heat(_ t: Double) -> Color {
        if t <= 0 { return track }
        let steps: [Double] = [0.22, 0.42, 0.65, 0.85, 1.0]
        let v = steps.first(where: { t <= $0 }) ?? 1
        return accent.opacity(0.18 + 0.82 * v)
    }
}

// MARK: - Typography

extension Font {
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Formatting

enum Fmt {
    static let fr = Locale(identifier: "fr_FR")
    static let weekdayShort = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
    static let weekdayLong = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]

    private static let intF: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = fr
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    private static let decF: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = fr
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f
    }()

    static func int(_ v: Int) -> String { intF.string(from: NSNumber(value: v)) ?? "\(v)" }
    static func int(_ v: Double) -> String { intF.string(from: NSNumber(value: v.rounded())) ?? "\(Int(v))" }
    static func dec(_ v: Double) -> String {
        if abs(v) >= 100 { return int(v) }
        return decF.string(from: NSNumber(value: v)) ?? String(format: "%.1f", v)
    }

    /// Uppercases only the first letter ("mardi 6 octobre" → "Mardi 6 octobre").
    static func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    /// Lowercases only the first letter.
    static func uncap(_ s: String) -> String { s.prefix(1).lowercased() + s.dropFirst() }

    static func compact(_ v: Int) -> String { compact(Double(v)) }
    static func compact(_ v: Double) -> String {
        let a = abs(v)
        if a >= 1e9 { return dec(v / 1e9) + " Md" }
        if a >= 1e6 { return dec(v / 1e6) + " M" }
        if a >= 1e4 { return int(v / 1e3) + " k" }
        if a >= 1e3 { return dec(v / 1e3) + " k" }
        return int(v)
    }

    static func pct(_ v: Double) -> String {
        if v > 0 && v < 0.01 { return "< 1 %" }
        return int(v * 100) + " %"
    }

    static func money(_ v: Double) -> String {
        if v >= 100 { return int(v) + " $" }
        return String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",") + " $"
    }

    static func duration(_ s: Double) -> String {
        if s < 60 { return "\(Int(s)) s" }
        let m = Int(s / 60)
        if m < 60 { return "\(m) min" }
        let h = m / 60, r = m % 60
        if h >= 100 { return "\(int(s / 3600)) h" }
        return r == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", r))"
    }

    static func hours(_ s: Double) -> String {
        let h = s / 3600
        if h < 1 { return "\(Int(s / 60)) min" }
        return h < 10 ? dec(h) + " h" : int(h) + " h"
    }

    static func hour(_ h: Int) -> String { "\(h) h" }

    private static func df(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = fr
        f.setLocalizedDateFormatFromTemplate(format)
        return f
    }
    private static let dayMonth = df("d MMMM")
    private static let dayMonthShort = df("d MMM")
    private static let dayMonthYear = df("d MMMM yyyy")
    private static let weekdayDay = df("EEEE d MMMM")
    private static let time = df("HH:mm")
    private static let full = df("EEEE d MMMM yyyy HH:mm")
    private static let monthYear = df("MMMM yyyy")

    static func day(_ d: Date) -> String { dayMonth.string(from: d) }
    static func dayShort(_ d: Date) -> String { dayMonthShort.string(from: d) }
    static func dayYear(_ d: Date) -> String { dayMonthYear.string(from: d) }
    static func weekday(_ d: Date) -> String { weekdayDay.string(from: d) }
    static func clock(_ d: Date) -> String { time.string(from: d) }
    static func full(_ d: Date) -> String { full.string(from: d) }
    static func month(_ d: Date) -> String { monthYear.string(from: d) }
    static func ts(_ t: Double) -> Date { Date(timeIntervalSince1970: t) }

    static func relative(_ d: Date) -> String {
        let s = Date().timeIntervalSince(d)
        if s < 60 { return "à l'instant" }
        if s < 3600 { return "il y a \(Int(s / 60)) min" }
        if s < 86400 { return "il y a \(Int(s / 3600)) h" }
        let days = Int(s / 86400)
        if days < 30 { return "il y a \(days) j" }
        return dayShort(d)
    }

    static func plural(_ n: Int, _ one: String, _ many: String) -> String {
        "\(int(n)) \(n > 1 ? many : one)"
    }

    static func greeting(name: String) -> String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Bonjour, \(name)"
        case 12..<18: return "Bon après-midi, \(name)"
        case 18..<23: return "Bonsoir, \(name)"
        default: return "Belle nuit, \(name)"
        }
    }
}
