import Foundation

struct Achievement: Identifiable, Sendable {
    var id: String
    var title: String
    var detail: String
    var symbol: String
    var current: Double
    var goal: Double
    var unit: String

    var progress: Double { goal > 0 ? min(1, current / goal) : 0 }
    var unlocked: Bool { current >= goal }
}

struct Persona: Sendable {
    var title: String
    var archetype: String
    var chronotype: String
    var symbol: String
    var summary: String
}

struct FunFact: Identifiable, Sendable {
    var id: String { title }
    var symbol: String
    var title: String
    var value: String
    var detail: String
}

enum Insights {

    // MARK: Persona

    static func persona(_ s: Stats) -> Persona {
        let top = s.categories.first?.category ?? .other
        let (arch, sym): (String, String) = {
            switch top {
            case .dev: return ("Architecte", "hammer")
            case .study: return ("Esprit studieux", "graduationcap")
            case .business: return ("Stratège", "chart.line.uptrend.xyaxis")
            case .writing: return ("Plume", "pencil.line")
            case .design: return ("Artiste", "paintbrush")
            case .data: return ("Analyste", "chart.bar.xaxis")
            case .research: return ("Esprit curieux", "binoculars")
            case .automation: return ("Alchimiste", "flask")
            case .personal, .other: return ("Touche-à-tout", "sparkles")
            }
        }()
        let h = s.peakHour
        let chrono: String
        switch h {
        case 5..<11: chrono = "du matin"
        case 11..<14: chrono = "de midi"
        case 14..<18: chrono = "de l'après-midi"
        case 18..<22: chrono = "du soir"
        default: chrono = "nocturne"
        }
        let title = chrono == "nocturne" ? "\(arch) nocturne" : "\(arch) \(chrono)"
        var summary = "Ton terrain de jeu favori : \(top.label.lowercased())"
        summary += ", avec un pic d'activité vers \(h) h"
        if s.weekendShare > 0.3 { summary += ", et le week-end ne t'arrête pas" }
        summary += "."
        return Persona(title: title, archetype: arch, chronotype: chrono, symbol: sym, summary: summary)
    }

    static func chronotypeDetail(_ s: Stats) -> (String, String) {
        switch s.peakHour {
        case 5..<11: return ("Lève-tôt", "Ton cerveau tourne à plein régime le matin, quand le café est encore chaud.")
        case 11..<14: return ("Pause-déj studieuse", "Ton pic tombe autour de midi.")
        case 14..<18: return ("Rythme de bureau", "Tu travailles surtout l'après-midi, aux heures classiques.")
        case 18..<22: return ("Oiseau du soir", "Tu t'y mets surtout en soirée, une fois la journée terminée.")
        default: return ("Oiseau de nuit", "Claude et toi, c'est surtout quand tout le monde dort.")
        }
    }

    // MARK: Achievements

