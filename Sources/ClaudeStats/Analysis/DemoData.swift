import Foundation

/// Fictional but realistic data for the demo mode (`--demo`) and the README screenshots.
/// Deterministic: the same seed always gives the same sessions. Dates are laid out relative to today
/// so the period filters (7 j, 30 j…) keep showing something.
enum DemoData {
    static var isEnabled: Bool { CommandLine.arguments.contains("--demo") }

    static func make(now: Date = Date()) -> RawData {
        var g = Generator(today: Calendar.current.startOfDay(for: now), now: now.timeIntervalSince1970)
        g.run()
        return g.raw()
    }
}

// MARK: - Random numbers

/// SplitMix64, with our own helpers so the output never depends on the standard library's algorithms.
private struct SeededRNG {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
    mutating func int(_ r: ClosedRange<Int>) -> Int { r.lowerBound + Int(next() % UInt64(r.upperBound - r.lowerBound + 1)) }
    mutating func double(_ r: ClosedRange<Double>) -> Double { r.lowerBound + unit() * (r.upperBound - r.lowerBound) }
    /// Log-uniform: small values are more frequent than large ones.
    mutating func logUniform(_ r: ClosedRange<Double>) -> Double { exp(double(log(r.lowerBound)...log(r.upperBound))) }
    mutating func pick<T>(_ a: [T]) -> T { a[Int(next() % UInt64(a.count))] }

    mutating func weighted<T>(_ items: [(T, Double)]) -> T {
        let total = items.reduce(0) { $0 + $1.1 }
        var x = unit() * total
        for (v, w) in items {
            if x < w { return v }
            x -= w
        }
        return items[items.count - 1].0
    }

    mutating func uuid() -> String {
        let a = next(), b = next()
        let hex = String(format: "%016llx%016llx", a, b)
        let c = Array(hex)
        return String(c[0..<8]) + "-" + String(c[8..<12]) + "-4" + String(c[13..<16]) + "-a" + String(c[17..<20]) + "-" + String(c[20..<32])
    }
}

// MARK: - Content

private enum Kind { case dev, study, data, research, automation }

private struct Scenario {
    var title: String
    var opener: String
    var followUps: [String] = []
    var english = false
    var images = 0
}

private struct Project {
    var cwd: String
    var source: SourceKind
    var kind: Kind
    var weight: Double
    /// Day offsets (relative to today, negative) during which the project is worked on.
    var days: ClosedRange<Int>
    var files: [String] = []
    var shell: [String] = []
    var domains: [String] = []
    var searches: [String] = []
    var branches: [String] = []
    var skill: String? = nil
    var tools: [(String, Double)]
    var scenarios: [Scenario]
}

private enum Content {
    static let home = "/Users/alex"

    static func devTools(ui: String) -> [(String, Double)] {
        [("Read", 24), ("Edit", 22), ("Bash", 18), ("Grep", 7), ("Glob", 4), ("Write", 6), ("TodoWrite", 4),
         ("WebSearch", 1), ("WebFetch", 1.5), ("Agent", 1.2), (ui, 2), ("Skill", 0.4)]
    }

    static let writingTools: [(String, Double)] = [
        ("Read", 18), ("Edit", 24), ("Write", 8), ("Bash", 6), ("WebSearch", 8), ("WebFetch", 5), ("Grep", 3),
        ("Skill", 1.5), ("Agent", 0.6)
    ]
    static let dataTools: [(String, Double)] = [
        ("Read", 14), ("Bash", 22), ("Write", 10), ("Edit", 12), ("Skill", 2.5), ("WebSearch", 2)
    ]
    static let researchTools: [(String, Double)] = [
        ("WebSearch", 30), ("WebFetch", 24), ("Write", 6), ("Read", 5), ("mcp__claude-in-chrome__navigate", 4), ("Skill", 1)
    ]
    static let automationTools: [(String, Double)] = [
        ("Bash", 30), ("Write", 12), ("Edit", 14), ("Read", 14), ("Grep", 3)
    ]

