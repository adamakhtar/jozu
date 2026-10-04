# Backlog

Ordered. Only the top item is “now” unless a conversation explicitly pulls something forward.

## Now

- [ ] **S0 verify** — Open `Jozu.xcodeproj` on a Mac, run Jozu, send a stub message, open Settings.

## Up next

- [ ] **S1 live tutor** — Confirm a real key works. Tighten the system prompt. Stream tokens if the first live call feels slow.
- [ ] **S2 persist chats** — SwiftData (or a thin SQLite store) for threads. One thread is fine at first.
- [ ] **S3 photo + OCR** — Attach image → Vision recognize → include text (and optionally the image) in the next turn.
- [ ] **S4 remember** — Chat tool / confirmation that stores a `MemoryItem` (word / sentence / grammar, source turn, notes).
- [ ] **S5 review list** — Browse items. Due drip. Not a grade session yet.
- [ ] **S6 review probe** — LLM writes a question, user answers, LLM grades, interval updates.
- [ ] **S7 Mac peek** — Selected text from a user-chosen app via Accessibility. Explicit allowlist.

## Later

- [ ] iPhone target on the same sources
- [ ] iCloud / sync (only after local-first feels good)
- [ ] Speech in / out
- [ ] Multiple courses / languages at once
- [ ] Extract `JozuCore` Swift package so Linux can test domain logic

## Won't (until a decision says otherwise)

- React / Electron
- Full SRS
- Unscoped screen recording
- Accounts required to chat