    static func achievements(_ s: Stats, langs: Int) -> [Achievement] {
        let nightOwl = s.nightPrompts
        let marathon = (s.records.longestSession?.seconds ?? 0) / 3600
        let weekendDays = Double(s.weekdays.count == 7 ? s.weekdays[5].activeDays + s.weekdays[6].activeDays : 0)
        return [
            Achievement(id: "first", title: "Premier pas", detail: "Lancer ta première session", symbol: "figure.walk",
                        current: Double(s.sessionCount), goal: 1, unit: "session"),
            Achievement(id: "sessions100", title: "Centurion", detail: "100 sessions avec Claude", symbol: "shield.lefthalf.filled",
                        current: Double(s.sessionCount), goal: 100, unit: "sessions"),
            Achievement(id: "msg1000", title: "Moulin à paroles", detail: "Envoyer 1 000 messages", symbol: "bubble.left.and.text.bubble.right",
                        current: Double(s.promptCount), goal: 1000, unit: "messages"),
            Achievement(id: "night", title: "Noctambule", detail: "Écrire à Claude entre minuit et 5 h", symbol: "moon.stars",
                        current: Double(nightOwl), goal: 1, unit: "message de nuit"),
            Achievement(id: "nightowl", title: "Chouette insomniaque", detail: "50 messages entre minuit et 5 h", symbol: "moon.zzz",
                        current: Double(nightOwl), goal: 50, unit: "messages de nuit"),
            Achievement(id: "marathon", title: "Marathon", detail: "Une session active de plus de 4 h", symbol: "figure.run",
                        current: marathon, goal: 4, unit: "h"),
            Achievement(id: "streak7", title: "Série de feu", detail: "7 jours d'affilée avec Claude", symbol: "flame",
                        current: Double(s.streakLongest), goal: 7, unit: "jours"),
            Achievement(id: "streak30", title: "Inarrêtable", detail: "30 jours d'affilée", symbol: "bolt.heart",
                        current: Double(s.streakLongest), goal: 30, unit: "jours"),
            Achievement(id: "days60", title: "Fidélité", detail: "60 jours actifs au total", symbol: "calendar.badge.checkmark",
                        current: Double(s.activeDays), goal: 60, unit: "jours"),
            Achievement(id: "code10k", title: "Grand chantier", detail: "10 000 lignes écrites par Claude", symbol: "building.2",
                        current: Double(s.linesAdded), goal: 10_000, unit: "lignes"),
            Achievement(id: "code100k", title: "Cathédrale de code", detail: "100 000 lignes écrites", symbol: "building.columns",
                        current: Double(s.linesAdded), goal: 100_000, unit: "lignes"),
            Achievement(id: "projects10", title: "Globe-trotter", detail: "Travailler sur 10 projets différents", symbol: "map",
                        current: Double(s.projects.count), goal: 10, unit: "projets"),
            Achievement(id: "agents", title: "Chef d'orchestre", detail: "Lancer 50 sous-agents", symbol: "person.3.sequence",
                        current: Double(s.agentsLaunched), goal: 50, unit: "sous-agents"),
            Achievement(id: "workflows", title: "Maestro", detail: "Lancer 10 workflows multi-agents", symbol: "music.note.list",
                        current: Double(s.workflows), goal: 10, unit: "workflows"),
            Achievement(id: "tokens", title: "Millionnaire", detail: "1 million de tokens générés par Claude", symbol: "dollarsign.circle",
                        current: Double(s.tokens.output), goal: 1_000_000, unit: "tokens"),
            Achievement(id: "cache", title: "Mémoire d'éléphant", detail: "1 milliard de tokens relus depuis le cache", symbol: "memorychip",
                        current: Double(s.tokens.cacheRead), goal: 1_000_000_000, unit: "tokens"),
            Achievement(id: "polite", title: "Politesse exquise", detail: "Dire merci 50 fois", symbol: "heart",
                        current: Double(s.style.thanks), goal: 50, unit: "mercis"),
            Achievement(id: "curious", title: "Curiosité insatiable", detail: "Poser 500 questions", symbol: "questionmark.bubble",
                        current: Double(s.style.questions), goal: 500, unit: "questions"),
            Achievement(id: "polyglot", title: "Polyglotte", detail: "Parler à Claude dans 3 langues", symbol: "globe.europe.africa",
                        current: Double(langs), goal: 3, unit: "langues"),
            Achievement(id: "photo", title: "Photographe", detail: "Envoyer 50 images", symbol: "photo.on.rectangle",
                        current: Double(s.style.images), goal: 50, unit: "images"),
            Achievement(id: "weekend", title: "Week-end warrior", detail: "10 jours de week-end actifs", symbol: "sun.max",
                        current: weekendDays, goal: 10, unit: "jours"),
            Achievement(id: "web", title: "Archiviste du web", detail: "500 recherches web lancées par Claude", symbol: "network",
                        current: Double(s.webSearches), goal: 500, unit: "recherches"),
            Achievement(id: "bash", title: "Virtuose du terminal", detail: "10 000 commandes shell exécutées", symbol: "terminal",
                        current: Double(s.bashCommands), goal: 10_000, unit: "commandes"),
            Achievement(id: "limits", title: "Repousser les limites", detail: "Atteindre la limite d'usage 5 fois", symbol: "gauge.with.dots.needle.100percent",
                        current: Double(s.usageLimitHits), goal: 5, unit: "fois")
        ]
    }

    // MARK: Equivalences

