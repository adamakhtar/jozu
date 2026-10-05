# Gaps

Questions that are open. Defaults in `STATUS.md` are in force until answered.

## Product

1. **Languages** — Confirm native / target defaults (English / Japanese). First language pair is enough; the model is not hardcoded to JP.
2. **“Jev”** — Unclear. Proceeding with LLM-as-judge. If this was BLEU, Jaccard, or a specific eval product, say so.
3. **Provider** — OpenAI-compatible is wired. Which host and model will you actually use?
4. **Review cadence numbers** — miss → 1 day, partial → 2, pass → 7, easy → 14. Open if you want different numbers.
5. **Lesson body schema** — Headword/pattern, sense, focus (struggle), examples, contrasts, pitfalls. Exact JSON fields still open at implement time.
6. **Peek UX** — Locked 2026-10-05: on-demand + session allowlist + confirm. See `DECISIONS.md`.
7. **Data** — Local-only forever, or iCloud later?
8. **Name / tone** — Jozu (上手) from the repo. Keep?

## Technical (not blocking S0)

- No Mac in this environment, so S0 is unverified.
- Sandbox + Accessibility + ScreenCaptureKit entitlements will need a real usage-description story and possibly notarization later.
- Multilingual OCR: Vision is strong for CJK / Latin; some scripts need language hints (`recognitionLanguages`).
- Grading: ask the model for JSON `{grade, reason, next_hint}` and parse it. Don’t regex the prose.
- Peek security: preview the exact selection, confirm, log app + text on the turn. Session allowlist. No full-desktop capture.

## Non-gaps (decided)

See `DECISIONS.md`. Native Swift, protocol LLM, Vision OCR, drip review, scoped Mac peek (AX selected text, session allowlist, confirm), `.jozu/` handoff, S8 Lessons (picker, one lesson per sense, review that sense + struggle, chat-only updates, key gate).
