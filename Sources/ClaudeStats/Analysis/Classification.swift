import Foundation

// MARK: - Categories

enum Category: String, CaseIterable, Codable, Identifiable, Sendable {
    case dev, study, business, writing, design, data, research, automation, personal, other

    var id: String { rawValue }

    /// Position in `allCases`, used to break ties the same way on every launch.
    var rank: Int { Category.allCases.firstIndex(of: self) ?? 0 }

    var label: String {
        switch self {
        case .dev: return "Développement"
        case .study: return "Études & cours"
        case .business: return "Finance & business"
        case .writing: return "Rédaction & documents"
        case .design: return "Design & créatif"
        case .data: return "Données & analyse"
        case .research: return "Recherche & questions"
        case .automation: return "Automatisation & outils"
        case .personal: return "Vie perso"
        case .other: return "Divers"
        }
    }

    var symbol: String {
        switch self {
        case .dev: return "chevron.left.forwardslash.chevron.right"
        case .study: return "graduationcap"
        case .business: return "chart.line.uptrend.xyaxis"
        case .writing: return "doc.text"
        case .design: return "paintpalette"
        case .data: return "tablecells"
        case .research: return "magnifyingglass"
        case .automation: return "gearshape.2"
        case .personal: return "house"
        case .other: return "sparkles"
        }
    }

    var blurb: String {
        switch self {
        case .dev: return "Apps, sites, scripts, bugs et déploiements."
        case .study: return "Cours, examens, exercices et candidatures."
        case .business: return "Finance, patrimoine, clients et stratégie."
        case .writing: return "Mails, rapports, présentations et traductions."
        case .design: return "Interfaces, logos, visuels et direction artistique."
        case .data: return "Excel, tableaux de bord, statistiques et graphiques."
        case .research: return "Recherches web, comparatifs et explications."
        case .automation: return "Workflows, tâches planifiées, plugins et configuration."
        case .personal: return "Voyages, famille, maison et loisirs."
        case .other: return "Tout ce qui ne rentre dans aucune case."
        }
    }
}

// MARK: - Normalisation

enum Words {
    /// Lowercased, accent-free tokens made of letters and digits.
    static func tokens(_ s: String, limit: Int = .max) -> [String] {
        var out: [String] = []
        var cur = ""
        cur.reserveCapacity(16)
        for ch in s.lowercased() {
            if ch.isLetter || ch.isNumber {
                cur.append(ch)
            } else if !cur.isEmpty {
                out.append(cur)
                cur = ""
                if out.count >= limit { break }
            }
        }
        if !cur.isEmpty && out.count < limit { out.append(cur) }
        return out
    }

    /// Drops file paths, URLs and @mentions so they do not pollute word statistics.
    static func withoutPaths(_ s: String) -> String {
        guard s.contains("/") || s.contains("@") || s.contains("\\") else { return s }
        return s.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .filter { w in !(w.contains("/") || w.hasPrefix("@") || w.contains("\\") || w.hasPrefix("http")) }
            .joined(separator: " ")
    }

    static func fold(_ w: String) -> String {
        w.folding(options: [.diacriticInsensitive], locale: nil)
    }
}

// MARK: - Categorizer

