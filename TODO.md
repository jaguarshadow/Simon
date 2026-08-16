# Simon — Polish & Production Value Expansion: TODO

Tracks implementation of `GAME_DESIGN.md` against the frozen core in `GAME_OVERVIEW.md`.
Phases 1–3 (UX/flow, Visual, Audio) and cross-cutting Accessibility are complete. Everything
completed to date (Music Mode, Duet Mode, the modifier system and its 24-entry roster, the
cash-out/hearts economy as it currently ships) has been trimmed from this file — it's fully
documented in `docs/` (see `docs/README.md`'s index) rather than duplicated here as a changelog.

The **Cash-out economy v2 / big-numbers** section below is a second deliberate exception to
`GAME_DESIGN.md`'s "no new scoring" boundary, the same way Music Mode and Duet Mode were — scoped
via a 2026-08-16 design session, not yet implemented.

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

## Cash-out economy v2 / big numbers (2026-08-16 design session)

Two threads that turned out to be the same problem: (1) even after hearts/the piecewise cash-out
formula/the inflected Chaos ramp, there's still a gap between "why stop right now" (rare, hearts
absorb most failure) and "why stop eventually" (true but not felt), and (2) scores never get
Balatro-big because scoring is deliberately additive (`combo_growth` is explicitly linear "so
scores don't blow past unlock thresholds") and the one-modifier-per-category slot system caps how
many multiplicative sources can ever stack at once. `docs/round-goals-and-big-numbers.md` exists
but **is stale** — written before the resolution below and needs a full rewrite to match it before
implementation starts.

**Resolved by design discussion** (research and reasoning fully captured in this session's
transcript; doc rewrite should preserve the "why," not just the final numbers):

- **Keep Cash Out voluntary.** A fully-automatic "bank on every complete sequence" (Balatro/Luck Be
  a Landlord-style ante loop) was explored in real depth and rejected — it deletes the "continue or
  stop" decision entirely rather than answering it, which is the one thing this mechanic exists for.
- **Per-round payout compounds multiplicatively, not additively/quadratically.** Two rates: gentle
  below the player's ceiling (calm territory), steep at/past it — so clearing "one more round" is a
  felt percentage jump each time, not a smooth curve. Grounded in Balatro's actual scoring math
  (`Chips × Mult`; two ×3 sources compound to ×9, not ×6 — multiplicative stacking is why Balatro
  runs reach billions and this game's scores sit in the low thousands by design).
- **A permanent, run-wide multiplier grows on every cash-out — but only from the portion of a
  streak past the ceiling.** Cashing out below the ceiling still always banks real points (no
  floor/gate), but contributes nothing to the permanent multiplier. This closes a real exploit we
  found: without this restriction, a player could spam trivial 1-note cash-outs (essentially
  risk-free) and compound a tiny per-cash-out bump into something enormous for free. Reuses the same
  `beyond = max(0, s - ceiling)` term the per-round formula already needs, read a second time.
- **The ceiling should be personal, not the fixed research constant.** `best_streak_this_run` (the
  same "beat your own record" condition Fortissimo and the redesigned Safety Net already use) self-
  scales the "real risk" bar to the actual player instead of a population-average number, and closes
  the farming exploit even harder — the bar only ever rises, never something a player can keep low
  to make grinding easy. Must read the value *before* the current round updates it (same ordering
  Fortissimo already relies on) or "beyond" collapses to zero the instant a new record is set.
- **Grand Finale keeps its current identity** (wager the accumulated pool) — this was only going to
  need a rescope under the fully-automatic ante version, which got rejected.

**Still genuinely open, needs a decision before implementation:**

- **The bootstrap ceiling.** A run's very first streak has no recorded `best_streak_this_run` (starts
  at 0) — literally every round of it would sit in the "steep" zone with no calm ramp at all. Two
  live options: accept that (first streak = uncharted territory, thematically defensible), or give
  it a small default floor (e.g. `max(best_streak_this_run, 3)`).
- **Miss-recovery scope**, raised in the same conversation and not yet resolved either way: right
  now a forgiven miss hints only the one missed note, then expects the rest of the sequence to be
  recalled with no re-exposure — research on interference suggests the interruption itself makes
  recalling *everything after* the miss genuinely harder, independent of whether those notes were
  actually known. Leading option discussed: replay from the missed note through the end of the
  sequence (not the whole thing from note 1) — fixes "lost my place after the interruption" without
  erasing the memory challenge already cleared, or making Quick Rewind's full-replay identity
  redundant. Not decided; needs to be revisited on its own once the economy work above settles.
- **Unlock ladder rebalance.** Best Score thresholds (500/1500/3000) were sized for the current
  ceiling and become trivial almost immediately once real compounding ships — needs its own numbers
  pass once the scoring shape is final, explicitly deferred until then, not before.

**Held for a later modifier pass, not part of the economy work above** (from the same session's
modifier audit, `docs/modifier-audit.md` Pass 4): **Echo of the Ring** (pans pad tones in stereo to
match ring position — dual-coding-grounded, but silent on mono audio, a real perceptibility risk)
and **Contour** (pitch-height-as-glow-intensity — unresolved overlap with Resonant Tones' "pitch
significance" territory, worth revisiting once Resonant Tones has real playtime behind it).
