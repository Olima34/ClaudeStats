import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            WindowGlass()
            AmbientHalos()
            HStack(spacing: 0) {
                Sidebar()
                    .frame(width: 240)
                stage
                    .padding(.vertical, Theme.stageInset)
                    .padding(.trailing, Theme.stageInset)
            }
            if model.showPalette {
                CommandPalette()
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .animation(.easeOut(duration: 0.16), value: model.showPalette)
        .ignoresSafeArea()
        .tint(Theme.accent)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Pick up new sessions when coming back to the app.
            if let d = model.lastLoad, Date().timeIntervalSince(d) > 90, !model.isRefreshing, !model.isLoading {
                model.load(force: false)
            }
        }
        .onAppear {
            // Do not start with a text field focused.
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

    /// The inset main stage (Arc-style frame), concentric with the window corners.
    private var stage: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusStage, style: .continuous)
        return ZStack {
            Theme.bg
            if model.page == .overview, model.phase == .ready {
                // Hero light: the accent alone, fading into the stage.
                RadialGradient(colors: [Theme.accentSoft, .clear], center: .topLeading, startRadius: 0, endRadius: 560)
                    .allowsHitTesting(false)
            }
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
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.border))
        .overlay(TopRim(radius: Theme.radiusStage))
        .shadow(color: Theme.shadow, radius: 20, y: 8)
    }
}

// MARK: - Window material

/// The desktop seen through frosted glass, under the sidebar and around the stage.
struct WindowGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Two faint blurred lights under the sidebar only, never in the stage.
struct AmbientHalos: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 520, height: 520)
                .blur(radius: 120)
                .opacity(scheme == .dark ? 0.14 : 0.10)
                .offset(x: -260, y: -200)
            Circle()
                .fill(Color(hex: 0x5A6B85))
                .frame(width: 520, height: 520)
                .blur(radius: 120)
                .opacity(scheme == .dark ? 0.12 : 0.08)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .offset(x: -220, y: 260)
        }
        .frame(width: 240, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
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
                        .padding(.horizontal, 28)
                        .padding(.bottom, 40)
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

/// Toolbar of the stage: history, command bar, global filters.
struct TopBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            Button { model.goBack() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(IconButtonStyle())
                .disabled(model.backStack.isEmpty)
                .opacity(model.backStack.isEmpty ? 0.4 : 1)
                .help("Page précédente (⌘[)")
                .accessibilityLabel("Page précédente")
            Button { model.goForward() } label: { Image(systemName: "chevron.right") }
                .buttonStyle(IconButtonStyle())
                .disabled(model.forwardStack.isEmpty)
                .opacity(model.forwardStack.isEmpty ? 0.4 : 1)
                .help("Page suivante (⌘])")
                .accessibilityLabel("Page suivante")
            if let p = model.filter.project {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill").font(.ui(10)).foregroundStyle(Theme.accent)
                    Text(p).font(.ui(12, .medium)).foregroundStyle(Theme.text)
                    Button {
                        model.filter.project = nil
                    } label: {
                        Image(systemName: "xmark").font(.ui(9, .bold)).foregroundStyle(Theme.text3)
                    }
                    .buttonStyle(.plain)
                    .help("Retirer le filtre projet")
                    .accessibilityLabel("Retirer le filtre projet")
                }
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.fill2))
                .padding(.leading, 6)
            }
            Spacer(minLength: 12)
            commandBar
            Spacer(minLength: 12)
            sourceMenu
            PillPicker(options: Period.allCases, selection: $model.filter.period, label: { $0.label })
                .padding(.leading, 4)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color.clear.contentShape(Rectangle()).gesture(WindowDragGesture()))
    }

    private var commandBar: some View {
        Button { model.showPalette = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.ui(12))
                Text("Rechercher une session, une page…").font(.ui(13)).lineLimit(1)
                Spacer(minLength: 4)
                Text("⌘K")
                    .font(.ui(11, .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.fill2))
            }
            .foregroundStyle(Theme.text3)
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .frame(minWidth: 180, maxWidth: 320)
            .frame(height: 30)
            .background(Capsule().fill(Theme.fill1))
            .overlay(Capsule().strokeBorder(Theme.border))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Rechercher (⌘K)")
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
                Text(label).font(.ui(12, .medium))
                Image(systemName: "chevron.down").font(.ui(8, .bold)).foregroundStyle(Theme.text3)
            }
            .foregroundStyle(Theme.text2)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.fill2))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.border))
        .overlay(TopRim(radius: 8))
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
                        .font(.display(24))
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
                .font(.display(26))
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
