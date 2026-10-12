import AVFoundation
import Foundation
import Observation
import Speech

enum DictationLanguage: String, CaseIterable, Identifiable, Sendable {
    case native
    case target

    var id: String { rawValue }
}

enum SpeechLocale {
    static func identifier(forLanguageName name: String) -> String {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "japanese", "日本語", "jp", "ja", "ja-jp", "ja_jp":
            return "ja-JP"
        case "english", "en", "en-us", "en_us", "en-gb", "en_gb",
             "british english", "uk english", "american english":
            return "en-GB"
        default:
            if let vision = VisionLanguage.codes(for: name).first {
                if vision.lowercased().hasPrefix("en") { return "en-GB" }
                return vision
            }
            return "en-GB"
        }
    }

    static func locale(forLanguageName name: String) -> Locale {
        resolved(from: Locale(identifier: identifier(forLanguageName: name)))
    }

    /// Pick a Speech locale the Mac actually has. Keyboard → Dictation may list
    /// "English" as US English; we still prefer `en-GB` when that pack exists.
    static func resolved(from preferred: Locale) -> Locale {
        let wanted = languageCode(preferred)
        let preferredID = canonical(preferred.identifier)
        let matches = SFSpeechRecognizer.supportedLocales().filter { languageCode($0) == wanted }
        guard !matches.isEmpty else { return preferred }
        if let exact = matches.first(where: { canonical($0.identifier) == preferredID }) {
            return exact
        }
        if wanted == "en", let gb = matches.first(where: { canonical($0.identifier).hasPrefix("en-gb") }) {
            return gb
        }
        return matches.sorted { canonical($0.identifier) < canonical($1.identifier) }.first ?? preferred
    }

    private static func languageCode(_ locale: Locale) -> String {
        let id = canonical(locale.identifier)
        return String(id.split(separator: "-").first ?? Substring(id))
    }

    private static func canonical(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }

    static func shortLabel(forLanguageName name: String) -> String {
        let id = identifier(forLanguageName: name).lowercased()
        if id.hasPrefix("ja") { return "JA" }
        if id.hasPrefix("en") { return "EN" }
        let language = id.split { $0 == "-" || $0 == "_" }.first.map(String.init) ?? id
        return language.uppercased()
    }
}

enum DictationError: LocalizedError {
    case microphoneDenied
    case speechDenied
    case recognizerUnavailable
    case onDeviceUnavailable(String)
    case noInputDevice

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone access is off. Enable it in System Settings → Privacy & Security → Microphone."
        case .speechDenied:
            return "Speech recognition is off. Enable it in System Settings → Privacy & Security → Speech Recognition."
        case .recognizerUnavailable:
            return "Dictation isn’t available for that language on this Mac."
        case .onDeviceUnavailable(let name):
            return "Couldn’t start on-device \(name). Add that exact language in System Settings → Keyboard → Dictation (British English is United Kingdom, not US) and allow Jozu under Privacy & Security → Speech Recognition."
        case .noInputDevice:
            return "No microphone found."
        }
    }
}

struct DictationInsertion: Equatable {
    var prefix: String
    var suffix: String
    var insertsSpace: Bool

    static func capturing(text: String, utf16Range: NSRange, insertsSpace: Bool) -> DictationInsertion {
        let ns = text as NSString
        let location: Int
        let length: Int
        if utf16Range.location == NSNotFound || utf16Range.location > ns.length {
            location = ns.length
            length = 0
        } else {
            location = utf16Range.location
            length = min(utf16Range.length, ns.length - location)
        }
        return DictationInsertion(
            prefix: ns.substring(to: location),
            suffix: ns.substring(from: location + length),
            insertsSpace: insertsSpace
        )
    }

    static func usesSpace(locale: Locale) -> Bool {
        let id = locale.identifier.lowercased()
        return !(id.hasPrefix("ja") || id.hasPrefix("zh") || id.hasPrefix("th") || id.hasPrefix("lo") || id.hasPrefix("km"))
    }

    func compose(_ spoken: String) -> String {
        head(spoken) + suffix
    }

