import Foundation

enum ReviewEngine {
    static func probe(
        lesson: Lesson,
        settings: LLMRequestSettings,
        client: any LLMServicing
    ) async throws -> String {
        var request = settings
        request.systemOverride = """
        You write ONE review probe for a language learner.
        Native language: \(settings.nativeLanguage).
        They are studying \(settings.targetLanguage).

        This lesson is ONE sense/use only. Test that sense, not other meanings.
        Lean on the learner's struggle (focus) when it is set.

        Kind: \(lesson.kind.rawValue)
        Title: \(lesson.title)
        Sense: \(lesson.sense)
        Focus: \(lesson.focus)
        Context: \(lesson.context)
        Contrasts: \(Self.encode(lesson.contrasts))
        Pitfalls: \(lesson.pitfalls.joined(separator: "; "))

        Write a question that makes them use this point, not only recognize it.
        Do not reveal a model answer. Do not quote the whole guide.

        Reply with JSON only, no markdown:
        {"question":"..."}
        Question in \(settings.nativeLanguage). Include any \(settings.targetLanguage) they must see.
        """

        let raw = try await client.complete(
            messages: [Message(role: .user, content: "Write the probe now.")],
            settings: request
        )
        if let question = parseProbe(raw) { return question }
        throw ReviewError.unreadableProbe
    }

    static func grade(
        lesson: Lesson,
        question: String,
        answer: String,
        settings: LLMRequestSettings,
        client: any LLMServicing
    ) async throws -> ReviewJudgment {
        var request = settings
        request.systemOverride = """
        You grade one language-learning review answer against this lesson's sense.
        Native language: \(settings.nativeLanguage).
        They are studying \(settings.targetLanguage).

        Grades:
        - miss: blank, wrong, or unusable
        - partial: on the right track but a real error
        - pass: acceptable, maybe small roughness
        - easy: fluent, no issue

        Accept valid paraphrases. Do not require exact match.
        Other senses of the same word are not required.

        Reply with JSON only, no markdown:
        {"grade":"miss"|"partial"|"pass"|"easy","reason":"...","next_hint":"..."}
        reason: one short sentence in \(settings.nativeLanguage).
        next_hint: one-line nudge if not easy, else empty.
        """

        let raw = try await client.complete(
            messages: [
                Message(
                    role: .user,
                    content: """
                    Title: \(lesson.title)
                    Sense: \(lesson.sense)
                    Focus: \(lesson.focus)
                    Question: \(question)
                    Answer: \(answer)
                    """
                ),
            ],
            settings: request
        )
        if let judgment = parseGrade(raw) { return judgment }
        throw ReviewError.unreadableGrade
    }

    private static func encode(_ contrasts: [LessonContrast]) -> String {
        contrasts.map { "\($0.item): \($0.difference)" }.joined(separator: "; ")
    }

    private static func parseProbe(_ raw: String) -> String? {
        guard let object = JSONSlice.object(in: raw) else { return nil }
        let question = (object["question"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return question.isEmpty ? nil : question
    }

    private static func parseGrade(_ raw: String) -> ReviewJudgment? {
        guard let object = JSONSlice.object(in: raw) else { return nil }
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
}

enum ReviewError: LocalizedError {
    case unreadableProbe
    case unreadableGrade
    case unreadableLesson
    case noCandidates
    case missingItem

    var errorDescription: String? {
        switch self {
        case .unreadableProbe:
            return "The model did not return a usable question."
        case .unreadableGrade:
            return "The model did not return a usable grade."
        case .unreadableLesson:
            return "The model did not return a usable lesson."
        case .noCandidates:
            return "Nothing in this stretch looks like a lesson yet."
        case .missingItem:
            return "That lesson is gone."
        }
    }
}
