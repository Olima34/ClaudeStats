import SwiftUI
import AppKit

enum Page: String, CaseIterable, Identifiable {
    case overview, rhythm, projects, categories, sessions, tools, style, limits, badges, wrapped, learn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Vue d'ensemble"
        case .rhythm: return "Rythme"
        case .projects: return "Projets"
        case .categories: return "Catégories"
        case .sessions: return "Sessions"
        case .tools: return "Claude au travail"
        case .style: return "Ton style"
        case .limits: return "Limites d'usage"
        case .badges: return "Badges"
        case .wrapped: return "Ton récap"
        case .learn: return "Comprendre"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .rhythm: return "clock"
        case .projects: return "folder"
        case .categories: return "circle.hexagongrid"
        case .sessions: return "bubble.left.and.bubble.right"
        case .tools: return "wrench.and.screwdriver"
        case .style: return "text.quote"
        case .limits: return "gauge.with.dots.needle.50percent"
        case .badges: return "rosette"
        case .wrapped: return "sparkles"
        case .learn: return "lightbulb"
        }
    }

    static let groups: [(String, [Page])] = [
        ("Statistiques", [.overview, .rhythm, .projects, .categories, .sessions]),
        ("Claude", [.tools, .style, .limits]),
        ("Pour le fun", [.badges, .wrapped, .learn])
    ]
}

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case loading(done: Int, total: Int)
        case ready
    }

    @Published var phase: Phase = .loading(done: 0, total: 0)
    @Published var dataset = Dataset()
    @Published var stats = Stats()
    @Published var allTime = Stats()
    /// Whole history with the current source / project filters (for the calendar).
    @Published var history = Stats()
    @Published var page: Page = .overview
    @Published var filter = StatsFilter() {
        didSet { if filter != oldValue { recompute() } }
    }
    @Published var search = ""
    @Published var selectedSession: String?
    @Published var lastLoad: Date?
    @Published var loadInfo = ""
    @Published var isRefreshing = false
    @Published var importMessage: String?
    @Published var showSources = false

    private var raw: RawData?
    private var generation = 0
    private var overrides: [String: Category] = [:]
    private let overridesKey = "categoryOverrides"

    init(autoload: Bool = true) {
        if let d = UserDefaults.standard.dictionary(forKey: overridesKey) as? [String: String] {
            overrides = d.compactMapValues { Category(rawValue: $0) }
        }
        if autoload { load(force: false) }
    }

    /// Synchronous variant used by the snapshot tool.
    func apply(raw: RawData) {
        self.raw = raw
        dataset = Dataset.build(raw, overrides: overrides)
        allTime = StatsEngine.compute(dataset, filter: StatsFilter())
        stats = allTime
        history = allTime
        lastLoad = Date()
        phase = .ready
    }

    var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    func load(force: Bool) {
        if !dataset.isEmpty { isRefreshing = true } else { phase = .loading(done: 0, total: 0) }
        let overrides = self.overrides
        let start = Date()
        Task.detached(priority: .userInitiated) {
            let raw = Loader.load(forceRescan: force) { done, total in
                Task { @MainActor [weak self] in
                    guard let self, self.isLoading else { return }
                    self.phase = .loading(done: done, total: total)
                }
            }
            let ds = Dataset.build(raw, overrides: overrides)
            let all = StatsEngine.compute(ds, filter: StatsFilter())
            await MainActor.run {
                self.raw = raw
                self.dataset = ds
                self.allTime = all
                self.stats = self.filter == StatsFilter() ? all : StatsEngine.compute(ds, filter: self.filter)
                var hf = self.filter
                hf.period = .all
                self.history = hf == StatsFilter() ? all : StatsEngine.compute(ds, filter: hf)
                self.lastLoad = Date()
                let secs = Date().timeIntervalSince(start)
                self.loadInfo = "\(Fmt.int(ds.fileCount)) fichiers · \(raw.parsedFiles) relus en \(Fmt.dec(secs)) s"
                self.isRefreshing = false
                withAnimation(.easeOut(duration: 0.35)) { self.phase = .ready }
            }
        }
    }

    func recompute() {
        generation += 1
        let gen = generation
        let ds = dataset
        let f = filter
        let all = allTime
        Task.detached(priority: .userInitiated) {
            let s = StatsEngine.compute(ds, filter: f)
            var hf = f
            hf.period = .all
            let h = hf == f ? s : (hf == StatsFilter() ? all : StatsEngine.compute(ds, filter: hf))
            await MainActor.run {
                guard gen == self.generation else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    self.stats = s
                    self.history = h
                }
            }
        }
    }

    // MARK: Categories

    func setCategory(_ c: Category?, for sessionId: String) {
        if let c { overrides[sessionId] = c } else { overrides.removeValue(forKey: sessionId) }
        UserDefaults.standard.set(overrides.mapValues(\.rawValue), forKey: overridesKey)
        if let i = dataset.sessions.firstIndex(where: { $0.id == sessionId }) {
            dataset.sessions[i].category = c ?? dataset.sessions[i].autoCategory
        }
        allTime = StatsEngine.compute(dataset, filter: StatsFilter())
        recompute()
    }

    func session(_ id: String) -> Session? {
        dataset.sessions.first { $0.id == id }
    }

    // MARK: Navigation helpers

    func open(project: String) {
        filter.project = project
        page = .overview
    }

    func openSession(_ id: String) {
        selectedSession = id
        page = .sessions
    }

    // MARK: Import

    func importClaudeAIExport() {
        let panel = NSOpenPanel()
        panel.title = "Importer un export claude.ai"
        panel.message = "Choisis l'archive .zip reçue par mail, son dossier décompressé ou le fichier conversations.json."
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.zip, .json, .folder]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let n = try ChatImport.importExport(at: url)
            importMessage = "\(Fmt.plural(n, "conversation importée", "conversations importées"))."
            load(force: false)
        } catch {
            importMessage = error.localizedDescription
        }
    }

    func removeImportedChats() {
        ChatImport.clearStored()
        importMessage = "Conversations claude.ai retirées."
        load(force: false)
    }

    func rebuildCache() {
        SummaryCache.clear()
        load(force: true)
    }
}
