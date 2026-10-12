import SwiftUI

struct ReviewView: View {
    @Bindable var session: ReviewSession
    var onClose: () -> Void
    @FocusState private var answerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Review · \(session.progressCaption)")
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.muted)
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(.borderless)
            }

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
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(JozuTheme.paper)
        .preferredColorScheme(.light)
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

                if let lesson = session.current {
                    Text(lesson.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(JozuTheme.ink)
                        .textSelection(.enabled)
                    if !lesson.sense.isEmpty {
                        Text(lesson.sense)
                            .font(.system(size: 13))
                            .foregroundStyle(JozuTheme.ink)
                            .textSelection(.enabled)
                    }
                    if !lesson.focus.isEmpty {
                        Text(lesson.focus)
                            .font(.system(size: 13))
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
