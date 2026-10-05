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

    func asItem() -> MemoryItem {
        MemoryItem(
            id: id,
            kind: MemoryKind(rawValue: kindRaw) ?? .word,
            target: target,
            note: note,
            sourceMessageID: sourceMessageID,
            createdAt: createdAt,
            nextReviewAt: nextReviewAt,
            intervalDays: intervalDays
        )
    }
}

enum Persistence {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([StoredConversation.self, StoredMessage.self, StoredMemory.self])
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
