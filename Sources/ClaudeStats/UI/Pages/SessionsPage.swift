import SwiftUI
import Charts

struct SessionsPage: View {
    @EnvironmentObject var model: AppModel
    @State private var sort: SortKey = .recent
    @State private var category: Category?
    @State private var visible = 60
    @State private var showAutomatic = false

    enum SortKey: String, CaseIterable, Identifiable {
        case recent, time, prompts, tokens, cost
        var id: String { rawValue }
        var label: String {
            switch self {
            case .recent: return "Récentes"
            case .time: return "Durée"
            case .prompts: return "Messages"
            case .tokens: return "Tokens"
            case .cost: return "Coût"
            }
        }
    }

    var s: Stats { model.stats }

    var filtered: [SessionRow] {
        var rows = s.sessions
        if !showAutomatic { rows = rows.filter { $0.prompts > 0 } }
        if let category { rows = rows.filter { $0.category == category } }
        let q = model.search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            let fq = Words.fold(q)
            rows = rows.filter { r in
                Words.fold(r.title.lowercased()).contains(fq) || Words.fold(r.project.lowercased()).contains(fq)
                    || Words.fold(model.dataset.sessions[r.index].firstPrompt.lowercased()).contains(fq)
            }
        }
        switch sort {
        case .recent: rows.sort { $0.end > $1.end }
        case .time: rows.sort { $0.seconds > $1.seconds }
        case .prompts: rows.sort { $0.prompts > $1.prompts }
        case .tokens: rows.sort { $0.tokens > $1.tokens }
        case .cost: rows.sort { $0.cost > $1.cost }
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Tes sessions", subtitle: "Toutes tes conversations avec Claude, leur durée, leur taille et ce qu'elles ont coûté en tokens.")
            HStack(spacing: 14) {
                StatTile(symbol: "number", value: Fmt.dec(s.avgPromptsPerSession), label: "Messages par session",
                         detail: "Médiane : \(Fmt.dec(s.medianPromptsPerSession))")
                StatTile(symbol: "timer", value: Fmt.duration(s.avgSessionSeconds), label: "Durée moyenne",
                         detail: "Médiane : \(Fmt.duration(s.medianSessionSeconds))")
                StatTile(symbol: "hourglass", value: Fmt.duration(s.claudeSeconds), label: "Claude a travaillé",
                         detail: "\(Fmt.duration(s.avgTurnSeconds)) par réponse en moyenne")
                StatTile(symbol: "arrow.triangle.branch", value: Fmt.int(s.sources.reduce(0) { $0 + $1.count }), label: "Sessions",
                         detail: s.sources.map { "\($0.count) \($0.name)" }.joined(separator: " · "))
            }
            HStack(alignment: .top, spacing: 18) {
                histogram(title: "Taille des sessions", subtitle: "Nombre de messages envoyés par session", data: s.sessionLengthBuckets)
                histogram(title: "Durée des sessions", subtitle: "Temps actif par session", data: s.sessionDurationBuckets)
            }
            controls
            HStack(alignment: .top, spacing: 18) {
                list
                if let id = model.selectedSession, let row = s.sessions.first(where: { $0.id == id }) {
                    SessionDetail(row: row)
                        .frame(width: 380)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: model.selectedSession)
        }
    }

