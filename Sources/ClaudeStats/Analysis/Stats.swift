import Foundation

// MARK: - Filter

enum Period: String, CaseIterable, Identifiable, Sendable {
    case week, month, quarter, year, all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .week: return "7 j"
        case .month: return "30 j"
        case .quarter: return "90 j"
        case .year: return "1 an"
        case .all: return "Tout"
        }
    }
    var longLabel: String {
        switch self {
        case .week: return "ces 7 derniers jours"
        case .month: return "ces 30 derniers jours"
        case .quarter: return "ces 3 derniers mois"
        case .year: return "cette dernière année"
        case .all: return "depuis le début"
        }
    }
    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        case .all: return nil
        }
    }
}

struct StatsFilter: Equatable, Sendable {
    var period: Period = .all
    var sources: Set<SourceKind> = Set(SourceKind.allCases)
    var project: String? = nil
}

// MARK: - Result types

struct NamedCount: Identifiable, Sendable, Hashable {
    var id: String { name }
    var name: String
    var count: Int
    var value: Double = 0
}

struct DayStat: Identifiable, Sendable {
    var id: Int { day }
    var day: Int
    var date: Date
    var prompts: Int = 0
    var seconds: Double = 0
    var messages: Int = 0
    var tokens: Int = 0
    var cost: Double = 0
    var sessions: Int = 0
    var avg7: Double = 0
}

struct HourStat: Identifiable, Sendable {
    var id: Int { hour }
    var hour: Int
    var prompts: Int = 0
    var seconds: Double = 0
}

struct WeekdayStat: Identifiable, Sendable {
    var id: Int { weekday }
    var weekday: Int
    var prompts: Int = 0
    var seconds: Double = 0
    var activeDays: Int = 0
    var name: String { Fmt.weekdayShort[weekday] }
}

struct PunchCell: Identifiable, Sendable {
    var id: Int { weekday * 24 + hour }
    var weekday: Int
    var hour: Int
    var prompts: Int
    var seconds: Double
}

struct SessionRow: Identifiable, Sendable {
    var id: String
    var index: Int
    var title: String
    var project: String
    var category: Category
    var source: SourceKind
    var start: Double
    var end: Double
    var prompts: Int = 0
    var messages: Int = 0
    var seconds: Double = 0
    var claudeSeconds: Double = 0
    var tokens: Int = 0
    var outputTokens: Int = 0
    var cost: Double = 0
    var linesAdded: Int = 0
    var linesRemoved: Int = 0
    var toolCalls: Int = 0
    var subagents: Int = 0
    var model: String
    var isArchived: Bool
    var isScheduled: Bool
    var branch: String?
    var startDate: Date { Date(timeIntervalSince1970: start) }
}

struct ProjectStat: Identifiable, Sendable {
    var id: String { name }
    var name: String
    var paths: Set<String> = []
    var sessions: Int = 0
    var prompts: Int = 0
    var seconds: Double = 0
    var tokens: Int = 0
    var cost: Double = 0
    var linesAdded: Int = 0
    var first: Double = .infinity
    var last: Double = 0
    var categorySeconds: [Category: Double] = [:]
    var weekly: [Int: Double] = [:]
    var mainCategory: Category { categorySeconds.max(by: { ($0.value, $1.key.rank) < ($1.value, $0.key.rank) })?.key ?? .other }
}

struct CategoryStat: Identifiable, Sendable {
    var id: Category { category }
    var category: Category
    var prompts: Int = 0
    var sessions: Int = 0
    var seconds: Double = 0
    var tokens: Int = 0
    var topProjects: [NamedCount] = []
    var examples: [String] = []
}

struct CategoryWeek: Identifiable, Sendable {
    var id: String { "\(week)-\(category.rawValue)" }
    var week: Date
    var category: Category
    var hours: Double
}

struct ModelStat: Identifiable, Sendable {
    var id: String { label }
    var label: String
    var messages: Int = 0
    var outputTokens: Int = 0
    var totalTokens: Int = 0
    var cost: Double = 0
}

struct ModelWeek: Identifiable, Sendable {
    var id: String { "\(week)-\(label)" }
    var week: Date
    var label: String
    var messages: Int
}

struct TokenTotals: Sendable {
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheWrite = 0
    var total: Int { input + output + cacheRead + cacheWrite }
    var cacheHitRate: Double {
        let ctx = input + cacheRead + cacheWrite
        return ctx > 0 ? Double(cacheRead) / Double(ctx) : 0
    }
}

