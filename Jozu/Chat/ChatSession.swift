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

    init(settings: AppSettings) {
        self.settings = settings
    }

    var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        draft = ""
        errorMessage = nil
        messages.append(Message(role: .user, content: text))
        isSending = true
        defer { isSending = false }

        let request = LLMRequestSettings(settings)
        let client = LLMServiceFactory.make(hasAPIKey: settings.hasAPIKey)

        do {
            let reply = try await client.complete(messages: messages, settings: request)
            messages.append(Message(role: .assistant, content: reply))
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
