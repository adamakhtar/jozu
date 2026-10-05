# Handoff

Read this first in a new conversation. Then `STATUS.md`.

Updated: 2026-10-05
Branch: `cursor/s7-mac-peek-81b3`
Slice: 7 — Mac scoped peek

## Now

S7 is on this branch, stacked on S8b (`cursor/s8b-discuss-merge-81b3` / PR #5).

Peek reads **selected text** from an app on this session’s allowlist via Accessibility. Preview and confirm before it attaches to the turn. Never the whole screen. Allowlist dies on quit. iPhone: photo / share only (no peek UI).

Pull this branch, ⌘R. System Settings → Privacy & Security → Accessibility → Jozu (ad-hoc rebuilds may need a re-add). Select a sentence in Pages/Word/etc., Peek → Allow and read → confirm → send.

This Linux agent cannot compile or launch the app.

## Next (do in this order)

1. Confirm S8 + S8b + S7 on a Mac.
2. Later items only (Word→senses, iPhone, sync, speech). Window screenshot via ScreenCaptureKit is not this slice.

## Do not

- Introduce React, Electron, or a JS webview shell.
- Add accounts, sync, or a server until local-first chat + memory work.
- Implement full SRS / SuperMemo.
- Capture the whole screen by default.
- Treat BLEU / exact-match as the grader for open-ended production.
- Add a parent Word→senses object yet (Later).
- Inline-edit lesson body in v1.
- Distill the entire mixed inbox into one lesson; picker if several topics.
- Send the photo bytes to the model unless a later decision says multimodal is needed.
- Merge discuss turns into the inbox thread.
- Background-read other apps. Peek is on-demand, allowlisted, confirmed.

## Blocked on the user

- LLM provider + API key (required).
- Accessibility grant on the Mac (required for Peek).
- Confirmation of native / target language defaults (currently English → Japanese).
- What “Jev” meant for scoring.
