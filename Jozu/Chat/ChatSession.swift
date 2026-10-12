import Foundation
import Observation

@MainActor
@Observable
final class ChatSession {
    var messages: [Message] = []
    var lessons: [Lesson] = []
    var draft = ""
    var pendingPhoto: PendingPhoto?
    var isSending = false
    var rememberingID: UUID?
    var errorMessage: String?
    var notice: String?
    var needsSettings = false
    var candidates: [LessonCandidate] = []
    var openedLessonID: UUID?
    private var pendingSourceID: UUID?

    private let settings: AppSettings
    private let store: ChatStore
    private let lessonStore: LessonStore

    init(settings: AppSettings, store: ChatStore, lessonStore: LessonStore) {
        self.settings = settings
        self.store = store
        self.lessonStore = lessonStore
        self.messages = store.loadMessages()
        self.lessons = lessonStore.all()
    }

    var dueCount: Int {
        lessons.filter(\.isDue).count
    }

    var canSend: Bool {
        guard !isSending else { return false }
        if pendingPhoto?.isRecognizing == true { return false }
        let hasText = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || pendingPhoto != nil
    }

    private func reviewQueue(startingAt itemID: UUID?) -> [Lesson] {
        let due = lessons.filter(\.isDue).sorted { $0.nextReviewAt < $1.nextReviewAt }
        if let itemID {
            guard let item = lessons.first(where: { $0.id == itemID }) else { return due }
            return [item] + due.filter { $0.id != itemID }
        }
        return due
    }

    func makeReviewSession(startingAt itemID: UUID?) -> ReviewSession? {
        let queue = reviewQueue(startingAt: itemID)
        guard !queue.isEmpty else { return nil }
        return ReviewSession(queue: queue, settings: settings, lessonStore: lessonStore)
    }

    func refreshLessons() {
        lessons = lessonStore.all()
    }

    var scrollAnchor: String {
        "\(messages.count)|\(messages.last?.content.count ?? 0)|\(isSending)|\(pendingPhoto != nil)"
    }

    func isSaved(messageID: UUID) -> Bool {
        lessons.contains { $0.sourceMessageID == messageID }
    }

