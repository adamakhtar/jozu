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

    private(set) var queue: [MemoryItem]
    private(set) var current: MemoryItem?
    private(set) var question = ""
    var answer = ""
    private(set) var judgment: ReviewJudgment?
    private(set) var intervalDays: Int?
    private(set) var phase: Phase = .writingQuestion
    private(set) var errorMessage: String?
    private(set) var position = 1
    private(set) var total: Int

    private let settings: AppSettings
    private let memoryStore: MemoryStore
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

    init(queue: [MemoryItem], settings: AppSettings, memoryStore: MemoryStore) {
        self.queue = queue
        self.total = queue.count
        self.settings = settings
        self.memoryStore = memoryStore
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
        guard canSubmit, let item = current else { return }
        errorMessage = nil
        phase = .grading
        let request = LLMRequestSettings(settings)
        let client = LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)
        do {
            let judged = try await ReviewEngine.grade(
                item: item,
                question: question,
                answer: answer,
                settings: request,
                client: client
            )
            let planned = ReviewScheduler.apply(grade: judged.grade)
            let updated = try memoryStore.schedule(
                item.id,
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
        guard let item = current else {
            phase = .done
            return
        }
        phase = .writingQuestion
        answer = ""
        question = ""
        judgment = nil
        intervalDays = nil
        let request = LLMRequestSettings(settings)
        let client = LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)
        do {
            question = try await ReviewEngine.probe(item: item, settings: request, client: client)
            phase = .answering
        } catch {
            errorMessage = error.localizedDescription
            phase = .answering
        }
    }
}
