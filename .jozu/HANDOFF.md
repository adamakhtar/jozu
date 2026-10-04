# Handoff

Read this first in a new conversation. Then `STATUS.md`.

Updated: 2026-10-04
Branch: `cursor/persist-stream-1eb4`
Slice: 4/5 — remember + memories list

## Now

S4/S5 is on this branch. **Remember** on an assistant turn (or type “remember this”) stores a word/sentence/grammar item. **Memories** lists them. Due items sit at the top. No grading yet.

Pull `cursor/persist-stream-1eb4`, ⌘R. Ask something, Remember, open Memories. Stub is enough (heuristic extract). With a key, extract is JSON from the model.

This Linux agent cannot compile or launch the app.

## Next (do in this order)

1. Confirm Remember + Memories on a Mac.
2. Review probe: LLM writes a question, user answers, LLM grades, `nextReviewAt` updates.
3. Mac-only scoped peek at another app (AX selected text first, never full desktop).

## Do not

- Introduce React, Electron, or a JS webview shell.
- Add accounts, sync, or a server until local-first chat + memory work.
- Implement full SRS / SuperMemo.
- Capture the whole screen by default.
- Treat BLEU / exact-match as the grader for open-ended production.
- Add multiple conversations until one thread feels solid.
- Send the photo bytes to the model unless a later decision says multimodal is needed.

## Blocked on the user

- LLM provider + API key when they want live answers / better extract.
- Confirmation of native / target language defaults (currently English → Japanese).
- What “Jev” meant for scoring.