    static func equivalences(_ s: Stats) -> [FunFact] {
        var out: [FunFact] = []
        let petitPrince = 14_000.0
        let harryPotter = 80_000.0
        if s.style.totalWords > 0 {
            let x = Double(s.style.totalWords) / petitPrince
            out.append(FunFact(symbol: "book.closed", title: "Tu as écrit",
                               value: "\(Fmt.int(s.style.totalWords)) mots",
                               detail: x >= 1 ? "Soit \(Fmt.dec(x)) fois Le Petit Prince." : "Soit \(Int(x * 100)) % du Petit Prince."))
        }
        if s.style.claudeWords > 0 {
            let x = Double(s.style.claudeWords) / harryPotter
            out.append(FunFact(symbol: "books.vertical", title: "Claude t'a répondu",
                               value: "\(Fmt.int(s.style.claudeWords)) mots",
                               detail: x >= 1 ? "L'équivalent de \(Fmt.dec(x)) tomes de Harry Potter." : "Soit \(Int(x * 100)) % d'un tome de Harry Potter."))
        }
        let read = s.tokens.input + s.tokens.cacheRead + s.tokens.cacheWrite
        if read > 0 {
            let bibles = Double(read) / 1_000_000
            out.append(FunFact(symbol: "eyeglasses", title: "Claude a relu",
                               value: "\(Fmt.compact(read)) tokens",
                               detail: "Comme lire \(Fmt.dec(bibles)) fois la Bible entière."))
        }
        if s.activeSeconds > 0 {
            let films = s.activeSeconds / 7200
            out.append(FunFact(symbol: "film", title: "Temps passé ensemble",
                               value: Fmt.duration(s.activeSeconds),
                               detail: "De quoi regarder \(Fmt.dec(films)) films de 2 h."))
        }
        if s.linesAdded > 0 {
            let apollo = Double(s.linesAdded) / 145_000
            out.append(FunFact(symbol: "airplane.departure", title: "Lignes écrites",
                               value: Fmt.int(s.linesAdded),
                               detail: apollo >= 1 ? "\(Fmt.dec(apollo)) fois le code qui a posé Apollo 11 sur la Lune."
                                   : (apollo >= 0.05 ? "\(Fmt.pct(apollo)) du code d'Apollo 11." : "Environ \(max(1, s.linesAdded / 50)) pages imprimées.")))
        }
        if s.cost > 0 {
            out.append(FunFact(symbol: "creditcard", title: "Équivalent API",
                               value: Fmt.money(s.cost),
                               detail: "Ce que ces tokens auraient coûté sans abonnement (estimation)."))
        }
        return out
    }

    // MARK: Did you know

    static func didYouKnow(_ s: Stats) -> [FunFact] {
        var out: [FunFact] = []
        out.append(FunFact(symbol: "textformat.abc", title: "Un token, c'est quoi ?",
                           value: Fmt.compact(s.tokens.output),
                           detail: "Les modèles lisent et écrivent en tokens, des morceaux de mots (≈ ¾ de mot en anglais, un peu moins en français). Claude t'a généré \(Fmt.compact(s.tokens.output)) tokens."))
        out.append(FunFact(symbol: "memorychip", title: "Le cache de prompt",
                           value: Fmt.pct(s.tokens.cacheHitRate),
                           detail: "\(Fmt.pct(s.tokens.cacheHitRate)) du contexte relu par Claude venait du cache : c'est environ 10× moins cher et beaucoup plus rapide que de tout relire."))
        if s.compactions > 0 {
            out.append(FunFact(symbol: "arrow.down.right.and.arrow.up.left", title: "Le compactage",
                               value: "\(s.compactions)×",
                               detail: "Quand la fenêtre de contexte est pleine, Claude résume la conversation pour continuer. C'est arrivé \(s.compactions) fois."))
        }
        if s.agentsLaunched > 0 {
            out.append(FunFact(symbol: "person.3", title: "Les sous-agents",
                               value: Fmt.int(s.agentsLaunched),
                               detail: "Claude a délégué \(Fmt.int(s.agentsLaunched)) tâches à des sous-agents, qui travaillent en parallèle avec leur propre contexte."))
        }
        if s.thinkingSeconds > 0 {
            out.append(FunFact(symbol: "brain", title: "La réflexion",
                               value: Fmt.duration(s.thinkingSeconds),
                               detail: "Avant de répondre, Claude peut réfléchir en interne. Cumulé, ça fait \(Fmt.duration(s.thinkingSeconds)) de réflexion."))
        }
        out.append(FunFact(symbol: "hammer", title: "Les outils",
                           value: Fmt.int(s.toolCalls),
                           detail: "Claude ne fait pas que parler : il lit des fichiers, lance des commandes, cherche sur le web. \(Fmt.int(s.toolCalls)) actions pour toi."))
        return out
    }
}
