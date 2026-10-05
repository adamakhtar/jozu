import Foundation

enum MemoryKind: String, Codable, CaseIterable, Sendable {
    case word
    case sentence
    case grammar

    var label: String {
        switch self {
        case .word: return "Word"
        case .sentence: return "Sentence"
        case .grammar: return "Grammar"
        }
    }
}

struct MemoryItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var kind: MemoryKind
    var target: String
    var note: String
    var sourceMessageID: UUID?
    var createdAt: Date
    var nextReviewAt: Date
    var intervalDays: Int

    var isDue: Bool {
        nextReviewAt <= Date()
    }

    var scheduleCaption: String {
        if isDue { return "Due now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: nextReviewAt, relativeTo: Date())
    }
}

struct MemoryDraft: Sendable {
    var kind: MemoryKind
    var target: String
    var note: String
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
