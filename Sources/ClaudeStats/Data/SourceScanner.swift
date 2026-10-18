import Foundation

/// Finds every place on this Mac where Claude keeps session data, and reads it.
enum SourceScanner {

    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    static var claudeDir: URL { home.appendingPathComponent(".claude") }
    static var desktopSupport: URL { home.appendingPathComponent("Library/Application Support/Claude") }

    struct TranscriptFile: Sendable {
        var url: URL
        var size: Int64
        var mtime: Double
        var source: SourceKind
        var isSubagent: Bool
    }

    /// Folders that hold Claude Code transcripts.
    static var transcriptRoots: [(URL, SourceKind?)] {
        var roots: [(URL, SourceKind?)] = [(claudeDir.appendingPathComponent("projects"), nil)]
        let xdg = home.appendingPathComponent(".config/claude/projects")
        if FileManager.default.fileExists(atPath: xdg.path) { roots.append((xdg, nil)) }
        if let env = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] {
            roots.append((URL(fileURLWithPath: env).appendingPathComponent("projects"), nil))
        }
        roots.append((desktopSupport.appendingPathComponent("local-agent-mode-sessions"), .cowork))
        return roots
    }

    static func listTranscripts() -> [TranscriptFile] {
        var files: [TranscriptFile] = []
        var seen = Set<String>()
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        for (root, forced) in transcriptRoots {
            guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: []) else { continue }
            for case let url as URL in en {
                guard url.pathExtension == "jsonl" else { continue }
                let path = url.path
                if forced == .cowork && !path.contains("/.claude/projects/") { continue }
                guard !seen.contains(path) else { continue }
                seen.insert(path)
                guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
                let size = Int64(v.fileSize ?? 0)
                if size == 0 { continue }
                files.append(TranscriptFile(
                    url: url, size: size,
                    mtime: v.contentModificationDate?.timeIntervalSince1970 ?? 0,
                    source: forced ?? .desktop,
                    isSubagent: path.contains("/subagents/")))
            }
        }
        return files
    }

    // MARK: Desktop metadata

    private struct MetaJ: Decodable {
        var sessionId: String?
        var cliSessionId: String?
        var title: String?
        var model: String?
        var effort: String?
        var isArchived: Bool?
        var scheduledTaskId: String?
        var forkedFromSessionId: String?
        var cwd: String?
        var createdAt: Double?
        var remoteMcpServersConfig: [McpJ]?
    }

    private struct McpJ: Decodable {
        var uuid: String?
        var name: String?
    }

    /// Names of claude.ai connectors (MCP servers are identified by UUID in tool names).
    nonisolated(unsafe) static var mcpNames: [String: String] = [:]

    static func loadDesktopMeta() -> [String: DesktopSessionMeta] {
        var out: [String: DesktopSessionMeta] = [:]
        let roots: [(URL, Bool)] = [
            (desktopSupport.appendingPathComponent("claude-code-sessions"), false),
            (desktopSupport.appendingPathComponent("local-agent-mode-sessions"), true)
        ]
        let decoder = JSONDecoder()
        for (root, cowork) in roots {
            guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in en {
                let name = url.lastPathComponent
                guard name.hasPrefix("local_"), name.hasSuffix(".json") else { continue }
                // Do not descend into session folders (they hold the VM copy of the transcripts).
                guard let data = try? Data(contentsOf: url),
                      let m = try? decoder.decode(MetaJ.self, from: data),
                      let cli = m.cliSessionId else { continue }
                for server in m.remoteMcpServersConfig ?? [] {
                    if let u = server.uuid, let n = server.name { mcpNames[u] = n }
                }
                let meta = DesktopSessionMeta(
                    cliSessionId: cli, title: m.title, model: m.model, effort: m.effort,
                    isArchived: m.isArchived ?? false, scheduledTaskId: m.scheduledTaskId,
                    forkedFrom: m.forkedFromSessionId, cwd: m.cwd,
                    createdAt: m.createdAt.map { $0 / 1000 }, isCowork: cowork)
                // Keep the non-fork entry if several point to the same transcript.
                if let existing = out[cli], existing.forkedFrom == nil, meta.forkedFrom != nil { continue }
                out[cli] = meta
            }
        }
        return out
    }

    // MARK: Plan usage & account

    private struct UsageFileJ: Decodable {
        struct Sample: Decodable {
            var t: Double
            var u: [String: Double]?
        }
        var samples: [Sample]?
    }

    static func loadUsageHistory() -> [UsageSample] {
        let url = desktopSupport.appendingPathComponent("plan-usage-history.json")
        guard let data = try? Data(contentsOf: url),
              let f = try? JSONDecoder().decode(UsageFileJ.self, from: data) else { return [] }
        return (f.samples ?? []).compactMap { s in
            guard let u = s.u else { return nil }
            return UsageSample(ts: s.t / 1000, fiveHour: u["fh"] ?? 0, weekly: u["sd"] ?? 0)
        }.sorted { $0.ts < $1.ts }
    }

    static func loadAccount() -> (AccountInfo, [(String, Int)]) {
        var info = AccountInfo(displayName: NSFullUserName().components(separatedBy: " ").first ?? "toi",
                               plan: "", firstStart: nil)
        var skills: [(String, Int)] = []
        let url = home.appendingPathComponent(".claude.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return (info, skills) }
        if let acc = obj["oauthAccount"] as? [String: Any] {
            if let n = acc["displayName"] as? String, !n.isEmpty { info.displayName = n }
            let type = (acc["organizationType"] as? String) ?? ""
            let tier = (acc["organizationRateLimitTier"] as? String) ?? ""
            info.plan = planLabel(type: type, tier: tier)
        }
        if let fs = obj["firstStartTime"] as? String, let ts = parseTimestamp(fs) {
            info.firstStart = Date(timeIntervalSince1970: ts)
        }
        if let su = obj["skillUsage"] as? [String: Any] {
            for (k, v) in su {
                if let d = v as? [String: Any], let c = d["usageCount"] as? Int, c > 0 { skills.append((k, c)) }
            }
            skills.sort { ($0.1, $1.0) > ($1.1, $0.0) }
        }
        return (info, skills)
    }

    static func planLabel(type: String, tier: String) -> String {
        if type.contains("max") {
            if tier.contains("20x") { return "Max 20x" }
            if tier.contains("5x") { return "Max 5x" }
            return "Max"
        }
        if type.contains("pro") { return "Pro" }
        if type.contains("team") { return "Team" }
        if type.contains("enterprise") { return "Enterprise" }
        return type.isEmpty ? "" : type.capitalized
    }
}

