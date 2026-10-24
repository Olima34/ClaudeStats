import SwiftUI
import Charts

struct ToolsPage: View {
    @EnvironmentObject var model: AppModel
    var s: Stats { model.stats }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Claude au travail", subtitle: "Ce que Claude fait pour toi en coulisses : outils, commandes, fichiers, modèles et tokens.")
            TileGrid(columns: 4) {
                StatTile(symbol: "hammer", value: Fmt.compact(s.toolCalls), label: "Actions effectuées",
                         detail: "\(Fmt.dec(Double(s.toolCalls) / Double(max(1, s.promptCount)))) par message envoyé")
                StatTile(symbol: "terminal", value: Fmt.compact(s.bashCommands), label: "Commandes shell",
                         detail: s.shellVerbs.first.map { "La plus fréquente : \($0.name)" })
                StatTile(symbol: "doc.on.doc", value: Fmt.int(s.filesTouched), label: "Fichiers modifiés",
                         detail: "\(Fmt.compact(s.filesRead)) lectures de fichiers")
                StatTile(symbol: "plus.forwardslash.minus", value: "+\(Fmt.compact(s.linesAdded))", label: "Lignes ajoutées",
                         detail: "−\(Fmt.compact(s.linesRemoved)) supprimées")
                StatTile(symbol: "globe", value: Fmt.int(s.webSearches), label: "Recherches web",
                         detail: "\(Fmt.int(s.webFetches)) pages lues")
                StatTile(symbol: "person.3", value: Fmt.int(s.agentsLaunched), label: "Sous-agents lancés",
                         detail: "\(Fmt.int(s.workflows)) workflows multi-agents")
                StatTile(symbol: "brain", value: Fmt.duration(s.thinkingSeconds), label: "Temps de réflexion",
                         detail: "Raisonnement interne avant de répondre")
                StatTile(symbol: "arrow.down.right.and.arrow.up.left", value: Fmt.int(s.compactions), label: "Compactages",
                         detail: "Contexte résumé pour continuer")
            }

            HStack(alignment: .top, spacing: 18) {
                Panel(title: "Outils favoris de Claude", subtitle: "Les 12 outils les plus appelés", symbol: "wrench.and.screwdriver") {
                    RankList(items: s.tools.map { NamedCount(name: ToolNames.pretty($0.name), count: $0.count) }, limit: 12, highlightLeader: true)
                }
                .frame(maxWidth: .infinity)
                Panel(title: "Par famille", subtitle: "À quoi servent ces actions", symbol: "square.stack.3d.up") {
                    Donut(items: s.toolFamilies.prefix(8).enumerated().map { i, f in
                        DonutItem(id: f.name, label: f.name, value: Double(f.count), color: Theme.color(index: i))
                    }, centerValue: Fmt.compact(s.toolCalls), centerLabel: "actions", valueText: { Fmt.compact($0) }, size: 140)
                }
                .frame(width: 440)
            }

            HStack(alignment: .top, spacing: 18) {
                Panel(title: "Commandes shell", subtitle: "Les programmes que Claude lance le plus", symbol: "terminal") {
                    RankList(items: s.shellVerbs, limit: 10)
                }
                Panel(title: "Langages écrits", subtitle: "Lignes ajoutées par type de fichier", symbol: "chevron.left.forwardslash.chevron.right") {
                    RankList(items: s.codeLanguages, limit: 10,
                             valueText: { "\(Fmt.compact($0.count)) lignes" })
                }
            }

            HStack(alignment: .top, spacing: 18) {
                Panel(title: "Fichiers les plus retouchés", subtitle: "Nombre de modifications", symbol: "doc.badge.ellipsis") {
                    RankList(items: s.topFiles, limit: 10,
                             nameText: { f in
                                 let url = URL(fileURLWithPath: f.name)
                                 return url.deletingLastPathComponent().lastPathComponent + "/" + url.lastPathComponent
                             })
                }
                VStack(spacing: 18) {
                    Panel(title: "Sous-agents", subtitle: "Types d'agents délégués", symbol: "person.3.sequence") {
                        RankList(items: s.subagentTypes, limit: 5)
                    }
                    Panel(title: "Sites consultés", subtitle: "Domaines lus par Claude", symbol: "network") {
                        RankList(items: s.webDomains, limit: 5)
                    }
                }
            }

