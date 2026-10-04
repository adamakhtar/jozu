import Foundation
import SwiftData

@MainActor
final class ChatStore {
    private let context: ModelContext
    private let conversation: StoredConversation

    init(context: ModelContext) {
        self.context = context
        if let existing = Self.latest(in: context) {
            conversation = existing
        } else {
            let created = StoredConversation()
            context.insert(created)
            conversation = created
            try? context.save()
        }
    }

    func loadMessages() -> [Message] {
        conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.asMessage() }
    }

    func append(_ message: Message) throws {
        let stored = StoredMessage(
            id: message.id,
            roleRaw: message.role.rawValue,
            content: message.content,
            createdAt: message.createdAt,
            conversation: conversation
        )
        context.insert(stored)
        conversation.updatedAt = .now
        try context.save()
    }

    func update(_ message: Message) throws {
        if let stored = conversation.messages.first(where: { $0.id == message.id }) {
            stored.content = message.content
            conversation.updatedAt = .now
            try context.save()
            return
        }
        try append(message)
    }

    func deleteAllMessages() throws {
        for message in conversation.messages {
            context.delete(message)
        }
        conversation.updatedAt = .now
        try context.save()
    }

    private static func latest(in context: ModelContext) -> StoredConversation? {
        var descriptor = FetchDescriptor<StoredConversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
