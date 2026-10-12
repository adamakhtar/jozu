import Foundation
import SwiftData

struct ConversationSummary: Identifiable, Hashable {
    var id: UUID
    var title: String
    var updatedAt: Date
}

enum ChatStoreError: LocalizedError {
    case missingConversation

    var errorDescription: String? {
        switch self {
        case .missingConversation:
            return "That conversation is gone."
        }
    }
}

@MainActor
final class ChatStore {
    private let context: ModelContext
    private var conversation: StoredConversation
    private let defaults: UserDefaults

    private enum Key {
        static let currentID = "chat.currentConversationID"
    }

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
        if let stored = defaults.string(forKey: Key.currentID),
           let id = UUID(uuidString: stored),
           let existing = Self.fetch(id, in: context) {
            conversation = existing
        } else if let existing = Self.latest(in: context) {
            conversation = existing
        } else {
            let created = StoredConversation()
            context.insert(created)
            conversation = created
            try? context.save()
        }
        persistCurrentID()
    }

    var currentID: UUID { conversation.id }

    var currentTitle: String { Self.title(for: conversation) }

    func summaries() -> [ConversationSummary] {
        let descriptor = FetchDescriptor<StoredConversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.map { item in
            ConversationSummary(id: item.id, title: Self.title(for: item), updatedAt: item.updatedAt)
        } ?? []
    }

    func loadMessages() -> [Message] {
        conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.asMessage() }
    }

    func startNew() throws {
        if conversation.messages.isEmpty {
            persistCurrentID()
            return
        }
        let created = StoredConversation()
        context.insert(created)
        conversation = created
        persistCurrentID()
        try context.save()
    }

    func open(_ id: UUID) throws {
        if conversation.id == id {
            return
        }
        guard let found = Self.fetch(id, in: context) else {
            throw ChatStoreError.missingConversation
        }
        let abandoning = conversation
        conversation = found
        conversation.updatedAt = .now
        if abandoning.messages.isEmpty {
            context.delete(abandoning)
        }
        persistCurrentID()
        try context.save()
    }

    func append(_ message: Message) throws {
        let stored = StoredMessage(
            id: message.id,
            roleRaw: message.role.rawValue,
            content: message.content,
            createdAt: message.createdAt,
            conversation: conversation,
            photoJPEG: message.photoJPEG,
            ocrText: message.ocrText
        )
        context.insert(stored)
        conversation.updatedAt = .now
        try context.save()
    }

    func update(_ message: Message) throws {
        if let stored = conversation.messages.first(where: { $0.id == message.id }) {
            stored.content = message.content
            stored.photoJPEG = message.photoJPEG
            stored.ocrText = message.ocrText
            conversation.updatedAt = .now
            try context.save()
            return
        }
        try append(message)
    }

    private func persistCurrentID() {
        defaults.set(conversation.id.uuidString, forKey: Key.currentID)
    }

    private static func title(for conversation: StoredConversation) -> String {
        let first = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .first { $0.roleRaw == Message.Role.user.rawValue }?
            .content
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first, !first.isEmpty else { return "New conversation" }
        let line = first.split(whereSeparator: \.isNewline).first.map(String.init) ?? first
        if line.count <= 42 { return line }
        return String(line.prefix(41)) + "…"
    }

    private static func latest(in context: ModelContext) -> StoredConversation? {
        var descriptor = FetchDescriptor<StoredConversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetch(_ id: UUID, in context: ModelContext) -> StoredConversation? {
        var descriptor = FetchDescriptor<StoredConversation>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
