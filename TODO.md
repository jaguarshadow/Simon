# Simon — Polish & Production Value Expansion: TODO

Tracks implementation of `GAME_DESIGN.md` against the frozen core in `GAME_OVERVIEW.md`.
Phases 1–3 (UX/flow, Visual, Audio) and cross-cutting Accessibility are complete.

## Remaining work

- [x] Visual QA pass: confirm new themes/shimmer don't reduce note-label contrast/legibility —
      found a real problem: fixed white note-label text scored well under WCAG AA contrast
      (often ~1.5-2.5:1, some as low as 1.2:1) against most of the new mid-tone pad palettes
      (Warm & Tactile, Playful & Colorful, Zen Garden, Raw Steel, and most of Monochrome Noir's
      steps), worse once `lightened()` brightens them on a hit. Fixed by picking black-or-white
      label text per pad from whichever contrasts better against both its resting and lit color
      (`_apply_label_contrast` in `Main.gd`), with a matching shadow color.
- [x] Tune exact shimmer shader parameters (color/speed/intensity) — dialed back both the idle
      band peak (0.16→0.12, sharper falloff) and the press sparkle peak (0.3→0.22) so it reads
      as "quietly alive" texture rather than washing out saturated/bright palettes or competing
      with the existing base/lit glow feedback. This is a by-eye task though - flag anything that
      still looks off (too flat, too busy, wrong on a specific palette) once you've seen it live.
- [x] Make pad tone synthesis (`_generate_harmonic` in `sound.gd`) sound closer to a real struck
      steel tongue: added a small stretched-partial inharmonicity term (n → n·√(1+B·n²), B=0.0004
      — subtle, since too much reads as gong/dissonant) and a ~15ms filtered-noise burst under the
      attack for the mallet-strike transient. Applies to both `play_tone` and `play_fail` (both
      route through `_generate_harmonic`); left `play_ui_tick` untouched since it's deliberately a
      softer, simpler click, not a full "struck" sound. Ear-tuning task - flag if the transient
      reads as too clicky/noisy or the detune reads as out-of-tune once you've heard it live.
- [x] Write onboarding walkthrough copy/callout text — `ONBOARDING_STEPS` in `Main.gd` already had
      real (non-placeholder) copy for the 4 steps `GAME_DESIGN.md` §3.1 specifies, wired into
      `_refresh_onboarding_step()`/the `OnboardingPanel` scene nodes; no new UI or logic needed.
      The one real gap: step 3 ("Three Modes") only mentioned Normal/Chaos/Zen, predating Music
      Mode and Duet Mode (both added later per this file's own completed items above). Rewrote
      that step's title/body ("Pick Your Mode") to briefly cover all 5 entry points in one short
      sentence each, keeping the "short callout, not a wall of text" constraint - still skippable,
      still ~20s total. Deliberately did not add a 5th step or otherwise expand scope: unlocks/
      progression stay excluded per §3.1, and the existing "?" replay button/first-launch trigger/
      `onboarding_seen` persistence were already fully wired, so nothing else needed touching.
- [x] Decide Theme save-schema details (likely mirrors Palette: unlocked-set + selected-id) —
      inspected `_is_unlocked`/`_meets_requirement`/`_load_progress`/`_save_progress` in `Main.gd`
      first: turns out **neither** Scale, Palette, nor Theme stores an actual "unlocked set" in
      `user://simon_save.json` - unlock state is derived fresh every load from `best_round`/
      `best_score`/`best_combo` via `_is_unlocked()`, for all three tracks identically. So the real
      schema decision was narrower than the open item implied: only the *selected* index needs
      persisting, and Palette wasn't actually persisting even that (`current_palette_index` reset
      to 0 every session before this change - a pre-existing gap, not something introduced here).
      Implemented selected-id persistence for both, so Theme genuinely mirrors Palette instead of
      mirroring a description of Palette that didn't match the code: `current_palette_index` and
      `current_theme_index` are now written in `_save_progress()` and restored in `_load_progress()`,
      with bounds/unlock validation on load (falls back to index 0 if the saved index is
      out-of-range or no longer unlocked, e.g. after a differently-progressed save or a shortened
      array) so a stale/corrupt save can never select a locked or nonexistent entry. Also added the
      missing `_save_progress()` calls in `_on_palette_button_pressed`/`_on_theme_button_pressed`
      (picking either previously never persisted at all). Follow-up flag: `current_scale_index` has
      the identical pre-existing gap (not persisted) and was left alone as out of scope for this
      item, which was specifically about Theme/Palette parity - worth a matching fix later for
      full consistency across all three tracks.
