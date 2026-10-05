# Handoff

Read this first in a new conversation. Then `STATUS.md`.

Updated: 2026-10-05
Branch: `cursor/persist-stream-1eb4`
Slice: 6 — review probe

## Now

S6 is on this branch (PR #2). Due memories open a probe: LLM writes a question, you answer, it grades miss/partial/pass/easy, `nextReviewAt` moves by 1/2/7/14 days. Stub probe/grade if there is no key.

Composer is a taller 16pt field. Return inserts a newline; ⌘↩ sends (chat) or checks (review). The review answer stays visible through grading and the judgment.

Pull `cursor/persist-stream-1eb4`, ⌘R. Remember a turn, open **Review** (or Memories → Review due), answer, confirm it lands under Later.

This Linux agent cannot compile or launch the app.

## Next (do in this order)

1. Confirm Remember + Review on a Mac (stub is enough; live key grades for real).
2. Mac-only scoped peek at another app (AX selected text first, never full desktop).

## Do not

- Introduce React, Electron, or a JS webview shell.
- Add accounts, sync, or a server until local-first chat + memory work.
- Implement full SRS / SuperMemo.
- Capture the whole screen by default.
- Treat BLEU / exact-match as the grader for open-ended production.
- Add multiple conversations until one thread feels solid.
- Send the photo bytes to the model unless a later decision says multimodal is needed.

## Blocked on the user

- LLM provider + API key when they want live answers / better extract / real grades.
- Confirmation of native / target language defaults (currently English → Japanese).
- What “Jev” meant for scoring.
