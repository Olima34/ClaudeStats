import SwiftUI
import Charts

struct CategoriesPage: View {
    @EnvironmentObject var model: AppModel
    @State private var metric: Metric = .time

    enum Metric: String, CaseIterable, Identifiable {
        case time, prompts, sessions
        var id: String { rawValue }
        var label: String {
            switch self {
            case .time: return "Temps"
            case .prompts: return "Messages"
            case .sessions: return "Sessions"
            }
        }
    }

    var s: Stats { model.stats }

    func value(_ c: CategoryStat) -> Double {
        switch metric {
        case .time: return c.seconds
        case .prompts: return Double(c.prompts)
        case .sessions: return Double(c.sessions)
        }
    }

    func text(_ v: Double) -> String {
        metric == .time ? Fmt.hours(v) : Fmt.int(v)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                PageHeader(title: "Tes catégories de demandes", subtitle: "Ce que tu demandes à Claude, regroupé par grands thèmes.")
                PillPicker(options: Metric.allCases, selection: $metric, label: { $0.label })
            }
            HStack(alignment: .top, spacing: 18) {
                Panel(title: "Répartition", subtitle: "Par \(metric.label.lowercased())", symbol: "circle.hexagongrid") {
                    let sortedCats = s.categories.sorted { value($0) > value($1) }
                    Donut(items: sortedCats.map {
                        DonutItem(id: $0.category.rawValue, label: $0.category.label, value: value($0),
                                  color: Theme.color($0.category), symbol: $0.category.symbol)
                    }, centerValue: text(sortedCats.reduce(0) { $0 + value($1) }), centerLabel: metric.label.lowercased(),
                          valueText: text, size: 190)
                }
                .frame(maxWidth: .infinity)
                if let top = s.categories.max(by: { value($0) < value($1) }) {
                    Card(padding: 22, featured: true) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Ta catégorie n°1", systemImage: "star").font(.ui(12)).foregroundStyle(Theme.text2)
                            Image(systemName: top.category.symbol)
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 44, height: 44)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.accentSoft))
                            Text(top.category.label).font(.display(24)).foregroundStyle(Theme.text)
                            Text(top.category.blurb).font(.ui(12.5)).foregroundStyle(Theme.text2)
                            Spacer(minLength: 6)
                            Text("\(Fmt.pct(value(top) / max(1, s.categories.reduce(0) { $0 + value($1) }))) de ton \(metric == .time ? "temps" : (metric == .prompts ? "nombre de messages" : "nombre de sessions"))")
                                .font(.ui(12, .medium)).foregroundStyle(Theme.text2)
                        }
                    }
                    .frame(width: 300)
                }
            }
            Panel(title: "Évolution par semaine", subtitle: "Heures par catégorie, semaine après semaine", symbol: "chart.line.uptrend.xyaxis") {
                let present = Category.allCases.filter { c in s.categoryWeeks.contains { $0.category == c } }
                Chart(s.categoryWeeks) { w in
                    BarMark(x: .value("Semaine", w.week, unit: .weekOfYear), y: .value("Heures", w.hours))
                        .foregroundStyle(by: .value("Catégorie", w.category.label))
                        .cornerRadius(2)
                }
                .chartForegroundStyleScale(domain: present.map(\.label), range: present.map { Theme.color($0) })
                .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 8)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.ui(11)).foregroundStyle(Theme.text3)
                    }
                }
                .chartYAxisStyle()
                .frame(height: 240)
            }
            SectionLabel(text: "Détail par catégorie")
            TileGrid(columns: 2) {
                ForEach(s.categories.sorted { value($0) > value($1) }) { c in
                    CategoryCard(stat: c, share: value(c) / max(1, s.categories.reduce(0) { $0 + value($1) }))
                }
            }
            Callout(symbol: "wand.and.stars", title: "Comment c'est calculé ?",
                    text: "Chaque session est classée à partir des mots de ton premier message et des suivants, de son titre, du dossier de travail et des types de fichiers modifiés. Rien n'est envoyé en ligne. Si une session est mal rangée, fais un clic droit dessus dans « Sessions » pour la corriger.")
        }
    }
}

struct CategoryCard: View {
    var stat: CategoryStat
    var share: Double

    var body: some View {
        let color = Theme.color(stat.category)
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: stat.category.symbol)
                        .font(.ui(14))
                        .foregroundStyle(Theme.text2)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: Theme.radiusInner, style: .continuous).fill(Theme.fill2))
                        .overlay(alignment: .bottomTrailing) {
                            Circle().fill(color).frame(width: 8, height: 8).offset(x: 2, y: 2)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.category.label).font(.ui(13, .semibold)).foregroundStyle(Theme.text)
                        Text(stat.category.blurb).font(.ui(11)).foregroundStyle(Theme.text3).lineLimit(1)
                    }
                    Spacer()
                    Text(Fmt.pct(share)).font(.display(20)).foregroundStyle(Theme.text).monospacedDigit()
                }
                HStack(spacing: 0) {
                    MiniStat(value: Fmt.hours(stat.seconds), label: "temps")
                    Spacer()
                    MiniStat(value: Fmt.int(stat.sessions), label: "sessions")
                    Spacer()
                    MiniStat(value: Fmt.int(stat.prompts), label: "messages")
                    Spacer()
                    MiniStat(value: stat.sessions > 0 ? Fmt.hours(stat.seconds / Double(stat.sessions)) : "–", label: "par session")
                }
                if !stat.topProjects.isEmpty {
                    HStack(spacing: 6) {
                        Text("Projets :").font(.ui(11)).foregroundStyle(Theme.text3)
                        ForEach(stat.topProjects.prefix(3)) { p in Tag(text: p.name, symbol: "folder") }
                    }
                }
                if !stat.examples.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(stat.examples.prefix(3), id: \.self) { t in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•").foregroundStyle(Theme.text3)
                                Text(t).foregroundStyle(Theme.text2).lineLimit(1)
                            }
                            .font(.ui(11.5))
                        }
                    }
                }
            }
        }
    }
}