enum Categorizer {
    /// Keywords (accent-free). A trailing `*` means "starts with".
    private static let keywords: [Category: [String]] = [
        .dev: ["code*", "coder", "coding", "develop*", "programm*", "app", "apps", "appli*", "bug*", "debug*",
               "fonction*", "function*", "swift*", "xcode", "python", "javascript", "typescript", "react", "nextjs",
               "node", "html", "css", "api", "apis", "backend", "frontend", "serveur*", "server*", "deploy*",
               "deploi*", "github", "git", "commit*", "compil*", "build", "sqlite", "database", "sql", "site",
               "sites", "website", "ios", "macos", "iphone", "electron", "starlette", "docker", "npm", "refacto*",
               "framework*", "endpoint*", "json", "crash*", "vercel", "firebase", "supabase", "login", "authentif*",
               "bouton*", "composant*", "component*", "terminal", "localhost", "jinja", "django", "flask",
               "fastapi", "kotlin", "java", "rust", "repo", "branche*", "feature*", "implement*", "codebase",
               "webapp", "web", "ovh", "nginx", "domaine", "hebergement", "https", "dns", "simulateur", "widget*"],
        .study: ["cours", "examen*", "exam", "exams", "partiel*", "td", "tp", "devoir*", "exercice*", "revision*",
                 "reviser", "universit*", "fac", "master*", "licence", "l3", "l2", "etudiant*", "etudes",
                 "professeur*", "prof", "profs", "memoire", "these", "candidature*", "econometr*", "macroeco*",
                 "microeco*", "theorem*", "demonstr*", "equation*", "math*", "lecon*", "apprendre", "quiz*",
                 "flashcard*", "fiche", "fiches", "chapitre*", "erasmus", "ects", "semestre*", "oral", "evaluation*",
                 "asignatura*", "ejercicio*", "clase*", "universidad", "spanish", "espagnol", "anglais",
                 "vocabulaire", "grammaire", "dissertation*", "enonce*", "qcm", "uv", "syllabus", "moodle",
                 "teoria", "estadistic*", "parcial*", "tarea*", "dialogue*"],
        .business: ["financ*", "invest*", "portefeuille*", "bourse*", "patrimoin*", "placement*", "epargne*",
                    "assurance*", "fiscal*", "impot*", "credit*", "banque*", "bancaire*", "trading", "trader*",
                    "crypto*", "etf", "etfs", "obligation*", "dividende*", "rendement*", "valorisation*", "bilan*",
                    "comptab*", "tresorerie*", "budget*", "client*", "prospect*", "commercial*", "vente*",
                    "broker*", "courtier*", "devis", "factur*", "entreprise*", "startup*", "business", "strategi*",
                    "marketing", "pitch*", "kpi", "kpis", "revenu*", "marge*", "rentab*", "cgp", "actionnaire*",
                    "fonds", "partenaire*", "contrat*", "juridique*", "notaire*", "immobilier*", "succession*",
                    "donation*", "association", "sponsor*", "levee", "concurren*", "offre*"],
        .writing: ["redig*", "redac*", "ecri*", "lettre*", "mail", "mails", "email*", "courriel*", "texte*",
                   "article*", "rapport*", "document*", "docx", "word", "pdf", "pptx", "powerpoint", "presentation*",
                   "diapo*", "slide*", "resum*", "synthes*", "tradu*", "translat*", "cv", "motivation", "relis",
                   "relire", "orthograph*", "reformul*", "paragraph*", "introduction", "conclusion", "linkedin",
                   "publication*", "newsletter*", "discours", "brouillon*", "deck", "compte", "plaquette*"],
        .design: ["design*", "logo*", "couleur*", "palette*", "maquette*", "mockup*", "figma", "ui", "ux",
                  "joli*", "jolie*", "beau", "belle", "esthet*", "police*", "typo*", "icone*", "illustration*",
                  "visuel*", "animation*", "theme*", "charte", "banniere*", "affiche*", "flyer*", "video*",
                  "photo*", "dessin*", "graphis*", "vibe", "style", "interface*", "responsive", "artistique",
                  "ergonom*", "screen", "capture*"],
        .data: ["excel", "xlsx", "xlsm", "xls", "tableur*", "donnee*", "data", "dataset*", "csv", "graphique*",
                "chart*", "dashboard*", "analys*", "statisti*", "stats", "regression*", "stata", "rstudio",
                "pandas", "indicateur*", "visualis*", "courbe*", "histogram*", "moyenne*", "correlation*",
                "echantillon*", "enquete*", "sondage*", "questionnaire*", "tableau", "tableaux", "calcul*",
                "modelis*", "prevision*", "pivot", "macro", "macros", "vba", "inventaire*", "base"],
        .research: ["recherch*", "cherch*", "trouv*", "compar*", "veille", "source", "sources", "benchmark*",
                    "actualit*", "news", "renseign*", "meilleur*", "avis", "explique*", "explication*",
                    "pourquoi", "comment", "difference*", "definition*", "signifie", "existe"],
        .automation: ["automatis*", "automat*", "workflow*", "cron", "planifi*", "tache*", "script*", "raccourci*",
                      "shortcut*", "mcp", "plugin*", "skill*", "agent*", "claude", "config*", "install*", "setup",
                      "parametr*", "integration*", "notion", "asana", "zapier", "n8n", "bot", "bots", "scrap*",
                      "routine*", "hook*", "synchronis*", "sync", "backup*", "sauvegard*", "connecteur*"],
        .personal: ["voyage*", "vacance*", "recette*", "cuisine*", "sport*", "sante", "medecin*", "famille*",
                    "familial*", "maison*", "appartement*", "logement*", "achat*", "acheter", "cadeau*",
                    "anniversaire*", "film*", "musique*", "jeu", "jeux", "loisir*", "agenda", "demenag*", "perso",
                    "amis", "mariage", "soiree*", "restaurant*", "velo", "billet*", "hotel*", "permis"]
    ]