    static let projects: [Project] = [
        Project(
            cwd: home + "/Developer/Portfolio", source: .desktop, kind: .dev, weight: 18, days: -119...0,
            files: ["src/App.tsx", "src/components/Header.tsx", "src/components/ProjectCard.tsx", "src/pages/Contact.tsx",
                    "src/pages/Projects.tsx", "src/styles/theme.css", "src/hooks/useTheme.ts", "package.json",
                    "vite.config.ts", "README.md"],
            shell: ["npm", "npm", "git", "git", "npx", "ls", "rg", "open"],
            domains: ["react.dev", "developer.mozilla.org", "vercel.com", "stackoverflow.com", "vitejs.dev"],
            searches: ["vite react dark mode prefers-color-scheme", "vercel custom domain dns", "css lift hover card shadow"],
            branches: ["main", "main", "dark-mode", "contact-form"],
            skill: "frontend-design",
            tools: devTools(ui: "mcp__Claude_Browser__computer"),
            scenarios: [
                Scenario(title: "Ajouter un mode sombre au portfolio",
                         opener: "Ajoute un mode sombre au portfolio, avec un bouton dans le header et la préférence système par défaut.",
                         followUps: ["Le bouton est bien, mais les cartes restent blanches en mode sombre.",
                                     "Mémorise le choix dans le localStorage.", "Parfait, on peut committer."]),
                Scenario(title: "Corriger le formulaire de contact",
                         opener: "Le formulaire de contact n'envoie rien quand je clique sur Envoyer, tu peux regarder ?",
                         followUps: ["J'ai une erreur dans la console : TypeError: Cannot read properties of undefined (reading 'value')",
                                     "Ajoute un message de confirmation après l'envoi.", "Merci, ça marche !"]),
                Scenario(title: "Animate project cards on hover",
                         opener: "Can you add a subtle hover animation on the project cards? Something like a lift and a soft shadow.",
                         followUps: ["A bit less movement, it feels jumpy.", "Respect prefers-reduced-motion too."],
                         english: true),
                Scenario(title: "Optimiser le chargement des images",
                         opener: "Les images de la page projets sont lourdes, optimise le chargement (lazy loading, formats modernes).",
                         followUps: ["Tu peux mesurer le gain avec un build ?", "Génère aussi des miniatures en WebP."]),
                Scenario(title: "Déployer le portfolio sur Vercel",
                         opener: "Aide-moi à déployer le portfolio sur Vercel avec mon nom de domaine.",
                         followUps: ["Le domaine affiche une erreur DNS, qu'est-ce que je dois changer ?", "C'est en ligne, merci !"]),
                Scenario(title: "Write the portfolio README",
                         opener: "Write a clean README for the portfolio repo: stack, how to run it locally, how to deploy.",
                         followUps: ["Add a screenshot section.", "Shorter please, people skim READMEs."], english: true),
                Scenario(title: "Refactoriser les composants de l'accueil",
                         opener: "Refactorise les composants de la page d'accueil, il y a beaucoup de code dupliqué.",
                         followUps: ["Explique-moi ce que fait le hook useTheme maintenant.", "Lance le build pour vérifier."]),
                Scenario(title: "Page projets filtrable",
                         opener: "Ajoute des filtres par technologie sur la page projets (React, Swift, Python…).",
                         followUps: ["Voilà ce que j'obtiens sur mobile, les filtres débordent.", "Super, on passe à la suite."],
                         images: 1),
                Scenario(title: "Accessibility pass on the portfolio",
                         opener: "Do an accessibility pass on the portfolio: contrast, focus states, alt texts, keyboard navigation.",
                         followUps: ["Fix the focus ring on the nav links first.", "Great, commit it."], english: true),
                Scenario(title: "Ajouter une section témoignages",
                         opener: "Ajoute une section témoignages sous les projets, avec trois cartes et un défilement doux.",
                         followUps: ["Fais plus simple, sans dépendance en plus.", "Parfait, merci !"]),
                Scenario(title: "Formulaire d'inscription à la newsletter",
                         opener: "Ajoute un petit formulaire d'inscription à la newsletter dans le footer.",
                         followUps: ["Valide l'adresse mail côté client.", "Parfait."]),
                Scenario(title: "TypeScript strict mode",
                         opener: "Turn on TypeScript strict mode and fix whatever breaks.",
                         followUps: ["Don't use any, find proper types.", "Run the build again."], english: true),
                Scenario(title: "Page 404 personnalisée",
                         opener: "Crée une page 404 personnalisée avec un petit clin d'œil et un lien vers l'accueil.",
                         followUps: ["Ajoute une animation légère sur l'illustration.", "Top, merci !"])
            ]),
        Project(
            cwd: home + "/Documents/Études/Thèse", source: .desktop, kind: .study, weight: 19, days: -119...0,
            files: ["chapitres/introduction.tex", "chapitres/chapitre2.tex", "chapitres/chapitre3.tex",
                    "chapitres/conclusion.tex", "biblio.bib", "figures/courbes.py", "plan.md", "notes/lectures.md"],
            shell: ["latexmk", "latexmk", "python3", "git", "bibtex", "ls"],
            domains: ["fr.wikipedia.org", "scholar.google.com", "arxiv.org", "insee.fr", "persee.fr"],
            searches: ["difference in differences hypothèse tendances parallèles", "insee données emploi par région 2024",
                       "latex biblatex style auteur-année"],
            branches: ["main"],
            skill: "pdf",
            tools: writingTools,
            scenarios: [
                Scenario(title: "Restructurer le plan du chapitre 2",
                         opener: "Voici le plan de mon chapitre 2, tu peux m'aider à le restructurer pour que l'argumentation soit plus claire ?",
                         followUps: ["Explique pourquoi tu proposes cet ordre.", "Ajoute une transition entre les deux parties."]),
                Scenario(title: "Relire l'introduction de la thèse",
                         opener: "Relis mon introduction et propose des reformulations là où c'est lourd, sans changer le fond.",
                         followUps: ["Tu peux raccourcir le deuxième paragraphe ?", "Garde un ton plus formel."]),
                Scenario(title: "Générer les figures du chapitre 3",
                         opener: "Écris un script Python qui génère les courbes du chapitre 3 à partir des données du dossier data.",
                         followUps: ["Mets les axes en français et une police plus lisible.", "Exporte-les en PDF pour LaTeX."]),
                Scenario(title: "Vérifier la bibliographie",
                         opener: "Vérifie que toutes les références citées dans les chapitres sont bien dans biblio.bib.",
                         followUps: ["Corrige les entrées où il manque l'année.", "Merci, c'est propre."]),
                Scenario(title: "Explain difference-in-differences",
                         opener: "Explain the difference-in-differences method like I'm a master's student, with a simple example.",
                         followUps: ["What happens if the parallel trends assumption fails?", "Can you give me a source for that?"],
                         english: true),
                Scenario(title: "Préparer la soutenance de mémoire",
                         opener: "Aide-moi à préparer une présentation de 15 minutes pour ma soutenance de mémoire.",
                         followUps: ["Fais-moi une version en bullet points.", "Quelles questions le jury risque de poser ?"]),
                Scenario(title: "Rédiger la conclusion",
                         opener: "J'ai fini les trois chapitres, aide-moi à rédiger une conclusion qui reprend les résultats sans les répéter.",
                         followUps: ["Ajoute les limites de l'étude.", "Parfait, on continue avec les perspectives."]),
                Scenario(title: "Fiches de révision d'économétrie",
                         opener: "Fais-moi des fiches de révision sur les modèles de panel pour mon examen d'économétrie.",
                         followUps: ["Ajoute un exercice corrigé.", "Fais un quiz de 10 questions pour vérifier."]),
                Scenario(title: "Mettre en page la thèse en LaTeX",
                         opener: "La compilation LaTeX échoue depuis que j'ai ajouté les annexes, tu peux regarder ?",
                         followUps: ["Et maintenant la table des matières est vide.", "Ça compile, merci !"]),
                Scenario(title: "Traduire le résumé en anglais",
                         opener: "Traduis le résumé de la thèse en anglais académique.",
                         followUps: ["Garde les termes techniques tels qu'on les emploie dans la littérature.", "Parfait."]),
                Scenario(title: "Statistiques descriptives du chapitre 3",
                         opener: "Calcule les statistiques descriptives des variables du chapitre 3 et mets-les dans un tableau LaTeX.",
                         followUps: ["Ajoute les écarts-types.", "Arrondis à deux décimales."]),
                Scenario(title: "Préparer le rendez-vous de suivi",
                         opener: "Prépare une liste de questions pour mon prochain rendez-vous de suivi de thèse.",
                         followUps: ["Classe-les par priorité.", "Merci !"]),
                Scenario(title: "Synthèse d'articles pour l'état de l'art",
                         opener: "Résume ces trois articles pour mon état de l'art, avec leurs méthodes et leurs résultats.",
                         followUps: ["Fais un tableau comparatif.", "Merci !"]),
                Scenario(title: "Uniformiser les notes de bas de page",
                         opener: "Uniformise les notes de bas de page du chapitre 2 selon les normes de mon université.",
                         followUps: ["Vérifie aussi les citations longues.", "Parfait."])
            ]),
        Project(
            cwd: home + "/Developer/Appli recettes", source: .cli, kind: .dev, weight: 14, days: -52...0,
            files: ["RecettesApp/ContentView.swift", "RecettesApp/Models/Recette.swift", "RecettesApp/Views/RecetteDetailView.swift",
                    "RecettesApp/Views/ListeCoursesView.swift", "RecettesApp/Store.swift", "RecettesAppTests/StoreTests.swift"],
            shell: ["xcodebuild", "xcodebuild", "swift", "git", "git", "xcrun", "ls"],
            domains: ["developer.apple.com", "swift.org", "hackingwithswift.com", "stackoverflow.com"],
            searches: ["swiftdata migration from json", "swiftui navigationstack detail view image"],
            branches: ["main", "swiftdata", "liste-courses"],
            tools: devTools(ui: "mcp__Claude_Code_iOS_Simulator__control"),
            scenarios: [
                Scenario(title: "Écran de détail d'une recette",
                         opener: "Crée l'écran de détail d'une recette en SwiftUI : photo, ingrédients, étapes.",
                         followUps: ["Ajoute un bouton pour ajuster le nombre de personnes.", "Lance l'app dans le simulateur."]),
                Scenario(title: "Persist recipes with SwiftData",
                         opener: "Let's persist recipes with SwiftData instead of the JSON file.",
                         followUps: ["Keep a migration path for the existing JSON.", "Run the tests please."], english: true),
                Scenario(title: "Corriger le crash au lancement",
                         opener: "L'app crashe au lancement sur le simulateur, voici l'erreur : Fatal error: Unexpectedly found nil while unwrapping an Optional value",
                         followUps: ["Ça marche ! Pourquoi c'était nil ?", "Ajoute un test pour ça."]),
                Scenario(title: "Ajouter des tests unitaires au Store",
                         opener: "Ajoute des tests unitaires pour le Store et lance-les.",
                         followUps: ["Un test échoue, regarde pourquoi.", "On peut committer."]),
                Scenario(title: "Générer la liste de courses",
                         opener: "Ajoute une liste de courses générée à partir des recettes de la semaine.",
                         followUps: ["Regroupe les ingrédients par rayon.", "Voilà le rendu, c'est trop serré.", "Parfait."],
                         images: 1),
                Scenario(title: "Widget recette du jour",
                         opener: "Ajoute un widget iOS qui affiche la recette du jour.",
                         followUps: ["Le widget reste vide dans le simulateur.", "Super, merci !"]),
                Scenario(title: "Recherche par ingrédient",
                         opener: "Ajoute une recherche par ingrédient dans la liste des recettes.",
                         followUps: ["La recherche doit ignorer les accents.", "Lance les tests."]),
                Scenario(title: "Mode sombre de l'appli",
                         opener: "Vérifie que l'appli rend bien en mode sombre, certaines couleurs sont codées en dur.",
                         followUps: ["Voilà une capture, le fond reste blanc.", "Parfait."], images: 1),
                Scenario(title: "Import recipes from a URL",
                         opener: "Add a way to import a recipe from a URL by parsing the JSON-LD on the page.",
                         followUps: ["Handle pages without JSON-LD gracefully.", "Nice, commit it."], english: true)
            ]),
        Project(
            cwd: home + "/Sites/Site vitrine", source: .desktop, kind: .dev, weight: 16, days: -119...(-30),
            files: ["index.html", "css/style.css", "js/main.js", "js/galerie.js", "assets/logo.svg", "contact.html"],
            shell: ["git", "npx", "open", "curl", "ls"],
            domains: ["developer.mozilla.org", "fonts.google.com", "web.dev", "css-tricks.com"],
            searches: ["lightbox vanilla js accessible", "balises meta open graph exemple", "palette couleurs terre cuite"],
            branches: ["main"],
            skill: "frontend-design",
            tools: devTools(ui: "mcp__Claude_Browser__computer"),
            scenarios: [
                Scenario(title: "Maquette du site d'un atelier de céramique",
                         opener: "Je veux une maquette de page d'accueil sobre pour un atelier de céramique : hero, galerie photo, horaires, contact.",
                         followUps: ["J'aime bien, mais la police du titre fait trop moderne.", "Ajoute une section ateliers découverte."]),
                Scenario(title: "Nouvelle palette de couleurs",
                         opener: "Propose une palette de couleurs plus chaleureuse pour le design du site, et applique-la au thème.",
                         followUps: ["Le contraste du texte gris est trop faible.", "Garde cette version."]),
                Scenario(title: "Rendre le site responsive",
                         opener: "Le menu casse sur mobile, rends le site responsive.",
                         followUps: ["Voilà ce que ça donne sur mon téléphone.", "Parfait, merci !"], images: 1),
                Scenario(title: "Galerie photo avec lightbox",
                         opener: "Ajoute une galerie photo avec une lightbox, sans librairie externe.",
                         followUps: ["Ajoute la navigation au clavier.", "Super."]),
                Scenario(title: "Improve the site's SEO",
                         opener: "How can I improve the site's SEO? Add whatever tags are missing.",
                         followUps: ["Add Open Graph tags too.", "Thanks!"], english: true),
                Scenario(title: "Page des ateliers découverte",
                         opener: "Ajoute une page qui présente les ateliers découverte avec les prix et un bouton de réservation.",
                         followUps: ["Le bouton doit ouvrir un mail pré-rempli.", "Super, merci."]),
                Scenario(title: "Logo simplifié pour le favicon",
                         opener: "Le logo est illisible en petit, propose une version simplifiée pour le favicon, dans le même style visuel.",
                         followUps: ["Garde la couleur terre cuite.", "Parfait."])
            ]),
        Project(
            cwd: home + "/Documents/Budget perso", source: .desktop, kind: .data, weight: 10, days: -119...0,
            files: ["depenses-2026.csv", "analyse_budget.py", "graphiques.py", "synthese.md"],
            shell: ["python3", "python3", "head", "open", "ls"],
            domains: ["service-public.fr", "economie.gouv.fr", "insee.fr"],
            searches: ["plafond livret A LDDS 2026", "taux livret A octobre 2026"],
            skill: "xlsx",
            tools: dataTools,
            scenarios: [
                Scenario(title: "Analyser les dépenses du trimestre",
                         opener: "Analyse le fichier des dépenses du trimestre et dis-moi où part mon argent, par catégorie.",
                         followUps: ["Et si j'enlève les dépenses exceptionnelles ?", "Merci, c'est très clair !"]),
                Scenario(title: "Tableau de bord du budget",
                         opener: "Crée un tableau de bord Excel avec un graphique des dépenses mensuelles et la moyenne.",
                         followUps: ["Le graphique est illisible, mets les catégories en barres horizontales.", "Ajoute la moyenne mobile sur 3 mois."]),
                Scenario(title: "Comparer livret A et LDDS",
                         opener: "Compare un livret A et un LDDS pour mon épargne de précaution, avantages et limites.",
                         followUps: ["Fais un tableau récapitulatif.", "Merci !"]),
                Scenario(title: "Prévoir le budget des vacances",
                         opener: "Fais une prévision du budget pour les vacances d'août à partir des dépenses de l'an dernier.",
                         followUps: ["Exporte le résultat en CSV.", "Parfait."]),
                Scenario(title: "Suivi des abonnements",
                         opener: "Repère tous mes abonnements récurrents dans le CSV et calcule ce qu'ils me coûtent par an.",
                         followUps: ["Lesquels je pourrais résilier facilement ?", "Super, merci."]),
                Scenario(title: "Simuler un crédit immobilier",
                         opener: "Simule un crédit immobilier de 200 000 € sur 20 ans à différents taux.",
                         followUps: ["Ajoute le coût total des intérêts.", "Fais un graphique."]),
                Scenario(title: "Catégoriser les dépenses automatiquement",
                         opener: "Écris un script qui catégorise automatiquement les lignes du relevé bancaire exporté en CSV.",
                         followUps: ["Ajoute une catégorie Transport.", "Merci, ça marche."]),
                Scenario(title: "Préparer la déclaration d'impôts",
                         opener: "Aide-moi à préparer ma déclaration d'impôts : quels justificatifs rassembler et quelles cases vérifier ?",
                         followUps: ["Et pour les frais réels ?", "Merci, c'est clair."]),
                Scenario(title: "Graphique de l'épargne sur l'année",
                         opener: "Fais un graphique de l'évolution de mon épargne sur l'année à partir du CSV.",
                         followUps: ["Ajoute une ligne d'objectif.", "Parfait."])
            ]),
        Project(
            cwd: home + "/Automatisations", source: .cli, kind: .automation, weight: 7, days: -119...0,
            files: ["backup.sh", "rename_photos.py", "sync_notes.sh", "ranger_telechargements.py", "com.alex.backup.plist", "README.md"],
            shell: ["bash", "chmod", "python3", "launchctl", "rsync", "ls"],
            domains: ["ss64.com", "developer.apple.com"],
            searches: ["launchd plist run every hour", "rsync exclude dossier"],
            branches: ["main"],
            tools: automationTools,
            scenarios: [
                Scenario(title: "Script de sauvegarde automatique",
                         opener: "Écris un script qui sauvegarde mon dossier Documents sur le disque externe tous les soirs.",
                         followUps: ["Exclus les dossiers node_modules.", "Planifie-le avec launchd."]),
                Scenario(title: "Rename photos by date taken",
                         opener: "Write a Python script that renames my photos by the date they were taken.",
                         followUps: ["Handle HEIC files too.", "Run it on the test folder first."], english: true),
                Scenario(title: "Planifier la synchro des notes",
                         opener: "Planifie la synchronisation de mes notes toutes les heures avec launchd.",
                         followUps: ["Ça ne se lance pas, regarde les logs.", "Ça marche, merci."]),
                Scenario(title: "Nettoyer le dossier Téléchargements",
                         opener: "Fais un script qui range le dossier Téléchargements par type de fichier.",
                         followUps: ["Ajoute un mode simulation sans rien déplacer.", "Parfait."]),
                Scenario(title: "Raccourci de conversion d'images",
                         opener: "Crée un raccourci qui convertit les images sélectionnées en JPEG.",
                         followUps: ["Ajoute une option pour réduire la taille.", "Parfait."]),
                Scenario(title: "Configurer un serveur MCP pour mes notes",
                         opener: "Aide-moi à configurer un serveur MCP pour accéder à mes notes depuis Claude.",
                         followUps: ["Il n'apparaît pas dans la liste des outils.", "Ça marche !"])
            ]),
        Project(
            cwd: "/sessions/demo", source: .cowork, kind: .research, weight: 15, days: -119...0,
            files: ["itineraire.md", "comparatif.md", "resume.md", "lettre.docx"],
            domains: ["fr.wikipedia.org", "visitlisboa.com", "service-public.fr", "quechoisir.org", "meteofrance.com",
                      "ariase.com", "marmiton.org"],
            searches: ["que faire à Lisbonne en 5 jours", "meilleure offre fibre sans engagement", "recettes rapides de saison octobre",
                       "modèle lettre résiliation salle de sport", "randonnée facile autour d'Annecy"],
            skill: "docx",
            tools: researchTools,
            scenarios: [
                Scenario(title: "Comparer des offres de box internet",
                         opener: "Compare les offres de box internet fibre du moment, je veux le meilleur rapport qualité/prix.",
                         followUps: ["Lesquelles sont sans engagement ?", "Merci ! Tu peux faire un tableau récapitulatif ?"]),
                Scenario(title: "Résumer un article de recherche",
                         opener: "Résume cet article en une page avec les points clés et les limites.",
                         followUps: ["Fais une version en anglais.", "Merci."]),
                Scenario(title: "Lettre de résiliation",
                         opener: "Rédige une lettre de résiliation pour mon abonnement de salle de sport.",
                         followUps: ["Ajoute la référence du contrat en objet.", "Parfait, exporte-la en Word."]),
                Scenario(title: "Menus de la semaine",
                         opener: "Propose des recettes pour la semaine, pour deux, rapides et de saison.",
                         followUps: ["Sans poisson s'il te plaît.", "Fais la liste de courses."]),
                Scenario(title: "Plan a weekend hike",
                         opener: "Plan an easy weekend hike near Annecy, with the weather forecast.",
                         followUps: ["Something shorter, around 3 hours.", "Thanks!"], english: true),
                Scenario(title: "Choisir un vélo d'occasion",
                         opener: "Je veux acheter un vélo de ville d'occasion, quels points vérifier et quel prix viser ?",
                         followUps: ["Et pour un vélo électrique ?", "Super, merci beaucoup."]),
                Scenario(title: "Organiser un anniversaire surprise",
                         opener: "Aide-moi à organiser un anniversaire surprise : lieu, déroulé, liste de choses à prévoir.",
                         followUps: ["Pour une vingtaine de personnes.", "Merci, c'est parfait."]),
                Scenario(title: "Comprendre une fiche de paie",
                         opener: "Explique-moi les lignes d'une fiche de paie, notamment les cotisations.",
                         followUps: ["Et la différence entre brut et net imposable ?", "Merci !"]),
                Scenario(title: "Translate a cover letter",
                         opener: "Translate my cover letter into English and make it sound natural.",
                         followUps: ["Make it a bit less formal.", "Thanks!"], english: true),
                Scenario(title: "Préparer un entretien d'embauche",
                         opener: "Aide-moi à préparer un entretien pour un poste de chargé de projet : questions probables et réponses.",
                         followUps: ["Fais-moi une simulation d'entretien.", "Merci, très utile."]),
                Scenario(title: "Ranger les photos des vacances en famille",
                         opener: "Range les photos du dossier Vacances par lieu et par date.",
                         followUps: ["Mets les doublons de côté.", "Parfait."]),
                Scenario(title: "Comparer des aspirateurs robots",
                         opener: "Compare trois aspirateurs robots à moins de 300 €, avec les avis et l'autonomie.",
                         followUps: ["Lequel est le moins bruyant ?", "Merci !"]),
                Scenario(title: "Résumer le compte rendu de copropriété",
                         opener: "Résume le compte rendu de l'assemblée générale de copropriété en points clés.",
                         followUps: ["Quelles décisions me concernent ?", "Merci."]),
                Scenario(title: "Plan d'entraînement pour un 10 km",
                         opener: "Prépare un plan d'entraînement de 8 semaines pour courir un 10 km.",
                         followUps: ["Trois séances par semaine maximum.", "Super, merci !"]),
                Scenario(title: "How index funds work",
                         opener: "Explain how index funds work and which fees to watch for.",
                         followUps: ["How do they compare to a savings account?", "Thanks!"], english: true),
                Scenario(title: "Idées de cadeaux",
                         opener: "Trouve des idées de cadeaux d'anniversaire autour de 50 € pour quelqu'un qui aime cuisiner.",
                         followUps: ["Plutôt des expériences que des objets.", "Merci !"])
            ])
    ]

