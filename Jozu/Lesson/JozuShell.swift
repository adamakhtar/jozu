import SwiftData
import SwiftUI

struct JozuShell: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var session: ChatSession?
    @State private var dictation = DictationController()
    @State private var pane: Pane = .chat
    @State private var showingSettings = false
    @State private var selectedLessonID: UUID?

    enum Pane: String, Hashable {
        case chat
        case lessons
    }

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            chrome(replyLanguage: $settings.replyLanguage)
            Divider().overlay(JozuTheme.line)
            if let session {
                switch pane {
                case .chat:
                    ChatView(session: session, dictation: dictation)
                case .lessons:
                    LessonLibraryView(session: session, selectedLessonID: $selectedLessonID)
                }
            } else {
                Spacer()
            }
        }
        .background(JozuTheme.paper)
        .preferredColorScheme(.light)
        .tint(JozuTheme.ink)
        .onAppear {
            if session == nil {
                session = ChatSession(
                    settings: settings,
                    store: ChatStore(context: modelContext),
                    lessonStore: LessonStore(context: modelContext)
                )
            }
        }
        .onChange(of: session?.openedLessonID) {
            if let id = session?.openedLessonID {
                selectedLessonID = id
                pane = .lessons
                session?.openedLessonID = nil
            }
        }
        .onChange(of: pane) {
            if pane != .chat {
                dictation.stop()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(settings)
                .frame(minWidth: 440, minHeight: 400)
        }
        .sheet(isPresented: candidatesPresented) {
            if let session {
                LessonPickerView(session: session)
                    .frame(minWidth: 420, minHeight: 360)
            }
        }
        .alert(
            "API key needed",
            isPresented: keyAlertPresented
        ) {
            Button("Settings") { showingSettings = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text(session?.errorMessage ?? "Add an OpenAI-compatible key in Settings.")
        }
    }

    private var candidatesPresented: Binding<Bool> {
        Binding(
            get: { !(session?.candidates.isEmpty ?? true) },
            set: { if !$0 { session?.cancelCandidates() } }
        )
    }

    private var keyAlertPresented: Binding<Bool> {
        Binding(
            get: { session?.needsSettings == true },
            set: { if !$0 { session?.needsSettings = false } }
        )
    }

    private func chrome(replyLanguage: Binding<ReplyLanguage>) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Jozu")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(JozuTheme.ink)
                conversationMenu
            }

            Picker("Pane", selection: $pane) {
                Text("Chat").tag(Pane.chat)
                Text(session.map { $0.dueCount > 0 ? "Lessons (\($0.dueCount) due)" : "Lessons" } ?? "Lessons")
                    .tag(Pane.lessons)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            Spacer()

            if pane == .chat {
                Picker("Reply in", selection: replyLanguage) {
                    Text(settings.nativeLanguage).tag(ReplyLanguage.native)
                    Text(settings.targetLanguage).tag(ReplyLanguage.target)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
                .help("Language the tutor replies in")

                Menu {
                    Button("New conversation") {
                        startNew(dictate: false)
                    }
                    Button("New with dictation") {
                        startNew(dictate: true)
                    }
                } label: {
                    Text("New")
                }
                .menuStyle(.borderlessButton)
                .disabled(session?.isSending == true)
                .help("Start a new conversation. The current one stays on this Mac.")
            }

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
    private var conversationMenu: some View {
        Menu {
            Button("New conversation") {
                startNew(dictate: false)
            }
            Button("New with dictation") {
                startNew(dictate: true)
            }
            if let session, !session.conversations.isEmpty {
                Divider()
                ForEach(session.conversations) { item in
                    Button {
                        dictation.stop()
                        session.openConversation(item.id)
                        pane = .chat
                    } label: {
                        if item.id == session.currentConversationID {
                            Label(item.title, systemImage: "checkmark")
                        } else {
                            Text(item.title)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(session?.conversationTitle ?? "New conversation")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 12))
            .foregroundStyle(JozuTheme.muted)
        }
        .menuStyle(.borderlessButton)
        .help("Past conversations on this Mac")
        .frame(maxWidth: 280, alignment: .leading)
    }

    private func startNew(dictate: Bool) {
        dictation.stop()
        pane = .chat
        session?.startNewConversation(beginDictation: dictate)
    }
}

struct LessonPickerView: View {
    @Bindable var session: ChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save which point?")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(JozuTheme.ink)
            Text("This stretch of chat has more than one lesson in it.")
                .font(.system(size: 13))
                .foregroundStyle(JozuTheme.muted)

            List(session.candidates) { candidate in
                Button {
                    Task { await session.chooseCandidate(candidate) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(candidate.kind.label.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(JozuTheme.vermillion)
                            Text(candidate.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(JozuTheme.ink)
                        }
                        if !candidate.subtitle.isEmpty {
                            Text(candidate.subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(JozuTheme.muted)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)

            HStack {
                Button("Cancel") { session.cancelCandidates() }
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(JozuTheme.paper)
        .preferredColorScheme(.light)
    }
}
