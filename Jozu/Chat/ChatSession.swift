import Foundation
import Observation

@MainActor
@Observable
final class ChatSession {
    var messages: [Message] = []
    var memories: [MemoryItem] = []
    var draft = ""
    var pendingPhoto: PendingPhoto?
    var isSending = false
    var rememberingID: UUID?
    var errorMessage: String?
    var notice: String?

    private let settings: AppSettings
    private let store: ChatStore
    private let memoryStore: MemoryStore

    init(settings: AppSettings, store: ChatStore, memoryStore: MemoryStore) {
        self.settings = settings
        self.store = store
        self.memoryStore = memoryStore
        self.messages = store.loadMessages()
        self.memories = memoryStore.all()
    }

    var canSend: Bool {
        guard !isSending else { return false }
        if pendingPhoto?.isRecognizing == true { return false }
        let hasText = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || pendingPhoto != nil
    }

    var scrollAnchor: String {
        "\(messages.count)|\(messages.last?.content.count ?? 0)|\(isSending)|\(pendingPhoto != nil)"
    }

    func isSaved(messageID: UUID) -> Bool {
        memories.contains { $0.sourceMessageID == messageID }
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
        if isSaved(messageID: assistant.id) {
            notice = "Already saved from this turn."
            return
        }

        rememberingID = assistant.id
        defer { rememberingID = nil }

        let user = precedingUser(before: assistant)
        await saveMemory(user: user?.content ?? "", assistant: assistant.content, source: assistant.id)
    }

    func deleteMemory(_ id: UUID) {
        do {
            try memoryStore.delete(id)
            memories = memoryStore.all()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send() async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
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

        var request = LLMRequestSettings(settings)
        if RememberIntent.matches(question) {
            let saved: MemoryItem?
            if let lastAssistant = lastAssistant() {
                saved = await saveMemory(
                    user: question,
                    assistant: lastAssistant.content,
                    source: lastAssistant.id
                )
            } else {
                saved = await saveMemory(user: question, assistant: "", source: user.id)
            }
            if let saved {
                request.extraInstruction = "A review item was just saved: [\(saved.kind.label)] \(saved.target) — \(saved.note). Confirm in one short line."
            }
        }

        let outbound = messages
        var assistant = Message(role: .assistant, content: "")
        messages.append(assistant)
        isSending = true
        defer { isSending = false }

        let client = LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)

        do {
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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    private func saveMemory(user: String, assistant: String, source: UUID) async -> MemoryItem? {
        if isSaved(messageID: source) {
            notice = "Already saved from this turn."
            return memories.first { $0.sourceMessageID == source }
        }

        let request = LLMRequestSettings(settings)
        let client = LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)
        do {
            let draft = try await MemoryExtractor.extract(
                user: user,
                assistant: assistant,
                settings: request,
                client: client
            )
            let item = try memoryStore.insert(draft, sourceMessageID: source)
            memories = memoryStore.all()
            notice = "Saved \(item.kind.label.lowercased()): \(item.target)"
            return item
        } catch {
            errorMessage = "Could not save that: \(error.localizedDescription)"
            return nil
        }
    }

    private func lastAssistant() -> Message? {
        messages.last(where: { $0.role == .assistant && !$0.content.isEmpty })
    }

    private func precedingUser(before message: Message) -> Message? {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return nil }
        return messages[..<index].last(where: { $0.role == .user })
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
