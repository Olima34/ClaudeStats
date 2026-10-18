import SwiftUI
import Charts

struct OverviewPage: View {
    @EnvironmentObject var model: AppModel
    @State private var heatByTime = true
    @State private var factIndex = 0

    var s: Stats { model.stats }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            hero
            if !s.hasData {
                Card { EmptyHint(text: "Aucune activité \(s.filter.period.longLabel). Essaie une période plus longue.") }
            } else {
                kpis
                Panel(title: "Calendrier d'activité", subtitle: "Toute ton histoire : chaque case est un jour, plus elle est bleue, plus tu as été actif.", symbol: "calendar") {
                    PillPicker(options: [true, false].map(BoolOption.init), selection: Binding(get: { BoolOption(heatByTime) }, set: { heatByTime = $0.value }),
                               label: { $0.value ? "Temps" : "Messages" })
                } content: {
                    CalendarHeatmap(days: model.history.days,
                                    metric: { heatByTime ? $0.seconds : Double($0.prompts) },
                                    describe: { d in
                                        "\(Fmt.cap(Fmt.weekday(d.date))) : \(Fmt.plural(d.prompts, "message", "messages")), \(Fmt.hours(d.seconds)) d'activité" + (d.sessions > 0 ? ", \(Fmt.plural(d.sessions, "session", "sessions"))" : "")
                                    })
                }
                HStack(alignment: .top, spacing: 18) {
                    activityChart
                        .frame(maxWidth: .infinity)
                    categoriesDonut
                        .frame(width: 480)
                }
                .fixedSize(horizontal: false, vertical: true)
                highlights
                SectionLabel(text: "En perspective")
                equivalences
                didYouKnow
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            MatrixBackdrop(seed: 11, opacity: 0.45)
                .frame(height: 170)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .offset(y: -10)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        ClaudeSpark(size: 34, animate: true)
                        Text(Fmt.greeting(name: model.dataset.account.displayName))
                            .font(.serif(36))
                            .foregroundStyle(Theme.text)
                    }
                    Text(heroSentence)
                        .font(.ui(14))
                        .foregroundStyle(Theme.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    if s.hasData {
                        let p = Insights.persona(s)
                        Button { model.page = .wrapped } label: {
                            HStack(spacing: 7) {
                                Image(systemName: p.symbol).font(.ui(11, .semibold))
                                Text("Ton profil : \(p.title)").font(.ui(12, .semibold))
                                Image(systemName: "chevron.right").font(.ui(9, .bold))
                            }
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.accent.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
                PixelMascot(pixel: 7)
                    .padding(.trailing, 24)
            }
            .padding(.top, 26)
            .padding(.bottom, 6)
        }
    }

    private var heroSentence: String {
        guard s.hasData else { return "Aucune activité \(s.filter.period.longLabel)." }
        let since = s.filter.period == .all ? "Depuis le \(Fmt.dayYear(s.firstDate))" : (s.filter.period.longLabel.prefix(1).uppercased() + s.filter.period.longLabel.dropFirst())
        var t = "\(since), tu as passé \(Fmt.duration(s.activeSeconds)) avec Claude sur \(Fmt.plural(s.activeDays, "jour", "jours"))"
        if let p = s.projects.first { t += ", surtout sur « \(p.name) »" }
        t += "."
        return t
    }

    // MARK: KPIs

    private var kpis: some View {
        TileGrid(columns: 4) {
            StatTile(symbol: "bubble.left.and.bubble.right", value: Fmt.int(s.sessionCount), label: "Sessions",
                     detail: "\(Fmt.dec(s.avgPromptsPerSession)) messages en moyenne")
            StatTile(symbol: "paperplane", value: Fmt.int(s.promptCount), label: "Messages envoyés",
                     detail: "\(Fmt.dec(s.promptsPerActiveDay)) par jour actif")
            StatTile(symbol: "clock", value: Fmt.hours(s.activeSeconds), label: "Temps passé",
                     detail: "\(Fmt.hours(s.secondsPerActiveDay)) par jour actif", tint: Theme.palette[1])
            StatTile(symbol: "calendar", value: Fmt.int(s.activeDays), label: "Jours actifs",
                     detail: s.spanDays > 0 ? "sur \(Fmt.plural(s.spanDays, "jour", "jours")) (\(Fmt.pct(Double(s.activeDays) / Double(max(1, s.spanDays)))))" : nil,
                     tint: Theme.palette[1])
            StatTile(symbol: "text.word.spacing", value: Fmt.compact(s.tokens.output), label: "Tokens générés",
                     detail: "\(Fmt.compact(s.tokens.total)) traités au total", tint: Theme.palette[2])
            StatTile(symbol: "creditcard", value: Fmt.money(s.cost), label: "Équivalent API",
                     detail: "Estimation au tarif public", tint: Theme.palette[2])
            StatTile(symbol: "chevron.left.forwardslash.chevron.right", value: Fmt.compact(s.linesAdded), label: "Lignes écrites",
                     detail: "−\(Fmt.compact(s.linesRemoved)) supprimées · \(Fmt.int(s.filesTouched)) fichiers", tint: Theme.palette[3])
            StatTile(symbol: "flame", value: Fmt.plural(s.streakCurrent, "jour", "jours"), label: "Série en cours",
                     detail: "Record : \(Fmt.plural(s.streakLongest, "jour", "jours")) d'affilée", tint: Theme.palette[3])
        }
    }

