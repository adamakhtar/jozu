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
    private var kit: [ReviewProbe] = []
    private var itemIndex = 0
    private var itemGrades: [Int: ReviewGrade] = [:]
    private var scheduled = false

    var question: String {
        guard kit.indices.contains(itemIndex) else { return "" }
        return kit[itemIndex].question
    }

    var currentProbe: ReviewProbe? {
        guard kit.indices.contains(itemIndex) else { return nil }
        return kit[itemIndex]
    }

    var itemPosition: Int { itemIndex + 1 }

    var itemTotal: Int {
        kit.isEmpty ? ReviewKitPlanner.size : kit.count
    }

    var hasMoreItems: Bool {
        itemIndex + 1 < kit.count
    }

    var hasMoreLessons: Bool {
        cursor + 1 < queue.count
    }

    /// Guide and interval stay hidden until the last probe of this lesson is graded.
    var revealsGuide: Bool {
        phase == .result && !hasMoreItems && scheduled
    }

    var canRetryItem: Bool {
        phase == .result && hasMoreItems && (judgment?.grade == .miss || judgment?.grade == .partial)
    }

    var progressCaption: String {
        let item = "\(min(itemPosition, itemTotal)) of \(itemTotal)"
        if total > 1 {
            return "Lesson \(min(position, total)) of \(total) · \(item)"
        }
        return item
    }

    var isBusy: Bool {
        phase == .writingQuestion || phase == .grading
    }

    var canSubmit: Bool {
        phase == .answering
            && currentProbe != nil
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
        await writeKit()
    }

    func submit() async {
        guard canSubmit, let lesson = current, let probe = currentProbe else { return }
        errorMessage = nil
        phase = .grading
        do {
            try settings.requireKey()
            let request = LLMRequestSettings(settings)
            let client = try LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)
            let judged = try await ReviewEngine.grade(
                lesson: lesson,
                probe: probe,
                answer: answer,
                settings: request,
                client: client
            )
            itemGrades[itemIndex] = judged.grade
            judgment = judged
            if !hasMoreItems {
                try commitSchedule()
            }
            phase = .result
        } catch {
            errorMessage = error.localizedDescription
            phase = .answering
        }
    }

    func advance() async {
        if hasMoreItems {
            itemIndex += 1
            answer = ""
            judgment = nil
            intervalDays = nil
            errorMessage = nil
            phase = .answering
            return
        }
        await advanceLesson()
    }

    func skip() async {
        await advanceLesson()
    }

    func retry() async {
        errorMessage = nil
        if kit.isEmpty {
            await writeKit()
        }
    }

    func retryItem() {
        guard canRetryItem else { return }
        judgment = nil
        intervalDays = nil
        errorMessage = nil
        phase = .answering
    }

    private func advanceLesson() async {
        guard hasMoreLessons else {
            phase = .done
            current = nil
            return
        }
        cursor += 1
        position = cursor + 1
        current = queue[cursor]
        await writeKit()
    }

    private func writeKit() async {
        guard let lesson = current else {
            phase = .done
            return
        }
        phase = .writingQuestion
        answer = ""
        judgment = nil
        intervalDays = nil
        errorMessage = nil
        kit = []
        itemIndex = 0
        itemGrades = [:]
        scheduled = false
        do {
            try settings.requireKey()
            let request = LLMRequestSettings(settings)
            let client = try LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)
            kit = try await ReviewEngine.makeKit(lesson: lesson, settings: request, client: client)
            phase = .answering
        } catch {
            errorMessage = error.localizedDescription
            phase = .answering
        }
    }

    private func commitSchedule() throws {
        guard let lesson = current else { return }
        let ordered = (0..<kit.count).compactMap { itemGrades[$0] }
        let combined = ReviewScheduler.combine(ordered)
        let planned = ReviewScheduler.apply(grade: combined)
        current = try lessonStore.schedule(
            lesson.id,
            intervalDays: planned.intervalDays,
            nextReviewAt: planned.nextReviewAt
        )
        intervalDays = planned.intervalDays
        scheduled = true
    }
}
