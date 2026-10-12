import Foundation

enum ReviewGrade: String, Codable, CaseIterable, Sendable, Comparable {
    case miss
    case partial
    case pass
    case easy

    var label: String {
        switch self {
        case .miss: return "Miss"
        case .partial: return "Partial"
        case .pass: return "Pass"
        case .easy: return "Easy"
        }
    }

    /// Coarse drip only. Not SM-2.
    var intervalDays: Int {
        switch self {
        case .miss: return 1
        case .partial: return 2
        case .pass: return 7
        case .easy: return 14
        }
    }

    private var rank: Int {
        switch self {
        case .miss: return 0
        case .partial: return 1
        case .pass: return 2
        case .easy: return 3
        }
    }

    static func < (lhs: ReviewGrade, rhs: ReviewGrade) -> Bool {
        lhs.rank < rhs.rank
    }
}

struct ReviewJudgment: Sendable {
    var grade: ReviewGrade
    var reason: String
    var nextHint: String
}

enum ReviewPattern: String, Codable, CaseIterable, Sendable {
    case produce
    case dialogue
    case resay
    case expand
    case transform
    case repair
    case cloze
    case contrastExplain
    case contrastProduce
    case situation

    var instruction: String {
        switch self {
        case .produce:
            return """
            Cued production: prompt in the native language (or a short situation) so they must write \
            a full target-language sentence that uses THIS sense. Do not name the headword/pattern \
            unless this is a grammar frame that cannot be cued otherwise. Constrain tense, object, \
            frequency, or politeness so this sense is almost obligatory.
            """
        case .dialogue:
            return """
            Conversation completion: give speaker A's line in the target language (and who they are \
            talking to if register matters). Learner writes B's next turn. The target should be a \
            natural reply, not named in the prompt.
            """
        case .resay:
            return """
            Re-production of the original struggle: using Focus/Context, ask them to say what they \
            were trying to say. Do not quote a model answer or the guide examples.
            """
        case .expand:
            return """
            Expansion/collocation: ask them to write a longer natural sentence using this sense with \
            a typical object, adverb, or complement — not a citation form.
            """
        case .transform:
            return """
            Transformation: give a grammatical sentence and ask them to change tense, polarity, \
            politeness, or person while keeping this pattern.
            """
        case .repair:
            return """
            Repair: give a plausible wrong sentence (from Pitfalls if set) and ask them to fix it \
            so it means X. Do not mark the error in a way that gives the answer away.
            """
        case .cloze:
            return """
            Cloze: a target-language sentence with a blank for the critical particle or form. They \
            type the missing bit. Never multiple choice.
            """
        case .contrastExplain:
            return """
            Nuance in the native language: ask them to explain how this item differs from a neighbour \
            (from Contrasts if set, else a close neighbour of this sense). Target-language production \
            is not required on this item.
            """
        case .contrastProduce:
            return """
            Forced contrast production: two short situations. They write the sentence where THIS item \
            is right, and the one where the neighbour is right (or why the neighbour would sound wrong).
            """
        case .situation:
            return """
            Situation to sentence: describe a scene with no full native-language sentence to translate. \
            They write what they would say. The scene must force this sense.
            """
        }
    }

    var gradeRubric: String {
        switch self {
        case .produce, .resay, .expand, .situation:
            return "Require this sense, usable grammar, and fitting particles/inflection. Accept valid paraphrases. A citation form alone is not a pass."
        case .dialogue:
            return "Require a reply that fits the turn (register, meaning) and uses this sense when that is the natural way to answer. Accept valid paraphrases."
        case .transform, .cloze:
            return "The changed or filled form must be correct for the requested operation. Small unrelated roughness can be partial or pass, not miss."
        case .repair:
            return "They must fix the actual error. A fluent rewrite that dodges it is at most partial."
        case .contrastExplain:
            return "Judge conceptual accuracy in the native language. Target-language production is not required."
        case .contrastProduce:
            return "Both sides of the contrast must be right enough to show they can choose the word. One right and one wrong is partial."
        }
    }
}

struct ReviewProbe: Equatable, Sendable {
    var pattern: ReviewPattern
    var question: String
}

enum ReviewKitPlanner {
    static let size = 3

    static func patterns(for lesson: Lesson) -> [ReviewPattern] {
        let hasFocus = !lesson.focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasContrasts = !lesson.contrasts.isEmpty
        let hasPitfalls = !lesson.pitfalls.isEmpty

        let chosen: [ReviewPattern]
        switch lesson.kind {
        case .word:
            chosen = [
                hasFocus ? .resay : .produce,
                .dialogue,
                hasContrasts ? .contrastProduce : .expand,
            ]
        case .grammar:
            chosen = [
                .transform,
                hasFocus ? .resay : .produce,
                hasPitfalls ? .repair : .cloze,
            ]
        case .nuance:
            chosen = [
                hasContrasts ? .contrastProduce : .produce,
                .contrastExplain,
                .dialogue,
            ]
        }
        return Array(chosen.prefix(Self.size))
    }
}

enum ReviewScheduler {
    static func apply(
        grade: ReviewGrade,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (intervalDays: Int, nextReviewAt: Date) {
        let days = grade.intervalDays
        let next = calendar.date(byAdding: .day, value: days, to: now)
            ?? now.addingTimeInterval(TimeInterval(days * 86_400))
        return (days, next)
    }

    /// Worst grade in the kit wins. Empty → miss.
    static func combine(_ grades: [ReviewGrade]) -> ReviewGrade {
        grades.min() ?? .miss
    }
}