    private func histogram(title: String, subtitle: String, data: [NamedCount]) -> some View {
        let peak = data.max(by: { $0.count < $1.count })?.name
        return Panel(title: title, subtitle: subtitle, symbol: "chart.bar") {
            Chart(data) { b in
                BarMark(x: .value("Tranche", b.name), y: .value("Sessions", b.count), width: .ratio(0.65))
                    .foregroundStyle(b.name == peak ? Theme.accent : Theme.chartNeutral)
                    .cornerRadius(3)
                    .annotation(position: .top) {
                        Text(b.count > 0 ? "\(b.count)" : "").font(.ui(11)).foregroundStyle(Theme.text3).monospacedDigit()
                    }
            }
            .chartXAxisStyle()
            .chartYAxis(.hidden)
            .frame(height: 160)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    FilterChip(label: "Toutes", symbol: nil, selected: category == nil) { category = nil }
                        .liquidItem("all")
                    ForEach(s.categories) { c in
                        FilterChip(label: c.category.label, symbol: nil, selected: category == c.category,
                                   dot: Theme.color(c.category)) {
                            category = category == c.category ? nil : c.category
                        }
                        .liquidItem(c.category.rawValue)
                    }
                }
                .liquidSelection(category?.rawValue ?? "all", axis: .horizontal, radius: 7) { id in
                    category = Category(rawValue: id)
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.never)
            Spacer()
            searchField
            let automatic = s.sessions.filter { $0.prompts == 0 }.count
            if automatic > 0 {
                Toggle(isOn: $showAutomatic) {
                    Text("Sessions automatiques (\(automatic))").font(.ui(11.5)).foregroundStyle(Theme.text2)
                }
                .toggleStyle(.checkbox)
                .help("Tâches planifiées et sessions sans message de ta part")
            }
            PillPicker(options: SortKey.allCases, selection: $sort, label: { $0.label })
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.ui(11)).foregroundStyle(Theme.text3)
            TextField("Filtrer", text: $model.search)
                .textFieldStyle(.plain)
                .font(.ui(12.5))
                .foregroundStyle(Theme.text)
                .frame(width: 130)
            if !model.search.isEmpty {
                Button { model.search = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.ui(11)).foregroundStyle(Theme.text3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer le filtre")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.fill1))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(model.search.isEmpty ? Theme.border : Theme.accentRim))
    }

    private var list: some View {
        let rows = filtered
        return Card(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Session").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Activité").frame(width: 92, alignment: .leading)
                    Text("Durée").frame(width: 62, alignment: .trailing)
                    Text("Msg").frame(width: 40, alignment: .trailing)
                    Text("Tokens").frame(width: 58, alignment: .trailing)
                    Text("Coût").frame(width: 56, alignment: .trailing)
                }
                .font(.ui(11, .semibold))
                .foregroundStyle(Theme.text3)
                .padding(.horizontal, 16)
                .frame(height: 32)
                Rectangle().fill(Theme.border).frame(height: 1)
                if rows.isEmpty {
                    EmptyHint(text: model.search.isEmpty ? "Aucune session." : "Aucune session ne correspond à « \(model.search) ».")
                        .padding()
                }
                LazyVStack(spacing: 0) {
                    ForEach(rows.prefix(visible)) { r in
                        SessionRowView(row: r, selected: model.selectedSession == r.id)
                            .onTapGesture { model.selectedSession = model.selectedSession == r.id ? nil : r.id }
                    }
                }
                if rows.count > visible {
                    Button("Afficher \(min(60, rows.count - visible)) de plus (\(rows.count - visible) restantes)") { visible += 60 }
                        .buttonStyle(.plain)
                        .font(.ui(12, .medium))
                        .foregroundStyle(Theme.text2)
                        .padding(14)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct FilterChip: View {
    var label: String
    var symbol: String?
    var selected: Bool
    var dot: Color? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot { Circle().fill(dot).frame(width: 6, height: 6) }
                if let symbol { Image(systemName: symbol).font(.ui(10)) }
                Text(label).font(.ui(12, .medium))
            }
            .foregroundStyle(selected ? Theme.text : Theme.text2)
            .padding(.horizontal, 10)
            .frame(height: 26)
            // The selected chip is marked by the shared glass bubble drawn behind the row.
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(selected ? .clear : Theme.fill1))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(selected ? .clear : Theme.border))
        }
        .buttonStyle(.plain)
    }
}

struct SessionRowView: View {
    @EnvironmentObject var model: AppModel
    var row: SessionRow
    var selected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: row.category.symbol)
                    .font(.ui(11))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.fill2))
                    .overlay(alignment: .bottomTrailing) {
                        Circle().fill(Theme.color(row.category)).frame(width: 7, height: 7).offset(x: 2, y: 2)
                    }
                    .help(row.category.label)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.ui(12.5, .medium))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Image(systemName: row.source.symbol).font(.ui(9))
                        Text(row.project)
                        if row.isScheduled { Text("· planifiée") }
                        if row.isArchived { Text("· archivée") }
                    }
                    .font(.ui(11.5))
                    .foregroundStyle(Theme.text3)
                    .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Fmt.dayShort(Fmt.ts(row.end)) + " " + Fmt.clock(Fmt.ts(row.end))).frame(width: 92, alignment: .leading)
                .help("Commencée le \(Fmt.full(row.startDate))")
            Text(Fmt.duration(row.seconds)).frame(width: 62, alignment: .trailing)
            Text(Fmt.int(row.prompts)).frame(width: 40, alignment: .trailing)
            Text(Fmt.compact(row.tokens)).frame(width: 58, alignment: .trailing)
            Text(row.cost > 0 ? Fmt.money(row.cost) : "–").frame(width: 56, alignment: .trailing)
        }
        .font(.ui(12))
        .foregroundStyle(Theme.text2)
        .monospacedDigit()
        .padding(.horizontal, 16)
        .frame(minHeight: 46)
        .background {
            if selected {
                Theme.accentSoft.overlay(alignment: .leading) { Theme.accent.frame(width: 2) }
            } else if hovering {
                Theme.fill1
            }
        }
        .overlay(alignment: .bottom) { Theme.border.frame(height: 1) }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu { SessionMenu(row: row) }
    }
}