- [x] Reorder each scale's pad placement around the ring by harmonic adjacency (fifths-style)
      instead of raw scale/pitch order. Computed exactly (not by hand): scored every pair of scale
      degrees by semitone-interval dissonance (octave/unison lowest, tritone highest) and brute-
      forced the ring permutation minimizing total adjacent-pair dissonance for each scale (8
      degrees → 360 distinct cycles, trivial to search exactly). Stored per-scale as `ring_order`
      in `SCALES` (`Main.gd`) and applied in `_apply_scale_and_palette()`, which now assigns
      `tones[ring_order[i]]`/`notes[ring_order[i]]` to ring position i instead of `tones[i]`
      directly. Sequence generation/matching still only cares about pad identity, not pitch, so
      Normal/Chaos Mode are unaffected as expected - only which note sits next to which physically
      changed, relevant for Zen Mode's free play.
- [x] New: "Music Mode" — auto-plays a generated, pleasant-sounding sequence (idle/demo-style,
      pads light up on their own). Scoped as a deliberate exception to `GAME_DESIGN.md`'s "no new
      game modes" boundary (that boundary was written for the polish pass, before this was scoped
      separately). Implemented as a fourth mode alongside Normal/Chaos/Zen: a Euclidean-rhythm
      generator (Bjorklund's algorithm, 16-step bar, 5-9 pulses re-rolled per bar) drives note
      timing, and a biased random walk over scale degrees drives melody, forced back to the tonic
      every 4 bars. Non-pentatonic scales (D Minor Diatonic, C Major Diatonic, Chromatic Run) get
      a smaller max leap since they lack the pentatonic dissonance guarantee. First pass sounded
      washed-out rather than musical - fixed by (1) shortening the note decay envelope so notes at
      Music Mode's ~150ms spacing don't all ring together, (2) replacing an arbitrary
      "reverse-after-2-steps" direction rule with the documented step-inertia/post-skip-reversal
      tendencies from melodic-cognition research (Huron; Narmour's implication-realization model),
      and (3) accenting each bar's downbeat. Full writeup with sources: `docs/music-mode.md`.
- [x] New: "Duet Mode" — game plays a phrase, player answers by repeating it. Scoped away from the
      original "variation, no wrong notes" pitch after discussion - exact note match is required
      (wrong pad/missed note behaves like a Normal Mode miss, Safety Net forgivable), and timing
      accuracy on top of that scales score (tight/good/late tiers) rather than being the only
      thing scored. Call phrase reuses Music Mode's Euclidean-rhythm + melody-walk generators, one
      fresh bar per round (not cumulative like Normal/Chaos). Notes-per-phrase and tempo both ramp
      with round count on a Chaos-style capped curve. Full writeup: `docs/game-modes.md`.
- [ ] Future: multi-click/multi-touch chord support in Zen Mode (and Duet Mode, once it exists) —
      lets players strike more than one pad at once, showcasing the "no wrong notes" pentatonic
      property harder than single-note play. Depends on input-handling work; not yet scoped.
- [ ] Future: recording/export in Zen Mode — let players capture a noodling session and play it
      back (in-session playback at minimum; file export is a stretch goal). Reuses existing
      sequence-storage/playback plumbing from the core game loop.
- [ ] Future: sequence-progress "lights" in the UI — a row of small indicator lights (count =
      current sequence length) somewhere near the pad ring, not under one specific pad since
      sequence length can climb past 20+ rounds in Normal Mode. Unlit = not yet reached, green =
      correct hit so far; needs a decision on the miss state too (likely a soft amber flash rather
      than red, to match the existing "deliberately mellow" miss treatment — soft shake + amber
      screen flash, not a harsh fail sting — see `GAME_OVERVIEW.md`), and on layout for long
      sequences (wrap or shrink dot size past some length rather than an ever-widening single row).
      Applies to Normal/Chaos (cumulative sequence) and Duet Mode (per-round phrase) alike. Also
      worth coordinating with the musical-chunking TODO below — if that ships, repeated-motif
      highlighting could reuse the same visual real estate instead of adding a second indicator.
- [ ] Future: bring real steel-tongue-drum/handpan playing idioms into the Music Mode generators —
      current rhythm/melody generators (Euclidean rhythm + biased random walk) are general-purpose
      generative-music techniques, not specific to this instrument. Researched idioms from actual
      playing technique (anchor-note/drone return between melodic notes, zigzag alternating-side
      contour across the ring, glissando sweeps, ghost notes, groove repetition instead of
      re-rolling every bar, canonical riff shapes) — full writeup with sources in
      `docs/music-mode.md#future-idioms-borrowed-from-how-the-real-instrument-is-played`. Anchor-
      note return and zigzag contour flagged there as the most idiomatic-and-cheap starting point
      given the existing `ring_order`/tonic-return machinery.

## Scoring escalation (Balatro-style "big numbers" within a memory game's limits)

Core problem: sequence length has a hard ceiling (human working memory), so score can't scale
indefinitely just from longer sequences the way it does in genres without that constraint. Lesson
from Balatro: decouple score growth from the thing with the hard ceiling — let a persistent
scoring layer compound across resets instead. Scoped via design discussion 2026-08-15; needed
a full design doc before implementation, mirroring the treatment `docs/music-mode.md` and
`docs/game-modes.md` got — written as **`docs/scoring-escalation.md`**, then substantially revised
during implementation itself based on hands-on playtest feedback (see the first bullet below). The
remaining three bullets build on the mechanic as it actually shipped, not the doc's original shape.

- [x] "Wave" reset, shipped as a fully player-triggered cash-out — went through three rounds of
      feedback during implementation, each changing the design from what the doc originally
      specified. **Round 1:** the original hybrid model (sequence grows toward a cap, forced reset
      at the cap, voluntary cash-out only as an early-exit alternative) was built and briefly
      tuned (`WAVE_CAP_START` dropped 8→5 in response to "hard to test the cap because I keep
      failing before it resets"). **Round 2:** the forced-reset-at-cap itself was rejected outright
      — "the cap thing feels weird... it should be up to the player when to trigger the reset."
      The cap concept was removed entirely: sequence length (Normal/Chaos) and Duet's phrase ramp
      now grow without limit, and a standing **Cash Out** button (new UI, always visible/enabled
      during a run on the player's turn) is the only way a streak ever resets. No forced-swap/debuff
      mechanic was added to compensate — the doc's original tone-based rejection of that idea holds
      even more strongly with no forced-reset moment left to pair it with. **Round 3:** "my score is
      going up before I've cashed out... it's supposed to be a kaching" led to a genuine two-pool
      scoring model — per-hit points now accumulate into an `unbanked_points` pool, and `score`
      (the real, permanent total, and what Best Score tracking reads) only increases on cash-out.
      This made misses matter again in a new way, which surfaced a fourth piece of feedback:
      "protection from misses should also provide protection for points, otherwise what's the
      point" — so a forgiven miss (Safety Net) now leaves the unbanked pool fully untouched, not
      just the run continuing; only a true run-ending miss forfeits it. Cash-out bonus is
      `k × streak_length² × combo_multiplier` (`CASHOUT_QUADRATIC_K = 2.0`, placeholder), banked on
      top of the unbanked pool. Full account, including why no artificial "run goes on forever" fix
      turned out to be needed once the incentive structure was in place: `docs/scoring-escalation.md`
      (rewritten to match) — the original forced-cap design is preserved there under "Rejected: the
      forced wave-cap design" since `docs/modifier-expansion.md` still designs a couple of
      not-yet-built modifiers against it (flagged there, not fixed, since they're unimplemented).
- [ ] Modifier slot system, Hades-style: modifiers are grouped into categories, one equipped
      modifier per category at a time (not unlimited stacking, not a flat N-of-many cap) — forces
      real tradeoffs at every pick and gives builds legible identity. Four categories, mapped onto
      the 5 existing modifiers:
        - **Multiplier** — Sharper Ear, Resonance (shared slot for now; split into two categories
          later if this gets crowded)
        - **Defense** — Safety Net (currently the only member — needs 1-2 new sibling modifiers
          before this category has a real choice in it, flag as open item)
        - **Tempo** — Steady Hands
        - **Bonus-Event** — Golden Step
      Categorizing by *effect type* (not risk/reward stance) was the deliberate choice — players
      need to read "I have a Defense slot open" at a glance during the paused, still-tense
      every-3rd-round pick moment, which an abstract risk-posture label doesn't support as well.
- [ ] Modifier roster expansion + synergies: grow from 5 to 24 modifiers (6 per category,
      including 1 milestone-gated "power" modifier per category), so cross-category builds
      (one modifier per category) create combinatorial synergy instead of same-category additive
      stacking. Full roster, per-modifier rationale, milestone unlock table, and 4 example builds
      ("Marathon Runner", "Precision Virtuoso", "Chunk Master", "All-In Gambler") written up in
      `docs/modifier-expansion.md`, including the opinion on why 24 (not Balatro's ~150) is the
      right v1 pool size for a shorter-run, calmer-toned game. Most of the roster is unaffected by
      the wave-reset bullet's cap removal above, but **Fortissimo and Grand Finale (the Multiplier
      and Bonus-Event power modifiers) and Second Wind (Defense) are flagged stale** in that doc —
      all three were specified against the rejected forced-cap mechanic and need a redesign pass
      before implementation, not a direct port.
- [ ] Musical chunking in sequence generation: build longer sequences out of reused, recognizable
      motifs/riffs (reuses Music Mode's generators — phrase repetition, resolving to tonic) instead
      of pure random note strings, so players can track longer sequences than raw digit-span would
      allow by recognizing structure. Surfaced to the player via a **very subtle** visual cue when
      a phrase repeats — subtlety is a deliberate constraint, not a placeholder; this should read
      as an ear/pattern-recognition aid, not an explicit "here's the repeated bit" callout.
