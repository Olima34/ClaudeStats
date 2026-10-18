import Foundation

/// Where a session comes from.
enum SourceKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case desktop   // Claude Code inside the Claude desktop app
    case cli       // Claude Code in a terminal
    case cowork    // Cowork mode of the desktop app
    case chat      // claude.ai conversations (imported export)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .desktop: return "Claude Code (app)"
        case .cli: return "Claude Code (terminal)"
        case .cowork: return "Cowork"
        case .chat: return "Chat claude.ai"
        }
    }

    var shortLabel: String {
        switch self {
        case .desktop: return "Code"
        case .cli: return "Terminal"
        case .cowork: return "Cowork"
        case .chat: return "Chat"
        }
    }

    var symbol: String {
        switch self {
        case .desktop: return "chevron.left.forwardslash.chevron.right"
        case .cli: return "terminal"
        case .cowork: return "person.2"
        case .chat: return "bubble.left.and.bubble.right"
        }
    }
}

enum PromptKind: UInt8, Codable, Sendable {
    case human      // a message typed by the user
    case command    // a slash command (/compact, /model…)
    case shell      // a "!" shell command typed by the user
}

/// One message written by the user.
struct PromptRec: Codable, Sendable {
    var id: String
    var session: String
    var ts: Double
    var text: String
    var kind: PromptKind
    var images: Int
    var command: String?
}

/// One tool call made by Claude.
struct ToolRec: Codable, Sendable {
    var name: String
    var file: String?
    var add: Int
    var del: Int
    var detail: String?
}

/// One line of an assistant message (Claude Code splits a message into one line per content block).
struct AssistantRec: Codable, Sendable {
    var uuid: String
    var msgId: String
    var session: String
    var ts: Double
    var model: String
    var input: Int
    var output: Int
    var cacheRead: Int
    var cacheWrite: Int
    var cacheWrite1h: Int
    var thinkMs: Int
    var textChars: Int
    var tools: [ToolRec]
    var sidechain: Bool
}

enum MarkerKind: UInt8, Codable, Sendable {
    case interrupt, compact, apiError, usageLimit, scheduled, taskNotification
}

struct MarkerRec: Codable, Sendable {
    var session: String
    var ts: Double
    var kind: MarkerKind
}

/// Per-session information found while reading a transcript.
struct SessionHint: Codable, Sendable {
    var session: String
    var cwd: String?
    var entrypoint: String?
    var title: String?
    var gitBranch: String?
}

/// Everything extracted from one transcript file. Cached between launches.
struct FileSummary: Codable, Sendable {
    var path: String
    var size: Int64
    var mtime: Double
    var source: SourceKind
    var isSubagent: Bool
    var prompts: [PromptRec]
    var assistants: [AssistantRec]
    var markers: [MarkerRec]
    var hints: [SessionHint]
}

/// Metadata the desktop app keeps for its sessions (titles, model, archive state…).
struct DesktopSessionMeta: Sendable {
    var cliSessionId: String
    var title: String?
    var model: String?
    var effort: String?
    var isArchived: Bool
    var scheduledTaskId: String?
    var forkedFrom: String?
    var cwd: String?
    var createdAt: Double?
    var isCowork: Bool
}

/// A sample of the plan usage history (five-hour window and weekly usage in %).
struct UsageSample: Sendable, Identifiable {
    var id: Double { ts }
    var ts: Double
    var fiveHour: Double
    var weekly: Double
}

struct AccountInfo: Sendable {
    var displayName: String
    var plan: String
    var firstStart: Date?
}