// MARK: - Cache

enum SummaryCache {
    static let version = 5

    private struct Envelope: Codable {
        var version: Int
        var files: [FileSummary]
    }

    static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaudeStats", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("transcripts-cache.json")
    }

    static func load() -> [String: FileSummary] {
        guard let data = try? Data(contentsOf: url),
              let env = try? JSONDecoder().decode(Envelope.self, from: data),
              env.version == version else { return [:] }
        var out: [String: FileSummary] = [:]
        for f in env.files { out[f.path] = f }
        return out
    }

    static func save(_ files: [FileSummary]) {
        guard let data = try? JSONEncoder().encode(Envelope(version: version, files: files)) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Loading pipeline

struct RawData: Sendable {
    var files: [FileSummary]
    var meta: [String: DesktopSessionMeta]
    var usage: [UsageSample]
    var account: AccountInfo
    var skills: [(String, Int)]
    var chats: [ChatConversation]
    var scannedBytes: Int64
    var parsedFiles: Int
}

enum Loader {
    /// Reads everything, reusing cached summaries of unchanged files. `progress` gets (done, total).
    static func load(forceRescan: Bool, progress: @escaping @Sendable (Int, Int) -> Void) -> RawData {
        let list = SourceScanner.listTranscripts()
        let cache = forceRescan ? [:] : SummaryCache.load()

        var results = [FileSummary?](repeating: nil, count: list.count)
        var toParse: [Int] = []
        for (i, f) in list.enumerated() {
            if let c = cache[f.url.path], c.size == f.size, abs(c.mtime - f.mtime) < 0.001 {
                results[i] = c
            } else {
                toParse.append(i)
            }
        }
        // Biggest files first for better load balancing.
        toParse.sort { list[$0].size > list[$1].size }

        let lock = NSLock()
        var done = list.count - toParse.count
        let total = list.count
        progress(done, total)
        let parsedBytes = toParse.reduce(Int64(0)) { $0 + list[$1].size }

        results.withUnsafeMutableBufferPointer { buf in
            let ptr = buf
            DispatchQueue.concurrentPerform(iterations: toParse.count) { k in
                let i = toParse[k]
                let f = list[i]
                let s = autoreleasepool {
                    TranscriptParser.parse(url: f.url, source: f.source, isSubagent: f.isSubagent,
                                           size: f.size, mtime: f.mtime)
                }
                lock.lock()
                ptr[i] = s
                done += 1
                let d = done
                lock.unlock()
                if d % 8 == 0 || d == total { progress(d, total) }
            }
        }
        let files = results.compactMap { $0 }
        if !toParse.isEmpty || cache.count != files.count { SummaryCache.save(files) }

        let (account, skills) = SourceScanner.loadAccount()
        return RawData(files: files,
                       meta: SourceScanner.loadDesktopMeta(),
                       usage: SourceScanner.loadUsageHistory(),
                       account: account, skills: skills,
                       chats: ChatImport.loadStored(),
                       scannedBytes: parsedBytes,
                       parsedFiles: toParse.count)
    }
}
