import Foundation
import Observation

@MainActor
@Observable
final class ChatSession {
    var messages: [Message] = []
    var draft = ""
    var pendingPhoto: PendingPhoto?
    var isSending = false
    var errorMessage: String?

    private let settings: AppSettings
    private let store: ChatStore

    init(settings: AppSettings, store: ChatStore) {
        self.settings = settings
        self.store = store
        self.messages = store.loadMessages()
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

    func send() async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        let photo = pendingPhoto

        draft = ""
        pendingPhoto = nil
        errorMessage = nil

        let user = Message(
            role: .user,
            content: Self.compose(question: question, ocr: photo?.ocrText),
            photoJPEG: photo?.thumbnailJPEG,
            ocrText: photo?.ocrText
        )
        messages.append(user)
        persist(user)

        let outbound = messages
        var assistant = Message(role: .assistant, content: "")
        messages.append(assistant)
        isSending = true
        defer { isSending = false }

        let request = LLMRequestSettings(settings)
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
        } catch {
            errorMessage = error.localizedDescription
        }
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
