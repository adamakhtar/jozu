import Foundation

enum MemoryExtractor {
    static func extract(
        user: String,
        assistant: String,
        settings: LLMRequestSettings,
        client: any LLMServicing
    ) async throws -> MemoryDraft {
        if settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return heuristic(user: user, assistant: assistant)
        }

        var request = settings
        request.systemOverride = """
        Extract ONE review item the learner should remember from this exchange.
        Reply with JSON only, no markdown:
        {"kind":"word"|"sentence"|"grammar","target":"...","note":"..."}
        target is the word, sentence, or pattern, in \(settings.targetLanguage) when possible.
        note is a short gloss in \(settings.nativeLanguage).
        """

        let messages = [
            Message(
                role: .user,
                content: "Learner:\n\(user)\n\nTutor:\n\(assistant)"
            ),
        ]

        let raw = try await client.complete(messages: messages, settings: request)
        if let draft = parse(raw) { return draft }
        return heuristic(user: user, assistant: assistant)
    }

    static func heuristic(user: String, assistant: String) -> MemoryDraft {
        if let quoted = firstQuoted(in: user) {
            return MemoryDraft(kind: .word, target: quoted, note: "From your question.")
        }
        let afterRemember = rememberTarget(in: user)
        if !afterRemember.isEmpty {
            return MemoryDraft(kind: .word, target: afterRemember, note: "Asked to remember.")
        }
        let line = firstUsefulLine(assistant) ?? firstUsefulLine(user) ?? "this turn"
        let kind: MemoryKind
        if line.count > 24 || line.contains(" ") {
            kind = line.count > 48 ? .sentence : .grammar
        } else {
            kind = .word
        }
        return MemoryDraft(kind: kind, target: line, note: "Saved from this turn.")
    }

    private static func parse(_ raw: String) -> MemoryDraft? {
        guard let data = jsonObject(in: raw) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let kind = MemoryKind(rawValue: (object["kind"] as? String)?.lowercased() ?? "") ?? .word
        let target = (object["target"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let note = (object["note"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if target.isEmpty { return nil }
        return MemoryDraft(kind: kind, target: target, note: note)
    }

    private static func jsonObject(in raw: String) -> Data? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end]).data(using: .utf8)
        }
        return trimmed.data(using: .utf8)
    }

    private static func firstQuoted(in text: String) -> String? {
        let patterns = ["\"([^\"]+)\"", "「([^」]+)」", "'([^']+)'"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text)
            {
                let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
        }
        return nil
    }

    private static func rememberTarget(in text: String) -> String {
        let prefixes = ["remember this ", "remember that ", "remember ", "please remember ", "save this "]
        let folded = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = folded.lowercased()
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                return String(folded.dropFirst(prefix.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".:"))
            }
        }
        return ""
    }

    private static func firstUsefulLine(_ text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("Offline stub") { continue }
            return String(trimmed.prefix(80))
        }
        return nil
    }
}