    private static let lookup: (exact: [String: [Category]], stems: [String: [Category]]) = {
        var exact: [String: [Category]] = [:]
        var stems: [String: [Category]] = [:]
        for (cat, list) in keywords {
            for k in list {
                if k.hasSuffix("*") {
                    stems[String(k.dropLast()), default: []].append(cat)
                } else {
                    exact[k, default: []].append(cat)
                }
            }
        }
        return (exact, stems)
    }()

    static func score(_ text: String, weight: Double, into s: inout [Category: Double], wordLimit: Int = 400) {
        let toks = Words.tokens(text, limit: wordLimit)
        for t0 in toks {
            let t = Words.fold(t0)
            if let cats = lookup.exact[t] {
                for c in cats { s[c, default: 0] += weight }
                continue
            }
            let n = t.count
            guard n >= 3 else { continue }
            var matched = false
            for L in stride(from: min(n, 12), through: 3, by: -1) {
                if let cats = lookup.stems[String(t.prefix(L))] {
                    for c in cats { s[c, default: 0] += weight }
                    matched = true
                    break
                }
            }
            _ = matched
        }
    }

    static func pathSignals(_ cwd: String, into s: inout [Category: Double]) {
        let p = Words.fold(cwd.lowercased())
        if p.contains("/developer/") || p.contains("xcode") || p.contains("/github/") || p.contains("/code/")
            || p.contains("/projects/") || p.contains("/repos/") || p.contains("/src/") { s[.dev, default: 0] += 7 }
        if p.contains("etudes") || p.contains("/cours") || p.contains("/l1") || p.contains("/l2") || p.contains("/l3")
            || p.contains("master") || p.contains("econom") || p.contains("/math") || p.contains("universit")
            || p.contains("school") || p.contains("college") || p.contains("/study") { s[.study, default: 0] += 7 }
        if p.contains("finance") || p.contains("business") || p.contains("entreprise") || p.contains("client")
            || p.contains("compta") || p.contains("patrimoine") || p.contains("invest") { s[.business, default: 0] += 5 }
        if p.contains("candidature") || p.contains("carriere") || p.contains("career") { s[.business, default: 0] += 3 }
        if p.contains("famille") || p.contains("family") || p.contains("perso") { s[.personal, default: 0] += 3 }
    }

    static func toolSignals(tools: [String: Int], extensions: [String: Int], into s: inout [Category: Double]) {
        let codeExt: Set<String> = ["swift", "py", "js", "ts", "tsx", "jsx", "html", "css", "json", "go", "rs",
                                    "java", "kt", "c", "cpp", "h", "m", "sh", "rb", "php", "vue", "sql", "yml", "yaml", "toml"]
        var code = 0, sheets = 0, docs = 0
        for (ext, n) in extensions {
            if codeExt.contains(ext) { code += n }
            if ["xlsx", "xlsm", "csv", "xls"].contains(ext) { sheets += n }
            if ["docx", "pdf", "pptx", "md", "txt", "tex"].contains(ext) { docs += n }
        }
        s[.dev, default: 0] += min(8, Double(code) * 0.25)
        s[.data, default: 0] += min(6, Double(sheets) * 0.5)
        s[.writing, default: 0] += min(5, Double(docs) * 0.3)
        let web = (tools["WebSearch"] ?? 0) + (tools["WebFetch"] ?? 0)
        s[.research, default: 0] += min(5, Double(web) * 0.15)
    }

