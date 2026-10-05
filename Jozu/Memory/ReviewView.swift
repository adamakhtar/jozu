import SwiftUI

struct MemorySheetView: View {
    @Bindable var session: ChatSession
    var startDue: Bool
    @State private var review: ReviewSession?
    @State private var showReview = false
    @State private var didAutoStart = false

    var body: some View {
        NavigationStack {
            MemoryListView(
                items: session.memories,
                onDelete: { session.deleteMemory($0) },
                onReview: { id in startReview(itemID: id) }
            )
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if session.dueCount > 0 {
                        Button("Review due") {
                            startReview(itemID: nil)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showReview) {
                if let review {
                    ReviewView(session: review) {
                        finishReview()
                    }
                }
            }
        }
        .onChange(of: showReview) {
            if !showReview {
                review = nil
                session.refreshMemories()
            }
        }
        .task {
            guard startDue, !didAutoStart else { return }
            didAutoStart = true
            startReview(itemID: nil)
        }
    }

    private func startReview(itemID: UUID?) {
        guard let next = session.makeReviewSession(startingAt: itemID) else { return }
        review = next
        showReview = true
        Task { await next.begin() }
    }

    private func finishReview() {
        showReview = false
        review = nil
        session.refreshMemories()
    }
}

struct ReviewView: View {
    @Bindable var session: ReviewSession
    var onClose: () -> Void
    @FocusState private var answerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(session.progressCaption)
                .font(.system(size: 12))
                .foregroundStyle(JozuTheme.muted)

            switch session.phase {
            case .writingQuestion:
                status("Writing a question…")
            case .grading:
                prompt
                answerField
                status("Grading…")
            case .answering:
                prompt
                answerField
            case .result:
                prompt
                answerField
                result
            case .done:
                Text("That’s the lot for now.")
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(JozuTheme.ink)
            }

            if let error = session.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.vermillion)
            }

            Spacer(minLength: 0)

            controls
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(JozuTheme.paper)
        .preferredColorScheme(.light)
        .navigationTitle("Review")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onClose() }
            }
        }
        .onChange(of: session.phase) {
            if session.phase == .answering {
                answerFocused = true
            }
        }
    }

    @ViewBuilder
    private var prompt: some View {
        if !session.question.isEmpty {
            Text(session.question)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(JozuTheme.ink)
                .textSelection(.enabled)
        }
    }

    private var answerField: some View {
        JozuComposerField(
            text: $session.answer,
            placeholder: "Your answer…",
            isEditable: session.phase == .answering
        )
        .focused($answerFocused)
    }

    @ViewBuilder
    private var result: some View {
        if let judgment = session.judgment {
            VStack(alignment: .leading, spacing: 8) {
                Text(judgment.grade.label.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(judgment.grade == .miss || judgment.grade == .partial
                        ? JozuTheme.vermillion
                        : JozuTheme.ink)

                Text(judgment.reason)
                    .font(.system(size: 14))
                    .foregroundStyle(JozuTheme.ink)
                    .textSelection(.enabled)

                if !judgment.nextHint.isEmpty {
                    Text(judgment.nextHint)
                        .font(.system(size: 13))
                        .foregroundStyle(JozuTheme.muted)
                        .textSelection(.enabled)
                }

                if let item = session.current {
                    Text(item.target)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(JozuTheme.ink)
                        .textSelection(.enabled)
                    if !item.note.isEmpty {
                        Text(item.note)
                            .font(.system(size: 12))
                            .foregroundStyle(JozuTheme.muted)
                            .textSelection(.enabled)
                    }
                }

                if let days = session.intervalDays {
                    Text(days == 1 ? "Again tomorrow." : "Again in \(days) days.")
                        .font(.system(size: 12))
                        .foregroundStyle(JozuTheme.muted)
                }
            }
        }
    }

    private func status(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(JozuTheme.muted)
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 16) {
            switch session.phase {
            case .writingQuestion, .grading:
                EmptyView()
            case .answering:
                if session.question.isEmpty {
                    Button("Retry") {
                        Task { await session.retry() }
                    }
                    Button("Skip") {
                        Task { await session.skip() }
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button("Skip") {
                        Task { await session.skip() }
                    }
                    .buttonStyle(.borderless)
                    Button("Check") {
                        Task { await session.submit() }
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!session.canSubmit)
                }
            case .result:
                if session.hasMore {
                    Button("Next") {
                        Task { await session.advance() }
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                } else {
                    Button("Done") { onClose() }
                    .keyboardShortcut(.return, modifiers: .command)
                }
            case .done:
                Button("Done") { onClose() }
            }
            Spacer()
        }
    }
}