    static let followFR: [Kind: [String]] = [
        .dev: ["Ok, vas-y.", "Parfait, merci !", "Tu peux lancer le build pour vérifier ?", "Fais plus simple, sans dépendance en plus.",
               "On peut committer.", "Ajoute un test pour ça.", "C'est mieux. Et si on change aussi la couleur du lien actif ?",
               "Non, reviens à l'ancienne version de ce fichier.", "Explique-moi ce que fait cette fonction.", "Super, on passe à la suite.",
               "Ça marche, mais il y a un décalage sur Safari.", "Vérifie qu'on n'a rien cassé ailleurs.", "Oui", "Continue.",
               "Regarde aussi les warnings du build.", "Tu peux m'expliquer la différence entre les deux approches ?",
               "Je préfère la première option.", "Ajoute des commentaires là où c'est subtil.", "Ça marche nickel.",
               "Hmm, ça ne change rien chez moi.", "Renomme cette variable, le nom n'est pas clair.",
               "Fais une capture pour que je voie le rendu.", "Mets à jour le README aussi.", "Et sur mobile, ça donne quoi ?"],
        .study: ["Merci, c'est beaucoup plus clair.", "Tu peux raccourcir ce passage ?", "Prends un ton plus formel.",
                 "Peux-tu me donner une source pour ça ?", "Parfait, on continue avec la partie suivante.",
                 "Fais-moi une version en bullet points.", "Je ne comprends pas la deuxième étape, tu peux détailler ?",
                 "Recompile le PDF.", "Ok, intègre ces changements.", "C'est un peu long, tu peux condenser ?",
                 "Vérifie la cohérence avec le chapitre précédent.", "Donne-moi un exemple concret.", "Super, merci !"],
        .data: ["Ajoute la moyenne sur l'année.", "Exporte le résultat en CSV.", "Merci, c'est très clair !",
                "Arrondis à l'euro près.", "Fais un graphique plus simple.", "Ok, enregistre le script.",
                "Compare avec l'année dernière.", "Pourquoi ce mois-ci est aussi élevé ?"],
        .research: ["Merci ! Tu peux faire un tableau récapitulatif ?", "Et pour un budget plus serré ?", "Super, merci beaucoup.",
                    "Tu as des sources plus récentes ?", "Fais court, je lis ça sur mon téléphone.", "Ok, je prends la deuxième option.",
                    "Tu peux vérifier les prix ?", "Et en partant un week-end ?", "Parfait, exporte ça en document."],
        .automation: ["Ok, vas-y.", "Teste-le d'abord sur un dossier vide.", "Ajoute des logs.", "Rends-le exécutable.",
                      "Ça marche, merci.", "Explique la ligne avec rsync."]
    ]

