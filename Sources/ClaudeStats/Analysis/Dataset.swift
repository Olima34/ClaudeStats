import Foundation

/// A Claude session (a Claude Code session, a Cowork task or an imported chat).
struct Session: Identifiable, Sendable {
    let id: String
    var index: Int
    var title: String
    var project: String
    var cwd: String
    var source: SourceKind
    var category: Category
    var autoCategory: Category
    var start: Double
    var end: Double
    var model: String
    var isArchived: Bool
    var isScheduled: Bool
    var isFork: Bool
    var branch: String?
    var firstPrompt: String
}

struct Prompt: Sendable {
    var session: Int
    var ts: Double
    var text: String
    var kind: PromptKind
    var images: Int
    var command: String?
    var words: Int
    var lang: Lang
    /// Time between this prompt and Claude's last reply before the next prompt.
    var turnSeconds: Double
}

struct Message: Sendable {
    var session: Int
    var ts: Double
    var model: String
    var input: Int
    var output: Int
    var cacheRead: Int
    var cacheWrite: Int
    var cost: Double
    var thinkMs: Int
    var textChars: Int
    var tools: [ToolRec]
    var sidechain: Bool

    var totalTokens: Int { input + output + cacheRead + cacheWrite }
}

/// A burst of continuous activity inside a session (no gap longer than the idle threshold).
struct Segment: Sendable {
    var session: Int
    var start: Double
    var duration: Double
}

struct Marker: Sendable {
    var session: Int
    var ts: Double
    var kind: MarkerKind
}

final class Dataset: @unchecked Sendable {
    var sessions: [Session] = []
    var prompts: [Prompt] = []
    var messages: [Message] = []
    var segments: [Segment] = []
    var markers: [Marker] = []
    var usage: [UsageSample] = []
    var account = AccountInfo(displayName: "toi", plan: "", firstStart: nil)
    var skills: [(String, Int)] = []
    var fileCount = 0
    var totalBytes: Int64 = 0
    var chatCount = 0

    var isEmpty: Bool { sessions.isEmpty }
    var firstTs: Double { min(prompts.first?.ts ?? .infinity, messages.first?.ts ?? .infinity) }
    var lastTs: Double { max(prompts.last?.ts ?? 0, messages.last?.ts ?? 0) }

    static let idleThreshold: Double = 15 * 60

    // MARK: Build

