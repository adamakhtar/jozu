import Foundation

enum LessonKind: String, Codable, CaseIterable, Sendable {
    case word
    case grammar
    case nuance

    var label: String {
        switch self {
        case .word: return "Word"
        case .grammar: return "Grammar"
        case .nuance: return "Nuance"
        }
    }
}

struct LessonExample: Codable, Hashable, Sendable {
    var sentence: String
    var gloss: String
}

struct LessonContrast: Codable, Hashable, Sendable {
    var item: String
    var difference: String
}

struct Lesson: Identifiable, Hashable, Sendable {
    let id: UUID
    var kind: LessonKind
    var title: String
    var sense: String
    var focus: String
    var context: String
    var examples: [LessonExample]
    var contrasts: [LessonContrast]
    var pitfalls: [String]
    var sourceMessageID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var nextReviewAt: Date
    var intervalDays: Int

    var isDue: Bool {
        nextReviewAt <= Date()
    }

    var subtitle: String {
        if !sense.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return sense }
        return focus
    }

    var scheduleCaption: String {
        if isDue { return "Due now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: nextReviewAt, relativeTo: Date())
    }

    var searchText: String {
        var parts = [title, sense, focus, context, kind.rawValue]
        parts += examples.flatMap { [$0.sentence, $0.gloss] }
        parts += contrasts.flatMap { [$0.item, $0.difference] }
        parts += pitfalls
        return parts.joined(separator: " ").lowercased()
    }

    var promptDump: String {
        var lines = [
            "kind: \(kind.rawValue)",
            "title: \(title)",
            "sense: \(sense)",
            "focus: \(focus)",
            "context: \(context)",
        ]
        for example in examples {
            lines.append("example: \(example.sentence) // \(example.gloss)")
        }
        for contrast in contrasts {
            lines.append("contrast: \(contrast.item) — \(contrast.difference)")
        }
        for pitfall in pitfalls {
            lines.append("pitfall: \(pitfall)")
        }
        return lines.joined(separator: "\n")
    }
}

struct LessonCandidate: Identifiable, Hashable, Sendable {
    let id: UUID
    var kind: LessonKind
    var title: String
    var sense: String
    var focus: String

    init(id: UUID = UUID(), kind: LessonKind, title: String, sense: String, focus: String) {
        self.id = id
        self.kind = kind
        self.title = title
        self.sense = sense
        self.focus = focus
    }

    var subtitle: String {
        if !sense.isEmpty { return sense }
        return focus
    }
}

enum RememberIntent {
    static func matches(_ text: String) -> Bool {
        let folded = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if folded.hasPrefix("remember ") { return true }
        if folded.contains("remember this") { return true }
        if folded.contains("remember that") { return true }
        if folded.contains("please remember") { return true }
        if folded.contains("save this") { return true }
        if folded.contains("覚えて") { return true }
        if folded.contains("記憶して") { return true }
        return false
    }
}

enum MergeIntent {
    static func matches(_ text: String) -> Bool {
        let folded = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if folded.hasPrefix("update lesson") { return true }
        if folded.hasPrefix("update the lesson") { return true }
        if folded.contains("update this lesson") { return true }
        if folded.contains("update the lesson") { return true }
        if folded.contains("merge this") { return true }
        if folded.contains("merge into the lesson") { return true }
        if folded.contains("save this update") { return true }
        if folded.contains("更新して") { return true }
        return false
    }
}
