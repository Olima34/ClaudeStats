import SwiftUI
import Charts

struct StylePage: View {
    @EnvironmentObject var model: AppModel
    var s: Stats { model.stats }
    var st: StyleStats { model.stats.style }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Ton style", subtitle: "Comment tu parles à Claude : tes mots, ta langue, ta longueur de message et ta politesse.")
            TileGrid(columns: 4) {
                StatTile(symbol: "character.cursor.ibeam", value: Fmt.compact(st.totalWords), label: "Mots écrits",
                         detail: "\(Fmt.dec(st.avgWords)) mots par message (médiane \(Fmt.int(st.medianWords)))")
                StatTile(symbol: "questionmark.bubble", value: Fmt.int(st.questions), label: "Questions posées",
                         detail: "\(Fmt.pct(Double(st.questions) / Double(max(1, st.humanPrompts)))) de tes messages")
                StatTile(symbol: "heart", value: Fmt.int(st.thanks), label: "Mercis",
                         detail: "\(Fmt.int(st.please)) « s'il te plaît » · \(Fmt.int(st.greetings)) bonjours")
                StatTile(symbol: "bolt", value: Fmt.int(st.shortReplies), label: "Réponses express",
                         detail: "Messages de 3 mots ou moins (« ok », « continue »…)")
                StatTile(symbol: "photo", value: Fmt.int(st.images), label: "Images envoyées",
                         detail: "Captures d'écran, photos, maquettes")
                StatTile(symbol: "command", value: Fmt.int(st.commandCount), label: "Commandes slash",
                         detail: st.commands.first.map { "Favorite : \($0.name)" })
                StatTile(symbol: "hand.raised", value: Fmt.int(s.interruptions), label: "Interruptions",
                         detail: "Fois où tu as arrêté Claude en plein élan")
                StatTile(symbol: "exclamationmark.bubble", value: Fmt.int(st.exclamations), label: "Exclamations",
                         detail: "Messages avec un « ! »")
            }
            Panel(title: "Tes mots les plus fréquents", subtitle: "Hors mots courants (le, de, pour…), sur l'ensemble de tes messages", symbol: "text.quote") {
                if st.words.isEmpty {
                    EmptyHint(text: "Pas encore assez de messages.")
                } else {
                    WordCloud(words: st.words, limit: 55)
                        .padding(.vertical, 8)
                }
            }
            HStack(alignment: .top, spacing: 18) {
                Panel(title: "Langues", subtitle: "Langue détectée dans tes messages", symbol: "globe.europe.africa") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(st.languages) { l in
                            let lang = Lang.allCases.first { $0.label == l.name } ?? .other
                            HStack(spacing: 10) {
                                Text(lang.flag).font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(l.name).font(.ui(12.5, .medium)).foregroundStyle(Theme.text)
                                        Spacer()
                                        Text("\(Fmt.pct(l.value)) · \(Fmt.int(l.count))").font(.ui(11.5)).foregroundStyle(Theme.text2)
                                    }
                                    GeometryReader { g in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Theme.track)
                                            Capsule().fill(l.id == st.languages.first?.id ? Theme.accent : Theme.chartNeutral).frame(width: g.size.width * l.value)
                                        }
                                    }
                                    .frame(height: 4)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                Panel(title: "Longueur de tes messages", subtitle: "Nombre de mots par message", symbol: "ruler") {
                    Chart(st.lengthBuckets) { b in
                        BarMark(x: .value("Mots", b.name), y: .value("Messages", b.count), width: .ratio(0.62))
                            .foregroundStyle(Theme.chartNeutral)
                            .cornerRadius(3)
                            .annotation(position: .top) {
                                Text(b.count > 0 ? "\(b.count)" : "").font(.ui(10)).foregroundStyle(Theme.text3)
                            }
                    }
                    .chartXAxisStyle()
                    .chartYAxis(.hidden)
                    .frame(height: 170)
                }
                .frame(maxWidth: .infinity)
            }
            HStack(alignment: .top, spacing: 18) {
                Panel(title: "Comment tu commences", subtitle: "Le premier mot de tes messages", symbol: "text.append") {
                    RankList(items: st.topOpeners, limit: 8,
                             nameText: { "« \($0.name) »" })
                }
                Panel(title: "Commandes slash", subtitle: "Les raccourcis que tu tapes", symbol: "command") {
                    if st.commands.isEmpty {
                        EmptyHint(text: "Tu n'utilises pas encore de commandes slash (/compact, /model…).")
                    } else {
                        RankList(items: st.commands, limit: 8)
                    }
                }
            }
            HStack(alignment: .top, spacing: 18) {
                politeness
                    .frame(maxWidth: .infinity)
                if let p = s.records.longestPrompt {
                    Panel(title: "Ton plus long message", subtitle: "\(Fmt.int(p.words)) mots · \(Fmt.day(Fmt.ts(p.ts)))", symbol: "scroll") {
                        Text(Dataset.snippet(p.text, 420))
                            .font(.ui(13.5))
                            .italic()
                            .foregroundStyle(Theme.text2)
                            .lineSpacing(3)
                        Text("Dans « \(p.session) »").font(.ui(11)).foregroundStyle(Theme.text3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Card(padding: 20) {
                HStack(spacing: 30) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Toi").font(.ui(11.5)).foregroundStyle(Theme.text3)
                        Text("\(Fmt.compact(st.totalWords)) mots").font(.display(26)).foregroundStyle(Theme.text)
                    }
                    GeometryReader { g in
                        let total = Double(max(1, st.totalWords + st.claudeWords))
                        HStack(spacing: 3) {
                            Capsule().fill(Theme.chartNeutral).frame(width: max(6, g.size.width * Double(st.totalWords) / total))
                            Capsule().fill(Theme.accent)
                        }
                    }
                    .frame(height: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Claude").font(.ui(11.5)).foregroundStyle(Theme.text3)
                        Text("\(Fmt.compact(st.claudeWords)) mots").font(.display(26)).foregroundStyle(Theme.text)
                    }
                }
                Text(st.totalWords > 0 ? "Pour chaque mot que tu écris, Claude t'en répond environ \(Fmt.dec(Double(st.claudeWords) / Double(max(1, st.totalWords))))." : "")
                    .font(.ui(12)).foregroundStyle(Theme.text2)
                    .padding(.top, 8)
            }
        }
    }

    private var politeness: some View {
        let rate = Double(st.thanks + st.please) / Double(max(1, st.humanPrompts))
        let level: (String, String) = {
            switch rate {
            case 0.25...: return ("Diplomate hors pair", "Claude se sent très apprécié.")
            case 0.1..<0.25: return ("Courtoisie exemplaire", "Un merci par-ci, un s'il te plaît par-là.")
            case 0.03..<0.1: return ("Politesse de rigueur", "L’essentiel est là.")
            default: return ("Droit au but", "Pas de chichis, que de l'efficacité.")
            }
        }()
        return Panel(title: "Politesse-o-mètre", subtitle: "Mercis et s'il te plaît par message", symbol: "heart.text.square") {
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: min(1, rate / 0.3), lineWidth: 9)
                        .frame(width: 92, height: 92)
                    Text(Fmt.pct(rate)).font(.display(20)).foregroundStyle(Theme.text)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(level.0).font(.display(21)).foregroundStyle(Theme.text)
                    Text(level.1).font(.ui(12)).foregroundStyle(Theme.text2)
                    Text("\(Fmt.int(st.thanks)) mercis · \(Fmt.int(st.please)) s'il te plaît · \(Fmt.int(st.greetings)) salutations")
                        .font(.ui(11)).foregroundStyle(Theme.text3)
                }
            }
        }
    }
}
