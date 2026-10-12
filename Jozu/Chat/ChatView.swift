import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ChatView: View {
    @Bindable var session: ChatSession
    @Bindable var dictation: DictationController
    @Environment(AppSettings.self) private var settings
    @State private var importingPhoto = false
    @State private var selectedUTF16Range = NSRange(location: 0, length: 0)
    @State private var insertion: DictationInsertion?
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            transcript
            Divider().overlay(JozuTheme.line)
            composer
        }
        .background(JozuTheme.paper)
        .onAppear {
            composerFocused = true
            consumeBeginDictationIfNeeded()
        }
        .onChange(of: session.beginDictation) {
            consumeBeginDictationIfNeeded()
        }
        .onChange(of: settings.dictationLanguage) {
            if dictation.isListening {
                Task { await startDictation() }
            }
        }
        .fileImporter(
            isPresented: $importingPhoto,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await loadFile(url) }
            case .failure(let error):
                session.errorMessage = error.localizedDescription
            }
        }
        .onDrop(of: [.image], isTargeted: nil, perform: importProviders)
        #if os(macOS)
        .onPasteCommand(of: [.image], perform: { providers in
            _ = importProviders(providers)
        })
        #endif
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if session.messages.isEmpty {
                        emptyState
                            .padding(.top, 48)
                    }

                    if let notice = session.notice {
                        Text(notice)
                            .font(.system(size: 12))
                            .foregroundStyle(JozuTheme.vermillion)
                    }

                    ForEach(session.messages) { message in
                        MessageBubble(
                            message: message,
                            isRemembering: session.rememberingID == message.id,
                            isSaved: session.isSaved(messageID: message.id),
                            onRemember: {
                                Task { await session.remember(from: message) }
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(20)
            }
            .onChange(of: session.scrollAnchor) {
                guard let anchor = session.messages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(anchor, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask about a word, a pattern, or a photo of text.")
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(JozuTheme.ink)
            Text("Type, or dictate in \(settings.nativeLanguage) or \(settings.targetLanguage). Audio stays on this Mac.")
                .font(.system(size: 13))
                .foregroundStyle(JozuTheme.muted)
            Button(dictation.isListening ? "Listening…" : "Dictate a message") {
                Task { await toggleDictation() }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(JozuTheme.vermillion)
            .disabled(session.isSending)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = composerError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.vermillion)
            }

            if session.pendingPhoto != nil {
                pendingPhotoRow
            }

            HStack(alignment: .bottom, spacing: 10) {
                JozuComposerField(
                    text: $session.draft,
                    placeholder: composerPlaceholder,
                    selectedUTF16Range: $selectedUTF16Range
                )
                .focused($composerFocused)

                Picker("Dictate in", selection: dictationLanguageBinding) {
                    Text(localeShort(settings.nativeLanguage)).tag(DictationLanguage.native)
                    Text(localeShort(settings.targetLanguage)).tag(DictationLanguage.target)
                }
                .pickerStyle(.segmented)
                .frame(width: 92)
                .help("Language to transcribe. On this Mac, not a server.")

                Button {
                    Task { await toggleDictation() }
                } label: {
                    Image(systemName: dictation.isListening ? "mic.fill" : "mic")
                        .foregroundStyle(dictation.isListening ? JozuTheme.vermillion : JozuTheme.ink)
                }
                .buttonStyle(.borderless)
                .help(dictation.isListening ? "Stop dictation" : "Dictate into this message")
                .disabled(session.isSending)

                Button {
                    importingPhoto = true
                } label: {
                    Image(systemName: "photo")
                }
                .buttonStyle(.borderless)
                .help("Attach a photo of text")
                .disabled(session.isSending)

                Button {
                    dictation.stop()
                    insertion = nil
                    Task { await session.send() }
                } label: {
                    Text("Send")
                        .font(.system(size: 13, weight: .semibold))
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!session.canSend)
            }

            Text(footerHint)
                .font(.system(size: 11))
                .foregroundStyle(JozuTheme.muted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var pendingPhotoRow: some View {
        HStack(alignment: .top, spacing: 10) {
            if let data = session.pendingPhoto?.thumbnailJPEG, let image = PlatformImage.view(from: data) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                if session.pendingPhoto?.isRecognizing == true {
                    Text("Reading text…")
                        .font(.system(size: 12))
                        .foregroundStyle(JozuTheme.muted)
                    ProgressView()
                        .controlSize(.small)
                } else {
                    TextField(
                        "Text from photo",
                        text: pendingOCRBinding,
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.ink)
                    .lineLimit(2...8)
                }
            }

            Button {
                session.discardPhoto()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(JozuTheme.muted)
            }
            .buttonStyle(.borderless)
            .help("Remove photo")
        }
        .padding(10)
        .background(JozuTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(JozuTheme.line, lineWidth: 1)
        )
    }

    private var footerHint: String {
        if dictation.isListening {
            return "Listening in \(dictationLanguageName). Click the mic to stop. Audio stays on this Mac."
        }
        if settings.hasAPIKey {
            return "Return for a new line, ⌘↩ to send. Mic dictates on this Mac."
        }
        return "Add an API key in Settings to chat, save lessons, and review."
    }

    private var composerPlaceholder: String {
        if dictation.isListening {
            return "Listening…"
        }
        if session.pendingPhoto == nil {
            return "Ask about \(settings.targetLanguage)…"
        }
        return "Ask about the photo, or send as-is…"
    }

    private var composerError: String? {
        if let error = dictation.errorMessage { return error }
        if session.needsSettings { return nil }
        return session.errorMessage
    }

    private var dictationLanguageName: String {
        settings.dictationLanguage == .native ? settings.nativeLanguage : settings.targetLanguage
    }

    private var dictationLanguageBinding: Binding<DictationLanguage> {
        Binding(
            get: { settings.dictationLanguage },
            set: { settings.dictationLanguage = $0 }
        )
    }

    private func consumeBeginDictationIfNeeded() {
        guard session.beginDictation else { return }
        session.beginDictation = false
        Task { await startDictation() }
    }

    private func toggleDictation() async {
        if dictation.isListening {
            dictation.stop()
            insertion = nil
            return
        }
        await startDictation()
    }

    private func startDictation() async {
        let locale = dictationLocale()
        insertion = DictationInsertion.capturing(
            text: session.draft,
            utf16Range: selectedUTF16Range,
            insertsSpace: DictationInsertion.usesSpace(locale: locale)
        )
        composerFocused = true
        await dictation.start(locale: locale) { spoken, isFinal in
            applyTranscript(spoken, isFinal: isFinal)
        }
        if !dictation.isListening {
            insertion = nil
        }
    }

    private func applyTranscript(_ spoken: String, isFinal: Bool) {
        guard var insertion else { return }
        session.draft = insertion.compose(spoken)
        selectedUTF16Range = NSRange(location: insertion.caretUTF16(after: spoken), length: 0)
        if isFinal {
            insertion = insertion.committed(spoken)
            self.insertion = insertion
        }
    }

    private func dictationLocale() -> Locale {
        let name = dictationLanguageName
        let code = VisionLanguage.codes(for: name).first ?? "en-US"
        return Locale(identifier: code)
    }

    private func localeShort(_ name: String) -> String {
        let code = VisionLanguage.codes(for: name).first ?? name
        let language = code.split(separator: "-").first.map(String.init) ?? code
        return language.uppercased()
    }

    private var pendingOCRBinding: Binding<String> {
        Binding(
            get: { session.pendingPhoto?.ocrText ?? "" },
            set: { text in
                guard var photo = session.pendingPhoto else { return }
                photo.ocrText = text
                session.pendingPhoto = photo
            }
        )
    }

    private func importProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }) else { return false }

        provider.loadDataRepresentation(for: .image) { data, _ in
            guard let data else { return }
            Task { @MainActor in
                await session.attachImage(data: data)
            }
        }
        return true
    }

    private func loadFile(_ url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let data = try Data(contentsOf: url)
            await session.attachImage(data: data)
        } catch {
            session.errorMessage = error.localizedDescription
        }
    }
}

