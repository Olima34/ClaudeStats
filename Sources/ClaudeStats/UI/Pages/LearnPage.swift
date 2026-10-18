import SwiftUI

struct LearnPage: View {
    @EnvironmentObject var model: AppModel

    struct Entry: Identifiable {
        var id: String { term }
        var symbol: String
        var term: String
        var text: String
        var mine: String
    }

    var body: some View {
        let s = model.allTime
        let entries: [Entry] = [
            Entry(symbol: "textformat.abc", term: "Token",
                  text: "L'unité de base que lit et écrit un modèle : un morceau de mot. En français, 100 tokens font environ 60 à 70 mots. Les limites, la mémoire et le coût se comptent en tokens.",
                  mine: "Claude t'a généré \(Fmt.compact(s.tokens.output)) tokens et en a traité \(Fmt.compact(s.tokens.total)) au total."),
            Entry(symbol: "rectangle.stack", term: "Fenêtre de contexte",
                  text: "Tout ce que Claude « a sous les yeux » pendant une conversation : tes messages, ses réponses, les fichiers lus. Elle est grande mais pas infinie.",
                  mine: "Ta session la plus chargée a mobilisé \(Fmt.compact(s.records.busiestSession?.tokens ?? 0)) tokens."),
            Entry(symbol: "memorychip", term: "Cache de prompt",
                  text: "Le début d'une conversation ne change pas d'un message à l'autre. Claude le garde en cache pour le relire bien plus vite et environ 10 fois moins cher.",
                  mine: "\(Fmt.pct(s.tokens.cacheHitRate)) de ton contexte venait du cache."),
            Entry(symbol: "arrow.down.right.and.arrow.up.left", term: "Compactage",
                  text: "Quand la fenêtre de contexte est pleine, Claude résume ce qui s'est passé pour libérer de la place et continuer. Tu peux le déclencher avec /compact.",
                  mine: "C'est arrivé \(Fmt.plural(s.compactions, "fois", "fois")) dans tes sessions."),
            Entry(symbol: "hammer", term: "Outils",
                  text: "Claude peut agir : lire et modifier des fichiers, lancer des commandes, chercher sur le web, piloter un navigateur. Chaque action est un appel d'outil.",
                  mine: "\(Fmt.int(s.toolCalls)) actions, dont \(Fmt.int(s.bashCommands)) commandes shell."),
            Entry(symbol: "person.3", term: "Sous-agents",
                  text: "Pour une grosse tâche, Claude peut lancer d'autres instances qui travaillent en parallèle, chacune avec son propre contexte, puis lui rendent un résumé.",
                  mine: "\(Fmt.int(s.agentsLaunched)) sous-agents et \(Fmt.int(s.workflows)) workflows lancés."),
            Entry(symbol: "brain", term: "Réflexion (thinking)",
                  text: "Avant de répondre, Claude peut raisonner en interne, étape par étape. Plus l'effort est élevé, plus il réfléchit longtemps sur les problèmes difficiles.",
                  mine: "\(Fmt.duration(s.thinkingSeconds)) de réflexion cumulée."),
            Entry(symbol: "cpu", term: "Modèles",
                  text: "Opus est le plus puissant, Sonnet l'équilibre entre vitesse et intelligence, Haiku le plus rapide. Fable est la gamme la plus avancée. Chacun consomme ton quota différemment.",
                  mine: s.models.first.map { "Ton modèle principal : \($0.label) (\(Fmt.pct(Double($0.messages) / Double(max(1, s.models.reduce(0) { $0 + $1.messages })))) des réponses)." } ?? ""),
            Entry(symbol: "puzzlepiece.extension", term: "MCP & connecteurs",
                  text: "Le Model Context Protocol permet de brancher Claude sur d'autres services (navigateur, docs, calendrier…) qui lui fournissent de nouveaux outils.",
                  mine: s.mcpServers.isEmpty ? "Tu n'as pas encore utilisé de connecteur." : "Ton connecteur le plus utilisé : \(s.mcpServers[0].name)."),
            Entry(symbol: "gauge.with.dots.needle.50percent", term: "Limites d'usage",
                  text: "Ton forfait est mesuré sur une fenêtre glissante de 5 heures et sur la semaine. Les modèles puissants et les longues sessions les remplissent plus vite.",
                  mine: "Tu as vu le message « limite atteinte » \(Fmt.plural(s.usageLimitHits, "fois", "fois"))."),
        ]

        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Comprendre", subtitle: "Les notions clés derrière tes statistiques, illustrées avec tes propres chiffres.")
            TileGrid(columns: 2) {
                ForEach(entries) { e in
                    Card(padding: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: e.symbol)
                                    .font(.ui(14, .medium))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 32, height: 32)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.accent.opacity(0.13)))
                                Text(e.term).font(.serif(20)).foregroundStyle(Theme.text)
                            }
                            Text(e.text).font(.ui(12.5)).foregroundStyle(Theme.text2).fixedSize(horizontal: false, vertical: true)
                            if !e.mine.isEmpty {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "person.crop.circle").font(.ui(11)).foregroundStyle(Theme.accent)
                                    Text("Chez toi : ").font(.ui(12, .semibold)).foregroundStyle(Theme.accent)
                                        + Text(e.mine).font(.ui(12)).foregroundStyle(Theme.text)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.accent.opacity(0.08)))
                            }
                        }
                    }
                }
            }
            SectionLabel(text: "Comment ClaudeStats calcule tout ça")
            TileGrid(columns: 3) {
                Callout(symbol: "clock", title: "Temps passé",
                        text: "Les messages d'une session sont regroupés en périodes d'activité : une pause de plus de 15 minutes clôt la période. Le temps passé est la somme de ces périodes.")
                Callout(symbol: "creditcard", title: "Équivalent API",
                        text: "Une estimation de ce qu'auraient coûté tes tokens au tarif public de l'API, cache compris. Ton abonnement, lui, est forfaitaire.")
                Callout(symbol: "doc.on.doc", title: "Sessions dupliquées",
                        text: "Les sessions « forkées » recopient les messages de leur parente. ClaudeStats les dédoublonne pour ne rien compter deux fois.")
                Callout(symbol: "lock.shield", title: "Confidentialité",
                        text: "Tout est lu et calculé sur ton Mac, rien n'est envoyé en ligne. Le cache de l'app est dans ~/Library/Application Support/ClaudeStats.")
                Callout(symbol: "tray.full", title: "Sources",
                        text: "Transcripts Claude Code (~/.claude/projects), sessions Cowork et métadonnées de l'app Claude. Les chats claude.ai s'ajoutent via leur export officiel.")
                Callout(symbol: "wand.and.stars", title: "Catégories",
                        text: "Un classement par mots-clés (français, anglais, espagnol), dossier de travail et fichiers modifiés. Corrige-le d'un clic droit dans Sessions.")
            }
        }
    }
}