struct SessionMenu: View {
    @EnvironmentObject var model: AppModel
    var row: SessionRow

    var body: some View {
        Menu("Changer de catégorie") {
            ForEach(Category.allCases) { c in
                Button {
                    model.setCategory(c, for: row.id)
                } label: {
                    Label(c.label, systemImage: row.category == c ? "checkmark" : c.symbol)
                }
            }
            Divider()
            Button("Revenir à la catégorie automatique") { model.setCategory(nil, for: row.id) }
        }
        Button("Filtrer sur le projet « \(row.project) »") { model.filter.project = row.project }
        Button("Copier le titre") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(row.title, forType: .string)
        }
        let cwd = model.dataset.sessions[row.index].cwd
        if FileManager.default.fileExists(atPath: cwd) {
            Button("Afficher le dossier dans le Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: cwd)
            }
        }
    }
}

struct SessionDetail: View {
    @EnvironmentObject var model: AppModel
    var row: SessionRow

    var body: some View {
        let ds = model.dataset
        let session = ds.sessions[row.index]
        let prompts = ds.prompts.filter { $0.session == row.index }
        let msgs = ds.messages.filter { $0.session == row.index }
        var toolCounts: [String: Int] = [:]
        for m in msgs { for t in m.tools { toolCounts[ToolNames.pretty(t.name), default: 0] += 1 } }
        let tools = StatsEngine.sortedCounts(toolCounts)
        var modelCounts: [String: Int] = [:]
        for m in msgs where m.model != "claude.ai" { modelCounts[Pricing.modelLabel(m.model), default: 0] += 1 }

        return Card(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text(row.title)
                        .font(.display(17))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button { model.selectedSession = nil } label: {
                        Image(systemName: "xmark").font(.ui(10, .bold)).foregroundStyle(Theme.text3)
                            .frame(width: 22, height: 22).background(Circle().fill(Theme.fill2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fermer le détail")
                }
                HStack(spacing: 6) {
                    Menu {
                        SessionMenu(row: row)
                    } label: {
                        CategoryChip(category: row.category)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    Tag(text: row.source.shortLabel, symbol: row.source.symbol)
                    if !session.model.isEmpty && session.model != "claude.ai" { Tag(text: Pricing.modelLabel(session.model), symbol: "cpu") }
                    if let b = row.branch { Tag(text: b, symbol: "arrow.triangle.branch") }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(Fmt.cap(Fmt.full(row.startDate)))
                    Text(session.cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .lineLimit(2).truncationMode(.middle)
                }
                .font(.ui(11))
                .foregroundStyle(Theme.text3)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                    MiniStat(value: Fmt.duration(row.seconds), label: "temps actif")
                    MiniStat(value: Fmt.int(row.prompts), label: "messages")
                    MiniStat(value: Fmt.int(row.messages), label: "réponses")
                    MiniStat(value: Fmt.compact(row.tokens), label: "tokens")
                    MiniStat(value: row.cost > 0 ? Fmt.money(row.cost) : "–", label: "équiv. API")
                    MiniStat(value: Fmt.int(row.toolCalls), label: "actions")
                    if row.linesAdded + row.linesRemoved > 0 {
                        MiniStat(value: "+\(Fmt.compact(row.linesAdded))", label: "lignes")
                        MiniStat(value: "−\(Fmt.compact(row.linesRemoved))", label: "supprimées")
                    }
                    if row.subagents > 0 { MiniStat(value: Fmt.int(row.subagents), label: "sous-agents") }
                }

                if !tools.isEmpty {
                    SectionLabel(text: "Outils les plus utilisés")
                    RankList(items: tools, limit: 5, numbered: false)
                }
                if !prompts.isEmpty {
                    SectionLabel(text: "Tes messages (\(prompts.count))")
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(prompts.prefix(25).enumerated()), id: \.offset) { _, p in
                            HStack(alignment: .top, spacing: 8) {
                                Text(Fmt.clock(Fmt.ts(p.ts)))
                                    .font(.mono(10))
                                    .foregroundStyle(Theme.text3)
                                    .frame(width: 36, alignment: .leading)
                                Text(p.kind == .command ? "\(p.command ?? "") \(p.text)" : (p.kind == .shell ? "! \(p.text)" : p.text))
                                    .font(p.kind == .human ? .ui(11.5) : .mono(11))
                                    .foregroundStyle(p.kind == .human ? Theme.text2 : Theme.text3)
                                    .lineLimit(3)
                            }
                        }
                        if prompts.count > 25 {
                            Text("… et \(prompts.count - 25) autres").font(.ui(11)).foregroundStyle(Theme.text3)
                        }
                    }
                }
            }
        }
    }
}