    static func classify(title: String?, prompts: [String], cwd: String, tools: [String: Int], extensions: [String: Int]) -> Category {
        var s: [Category: Double] = [:]
        if let title { score(title, weight: 3, into: &s) }
        for (i, p) in prompts.prefix(60).enumerated() {
            score(p, weight: i == 0 ? 2 : 1, into: &s, wordLimit: i == 0 ? 600 : 250)
        }
        pathSignals(cwd, into: &s)
        toolSignals(tools: tools, extensions: extensions, into: &s)
        // Research words are very generic: dampen them a little.
        if let r = s[.research] { s[.research] = r * 0.6 }
        // On a tie, the category listed first wins (dictionary order changes from one launch to the next).
        guard let best = s.max(by: { ($0.value, $1.key.rank) < ($1.value, $0.key.rank) }), best.value >= 1.5 else { return .other }
        return best.key
    }
}

// MARK: - Pricing (API-equivalent estimate)

enum Pricing {
    /// Base price per million input tokens, estimated from the costs Claude Code records.
    static func inputPrice(_ model: String) -> Double {
        let m = model.lowercased()
        if m.contains("fable") { return 9.0 }
        if m.contains("opus") {
            if m.contains("opus-4-0") || m.contains("opus-4-1") || m.contains("3-opus") { return 15 }
            if m.contains("opus-4") { return 5 }
            return 2.75
        }
        if m.contains("sonnet") { return m.contains("sonnet-5") ? 2 : 3 }
        if m.contains("haiku") { return m.contains("haiku-5") ? 0.35 : 1 }
        return 3
    }

    static func cost(model: String, input: Int, output: Int, cacheRead: Int, cacheWrite: Int, cacheWrite1h: Int) -> Double {
        let p = inputPrice(model)
        let w5 = max(0, cacheWrite - cacheWrite1h)
        let units = Double(input) + 5 * Double(output) + 0.1 * Double(cacheRead) + 1.25 * Double(w5) + 2 * Double(cacheWrite1h)
        return units * p / 1_000_000
    }

    static func modelLabel(_ id: String) -> String {
        var m = id.lowercased()
        if let r = m.range(of: "[") { m = String(m[..<r.lowerBound]) }
        m = m.replacingOccurrences(of: "claude-", with: "")
        // Strip date suffixes like -20251001
        let parts: [String] = m.split(separator: "-").map(String.init).filter { p in
            !(p.count == 8 && p.allSatisfy { $0.isNumber })
        }
        guard let family = parts.first else { return id }
        let version: String = parts.dropFirst().joined(separator: ".")
        let name: String = family.prefix(1).uppercased() + String(family.dropFirst())
        return version.isEmpty ? name : name + " " + version
    }
}

// MARK: - Language & style

enum Lang: String, CaseIterable, Sendable {
    case fr, en, es, other
    var label: String {
        switch self {
        case .fr: return "Français"
        case .en: return "Anglais"
        case .es: return "Espagnol"
        case .other: return "Autre"
        }
    }
    var flag: String {
        switch self {
        case .fr: return "🇫🇷"
        case .en: return "🇬🇧"
        case .es: return "🇪🇸"
        case .other: return "🌍"
        }
    }
}

enum TextStats {
    private static let fr: Set<String> = ["le", "la", "les", "des", "est", "et", "pour", "dans", "une", "je", "tu", "pas",
                                          "avec", "sur", "du", "au", "ce", "qui", "mon", "ma", "mes", "il", "veux", "fais",
                                          "moi", "toi", "nous", "vous", "mais", "ou", "donc", "aussi", "tout", "cette", "faire"]
    private static let en: Set<String> = ["the", "and", "is", "to", "of", "in", "that", "it", "for", "with", "you", "this",
                                          "my", "on", "are", "can", "what", "how", "please", "make", "want", "should", "be"]
    private static let es: Set<String> = ["el", "los", "las", "es", "y", "por", "para", "una", "con", "del", "mi", "se",
                                          "como", "pero", "esta", "muy", "lo", "yo", "tengo", "hay", "puedes", "quiero"]

