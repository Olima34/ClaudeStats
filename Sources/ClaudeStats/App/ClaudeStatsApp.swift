import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}


struct ClaudeStatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("ClaudeStats", id: "main") {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 1080, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1380, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Données") {
                Button("Rafraîchir") { model.load(force: false) }
                    .keyboardShortcut("r")
                Button("Importer un export claude.ai…") { model.importClaudeAIExport() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Sources de données…") { model.showSources = true }
                Divider()
                Button("Tout relire depuis zéro") { model.rebuildCache() }
            }
            CommandMenu("Aller à") {
                Button("Rechercher…") { model.showPalette = true }
                    .keyboardShortcut("k")
                Button("Page précédente") { model.goBack() }
                    .keyboardShortcut("[")
                Button("Page suivante") { model.goForward() }
                    .keyboardShortcut("]")
                Divider()
                ForEach(Array(Page.allCases.enumerated()), id: \.element) { i, p in
                    if i < 9 {
                        Button(p.title) { model.page = p }
                            .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
                    } else {
                        Button(p.title) { model.page = p }
                    }
                }
            }
        }

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(model)
        } label: {
            Image(systemName: "sparkle")
        }
        .menuBarExtraStyle(.window)
    }
}
