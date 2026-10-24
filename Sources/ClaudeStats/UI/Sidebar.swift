import SwiftUI

/// Translucent sidebar: it has no background of its own and shows the window's glass.
struct Sidebar: View {
    @EnvironmentObject var model: AppModel
    @State private var showAllProjects = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room for the traffic lights.
            Color.clear.frame(height: 40)

            HStack(spacing: 9) {
                ClaudeSpark(size: 18)
                Text("ClaudeStats")
                    .font(.ui(15, .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Page.groups, id: \.0) { group in
                        GroupLabel(text: group.0)
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
            StatusModule()
                .padding(10)
        }
    }

    @ViewBuilder private var projectsSection: some View {
        let projects = model.allTime.projects.filter { $0.prompts > 0 }
        if !projects.isEmpty {
            HStack {
                GroupLabel(text: "Projets")
                Spacer()
                if model.filter.project != nil {
                    Button("Tous") { model.filter.project = nil }
                        .buttonStyle(.plain)
                        .font(.ui(11, .medium))
                        .foregroundStyle(Theme.text2)
                        .padding(.top, 14)
                        .padding(.trailing, 10)
                }
            }

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
                        .font(.ui(12))
                        .foregroundStyle(Theme.text3)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct GroupLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.ui(11, .semibold))
            .foregroundStyle(Theme.text3)
            .padding(.horizontal, 10)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }
}

/// Live activity of the app: data freshness, refresh and the data menu.
struct StatusModule: View {
    @EnvironmentObject var model: AppModel
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.isRefreshing ? Theme.accent : Theme.positive)
                .frame(width: 6, height: 6)
                .background(Circle().fill((model.isRefreshing ? Theme.accent : Theme.positive).opacity(0.25)).frame(width: 12, height: 12)
                    .scaleEffect(model.isRefreshing && pulse ? 1.5 : 1))
                .frame(width: 12)
                .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true } }
            VStack(alignment: .leading, spacing: 1) {
                Text(model.isRefreshing ? "Lecture en cours…" : "Données à jour")
                    .font(.ui(12, .semibold))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.ui(11))
                    .foregroundStyle(Theme.text3)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Menu {
                Section(account) {
                    Button { model.load(force: false) } label: { Label("Relire les sessions", systemImage: "arrow.clockwise") }
                    Button { model.importClaudeAIExport() } label: { Label("Importer un export claude.ai…", systemImage: "square.and.arrow.down") }
                    Button { model.showSources = true } label: { Label("Sources de données…", systemImage: "externaldrive") }
                }
                Divider()
                Button { model.rebuildCache() } label: { Label("Tout relire depuis zéro", systemImage: "arrow.triangle.2.circlepath") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.ui(13, .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Plus d'options")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .floatingSurface(radius: 12)
    }

    private var detail: String {
        if DemoData.isEnabled { return "Données fictives" }
        guard let d = model.lastLoad else { return "Analyse en cours" }
        return "Analysé \(Fmt.relative(d))"
    }

    private var account: String {
        let a = model.dataset.account
        return a.plan.isEmpty ? a.displayName : "\(a.displayName) · \(a.plan)"
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
                    .foregroundStyle(selected ? Theme.accent : Theme.text2)
                    .frame(width: 18)
                Text(title)
                    .font(.ui(13, selected ? .medium : .regular))
                    .foregroundStyle(selected ? Theme.text : Theme.text2)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background { SidebarHighlight(selected: selected, hovering: hovering) }
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
            HStack(spacing: 10) {
                Image(systemName: selected ? "folder.fill" : "folder")
                    .font(.ui(12))
                    .foregroundStyle(selected ? Theme.accent : Theme.text3)
                    .frame(width: 18)
                Text(project.name)
                    .font(.ui(13, selected ? .medium : .regular))
                    .foregroundStyle(selected ? Theme.text : Theme.text2)
                    .lineLimit(1)
                Spacer()
                Text(Fmt.hours(project.seconds))
                    .font(.ui(11.5))
                    .foregroundStyle(Theme.text3)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background { SidebarHighlight(selected: selected, hovering: hovering) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(project.paths.sorted().joined(separator: "\n"))
    }
}

private struct SidebarHighlight: View {
    var selected: Bool
    var hovering: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if selected {
            shape.fill(Theme.fill3).overlay(TopRim(radius: 8))
        } else if hovering {
            shape.fill(Theme.fill1)
        }
    }
}
