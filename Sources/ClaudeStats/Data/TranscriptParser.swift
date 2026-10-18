import Foundation

// MARK: - Lenient JSON shapes

extension KeyedDecodingContainer {
    /// Decodes a value if present and of the right type, never throws.
    func opt<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}

private struct DynKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

private struct UserLine: Decodable {
    var type: String?
    var uuid: String?
    var sessionId: String?
    var timestamp: String?
    var cwd: String?
    var entrypoint: String?
    var gitBranch: String?
    var isMeta: Bool?
    var isSidechain: Bool?
    var isCompactSummary: Bool?
    var originKind: String?
    var content: UContent?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynKey.self)
        type = c.opt(DynKey("type"))
        uuid = c.opt(DynKey("uuid"))
        sessionId = c.opt(DynKey("sessionId"))
        timestamp = c.opt(DynKey("timestamp"))
        cwd = c.opt(DynKey("cwd"))
        entrypoint = c.opt(DynKey("entrypoint"))
        gitBranch = c.opt(DynKey("gitBranch"))
        isMeta = c.opt(DynKey("isMeta"))
        isSidechain = c.opt(DynKey("isSidechain"))
        isCompactSummary = c.opt(DynKey("isCompactSummary"))
        if let o = try? c.nestedContainer(keyedBy: DynKey.self, forKey: DynKey("origin")) {
            originKind = o.opt(DynKey("kind"))
        }
        if let m = try? c.nestedContainer(keyedBy: DynKey.self, forKey: DynKey("message")) {
            content = m.opt(DynKey("content"))
        }
    }
}

private enum UContent: Decodable {
    case text(String)
    case blocks([UBlock])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            self = .text(s)
        } else if let b = try? c.decode([UBlock].self) {
            self = .blocks(b)
        } else {
            self = .text("")
        }
    }
}

private struct UBlock: Decodable {
    var type: String?
    var text: String?
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynKey.self)
        type = c.opt(DynKey("type"))
        text = c.opt(DynKey("text"))
    }
}

private struct AssistantLine: Decodable {
    var uuid: String?
    var sessionId: String?
    var timestamp: String?
    var cwd: String?
    var entrypoint: String?
    var gitBranch: String?
    var isSidechain: Bool?
    var thinkingDurationMs: Double?
    var id: String?
    var model: String?
    var blocks: [ABlock]
    var usage: UsageJ?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynKey.self)
        uuid = c.opt(DynKey("uuid"))
        sessionId = c.opt(DynKey("sessionId"))
        timestamp = c.opt(DynKey("timestamp"))
        cwd = c.opt(DynKey("cwd"))
        entrypoint = c.opt(DynKey("entrypoint"))
        gitBranch = c.opt(DynKey("gitBranch"))
        isSidechain = c.opt(DynKey("isSidechain"))
        thinkingDurationMs = c.opt(DynKey("thinkingDurationMs"))
        blocks = []
        if let m = try? c.nestedContainer(keyedBy: DynKey.self, forKey: DynKey("message")) {
            id = m.opt(DynKey("id"))
            model = m.opt(DynKey("model"))
            blocks = m.opt(DynKey("content")) ?? []
            usage = m.opt(DynKey("usage"))
        }
    }
}

private struct UsageJ: Decodable {
    var input: Int = 0
    var output: Int = 0
    var cacheWrite: Int = 0
    var cacheRead: Int = 0
    var cacheWrite1h: Int = 0

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynKey.self)
        input = c.opt(DynKey("input_tokens")) ?? 0
        output = c.opt(DynKey("output_tokens")) ?? 0
        cacheWrite = c.opt(DynKey("cache_creation_input_tokens")) ?? 0
        cacheRead = c.opt(DynKey("cache_read_input_tokens")) ?? 0
        if let cc = try? c.nestedContainer(keyedBy: DynKey.self, forKey: DynKey("cache_creation")) {
            cacheWrite1h = cc.opt(DynKey("ephemeral_1h_input_tokens")) ?? 0
        }
    }
}

private struct ABlock: Decodable {
    var type: String?
    var text: String?
    var thinking: String?
    var name: String?
    var input: ToolInputJ?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynKey.self)
        type = c.opt(DynKey("type"))
        text = c.opt(DynKey("text"))
        thinking = c.opt(DynKey("thinking"))
        name = c.opt(DynKey("name"))
        input = c.opt(DynKey("input"))
    }
}