    static func build(_ raw: RawData, overrides: [String: Category]) -> Dataset {
        let ds = Dataset()
        ds.usage = raw.usage
        ds.account = raw.account
        ds.skills = raw.skills
        ds.fileCount = raw.files.count
        ds.totalBytes = raw.files.reduce(0) { $0 + $1.size }
        ds.chatCount = raw.chats.count

        // 1. Deduplicate prompts (forked sessions copy their parent's lines).
        var promptById: [String: PromptRec] = [:]
        var assistantByUuid: [String: AssistantRec] = [:]
        var hints: [String: SessionHint] = [:]
        var sessionSource: [String: SourceKind] = [:]
        var markerRecs: [MarkerRec] = []
        for f in raw.files {
            for p in f.prompts where promptById[p.id] == nil { promptById[p.id] = p }
            for a in f.assistants where assistantByUuid[a.uuid] == nil { assistantByUuid[a.uuid] = a }
            markerRecs.append(contentsOf: f.markers)
            for h in f.hints {
                if var e = hints[h.session] {
                    if e.cwd == nil { e.cwd = h.cwd }
                    if e.entrypoint == nil { e.entrypoint = h.entrypoint }
                    if e.title == nil { e.title = h.title }
                    if e.gitBranch == nil { e.gitBranch = h.gitBranch }
                    hints[h.session] = e
                } else {
                    hints[h.session] = h
                }
                if f.source == .cowork { sessionSource[h.session] = .cowork }
            }
        }

        // 2. Merge assistant lines into messages.
        struct MsgAcc {
            var rec: AssistantRec
            var tools: [ToolRec]
            var textChars: Int
            var thinkMs: Int
        }
        var msgById: [String: MsgAcc] = [:]
        for a in assistantByUuid.values {
            if var m = msgById[a.msgId] {
                m.tools.append(contentsOf: a.tools)
                m.textChars += a.textChars
                m.thinkMs = max(m.thinkMs, a.thinkMs)
                if a.ts < m.rec.ts { m.rec.ts = a.ts }
                m.rec.input = max(m.rec.input, a.input)
                m.rec.output = max(m.rec.output, a.output)
                m.rec.cacheRead = max(m.rec.cacheRead, a.cacheRead)
                m.rec.cacheWrite = max(m.rec.cacheWrite, a.cacheWrite)
                m.rec.cacheWrite1h = max(m.rec.cacheWrite1h, a.cacheWrite1h)
                msgById[a.msgId] = m
            } else {
                msgById[a.msgId] = MsgAcc(rec: a, tools: a.tools, textChars: a.textChars, thinkMs: a.thinkMs)
            }
        }

        // 3. Sessions.
        var sessionIndex: [String: Int] = [:]
        var sessions: [Session] = []
        func sessionIdx(_ id: String) -> Int {
            if let i = sessionIndex[id] { return i }
            let i = sessions.count
            sessionIndex[id] = i
            sessions.append(Session(id: id, index: i, title: "", project: "", cwd: "", source: .desktop,
                                    category: .other, autoCategory: .other, start: .infinity, end: 0, model: "",
                                    isArchived: false, isScheduled: false, isFork: false, branch: nil, firstPrompt: ""))
            return i
        }

        var prompts: [Prompt] = []
        prompts.reserveCapacity(promptById.count)
        for p in promptById.values {
            let toks = Words.tokens(p.text)
            prompts.append(Prompt(session: sessionIdx(p.session), ts: p.ts, text: p.text, kind: p.kind, images: p.images,
                                  command: p.command, words: toks.count,
                                  lang: p.kind == .human ? TextStats.language(toks) : .other, turnSeconds: 0))
        }
        var messages: [Message] = []
        messages.reserveCapacity(msgById.count)
        for m in msgById.values {
            let r = m.rec
            messages.append(Message(session: sessionIdx(r.session), ts: r.ts, model: r.model, input: r.input,
                                    output: r.output, cacheRead: r.cacheRead, cacheWrite: r.cacheWrite,
                                    cost: Pricing.cost(model: r.model, input: r.input, output: r.output,
                                                       cacheRead: r.cacheRead, cacheWrite: r.cacheWrite,
                                                       cacheWrite1h: r.cacheWrite1h),
                                    thinkMs: m.thinkMs, textChars: m.textChars, tools: m.tools, sidechain: r.sidechain))
        }

        // 3b. Imported claude.ai chats.
        for c in raw.chats {
            let sid = "chat-" + c.uuid
            let si = sessionIdx(sid)
            sessionSource[sid] = .chat
            hints[sid] = SessionHint(session: sid, cwd: "", entrypoint: "claude.ai", title: c.name, gitBranch: nil)
            for m in c.messages {
                if m.human {
                    let toks = Words.tokens(m.text)
                    prompts.append(Prompt(session: si, ts: m.ts, text: m.text, kind: .human, images: m.attachments,
                                          command: nil, words: toks.count, lang: TextStats.language(toks), turnSeconds: 0))
                } else {
                    messages.append(Message(session: si, ts: m.ts, model: "claude.ai", input: 0, output: 0,
                                            cacheRead: 0, cacheWrite: 0, cost: 0, thinkMs: 0,
                                            textChars: m.text.count, tools: [], sidechain: false))
                }
            }
        }

        prompts.sort { $0.ts < $1.ts }
        messages.sort { $0.ts < $1.ts }

        var seenMarkers = Set<String>()
        for r in markerRecs {
            let key = "\(r.session)|\(r.kind.rawValue)|\(Int(r.ts))"
            guard seenMarkers.insert(key).inserted else { continue }
            // Markers of sessions with no real activity (e.g. a scheduled run that hit the limit) are kept with index -1.
            ds.markers.append(Marker(session: sessionIndex[r.session] ?? -1, ts: r.ts, kind: r.kind))
        }
        ds.markers.sort { $0.ts < $1.ts }

        // 4. Per-session details.
        var promptsBySession = [[Int]](repeating: [], count: sessions.count)
        for (i, p) in prompts.enumerated() { promptsBySession[p.session].append(i) }
        var messagesBySession = [[Int]](repeating: [], count: sessions.count)
        for (i, m) in messages.enumerated() { messagesBySession[m.session].append(i) }

        var segments: [Segment] = []
        for si in sessions.indices {
            let id = sessions[si].id
            let h = hints[id]
            let meta = raw.meta[id]
            var s = sessions[si]
            let pIdx = promptsBySession[si]
            let mIdx = messagesBySession[si]

            s.cwd = h?.cwd ?? meta?.cwd ?? ""
            s.branch = h?.gitBranch
            if let src = sessionSource[id] {
                s.source = src
            } else if meta?.isCowork == true {
                s.source = .cowork
            } else if let e = h?.entrypoint, e == "cli" || e.contains("vscode") || e.contains("jetbrains") {
                s.source = .cli
            } else {
                s.source = .desktop
            }
            s.project = s.source == .chat ? "Chat claude.ai" : projectName(s.cwd, cowork: s.source == .cowork)
            s.isArchived = meta?.isArchived ?? false
            s.isFork = meta?.forkedFrom != nil
            s.isScheduled = meta?.scheduledTaskId != nil

            let humanTexts = pIdx.compactMap { prompts[$0].kind == .human ? prompts[$0].text : nil }
            s.firstPrompt = humanTexts.first ?? ""
            let fallbackTitle = humanTexts.first.map { snippet($0, 70) } ?? "Session sans titre"
            s.title = (meta?.title).flatMap { $0.isEmpty ? nil : $0 } ?? h?.title ?? fallbackTitle

            var times: [Double] = pIdx.map { prompts[$0].ts }
            times.append(contentsOf: mIdx.compactMap { messages[$0].sidechain ? nil : messages[$0].ts })
            times.sort()
            s.start = times.first ?? 0
            s.end = times.last ?? 0

            var modelCount: [String: Int] = [:]
            var toolCount: [String: Int] = [:]
            var extCount: [String: Int] = [:]
            for mi in mIdx {
                let m = messages[mi]
                if !m.sidechain { modelCount[m.model, default: 0] += 1 }
                for t in m.tools {
                    toolCount[t.name, default: 0] += 1
                    if let f = t.file, t.add > 0 || t.del > 0 {
                        let ext = (f as NSString).pathExtension.lowercased()
                        if !ext.isEmpty { extCount[ext, default: 0] += 1 }
                    }
                }
            }
            s.model = modelCount.max(by: { ($0.value, $1.key) < ($1.value, $0.key) })?.key ?? (meta?.model ?? "")
            s.autoCategory = Categorizer.classify(title: s.title, prompts: humanTexts, cwd: s.cwd,
                                                  tools: toolCount, extensions: extCount)
            s.category = overrides[id] ?? s.autoCategory
            sessions[si] = s

            // Activity segments.
            if var segStart = times.first {
                var last = segStart
                for t in times.dropFirst() {
                    if t - last > idleThreshold {
                        segments.append(Segment(session: si, start: segStart, duration: last - segStart + 60))
                        segStart = t
                    }
                    last = t
                }
                segments.append(Segment(session: si, start: segStart, duration: last - segStart + 60))
            }

            // Turn durations: how long Claude kept working after each prompt (pauses over 15 min excluded).
            let mainTimes = mIdx.compactMap { messages[$0].sidechain ? nil : messages[$0].ts }
            var j = 0
            for (k, pi) in pIdx.enumerated() {
                let t0 = prompts[pi].ts
                let t1 = k + 1 < pIdx.count ? prompts[pIdx[k + 1]].ts : .infinity
                while j < mainTimes.count && mainTimes[j] <= t0 { j += 1 }
                var last = t0, busy = 0.0, jj = j
                while jj < mainTimes.count && mainTimes[jj] < t1 {
                    let gap = mainTimes[jj] - last
                    if gap <= idleThreshold { busy += gap }
                    last = mainTimes[jj]
                    jj += 1
                }
                prompts[pi].turnSeconds = busy
            }
        }

        // Drop sessions with no visible activity.
        ds.sessions = sessions
        ds.prompts = prompts
        ds.messages = messages
        ds.segments = segments.sorted { $0.start < $1.start }
        return ds
    }

    static func projectName(_ cwd: String, cowork: Bool) -> String {
        if cowork || cwd.hasPrefix("/sessions/") { return "Cowork" }
        if cwd.isEmpty { return "Sans dossier" }
        var path = cwd
        for marker in ["/.claude/worktrees/", "/.worktrees/", "/.claude-worktrees/"] {
            if let r = path.range(of: marker) { path = String(path[..<r.lowerBound]) }
        }
        if path.hasPrefix("/private/tmp") || path.hasPrefix("/tmp") || path.contains("/T/") || path.contains("scratchpad") {
            return "Temporaire"
        }
        if path == NSHomeDirectory() { return "Dossier personnel" }
        if path == "/" { return "Racine du Mac" }
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? path : name
    }

    static func snippet(_ s: String, _ n: Int) -> String {
        let one = s.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return one.count > n ? String(one.prefix(n)).trimmingCharacters(in: .whitespaces) + "…" : one
    }
}