    func committed(_ spoken: String) -> DictationInsertion {
        DictationInsertion(prefix: head(spoken), suffix: suffix, insertsSpace: insertsSpace)
    }

    func caretUTF16(after spoken: String) -> Int {
        (head(spoken) as NSString).length
    }

    private func head(_ spoken: String) -> String {
        let trimmed = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return prefix }
        if prefix.isEmpty { return spoken }
        if !insertsSpace { return prefix + spoken }
        if prefix.last?.isWhitespace == true { return prefix + spoken }
        return prefix + " " + spoken
    }
}

@MainActor
@Observable
final class DictationController {
    var isListening = false
    var errorMessage: String?

    private var engine: AVAudioEngine?
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let sink = BufferSink()
    private var tapInstalled = false
    private var wantsListening = false
    private var generation = 0
    private var onTranscript: ((String, Bool) -> Void)?

    func start(locale: Locale, onTranscript: @escaping (String, Bool) -> Void) async {
        stop()
        errorMessage = nil
        do {
            try await Self.authorize()
            let recognizer = try await Self.makeRecognizer(locale: locale)
            self.recognizer = recognizer
            self.onTranscript = onTranscript
            wantsListening = true
            try startEngine()
            try startTask()
            isListening = true
        } catch {
            stop()
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        wantsListening = false
        generation += 1
        isListening = false
        tearDownTask()
        if tapInstalled {
            engine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine?.stop()
        engine = nil
        recognizer = nil
        onTranscript = nil
    }

    private func startEngine() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw DictationError.noInputDevice
        }
        let sink = sink
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            sink.append(buffer)
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    private func startTask() throws {
        guard let recognizer else { throw DictationError.recognizerUnavailable }
        let gen = generation
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        self.request = request
        sink.set(request)
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handle(result: result, error: error, generation: gen)
            }
        }
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?, generation: Int) {
        guard wantsListening, generation == self.generation else { return }
        if let result {
            onTranscript?(result.bestTranscription.formattedString, result.isFinal)
            if result.isFinal {
                restartTask()
            }
            return
        }
        if let error {
            let ns = error as NSError
            if Self.isNoSpeech(ns) {
                restartTask()
                return
            }
            if Self.isOnDeviceAssetError(ns), let recognizer {
                errorMessage = DictationError.onDeviceUnavailable(Self.displayName(recognizer.locale)).errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            stop()
        }
    }

    private func restartTask() {
        guard wantsListening else { return }
        generation += 1
        tearDownTask()
        try? startTask()
    }

    private func tearDownTask() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        sink.set(nil)
    }

    private static func authorize() async throws {
        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { throw DictationError.speechDenied }

        let microphone: Bool = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
        guard microphone else { throw DictationError.microphoneDenied }
    }

    private static func makeRecognizer(locale: Locale) async throws -> SFSpeechRecognizer {
        let resolved = SpeechLocale.resolved(from: locale)
        guard let recognizer = SFSpeechRecognizer(locale: resolved) else {
            throw DictationError.recognizerUnavailable
        }
        recognizer.defaultTaskHint = .dictation
        // On macOS this flag is often false even when Keyboard → Dictation is
        // on and on-device requests work. Give the asset catalog a moment,
        // then proceed anyway and keep requiresOnDeviceRecognition on the request.
        if !recognizer.isAvailable || !recognizer.supportsOnDeviceRecognition {
            try await Task.sleep(nanoseconds: 400_000_000)
        }
        guard recognizer.isAvailable else {
            throw DictationError.recognizerUnavailable
        }
        return recognizer
    }

    private static func isNoSpeech(_ error: NSError) -> Bool {
        error.domain == "kAFAssistantErrorDomain" && (error.code == 216 || error.code == 1110)
    }

    private static func isOnDeviceAssetError(_ error: NSError) -> Bool {
        if error.domain == "kAFAssistantErrorDomain", error.code == 1101 {
            return true
        }
        let text = error.localizedDescription.lowercased()
        return text.contains("on-device") || text.contains("on device")
    }

    private static func displayName(_ locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }
}

private final class BufferSink: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let request = request
        lock.unlock()
        request?.append(buffer)
    }
}
