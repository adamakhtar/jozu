import Foundation

protocol LLMServicing: Sendable {
    func complete(messages: [Message], settings: LLMRequestSettings) async throws -> String
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
        You are Jozu, a concise language-learning companion.
        The learner's native language is \(nativeLanguage).
        They are studying \(targetLanguage).
        Reply in \(replyLanguageName) unless they explicitly ask otherwise.
        Explain grammar clearly. Give short, natural examples.
        If they ask to remember a word, sentence, or grammar point, acknowledge it \
        and restate what you would store. Persistence is not wired yet — do not pretend it was saved.
        """
    }
}

enum LLMServiceFactory {
    static func make(hasAPIKey: Bool) -> any LLMServicing {
        hasAPIKey ? OpenAICompatibleLLMService() : StubLLMService()
    }
}

struct StubLLMService: LLMServicing {
    func complete(messages: [Message], settings: LLMRequestSettings) async throws -> String {
        try await Task.sleep(for: .milliseconds(350))
        let last = messages.last(where: { $0.role == .user })?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sample: String
        if last.isEmpty {
            sample = "Ask me what a word means, how a sentence works, or how to say something in \(settings.targetLanguage)."
        } else {
            sample = """
            You asked: “\(last)”

            I would unpack this in \(settings.replyLanguageName): meaning, a natural example, and one thing to watch for. \
            Add an API key in Settings to get a real explanation.
            """
        }
        return """
        Offline stub — no API key yet.

        \(sample)
        """
    }
}

struct OpenAICompatibleLLMService: LLMServicing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func complete(messages: [Message], settings: LLMRequestSettings) async throws -> String {
        guard let url = Self.endpoint(from: settings.apiBaseURL) else {
            throw LLMError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let payload = ChatCompletionRequest(
            model: settings.model,
            messages: [.init(role: "system", content: settings.systemPrompt)]
                + messages
                .filter { $0.role != .system }
                .map { .init(role: $0.role.rawValue, content: $0.content) }
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.http(status: status, body: body)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw LLMError.emptyResponse
        }
        return text
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
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}