    // MARK: Charts

    private var activityChart: some View {
        Panel(title: "Ton activité au fil du temps", subtitle: "Messages envoyés par jour et moyenne glissante sur 7 jours", symbol: "chart.bar") {
            Chart {
                ForEach(s.days) { d in
                    BarMark(x: .value("Jour", d.date, unit: .day), y: .value("Messages", d.prompts))
                        .foregroundStyle(Theme.accent.opacity(0.75))
                        .cornerRadius(2)
                }
                ForEach(s.days) { d in
                    LineMark(x: .value("Jour", d.date, unit: .day), y: .value("Moyenne", d.avg7))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Theme.text2)
                        .lineStyle(StrokeStyle(lineWidth: 1.6))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: false)
                        .font(.ui(10)).foregroundStyle(Theme.text3)
                }
            }
            .chartYAxisStyle()
            .frame(height: 220)
        }
    }

    private var categoriesDonut: some View {
        Panel(title: "Où passe ton temps", subtitle: "Répartition du temps par catégorie", symbol: "circle.hexagongrid") {
            Donut(items: s.categories.prefix(7).map {
                DonutItem(id: $0.category.rawValue, label: $0.category.label, value: $0.seconds,
                          color: Theme.color($0.category))
            }, centerValue: Fmt.hours(s.activeSeconds), centerLabel: "au total",
                  valueText: { Fmt.hours($0) }, size: 150)
            .frame(height: 220)
        }
    }

    // MARK: Highlights

    private var highlights: some View {
        TileGrid(columns: 4) {
            if let d = s.records.biggestDay {
                Highlight(symbol: "trophy", title: "Journée record", value: Fmt.day(d.date),
                          detail: "\(Fmt.plural(d.prompts, "message", "messages")) · \(Fmt.hours(d.seconds))")
            }
            if let l = s.records.longestSession {
                Highlight(symbol: "timer", title: "Plus longue session", value: Fmt.duration(l.seconds),
                          detail: l.title) { model.openSession(l.id) }
            }
            Highlight(symbol: "sun.max", title: "Heure de pointe", value: "\(s.peakHour) h – \(s.peakHour + 1) h",
                      detail: "\(Fmt.cap(Fmt.weekdayLong[s.peakWeekday])) est ton jour le plus actif")
            if let p = s.projects.first {
                Highlight(symbol: "star", title: "Projet favori", value: p.name,
                          detail: "\(Fmt.hours(p.seconds)) · \(Fmt.plural(p.sessions, "session", "sessions"))") { model.page = .projects }
            }
        }
    }

    private var equivalences: some View {
        TileGrid(columns: 3) {
            ForEach(Insights.equivalences(s)) { f in
                Card(padding: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: f.symbol)
                            .font(.ui(15))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.accent.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(f.title).font(.ui(11.5)).foregroundStyle(Theme.text3)
                            Text(f.value).font(.serif(21)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.7)
                            Text(f.detail).font(.ui(11.5)).foregroundStyle(Theme.text2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var didYouKnow: some View {
        let facts = Insights.didYouKnow(s)
        let f = facts[factIndex % max(1, facts.count)]
        return HStack(alignment: .center, spacing: 10) {
            Callout(symbol: f.symbol, title: "Le saviez-vous ? \(f.title)", text: f.detail)
            Button {
                withAnimation(.easeOut(duration: 0.2)) { factIndex += 1 }
            } label: {
                Image(systemName: "arrow.right").font(.ui(12, .semibold))
            }
            .buttonStyle(SoftButtonStyle())
            .help("Anecdote suivante")
            .accessibilityLabel("Anecdote suivante")
        }
    }
}

struct BoolOption: Identifiable, Hashable {
    var value: Bool
    init(_ v: Bool) { value = v }
    var id: Bool { value }
}

struct Highlight: View {
    var symbol: String
    var title: String
    var value: String
    var detail: String
    var action: (() -> Void)? = nil
    @State private var hovering = false

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: symbol).font(.ui(11, .semibold)).foregroundStyle(Theme.accent)
                    Text(title).font(.ui(11.5)).foregroundStyle(Theme.text3)
                    Spacer()
                    if action != nil {
                        Image(systemName: "arrow.up.right").font(.ui(9.5, .semibold)).foregroundStyle(Theme.text3)
                            .opacity(hovering ? 1 : 0)
                    }
                }
                Text(value).font(.serif(20)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.7)
                Text(detail).font(.ui(11.5)).foregroundStyle(Theme.text2).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { action?() }
    }
}
