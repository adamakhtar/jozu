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

    init(
        id: UUID,
        roleRaw: String,
        content: String,
        createdAt: Date,
        conversation: StoredConversation
    ) {
        self.id = id
        self.roleRaw = roleRaw
        self.content = content
        self.createdAt = createdAt
        self.conversation = conversation
    }

    func asMessage() -> Message {
        Message(
            id: id,
            role: Message.Role(rawValue: roleRaw) ?? .assistant,
            content: content,
            createdAt: createdAt
        )
    }
}

enum Persistence {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([StoredConversation.self, StoredMessage.self])
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