struct PromptHighlight: Sendable {
    var ts: Double
    var text: String
    var words: Int
    var session: String
}

struct Records: Sendable {
    var longestSession: SessionRow?
    var busiestSession: SessionRow?
    var costliestSession: SessionRow?
    var biggestDay: DayStat?
    var latestPrompt: PromptHighlight?
    var earliestPrompt: PromptHighlight?
    var longestPrompt: PromptHighlight?
    var longestTurn: (seconds: Double, title: String)?
}

struct StyleStats: Sendable {
    var words: [NamedCount] = []
    var languages: [NamedCount] = []
    var totalWords = 0
    var avgWords: Double = 0
    var medianWords: Double = 0
    var lengthBuckets: [NamedCount] = []
    var humanPrompts = 0
    var questions = 0
    var thanks = 0
    var please = 0
    var greetings = 0
    var shortReplies = 0
    var exclamations = 0
    var images = 0
    var commands: [NamedCount] = []
    var commandCount = 0
    var shellTyped = 0
    var claudeWords = 0
    var topOpeners: [NamedCount] = []
}

struct Stats: Sendable {
    var filter = StatsFilter()
    var firstTs: Double = 0
    var lastTs: Double = 0
    var sessionCount = 0
    var promptCount = 0
    var messageCount = 0
    var activeDays = 0
    var spanDays = 0
    var activeSeconds: Double = 0
    var claudeSeconds: Double = 0
    var thinkingSeconds: Double = 0
    var avgTurnSeconds: Double = 0
    var tokens = TokenTotals()
    var cost: Double = 0
    var linesAdded = 0
    var linesRemoved = 0
    var filesTouched = 0
    var toolCalls = 0
    var avgPromptsPerSession: Double = 0
    var medianPromptsPerSession: Double = 0
    var avgSessionSeconds: Double = 0
    var medianSessionSeconds: Double = 0
    var promptsPerActiveDay: Double = 0
    var secondsPerActiveDay: Double = 0

    var days: [DayStat] = []          // contiguous, including empty days
    var hours: [HourStat] = []
    var weekdays: [WeekdayStat] = []
    var punch: [PunchCell] = []
    var streakCurrent = 0
    var streakLongest = 0
    var streakLongestEnd: Date?
    var weekendShare: Double = 0
    var nightPrompts = 0
    var peakHour = 0
    var peakWeekday = 0
    var topDays: [DayStat] = []

    var projects: [ProjectStat] = []
    var categories: [CategoryStat] = []
    var categoryWeeks: [CategoryWeek] = []
    var sessions: [SessionRow] = []

    var tools: [NamedCount] = []
    var toolFamilies: [NamedCount] = []
    var shellVerbs: [NamedCount] = []
    var codeLanguages: [NamedCount] = []
    var topFiles: [NamedCount] = []
    var subagentTypes: [NamedCount] = []
    var skills: [NamedCount] = []
    var mcpServers: [NamedCount] = []
    var webDomains: [NamedCount] = []
    var webSearches = 0
    var webFetches = 0
    var agentsLaunched = 0
    var workflows = 0
    var bashCommands = 0
    var filesRead = 0

    var models: [ModelStat] = []
    var modelWeeks: [ModelWeek] = []
    var style = StyleStats()
    var records = Records()

    var interruptions = 0
    var compactions = 0
    var apiErrors = 0
    var usageLimitHits = 0
    var scheduledRuns = 0
    var sources: [NamedCount] = []
    var sessionLengthBuckets: [NamedCount] = []
    var sessionDurationBuckets: [NamedCount] = []

    var hasData: Bool { promptCount + messageCount > 0 }
    var firstDate: Date { Date(timeIntervalSince1970: firstTs) }
}

// MARK: - Engine

enum StatsEngine {
    static let tz = TimeZone.current

    struct LocalTime {
        var day: Int
        var hour: Int
        var weekday: Int
        var second: Int
    }

    @inline(__always)
    static func local(_ ts: Double) -> LocalTime {
        let off = Double(tz.secondsFromGMT(for: Date(timeIntervalSince1970: ts)))
        let l = ts + off
        let day = Int((l / 86400).rounded(.down))
        let sec = Int(l - Double(day) * 86400)
        return LocalTime(day: day, hour: min(23, max(0, sec / 3600)), weekday: ((day % 7) + 7 + 3) % 7, second: sec)
    }

