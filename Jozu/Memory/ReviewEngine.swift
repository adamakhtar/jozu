import Foundation

enum ReviewEngine {
    static func probe(
        item: MemoryItem,
        settings: LLMRequestSettings,
        client: any LLMServicing
    ) async throws -> String {
        if settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stubProbe(item: item)
        }

        var request = settings
        request.systemOverride = """
        You write ONE review probe for a language learner.
        Native language: \(settings.nativeLanguage).
        They are studying \(settings.targetLanguage).
        Item kind: \(item.kind.rawValue)
        Target: \(item.target)
        Note (do not quote this as the answer in the question): \(item.note)

        The probe should check they can use the item, not only recognize it.
        Word: meaning plus a short production, or use it in a sentence.
        Sentence: reproduce or recast it.
        Grammar: use the pattern in a new sentence.

        Write the question in \(settings.nativeLanguage). Include any \(settings.targetLanguage) \
        the learner must see. Do not reveal a model answer.

        Reply with JSON only, no markdown:
        {"question":"..."}
        """

        let messages = [
            Message(role: .user, content: "Write the probe now."),
        ]
        let raw = try await client.complete(messages: messages, settings: request)
        if let question = parseProbe(raw) { return question }
        throw ReviewError.unreadableProbe
    }

    static func grade(
        item: MemoryItem,
        question: String,
        answer: String,
        settings: LLMRequestSettings,
        client: any LLMServicing
    ) async throws -> ReviewJudgment {
        if settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stubGrade(item: item, answer: answer)
        }

        var request = settings
        request.systemOverride = """
        You grade one language-learning review answer.
        Native language: \(settings.nativeLanguage).
        They are studying \(settings.targetLanguage).

        Grades:
        - miss: blank, wrong, or unusable
        - partial: on the right track but a real error
        - pass: acceptable, maybe small roughness
        - easy: fluent, no issue

        Accept valid paraphrases. Do not require exact match.

        Reply with JSON only, no markdown:
        {"grade":"miss"|"partial"|"pass"|"easy","reason":"...","next_hint":"..."}
        reason: one short sentence in \(settings.nativeLanguage).
        next_hint: one-line nudge if not easy, else empty.
        """

        let messages = [
            Message(
                role: .user,
                content: """
                Kind: \(item.kind.rawValue)
                Target: \(item.target)
                Note: \(item.note)
                Question: \(question)
                Answer: \(answer)
                """
            ),
        ]
        let raw = try await client.complete(messages: messages, settings: request)
        if let judgment = parseGrade(raw) { return judgment }
        throw ReviewError.unreadableGrade
    }

    static func stubProbe(item: MemoryItem) -> String {
        switch item.kind {
        case .word:
            return "What does “\(item.target)” mean? Use it in a short sentence."
        case .sentence:
            return "Reproduce or recast this:\n\(item.target)"
        case .grammar:
            return "Use this pattern in a new sentence:\n\(item.target)"
        }
    }

    static func stubGrade(item: MemoryItem, answer: String) -> ReviewJudgment {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ReviewJudgment(
                grade: .miss,
                reason: "No answer.",
                nextHint: "Try a short sentence that uses the item."
            )
        }

        let answerFolded = trimmed.lowercased()
        let targetFolded = item.target.lowercased()
        if !targetFolded.isEmpty, answerFolded.contains(targetFolded), trimmed.count >= 8 {
            return ReviewJudgment(
                grade: .pass,
                reason: "Stub pass — you used the item. Add an API key for a real grade.",
                nextHint: ""
            )
        }
        if trimmed.count >= 12 {
            return ReviewJudgment(
                grade: .partial,
                reason: "Stub partial — something was written. Add an API key for a real grade.",
                nextHint: item.target.isEmpty ? "" : "Include “\(item.target)” if you can."
            )
        }
        return ReviewJudgment(
            grade: .miss,
            reason: "Stub miss — too little to go on. Add an API key for a real grade.",
            nextHint: "Write a full attempt."
        )
    }

    private static func parseProbe(_ raw: String) -> String? {
        guard let object = jsonObject(in: raw) else { return nil }
        let question = (object["question"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return question.isEmpty ? nil : question
    }

    private static func parseGrade(_ raw: String) -> ReviewJudgment? {
        guard let object = jsonObject(in: raw) else { return nil }
        let rawGrade = (object["grade"] as? String)?.lowercased() ?? ""
        guard let grade = ReviewGrade(rawValue: rawGrade) else { return nil }
        let reason = (object["reason"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hint = (object["next_hint"] as? String)
            ?? (object["nextHint"] as? String)
            ?? ""
        if reason.isEmpty { return nil }
        return ReviewJudgment(
            grade: grade,
            reason: reason,
            nextHint: hint.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func jsonObject(in raw: String) -> [String: Any]? {
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

enum ReviewError: LocalizedError {
    case unreadableProbe
    case unreadableGrade
    case missingItem

    var errorDescription: String? {
        switch self {
        case .unreadableProbe:
            return "The model did not return a usable question."
        case .unreadableGrade:
            return "The model did not return a usable grade."
        case .missingItem:
            return "That item is gone."
        }
    }
}
