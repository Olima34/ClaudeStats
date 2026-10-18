import Foundation

@main
enum Entry {
    static func main() {
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot") {
            let dir = CommandLine.arguments.count > i + 1 ? CommandLine.arguments[i + 1] : "."
            MainActor.assumeIsolated { Snapshot.run(dir: dir) }
            return
        }
        if CommandLine.arguments.contains("--dump") {
            Diagnostics.run(force: CommandLine.arguments.contains("--force"))
            return
        }
        ClaudeStatsApp.main()
    }
}

/// `ClaudeStats --dump [--force] [--demo]` prints a summary of what the app computes, for checking numbers.
enum Diagnostics {
    static func run(force: Bool) {
        let t0 = Date()
        let raw = DemoData.isEnabled ? DemoData.make() : Loader.load(forceRescan: force) { _, _ in }
        let t1 = Date()
        let ds = Dataset.build(raw, overrides: [:])
        let t2 = Date()
        let s = StatsEngine.compute(ds, filter: StatsFilter())
        let t3 = Date()
        print("load \(String(format: "%.2f", t1.timeIntervalSince(t0)))s (parsed \(raw.parsedFiles) files, \(raw.scannedBytes / 1_000_000) MB) · build \(String(format: "%.2f", t2.timeIntervalSince(t1)))s · stats \(String(format: "%.3f", t3.timeIntervalSince(t2)))s")
        print("files \(ds.fileCount) sessions \(ds.sessions.count) prompts \(ds.prompts.count) messages \(ds.messages.count) segments \(ds.segments.count)")
        print("stats: sessions \(s.sessionCount) prompts \(s.promptCount) replies \(s.messageCount) activeDays \(s.activeDays) span \(s.spanDays)")
        print("active \(Fmt.duration(s.activeSeconds)) claude \(Fmt.duration(s.claudeSeconds)) thinking \(Fmt.duration(s.thinkingSeconds)) avgTurn \(Fmt.duration(s.avgTurnSeconds))")
        print("tokens in \(s.tokens.input) out \(s.tokens.output) cr \(s.tokens.cacheRead) cw \(s.tokens.cacheWrite) cost \(Fmt.money(s.cost)) hit \(Fmt.pct(s.tokens.cacheHitRate))")
        print("lines +\(s.linesAdded) -\(s.linesRemoved) files \(s.filesTouched) tools \(s.toolCalls) bash \(s.bashCommands) agents \(s.agentsLaunched) workflows \(s.workflows) web \(s.webSearches)/\(s.webFetches)")
        print("streak cur \(s.streakCurrent) longest \(s.streakLongest) peakHour \(s.peakHour) peakWd \(s.peakWeekday) night \(s.nightPrompts) weekend \(Fmt.pct(s.weekendShare))")
        print("markers: interrupts \(s.interruptions) compact \(s.compactions) apiErr \(s.apiErrors) limits \(s.usageLimitHits) scheduled \(s.scheduledRuns)")
        print("sources", s.sources.map { "\($0.name)=\($0.count)" })
        print("projects", s.projects.prefix(12).map { "\($0.name) \(Fmt.hours($0.seconds)) \($0.sessions)s \($0.mainCategory.rawValue)" })
        print("categories", s.categories.map { "\($0.category.rawValue) \(Fmt.hours($0.seconds)) \($0.sessions)s" })
        print("models", s.models.map { "\($0.label) \($0.messages) \(Fmt.money($0.cost))" })
        print("tools", s.tools.prefix(10).map { "\($0.name)=\($0.count)" })
        print("families", s.toolFamilies.map { "\($0.name)=\($0.count)" })
        print("shell", s.shellVerbs.prefix(10).map { "\($0.name)=\($0.count)" })
        print("langs code", s.codeLanguages.prefix(8).map { "\($0.name)=\($0.count)" })
        print("mcp", s.mcpServers.prefix(8).map { "\($0.name)=\($0.count)" })
        print("skills", s.skills.prefix(8).map { "\($0.name)=\($0.count)" })
        let st = s.style
        print("style: words \(st.totalWords) avg \(Fmt.dec(st.avgWords)) q \(st.questions) thanks \(st.thanks) please \(st.please) greet \(st.greetings) short \(st.shortReplies) img \(st.images) cmds \(st.commandCount) shell \(st.shellTyped) claudeWords \(st.claudeWords)")
        print("languages", st.languages.map { "\($0.name)=\($0.count)" })
        print("top words", st.words.prefix(30).map { "\($0.name)=\($0.count)" })
        print("commands", st.commands.prefix(8).map { "\($0.name)=\($0.count)" })
        print("openers", st.topOpeners.map { "\($0.name)=\($0.count)" })
        print("persona", Insights.persona(s).title, "|", Insights.persona(s).summary)
        print("records: longest \(s.records.longestSession.map { "\($0.title) \(Fmt.duration($0.seconds))" } ?? "-")")
        print("         busiest \(s.records.busiestSession.map { "\($0.title) \($0.prompts)" } ?? "-")")
        print("         biggestDay \(s.records.biggestDay.map { "\(Fmt.day($0.date)) \($0.prompts)" } ?? "-")")
        print("         latest \(s.records.latestPrompt.map { Fmt.full(Fmt.ts($0.ts)) } ?? "-")  earliest \(s.records.earliestPrompt.map { Fmt.full(Fmt.ts($0.ts)) } ?? "-")")
        print("usage samples \(ds.usage.count) account \(ds.account.displayName) \(ds.account.plan)")
        if CommandLine.arguments.contains("--ids") {
            for x in ds.sessions { print("ID", x.id) }
        }
        print("sample sessions:")
        for r in s.sessions.prefix(15) {
            print("  [\(r.category.rawValue)] \(r.title.prefix(60)) | \(r.project) | \(r.prompts)p \(Fmt.duration(r.seconds)) \(r.source.rawValue)")
        }
    }
}

