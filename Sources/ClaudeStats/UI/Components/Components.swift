import SwiftUI

// MARK: - Card

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }
}

/// A card with a title row.
struct Panel<Content: View, Trailing: View>: View {
    var title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.ui(12, .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.ui(13.5, .semibold))
                            .foregroundStyle(Theme.text)
                        if let subtitle {
                            Text(subtitle)
                                .font(.ui(11.5))
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
    init(title: String, subtitle: String? = nil, symbol: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
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
    var tint: Color = Theme.accent

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: symbol)
                        .font(.ui(11, .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(tint.opacity(0.14)))
                    Text(label)
                        .font(.ui(12))
                        .foregroundStyle(Theme.text2)
                        .lineLimit(1)
                }
                Text(value)
                    .font(.serif(28))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
                if let detail {
                    Text(detail)
                        .font(.ui(11))
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
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.serif(30))
                .foregroundStyle(Theme.text)
            Text(subtitle)
                .font(.ui(13))
                .foregroundStyle(Theme.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.ui(10.5, .semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.text3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}

// MARK: - Category chip

struct CategoryChip: View {
    var category: Category
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: category.symbol)
                .font(.ui(9.5, .semibold))
            if !compact {
                Text(category.label)
                    .font(.ui(11, .medium))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Theme.color(category))
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 3.5)
        .background(Capsule().fill(Theme.color(category).opacity(0.13)))
    }
}

struct Tag: View {
    var text: String
    var symbol: String? = nil
    var tint: Color = Theme.text2

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.ui(9.5, .semibold)) }
            Text(text).font(.ui(11, .medium)).lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Theme.track))
    }
}

// MARK: - Ranking rows

struct RankRow: View {
    var rank: Int? = nil
    var symbol: String? = nil
    var name: String
    var value: String
    var fraction: Double
    var tint: Color = Theme.accent
    var detail: String? = nil

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                if let rank {
                    Text("\(rank)")
                        .font(.mono(10.5, .medium))
                        .foregroundStyle(Theme.text3)
                        .frame(width: 16, alignment: .trailing)
                }
                if let symbol {
                    Image(systemName: symbol)
                        .font(.ui(11))
                        .foregroundStyle(tint)
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
                    .font(.ui(12, .medium))
                    .foregroundStyle(Theme.text2)
                    .monospacedDigit()
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(tint.opacity(hovering ? 1 : 0.85))
                        .frame(width: max(4, g.size.width * min(1, max(0, fraction))))
                }
            }
            .frame(height: 5)
            .padding(.leading, rank != nil ? 24 : (symbol != nil ? 24 : 0))
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

struct RankList: View {
    var items: [NamedCount]
    var limit = 8
    var tint: (Int, NamedCount) -> Color = { _, _ in Theme.accent }
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
                        value: valueText(item), fraction: Double(item.count) / max(1, maxV), tint: tint(i, item))
            }
        }
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
                .font(.ui(13, .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.14)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.ui(12.5, .semibold))
                    .foregroundStyle(Theme.text)
                Text(text)
                    .font(.ui(12))
                    .foregroundStyle(Theme.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accentSoft.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.accent.opacity(0.18)))
    }
}

// MARK: - Segmented pills

struct PillPicker<T: Hashable & Identifiable>: View {
    var options: [T]
    @Binding var selection: T
    var label: (T) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { o in
                let on = o == selection
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selection = o }
                } label: {
                    Text(label(o))
                        .font(.ui(11.5, on ? .semibold : .regular))
                        .foregroundStyle(on ? Theme.text : Theme.text2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7).fill(on ? Theme.selected : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.border))
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

// MARK: - Hover button style

struct SoftButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(12, .medium))
            .foregroundStyle(prominent ? Color.white : Theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(prominent ? Theme.accent : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(prominent ? Color.clear : Theme.border))
            .opacity(configuration.isPressed ? 0.75 : 1)
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
