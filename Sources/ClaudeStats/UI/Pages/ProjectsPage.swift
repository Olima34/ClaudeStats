import SwiftUI
import Charts

struct ProjectsPage: View {
    @EnvironmentObject var model: AppModel
    @State private var sortKey: SortKey = .time

    enum SortKey: String, CaseIterable, Identifiable {
        case time, prompts, tokens, recent
        var id: String { rawValue }
        var label: String {
            switch self {
            case .time: return "Temps"
            case .prompts: return "Messages"
            case .tokens: return "Tokens"
            case .recent: return "Récents"
            }
        }
    }

    var s: Stats { model.stats }

    var sorted: [ProjectStat] {
        switch sortKey {
        case .time: return s.projects
        case .prompts: return s.projects.sorted { $0.prompts > $1.prompts }
        case .tokens: return s.projects.sorted { $0.tokens > $1.tokens }
        case .recent: return s.projects.sorted { $0.last > $1.last }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Tes projets", subtitle: "Les dossiers dans lesquels tu as travaillé avec Claude, et le temps que tu y as passé. Clique sur un projet pour filtrer toute l'app.")
            HStack(spacing: 14) {
                StatTile(symbol: "folder", value: Fmt.int(s.projects.count), label: "Projets actifs")
                StatTile(symbol: "star", value: s.projects.first?.name ?? "–", label: "Projet n°1",
                         detail: s.projects.first.map { "\(Fmt.pct($0.seconds / max(1, s.activeSeconds))) de ton temps" })
                StatTile(symbol: "chart.pie", value: Fmt.pct(top3Share), label: "Part des 3 premiers")
                StatTile(symbol: "clock.arrow.circlepath", value: s.projects.max(by: { $0.last < $1.last })?.name ?? "–",
                         label: "Dernier projet ouvert")
            }
            Panel(title: "Temps par projet", subtitle: "Les 12 projets où tu passes le plus de temps", symbol: "chart.bar.xaxis") {
                let top = Array(s.projects.prefix(12))
                Chart(top) { p in
                    BarMark(x: .value("Heures", p.seconds / 3600), y: .value("Projet", p.name), height: .ratio(0.55))
                        .foregroundStyle(p.name == top.first?.name ? Theme.accent : Theme.chartNeutral)
                        .cornerRadius(3)
                        .annotation(position: .trailing) {
                            Text(Fmt.hours(p.seconds)).font(.ui(11)).foregroundStyle(Theme.text2).monospacedDigit()
                        }
                }
                .chartYAxis {
                    AxisMarks { _ in AxisValueLabel().font(.ui(12)).foregroundStyle(Theme.text) }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(max(3, top.count)) * 30)
            }
            HStack {
                SectionLabel(text: "Tous les projets")
                Spacer()
                PillPicker(options: SortKey.allCases, selection: $sortKey, label: { $0.label })
            }
            TileGrid(columns: 3) {
                ForEach(sorted) { p in
                    ProjectCard(project: p, total: s.activeSeconds)
                        .onTapGesture { model.open(project: p.name) }
                }
            }
        }
    }

    private var top3Share: Double {
        guard s.activeSeconds > 0 else { return 0 }
        return s.projects.prefix(3).reduce(0) { $0 + $1.seconds } / s.activeSeconds
    }
}

struct ProjectCard: View {
    @EnvironmentObject var model: AppModel
    var project: ProjectStat
    var total: Double
    @State private var hovering = false

    var body: some View {
        let weeks = project.weekly.keys.sorted()
        let series: [Double] = {
            guard let first = weeks.first, let last = weeks.last else { return [] }
            return stride(from: first, through: last, by: 7).map { (project.weekly[$0] ?? 0) / 3600 }
        }()
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.display(16))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text(displayPath)
                            .font(.ui(11))
                            .foregroundStyle(Theme.text3)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    Spacer()
                    CategoryChip(category: project.mainCategory, compact: true)
                }
                HStack(spacing: 0) {
                    MiniStat(value: Fmt.hours(project.seconds), label: "temps")
                    Spacer()
                    MiniStat(value: Fmt.int(project.sessions), label: "sessions")
                    Spacer()
                    MiniStat(value: Fmt.int(project.prompts), label: "messages")
                    Spacer()
                    MiniStat(value: Fmt.compact(project.tokens), label: "tokens")
                }
                Group {
                    if series.count > 1 {
                        Sparkline(values: series)
                    } else {
                        VStack {
                            Spacer()
                            Rectangle().fill(Theme.chartNeutral).frame(height: 1.5)
                        }
                    }
                }
                .frame(height: 34)
                Spacer(minLength: 0)
                HStack {
                    Text("\(Fmt.dayShort(Fmt.ts(project.first))) → \(Fmt.dayShort(Fmt.ts(project.last)))")
                    Spacer()
                    if project.linesAdded > 0 { Text("+\(Fmt.compact(project.linesAdded)) lignes") }
                    Text(Fmt.money(project.cost))
                }
                .font(.ui(11))
                .foregroundStyle(Theme.text3)
                .monospacedDigit()
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).strokeBorder(hovering ? Theme.borderStrong : .clear, lineWidth: 1))
        .animation(.easeOut(duration: 0.16), value: hovering)
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Filtrer l'app sur ce projet") { model.open(project: project.name) }
            Button("Voir ses sessions") { model.filter.project = project.name; model.page = .sessions }
            if let path = project.paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                Button("Ouvrir dans le Finder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path) }
            }
        }
        .help(project.paths.sorted().joined(separator: "\n"))
    }

    private var displayPath: String {
        if project.name == "Cowork" { return "Sessions Cowork de l'app Claude" }
        guard let p = project.paths.sorted().first, !p.isEmpty else { return project.name }
        return p.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