    static let followEN: [Kind: [String]] = [
        .dev: ["Looks good, go ahead.", "Thanks! Can you also update the README?", "That broke the layout on Safari, can you check?",
               "Run the tests please.", "Why did you choose this approach?", "Perfect, commit it.", "Let's keep it simple for now.",
               "Great, what's next?", "yes"],
        .study: ["Thanks, that's much clearer.", "Can you give me a concrete example?", "Make it shorter.", "Great, next part."],
        .data: ["Add a monthly average.", "Export it as CSV.", "Thanks!"],
        .research: ["Thanks! Can you make a summary table?", "Any cheaper options?", "Great, thanks."],
        .automation: ["Go ahead.", "Add some logging.", "Works, thanks!"]
    ]

    static let commands: [(String, String)] = [("/compact", ""), ("/model", "opus"), ("/clear", ""), ("/review", ""), ("/context", "")]

    /// The day before the summer break.
    static let lisbon = Scenario(title: "Itinéraire de 5 jours à Lisbonne",
                                 opener: "Prépare un itinéraire de 5 jours à Lisbonne en août, avec un budget raisonnable.",
                                 followUps: ["Et pour un budget plus serré ?", "Ajoute les horaires d'ouverture."])

    /// The record session.
    static let marathon = Scenario(title: "Refonte complète de la page projets",
                                   opener: "On refait entièrement la page projets : nouvelle grille, filtres, fiches détaillées et animations. On y va étape par étape.",
                                   followUps: ["Commence par la grille.", "Maintenant les filtres.", "Les fiches détaillées s'ouvrent mal sur mobile.",
                                               "Ajoute les animations, mais discrètes.", "Lance le build et vérifie dans le navigateur."])
}

