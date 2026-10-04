# Handoff

Read this first in a new conversation. Then `STATUS.md`.

Updated: 2026-10-04
Branch: `cursor/mac-chat-foundation-1eb4`
Slice: 0 — Mac chat window

## Now

Slice 0 is in the repo: a sandboxed macOS SwiftUI app with a chat thread, reply-language toggle, Settings (languages + OpenAI-compatible key), and a stub LLM when no key is set.

Open `Jozu.xcodeproj` on a Mac and run the **Jozu** scheme. That is the feedback loop. This Linux agent cannot compile or launch the app.

## Next (do in this order)

1. Confirm the window builds and the stub chat works on a Mac.
2. Wire a real API key and send one live tutor turn.
3. Persist transcripts locally (SwiftData).
4. Photo attach + Vision OCR.
5. “Remember this” → review items (no SRS yet).
6. Review session: LLM writes a probe, grades the answer, reschedules.
7. Mac-only scoped peek at another app (AX selected text first, never full desktop).

## Do not

- Introduce React, Electron, or a JS webview shell.
- Add accounts, sync, or a server until local-first chat + memory work.
- Implement full SRS / SuperMemo.
- Capture the whole screen by default.
- Treat BLEU / exact-match as the grader for open-ended production.

## Blocked on the user

- A Mac (or a Cursor self-hosted Mac worker) to run the app.
- LLM provider + API key when they want live answers.
- Confirmation of native / target language defaults (currently English → Japanese).
- What “Jev” meant for scoring.
