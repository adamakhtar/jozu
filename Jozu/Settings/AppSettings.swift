import Foundation
import Observation

enum ReplyLanguage: String, CaseIterable, Identifiable, Sendable {
    case native
    case target

    var id: String { rawValue }

    var label: String {
        switch self {
        case .native: "Native language"
        case .target: "Target language"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    var nativeLanguage: String {
        didSet { defaults.set(nativeLanguage, forKey: Key.nativeLanguage) }
    }

    var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: Key.targetLanguage) }
    }

    var replyLanguage: ReplyLanguage {
        didSet { defaults.set(replyLanguage.rawValue, forKey: Key.replyLanguage) }
    }

    var model: String {
        didSet { defaults.set(model, forKey: Key.model) }
    }

    var apiBaseURL: String {
        didSet { defaults.set(apiBaseURL, forKey: Key.apiBaseURL) }
    }

    var apiKey: String {
        didSet { KeychainStore.set(Key.apiKey, apiKey) }
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let defaults: UserDefaults

    private enum Key {
        static let nativeLanguage = "settings.nativeLanguage"
        static let targetLanguage = "settings.targetLanguage"
        static let replyLanguage = "settings.replyLanguage"
        static let model = "settings.model"
        static let apiBaseURL = "settings.apiBaseURL"
        static let apiKey = "apiKey"
    }

    init(
        nativeLanguage: String,
        targetLanguage: String,
        replyLanguage: ReplyLanguage,
        model: String,
        apiBaseURL: String,
        apiKey: String,
        defaults: UserDefaults = .standard
    ) {
        self.nativeLanguage = nativeLanguage
        self.targetLanguage = targetLanguage
        self.replyLanguage = replyLanguage
        self.model = model
        self.apiBaseURL = apiBaseURL
        self.apiKey = apiKey
        self.defaults = defaults
    }

    static func load(defaults: UserDefaults = .standard) -> AppSettings {
        AppSettings(
            nativeLanguage: defaults.string(forKey: Key.nativeLanguage) ?? "English",
            targetLanguage: defaults.string(forKey: Key.targetLanguage) ?? "Japanese",
            replyLanguage: ReplyLanguage(rawValue: defaults.string(forKey: Key.replyLanguage) ?? "") ?? .native,
            model: defaults.string(forKey: Key.model) ?? "gpt-4o-mini",
            apiBaseURL: defaults.string(forKey: Key.apiBaseURL) ?? "https://api.openai.com/v1",
            apiKey: KeychainStore.get(Key.apiKey) ?? "",
            defaults: defaults
        )
    }

    func replyLanguageName() -> String {
        switch replyLanguage {
        case .native: nativeLanguage
        case .target: targetLanguage
        }
    }
}