// MARK: - Generator

private struct Generator {
    let today: Date
    let now: Double
    var rng = SeededRNG(state: 0xC1A0_DE57_2026)

    var files: [FileSummary] = []
    var meta: [String: DesktopSessionMeta] = [:]
    var usage: [UsageSample] = []
    /// Index in `files` of each session's main transcript.
    var mainFile: [String: Int] = [:]
    var scenarioUses: [String: Int] = [:]
    /// Last scenario used in each project, to sometimes pick it up again a day or two later.
    var lastScenario: [String: (index: Int, day: Int)] = [:]
    /// (ts, weight, session) of every assistant message, to derive the plan usage history.
    var usageEvents: [(ts: Double, weight: Double, session: String)] = []

    init(today: Date, now: Double) {
        self.today = today
        self.now = now
    }

    func dayStart(_ offset: Int) -> Double {
        (Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today).timeIntervalSince1970
    }

    /// 1 = Sunday … 7 = Saturday.
    func weekday(_ offset: Int) -> Int {
        Calendar.current.component(.weekday, from: Date(timeIntervalSince1970: dayStart(offset) + 43200))
    }

    // MARK: Calendar

    mutating func run() {
        let projects = Content.projects
        let vacation = -62...(-54)
        let vacationEve = vacation.lowerBound - 3
        let marathonDay = -23

        for d in -119...(-1) {
            if vacation.contains(d) { continue }
            let wd = weekday(d)
            let weekend = wd == 1 || wd == 7
            // A scheduled task over the last two months: a backup check every Monday morning.
            if wd == 2 && d >= -56 { scheduledRun(day: d) }

            var p = weekend ? 0.3 : 0.48
            if d > -40 { p += 0.12 }
            let forced = d >= -9 || d == marathonDay || d == vacationEve
            guard forced || rng.chance(p) else { continue }

            var count = 1
            if rng.chance(0.24) { count += 1 }
            if rng.chance(0.05) { count += 1 }
            var hours: [Double] = []
            for _ in 0..<count { hours.append(startHour(weekend: weekend)) }
            hours.sort()

            var notBefore = dayStart(d)
            for (i, h) in hours.enumerated() {
                var start = max(dayStart(d) + h * 3600, notBefore)
                guard start < dayStart(d) + 25 * 3600 else { break }
                let candidates = projects.filter { $0.days.contains(d) }
                var project = rng.weighted(candidates.map { ($0, $0.weight) })
                var sc: (Scenario, String)
                var prompts: Int? = nil
                if d == marathonDay && i == 0 {
                    project = projects[0]
                    sc = (Content.marathon, Content.marathon.title)
                    prompts = 46
                    start = dayStart(d) + 13.6 * 3600
                } else if d == vacationEve && i == 0 {
                    project = projects.first { $0.source == .cowork } ?? project
                    sc = (Content.lisbon, Content.lisbon.title)
                } else {
                    sc = scenario(for: project, day: d)
                }
                let end = session(project: project, scenario: sc.0, title: sc.1, day: d, start: start, prompts: prompts)
                notBefore = end + rng.double(20 * 60...90 * 60)
            }
        }
        usageHistory()
    }