    static func date(ofDay day: Int) -> Date {
        let noon = Double(day) * 86400 + 43200
        return Date(timeIntervalSince1970: noon - Double(tz.secondsFromGMT(for: Date(timeIntervalSince1970: noon))))
    }

    static func todayIndex() -> Int { local(Date().timeIntervalSince1970).day }

    static func compute(_ ds: Dataset, filter: StatsFilter) -> Stats {
        var st = Stats()
        st.filter = filter
        let today = todayIndex()
        let lowerDay = filter.period.days.map { today - $0 + 1 } ?? Int.min
        let lower: Double = lowerDay == Int.min ? -.infinity : date(ofDay: lowerDay).timeIntervalSince1970 - 43200 - 3600 * 2

        let allowed: [Bool] = ds.sessions.map { s in
            filter.sources.contains(s.source) && (filter.project == nil || s.project == filter.project)
        }
        func inRange(_ ts: Double) -> Bool { ts >= lower && local(ts).day >= lowerDay }

        let P = ds.prompts.filter { allowed[$0.session] && $0.ts >= lower && inRange($0.ts) }
        let M = ds.messages.filter { allowed[$0.session] && $0.ts >= lower && inRange($0.ts) }
        let S = ds.segments.filter { allowed[$0.session] && $0.start >= lower && inRange($0.start) }
        let K = ds.markers.filter {
            ($0.session >= 0 ? allowed[$0.session] : filter.project == nil) && $0.ts >= lower && inRange($0.ts)
        }

        st.promptCount = P.count
        st.messageCount = M.filter { !$0.sidechain }.count
        st.firstTs = min(P.first?.ts ?? .infinity, M.first?.ts ?? .infinity)
        st.lastTs = max(P.last?.ts ?? 0, M.last?.ts ?? 0)
        if !st.firstTs.isFinite { st.firstTs = 0 }

        // MARK: Per-session rows
        var rows: [Int: SessionRow] = [:]
        func row(_ si: Int) -> SessionRow {
            if let r = rows[si] { return r }
            let s = ds.sessions[si]
            return SessionRow(id: s.id, index: si, title: s.title, project: s.project, category: s.category,
                              source: s.source, start: .infinity, end: 0, model: s.model, isArchived: s.isArchived,
                              isScheduled: s.isScheduled, branch: s.branch)
        }

        var days: [Int: DayStat] = [:]
        func dayAcc(_ d: Int) -> DayStat { days[d] ?? DayStat(day: d, date: date(ofDay: d)) }
        var daySessions: [Int: Set<Int>] = [:]
        var hours = (0..<24).map { HourStat(hour: $0) }
        var weekdays = (0..<7).map { WeekdayStat(weekday: $0) }
        var punchP = [[Int]](repeating: [Int](repeating: 0, count: 24), count: 7)
        var punchS = [[Double]](repeating: [Double](repeating: 0, count: 24), count: 7)

        for p in P {
            let lt = local(p.ts)
            var r = row(p.session)
            r.prompts += 1
            r.claudeSeconds += p.turnSeconds
            r.start = min(r.start, p.ts)
            r.end = max(r.end, p.ts)
            rows[p.session] = r
            var d = dayAcc(lt.day)
            d.prompts += 1
            days[lt.day] = d
            daySessions[lt.day, default: []].insert(p.session)
            hours[lt.hour].prompts += 1
            weekdays[lt.weekday].prompts += 1
            punchP[lt.weekday][lt.hour] += 1
            st.claudeSeconds += p.turnSeconds
            if lt.hour < 5 { st.nightPrompts += 1 }
        }

        var modelAcc: [String: ModelStat] = [:]
        var modelWeekAcc: [String: Int] = [:]
        var toolAcc: [String: Int] = [:]
        var familyAcc: [String: Int] = [:]
        var shellAcc: [String: Int] = [:]
        var langAcc: [String: Int] = [:]
        var fileAcc: [String: Int] = [:]
        var agentAcc: [String: Int] = [:]
        var skillAcc: [String: Int] = [:]
        var mcpAcc: [String: Int] = [:]
        var domainAcc: [String: Int] = [:]
        var touched = Set<String>()

        for m in M {
            let lt = local(m.ts)
            var r = row(m.session)
            if !m.sidechain { r.messages += 1 }
            r.tokens += m.totalTokens
            r.outputTokens += m.output
            r.cost += m.cost
            r.start = min(r.start, m.ts)
            r.end = max(r.end, m.ts)

            st.tokens.input += m.input
            st.tokens.output += m.output
            st.tokens.cacheRead += m.cacheRead
            st.tokens.cacheWrite += m.cacheWrite
            st.cost += m.cost
            st.thinkingSeconds += Double(m.thinkMs) / 1000

            var d = dayAcc(lt.day)
            if !m.sidechain { d.messages += 1 }
            d.tokens += m.totalTokens
            d.cost += m.cost
            days[lt.day] = d

            if m.model != "claude.ai" {
                let label = Pricing.modelLabel(m.model)
                var ms = modelAcc[label] ?? ModelStat(label: label)
                ms.messages += 1
                ms.outputTokens += m.output
                ms.totalTokens += m.totalTokens
                ms.cost += m.cost
                modelAcc[label] = ms
                modelWeekAcc["\(lt.day - lt.weekday)|\(label)", default: 0] += 1
            }

            for t in m.tools {
                st.toolCalls += 1
                r.toolCalls += 1
                toolAcc[t.name, default: 0] += 1
                familyAcc[ToolNames.family(t.name), default: 0] += 1
                r.linesAdded += t.add
                r.linesRemoved += t.del
                st.linesAdded += t.add
                st.linesRemoved += t.del
                switch t.name {
                case "Bash":
                    st.bashCommands += 1
                    if let v = t.detail { shellAcc[v, default: 0] += 1 }
                case "Agent", "Task":
                    st.agentsLaunched += 1
                    r.subagents += 1
                    agentAcc[t.detail ?? "general-purpose", default: 0] += 1
                case "Workflow":
                    st.workflows += 1
                case "Skill":
                    if let v = t.detail { skillAcc[v, default: 0] += 1 }
                case "WebSearch":
                    st.webSearches += 1
                case "WebFetch":
                    st.webFetches += 1
                    if let v = t.detail { domainAcc[v, default: 0] += 1 }
                case "Read":
                    st.filesRead += 1
                default:
                    break
                }
                if t.name.hasPrefix("mcp__") {
                    mcpAcc[ToolNames.serverLabel(t.name, ds: ds), default: 0] += 1
                }
                if let f = t.file, t.add > 0 || t.del > 0 {
                    touched.insert(f)
                    fileAcc[f, default: 0] += 1
                    let ext = (f as NSString).pathExtension.lowercased()
                    langAcc[ToolNames.language(ext), default: 0] += t.add
                }
            }
            rows[m.session] = r
        }

        for seg in S {
            var r = row(seg.session)
            r.seconds += seg.duration
            rows[seg.session] = r
            st.activeSeconds += seg.duration
            // Spread the segment over the hours it covers.
            var t = seg.start
            var remaining = seg.duration
            while remaining > 0.5 {
                let lt = local(t)
                let chunk = min(remaining, Double(3600 - lt.second % 3600))
                hours[lt.hour].seconds += chunk
                weekdays[lt.weekday].seconds += chunk
                punchS[lt.weekday][lt.hour] += chunk
                var d = dayAcc(lt.day)
                d.seconds += chunk
                days[lt.day] = d
                daySessions[lt.day, default: []].insert(seg.session)
                t += chunk
                remaining -= chunk
            }
        }

        for k in K {
            switch k.kind {
            case .interrupt: st.interruptions += 1
            case .compact: st.compactions += 1
            case .apiError: st.apiErrors += 1
            case .usageLimit: st.usageLimitHits += 1
            case .scheduled: st.scheduledRuns += 1
            case .taskNotification: break
            }
        }

        // MARK: Days, streaks, rhythm
        for (d, set) in daySessions { var x = dayAcc(d); x.sessions = set.count; days[d] = x }
        let activeDayKeys = days.filter { $0.value.prompts > 0 || $0.value.seconds > 0 }.keys.sorted()
        st.activeDays = activeDayKeys.count
        if let first = activeDayKeys.first {
            let start = filter.period.days == nil ? first : lowerDay
            let end = max(today, activeDayKeys.last ?? today)
            var series: [DayStat] = []
            for d in start...end { series.append(days[d] ?? DayStat(day: d, date: date(ofDay: d))) }
            for i in series.indices {
                let lo = max(0, i - 6)
                let slice = series[lo...i]
                series[i].avg7 = Double(slice.reduce(0) { $0 + $1.prompts }) / Double(slice.count)
            }
            st.days = series
            st.spanDays = end - start + 1
            // Streaks
            var longest = 0, run = 0, prev = Int.min, longestEnd = first
            for d in activeDayKeys {
                run = (d == prev + 1) ? run + 1 : 1
                if run > longest { longest = run; longestEnd = d }
                prev = d
            }
            st.streakLongest = longest
            st.streakLongestEnd = date(ofDay: longestEnd)
            let set = Set(activeDayKeys)
            var cur = 0
            var d = set.contains(today) ? today : today - 1
            while set.contains(d) { cur += 1; d -= 1 }
            st.streakCurrent = cur
            for d in activeDayKeys { weekdays[((d % 7) + 7 + 3) % 7].activeDays += 1 }
        }
        st.hours = hours
        st.weekdays = weekdays
        st.punch = (0..<7).flatMap { w in (0..<24).map { h in PunchCell(weekday: w, hour: h, prompts: punchP[w][h], seconds: punchS[w][h]) } }
        // Peaks follow your own messages (when you are there), time breaks ties.
        st.peakHour = hours.max(by: { ($0.prompts, $0.seconds) < ($1.prompts, $1.seconds) })?.hour ?? 0
        st.peakWeekday = weekdays.max(by: { ($0.prompts, $0.seconds) < ($1.prompts, $1.seconds) })?.weekday ?? 0
        let weekendSecs = weekdays[5].seconds + weekdays[6].seconds
        st.weekendShare = st.activeSeconds > 0 ? weekendSecs / st.activeSeconds : 0
        st.topDays = Array(days.values.filter { $0.prompts > 0 }
            .sorted { ($0.prompts, $0.seconds, $1.day) > ($1.prompts, $1.seconds, $0.day) }.prefix(10))
        st.promptsPerActiveDay = st.activeDays > 0 ? Double(st.promptCount) / Double(st.activeDays) : 0
        st.secondsPerActiveDay = st.activeDays > 0 ? st.activeSeconds / Double(st.activeDays) : 0

        // MARK: Sessions
        let sessionRows = rows.values.filter { $0.prompts > 0 || $0.messages > 0 }
            .sorted { $0.start != $1.start ? $0.start > $1.start : $0.id < $1.id }
        st.sessions = sessionRows
        st.sessionCount = sessionRows.count
        let withPrompts = sessionRows.filter { $0.prompts > 0 }
        if !withPrompts.isEmpty {
            let counts = withPrompts.map { Double($0.prompts) }.sorted()
            st.avgPromptsPerSession = counts.reduce(0, +) / Double(counts.count)
            st.medianPromptsPerSession = median(counts)
            let secs = withPrompts.map { $0.seconds }.sorted()
            st.avgSessionSeconds = secs.reduce(0, +) / Double(secs.count)
            st.medianSessionSeconds = median(secs)
        }
        let turns = P.filter { $0.turnSeconds > 0 }
        st.avgTurnSeconds = turns.isEmpty ? 0 : turns.reduce(0) { $0 + $1.turnSeconds } / Double(turns.count)
        st.filesTouched = touched.count

        st.sessionLengthBuckets = buckets(withPrompts.map { Double($0.prompts) },
                                          edges: [(1, "1"), (5, "2-5"), (10, "6-10"), (25, "11-25"), (50, "26-50"), (100, "51-100"), (.infinity, "100+")])
        st.sessionDurationBuckets = buckets(withPrompts.map { $0.seconds / 60 },
                                            edges: [(5, "< 5 min"), (15, "5-15 min"), (30, "15-30 min"), (60, "30-60 min"),
                                                    (120, "1-2 h"), (240, "2-4 h"), (.infinity, "4 h +")])
        var srcAcc: [SourceKind: Int] = [:]
        for r in sessionRows { srcAcc[r.source, default: 0] += 1 }
        st.sources = SourceKind.allCases.compactMap { s in srcAcc[s].map { NamedCount(name: s.label, count: $0) } }

        // MARK: Projects & categories
        var projAcc: [String: ProjectStat] = [:]
        var catAcc: [Category: CategoryStat] = [:]
        var catProj: [Category: [String: Double]] = [:]
        for r in sessionRows {
            var p = projAcc[r.project] ?? ProjectStat(name: r.project)
            p.paths.insert(ds.sessions[r.index].cwd)
            p.sessions += 1
            p.prompts += r.prompts
            p.seconds += r.seconds
            p.tokens += r.tokens
            p.cost += r.cost
            p.linesAdded += r.linesAdded
            p.first = min(p.first, r.start)
            p.last = max(p.last, r.end)
            p.categorySeconds[r.category, default: 0] += r.seconds
            projAcc[r.project] = p

            var c = catAcc[r.category] ?? CategoryStat(category: r.category)
            c.sessions += 1
            c.prompts += r.prompts
            c.seconds += r.seconds
            c.tokens += r.tokens
            if c.examples.count < 6, r.prompts > 0 { c.examples.append(r.title) }
            catAcc[r.category] = c
            catProj[r.category, default: [:]][r.project, default: 0] += r.seconds
        }
        var catWeekAcc: [String: Double] = [:]
        for seg in S {
            let lt = local(seg.start)
            let p = ds.sessions[seg.session].project
            projAcc[p]?.weekly[lt.day - lt.weekday, default: 0] += seg.duration
            catWeekAcc["\(lt.day - lt.weekday)|\(ds.sessions[seg.session].category.rawValue)", default: 0] += seg.duration
        }
        // Equal values are ordered by name so the result does not depend on dictionary order.
        st.projects = projAcc.values.sorted { $0.seconds != $1.seconds ? $0.seconds > $1.seconds : $0.name < $1.name }
        for (cat, projs) in catProj {
            catAcc[cat]?.topProjects = projs.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(4)
                .map { NamedCount(name: $0.key, count: Int($0.value)) }
        }
        st.categories = catAcc.values.sorted { $0.seconds != $1.seconds ? $0.seconds > $1.seconds : $0.category.rank < $1.category.rank }
        st.categoryWeeks = catWeekAcc.compactMap { k, v in
            let parts = k.split(separator: "|")
            guard parts.count == 2, let d = Int(parts[0]), let c = Category(rawValue: String(parts[1])) else { return nil }
            return CategoryWeek(week: date(ofDay: d), category: c, hours: v / 3600)
        }.sorted { $0.week != $1.week ? $0.week < $1.week : $0.category.rank < $1.category.rank }

        // MARK: Tools & models
        st.tools = sortedCounts(toolAcc).map { NamedCount(name: $0.name, count: $0.count) }
        st.toolFamilies = sortedCounts(familyAcc)
        st.shellVerbs = Array(sortedCounts(shellAcc).prefix(15))
        st.codeLanguages = sortedCounts(langAcc).filter { $0.count > 0 }
        st.topFiles = Array(sortedCounts(fileAcc).prefix(12))
        st.subagentTypes = sortedCounts(agentAcc)
        var allSkills = skillAcc
        if filter.period == .all { for (k, v) in ds.skills { allSkills[k] = max(allSkills[k] ?? 0, v) } }
        st.skills = Array(sortedCounts(allSkills).prefix(12))
        st.mcpServers = sortedCounts(mcpAcc)
        st.webDomains = Array(sortedCounts(domainAcc).prefix(12))
        st.models = modelAcc.values.sorted { $0.messages != $1.messages ? $0.messages > $1.messages : $0.label < $1.label }
        st.modelWeeks = modelWeekAcc.compactMap { k, v in
            let parts = k.split(separator: "|", maxSplits: 1)
            guard parts.count == 2, let d = Int(parts[0]) else { return nil }
            return ModelWeek(week: date(ofDay: d), label: String(parts[1]), messages: v)
        }.sorted { $0.week != $1.week ? $0.week < $1.week : $0.label < $1.label }

        // MARK: Style
        st.style = style(P, M)

        // MARK: Records
        var rec = Records()
        rec.longestSession = sessionRows.max { $0.seconds < $1.seconds }
        rec.busiestSession = sessionRows.max { $0.prompts < $1.prompts }
        rec.costliestSession = sessionRows.max { $0.cost < $1.cost }
        rec.biggestDay = days.values.max { $0.prompts < $1.prompts }
        let humans = P.filter { $0.kind == .human }
        func hl(_ p: Prompt) -> PromptHighlight {
            PromptHighlight(ts: p.ts, text: p.text, words: p.words, session: ds.sessions[p.session].title)
        }
        // Latest: the prompt closest to 5 a.m. coming from the evening side.
        if let late = humans.max(by: { lateScore($0.ts) < lateScore($1.ts) }) { rec.latestPrompt = hl(late) }
        if let early = humans.min(by: { earlyScore($0.ts) < earlyScore($1.ts) }) { rec.earliestPrompt = hl(early) }
        if let long = humans.max(by: { $0.words < $1.words }) { rec.longestPrompt = hl(long) }
        if let t = P.max(by: { $0.turnSeconds < $1.turnSeconds }), t.turnSeconds > 0 {
            rec.longestTurn = (t.turnSeconds, ds.sessions[t.session].title)
        }
        st.records = rec
        return st
    }

