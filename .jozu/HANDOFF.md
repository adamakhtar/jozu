# Handoff

Read this first in a new conversation. Then `STATUS.md`.

Updated: 2026-10-04
Branch: `cursor/persist-stream-1eb4`
Slice: 3 — photo + Vision OCR

## Now

S3 is on this branch: attach / drop / paste a photo of text. Vision reads it on-device. The reading is editable. Send includes that text (image stays local). Thumbnail is saved with the turn.

Pull `cursor/persist-stream-1eb4`, ⌘R. Attach a screenshot of Japanese (or any) text, optionally edit the OCR, send. Stub is enough.

This Linux agent cannot compile or launch the app.

## Next (do in this order)

1. Confirm photo OCR on a Mac.
2. “Remember this” → review items (no SRS yet).
3. Review list, then LLM probe + grade + reschedule.
4. Mac-only scoped peek at another app (AX selected text first, never full desktop).

## Do not

- Introduce React, Electron, or a JS webview shell.
- Add accounts, sync, or a server until local-first chat + memory work.
- Implement full SRS / SuperMemo.
- Capture the whole screen by default.
- Treat BLEU / exact-match as the grader for open-ended production.
- Add multiple conversations until one thread feels solid.
- Send the photo bytes to the model unless a later decision says multimodal is needed.

## Blocked on the user

- LLM provider + API key when they want live answers.
- Confirmation of native / target language defaults (currently English → Japanese).
- What “Jev” meant for scoring.
