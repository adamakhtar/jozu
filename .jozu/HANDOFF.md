# Handoff

Read this first in a new conversation. Then `STATUS.md`.

Updated: 2026-10-05
Branch: `cursor/s8b-discuss-merge-81b3`
Slice: 8b — Discuss + merge

## Now

S8b is on this branch, stacked on S8 (`cursor/s8-lessons-7cbf` / PR #4).

Discuss is a lesson-scoped thread (not the inbox). Follow-ups land in Chat with the current guide in context. **Update lesson** rewrites that guide from the talk. Schedule (`nextReviewAt`, interval) is unchanged. No inline edit.

Pull this branch, ⌘R, add a key. Open a lesson → Discuss → ask a follow-up → Update lesson. You should land on the revised guide. Done returns to the inbox; the discussion stays on the lesson.

This Linux agent cannot compile or launch the app.

## Next (do in this order)

1. Confirm S8 + S8b on a Mac.
2. S7 Mac-only scoped peek.

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

## Blocked on the user

- LLM provider + API key (required).
- Confirmation of native / target language defaults (currently English → Japanese).
- What “Jev” meant for scoring.
