import SwiftUI
import Charts

// MARK: - Calendar heatmap (GitHub-style)

struct CalendarHeatmap: View {
    var days: [DayStat]
    var metric: (DayStat) -> Double
    var describe: (DayStat) -> String

    @State private var hovered: Int?
    @State private var width: CGFloat = 1080
    private let gap: CGFloat = 3.5
    private let labelW: CGFloat = 30

    var body: some View {
        let byDay = Dictionary(uniqueKeysWithValues: days.map { ($0.day, $0) })
        let values = days.map(metric).filter { $0 > 0 }.sorted()
        let ref = values.isEmpty ? 1 : values[min(values.count - 1, Int(Double(values.count) * 0.95))]
        let end = StatsEngine.todayIndex()
        let firstActive = days.first(where: { metric($0) > 0 })?.day ?? end
        let endWeekStart = end - ((end % 7 + 7 + 3) % 7)
        let dataWeeks = (endWeekStart - (firstActive - ((firstActive % 7 + 7 + 3) % 7))) / 7 + 1

        VStack(alignment: .leading, spacing: 8) {
            let maxWeeks = max(8, Int((width - labelW) / (11 + gap)))
            let fillWeeks = Int((width - labelW) / (19 + gap))
            let weeks = min(maxWeeks, max(fillWeeks, dataWeeks))
            let cell = min(24, (width - labelW) / CGFloat(weeks) - gap)
            let startDay = endWeekStart - (weeks - 1) * 7
            ZStack(alignment: .topLeading) {
                    ForEach(0..<weeks, id: \.self) { col in
                        let d = startDay + col * 7
                        let date = StatsEngine.date(ofDay: d)
                        if Calendar.current.component(.day, from: date) <= 7 {
                            Text(Fmt.dayShort(date).components(separatedBy: " ").last ?? "")
                                .font(.ui(10))
                                .foregroundStyle(Theme.text3)
                                .fixedSize()
                                .offset(x: labelW + CGFloat(col) * (cell + gap), y: 0)
                        }
                    }
                    ForEach([0, 2, 4, 6], id: \.self) { r in
                        Text(Fmt.weekdayShort[r])
                            .font(.ui(9.5))
                            .foregroundStyle(Theme.text3)
                            .frame(height: cell)
                            .offset(x: 0, y: 16 + CGFloat(r) * (cell + gap))
                    }
                    ForEach(0..<weeks, id: \.self) { col in
                        ForEach(0..<7, id: \.self) { row in
                            let d = startDay + col * 7 + row
                            if d <= end {
                                let v = byDay[d].map(metric) ?? 0
                                RoundedRectangle(cornerRadius: min(4, cell * 0.22), style: .continuous)
                                    .fill(Theme.heat(v / max(ref, 0.0001)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: min(4, cell * 0.22), style: .continuous)
                                            .strokeBorder(hovered == d ? Theme.text : (d == end ? Theme.text2 : .clear), lineWidth: hovered == d ? 1.4 : 1)
                                    )
                                    .frame(width: cell, height: cell)
                                    .offset(x: labelW + CGFloat(col) * (cell + gap), y: 16 + CGFloat(row) * (cell + gap))
                                    .onHover { inside in hovered = inside ? d : (hovered == d ? nil : hovered) }
                            }
                        }
                    }
            }
            .frame(maxWidth: .infinity, minHeight: 16 + 7 * (cell + gap), maxHeight: 16 + 7 * (cell + gap), alignment: .topLeading)
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { width = g.size.width }
                    .onChange(of: g.size.width) { _, w in width = w }
            })

            HStack(spacing: 6) {
                if let h = hovered {
                    let stat = byDay[h] ?? DayStat(day: h, date: StatsEngine.date(ofDay: h))
                    Text(describe(stat))
                        .font(.ui(11.5))
                        .foregroundStyle(Theme.text2)
                } else {
                    Text("Survole une case pour voir le détail du jour")
                        .font(.ui(11.5))
                        .foregroundStyle(Theme.text3)
                }
                Spacer()
                Text("Moins").font(.ui(10.5)).foregroundStyle(Theme.text3)
                ForEach([0.0, 0.2, 0.5, 0.7, 1.0], id: \.self) { t in
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Theme.heat(t)).frame(width: 11, height: 11)
                }
                Text("Plus").font(.ui(10.5)).foregroundStyle(Theme.text3)
            }
        }
    }

}

// MARK: - Punch card (weekday × hour)

struct PunchCard: View {
    var cells: [PunchCell]
    var useTime: Bool

    @State private var hovered: Int?

    var body: some View {
        let maxV = cells.map { useTime ? $0.seconds : Double($0.prompts) }.max() ?? 1
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { g in
                let labelW: CGFloat = 34
                let cw = (g.size.width - labelW) / 24
                let ch: CGFloat = 26
                ZStack(alignment: .topLeading) {
                    ForEach(0..<7, id: \.self) { w in
                        Text(Fmt.weekdayShort[w])
                            .font(.ui(10.5))
                            .foregroundStyle(Theme.text3)
                            .frame(width: labelW, height: ch, alignment: .leading)
                            .offset(y: CGFloat(w) * ch)
                    }
                    ForEach(cells) { c in
                        let v = useTime ? c.seconds : Double(c.prompts)
                        let t = maxV > 0 ? v / maxV : 0
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.heat(t))
                            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(hovered == c.id ? Theme.text : .clear, lineWidth: 1.2))
                            .padding(1.5)
                            .frame(width: cw, height: ch)
                            .contentShape(Rectangle())
                            .onHover { inside in hovered = inside ? c.id : (hovered == c.id ? nil : hovered) }
                            .offset(x: labelW + CGFloat(c.hour) * cw, y: CGFloat(c.weekday) * ch)
                    }
                    ForEach([0, 3, 6, 9, 12, 15, 18, 21], id: \.self) { h in
                        Text("\(h) h")
                            .font(.ui(10))
                            .foregroundStyle(Theme.text3)
                            .fixedSize()
                            .frame(width: cw, alignment: .center)
                            .offset(x: labelW + CGFloat(h) * cw, y: 7 * ch + 4)
                    }
                }
            }
            .frame(height: 7 * 26 + 20)
            Group {
                if let h = hovered, let c = cells.first(where: { $0.id == h }) {
                    Text("\(Fmt.cap(Fmt.weekdayLong[c.weekday])) entre \(c.hour) h et \(c.hour + 1) h : \(Fmt.plural(c.prompts, "message", "messages")), \(Fmt.hours(c.seconds)) d'activité")
                        .foregroundStyle(Theme.text2)
                } else {
                    Text("Plus une case est foncée, plus tu es actif à ce moment de la semaine.")
                        .foregroundStyle(Theme.text3)
                }
            }
            .font(.ui(11.5))
        }
    }
}

