import SwiftUI

// MARK: - Surfaces

/// 1 px specular highlight that follows the top edge of a rounded surface and fades down its sides.
struct TopRim: View {
    var radius: CGFloat
    var color: Color = Theme.rim

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(color, lineWidth: 1)
            .frame(height: radius * 2)
            .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center))
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
    }
}

/// Raised card material: soft vertical gradient, hairline border, specular top rim, quiet shadow.
/// A featured surface (one per screen at most) gets an accent rim and a faint accent glow.
struct SurfaceBackground: View {
    var radius: CGFloat = Theme.radiusCard
    var featured = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Theme.cardTop, Theme.card], startPoint: .top, endPoint: .bottom))
            if featured {
                shape.fill(RadialGradient(colors: [Theme.accentSoft, .clear], center: .topLeading, startRadius: 0, endRadius: 340))
            }
        }
        .overlay(shape.strokeBorder(Theme.border, lineWidth: 1))
        .overlay(TopRim(radius: radius, color: featured ? Theme.accentRim : Theme.rim))
        .shadow(color: Theme.shadow, radius: 12, y: 6)
    }
}

/// Floating glass (status module, palette, popovers).
struct FloatingBackground: View {
    var radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Theme.floating)
        }
        .overlay(shape.strokeBorder(Theme.border, lineWidth: 1))
        .overlay(TopRim(radius: radius))
        .shadow(color: Theme.shadow, radius: 16, y: 8)
    }
}

extension View {
    func surface(radius: CGFloat = Theme.radiusCard, featured: Bool = false) -> some View {
        background(SurfaceBackground(radius: radius, featured: featured))
    }

    func floatingSurface(radius: CGFloat) -> some View {
        background(FloatingBackground(radius: radius))
    }
}

// MARK: - Card

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    var featured = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .surface(featured: featured)
    }
}

/// A card with a title row.
struct Panel<Content: View, Trailing: View>: View {
    var title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    var featured = false
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    var body: some View {
        Card(featured: featured) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.ui(12))
                            .foregroundStyle(Theme.text3)
                            .frame(width: 16)
                            .padding(.top, 1)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.ui(13, .semibold))
                            .foregroundStyle(Theme.text)
                        if let subtitle {
                            Text(subtitle)
                                .font(.ui(12))
                                .foregroundStyle(Theme.text3)
                        }
                    }
                    Spacer(minLength: 8)
                    trailing
                }
                content
            }
        }
    }
}

extension Panel where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, symbol: String? = nil, featured: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.featured = featured
        self.trailing = EmptyView()
        self.content = content()
    }
}

// MARK: - Equal-height grid

/// A grid whose cells in a row all share the height of the tallest one.
struct TileGrid<Content: View>: View {
    var columns: Int
    var spacing: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        Group(subviews: content) { subs in
            let rows = (subs.count + columns - 1) / max(1, columns)
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { c in
                            let i = r * columns + c
                            if i < subs.count {
                                subs[i].frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Stat tile

struct StatTile: View {
    var symbol: String
    var value: String
    var label: String
    var detail: String? = nil
    var featured = false

    var body: some View {
        Card(padding: 16, featured: featured) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: symbol)
                        .font(.ui(11.5))
                        .foregroundStyle(featured ? Theme.accent : Theme.text3)
                        .frame(width: 15)
                    Text(label)
                        .font(.ui(12))
                        .foregroundStyle(Theme.text2)
                        .lineLimit(1)
                }
                Text(value)
                    .font(.display(26))
                    .foregroundStyle(Theme.text)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
                if let detail {
                    Text(detail)
                        .font(.ui(12))
                        .foregroundStyle(Theme.text3)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Headers

struct PageHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.display(28, .bold))
                .foregroundStyle(Theme.text)
            Text(subtitle)
                .font(.ui(13))
                .foregroundStyle(Theme.text2)
                .frame(maxWidth: 720, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.ui(11, .semibold))
            .tracking(0.66)
            .foregroundStyle(Theme.text3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}

// MARK: - Category chip

/// Neutral tag with a dot of the category color: the color stays a hint, never a fill.
struct CategoryChip: View {
    var category: Category
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.color(category)).frame(width: 6, height: 6)
            if compact {
                Image(systemName: category.symbol).font(.ui(10))
            } else {
                Text(category.label)
                    .font(.ui(11, .medium))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Theme.text2)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.fill2))
    }
}

struct Tag: View {
    var text: String
    var symbol: String? = nil
    var tint: Color = Theme.text2

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.ui(9.5, .medium)) }
            Text(text).font(.ui(11, .medium)).lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.fill2))
    }
}

// MARK: - Ranking rows

