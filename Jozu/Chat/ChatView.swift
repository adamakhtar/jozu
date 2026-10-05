import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ChatView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var session: ChatSession?
    @State private var showingSettings = false
    @State private var showingMemories = false
    @State private var startDueReview = false
    @State private var importingPhoto = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            header(replyLanguage: $settings.replyLanguage)
            Divider().overlay(JozuTheme.line)
            transcript
            Divider().overlay(JozuTheme.line)
            composer
        }
        .background(JozuTheme.paper)
        .preferredColorScheme(.light)
        .tint(JozuTheme.ink)
        .onAppear {
            if session == nil {
                session = ChatSession(
                    settings: settings,
                    store: ChatStore(context: modelContext),
                    memoryStore: MemoryStore(context: modelContext)
                )
            }
            composerFocused = true
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(settings)
                .frame(minWidth: 440, minHeight: 400)
        }
        .sheet(isPresented: $showingMemories, onDismiss: {
            startDueReview = false
            session?.refreshMemories()
        }) {
            if let session {
                MemorySheetView(session: session, startDue: startDueReview)
                    .frame(minWidth: 440, minHeight: 520)
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
                session?.errorMessage = error.localizedDescription
            }
        }
        .onDrop(of: [.image], isTargeted: nil, perform: importProviders)
        #if os(macOS)
        .onPasteCommand(of: [.image], perform: { providers in
            _ = importProviders(providers)
        })
        #endif
    }

    private func header(replyLanguage: Binding<ReplyLanguage>) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Jozu")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(JozuTheme.ink)
                Text("\(settings.targetLanguage) companion")
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.muted)
            }

            Spacer()

            Picker("Reply in", selection: replyLanguage) {
                Text(settings.nativeLanguage).tag(ReplyLanguage.native)
                Text(settings.targetLanguage).tag(ReplyLanguage.target)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
            .help("Language the tutor replies in")

            if let due = session?.dueCount, due > 0 {
                Button("Review (\(due))") {
                    startDueReview = true
                    showingMemories = true
                }
                .buttonStyle(.borderless)
                .help("Due review items")
            }

            Button {
                startDueReview = false
                showingMemories = true
            } label: {
                Text(session.map { "Memories (\($0.memories.count))" } ?? "Memories")
            }
            .buttonStyle(.borderless)
            .help("Review items saved on this Mac")

            Button("Clear") {
                session?.clear()
            }
            .buttonStyle(.borderless)
            .disabled(session?.messages.isEmpty ?? true || session?.isSending == true)
            .help("Delete this thread from this Mac")

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var transcript: some View {
        if let session {
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
        } else {
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask about a word, a sentence, or a photo of text.")
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(JozuTheme.ink)
            Text("Photos are read on this Mac. Remember a turn, then Review when it’s due.")
                .font(.system(size: 13))
                .foregroundStyle(JozuTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = session?.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.vermillion)
            }

            if session?.pendingPhoto != nil {
                pendingPhotoRow
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    "",
                    text: draftBinding,
                    prompt: Text(session?.pendingPhoto == nil
                        ? "Ask about \(settings.targetLanguage)…"
                        : "Ask about the photo, or send as-is…")
                        .foregroundStyle(JozuTheme.muted),
                    axis: .vertical
                )
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(JozuTheme.ink)
                    .lineLimit(1...6)
                    .focused($composerFocused)
                    .onSubmit {
                        Task { await session?.send() }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(JozuTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(JozuTheme.line, lineWidth: 1)
                    )

                Button {
                    importingPhoto = true
                } label: {
                    Image(systemName: "photo")
                }
                .buttonStyle(.borderless)
                .help("Attach a photo of text")
                .disabled(session?.isSending == true)

                Button {
                    Task { await session?.send() }
                } label: {
                    Text("Send")
                        .font(.system(size: 13, weight: .semibold))
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!(session?.canSend ?? false))
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
            if let data = session?.pendingPhoto?.thumbnailJPEG, let image = PlatformImage.view(from: data) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                if session?.pendingPhoto?.isRecognizing == true {
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
                session?.discardPhoto()
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
        if settings.hasAPIKey {
            return "⌘↩ to send. Remember a turn, then Review from Memories."
        }
        return "No API key — chat, remember, and review are stubbed on this Mac."
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { session?.draft ?? "" },
            set: { session?.draft = $0 }
        )
    }

    private var pendingOCRBinding: Binding<String> {
        Binding(
            get: { session?.pendingPhoto?.ocrText ?? "" },
            set: { text in
                guard var photo = session?.pendingPhoto else { return }
                photo.ocrText = text
                session?.pendingPhoto = photo
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
                await session?.attachImage(data: data)
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
            await session?.attachImage(data: data)
        } catch {
            session?.errorMessage = error.localizedDescription
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
                            Text(isSaved ? "Saved" : "Remember")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(isSaved ? JozuTheme.muted : JozuTheme.vermillion)
                    .disabled(isRemembering || isSaved)
                    .help("Save a review item from this turn")
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

#Preview {
    ChatView()
        .environment(AppSettings.load())
        .modelContainer(Persistence.makeContainer(inMemory: true))
        .frame(width: 720, height: 800)
}
