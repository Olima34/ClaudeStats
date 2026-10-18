import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var model: AppModel
    @State private var showAllProjects = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room for the traffic lights.
            Color.clear.frame(height: 38)

            HStack(spacing: 9) {
                ClaudeSpark(size: 20)
                Text("ClaudeStats")
                    .font(.serif(18, .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            searchField
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Page.groups, id: \.0) { group in
                        Text(group.0)
                            .font(.ui(11.5))
                            .foregroundStyle(Theme.text3)
                            .padding(.horizontal, 12)
                            .padding(.top, 14)
                            .padding(.bottom, 4)
                        ForEach(group.1) { p in
                            SidebarItem(symbol: p.symbol, title: p.title, selected: model.page == p) {
                                model.page = p
                            }
                        }
                    }

                    projectsSection
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.never)

            Spacer(minLength: 0)
            Rectangle().fill(Theme.border).frame(height: 1)
            profileRow
        }
        .background(Theme.sidebar)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.ui(12))
                .foregroundStyle(Theme.text3)
            TextField("Rechercher une session", text: $model.search)
                .textFieldStyle(.plain)
                .font(.ui(13))
                .foregroundStyle(Theme.text)
                .focused($searchFocused)
                .onSubmit { model.page = .sessions }
                .onChange(of: model.search) { _, v in if !v.isEmpty { model.page = .sessions } }
            if !model.search.isEmpty {
                Button { model.search = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.ui(11)).foregroundStyle(Theme.text3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(searchFocused ? Theme.accent.opacity(0.6) : Theme.border))
    }

    @ViewBuilder private var projectsSection: some View {
        let projects = model.allTime.projects.filter { $0.prompts > 0 }
        if !projects.isEmpty {
            HStack {
                Text("Projets")
                    .font(.ui(11.5))
                    .foregroundStyle(Theme.text3)
                Spacer()
                if model.filter.project != nil {
                    Button("Tous") { model.filter.project = nil }
                        .buttonStyle(.plain)
                        .font(.ui(11))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 18)
            .padding(.bottom, 4)

            let shown = showAllProjects ? projects : Array(projects.prefix(6))
            ForEach(shown) { p in
                SidebarProjectItem(project: p, selected: model.filter.project == p.name) {
                    model.filter.project = model.filter.project == p.name ? nil : p.name
                }
            }
            if projects.count > 6 {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showAllProjects.toggle() }
                } label: {
                    Text(showAllProjects ? "Afficher moins" : "Afficher plus")
                        .font(.ui(13))
                        .foregroundStyle(Theme.text3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var profileRow: some View {
        HStack(spacing: 9) {
            Text(String(model.dataset.account.displayName.prefix(1)).uppercased())
                .font(.ui(11, .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.selected))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(model.dataset.account.displayName)
                        .font(.ui(13, .medium))
                        .foregroundStyle(Theme.text)
                    if !model.dataset.account.plan.isEmpty {
                        Text("· \(model.dataset.account.plan)")
                            .font(.ui(11.5))
                            .foregroundStyle(Theme.text3)
                    }
                }
                if let d = model.lastLoad {
                    Text("Mis à jour \(Fmt.relative(d))")
                        .font(.ui(10.5))
                        .foregroundStyle(Theme.text3)
                }
            }
            Spacer()
            Menu {
                Button { model.load(force: false) } label: { Label("Rafraîchir", systemImage: "arrow.clockwise") }
                Button { model.importClaudeAIExport() } label: { Label("Importer un export claude.ai…", systemImage: "square.and.arrow.down") }
                Button { model.showSources = true } label: { Label("Sources de données…", systemImage: "externaldrive") }
                Divider()
                Button { model.rebuildCache() } label: { Label("Tout relire depuis zéro", systemImage: "arrow.triangle.2.circlepath") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.ui(13, .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 26, height: 26)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Plus d'options")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct SidebarItem: View {
    var symbol: String
    var title: String
    var selected: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.ui(13))
                    .foregroundStyle(selected ? Theme.text : Theme.text2)
                    .frame(width: 18)
                Text(title)
                    .font(.ui(13.5))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Theme.selected : (hovering ? Theme.hover : .clear)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct SidebarProjectItem: View {
    var project: ProjectStat
    var selected: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.color(project.mainCategory))
                    .frame(width: 6, height: 6)
                Text(project.name)
                    .font(.ui(13))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer()
                Text(Fmt.hours(project.seconds))
                    .font(.ui(11))
                    .foregroundStyle(Theme.text3)
                    .opacity(hovering || selected ? 1 : 0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Theme.selected : (hovering ? Theme.hover : .clear)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(project.paths.sorted().joined(separator: "\n"))
    }
}
