import Foundation
import SwiftData

@MainActor
final class LessonStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        migrateCrumbsIfNeeded()
    }

    func all() -> [Lesson] {
        let descriptor = FetchDescriptor<StoredLesson>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.map { $0.asLesson() } ?? []
    }

    func lesson(id: UUID) -> Lesson? {
        try? fetchLesson(id)?.asLesson()
    }

    @discardableResult
    func insert(_ lesson: Lesson) throws -> Lesson {
        if let existing = try duplicate(of: lesson) {
            return existing.asLesson()
        }
        let stored = StoredLesson(from: lesson)
        context.insert(stored)
        try context.save()
        return stored.asLesson()
    }

    func delete(_ id: UUID) throws {
        guard let stored = try fetchLesson(id) else { return }
        context.delete(stored)
        try context.save()
    }

    @discardableResult
    func schedule(_ id: UUID, intervalDays: Int, nextReviewAt: Date) throws -> Lesson {
        guard let stored = try fetchLesson(id) else { throw ReviewError.missingItem }
        stored.intervalDays = intervalDays
        stored.nextReviewAt = nextReviewAt
        stored.updatedAt = Date()
        try context.save()
        return stored.asLesson()
    }

    private func fetchLesson(_ id: UUID) throws -> StoredLesson? {
        var descriptor = FetchDescriptor<StoredLesson>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func duplicate(of lesson: Lesson) throws -> StoredLesson? {
        let all = try context.fetch(FetchDescriptor<StoredLesson>())
        let title = lesson.title.lowercased()
        let sense = lesson.sense.lowercased()
        return all.first {
            $0.title.lowercased() == title && $0.sense.lowercased() == sense
        }
    }

    private func migrateCrumbsIfNeeded() {
        let existing = (try? context.fetch(FetchDescriptor<StoredLesson>())) ?? []
        if !existing.isEmpty { return }
        let crumbs = (try? context.fetch(FetchDescriptor<StoredMemory>())) ?? []
        guard !crumbs.isEmpty else { return }
        for crumb in crumbs {
            context.insert(StoredLesson(from: crumb.asLesson()))
        }
        try? context.save()
    }
}
