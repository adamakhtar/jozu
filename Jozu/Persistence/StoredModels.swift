import Foundation
import SwiftData

@Model
final class StoredConversation {
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \StoredMessage.conversation)
    var messages: [StoredMessage] = []

    init(createdAt: Date = .now, updatedAt: Date = .now) {
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = []
    }
}

@Model
final class StoredMessage {
    var id: UUID
    var roleRaw: String
    var content: String
    var createdAt: Date
    var conversation: StoredConversation?
    var photoJPEG: Data?
    var ocrText: String?

    init(
        id: UUID,
        roleRaw: String,
        content: String,
        createdAt: Date,
        conversation: StoredConversation,
        photoJPEG: Data? = nil,
        ocrText: String? = nil
    ) {
        self.id = id
        self.roleRaw = roleRaw
        self.content = content
        self.createdAt = createdAt
        self.conversation = conversation
        self.photoJPEG = photoJPEG
        self.ocrText = ocrText
    }

    func asMessage() -> Message {
        Message(
            id: id,
            role: Message.Role(rawValue: roleRaw) ?? .assistant,
            content: content,
            createdAt: createdAt,
            photoJPEG: photoJPEG,
            ocrText: ocrText
        )
    }
}

@Model
final class StoredMemory {
    var id: UUID
    var kindRaw: String
    var target: String
    var note: String
    var sourceMessageID: UUID?
    var createdAt: Date
    var nextReviewAt: Date
    var intervalDays: Int

    init(
        id: UUID,
        kindRaw: String,
        target: String,
        note: String,
        sourceMessageID: UUID?,
        createdAt: Date,
        nextReviewAt: Date,
        intervalDays: Int
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.target = target
        self.note = note
        self.sourceMessageID = sourceMessageID
        self.createdAt = createdAt
        self.nextReviewAt = nextReviewAt
        self.intervalDays = intervalDays
    }

    func asLesson() -> Lesson {
        let kind: LessonKind
        switch kindRaw {
        case LessonKind.grammar.rawValue, "sentence":
            kind = .grammar
        case LessonKind.nuance.rawValue:
            kind = .nuance
        default:
            kind = .word
        }
        let now = createdAt
        return Lesson(
            id: id,
            kind: kind,
            title: target,
            sense: "",
            focus: note,
            context: "",
            examples: [],
            contrasts: [],
            pitfalls: [],
            sourceMessageID: sourceMessageID,
            createdAt: createdAt,
            updatedAt: now,
            nextReviewAt: nextReviewAt,
            intervalDays: intervalDays
        )
    }
}

@Model
final class StoredLesson {
    var id: UUID
    var kindRaw: String
    var title: String
    var sense: String
    var focus: String
    var context: String
    var examplesJSON: Data
    var contrastsJSON: Data
    var pitfallsJSON: Data
    var sourceMessageID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var nextReviewAt: Date
    var intervalDays: Int

    init(from lesson: Lesson) {
        id = lesson.id
        kindRaw = lesson.kind.rawValue
        title = lesson.title
        sense = lesson.sense
        focus = lesson.focus
        context = lesson.context
        examplesJSON = Self.encode(lesson.examples)
        contrastsJSON = Self.encode(lesson.contrasts)
        pitfallsJSON = Self.encode(lesson.pitfalls)
        sourceMessageID = lesson.sourceMessageID
        createdAt = lesson.createdAt
        updatedAt = lesson.updatedAt
        nextReviewAt = lesson.nextReviewAt
        intervalDays = lesson.intervalDays
    }

    func asLesson() -> Lesson {
        Lesson(
            id: id,
            kind: LessonKind(rawValue: kindRaw) ?? .word,
            title: title,
            sense: sense,
            focus: focus,
            context: context,
            examples: Self.decode(examplesJSON, as: [LessonExample].self) ?? [],
            contrasts: Self.decode(contrastsJSON, as: [LessonContrast].self) ?? [],
            pitfalls: Self.decode(pitfallsJSON, as: [String].self) ?? [],
            sourceMessageID: sourceMessageID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            nextReviewAt: nextReviewAt,
            intervalDays: intervalDays
        )
    }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data("[]".utf8)
    }

    private static func decode<T: Decodable>(_ data: Data, as type: T.Type) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}

enum Persistence {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            StoredConversation.self,
            StoredMessage.self,
            StoredMemory.self,
            StoredLesson.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let fallback = ModelConfiguration(
                "jozu-memory",
                schema: schema,
                isStoredInMemoryOnly: true
            )
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                preconditionFailure("SwiftData container failed: \(error)")
            }
        }
    }
}