    static func language(_ tokens: [String]) -> Lang {
        guard tokens.count >= 3 else { return .other }
        var f = 0, e = 0, s = 0
        for t in tokens.prefix(120) {
            if fr.contains(t) { f += 1 }
            if en.contains(t) { e += 1 }
            if es.contains(t) { s += 1 }
        }
        let m = max(f, e, s)
        if m == 0 { return .other }
        if m == f { return .fr }
        if m == e { return .en }
        return .es
    }

    static let stopwords: Set<String> = {
        let list = """
        le la les un une des de du et ou mais donc or ni car que qui quoi dont où ce cet cette ces se sa son ses ma mon mes ta ton tes \
        notre nos votre vos leur leurs je tu il elle on nous vous ils elles me te lui moi toi eux y en au aux a à est sont été être \
        avoir ai as avons avez ont fait faire fais faut peux peut pouvez veux veut voulez dois doit plus moins très tres bien aussi \
        comme pour par avec sans sous sur dans chez entre vers depuis pendant avant après apres alors ainsi encore déjà deja juste \
        tout tous toute toutes rien chaque même meme autre autres quel quelle quels quelles quand comment pourquoi combien si oui non \
        pas ne ça ca cela ceci celui celle ceux celles là ici voici voilà merci stp svp ok okay d l j s n c qu m t \
        ensuite maintenant puis afin vraiment trop beaucoup peu fois sera serait était etait étais etre avoir avais aurait \
        the a an and or but if then of to in on at for with without by from as is are was were be been being have has had do does \
        did can could should would will just also more most very this that these those it its i you he she we they me my your our \
        their them what which who how why when where all any some each other into about there here than so not no yes please \
        el la los las un una unos unas de del y o pero que en con por para es son está esta este esto lo le se mi tu su muy más \
        qué cómo hay ya también \
        dis veux voudrais aimerais pourrais pourrait mets met mettre prends prend prendre regarde vois voir donne donner \
        utilise utiliser crée créer cree creer ajoute ajouter fasse fassent dit dire sais savoir besoin chose choses truc \
        partie niveau cas façon facon manière maniere exemple bon bonne petit petite nouveau nouvelle gros grand grande \
        premier première dernier dernière tour aller va vais allons sorte mettre mis lieu jour jours temps fin début \
        soit également egalement fasses pouvoir possible place deux trois quelque quelques toujours jamais peut-être \
        vraiment surtout notamment ensuite plutôt plutot assez autant certain certaine certains certaines tant lors \
        celle-ci celui-ci ceux-ci sinon parce selon déjà encore voilà bien sûr ainsi chaque chacun chacune etc \
        fichier fichiers dossier dossiers users downloads documents desktop heic jpeg jpg png webp image images \
        concernant suite demande propre instant fonctionne travaille faites faite voici veuillez quoi niveau \
        souhaite souhaites puisse puisses passer réalisé realise plusieurs suis mettes trouve trouves reste parfait \
        partir sommes continue continuer envoyé envoye utilisation aide aider aides prendre prends rends rendre \
        mieux fasse moment ligne lignes exemple question questions point points travail travailler veut vouloir \
        regarder reprendre refaire relis lire lis besoins ceci cela celui avant après bonjour salut merci
        """
        return Set(list.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init))
    }()

    static let thanksWords: [String] = ["merci", "thanks", "thank", "thx", "gracias", "danke", "grazie"]
    static let pleaseWords: [String] = ["stp", "svp", "please", "plait", "plaît"]
    static let greetingWords: [String] = ["bonjour", "salut", "hello", "coucou", "hola", "hey", "bonsoir", "yo"]
}
