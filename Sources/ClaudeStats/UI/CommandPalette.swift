import SwiftUI

/// ⌘K: jump to a session, a page or an action from the keyboard.
struct CommandPalette: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    struct Item: Identifiable {
        var id: String
        var group: String
        var symbol: String
        var title: String
        var subtitle = ""
        var shortcut: String? = nil
        var run: () -> Void
    }

    var body: some View {
        let items = results
        ZStack(alignment: .top) {
            Color.black.opacity(0.28)
                .contentShape(Rectangle())
                .onTapGesture { close() }
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.ui(15)).foregroundStyle(Theme.text3)
                    TextField("Rechercher une session, une page, une action…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.ui(16))
                        .foregroundStyle(Theme.text)
                        .focused($focused)
                        .onSubmit { activate(items) }
                        .onKeyPress(.downArrow) { move(1, in: items); return .handled }
                        .onKeyPress(.upArrow) { move(-1, in: items); return .handled }
                        .onKeyPress(.escape) { close(); return .handled }
                        .onChange(of: query) { _, _ in selection = 0 }
                    KeyCap(text: "esc")
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                Rectangle().fill(Theme.border).frame(height: 1)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if items.isEmpty {
                                Text("Aucun résultat pour « \(query) ».")
                                    .font(.ui(13))
                                    .foregroundStyle(Theme.text3)
                                    .frame(maxWidth: .infinity, minHeight: 80)
                            }
                            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                                if i == 0 || items[i - 1].group != item.group {
                                    SectionLabel(text: item.group)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 6)
                                        .padding(.bottom, 2)
                                }
                                row(item, selected: i == selection)
                                    .id(item.id)
                                    .onTapGesture { selection = i; activate(items) }
                                    .onHover { if $0 { selection = i } }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 420)
                    .fixedSize(horizontal: false, vertical: true)
                    .onChange(of: selection) { _, i in
                        if items.indices.contains(i) { proxy.scrollTo(items[i].id) }
                    }
                }

                Rectangle().fill(Theme.border).frame(height: 1)
                HStack(spacing: 16) {
                    hint(["↑", "↓"], "naviguer")
                    hint(["↵"], "ouvrir")
                    hint(["esc"], "fermer")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 36)
            }
            .frame(width: 620)
            .background {
                let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                ZStack {
                    shape.fill(.regularMaterial)
                    shape.fill(Theme.floating)
                }
                .overlay(shape.strokeBorder(Theme.borderStrong))
                .overlay(TopRim(radius: 14))
                .shadow(color: .black.opacity(0.4), radius: 32, y: 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 96)
            .padding(.leading, 240)
        }
        .onAppear { focused = true }
    }

    // MARK: Results

    private var results: [Item] {
        let q = Words.fold(query.trimmingCharacters(in: .whitespaces).lowercased())
        var items: [Item] = []

        let sessions = model.stats.sessions.filter { $0.prompts > 0 }
        let matching = q.isEmpty
            ? Array(sessions.sorted { $0.end > $1.end }.prefix(3))
            : Array(sessions.filter { Words.fold($0.title.lowercased()).contains(q) || Words.fold($0.project.lowercased()).contains(q) }
                .sorted { $0.end > $1.end }.prefix(6))
        for r in matching {
            items.append(Item(id: "s-\(r.id)", group: q.isEmpty ? "Sessions récentes" : "Sessions", symbol: r.category.symbol,
                              title: r.title, subtitle: "\(r.project) · \(Fmt.dayShort(Fmt.ts(r.end)))") {
                model.openSession(r.id)
            })
        }
        if !q.isEmpty {
            let text = query.trimmingCharacters(in: .whitespaces)
            items.append(Item(id: "s-all", group: "Sessions", symbol: "line.3.horizontal.decrease", title: "Toutes les sessions contenant « \(text) »") {
                model.search = text
                model.page = .sessions
            })
        }

        for (i, p) in Page.allCases.enumerated() where q.isEmpty || Words.fold(p.title.lowercased()).contains(q) {
            items.append(Item(id: "p-\(p.rawValue)", group: "Pages", symbol: p.symbol, title: p.title,
                              shortcut: i < 9 ? "⌘ \(i + 1)" : nil) { model.page = p })
        }

        let actions: [Item] = [
            Item(id: "a-refresh", group: "Actions", symbol: "arrow.clockwise", title: "Relire les sessions", shortcut: "⌘ R") { model.load(force: false) },
            Item(id: "a-wrapped", group: "Actions", symbol: "square.and.arrow.up", title: "Exporter ton récap en image") { model.page = .wrapped },
            Item(id: "a-import", group: "Actions", symbol: "square.and.arrow.down", title: "Importer un export claude.ai…", shortcut: "⇧ ⌘ I") { model.importClaudeAIExport() },
            Item(id: "a-sources", group: "Actions", symbol: "externaldrive", title: "Sources de données…") { model.showSources = true },
        ]
        items += actions.filter { q.isEmpty || Words.fold($0.title.lowercased()).contains(q) }
        return items
    }

    // MARK: Pieces

    private func row(_ item: Item, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol)
                .font(.ui(11.5))
                .foregroundStyle(Theme.text2)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.fill2))
            Text(item.title).font(.ui(13)).foregroundStyle(Theme.text).lineLimit(1)
            if !item.subtitle.isEmpty {
                Text(item.subtitle).font(.ui(12)).foregroundStyle(Theme.text3).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let s = item.shortcut {
                HStack(spacing: 3) { ForEach(s.split(separator: " ").map(String.init), id: \.self) { KeyCap(text: $0) } }
            } else if selected {
                KeyCap(text: "↵")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.fill2).overlay(TopRim(radius: 8))
            }
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 6)
    }

    private func hint(_ keys: [String], _ text: String) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { KeyCap(text: $0) }
            Text(text).font(.ui(11.5)).foregroundStyle(Theme.text3)
        }
    }

    private func move(_ d: Int, in items: [Item]) {
        guard !items.isEmpty else { return }
        selection = (selection + d + items.count) % items.count
    }

    private func activate(_ items: [Item]) {
        guard items.indices.contains(selection) else { return }
        let item = items[selection]
        close()
        item.run()
    }

    private func close() {
        model.showPalette = false
        query = ""
    }
}

struct KeyCap: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.ui(11, .medium))
            .foregroundStyle(Theme.text3)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.fill2))
    }
}