import SwiftUI
import AppKit

/// `ClaudeStats --snapshot <dir> [--light] [--period week|month|…] [--page overview] [--scale 2] [--demo]` renders every page to PNG files.
/// With `--demo`, the pages show the fictional demo data instead of what is on this Mac.
@MainActor
enum Snapshot {
    static func run(dir: String) {
        _ = NSApplication.shared
        let light = CommandLine.arguments.contains("--light")
        let appearance = NSAppearance(named: light ? .aqua : .darkAqua)!
        NSApp.appearance = appearance
        let raw = DemoData.isEnabled ? DemoData.make() : Loader.load(forceRescan: false) { _, _ in }
        let model = AppModel(autoload: false)
        model.apply(raw: raw)
        if let i = CommandLine.arguments.firstIndex(of: "--period"), CommandLine.arguments.count > i + 1,
           let p = Period(rawValue: CommandLine.arguments[i + 1]) {
            model.stats = StatsEngine.compute(model.dataset, filter: StatsFilter(period: p))
        }
        let only = CommandLine.arguments.firstIndex(of: "--page").flatMap { i in
            CommandLine.arguments.count > i + 1 ? Page(rawValue: CommandLine.arguments[i + 1]) : nil
        }
        let scale = CommandLine.arguments.firstIndex(of: "--scale").flatMap { i in
            CommandLine.arguments.count > i + 1 ? Double(CommandLine.arguments[i + 1]) : nil
        } ?? 1
        if CommandLine.arguments.contains("--select") {
            model.selectedSession = model.stats.sessions.first(where: { $0.prompts > 3 })?.id
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for page in Page.allCases where only == nil || only == page {
            model.page = page
            let view = PageView(page: page)
                .environmentObject(model)
                .frame(width: 1180)
                .padding(32)
                .background(Theme.bg)
                .environment(\.colorScheme, light ? .light : .dark)
            appearance.performAsCurrentDrawingAppearance {
                let r = ImageRenderer(content: view)
                r.scale = scale
                guard let cg = r.cgImage,
                      let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
                    print("failed \(page.rawValue)")
                    return
                }
                let url = URL(fileURLWithPath: dir).appendingPathComponent("\(page.rawValue).png")
                try? png.write(to: url)
                print("wrote \(url.path) \(cg.width)x\(cg.height)")
            }
        }
    }
}
