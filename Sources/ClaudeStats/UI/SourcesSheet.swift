import SwiftUI

struct SourcesSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let ds = model.dataset
        let bySource = Dictionary(grouping: ds.sessions, by: \.source).mapValues(\.count)
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                ClaudeSpark(size: 22)
                Text("Sources de données").font(.serif(24)).foregroundStyle(Theme.text)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.ui(11, .bold)).foregroundStyle(Theme.text2)
                        .frame(width: 26, height: 26).background(Circle().fill(Theme.track))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            Text("ClaudeStats lit uniquement des fichiers locaux. Rien n'est envoyé en ligne.")
                .font(.ui(12.5)).foregroundStyle(Theme.text2)

            VStack(spacing: 10) {
                SourceRow(symbol: "chevron.left.forwardslash.chevron.right", title: "Claude Code (app & terminal)",
                          path: "~/.claude/projects",
                          count: (bySource[.desktop] ?? 0) + (bySource[.cli] ?? 0))
                SourceRow(symbol: "person.2", title: "Cowork",
                          path: "~/Library/Application Support/Claude/local-agent-mode-sessions",
                          count: bySource[.cowork] ?? 0)
                SourceRow(symbol: "gauge.with.dots.needle.50percent", title: "Historique des limites d'usage",
                          path: "~/Library/Application Support/Claude/plan-usage-history.json",
                          count: ds.usage.count, unit: "relevés")
                SourceRow(symbol: "bubble.left.and.bubble.right", title: "Chats claude.ai (import)",
                          path: ds.chatCount > 0 ? "Export importé" : "Aucun export importé",
                          count: bySource[.chat] ?? 0)
            }

            Card(padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ajouter tes conversations claude.ai").font(.ui(13.5, .semibold)).foregroundStyle(Theme.text)
                    Text("Les conversations du chat sont stockées sur les serveurs d'Anthropic, pas sur ton Mac. Pour les inclure : sur claude.ai, va dans Réglages › Confidentialité › Exporter les données. Tu recevras un lien par mail ; importe ensuite l'archive ici.")
                        .font(.ui(12)).foregroundStyle(Theme.text2).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Importer un export…") { model.importClaudeAIExport() }
                            .buttonStyle(SoftButtonStyle(prominent: true))
                        if ds.chatCount > 0 {
                            Button("Retirer les chats importés") { model.removeImportedChats() }
                                .buttonStyle(SoftButtonStyle())
                        }
                    }
                }
            }

            HStack {
                Text("\(Fmt.int(ds.fileCount)) fichiers · \(ByteCountFormatter.string(fromByteCount: ds.totalBytes, countStyle: .file)) · \(model.loadInfo)")
                    .font(.ui(11)).foregroundStyle(Theme.text3)
                Spacer()
                Button("Tout relire depuis zéro") { model.rebuildCache(); dismiss() }
                    .buttonStyle(SoftButtonStyle())
            }
        }
        .padding(26)
        .frame(width: 620)
        .background(Theme.bg)
    }
}

struct SourceRow: View {
    var symbol: String
    var title: String
    var path: String
    var count: Int
    var unit = "sessions"

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.ui(13))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ui(13, .medium)).foregroundStyle(Theme.text)
                Text(path).font(.mono(10.5)).foregroundStyle(Theme.text3).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text("\(Fmt.int(count)) \(unit)").font(.ui(12)).foregroundStyle(count > 0 ? Theme.text2 : Theme.text3)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border))
    }
}

/// Compact panel shown from the menu bar.
struct MenuBarPanel: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let ds = model.dataset
        let today = StatsEngine.todayIndex()
        let t = model.allTime.days.first { $0.day == today }
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ClaudeSpark(size: 18)
                Text("Aujourd'hui avec Claude").font(.serif(16)).foregroundStyle(Theme.text)
                Spacer()
                PixelMascot(pixel: 3)
            }
            if model.isLoading {
                ProgressView().controlSize(.small)
            } else {
                HStack(spacing: 18) {
                    MiniStat(value: Fmt.int(t?.prompts ?? 0), label: "messages")
                    MiniStat(value: Fmt.hours(t?.seconds ?? 0), label: "d'activité")
                    MiniStat(value: "\(model.allTime.streakCurrent) j", label: "série")
                }
                if let last = ds.sessions.max(by: { $0.end < $1.end }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dernière session").font(.ui(10.5)).foregroundStyle(Theme.text3)
                        Text(last.title).font(.ui(12)).foregroundStyle(Theme.text).lineLimit(2)
                    }
                }
            }
            Divider()
            HStack {
                Button("Ouvrir ClaudeStats") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(SoftButtonStyle(prominent: true))
                Button("Rafraîchir") { model.load(force: false) }
                    .buttonStyle(SoftButtonStyle())
                Spacer()
                Button("Quitter") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.ui(11.5))
                    .foregroundStyle(Theme.text3)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(Theme.bg)
    }
}