            SectionLabel(text: "Modèles & tokens")
            HStack(alignment: .top, spacing: 18) {
                Panel(title: "Modèles utilisés", subtitle: "Part des réponses par modèle", symbol: "cpu") {
                    Donut(items: s.models.prefix(7).enumerated().map { i, m in
                        DonutItem(id: m.label, label: m.label, value: Double(m.messages), color: Theme.color(index: i))
                    }, centerValue: Fmt.compact(s.models.reduce(0) { $0 + $1.messages }), centerLabel: "réponses",
                          valueText: { Fmt.compact($0) }, size: 140)
                }
                .frame(maxWidth: .infinity)
                Panel(title: "Évolution des modèles", subtitle: "Réponses par semaine", symbol: "chart.bar.doc.horizontal") {
                    let labels = s.models.prefix(7).map(\.label)
                    Chart(s.modelWeeks.filter { labels.contains($0.label) }) { w in
                        BarMark(x: .value("Semaine", w.week, unit: .weekOfYear), y: .value("Réponses", w.messages))
                            .foregroundStyle(by: .value("Modèle", w.label))
                            .cornerRadius(2)
                    }
                    .chartForegroundStyleScale(domain: labels, range: labels.indices.map { Theme.color(index: $0) })
                    .chartLegend(position: .bottom, alignment: .leading)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.ui(11)).foregroundStyle(Theme.text3)
                        }
                    }
                    .chartYAxisStyle()
                    .frame(height: 190)
                }
                .frame(maxWidth: .infinity)
            }
            tokens
            if !s.skills.isEmpty || !s.mcpServers.isEmpty {
                HStack(alignment: .top, spacing: 18) {
                    Panel(title: "Skills utilisés", subtitle: "Compétences chargées par Claude", symbol: "sparkles") {
                        RankList(items: s.skills, limit: 8)
                    }
                    Panel(title: "Connecteurs & MCP", subtitle: "Serveurs d'outils externes appelés", symbol: "puzzlepiece.extension") {
                        RankList(items: s.mcpServers, limit: 8)
                    }
                }
            }
        }
    }

    private var tokens: some View {
        let t = s.tokens
        let parts: [(String, Int, Color, String)] = [
            ("Lecture du cache", t.cacheRead, Theme.chartNeutral, "Contexte déjà connu, relu à prix réduit"),
            ("Écriture du cache", t.cacheWrite, Theme.palette[1], "Nouveau contexte mis en cache"),
            ("Entrée", t.input, Theme.palette[3], "Tokens envoyés sans cache"),
            ("Sortie", t.output, Theme.accent, "Ce que Claude a écrit (texte, code, réflexion)")
        ]
        let total = max(1, t.total)
        return Panel(title: "Anatomie de tes tokens", subtitle: "\(Fmt.compact(t.total)) tokens traités, \(Fmt.money(s.cost)) en équivalent API", symbol: "textformat.abc") {
            VStack(alignment: .leading, spacing: 14) {
                GeometryReader { g in
                    HStack(spacing: 2) {
                        ForEach(parts, id: \.0) { p in
                            Rectangle().fill(p.2)
                                .frame(width: max(p.1 > 0 ? 3 : 0, g.size.width * CGFloat(p.1) / CGFloat(total)))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .frame(height: 10)
                HStack(alignment: .top, spacing: 18) {
                    ForEach(parts, id: \.0) { p in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(p.2).frame(width: 8, height: 8)
                                Text(p.0).font(.ui(12)).foregroundStyle(Theme.text2)
                            }
                            Text(Fmt.compact(p.1)).font(.display(22)).foregroundStyle(Theme.text).monospacedDigit()
                            Text(p.3).font(.ui(12)).foregroundStyle(Theme.text3).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Callout(symbol: "memorychip", title: "Pourquoi autant de cache ?",
                        text: "À chaque message, Claude relit toute la conversation. Grâce au cache de prompt, \(Fmt.pct(t.cacheHitRate)) de cette relecture vient d'un contexte déjà mémorisé, facturé environ 10 fois moins cher. Sans cache, tes sessions coûteraient bien plus cher et seraient plus lentes.")
            }
        }
    }
}
