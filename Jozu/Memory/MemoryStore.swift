import Foundation
import SwiftData

@MainActor
final class MemoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func all() -> [MemoryItem] {
        let descriptor = FetchDescriptor<StoredMemory>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.map { $0.asItem() } ?? []
    }

    func exists(sourceMessageID: UUID) -> Bool {
        all().contains { $0.sourceMessageID == sourceMessageID }
    }

    func insert(_ draft: MemoryDraft, sourceMessageID: UUID?) throws -> MemoryItem {
        let now = Date()
        let stored = StoredMemory(
            id: UUID(),
            kindRaw: draft.kind.rawValue,
            target: draft.target,
            note: draft.note,
            sourceMessageID: sourceMessageID,
            createdAt: now,
            nextReviewAt: now,
            intervalDays: 1
        )
        context.insert(stored)
        try context.save()
        return stored.asItem()
    }

    func delete(_ id: UUID) throws {
        var descriptor = FetchDescriptor<StoredMemory>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let stored = try context.fetch(descriptor).first else { return }
        context.delete(stored)
        try context.save()
    }
}
