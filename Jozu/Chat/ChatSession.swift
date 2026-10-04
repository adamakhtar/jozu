import Foundation
import Observation

@MainActor
@Observable
final class ChatSession {
    var messages: [Message] = []
    var draft = ""
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
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var scrollAnchor: String {
        "\(messages.count)|\(messages.last?.content.count ?? 0)|\(isSending)"
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        draft = ""
        errorMessage = nil

        let user = Message(role: .user, content: text)
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
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