struct RankRow: View {
    var rank: Int? = nil
    var symbol: String? = nil
    var name: String
    var value: String
    var fraction: Double
    var tint: Color = Theme.chartNeutral
    var detail: String? = nil

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                if let rank {
                    Text("\(rank)")
                        .font(.ui(11))
                        .foregroundStyle(Theme.text3)
                        .monospacedDigit()
                        .frame(width: 16, alignment: .leading)
                }
                if let symbol {
                    Image(systemName: symbol)
                        .font(.ui(11))
                        .foregroundStyle(Theme.text3)
                        .frame(width: 16)
                }
                Text(name)
                    .font(.ui(12.5))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let detail {
                    Text(detail)
                        .font(.ui(11))
                        .foregroundStyle(Theme.text3)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(value)
                    .font(.ui(12))
                    .foregroundStyle(Theme.text2)
                    .monospacedDigit()
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Theme.track)
                    RoundedRectangle(cornerRadius: 2).fill(hovering && tint == Theme.chartNeutral ? Theme.text2 : tint)
                        .frame(width: max(3, g.size.width * min(1, max(0, fraction))))
                }
            }
            .frame(height: 4)
            .padding(.leading, rank != nil ? 24 : (symbol != nil ? 24 : 0))
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

struct RankList: View {
    var items: [NamedCount]
    var limit = 8
    /// Neutral bars, the leader slightly brighter. `highlightLeader` puts it in the accent:
    /// keep that for the main ranking of a page.
    var highlightLeader = false
    var tint: ((Int, NamedCount) -> Color)? = nil
    var valueText: (NamedCount) -> String = { Fmt.int($0.count) }
    var nameText: (NamedCount) -> String = { $0.name }
    var symbol: ((NamedCount) -> String?)? = nil
    var numbered = true

    var body: some View {
        let top = Array(items.prefix(limit))
        let maxV = Double(top.map(\.count).max() ?? 1)
        VStack(spacing: 11) {
            if top.isEmpty {
                EmptyHint(text: "Rien à afficher pour cette période.")
            }
            ForEach(Array(top.enumerated()), id: \.offset) { i, item in
                RankRow(rank: numbered ? i + 1 : nil, symbol: symbol?(item), name: nameText(item),
                        value: valueText(item), fraction: Double(item.count) / max(1, maxV), tint: color(i, item))
            }
        }
    }
}

extension RankList {
    func color(_ i: Int, _ item: NamedCount) -> Color {
        if let tint { return tint(i, item) }
        guard i == 0 else { return Theme.chartNeutral }
        return highlightLeader ? Theme.accent : Theme.text2
    }
}

struct EmptyHint: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.ui(12))
            .foregroundStyle(Theme.text3)
            .frame(maxWidth: .infinity, minHeight: 60)
    }
}

// MARK: - Callout

struct Callout: View {
    var symbol: String = "lightbulb"
    var title: String
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.ui(13))
                .foregroundStyle(Theme.text2)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.fill2))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.ui(12.5, .semibold))
                    .foregroundStyle(Theme.text)
                Text(text)
                    .font(.ui(12.5))
                    .foregroundStyle(Theme.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.fill1))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border))
    }
}

// MARK: - Segmented control

/// macOS-style segmented control. Stays neutral: the accent is not for navigation state.
struct PillPicker<T: Hashable & Identifiable>: View {
    var options: [T]
    @Binding var selection: T
    var label: (T) -> String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { o in
                let on = o == selection
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { selection = o }
                } label: {
                    Text(label(o))
                        .font(.ui(12, .medium))
                        .foregroundStyle(on ? Theme.text : Theme.text2)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(scheme == .dark ? Theme.fill3 : Color.white)
                                    .overlay(TopRim(radius: 6))
                                    .shadow(color: .black.opacity(scheme == .dark ? 0.25 : 0.12), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.fill1))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.border))
    }
}

// MARK: - Ring

struct ProgressRing: View {
    var progress: Double
    var tint: Color = Theme.accent
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Buttons

/// Prominent: accent fill. Otherwise: neutral glass with a specular rim.
struct SoftButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(13, .medium))
            .foregroundStyle(prominent ? Color.white : Theme.text)
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background {
                let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
                if prominent {
                    shape.fill(Theme.accent)
                        .overlay(TopRim(radius: 8, color: .white.opacity(0.25)))
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                } else {
                    shape.fill(Theme.fill2)
                        .overlay(shape.strokeBorder(Theme.border))
                        .overlay(TopRim(radius: 8))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Small square icon button (toolbar, status module).
struct IconButtonStyle: ButtonStyle {
    var glass = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(13, .medium))
            .foregroundStyle(Theme.text2)
            .frame(width: 28, height: 28)
            .background {
                let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
                if glass {
                    shape.fill(Theme.fill2).overlay(shape.strokeBorder(Theme.border)).overlay(TopRim(radius: 8))
                } else {
                    shape.fill(configuration.isPressed ? Theme.fill2 : .clear)
                }
            }
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

// MARK: - Flow layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width && x > 0 { x = 0; y += lineH + lineSpacing; lineH = 0 }
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
        return CGSize(width: width, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var lines: [[(LayoutSubviews.Element, CGSize)]] = [[]]
        var x: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.width && x > 0 { lines.append([]); x = 0 }
            lines[lines.count - 1].append((v, s))
            x += s.width + spacing
        }
        var y = bounds.minY
        for line in lines {
            let lineW = line.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, line.count - 1))
            let lineH = line.map { $0.1.height }.max() ?? 0
            var cx = bounds.minX + (bounds.width - lineW) / 2
            for (v, s) in line {
                v.place(at: CGPoint(x: cx, y: y + (lineH - s.height) / 2), proposal: ProposedViewSize(s))
                cx += s.width + spacing
            }
            y += lineH + lineSpacing
        }
    }
}