    mutating func startHour(weekend: Bool) -> Double {
        let weights: [(Double, Double)] = weekend
            ? [(10, 2), (11, 3), (14, 2), (15, 3), (16, 2), (17, 2), (21, 3), (22, 2), (23, 1)]
            : [(8, 1), (9, 3), (10, 5), (11, 3), (13, 1.5), (14, 4), (15, 4), (16, 3), (17, 2), (18, 1), (20, 1.5), (21, 3.5),
               (22, 3), (23, 1.2), (24, 0.4)]
        return rng.weighted(weights) + rng.double(0...0.9)
    }

    /// Goes through a project's scenarios in order (recurring tasks once they have all been used).
    /// Now and then a session picks up the previous one again.
    mutating func scenario(for p: Project, day: Int) -> (Scenario, String) {
        if let last = lastScenario[p.cwd], day - last.day <= 3, rng.chance(0.22) {
            var sc = p.scenarios[last.index]
            sc.opener = sc.english ? "Let's pick up where we left off on \"\(sc.title)\"."
                : "On reprend « \(sc.title) » là où on s'était arrêté."
            lastScenario[p.cwd] = nil
            return (sc, sc.title + " (suite)")
        }
        let n = scenarioUses[p.cwd, default: 0]
        scenarioUses[p.cwd] = n + 1
        let index = n % p.scenarios.count
        lastScenario[p.cwd] = (index, day)
        var sc = p.scenarios[index]
        // A few greetings (not in the terminal, where the first message doubles as the title).
        if p.source != .cli && rng.chance(0.12) { sc.opener = (sc.english ? "Hi! " : "Salut ! ") + sc.opener }
        return (sc, sc.title)
    }

    mutating func model(day: Int) -> String {
        if day < -70 {
            return rng.weighted([("claude-sonnet-5-5", 0.65), ("claude-opus-5-5", 0.35)])
        }
        return rng.weighted([("claude-opus-5-5", 0.8), ("claude-sonnet-5-5", 0.14), ("claude-fable-5-1", 0.06)])
    }

