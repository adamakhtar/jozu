import Foundation

protocol LLMServicing: Sendable {
    func stream(messages: [Message], settings: LLMRequestSettings) -> AsyncThrowingStream<String, Error>
}

struct LLMRequestSettings: Sendable {
    let nativeLanguage: String
    let targetLanguage: String
    let replyLanguage: ReplyLanguage
    let model: String
    let apiBaseURL: String
    let apiKey: String

    @MainActor
    init(_ settings: AppSettings) {
        nativeLanguage = settings.nativeLanguage
        targetLanguage = settings.targetLanguage
        replyLanguage = settings.replyLanguage
        model = settings.model
        apiBaseURL = settings.apiBaseURL
        apiKey = settings.apiKey
    }

    var replyLanguageName: String {
        switch replyLanguage {
        case .native: return nativeLanguage
        case .target: return targetLanguage
        }
    }

    var systemPrompt: String {
        """
        You are Jozu, a language-learning companion.
        The learner's native language is \(nativeLanguage).
        They are studying \(targetLanguage).
        Reply in \(replyLanguageName) unless they explicitly ask otherwise.

        Be precise and brief.
        - Meaning: gloss, one natural example, one pitfall if it matters.
        - How to say X: everyday phrasing, a literal gloss, register if needed.
        - Grammar: name the pattern, show the frame, two short examples.
        Do not dump a textbook chapter. Do not praise the learner.

        When the user includes "Text from photo:", that is on-device OCR and may contain mistakes. \
        Prefer the intended reading. Do not mention OCR unless the text is genuinely ambiguous.

        Chat turns persist on this device. Review-item memory is not implemented yet. \
        If they say they want to remember something, restate the item you would store \
        and say it is not saved to review yet.
        """
    }
}

enum LLMServiceFactory {
    static func make(hasAPIKey: Bool) -> any LLMServicing {
        hasAPIKey ? OpenAICompatibleLLMService() : StubLLMService()
    }
}

struct StubLLMService: LLMServicing {
    func stream(messages: [Message], settings: LLMRequestSettings) -> AsyncThrowingStream<String, Error> {
        let last = messages.last(where: { $0.role == .user })?.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body: String
        if last.isEmpty {
            body = "Ask me what a word means, how a sentence works, or how to say something in \(settings.targetLanguage)."
        } else {
            body = """
            You asked: “\(last)”

            I would unpack this in \(settings.replyLanguageName): meaning, a natural example, and one thing to watch for. \
            Add an API key in Settings to get a real explanation.
            """
        }
        let reply = "Offline stub — no API key yet.\n\n\(body)"
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var index = reply.startIndex
                    while index < reply.endIndex {
                        try Task.checkCancellation()
                        let end = reply.index(index, offsetBy: 8, limitedBy: reply.endIndex) ?? reply.endIndex
                        continuation.yield(String(reply[index..<end]))
                        index = end
                        try await Task.sleep(for: .milliseconds(18))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

struct OpenAICompatibleLLMService: LLMServicing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func stream(messages: [Message], settings: LLMRequestSettings) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.write(messages: messages, settings: settings, to: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func write(
        messages: [Message],
        settings: LLMRequestSettings,
        to continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard let url = Self.endpoint(from: settings.apiBaseURL) else {
            throw LLMError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let payload = ChatCompletionRequest(
            model: settings.model,
            messages: [.init(role: "system", content: settings.systemPrompt)]
                + messages
                .filter { $0.role != .system }
                .map { .init(role: $0.role.rawValue, content: $0.content) },
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (bytes, response) = try await session.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if !(200...299).contains(status) {
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
            }
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.http(status: status, body: body)
        }

        var received = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard let payload = Self.ssePayload(from: line) else { continue }
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8) else { continue }
            guard let piece = try? JSONDecoder().decode(ChatCompletionChunk.self, from: data)
                .choices.first?.delta.content,
                !piece.isEmpty
            else { continue }
            received = true
            continuation.yield(piece)
        }

        if !received {
            throw LLMError.emptyResponse
        }
    }

    private static func ssePayload(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        return String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
    }

    private static func endpoint(from base: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: trimmed + "/chat/completions")
    }
}

enum LLMError: LocalizedError {
    case invalidBaseURL
    case emptyResponse
    case http(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "API base URL is invalid."
        case .emptyResponse:
            return "The model returned an empty reply."
        case .http(let status, let body):
            let snippet = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if snippet.isEmpty { return "The model request failed (\(status))." }
            return "The model request failed (\(status)): \(snippet.prefix(240))"
        }
    }
}

private struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let stream: Bool
}

private struct ChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }

        let delta: Delta
    }

    let choices: [Choice]
}