    /// Seconds after 5 a.m. (local), so that 3 a.m. counts as "later" than 11 p.m.
    static func lateScore(_ ts: Double) -> Int {
        let s = local(ts).second
        return (s - 5 * 3600 + 86400) % 86400
    }

    static func earlyScore(_ ts: Double) -> Int { lateScore(ts) }

    static func median(_ sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let n = sorted.count
        return n % 2 == 1 ? sorted[n / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2
    }

    static func buckets(_ values: [Double], edges: [(Double, String)]) -> [NamedCount] {
        var counts = [Int](repeating: 0, count: edges.count)
        for v in values {
            if let i = edges.firstIndex(where: { v <= $0.0 }) { counts[i] += 1 }
        }
        return edges.enumerated().map { NamedCount(name: $0.element.1, count: counts[$0.offset]) }
    }

    static func sortedCounts(_ d: [String: Int]) -> [NamedCount] {
        d.map { NamedCount(name: $0.key, count: $0.value) }.sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    static func style(_ P: [Prompt], _ M: [Message]) -> StyleStats {
        var s = StyleStats()
        let humans = P.filter { $0.kind == .human }
        s.humanPrompts = humans.count
        var wordAcc: [String: Int] = [:]
        var display: [String: [String: Int]] = [:]
        var langAcc: [Lang: Int] = [:]
        var openers: [String: Int] = [:]
        var lengths: [Double] = []
        for p in humans {
            s.totalWords += p.words
            lengths.append(Double(p.words))
            s.images += p.images
            if p.lang != .other { langAcc[p.lang, default: 0] += 1 }
            let lower = p.text.lowercased()
            if lower.contains("?") { s.questions += 1 }
            if lower.contains("!") { s.exclamations += 1 }
            if p.words <= 3 && p.words > 0 { s.shortReplies += 1 }
            let toks = Words.tokens(Words.withoutPaths(p.text), limit: 300)
            let folded = Set(toks.map(Words.fold))
            if TextStats.thanksWords.contains(where: { folded.contains($0) }) { s.thanks += 1 }
            if folded.contains("stp") || folded.contains("svp") || folded.contains("please")
                || lower.contains("s'il te pla") || lower.contains("s’il te pla") || lower.contains("s'il vous pla")
                || lower.contains("por favor") { s.please += 1 }
            if let f = toks.first, TextStats.greetingWords.contains(Words.fold(f)) { s.greetings += 1 }
            if let f = toks.first, f.count > 1 { openers[f, default: 0] += 1 }
            for t in toks where t.count >= 4 && !TextStats.stopwords.contains(t) && !t.allSatisfy(\.isNumber) {
                let key = Words.fold(t)
                if TextStats.stopwords.contains(key) { continue }
                wordAcc[key, default: 0] += 1
                display[key, default: [:]][t, default: 0] += 1
            }
        }
        s.words = wordAcc.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(80).map { k, v in
            NamedCount(name: display[k]?.max(by: { ($0.value, $1.key) < ($1.value, $0.key) })?.key ?? k, count: v)
        }
        let langTotal = max(1, langAcc.values.reduce(0, +))
        s.languages = Lang.allCases.compactMap { l in
            langAcc[l].map { NamedCount(name: l.label, count: $0, value: Double($0) / Double(langTotal)) }
        }.sorted { $0.count > $1.count }
        lengths.sort()
        s.avgWords = lengths.isEmpty ? 0 : lengths.reduce(0, +) / Double(lengths.count)
        s.medianWords = median(lengths)
        s.lengthBuckets = buckets(lengths, edges: [(5, "1-5"), (20, "6-20"), (50, "21-50"), (100, "51-100"),
                                                   (250, "101-250"), (.infinity, "250+")])
        let cmds = P.filter { $0.kind == .command }
        s.commandCount = cmds.count
        var cmdAcc: [String: Int] = [:]
        for c in cmds { cmdAcc[c.command ?? "/?", default: 0] += 1 }
        s.commands = sortedCounts(cmdAcc)
        s.shellTyped = P.filter { $0.kind == .shell }.count
        s.claudeWords = M.filter { !$0.sidechain }.reduce(0) { $0 + $1.textChars } / 6
        s.topOpeners = Array(sortedCounts(openers).prefix(8))
        return s
    }
}

// MARK: - Tool naming

enum ToolNames {
    static func family(_ name: String) -> String {
        switch name {
        case "Bash", "BashOutput", "KillShell", "KillBash", "Monitor": return "Terminal"
        case "Read", "Edit", "Write", "MultiEdit", "NotebookEdit", "Glob", "Grep", "LS": return "Fichiers"
        case "WebFetch", "WebSearch": return "Web"
        case "Agent", "Task", "Workflow", "SendMessage", "TaskOutput", "SubagentHandback", "StructuredOutput", "TaskStop": return "Agents"
        case "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "TodoWrite", "ExitPlanMode", "EnterPlanMode": return "Planification"
        case "AskUserQuestion", "SendUserFile", "ScheduleWakeup", "PushNotification": return "Interaction"
        case "Artifact", "ArtifactComments", "ArtifactData", "Skill", "ToolSearch": return "Artifacts & skills"
        default: break
        }
        if name.hasPrefix("mcp__Claude_Browser") || name.hasPrefix("mcp__claude-in-chrome") { return "Navigateur" }
        if name.hasPrefix("mcp__ccd_") { return "Interaction" }
        if name.hasPrefix("mcp__") { return "Connecteurs MCP" }
        return "Autres"
    }

    static func pretty(_ name: String) -> String {
        guard name.hasPrefix("mcp__") else { return name }
        let parts = name.dropFirst(5).components(separatedBy: "__")
        guard parts.count >= 2 else { return name }
        return "\(serverShort(parts[0])) · \(parts[1])"
    }

    static func serverShort(_ server: String) -> String {
        switch server {
        case "Claude_Browser": return "Navigateur"
        case "claude-in-chrome": return "Chrome"
        case "ccd_session", "ccd_session_mgmt": return "Sessions"
        case "ccd_turn": return "Plan"
        case "ccd_view", "ccd_window", "ccd_sidebar": return "Interface"
        case "Claude_Code_iOS_Simulator": return "Simulateur iOS"
        case "visualize": return "Visualisation"
        default:
            if let n = SourceScanner.mcpNames[server] { return n }
            return server.count > 20 ? "Connecteur" : server
        }
    }


    static func serverLabel(_ name: String, ds: Dataset) -> String {
        let parts = name.dropFirst(5).components(separatedBy: "__")
        return serverShort(parts.first ?? name)
    }

    static func language(_ ext: String) -> String {
        switch ext {
        case "swift": return "Swift"
        case "py": return "Python"
        case "js", "mjs", "cjs": return "JavaScript"
        case "ts": return "TypeScript"
        case "tsx", "jsx": return "React"
        case "html", "htm": return "HTML"
        case "css", "scss": return "CSS"
        case "md", "markdown": return "Markdown"
        case "json": return "JSON"
        case "sh", "zsh", "bash": return "Shell"
        case "sql": return "SQL"
        case "yml", "yaml": return "YAML"
        case "txt": return "Texte"
        case "csv": return "CSV"
        case "tex": return "LaTeX"
        case "r": return "R"
        case "java": return "Java"
        case "kt": return "Kotlin"
        case "go": return "Go"
        case "rs": return "Rust"
        case "c", "h": return "C"
        case "cpp", "hpp", "cc": return "C++"
        case "m", "mm": return "Objective-C"
        case "rb": return "Ruby"
        case "php": return "PHP"
        case "vue": return "Vue"
        case "xml", "plist": return "XML"
        case "toml": return "TOML"
        case "ipynb": return "Notebook"
        case "do": return "Stata"
        case "typ": return "Typst"
        case "mqh", "mq4", "mq5": return "MQL"
        case "vba", "bas": return "VBA"
        case "": return "Sans extension"
        default: return ext.uppercased()
        }
    }
}
