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
    @Environment(AppSettings.self) private var settings
    @State private var importingPhoto = false
    @State private var showingPeek = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            transcript
            Divider().overlay(JozuTheme.line)
            composer
        }
        .background(JozuTheme.paper)
        .onAppear { composerFocused = true }
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
        .sheet(isPresented: $showingPeek) {
            PeekSheet(session: session)
        }
        #endif
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if let lesson = session.discussingLesson {
                        discussBanner(lesson)
                    }

                    if session.displayedMessages.isEmpty {
                        emptyState
                            .padding(.top, session.discussingLesson == nil ? 48 : 8)
                    }

                    if let notice = session.notice, session.discussingLessonID == nil {
                        Text(notice)
                            .font(.system(size: 12))
                            .foregroundStyle(JozuTheme.vermillion)
                    }

                    ForEach(session.displayedMessages) { message in
                        MessageBubble(
                            message: message,
                            isRemembering: session.rememberingID == message.id,
                            isSaved: session.isSaved(messageID: message.id),
                            onRemember: rememberAction(for: message)
                        )
                        .id(message.id)
                    }
                }
                .padding(20)
            }
            .onChange(of: session.scrollAnchor) {
                guard let anchor = session.displayedMessages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(anchor, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            if session.discussingLesson != nil {
                Text("Ask a follow-up about this lesson.")
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(JozuTheme.ink)
                Text("When the guide should change, Update lesson. Done returns to the inbox.")
                    .font(.system(size: 13))
                    .foregroundStyle(JozuTheme.muted)
            } else {
                Text("Ask about a word, a pattern, a photo, or selected text from another app.")
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(JozuTheme.ink)
                Text("Remember a turn to save a lesson. Peek reads a selection you confirm. Open Lessons to search, discuss, and review.")
                    .font(.system(size: 13))
                    .foregroundStyle(JozuTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func discussBanner(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Discussing")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(JozuTheme.vermillion)
                    Text(lesson.title)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundStyle(JozuTheme.ink)
                    if !lesson.subtitle.isEmpty {
                        Text(lesson.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(JozuTheme.muted)
                    }
                }
                Spacer()
                Button("Update lesson") {
                    Task { await session.mergeLesson() }
                }
                .disabled(!session.canMerge)
                .help("Rewrite the guide from this discussion")
                Button("Done") {
                    session.exitDiscuss()
                }
                .buttonStyle(.borderless)
                .disabled(session.isSending || session.isMerging)
                .help("Return to the inbox. The discussion stays with the lesson.")
            }
            if session.isMerging {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Updating the lesson…")
                        .font(.system(size: 12))
                        .foregroundStyle(JozuTheme.muted)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JozuTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(JozuTheme.line, lineWidth: 1)
        )
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = session.errorMessage, session.needsSettings == false {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.vermillion)
            }

            if session.pendingPhoto != nil {
                pendingPhotoRow
            }

            if session.pendingPeek != nil {
                pendingPeekRow
            }

            HStack(alignment: .bottom, spacing: 10) {
                JozuComposerField(
                    text: $session.draft,
                    placeholder: composerPlaceholder
                )
                .focused($composerFocused)

                Button {
                    importingPhoto = true
                } label: {
                    Image(systemName: "photo")
                }
                .buttonStyle(.borderless)
                .help("Attach a photo of text")
                .disabled(session.isSending || session.isMerging)

                #if os(macOS)
                Button {
                    showingPeek = true
                } label: {
                    Image(systemName: "eye")
                }
                .buttonStyle(.borderless)
                .help("Peek selected text from an allowed app")
                .disabled(session.isSending || session.isMerging)
                #endif

                Button {
                    Task { await session.send() }
                } label: {
                    Text("Send")
                        .font(.system(size: 13, weight: .semibold))
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!session.canSend || session.isMerging)
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

    private var pendingPeekRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "eye")
                .foregroundStyle(JozuTheme.vermillion)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text("From \(session.pendingPeek?.appName ?? "app")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(JozuTheme.vermillion)
                TextField(
                    "Selected text",
                    text: pendingPeekBinding,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(JozuTheme.ink)
                .lineLimit(2...8)
            }

            Button {
                session.discardPeek()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(JozuTheme.muted)
            }
            .buttonStyle(.borderless)
            .help("Remove peeked text")
        }
        .padding(10)
        .background(JozuTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(JozuTheme.line, lineWidth: 1)
        )
    }

    private var composerPlaceholder: String {
        if session.pendingPeek != nil || session.pendingPhoto != nil {
            return "Ask about the attached text, or send as-is…"
        }
        if session.discussingLesson != nil {
            return "Ask a follow-up about this lesson…"
        }
        return "Ask about \(settings.targetLanguage)…"
    }

    private var footerHint: String {
        if !settings.hasAPIKey {
            return "Add an API key in Settings to chat, save lessons, and review."
        }
        if session.discussingLesson != nil {
            return "Return for a new line, ⌘↩ to send. Update lesson when the guide should change."
        }
        return "Return for a new line, ⌘↩ to send. Peek selected text from an allowed app, or Remember a turn."
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

    private var pendingPeekBinding: Binding<String> {
        Binding(
            get: { session.pendingPeek?.text ?? "" },
            set: { text in
                guard var peek = session.pendingPeek else { return }
                peek.text = text
                session.pendingPeek = peek
            }
        )
    }

    private func rememberAction(for message: Message) -> (() -> Void)? {
        guard session.discussingLessonID == nil else { return nil }
        return {
            Task { await session.remember(from: message) }
        }
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

                if let peek = message.peekText, !peek.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        if let app = message.peekAppName, !app.isEmpty {
                            Text(app)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(message.role == .user ? JozuTheme.userInk.opacity(0.75) : JozuTheme.vermillion)
                        }
                        Text(peek)
                            .font(.system(size: 12))
                            .foregroundStyle(message.role == .user ? JozuTheme.userInk.opacity(0.9) : JozuTheme.muted)
                            .textSelection(.enabled)
                    }
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
        let text = (message.ocrText == nil && message.peekText == nil) ? message.content : message.questionText
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
