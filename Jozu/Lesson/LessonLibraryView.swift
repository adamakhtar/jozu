import SwiftUI

struct LessonLibraryView: View {
    @Bindable var session: ChatSession
    @Binding var selectedLessonID: UUID?
    @State private var query = ""
    @State private var review: ReviewSession?
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HSplitView {
            list
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            detail
                .frame(minWidth: 400)
        }
        .background(JozuTheme.paper)
        .onChange(of: selectedLessonID) {
            review = nil
        }
    }

    private var filtered: [Lesson] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let items = session.lessons
        if q.isEmpty { return items }
        return items.filter { $0.searchText.contains(q) }
    }

    private var list: some View {
        VStack(spacing: 0) {
            HStack {
                TextField(
                    "Search lessons",
                    text: $query
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(8)
                .background(JozuTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(JozuTheme.line, lineWidth: 1)
                )

                if session.dueCount > 0 {
                    Button("Review") {
                        startReview(itemID: nil)
                    }
                    .help("Review due lessons")
                }
            }
            .padding(12)

            Divider().overlay(JozuTheme.line)

            if filtered.isEmpty {
                Text(session.lessons.isEmpty
                     ? "Nothing saved yet. Ask something, then Remember."
                     : "No lessons match that search.")
                    .font(.system(size: 13))
                    .foregroundStyle(JozuTheme.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List(selection: $selectedLessonID) {
                    let due = filtered.filter(\.isDue)
                    let later = filtered.filter { !$0.isDue }
                    if !due.isEmpty {
                        Section("Due") {
                            ForEach(due) { row($0) }
                        }
                    }
                    if !later.isEmpty {
                        Section("Later") {
                            ForEach(later) { row($0) }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(JozuTheme.paper)
    }

    private func row(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(lesson.kind.label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(JozuTheme.vermillion)
                Text(lesson.scheduleCaption)
                    .font(.system(size: 10))
                    .foregroundStyle(JozuTheme.muted)
            }
            Text(lesson.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(JozuTheme.ink)
            if !lesson.subtitle.isEmpty {
                Text(lesson.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.muted)
                    .lineLimit(2)
            }
        }
        .tag(lesson.id as UUID?)
        .padding(.vertical, 4)
        .contextMenu {
            Button("Review") { startReview(itemID: lesson.id) }
            Button("Delete", role: .destructive) {
                session.deleteLesson(lesson.id)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let review {
            ReviewView(session: review) {
                self.review = nil
                session.refreshLessons()
            }
        } else if let id = selectedLessonID, let lesson = session.lessons.first(where: { $0.id == id }) {
            LessonDetailView(lesson: lesson) {
                startReview(itemID: lesson.id)
            } onDelete: {
                session.deleteLesson(lesson.id)
            }
        } else {
            Text("Select a lesson, or Remember one from chat.")
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(JozuTheme.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func startReview(itemID: UUID?) {
        do {
            try settings.requireKey()
        } catch {
            session.errorMessage = error.localizedDescription
            session.needsSettings = true
            return
        }
        guard let next = session.makeReviewSession(startingAt: itemID) else { return }
        review = next
        Task { await next.begin() }
    }
}

struct LessonDetailView: View {
    let lesson: Lesson
    var onReview: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(lesson.kind.label.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(JozuTheme.vermillion)
                    Spacer()
                    Button("Review") { onReview() }
                    Button("Delete", role: .destructive) { onDelete() }
                        .buttonStyle(.borderless)
                }

                Text(lesson.title)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(JozuTheme.ink)
                    .textSelection(.enabled)

                if !lesson.sense.isEmpty {
                    Text(lesson.sense)
                        .font(.system(size: 16))
                        .foregroundStyle(JozuTheme.ink)
                        .textSelection(.enabled)
                }

                if !lesson.focus.isEmpty {
                    labeled("Focus", lesson.focus)
                }

                if !lesson.context.isEmpty {
                    labeled("In context", lesson.context)
                }

                if !lesson.examples.isEmpty {
                    Text("Examples")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(JozuTheme.muted)
                    ForEach(Array(lesson.examples.enumerated()), id: \.offset) { _, example in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(example.sentence)
                                .font(.system(size: 15))
                                .foregroundStyle(JozuTheme.ink)
                                .textSelection(.enabled)
                            if !example.gloss.isEmpty {
                                Text(example.gloss)
                                    .font(.system(size: 13))
                                    .foregroundStyle(JozuTheme.muted)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                if !lesson.contrasts.isEmpty {
                    Text("Contrasts")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(JozuTheme.muted)
                    ForEach(Array(lesson.contrasts.enumerated()), id: \.offset) { _, contrast in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contrast.item)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(JozuTheme.ink)
                                .textSelection(.enabled)
                            Text(contrast.difference)
                                .font(.system(size: 13))
                                .foregroundStyle(JozuTheme.muted)
                                .textSelection(.enabled)
                        }
                    }
                }

                if !lesson.pitfalls.isEmpty {
                    Text("Pitfalls")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(JozuTheme.muted)
                    ForEach(Array(lesson.pitfalls.enumerated()), id: \.offset) { _, pitfall in
                        Text(pitfall)
                            .font(.system(size: 14))
                            .foregroundStyle(JozuTheme.ink)
                            .textSelection(.enabled)
                    }
                }

                Text(lesson.scheduleCaption)
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.muted)
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(JozuTheme.paper)
    }

    private func labeled(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(JozuTheme.muted)
            Text(body)
                .font(.system(size: 15))
                .foregroundStyle(JozuTheme.ink)
                .textSelection(.enabled)
        }
    }
}
