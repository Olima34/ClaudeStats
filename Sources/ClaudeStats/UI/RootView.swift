import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 252)
            Rectangle().fill(Theme.border).frame(width: 1)
            ZStack {
                Theme.bg
                switch model.phase {
                case .loading(let done, let total):
                    LoadingView(done: done, total: total)
                        .transition(.opacity)
                case .ready:
                    if model.dataset.isEmpty {
                        EmptyDataView()
                    } else {
                        VStack(spacing: 0) {
                            TopBar()
                            PageContainer()
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .background(Theme.bg)
        .tint(Theme.accent)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Pick up new sessions when coming back to the app.
            if let d = model.lastLoad, Date().timeIntervalSince(d) > 90, !model.isRefreshing, !model.isLoading {
                model.load(force: false)
            }
        }
        .onAppear {
            // Do not start with the search field focused.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { NSApp.keyWindow?.makeFirstResponder(nil) }
        }
        .sheet(isPresented: $model.showSources) {
            SourcesSheet().environmentObject(model)
        }
        .alert(model.importMessage ?? "", isPresented: Binding(get: { model.importMessage != nil },
                                                             set: { if !$0 { model.importMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - Page container

struct PageContainer: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 0).id("top")
                    page
                        .frame(maxWidth: 1180)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                        .padding(.bottom, 48)
                        .frame(maxWidth: .infinity)
                }
            }
            .scrollIndicators(.automatic)
            .onChange(of: model.page) { _, _ in proxy.scrollTo("top", anchor: .top) }
        }
    }

    var page: some View { PageView(page: model.page) }
}

struct PageView: View {
    var page: Page

    var body: some View {
        switch page {
        case .overview: OverviewPage()
        case .rhythm: RhythmPage()
        case .projects: ProjectsPage()
        case .categories: CategoriesPage()
        case .sessions: SessionsPage()
        case .tools: ToolsPage()
        case .style: StylePage()
        case .limits: LimitsPage()
        case .badges: BadgesPage()
        case .wrapped: WrappedPage()
        case .learn: LearnPage()
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Text(model.page.title)
                .font(.ui(14, .medium))
                .foregroundStyle(Theme.text)
            if let p = model.filter.project {
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill").font(.ui(10))
                    Text(p).font(.ui(11.5, .medium))
                    Button {
                        model.filter.project = nil
                    } label: {
                        Image(systemName: "xmark").font(.ui(9, .bold))
                    }
                    .buttonStyle(.plain)
                    .help("Retirer le filtre projet")
                    .accessibilityLabel("Retirer le filtre projet")
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.accent.opacity(0.14)))
            }
            Spacer()
            sourceMenu
            PillPicker(options: Period.allCases, selection: $model.filter.period, label: { $0.label })
            Button {
                model.load(force: false)
            } label: {
                Group {
                    if model.isRefreshing {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise").font(.ui(12, .medium))
                    }
                }
                .frame(width: 28, height: 28)
                .foregroundStyle(Theme.text2)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border))
            }
            .buttonStyle(.plain)
            .help("Relire les sessions (⌘R)")
            .accessibilityLabel("Rafraîchir")
        }
        .padding(.leading, 32)
        .padding(.trailing, 20)
        .frame(height: 52)
        .background(Theme.bg)
    }

    private var sourceMenu: some View {
        let all = Set(SourceKind.allCases)
        let present = Set(model.dataset.sessions.map(\.source))
        let label: String = {
            if model.filter.sources == all { return "Toutes les sources" }
            let on = SourceKind.allCases.filter { model.filter.sources.contains($0) }
            return on.map(\.shortLabel).joined(separator: " + ")
        }()
        return Menu {
            Button("Toutes les sources") { model.filter.sources = all }
            Divider()
            ForEach(SourceKind.allCases) { s in
                Toggle(isOn: Binding(
                    get: { model.filter.sources.contains(s) },
                    set: { on in
                        var set = model.filter.sources
                        if on { set.insert(s) } else if set.count > 1 { set.remove(s) }
                        model.filter.sources = set
                    })) {
                    Label(s.label + (present.contains(s) ? "" : " (aucune donnée)"), systemImage: s.symbol)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease").font(.ui(11, .medium))
                Text(label).font(.ui(11.5))
            }
            .foregroundStyle(Theme.text2)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border))
    }
}

// MARK: - Loading

struct LoadingView: View {
    var done: Int
    var total: Int

    var body: some View {
        ZStack {
            MatrixBackdrop(seed: 42, opacity: 0.55)
                .mask(LinearGradient(colors: [.black, .black.opacity(0.2)], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 22) {
                ClaudeSpark(size: 54, animate: true)
                VStack(spacing: 8) {
                    Text("Je lis tes sessions avec Claude…")
                        .font(.serif(26))
                        .foregroundStyle(Theme.text)
                    Text(total > 0 ? "\(Fmt.int(done)) fichiers sur \(Fmt.int(total))" : "Recherche des transcripts sur ton Mac")
                        .font(.ui(12.5))
                        .foregroundStyle(Theme.text2)
                        .monospacedDigit()
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.track)
                        Capsule().fill(Theme.accent)
                            .frame(width: total > 0 ? g.size.width * CGFloat(done) / CGFloat(total) : 24)
                            .animation(.easeOut(duration: 0.2), value: done)
                    }
                }
                .frame(width: 320, height: 6)
                Text("Tout est analysé en local : rien ne quitte ton Mac.")
                    .font(.ui(11.5))
                    .foregroundStyle(Theme.text3)
                PixelMascot(pixel: 5)
                    .padding(.top, 10)
            }
        }
    }
}

struct EmptyDataView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            PixelMascot(pixel: 7)
            Text("Aucune session trouvée")
                .font(.serif(26))
                .foregroundStyle(Theme.text)
            Text("ClaudeStats lit les transcripts de Claude Code dans ~/.claude/projects et ceux de Cowork.\nTu peux aussi importer l'export de tes conversations claude.ai.")
                .font(.ui(13))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
            HStack {
                Button("Importer un export claude.ai…") { model.importClaudeAIExport() }
                    .buttonStyle(SoftButtonStyle(prominent: true))
                Button("Relire") { model.load(force: true) }
                    .buttonStyle(SoftButtonStyle())
            }
        }
    }
}
