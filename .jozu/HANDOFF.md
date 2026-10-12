# Handoff

Read this first in a new conversation. Then `STATUS.md`.

Updated: 2026-10-12
Branch: `cursor/review-kit-f89a`
Slice: Review kit (production probes)

## Now

Review writes a 3-probe kit in one LLM call (patterns from lesson kind + focus/contrasts/pitfalls). One at a time. Grade each. Guide hidden until the last probe. Interval from the worst grade. Skip leaves the lesson due.

S8 first slice is on `main`. Chat | Lessons are full screens. Remember distills a stretch of chat into a structured lesson (word sense / grammar / nuance). Several candidates → picker. Search the library. No API key / 401 blocks LLM and points at Settings. No stub tutor.

Discuss + merge (S8b) is not in this slice.

Pull this branch, ⌘R (ad-hoc Sign to Run Locally), add a key, Review a lesson: three distinct questions, guide after the third, interval from the weakest answer.

This Linux agent cannot compile or launch the app.

## Next (do in this order)

1. Confirm S8 + this review kit on a Mac.
2. S8b — Discuss this lesson + merge update.
3. S7 Mac-only scoped peek.

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

## Blocked on the user

- LLM provider + API key (required).
- Confirmation of native / target language defaults (currently English → Japanese).
- What “Jev” meant for scoring.