private struct ToolInputJ: Decodable {
    var filePath: String?
    var oldString: String?
    var newString: String?
    var content: String?
    var newSource: String?
    var command: String?
    var subagentType: String?
    var skill: String?
    var url: String?
    var query: String?
    var edits: [(String, String)] = []

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynKey.self)
        filePath = c.opt(DynKey("file_path")) ?? c.opt(DynKey("notebook_path"))
        oldString = c.opt(DynKey("old_string"))
        newString = c.opt(DynKey("new_string"))
        content = c.opt(DynKey("content"))
        newSource = c.opt(DynKey("new_source"))
        command = c.opt(DynKey("command"))
        subagentType = c.opt(DynKey("subagent_type"))
        skill = c.opt(DynKey("skill"))
        url = c.opt(DynKey("url"))
        query = c.opt(DynKey("query"))
        if var arr = try? c.nestedUnkeyedContainer(forKey: DynKey("edits")) {
            while !arr.isAtEnd {
                guard let e = try? arr.nestedContainer(keyedBy: DynKey.self) else { break }
                edits.append((e.opt(DynKey("old_string")) ?? "", e.opt(DynKey("new_string")) ?? ""))
            }
        }
    }
}

private struct SmallLine: Decodable {
    var type: String?
    var subtype: String?
    var sessionId: String?
    var timestamp: String?
    var customTitle: String?
    var agentName: String?
}

// MARK: - Byte patterns

