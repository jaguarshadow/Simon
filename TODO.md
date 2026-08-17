# Simon — Polish & Production Value Expansion: TODO

Tracks implementation of `GAME_DESIGN.md` against the frozen core in `GAME_OVERVIEW.md`.
Phases 1–3 (UX/flow, Visual, Audio) and cross-cutting Accessibility are complete. Everything
completed to date (Music Mode, Duet Mode, the modifier system and its 24-entry roster, the
cash-out/hearts economy including the v2/big-numbers compounding rework — multiplicative per-round
payout, personal-ceiling-gated permanent multiplier, silent-flash miss hints — all shipped
2026-08-16 per `docs/round-goals-and-big-numbers.md`) has been trimmed from this file — it's fully
documented in `docs/` (see `docs/README.md`'s index) rather than duplicated here as a changelog.

## Remaining work

- [ ] Multi-click/multi-touch chord support in Zen Mode (and Duet Mode) — lets players strike more
      than one pad at once, showcasing the "no wrong notes" pentatonic property harder than
      single-note play. Depends on input-handling work; not yet scoped.
- [ ] Recording/export in Zen Mode — let players capture a noodling session and play it back
      (in-session playback at minimum; file export is a stretch goal). Reuses existing
      sequence-storage/playback plumbing from the core game loop.
- [ ] Sequence-progress "lights" in the UI — a row of small indicator lights (count = current
      sequence length) near the pad ring, unlit/green per hit, some softer-than-red state for a
      miss (matching the existing mellow miss treatment). Applies to Normal/Chaos (cumulative) and
      Duet (per-round phrase) alike. Note: **Constellation** (a Phrasing modifier added this
      session) now traces the sequence's shape spatially across the ring — check this doesn't
      duplicate that before building it; the two are visually different (a path vs. a counter) but
      worth a deliberate call, not an accident, if a player could have both on screen together.
- [ ] A very subtle visual cue when a chunk repeats — the underlying signal
      (`sequence_chunk_id`/`_completed_repeated_chunk`) already exists (feeds Harmonic Chain/Motif
      Bonus); this is just the presentation layer, intentionally deferred to keep it genuinely
      subtle rather than rushed.
- [ ] **Unlock ladder rebalance.** Best Score thresholds (500/1500/3000) were sized for the old
      cash-out formula and are expected to trivialize now that the v2 compounding formula has
      shipped (`bb1e245`, see `docs/round-goals-and-big-numbers.md`) — needs its own numbers pass
      once the new curve has real playtime behind it, explicitly deferred until then.

**Held for a later modifier pass** (from the 2026-08-16 session's modifier audit,
`docs/modifier-audit.md` Pass 4): **Echo of the Ring** (pans pad tones in stereo to match ring
position — dual-coding-grounded, but silent on mono audio, a real perceptibility risk) and
**Contour** (pitch-height-as-glow-intensity — unresolved overlap with Resonant Tones' "pitch
significance" territory, worth revisiting once Resonant Tones has real playtime behind it).