    func transcriptPath(_ p: Project, _ sid: String) -> String {
        if p.source == .cowork {
            return Content.home + "/Library/Application Support/Claude/local-agent-mode-sessions/demo/.claude/projects/-sessions-demo/\(sid).jsonl"
        }
        let folder = p.cwd.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: " ", with: "-")
        return Content.home + "/.claude/projects/\(folder)/\(sid).jsonl"
    }

    // MARK: Sessions

    /// Generates one session and returns the time of its last message.
    mutating func session(project p: Project, scenario sc: Scenario, title: String, day: Int, start: Double, prompts forced: Int?) -> Double {
        let sid = rng.uuid()
        let model = model(day: day)
        let source: SourceKind = p.source == .cowork ? .cowork : .desktop
        var file = FileSummary(path: transcriptPath(p, sid), size: 0, mtime: 0, source: source, isSubagent: false,
                               prompts: [], assistants: [], markers: [], hints: [])
        var subagentFiles: [FileSummary] = []

        var nPrompts: Int
        switch p.kind {
        case .dev: nPrompts = rng.int(4...24)
        case .study: nPrompts = rng.int(4...18)
        case .data: nPrompts = rng.int(3...14)
        case .research: nPrompts = rng.int(3...11)
        case .automation: nPrompts = rng.int(3...12)
        }
        if let forced { nPrompts = forced }
        let maxMsgs = p.kind == .dev ? 8 : 5
        let pool = (sc.english ? Content.followEN : Content.followFR)[p.kind] ?? []
        var specific = sc.followUps
        var t = start
        var context = rng.int(20_000...30_000)

        for k in 0..<nPrompts {
            // The user's message.
            if k == 0 {
                file.prompts.append(PromptRec(id: rng.uuid(), session: sid, ts: t, text: sc.opener, kind: .human, images: 0, command: nil))
            } else if k > 3 && rng.chance(0.05) {
                let (cmd, args) = rng.pick(Content.commands)
                file.prompts.append(PromptRec(id: rng.uuid(), session: sid, ts: t, text: args, kind: .command, images: 0, command: cmd))
                if cmd == "/compact" {
                    file.markers.append(MarkerRec(session: sid, ts: t + 20, kind: .compact))
                    context = rng.int(22_000...32_000)
                }
                t += rng.double(20...90)
                continue
            } else if p.kind == .dev && rng.chance(0.03) {
                let cmd = rng.pick(["git status", "git log --oneline -5", "npm run dev", "ls"])
                file.prompts.append(PromptRec(id: rng.uuid(), session: sid, ts: t, text: cmd, kind: .shell, images: 0, command: nil))
                t += rng.double(10...40)
                continue
            } else {
                let useSpecific = !specific.isEmpty && (rng.chance(0.45) || nPrompts - k <= specific.count)
                let text = useSpecific ? specific.removeFirst() : rng.pick(pool)
                let images = sc.images > 0 && text.hasPrefix("Voilà") ? sc.images : (rng.chance(0.02) ? 1 : 0)
                file.prompts.append(PromptRec(id: rng.uuid(), session: sid, ts: t, text: text, kind: .human, images: images, command: nil))
            }
            context += rng.int(80...1_500)

            // Claude's turn.
            var tt = t + rng.double(2...9)
            let nMsgs = 1 + rng.int(0...maxMsgs)
            let interruptAt = nMsgs > 2 && rng.chance(0.045) ? rng.int(1...(nMsgs - 1)) : -1
            for j in 0..<nMsgs {
                if j == interruptAt {
                    file.markers.append(MarkerRec(session: sid, ts: tt, kind: .interrupt))
                    break
                }
                let last = j == nMsgs - 1
                var tools: [ToolRec] = []
                if !last {
                    tools.append(tool(p))
                    if rng.chance(0.25) { tools.append(tool(p)) }
                }
                let thinkMs = j == 0 && rng.chance(0.35) ? rng.int(1_500...22_000) : 0
                let writes = tools.contains { $0.name == "Write" }
                let output = last ? rng.int(180...1_600) : (writes ? rng.int(700...3_800) : rng.int(60...900))
                let cacheWrite = j == 0 ? rng.int(1_200...4_500) : Int(rng.logUniform(200...7_000))
                let rec = AssistantRec(uuid: rng.uuid(), msgId: "msg_" + rng.uuid(), session: sid, ts: tt, model: model,
                                       input: rng.int(1...8), output: output, cacheRead: context, cacheWrite: cacheWrite,
                                       cacheWrite1h: 0, thinkMs: thinkMs,
                                       textChars: last ? rng.int(300...2_600) : (rng.chance(0.3) ? rng.int(40...320) : 0),
                                       tools: tools, sidechain: false)
                file.assistants.append(rec)
                usageEvents.append((tt, usageWeight(rec), sid))
                context += cacheWrite + output
                if context > 160_000 {
                    file.markers.append(MarkerRec(session: sid, ts: tt + 30, kind: .compact))
                    context = rng.int(24_000...36_000)
                    tt += 45
                }
                tt += Double(thinkMs) / 1000 + rng.logUniform(5...70)

                if let agent = tools.first(where: { $0.name == "Agent" }) {
                    let (sub, end) = subagent(p, session: sid, start: tt, type: agent.detail ?? "Explore")
                    subagentFiles.append(sub)
                    tt = end + rng.double(3...10)
                }
            }

            // The user reads, tests, thinks… and sometimes takes a real break.
            t = tt + (rng.chance(0.07) ? rng.double(16 * 60...75 * 60) : rng.logUniform(20...420))
        }

        if rng.chance(0.03), let a = file.assistants.last {
            file.markers.append(MarkerRec(session: sid, ts: a.ts - 30, kind: .apiError))
        }

        let end = max(file.prompts.last?.ts ?? start, file.assistants.last?.ts ?? start)
        let branch = p.branches.isEmpty ? nil : rng.pick(p.branches)
        file.hints = [SessionHint(session: sid, cwd: p.cwd, entrypoint: p.source == .cli ? "cli" : "claude-desktop",
                                  title: nil, gitBranch: branch)]
        file.size = Int64(file.prompts.count * 1_900 + file.assistants.count * 2_700 + rng.int(4_000...40_000))
        file.mtime = end
        mainFile[sid] = files.count
        files.append(file)
        files.append(contentsOf: subagentFiles)

        // Terminal sessions have no desktop metadata: their title is their first message.
        if p.source != .cli {
            meta[sid] = DesktopSessionMeta(cliSessionId: sid, title: title, model: model, effort: nil,
                                           isArchived: day < -30 && rng.chance(0.2), scheduledTaskId: nil, forkedFrom: nil,
                                           cwd: p.cwd, createdAt: start, isCowork: p.source == .cowork)
        }
        return end
    }

    mutating func tool(_ p: Project) -> ToolRec {
        let name = rng.weighted(p.tools)
        var t = ToolRec(name: name, file: nil, add: 0, del: 0, detail: nil)
        let path = p.files.isEmpty ? nil : p.cwd + "/" + rng.pick(p.files)
        switch name {
        case "Read":
            t.file = path
        case "Edit":
            t.file = path
            t.add = rng.int(1...32)
            t.del = rng.chance(0.2) ? 0 : rng.int(1...min(20, t.add + 4))
        case "Write":
            t.file = path
            t.add = rng.int(14...170)
        case "Bash":
            t.detail = p.shell.isEmpty ? "ls" : rng.pick(p.shell)
        case "WebSearch":
            t.detail = p.searches.isEmpty ? nil : rng.pick(p.searches)
        case "WebFetch":
            t.detail = p.domains.isEmpty ? nil : rng.pick(p.domains)
        case "Agent":
            t.detail = rng.weighted([("Explore", 5.0), ("general-purpose", 2.0), ("Plan", 1.0)])
        case "Skill":
            if let s = p.skill {
                t.detail = s
            } else {
                t.name = "Read"
                t.file = path
            }
        default:
            break
        }
        return t
    }

    /// A sub-agent's transcript: a few quick messages reading and searching on the main session's behalf.
    mutating func subagent(_ p: Project, session sid: String, start: Double, type: String) -> (FileSummary, Double) {
        let agentId = rng.uuid()
        let path = transcriptPath(p, sid).replacingOccurrences(of: ".jsonl", with: "/subagents/agent-\(agentId.prefix(8)).jsonl")
        var f = FileSummary(path: path, size: 0, mtime: 0, source: p.source == .cowork ? .cowork : .desktop, isSubagent: true,
                            prompts: [], assistants: [], markers: [],
                            hints: [SessionHint(session: sid, cwd: p.cwd, entrypoint: nil, title: nil, gitBranch: nil)])
        var t = start + rng.double(1...3)
        var context = rng.int(9_000...14_000)
        let n = type == "Explore" ? rng.int(4...10) : rng.int(3...7)
        for j in 0..<n {
            var tools: [ToolRec] = []
            if j < n - 1 {
                let name = rng.weighted([("Read", 5.0), ("Grep", 3.0), ("Glob", 2.0), ("Bash", 1.0)])
                let file = name == "Read" && !p.files.isEmpty ? p.cwd + "/" + rng.pick(p.files) : nil
                tools.append(ToolRec(name: name, file: file, add: 0, del: 0, detail: name == "Bash" ? "ls" : nil))
            }
            let cacheWrite = rng.int(400...5_000)
            let rec = AssistantRec(uuid: rng.uuid(), msgId: "msg_" + rng.uuid(), session: sid, ts: t, model: "claude-haiku-5-5",
                                   input: rng.int(1...6), output: rng.int(50...700), cacheRead: context, cacheWrite: cacheWrite,
                                   cacheWrite1h: 0, thinkMs: 0, textChars: j == n - 1 ? rng.int(400...1_800) : 0,
                                   tools: tools, sidechain: true)
            f.assistants.append(rec)
            usageEvents.append((t, usageWeight(rec), sid))
            context += cacheWrite
            t += rng.logUniform(2...14)
        }
        f.size = Int64(f.assistants.count * 2_400)
        f.mtime = t
        return (f, t)
    }

    /// The weekly scheduled task: no message from the user, just Claude checking the backups.
    mutating func scheduledRun(day: Int) {
        guard let p = Content.projects.first(where: { $0.kind == .automation }) else { return }
        let sid = rng.uuid()
        let start = dayStart(day) + 9 * 3600 + rng.double(0...120)
        var f = FileSummary(path: transcriptPath(p, sid), size: 0, mtime: 0, source: .desktop, isSubagent: false,
                            prompts: [], assistants: [], markers: [MarkerRec(session: sid, ts: start, kind: .scheduled)],
                            hints: [SessionHint(session: sid, cwd: p.cwd, entrypoint: "claude-desktop", title: nil, gitBranch: nil)])
        var t = start + rng.double(3...8)
        var context = rng.int(15_000...19_000)
        let n = rng.int(3...6)
        for j in 0..<n {
            let tools = j < n - 1 ? [ToolRec(name: "Bash", file: nil, add: 0, del: 0, detail: rng.pick(["ls", "du", "rsync", "tail"]))] : []
            let cacheWrite = rng.int(300...2_500)
            let rec = AssistantRec(uuid: rng.uuid(), msgId: "msg_" + rng.uuid(), session: sid, ts: t, model: "claude-sonnet-5-5",
                                   input: rng.int(1...5), output: rng.int(80...600), cacheRead: context, cacheWrite: cacheWrite,
                                   cacheWrite1h: 0, thinkMs: 0, textChars: j == n - 1 ? rng.int(200...700) : 0,
                                   tools: tools, sidechain: false)
            f.assistants.append(rec)
            usageEvents.append((t, usageWeight(rec), sid))
            context += cacheWrite
            t += rng.logUniform(4...30)
        }
        f.size = Int64(n * 2_500 + 3_000)
        f.mtime = t
        mainFile[sid] = files.count
        files.append(f)
        meta[sid] = DesktopSessionMeta(cliSessionId: sid, title: "Vérifier les sauvegardes", model: "claude-sonnet-5-5", effort: nil,
                                       isArchived: false, scheduledTaskId: "verifier-sauvegardes", forkedFrom: nil,
                                       cwd: p.cwd, createdAt: start, isCowork: false)
    }

    // MARK: Plan usage

    func usageWeight(_ r: AssistantRec) -> Double {
        let units = Double(r.input) + 5 * Double(r.output) + 0.1 * Double(r.cacheRead) + 1.25 * Double(r.cacheWrite)
        let factor = r.model.contains("haiku") ? 0.2 : r.model.contains("sonnet") ? 0.6 : r.model.contains("fable") ? 1.6 : 1
        return units * factor
    }

    /// Rebuilds a plausible plan usage history (rolling five-hour window, weekly quota) from the generated messages,
    /// and marks the moments the five-hour window filled up.
    mutating func usageHistory() {
        let events = usageEvents.sorted { $0.ts < $1.ts }
        guard let first = events.first?.ts else { return }
        let budget5h = 2_300_000.0
        let budgetWeek = 10_500_000.0
        let weekAnchor = dayStart(0) + 10 * 3600
        func weekIndex(_ ts: Double) -> Int { Int(((ts - weekAnchor) / (7 * 86400)).rounded(.down)) }

        // A sample every 10 minutes around activity, every 4 hours otherwise.
        var times = Set<Double>()
        for e in events {
            let g = (e.ts / 600).rounded(.up) * 600
            for k in 0..<6 { times.insert(g + Double(k) * 600) }
        }
        var t = (first / 14_400).rounded(.down) * 14_400
        while t < now {
            times.insert(t)
            t += 14_400
        }

        var lo = 0, hi = 0, window = 0.0, weekSum = 0.0, week = Int.min, full = false
        for ts in times.filter({ $0 <= now }).sorted() {
            let wi = weekIndex(ts)
            if wi != week {
                week = wi
                weekSum = 0
            }
            while hi < events.count && events[hi].ts <= ts {
                window += events[hi].weight
                if weekIndex(events[hi].ts) == wi { weekSum += events[hi].weight }
                hi += 1
            }
            while lo < hi && events[lo].ts <= ts - 5 * 3600 {
                window -= events[lo].weight
                lo += 1
            }
            let five = min(100, (window / budget5h * 100).rounded())
            usage.append(UsageSample(ts: ts, fiveHour: five, weekly: min(100, (weekSum / budgetWeek * 100).rounded())))
            if five >= 100 && !full, hi > 0, let idx = mainFile[events[hi - 1].session] {
                files[idx].markers.append(MarkerRec(session: events[hi - 1].session, ts: ts, kind: .usageLimit))
            }
            full = five >= 100
        }
    }

    func raw() -> RawData {
        let first = files.compactMap { $0.prompts.first?.ts }.min() ?? now
        let account = AccountInfo(displayName: "Alex", plan: "Max 5x", firstStart: Date(timeIntervalSince1970: first - 35 * 86400))
        return RawData(files: files, meta: meta, usage: usage, account: account,
                       skills: [("frontend-design", 7), ("pdf", 5), ("xlsx", 4), ("docx", 2)],
                       chats: [], scannedBytes: 0, parsedFiles: 0)
    }
}
