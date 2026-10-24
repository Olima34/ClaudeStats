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
        adaptive(light: (light, alpha), dark: (dark, alpha))
    }

    /// A color that follows the light / dark appearance, with its own opacity in each.
    static func adaptive(light: (UInt32, CGFloat), dark: (UInt32, CGFloat)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: dark.0, alpha: dark.1)
                : NSColor(hex: light.0, alpha: light.1)
        })
    }
}

/// "Graphite" design system (design/design_system_macos27.md): cool neutrals,
/// glass and light for depth, and a single accent used sparingly.
enum Theme {
    // Surfaces
    /// The inset stage that holds the pages.
    static let bg = Color.adaptive(light: 0xF6F6F8, dark: 0x121215)
    /// Under the glass sidebar, when the window material is unavailable.
    static let window = Color.adaptive(light: 0xE6E7EA, dark: 0x0B0C0E)
    static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x1A1A1E)
    /// Top of the card gradient: light comes from above.
    static let cardTop = Color.adaptive(light: 0xFFFFFF, dark: 0x1F1F23)
    static let cardRaised = Color.adaptive(light: 0xFFFFFF, dark: 0x232328)
    /// Popovers, menus, palette, status module.
    static let floating = Color.adaptive(light: (0xFFFFFF, 0.80), dark: (0x202025, 0.82))

    // Neutral fills for controls, tracks and hovers.
    static let fill1 = Color.adaptive(light: (0x000000, 0.04), dark: (0xFFFFFF, 0.05))
    static let fill2 = Color.adaptive(light: (0x000000, 0.06), dark: (0xFFFFFF, 0.08))
    static let fill3 = Color.adaptive(light: (0x000000, 0.08), dark: (0xFFFFFF, 0.11))
    static let hover = fill1
    static let selected = fill3

    // Borders & light
    static let border = Color.adaptive(light: (0x000000, 0.07), dark: (0xFFFFFF, 0.07))
    static let borderStrong = Color.adaptive(light: (0x000000, 0.12), dark: (0xFFFFFF, 0.12))
    /// 1 px specular highlight on the top edge of raised surfaces.
    static let rim = Color.adaptive(light: (0xFFFFFF, 0.9), dark: (0xFFFFFF, 0.10))
    static let shadow = Color.adaptive(light: (0x000000, 0.06), dark: (0x000000, 0.35))

    // Text
    static let text = Color.adaptive(light: (0x000000, 0.88), dark: (0xFFFFFF, 0.94))
    static let text2 = Color.adaptive(light: (0x000000, 0.58), dark: (0xFFFFFF, 0.62))
    static let text3 = Color.adaptive(light: (0x000000, 0.40), dark: (0xFFFFFF, 0.40))

    // Accent: the only hue of the interface (Claude terracotta).
    static let accentHex: UInt32 = 0xD8795A
    static let accent = Color.adaptive(light: 0xD05F39, dark: accentHex)
    static let accentDeep = Color.adaptive(light: 0xB4502E, dark: 0xC4613F)
    static let accentSoft = Color.adaptive(light: (0xD05F39, 0.12), dark: (accentHex, 0.14))
    static let accentRim = Color.adaptive(light: (0xD05F39, 0.45), dark: (accentHex, 0.55))
    /// Claude's own orange, kept for the logo and the pixel mascot.
    static let brandHex: UInt32 = 0xD97757
    static let brand = Color(hex: brandHex)
    static let matrix = Color.adaptive(light: 0x9A9AA0, dark: 0x4A4C55)

    // Semantic, for real states only.
    static let positive = Color(hex: 0x4CB782)
    static let warning = Color(hex: 0xE0A443)
    static let negative = Color(hex: 0xE5675C)

    // Charts: one neutral for the data, the accent for the insight.
    static let chartNeutral = Color.adaptive(light: (0x000000, 0.22), dark: (0xFFFFFF, 0.26))
    static let chartGrid = Color.adaptive(light: (0x000000, 0.06), dark: (0xFFFFFF, 0.06))
    static let track = Color.adaptive(light: (0x000000, 0.05), dark: (0xFFFFFF, 0.06))
    static let other = Color.adaptive(light: (0x000000, 0.18), dark: (0xFFFFFF, 0.20))

    /// Muted categorical palette, led by the accent.
    static let palette: [Color] = [
        accent,
        Color.adaptive(light: 0x5E7697, dark: 0x7F95B2), // slate
        Color.adaptive(light: 0x6E8A68, dark: 0x8FA58A), // sage
        Color.adaptive(light: 0xA8925F, dark: 0xC2AE8C), // sand
        Color.adaptive(light: 0x8371A0, dark: 0xA190B8), // lavender
        Color.adaptive(light: 0x56606B, dark: 0x6F7A86), // steel
        Color.adaptive(light: 0x5F8C8A, dark: 0x82AAA7), // sea
        Color.adaptive(light: 0x9A7560, dark: 0xB89A86), // clay
        Color.adaptive(light: 0x7D7470, dark: 0x9C928C), // stone
    ]

    static func color(_ c: Category) -> Color {
        switch c {
        case .dev: return palette[0]
        case .study: return palette[1]
        case .design: return palette[2]
        case .writing: return palette[3]
        case .automation: return palette[4]
        case .data: return palette[5]
        case .research: return palette[6]
        case .business: return palette[7]
        case .personal: return palette[8]
        case .other: return other
        }
    }

    static func color(index: Int) -> Color { palette[abs(index) % palette.count] }

    /// Five-step heat scale, from the empty track to the full accent.
    static func heat(_ t: Double) -> Color {
        if t <= 0 { return track }
        switch t {
        case ..<0.3: return accent.opacity(0.2)
        case ..<0.55: return accent.opacity(0.38)
        case ..<0.8: return accent.opacity(0.62)
        default: return accent
        }
    }

    // Radii: the stage is concentric with the window (inner = outer − inset).
    static let stageInset: CGFloat = 8
    static let radiusStage: CGFloat = 14
    static let radiusCard: CGFloat = 12
    static let radiusInner: CGFloat = 8
}

// MARK: - Typography

extension Font {
    /// Numbers and titles: SF Pro, heavier than body text.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
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