private enum Pat {
    static let userToolUseId = Array(#""message":{"role":"user","content":[{"tool_use_id""#.utf8)
    static let userToolResult = Array(#""message":{"role":"user","content":[{"type":"tool_result""#.utf8)
    static let userMsg = Array(#""message":{"role":"user""#.utf8)
    static let roleAssistant = Array(#""role":"assistant""#.utf8)
    static let customTitle = Array(#"{"type":"custom-title""#.utf8)
    static let agentName = Array(#"{"type":"agent-name""#.utf8)
    static let typeSystem = Array(#""type":"system""#.utf8)
    static let compactBoundary = Array(#""compact_boundary""#.utf8)
    static let apiError = Array(#""api_error""#.utf8)
}

@inline(__always)
private func contains(_ p: UnsafePointer<UInt8>, _ len: Int, _ pat: [UInt8]) -> Bool {
    pat.withUnsafeBufferPointer { pp in
        memmem(p, len, pp.baseAddress!, pat.count) != nil
    }
}

@inline(__always)
private func hasPrefix(_ p: UnsafePointer<UInt8>, _ len: Int, _ pat: [UInt8]) -> Bool {
    guard len >= pat.count else { return false }
    return pat.withUnsafeBufferPointer { pp in memcmp(p, pp.baseAddress!, pat.count) == 0 }
}

// MARK: - Timestamps

@inline(__always)
func daysFromCivil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
    let y = m <= 2 ? y0 - 1 : y0
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let mp = (m + 9) % 12
    let doy = (153 * mp + 2) / 5 + d - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146097 + doe - 719468
}

/// Fast ISO-8601 parser ("2026-10-06T22:20:39.213Z") returning a Unix timestamp.
func parseTimestamp(_ str: String?) -> Double? {
    guard var s = str else { return nil }
    return s.withUTF8 { b -> Double? in
        guard b.count >= 19 else { return nil }
        func num(_ i: Int, _ n: Int) -> Int {
            var r = 0
            for k in i..<(i + n) { r = r * 10 + Int(b[k] &- 48) }
            return r
        }
        let y = num(0, 4), mo = num(5, 2), d = num(8, 2)
        let h = num(11, 2), mi = num(14, 2), se = num(17, 2)
        var frac = 0.0
        var i = 19
        if i < b.count && b[i] == UInt8(ascii: ".") {
            i += 1
            var scale = 0.1
            while i < b.count, b[i] >= 48, b[i] <= 57 {
                frac += Double(b[i] - 48) * scale
                scale /= 10
                i += 1
            }
        }
        var offset = 0
        if i + 6 <= b.count, b[i] == UInt8(ascii: "+") || b[i] == UInt8(ascii: "-") {
            let sign = b[i] == UInt8(ascii: "+") ? 1 : -1
            offset = sign * (num(i + 1, 2) * 3600 + num(i + 4, 2) * 60)
        }
        let days = daysFromCivil(y, mo, d)
        return Double(days * 86400 + h * 3600 + mi * 60 + se - offset) + frac
    }
}

// MARK: - Text helpers

enum TextClean {
    static func lineCount(_ s: String) -> Int {
        if s.isEmpty { return 0 }
        var n = 1
        for c in s.utf8 where c == 10 { n += 1 }
        if s.utf8.last == 10 { n -= 1 }
        return n
    }

    /// Lines added / removed by replacing `old` with `new`, ignoring the shared leading and trailing lines.
    static func diffCounts(old: String, new: String) -> (add: Int, del: Int) {
        if old.isEmpty { return (lineCount(new), 0) }
        if new.isEmpty { return (0, lineCount(old)) }
        let o = old.split(separator: "\n", omittingEmptySubsequences: false)
        let n = new.split(separator: "\n", omittingEmptySubsequences: false)
        var pre = 0
        while pre < o.count && pre < n.count && o[pre] == n[pre] { pre += 1 }
        var suf = 0
        while suf < o.count - pre && suf < n.count - pre && o[o.count - 1 - suf] == n[n.count - 1 - suf] { suf += 1 }
        return (max(0, n.count - pre - suf), max(0, o.count - pre - suf))
    }

    static func removeBlocks(_ s: String, tag: String) -> String {
        var out = s
        let open = "<\(tag)"
        let close = "</\(tag)>"
        while let r = out.range(of: open) {
            if let e = out.range(of: close, range: r.upperBound..<out.endIndex) {
                out.removeSubrange(r.lowerBound..<e.upperBound)
            } else {
                out.removeSubrange(r.lowerBound..<out.endIndex)
            }
        }
        return out
    }

    static func between(_ s: String, _ a: String, _ b: String) -> String? {
        guard let r = s.range(of: a), let e = s.range(of: b, range: r.upperBound..<s.endIndex) else { return nil }
        return String(s[r.upperBound..<e.lowerBound])
    }

    /// Strips machine-added wrappers from a user prompt so only what the person wrote remains.
    static func cleanPrompt(_ t: String) -> String {
        var s = t
        if s.contains("<") {
            for tag in ["system-reminder", "uploaded_files", "attachments", "ide_selection", "ide_opened_file"] {
                if s.contains("<\(tag)") { s = removeBlocks(s, tag: tag) }
            }
        }
        if s.contains("[Image") {
            s = s.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.hasPrefix("[Image") }
                .joined(separator: "\n")
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count > 12000 { s = String(s.prefix(12000)) }
        return s
    }

    static let systemPrefixes: [String] = [
        "<task-notification>", "<local-command", "<bash-stdout>", "<bash-stderr>",
        "This session is being continued", "Base directory for this skill", "Another Claude session",
        "Caveat:", "<system-reminder>", "[Usage limit reached", "[Earlier usage-limit",
        "<user-prompt-submit-hook>", "<artifact-content", "<side-sessions-event>", "<ci-monitor-event>",
        "<channel-message", "<command-message>"
    ]
}

// MARK: - Parser

enum TranscriptParser {

    static func parse(url: URL, source: SourceKind, isSubagent: Bool, size: Int64, mtime: Double) -> FileSummary {
        var summary = FileSummary(path: url.path, size: size, mtime: mtime, source: source, isSubagent: isSubagent,
                                  prompts: [], assistants: [], markers: [], hints: [])
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return summary }
        let decoder = JSONDecoder()
        var hints: [String: SessionHint] = [:]

        func hint(_ session: String, cwd: String?, entrypoint: String?, branch: String?) {
            if var h = hints[session] {
                if h.cwd == nil { h.cwd = cwd }
                if h.entrypoint == nil { h.entrypoint = entrypoint }
                if h.gitBranch == nil, let branch, branch != "HEAD" { h.gitBranch = branch }
                hints[session] = h
            } else {
                hints[session] = SessionHint(session: session, cwd: cwd, entrypoint: entrypoint, title: nil,
                                             gitBranch: branch == "HEAD" ? nil : branch)
            }
        }

        func lineData(_ p: UnsafePointer<UInt8>, _ len: Int) -> Data {
            Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: p), count: len, deallocator: .none)
        }

        func handleLine(_ p: UnsafePointer<UInt8>, _ len: Int) {
            let head = min(len, 2048)
            if hasPrefix(p, len, Pat.customTitle) || hasPrefix(p, len, Pat.agentName) {
                if let l = try? decoder.decode(SmallLine.self, from: lineData(p, len)), let sid = l.sessionId {
                    let title = l.customTitle ?? l.agentName
                    hint(sid, cwd: nil, entrypoint: nil, branch: nil)
                    if let title, !title.isEmpty {
                        // A custom title always wins over the agent name.
                        if l.customTitle != nil || hints[sid]?.title == nil { hints[sid]?.title = title }
                    }
                }
                return
            }
            if contains(p, head, Pat.userToolUseId) || contains(p, head, Pat.userToolResult) {
                return
            }
            if contains(p, head, Pat.userMsg) {
                guard let l = try? decoder.decode(UserLine.self, from: lineData(p, len)) else { return }
                handleUser(l)
                return
            }
            if contains(p, head, Pat.roleAssistant) {
                guard let l = try? decoder.decode(AssistantLine.self, from: lineData(p, len)) else { return }
                handleAssistant(l)
                return
            }
            if contains(p, head, Pat.typeSystem) {
                let isCompact = contains(p, head, Pat.compactBoundary)
                let isError = contains(p, head, Pat.apiError)
                guard isCompact || isError,
                      let l = try? decoder.decode(SmallLine.self, from: lineData(p, len)),
                      let sid = l.sessionId, let ts = parseTimestamp(l.timestamp) else { return }
                summary.markers.append(MarkerRec(session: sid, ts: ts, kind: isCompact ? .compact : .apiError))
            }
        }

        func handleUser(_ l: UserLine) {
            guard l.type == "user", let sid = l.sessionId, let ts = parseTimestamp(l.timestamp), let uuid = l.uuid else { return }
            hint(sid, cwd: l.cwd, entrypoint: l.entrypoint, branch: l.gitBranch)
            if l.isSidechain == true || isSubagent { return }
            if l.isCompactSummary == true { return }

            var raw = ""
            var images = 0
            switch l.content {
            case .text(let s): raw = s
            case .blocks(let blocks):
                var parts: [String] = []
                for b in blocks {
                    switch b.type {
                    case "text": if let t = b.text { parts.append(t) }
                    case "image": images += 1
                    case "tool_result": return
                    default: break
                    }
                }
                raw = parts.joined(separator: "\n")
            case .none: break
            }

            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            if let kind = l.originKind {
                if kind != "human" {
                    if kind.hasPrefix("task-notification") {
                        summary.markers.append(MarkerRec(session: sid, ts: ts, kind: .taskNotification))
                    }
                    return
                }
            } else if l.isMeta == true {
                return
            }

            if trimmed.hasPrefix("[Request interrupted") {
                summary.markers.append(MarkerRec(session: sid, ts: ts, kind: .interrupt))
                return
            }
            if trimmed.hasPrefix("<scheduled-task") {
                summary.markers.append(MarkerRec(session: sid, ts: ts, kind: .scheduled))
                return
            }
            if trimmed.contains("<command-name>") && trimmed.count < 4000 {
                var name = TextClean.between(trimmed, "<command-name>", "</command-name>") ?? ""
                name = name.trimmingCharacters(in: .whitespaces)
                if !name.hasPrefix("/") { name = "/" + name }
                let args = TextClean.between(trimmed, "<command-args>", "</command-args>")?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                summary.prompts.append(PromptRec(id: uuid, session: sid, ts: ts, text: args, kind: .command,
                                                 images: images, command: name))
                return
            }
            if trimmed.hasPrefix("<bash-input>") {
                let cmd = TextClean.between(trimmed, "<bash-input>", "</bash-input>") ?? ""
                summary.prompts.append(PromptRec(id: uuid, session: sid, ts: ts, text: cmd, kind: .shell,
                                                 images: 0, command: nil))
                return
            }
            for pre in TextClean.systemPrefixes where trimmed.hasPrefix(pre) { return }

            let text = TextClean.cleanPrompt(trimmed)
            if text.isEmpty && images == 0 { return }
            summary.prompts.append(PromptRec(id: uuid, session: sid, ts: ts, text: text, kind: .human,
                                             images: images, command: nil))
        }

        func handleAssistant(_ l: AssistantLine) {
            guard let sid = l.sessionId, let ts = parseTimestamp(l.timestamp) else { return }
            hint(sid, cwd: l.cwd, entrypoint: l.entrypoint, branch: l.gitBranch)
            let model = l.model ?? "inconnu"
            if model == "<synthetic>" {
                let text = l.blocks.compactMap { $0.text }.joined(separator: " ").lowercased()
                if text.contains("limit") && !isSubagent && l.isSidechain != true {
                    summary.markers.append(MarkerRec(session: sid, ts: ts, kind: .usageLimit))
                }
                return
            }
            var textChars = 0
            var tools: [ToolRec] = []
            for b in l.blocks {
                switch b.type {
                case "text":
                    textChars += b.text?.count ?? 0
                case "tool_use":
                    tools.append(makeTool(name: b.name ?? "?", input: b.input))
                default:
                    break
                }
            }
            let u = l.usage
            summary.assistants.append(AssistantRec(
                uuid: l.uuid ?? UUID().uuidString,
                msgId: l.id ?? (l.uuid ?? UUID().uuidString),
                session: sid, ts: ts, model: model,
                input: u?.input ?? 0, output: u?.output ?? 0,
                cacheRead: u?.cacheRead ?? 0, cacheWrite: u?.cacheWrite ?? 0, cacheWrite1h: u?.cacheWrite1h ?? 0,
                thinkMs: Int(l.thinkingDurationMs ?? 0),
                textChars: textChars, tools: tools,
                sidechain: (l.isSidechain ?? false) || isSubagent))
        }

        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base0 = raw.baseAddress else { return }
            let base = base0.assumingMemoryBound(to: UInt8.self)
            let n = raw.count
            var start = 0
            while start < n {
                let nl = memchr(base + start, 0x0A, n - start)
                let end: Int = nl.map { UnsafeRawPointer($0) - UnsafeRawPointer(base) } ?? n
                let len = end - start
                if len > 2 {
                    handleLine(base + start, len)
                }
                start = end + 1
            }
        }

        summary.hints = Array(hints.values)
        return summary
    }

    private static func makeTool(name: String, input: ToolInputJ?) -> ToolRec {
        var tool = ToolRec(name: name, file: nil, add: 0, del: 0, detail: nil)
        guard let input else { return tool }
        switch name {
        case "Edit":
            tool.file = input.filePath
            let d = TextClean.diffCounts(old: input.oldString ?? "", new: input.newString ?? "")
            tool.add = d.add
            tool.del = d.del
        case "MultiEdit":
            tool.file = input.filePath
            for (o, n) in input.edits {
                let d = TextClean.diffCounts(old: o, new: n)
                tool.add += d.add
                tool.del += d.del
            }
        case "Write":
            tool.file = input.filePath
            tool.add = TextClean.lineCount(input.content ?? "")
        case "NotebookEdit":
            tool.file = input.filePath
            tool.add = TextClean.lineCount(input.newSource ?? "")
        case "Read":
            tool.file = input.filePath
        case "Bash":
            tool.detail = shellVerb(input.command ?? "")
        case "Agent", "Task":
            tool.detail = input.subagentType ?? "general-purpose"
        case "Skill":
            tool.detail = input.skill
        case "WebFetch":
            if let u = input.url, let host = URL(string: u)?.host {
                tool.detail = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            }
        case "WebSearch":
            if let q = input.query { tool.detail = String(q.prefix(120)) }
        default:
            break
        }
        return tool
    }

    /// The program a shell command runs ("git", "npm", "python3"…), skipping `cd`, assignments and shell keywords.
    static func shellVerb(_ command: String) -> String? {
        let skip: Set<String> = ["cd", "export", "source", ".", "set", "local", "for", "while", "if", "then", "do",
                                 "done", "fi", "else", "elif", "case", "esac", "until", "{", "}", "(", ")", "!",
                                 "[", "[[", "true", "false", "unset", "trap", "wait", "exec"]
        let separators = CharacterSet(charactersIn: "&;|\n")
        for seg in command.components(separatedBy: separators) {
            var words = seg.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            // Drop VAR=value assignments.
            while let f = words.first, let eq = f.firstIndex(of: "="), f[..<eq].allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }), !f.hasPrefix("=") {
                words.removeFirst()
            }
            guard var first = words.first else { continue }
            if skip.contains(first) { continue }
            if ["sudo", "time", "env", "nohup", "timeout", "xargs"].contains(first) {
                words.removeFirst()
                if first == "timeout", !words.isEmpty { words.removeFirst() }
                guard let next = words.first else { continue }
                first = next
            }
            if first.hasPrefix("$") || first.hasPrefix("\"$") { continue }
            first = first.trimmingCharacters(in: CharacterSet(charactersIn: "\"'()`"))
            if first.contains("/") { first = (first as NSString).lastPathComponent }
            if first.isEmpty || first.count > 24 || first.hasPrefix("-") || first.first?.isNumber == true { continue }
            return first
        }
        return nil
    }
}
