import Foundation

enum ReviewEngine {
    static func makeKit(
        lesson: Lesson,
        settings: LLMRequestSettings,
        client: any LLMServicing
    ) async throws -> [ReviewProbe] {
        let expected = ReviewKitPlanner.patterns(for: lesson)
        var request = settings
        request.systemOverride = """
        You write \(expected.count) review probes for a language learner, one per requested pattern, in that order.
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

        Requested patterns:
        \(Self.patternList(expected))

        Rules:
        - Distinct patterns. Do not write three translations of the same sentence.
        - Write a question that makes them use this point, not only recognize it.
        - Do not reveal a model answer. Do not quote the guide, examples, or pitfalls as the key.
        - For production items, do not name the headword unless the pattern is transform, cloze, or repair and the frame must be shown.
        - Question text in \(settings.nativeLanguage). Include any \(settings.targetLanguage) they must see (dialogue lines, cloze, the sentence to transform).

        Reply with JSON only, no markdown:
        {"probes":[\(expected.map { "{\"pattern\":\"\($0.rawValue)\",\"question\":\"...\"}" }.joined(separator: ","))]}
        """

        let raw = try await client.complete(
            messages: [Message(role: .user, content: "Write the probes now.")],
            settings: request
        )
        if let kit = parseKit(raw, expected: expected), !kit.isEmpty { return kit }
        throw ReviewError.unreadableProbe
    }

    static func grade(
        lesson: Lesson,
        probe: ReviewProbe,
        answer: String,
        settings: LLMRequestSettings,
        client: any LLMServicing
    ) async throws -> ReviewJudgment {
        var request = settings
        request.systemOverride = """
        You grade one language-learning review answer against this lesson's sense.
        Native language: \(settings.nativeLanguage).
        They are studying \(settings.targetLanguage).

        Pattern: \(probe.pattern.rawValue)
        \(probe.pattern.gradeRubric)

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
                    Pattern: \(probe.pattern.rawValue)
                    Question: \(probe.question)
                    Answer: \(answer)
                    """
                ),
            ],
            settings: request
        )
        if let judgment = parseGrade(raw) { return judgment }
        throw ReviewError.unreadableGrade
    }

    static func parseKit(_ raw: String, expected: [ReviewPattern]) -> [ReviewProbe]? {
        guard let object = JSONSlice.object(in: raw) else { return nil }
        if let rows = object["probes"] as? [[String: Any]] {
            let questions = rows.compactMap { row -> String? in
                let question = (row["question"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return question.isEmpty ? nil : question
            }
            guard !questions.isEmpty else { return nil }
            let count = min(questions.count, max(expected.count, 1))
            var probes: [ReviewProbe] = []
            for index in 0..<count {
                let pattern = expected.indices.contains(index) ? expected[index] : .produce
                probes.append(ReviewProbe(pattern: pattern, question: questions[index]))
            }
            return probes
        }
        let question = (object["question"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !question.isEmpty else { return nil }
        return [ReviewProbe(pattern: expected.first ?? .produce, question: question)]
    }

    private static func patternList(_ patterns: [ReviewPattern]) -> String {
        patterns.enumerated().map { index, pattern in
            "\(index + 1). \(pattern.rawValue): \(pattern.instruction)"
        }.joined(separator: "\n")
    }

    private static func encode(_ contrasts: [LessonContrast]) -> String {
        contrasts.map { "\($0.item): \($0.difference)" }.joined(separator: "; ")
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
            return "The model did not return usable questions."
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