// MARK: - Word cloud

struct WordCloud: View {
    var words: [NamedCount]
    var limit = 50

    var body: some View {
        let top = Array(words.prefix(limit))
        let maxC = Double(top.first?.count ?? 1)
        let minC = Double(top.last?.count ?? 1)
        // Shuffle deterministically so big words are spread out.
        let ordered = top.enumerated().sorted { ($0.offset * 7919) % 31 < ($1.offset * 7919) % 31 }.map(\.element)
        FlowLayout(spacing: 10, lineSpacing: 4) {
            ForEach(ordered) { w in
                let t = maxC > minC ? (Double(w.count) - minC) / (maxC - minC) : 1
                let rank = top.firstIndex(of: w) ?? 0
                Text(w.name)
                    .font(.display(13 + 25 * sqrt(t), t > 0.5 ? .semibold : .regular))
                    .foregroundStyle(rank < 3 ? Theme.accent : Theme.text.opacity(0.4 + 0.5 * t))
                    .help("\(w.name) : \(Fmt.plural(w.count, "fois", "fois"))")
            }
        }
    }
}

// MARK: - Donut with legend

struct DonutItem: Identifiable {
    var id: String
    var label: String
    var value: Double
    var color: Color
    var symbol: String? = nil
}

struct Donut: View {
    var items: [DonutItem]
    var centerValue: String
    var centerLabel: String
    var valueText: (Double) -> String
    var size: CGFloat = 170

    @State private var selected: String?

    var body: some View {
        let total = max(items.reduce(0) { $0 + $1.value }, 0.0001)
        HStack(alignment: .center, spacing: 22) {
            ZStack {
                Chart(items) { it in
                    SectorMark(angle: .value("Valeur", it.value),
                               innerRadius: .ratio(0.72),
                               outerRadius: .ratio(selected == nil || selected == it.id ? 1 : 0.94),
                               angularInset: 1.2)
                        .cornerRadius(2)
                        .foregroundStyle(it.color)
                        .opacity(selected == nil || selected == it.id ? 1 : 0.45)
                }
                .chartLegend(.hidden)
                .frame(width: size, height: size)
                VStack(spacing: 2) {
                    if let s = selected, let it = items.first(where: { $0.id == s }) {
                        Text(Fmt.pct(it.value / total)).font(.display(22)).foregroundStyle(Theme.text).monospacedDigit()
                        Text(it.label).font(.ui(10.5)).foregroundStyle(Theme.text3).lineLimit(2).multilineTextAlignment(.center)
                    } else {
                        Text(centerValue).font(.display(22)).foregroundStyle(Theme.text).monospacedDigit()
                        Text(centerLabel).font(.ui(10.5)).foregroundStyle(Theme.text3)
                    }
                }
                .frame(width: size * 0.55)
            }
            VStack(alignment: .leading, spacing: 7) {
                ForEach(items) { it in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(it.color).frame(width: 8, height: 8)
                        if let s = it.symbol {
                            Image(systemName: s).font(.ui(10.5)).foregroundStyle(Theme.text3).frame(width: 14)
                        }
                        Text(it.label).font(.ui(12.5)).foregroundStyle(Theme.text).lineLimit(1)
                        Spacer(minLength: 6)
                        Text(valueText(it.value)).font(.ui(11.5)).foregroundStyle(Theme.text2).monospacedDigit()
                        Text(Fmt.pct(it.value / total)).font(.ui(11)).foregroundStyle(Theme.text3).monospacedDigit()
                            .frame(width: 38, alignment: .trailing)
                    }
                    .padding(.vertical, 1)
                    .contentShape(Rectangle())
                    .onHover { inside in withAnimation(.easeOut(duration: 0.15)) { selected = inside ? it.id : (selected == it.id ? nil : selected) } }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    var values: [Double]
    var color: Color = Theme.chartNeutral

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { i, v in
            AreaMark(x: .value("i", i), y: .value("v", v))
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("i", i), y: .value("v", v))
                .interpolationMethod(.monotone)
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            if i == values.count - 1 {
                PointMark(x: .value("i", i), y: .value("v", v))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(22)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

// MARK: - Chart styling helpers

extension View {
    func warmAxes() -> some View {
        self
            .chartXAxisStyle()
            .chartYAxisStyle()
    }

    func chartXAxisStyle() -> some View {
        self.chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(.ui(11)).foregroundStyle(Theme.text3)
            }
        }
    }

    func chartYAxisStyle() -> some View {
        self.chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.chartGrid)
                AxisValueLabel().font(.ui(11)).foregroundStyle(Theme.text3)
            }
        }
    }
}
