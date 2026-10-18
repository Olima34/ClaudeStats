import Foundation

/// A claude.ai conversation imported from the official data export (Settings › Privacy › Export data).
struct ChatConversation: Codable, Sendable {
    var uuid: String
    var name: String
    var createdAt: Double
    var messages: [ChatMessage]
}

struct ChatMessage: Codable, Sendable {
    var uuid: String
    var human: Bool
    var ts: Double
    var text: String
    var attachments: Int
}

enum ChatImport {
    enum ImportError: LocalizedError {
        case notFound, unreadable
        var errorDescription: String? {
            switch self {
            case .notFound: return "Aucun fichier conversations.json trouvé dans cet export."
            case .unreadable: return "Le fichier conversations.json n'a pas pu être lu."
            }
        }
    }

    static var storeURL: URL {
        SummaryCache.url.deletingLastPathComponent().appendingPathComponent("claude-ai-chats.json")
    }

    static func loadStored() -> [ChatConversation] {
        guard let data = try? Data(contentsOf: storeURL),
              let list = try? JSONDecoder().decode([ChatConversation].self, from: data) else { return [] }
        return list
    }

    static func clearStored() {
        try? FileManager.default.removeItem(at: storeURL)
    }

    /// Imports a .zip export, a folder, or the conversations.json file itself. Returns the number of conversations.
    @discardableResult
    static func importExport(at url: URL) throws -> Int {
        let fm = FileManager.default
        var jsonURL: URL?
        var tempDir: URL?
        defer { if let tempDir { try? fm.removeItem(at: tempDir) } }

        var isDir: ObjCBool = false
        fm.fileExists(atPath: url.path, isDirectory: &isDir)
        if isDir.boolValue {
            jsonURL = find(in: url)
        } else if url.pathExtension.lowercased() == "zip" {
            let dir = fm.temporaryDirectory.appendingPathComponent("claudestats-import-\(UUID().uuidString)")
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            tempDir = dir
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            p.arguments = ["-x", "-k", url.path, dir.path]
            try p.run()
            p.waitUntilExit()
            jsonURL = find(in: dir)
        } else {
            jsonURL = url
        }
        guard let jsonURL else { throw ImportError.notFound }
        guard let data = try? Data(contentsOf: jsonURL),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ImportError.unreadable
        }
        let conversations = arr.compactMap(parseConversation)
        let encoded = try JSONEncoder().encode(conversations)
        try encoded.write(to: storeURL, options: .atomic)
        return conversations.count
    }

    private static func find(in dir: URL) -> URL? {
        guard let en = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return nil }
        for case let u as URL in en where u.lastPathComponent == "conversations.json" { return u }
        return nil
    }

    private static func parseConversation(_ c: [String: Any]) -> ChatConversation? {
        guard let uuid = c["uuid"] as? String else { return nil }
        let name = (c["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Conversation sans titre"
        let created = parseTimestamp(c["created_at"] as? String) ?? 0
        let raw = (c["chat_messages"] as? [[String: Any]]) ?? []
        let messages: [ChatMessage] = raw.compactMap { m in
            guard let ts = parseTimestamp(m["created_at"] as? String) else { return nil }
            let sender = (m["sender"] as? String) ?? ""
            var text = (m["text"] as? String) ?? ""
            if text.isEmpty, let content = m["content"] as? [[String: Any]] {
                text = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
            }
            let att = ((m["attachments"] as? [Any])?.count ?? 0) + ((m["files"] as? [Any])?.count ?? 0)
            return ChatMessage(uuid: (m["uuid"] as? String) ?? UUID().uuidString,
                               human: sender == "human", ts: ts,
                               text: String(text.prefix(12000)), attachments: att)
        }
        guard !messages.isEmpty else { return nil }
        return ChatConversation(uuid: uuid, name: name, createdAt: created, messages: messages)
    }
}
