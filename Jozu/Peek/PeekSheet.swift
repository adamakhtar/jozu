import SwiftUI

#if os(macOS)

struct PeekSheet: View {
    @Bindable var session: ChatSession
    @Environment(\.dismiss) private var dismiss
    @State private var apps: [PeekTarget] = []
    @State private var trusted = false
    @State private var preview: PendingPeek?
    @State private var truncated = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Peek selected text")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(JozuTheme.ink)
            Text("Only selected text in apps you allow this session. Never the whole screen. Confirm before anything is sent.")
                .font(.system(size: 13))
                .foregroundStyle(JozuTheme.muted)

            if !trusted {
                permission
            } else if let preview {
                confirm(preview)
            } else {
                picker
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 420)
        .background(JozuTheme.paper)
        .preferredColorScheme(.light)
        .onAppear(perform: refresh)
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("macOS Accessibility is off for Jozu. Nothing is read until you grant it, allow an app, and confirm the text.")
                .font(.system(size: 13))
                .foregroundStyle(JozuTheme.ink)
            HStack {
                Button("Open System Settings") {
                    AXPeek.openAccessibilitySettings()
                    AXPeek.promptForTrust()
                }
                Button("I’ve allowed Jozu") { refresh() }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)
            }
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let last = session.lastOtherApp {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last app")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(JozuTheme.vermillion)
                        Text(last.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(JozuTheme.ink)
                    }
                    Spacer()
                    Button(session.isPeekAllowed(last.bundleID) ? "Read selection" : "Allow and read") {
                        peek(last, allowIfNeeded: true)
                    }
                }
                .padding(10)
                .background(JozuTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(JozuTheme.line, lineWidth: 1)
                )
            }

            Text("Running apps")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(JozuTheme.muted)

            List(apps) { app in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.system(size: 14))
                            .foregroundStyle(JozuTheme.ink)
                        Text(session.isPeekAllowed(app.bundleID) ? "Allowed this session" : app.bundleID)
                            .font(.system(size: 11))
                            .foregroundStyle(JozuTheme.muted)
                    }
                    Spacer()
                    if session.isPeekAllowed(app.bundleID) {
                        Button("Read") { peek(app, allowIfNeeded: false) }
                        Button("Remove") { session.revokePeek(app.bundleID) }
                            .buttonStyle(.borderless)
                    } else {
                        Button("Allow") { session.allowPeek(app.bundleID) }
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.vermillion)
            }

            HStack {
                Button("Refresh") { refresh() }
                    .buttonStyle(.borderless)
                Spacer()
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func confirm(_ peek: PendingPeek) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("From \(peek.appName)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(JozuTheme.muted)
            Text("This is exactly what will be attached to the next turn. Edit if the selection is wrong.")
                .font(.system(size: 13))
                .foregroundStyle(JozuTheme.ink)
            if truncated {
                Text("Selection was truncated to \(AXPeek.maxCharacters) characters.")
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.vermillion)
            }
            JozuComposerField(
                text: previewText,
                placeholder: "Selected text",
                minHeight: 160,
                maxHeight: 240
            )
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(JozuTheme.vermillion)
            }
            HStack {
                Button("Back") {
                    preview = nil
                    truncated = false
                }
                .buttonStyle(.borderless)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)
                Button("Attach") { attach() }
                    .disabled(preview?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true)
            }
        }
    }

    private var previewText: Binding<String> {
        Binding(
            get: { preview?.text ?? "" },
            set: { text in preview?.text = text }
        )
    }

    private func refresh() {
        trusted = AXPeek.isTrusted
        apps = AXPeek.runningApps()
        errorMessage = nil
    }

    private func peek(_ target: PeekTarget, allowIfNeeded: Bool) {
        errorMessage = nil
        if allowIfNeeded {
            session.allowPeek(target.bundleID)
        }
        do {
            let text = try AXPeek.selectedText(in: target, allowlist: session.peekAllowlist)
            truncated = text.count >= AXPeek.maxCharacters
            preview = PendingPeek(appName: target.name, bundleID: target.bundleID, text: text)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func attach() {
        guard var peek = preview else { return }
        peek.text = peek.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !peek.text.isEmpty else {
            errorMessage = "Nothing to attach."
            return
        }
        session.confirmPeek(peek)
        dismiss()
    }
}

#endif
