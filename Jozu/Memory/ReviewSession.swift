import Foundation
import Observation

@MainActor
@Observable
final class ReviewSession {
    enum Phase: Equatable {
        case writingQuestion
        case answering
        case grading
        case result
        case done
    }

    private(set) var queue: [Lesson]
    private(set) var current: Lesson?
    private(set) var question = ""
    var answer = ""
    private(set) var judgment: ReviewJudgment?
    private(set) var intervalDays: Int?
    private(set) var phase: Phase = .writingQuestion
    private(set) var errorMessage: String?
    private(set) var position = 1
    private(set) var total: Int

    private let settings: AppSettings
    private let lessonStore: LessonStore
    private var cursor = 0

    var hasMore: Bool {
        cursor + 1 < queue.count
    }

    var progressCaption: String {
        "\(min(position, total)) of \(total)"
    }

    var isBusy: Bool {
        phase == .writingQuestion || phase == .grading
    }

    var canSubmit: Bool {
        phase == .answering
            && !question.isEmpty
            && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isBusy
    }

    init(queue: [Lesson], settings: AppSettings, lessonStore: LessonStore) {
        self.queue = queue
        self.total = queue.count
        self.settings = settings
        self.lessonStore = lessonStore
        self.current = queue.first
    }

    func begin() async {
        guard current != nil else {
            phase = .done
            return
        }
        await writeQuestion()
    }

    func submit() async {
        guard canSubmit, let lesson = current else { return }
        errorMessage = nil
        phase = .grading
        do {
            try settings.requireKey()
            let request = LLMRequestSettings(settings)
            let client = try LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)
            let judged = try await ReviewEngine.grade(
                lesson: lesson,
                question: question,
                answer: answer,
                settings: request,
                client: client
            )
            let planned = ReviewScheduler.apply(grade: judged.grade)
            let updated = try lessonStore.schedule(
                lesson.id,
                intervalDays: planned.intervalDays,
                nextReviewAt: planned.nextReviewAt
            )
            current = updated
            judgment = judged
            intervalDays = planned.intervalDays
            phase = .result
        } catch {
            errorMessage = error.localizedDescription
            phase = .answering
        }
    }

    func advance() async {
        guard hasMore else {
            phase = .done
            current = nil
            return
        }
        cursor += 1
        position = cursor + 1
        current = queue[cursor]
        answer = ""
        question = ""
        judgment = nil
        intervalDays = nil
        errorMessage = nil
        await writeQuestion()
    }

    func skip() async {
        await advance()
    }

    func retry() async {
        errorMessage = nil
        if question.isEmpty {
            await writeQuestion()
        }
    }

    private func writeQuestion() async {
        guard let lesson = current else {
            phase = .done
            return
        }
        phase = .writingQuestion
        answer = ""
        question = ""
        judgment = nil
        intervalDays = nil
        do {
            try settings.requireKey()
            let request = LLMRequestSettings(settings)
            let client = try LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)
            question = try await ReviewEngine.probe(lesson: lesson, settings: request, client: client)
            phase = .answering
        } catch {
            errorMessage = error.localizedDescription
            phase = .answering
        }
    }
}