    func attachImage(data: Data) async {
        errorMessage = nil
        guard
            let thumbnail = ImageData.jpegThumbnail(from: data, maxPixelSize: 480),
            let ocrImage = ImageData.cgImage(from: data, maxPixelSize: 2000)
        else {
            errorMessage = "Could not read that image."
            return
        }

        pendingPhoto = PendingPhoto(thumbnailJPEG: thumbnail, ocrText: "", isRecognizing: true)
        let languages = VisionLanguage.codes(from: [settings.targetLanguage, settings.nativeLanguage])

        do {
            let text = try await VisionTextRecognizer.recognize(image: ocrImage, languages: languages)
            var photo = pendingPhoto
            photo?.ocrText = text
            photo?.isRecognizing = false
            pendingPhoto = photo
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMessage = "No text found in the photo. Add a question or send it anyway."
            }
        } catch {
            var photo = pendingPhoto
            photo?.isRecognizing = false
            pendingPhoto = photo
            errorMessage = "Could not read text: \(error.localizedDescription)"
        }
    }

    func discardPhoto() {
        pendingPhoto = nil
    }

    func remember(from assistant: Message) async {
        errorMessage = nil
        rememberingID = assistant.id
        defer { rememberingID = nil }
        await distill(source: assistant.id)
    }

    func chooseCandidate(_ candidate: LessonCandidate) async {
        await generate(candidate, source: pendingSourceID)
        candidates = []
        pendingSourceID = nil
    }

    func cancelCandidates() {
        candidates = []
        pendingSourceID = nil
        rememberingID = nil
    }

    func deleteLesson(_ id: UUID) {
        do {
            try lessonStore.delete(id)
            lessons = lessonStore.all()
            if openedLessonID == id { openedLessonID = nil }
        } catch {
            present(error)
        }
    }

    func send() async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        do {
            try settings.requireKey()
        } catch {
            present(error)
            return
        }

        let photo = pendingPhoto
        draft = ""
        pendingPhoto = nil
        errorMessage = nil
        notice = nil

        let user = Message(
            role: .user,
            content: Self.compose(question: question, ocr: photo?.ocrText),
            photoJPEG: photo?.thumbnailJPEG,
            ocrText: photo?.ocrText
        )
        messages.append(user)
        persist(user)

        if RememberIntent.matches(question) {
            await distill(source: lastAssistant()?.id ?? user.id)
            if candidates.isEmpty, let notice {
                let assistant = Message(role: .assistant, content: notice)
                messages.append(assistant)
                persist(assistant)
            }
            return
        }

        let outbound = messages
        var assistant = Message(role: .assistant, content: "")
        messages.append(assistant)
        isSending = true
        defer { isSending = false }

        do {
            let client = try LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)
            let request = LLMRequestSettings(settings)
            for try await chunk in client.stream(messages: outbound, settings: request) {
                assistant.content += chunk
                replaceLast(assistant)
            }
            if assistant.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw LLMError.emptyResponse
            }
            persist(assistant)
        } catch is CancellationError {
            if !assistant.content.isEmpty {
                persist(assistant)
            } else {
                removeLastIfAssistantPlaceholder()
            }
        } catch {
            present(error)
            if assistant.content.isEmpty {
                removeLastIfAssistantPlaceholder()
            } else {
                persist(assistant)
            }
        }
    }

    func clear() {
        do {
            try store.deleteAllMessages()
            messages = []
            pendingPhoto = nil
            errorMessage = nil
            notice = nil
        } catch {
            present(error)
        }
    }

    private func distill(source: UUID?) async {
        pendingSourceID = source
        do {
            try settings.requireKey()
            let client = try LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)
            let request = LLMRequestSettings(settings)
            let found = try await LessonDistiller.candidates(
                messages: messages,
                settings: request,
                client: client
            )
            if found.isEmpty { throw ReviewError.noCandidates }
            if found.count == 1 {
                await generate(found[0], source: source)
                pendingSourceID = nil
                return
            }
            candidates = found
            notice = "Choose which point to save as a lesson."
        } catch {
            pendingSourceID = nil
            present(error)
        }
    }

    private func generate(_ candidate: LessonCandidate, source: UUID?) async {
        do {
            try settings.requireKey()
            let client = try LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)
            let request = LLMRequestSettings(settings)
            var lesson = try await LessonDistiller.generate(
                candidate: candidate,
                messages: messages,
                settings: request,
                client: client
            )
            lesson.sourceMessageID = source
            let saved = try lessonStore.insert(lesson)
            lessons = lessonStore.all()
            openedLessonID = saved.id
            notice = "Saved lesson: \(saved.title) — \(saved.subtitle)"
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        if let llm = error as? LLMError, llm.needsSettings {
            needsSettings = true
        }
    }

    private func lastAssistant() -> Message? {
        messages.last(where: { $0.role == .assistant && !$0.content.isEmpty })
    }

    private static func compose(question: String, ocr: String?) -> String {
        let reading = ocr?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if reading.isEmpty {
            return question.isEmpty ? "What should I learn from this photo?" : question
        }
        if question.isEmpty {
            return "Text from photo:\n\(reading)\n\nWhat does this say? Explain anything I should learn from it."
        }
        return "Text from photo:\n\(reading)\n\n\(question)"
    }

    private func replaceLast(_ message: Message) {
        guard let index = messages.indices.last else { return }
        messages[index] = message
    }

    private func removeLastIfAssistantPlaceholder() {
        guard let last = messages.last, last.role == .assistant, last.content.isEmpty else { return }
        messages.removeLast()
    }

    private func persist(_ message: Message) {
        do {
            try store.update(message)
        } catch {
            errorMessage = "Could not save this turn: \(error.localizedDescription)"
        }
    }
}
