import SwiftData
import SwiftUI

struct ChatView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var session: ChatSession?
    @State private var showingSettings = false
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
                session = ChatSession(settings: settings, store: ChatStore(context: modelContext))
            }
            composerFocused = true
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(settings)
                .frame(minWidth: 440, minHeight: 400)
        }
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

                        ForEach(session.messages) { message in
                            MessageBubble(message: message)
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
            Text("Ask about a word, a sentence, or how to say something.")
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(JozuTheme.ink)
            Text("This thread stays on this Mac. Photos, memory, and review come next.")
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

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    "",
                    text: draftBinding,
                    prompt: Text("Ask about \(settings.targetLanguage)…")
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
                    Task { await session?.send() }
                } label: {
                    Text("Send")
                        .font(.system(size: 13, weight: .semibold))
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!(session?.canSend ?? false))
            }

            Text(settings.hasAPIKey ? "⌘↩ to send. Saved on this Mac." : "No API key — replies are stubbed. Saved on this Mac. ⌘↩ to send.")
                .font(.system(size: 11))
                .foregroundStyle(JozuTheme.muted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { session?.draft ?? "" },
            set: { session?.draft = $0 }
        )
    }
}

private struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 80) }

            Group {
                if message.content.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundStyle(message.role == .user ? JozuTheme.userInk : JozuTheme.ink)
                        .textSelection(.enabled)
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
}

#Preview {
    ChatView()
        .environment(AppSettings.load())
        .modelContainer(Persistence.makeContainer(inMemory: true))
        .frame(width: 720, height: 800)
}