private struct MessageBubble: View {
    let message: Message
    var isRemembering = false
    var isSaved = false
    var onRemember: (() -> Void)?

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 80) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                if let data = message.photoJPEG, let image = PlatformImage.view(from: data) {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if let ocr = message.ocrText, !ocr.isEmpty {
                    Text(ocr)
                        .font(.system(size: 12))
                        .foregroundStyle(message.role == .user ? JozuTheme.userInk.opacity(0.9) : JozuTheme.muted)
                        .textSelection(.enabled)
                }

                bubbleBody

                if message.role == .assistant, !message.content.isEmpty, onRemember != nil {
                    Button {
                        onRemember?()
                    } label: {
                        if isRemembering {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(isSaved ? "Remember again" : "Remember")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(JozuTheme.vermillion)
                    .disabled(isRemembering)
                    .help("Save a lesson from this stretch of chat")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(message.role == .user ? JozuTheme.vermillion : JozuTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(message.role == .user ? Color.clear : JozuTheme.line, lineWidth: 1)
            )

            if message.role == .assistant { Spacer(minLength: 80) }
        }
    }

    @ViewBuilder
    private var bubbleBody: some View {
        let text = message.ocrText == nil ? message.content : message.questionText
        if text.isEmpty {
            ProgressView()
                .controlSize(.small)
        } else {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(message.role == .user ? JozuTheme.userInk : JozuTheme.ink)
                .textSelection(.enabled)
        }
    }
}

private enum PlatformImage {
    static func view(from data: Data) -> Image? {
        #if os(macOS)
        return NSImage(data: data).map { Image(nsImage: $0) }
        #else
        return UIImage(data: data).map { Image(uiImage: $0) }
        #endif
    }
}
