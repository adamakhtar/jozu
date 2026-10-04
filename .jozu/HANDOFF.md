# Handoff

Read this first in a new conversation. Then `STATUS.md`.

Updated: 2026-10-04
Branch: `cursor/mac-chat-foundation-1eb4`
Slice: 1/2 — persist thread + stream replies

## Now

S0 window is up on the user's Mac. This slice persists the single thread with SwiftData and streams stub/live tokens into the assistant bubble.

Pull, ⌘R, send a stub message, quit, reopen — the thread should still be there. **Clear** wipes it. Settings → API key for a live streamed tutor.

This Linux agent cannot compile or launch the app.

## Next (do in this order)

1. Confirm persist + stream on a Mac (stub is enough; live key optional).
2. Photo attach + Vision OCR.
3. “Remember this” → review items (no SRS yet).
4. Review list, then LLM probe + grade + reschedule.
5. Mac-only scoped peek at another app (AX selected text first, never full desktop).

## Do not

- Introduce React, Electron, or a JS webview shell.
- Add accounts, sync, or a server until local-first chat + memory work.
- Implement full SRS / SuperMemo.
- Capture the whole screen by default.
- Treat BLEU / exact-match as the grader for open-ended production.
- Add multiple conversations until one thread feels solid.

## Blocked on the user

- LLM provider + API key when they want live answers.
- Confirmation of native / target language defaults (currently English → Japanese).
- What “Jev” meant for scoring.
