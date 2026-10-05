import Foundation

enum LessonDistiller {
    static func candidates(
        messages: [Message],
        settings: LLMRequestSettings,
        client: any LLMServicing
    ) async throws -> [LessonCandidate] {
        var request = settings
        request.systemOverride = """
        List distinct learning points in this exchange that are worth a lesson.
        One item per word-sense, grammar use, or nuance/contrast — not one item per turn.
        A word with two senses is two candidates.

        Native language: \(settings.nativeLanguage).
        They are studying \(settings.targetLanguage).

        Reply with JSON only, no markdown:
        {"candidates":[{"kind":"word"|"grammar"|"nuance","title":"...","sense":"...","focus":"..."}]}
        title is the headword or pattern in \(settings.targetLanguage) when possible.
        sense is the specific meaning or use, short, in \(settings.nativeLanguage).
        focus is the learner's struggle in this talk, one line, in \(settings.nativeLanguage). Empty if unclear.
        If nothing is worth saving, return {"candidates":[]}.
        """

        let raw = try await client.complete(
            messages: [Message(role: .user, content: transcript(messages))],
            settings: request
        )
        return parseCandidates(raw)
    }

    static func generate(
        candidate: LessonCandidate,
        messages: [Message],
        settings: LLMRequestSettings,
        client: any LLMServicing
    ) async throws -> Lesson {
        var request = settings
        request.systemOverride = """
        Write ONE concise learning guide for this single point.
        Native language: \(settings.nativeLanguage).
        They are studying \(settings.targetLanguage).

        Kind: \(candidate.kind.rawValue)
        Title: \(candidate.title)
        Sense: \(candidate.sense)
        Focus (lean on this struggle): \(candidate.focus)

        Cover only this sense/use. Omit sections that this talk did not earn.
        Examples: group by this lesson's sense; put the in-context use first.
        Contrasts: similar words/patterns and how they differ, if the learner asked.
        Pitfalls: only real ones from the talk or this sense.

        Reply with JSON only, no markdown:
        {"kind":"word"|"grammar"|"nuance","title":"...","sense":"...","focus":"...","context":"...","examples":[{"sentence":"...","gloss":"..."}],"contrasts":[{"item":"...","difference":"..."}],"pitfalls":["..."]}
        title in \(settings.targetLanguage) when possible. sense, focus, gloss, difference in \(settings.nativeLanguage).
        """

        let raw = try await client.complete(
            messages: [
                Message(
                    role: .user,
                    content: "Transcript:\n\(transcript(messages))\n\nWrite the guide for this candidate only."
                ),
            ],
            settings: request
        )
        guard let lesson = parseLesson(raw, fallback: candidate) else {
            throw ReviewError.unreadableLesson
        }
        return lesson
    }

    private static func transcript(_ messages: [Message], limit: Int = 16) -> String {
        messages.suffix(limit).map { message in
            "\(message.role.rawValue): \(message.content)"
        }.joined(separator: "\n\n")
    }

    private static func parseCandidates(_ raw: String) -> [LessonCandidate] {
        guard let object = JSONSlice.object(in: raw) else { return [] }
        let rows = object["candidates"] as? [[String: Any]] ?? []
        return rows.compactMap { row in
            let title = (row["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if title.isEmpty { return nil }
            let kind = LessonKind(rawValue: (row["kind"] as? String)?.lowercased() ?? "") ?? .word
            return LessonCandidate(
                kind: kind,
                title: title,
                sense: (row["sense"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                focus: (row["focus"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            )
        }
    }

    private static func parseLesson(_ raw: String, fallback: LessonCandidate) -> Lesson? {
        guard let object = JSONSlice.object(in: raw) else { return nil }
        let title = (object["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if title.isEmpty { return nil }
        let kind = LessonKind(rawValue: (object["kind"] as? String)?.lowercased() ?? "") ?? fallback.kind
        let examples = (object["examples"] as? [[String: Any]] ?? []).compactMap { row -> LessonExample? in
            let sentence = (row["sentence"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if sentence.isEmpty { return nil }
            return LessonExample(
                sentence: sentence,
                gloss: (row["gloss"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            )
        }
        let contrasts = (object["contrasts"] as? [[String: Any]] ?? []).compactMap { row -> LessonContrast? in
            let item = (row["item"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if item.isEmpty { return nil }
            return LessonContrast(
                item: item,
                difference: (row["difference"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            )
        }
        let pitfalls = (object["pitfalls"] as? [String] ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let now = Date()
        return Lesson(
            id: UUID(),
            kind: kind,
            title: title,
            sense: (object["sense"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? fallback.sense,
            focus: (object["focus"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? fallback.focus,
            context: (object["context"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            examples: examples,
            contrasts: contrasts,
            pitfalls: pitfalls,
            sourceMessageID: nil,
            createdAt: now,
            updatedAt: now,
            nextReviewAt: now,
            intervalDays: 1
        )
    }
}

enum JSONSlice {
    static func object(in raw: String) -> [String: Any]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let slice: String
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            slice = String(trimmed[start...end])
        } else {
            slice = trimmed
        }
        guard let data = slice.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
