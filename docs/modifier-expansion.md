# Modifier Expansion — Shipped

**Implemented.** Everything below (the four-category slot system, all 24 modifiers, 1→5 leveling)
is live in `Main.gd` as of this pass — see `docs/scoring-and-modifiers.md` for the shipped
mechanics summary and `TODO.md` for the checklist entry. This doc is kept as the design record;
where implementation required a concrete call the design text left open, an **Implementation
note** is added inline at that entry rather than silently changing the text above it.

Original framing, left as-is below since it's still an accurate account of *why* each piece looks
the way it does: design proposal for the modifier roster feeding the "Scoring escalation" work in
`TODO.md`, written against the shipped cash-out economy (`docs/scoring-escalation.md`), adding the
four-category slot system and a **1-5 leveling curve for every modifier** on top of it.

**Revision history:** an earlier pass rejected the wave-cap mechanic this doc was first written
against (sequence length climbing toward a forced-reset cap) in favor of the shipped
player-triggered, no-cap cash-out — see
[scoring-escalation.md](scoring-escalation.md#what-shipped-instead-of-a-forced-cap). That left
three roster entries (Fortissimo, Grand Finale, Second Wind) and one non-power entry (Echo
Chamber) specified against mechanics that no longer exist or are now redundant with shipped
behavior. **This pass resolves all four** with real redesigns (below) rather than leaving them
flagged — see each entry's own note on what changed and why.

**Superseded by [modifier-audit.md](modifier-audit.md):** the charge/"uses" pools and the Peek/
Rewind manual-activation buttons described below for Safety Net, Echo Chamber, Second Wind,
Unbreakable, Quick Rewind, and Grand Finale no longer exist. A later audit concluded no modifier
should track a countable resource or require a mid-flow click (rule 6) — all six are now either
Passive or an automatic Roll/state check; Grand Finale is the one documented exception, keeping its
Gamble button since it's a pause-point choice, not a mid-sequence one. Left as-is below as the
design record for *why* the charge system existed in the first place; `modifier-audit.md` is
authoritative for current mechanics.

**Also superseded:** Metronome and Slow Fade (Tempo, described below) have been retired and
replaced by Constellation and Resonant Tones respectively, and the Tempo category is now labeled
**Phrasing** — see `modifier-audit.md`'s Pass 4 for why and what shipped instead. Left as-is below
for the same reason as above.

## Should cash-out itself pay out more? (No — Crescendo is the answer, not the base formula)

Raised directly: should cashing out preserve some percentage of your combo, as a way to make it
feel more rewarding? Worth stating plainly why the answer is no, not a small tweak: **combo
already persists 100% across a cash-out** — nothing about `combo` or `combo_growth` is touched by
`_on_cash_out_button_pressed()` (`docs/scoring-escalation.md`'s "what persists" table). There's no
gap to refund, because nothing is lost. A "preserve some % of combo on cash-out" modifier would be
solving a problem that doesn't exist in the shipped mechanic.

The real lever for "cash-out should feel more lucrative, especially deep into a run" is
**Crescendo** (below) — a Multiplier-category pick that scales off *waves completed this run*
(voluntary cash-outs), not combo. That's the correct place for "reward committing to the cash-out
loop over many streaks" to live: a modifier choice with real opportunity cost (it competes for the
Multiplier slot against Sharper Ear/Resonance/Perfect Pitch/Harmonic Chain/Fortissimo), not a
buff to the base mechanic every build gets for free.

## Leveling: 1→5, redrafting an equipped modifier commits further instead of swapping

Previously, picking a modifier whose category slot was already filled prompted swap-or-skip
(replace the equipped pick, or decline and keep it). That's refined, not replaced:

- **Picking a *different* modifier into a filled category slot** still prompts swap-or-skip —
  unchanged, this is a real "do I want to try something else" decision.
- **Picking the *same* modifier that's already equipped levels it up instead** (1→2→3→4→5,
  capped at 5 — a sixth pick offers nothing new for that slot, so it simply won't appear in future
  draft pools once maxed). This wasn't a real choice before (today's shipped 5-modifier pool just
  stacks flat effects uncapped); under the slot system it becomes a genuine build decision —
  every level spent on one modifier is a pick *not* spent trying a different category-mate or
  diversifying, since drafts only offer 3 of the remaining pool each time.

**Curve shape:** levels 1-4 are smooth, predictable scaling of the same number (a player can plan
around "I'm 2 levels into Sharper Ear" the same way they'd plan around a flat stack today). **Level
5 is reserved for a real "mastered" payoff on the modifiers that support one** — several entries
below get a qualitative twist at L5, not just a bigger coefficient, so going all-in on one pick
over draft variety is a genuinely exciting, distinct choice rather than just "more of the same
number." Not every modifier gets a twist — most are numeric-only through L5, which is deliberate:
if every single one had a mastery gimmick, none of them would feel special. All numeric curves
below (percentages, charge counts, seconds) are placeholder tuning, same by-eye/balance-pass status
as every other numeric constant in these docs (`CASHOUT_QUADRATIC_K`, the old shimmer-shader
parameters, etc.) — the shape and existence of a level-5 twist is the design decision; the exact
numbers are not.

The existing 5 shipped modifiers (Sharper Ear, Safety Net, Golden Step, Steady Hands, Resonance)
get leveling curves here too, describing the *target* design this proposal is building toward —
they're live today with the simpler flat-stacking model per `docs/scoring-and-modifiers.md`; that
doesn't change until the slot system ships.

## Opinion: how big should the pool be?

**6 per category, 24 total, for v1.** Unchanged from the original reasoning: Balatro's ~150-joker
pool works because runs are long and mastery is a long-tail pursuit; Simon's runs are short and
calm-toned, not a min-max deckbuilder. 24 (6/category, one milestone-gated power pick each) is
enough for drafts to feel different run to run and for a reasonably engaged player to see the
whole pool within a handful of runs, without diluting the "I know what this does and what it
combos with" recognition a good draft pick needs. Leveling adds a second axis of depth (breadth
of picks vs. depth on one) without needing a bigger pool to get there — room to grow the pool
itself later once playtesting shows which categories are under-picked.

## Cross-mode applicability audit

Every modifier's effect needs to be a real, measurable thing in **Normal, Chaos, and Duet Mode**
alike. Zen Mode and Music Mode are structurally exempt across the board (no scoring/fail state,
no player input to modify, respectively) — that's a property of those two modes for *all*
modifiers equally.

- **Perfect Pitch** — reframed from Duet-timing-tier-specific to **rhythmic cadence consistency**
  (variance between the intervals of your own consecutive hits), a real signal in Normal/Chaos with
  no external tiers needed; in Duet it stacks alongside the existing tight/good/late accuracy tiers
  as a second, complementary dimension.
- **Grounding Resonance** — the original "reduces any mode's per-round escalation rate" pitch turned
  out not to hold up under this section's own audit standard: Normal Mode has no ramp at all (not
  just a low-value one), so a full Normal-mode run made this pick a complete no-op, not merely
  "naturally low-value there." **Revision note (later pass, same modifier-audit initiative):**
  redesigned again, this time to something that's identically real in Normal/Chaos/Duet by
  construction — see its roster entry below.
- **Steady Hands** and **Rubato** — audited in a later pass and found to have the mirror-image bug:
  both scale playback pacing in `_play_sequence()` (Normal/Chaos) but were never wired into
  `_play_duet_call()`, so both were dead picks for an entire Duet run despite reading as
  mode-agnostic on paper. **Fixed** — `_play_duet_call()` now scales its own local step duration by
  the same `sequence_speed_multiplier × _rubato_speed_factor()` factors, without touching
  `duet_step_duration` itself (the response phase still grades timing against the original tempo
  grid, so the fix only changes what you *watch*, never what you're graded against).
- **Metronome** was already mode-agnostic mechanically, just under-described as a Duet-flavored
  extra — wording only.
- **Echo Chamber's Peek and Quick Rewind's Rewind** (see their entries below) were both flatly
  excluded from Duet at first ship — Peek's "preview the next note" and the original automatic
  rewind both interact with Duet's live, timed response window in ways that seemed unsafe to just
  turn on. **Fixed properly instead of left excluded**: both abilities now work in Duet by pausing
  the response phase's clock while they play (`_pause_duet_clock_start`/`_pause_duet_clock_end`) —
  the current note's grace deadline and the fixed pulse-timing reference both shift forward by
  exactly how long the ability took, so spending a charge mid-response can't cost a miss or skew the
  timing grade. **Grand Finale** got the same full-Duet treatment: `_handle_duet_miss()` now checks
  a pending gamble before falling into normal defense-mod handling (same bypass Double Down already
  used), and `_run_duet_response()` checks it on a phrase's natural completion. The governing
  principle, stated plainly this pass: **every modifier should work in every scored mode** —
  "naturally low-value in mode X" is an acceptable audit finding, "flatly dead/excluded in mode X"
  is not, and should be fixed or redesigned rather than documented as a known gap.
- **Harmonic Chain** and **Motif Bonus** depend on the (not-yet-implemented) musical-chunking
  generator being shared across Normal/Chaos's sequences *and* Duet's call-phrases, not
  Normal/Chaos-only.
  **Implementation note:** shipped as a lightweight, scoped-down chunking system
  (`_tag_chunk_for_new_note()`/`_completed_repeated_chunk()` in `Main.gd`, `TODO.md`'s musical-
  chunking bullet) - every 3-note (`CHUNK_SIZE`) group has a 35% (`CHUNK_REPEAT_CHANCE`) chance of
  reusing an earlier chunk's id instead of getting a fresh one, applied identically to Normal/
  Chaos's cumulative sequence and Duet's per-round phrase (both call the same tagging function per
  note appended). This is deliberately the minimum needed to give Harmonic Chain/Motif Bonus a
  real "was this note part of a repeated motif" signal, not the fuller "canonical riff library"
  version `TODO.md` originally envisioned for musical chunking generally - the visual repeat cue
  that TODO also asked for is still an open follow-up, now cheap to add since the underlying
  per-note chunk id already exists.

## The restated design invariant (cap is gone; this is what replaced it)

The original "the wave-cap escalation curve is unmodifiable" invariant has no premise anymore —
there's no `cap(n)` in the shipped code to protect. The concern it was guarding is preserved in
`docs/scoring-escalation.md`'s restated version: **no modifier should let a player realize
compounding score gains without ever tapping Cash Out.** Forgiveness protecting the unbanked pool
(Safety Net, below) is a deliberate, named exception to "misses have stakes," not a precedent for
quietly removing the "you must cash out to bank anything" requirement itself. Every modifier below
was checked against this — none of them auto-bank or bypass the Cash Out action, including Grand
Finale's redesigned gamble (still requires an explicit player action to resolve, win or lose).

**Shared definition**, referenced by several entries below: **"complete a streak" / "waves
completed"** means a voluntary cash-out (a Grand Finale win counts too, since it is a player-triggered
streak end). A Second Wind save does **not** count — it is insurance, not a wave. A true run-ending
miss also doesn't count.

## Categories & roster

Each category = one equip slot. A *different* modifier into a filled slot prompts swap-or-skip; the
*same* modifier into its own filled slot levels it up (see "Leveling" above).

### Dynamics

Score-scaling effects. All six compound into cash-outs, not just per-hit score — confirmed in the
shipped formula (`docs/scoring-escalation.md`'s `_cash_out_streak_bonus()`, which already includes
both `combo_growth` and `score_bonus_percent`; a modifier audit this session caught and fixed a gap
where Resonance's bonus wasn't reaching it).

1. **Sharper Ear** *(existing, shipped as flat uncapped stacking today)* — combo multiplier grows
   faster per hit. Leveled target: `combo_growth` bonus of **+0.03 / +0.06 / +0.09 / +0.12 / +0.15**
   at L1-L5 (replacing the shipped flat `+0.05` per pick). No L5 twist — this is the pool's
   "reliable anchor" pick; a new player should be able to read exactly what it does at a glance,
   and a gimmick at L5 would undercut that legibility.
2. **Resonance** *(existing, shipped as flat uncapped stacking today)* — flat score bonus. Leveled
   target: `score_bonus_percent` of **+4% / +8% / +12% / +16% / +20%** at L1-L5 (replacing the
   shipped flat `+10%` per pick). No L5 twist, same reasoning as Sharper Ear.
3. **Crescendo** *(new)* — multiplier bonus scales with **waves completed this run**
   (`waves_completed`), not combo. The direct answer to "should cash-out pay out more" (see above)
   — this is the pick that makes committing to the cash-out loop over many streaks compound.
   Levels set the per-wave bonus: **+5% / +8% / +12% / +18% / +25%** per wave completed, additive
   (e.g. L1 after 4 waves = +20% multiplier). **L5 twist:** the per-wave bonus stops being additive
   and becomes *multiplicative* — `(1.25)^waves_completed` instead of `1 + 0.25×waves_completed` —
   a genuinely different growth shape, not just a bigger number, and the whole point of going all-in
   on this pick: a maxed Crescendo build should feel like it's *snowballing*, not just adding up.
4. **Perfect Pitch** *(new)* — bonus multiplier for a steady tapping cadence (low variance between
   your own consecutive hit intervals during a repeat-back), measured identically in Normal/Chaos/
   Duet. Levels scale the bonus magnitude: **+5% / +8% / +12% / +16% / +20%** when cadence is
   steady. No L5 twist - the "cadence consistency" measurement itself still needs a real formula
   (window size, variance-to-bonus mapping) before implementation, flagged in Open Items; adding a
   mastery gimmick on top of an unspecified base mechanic would be premature.
   **Implementation note:** shipped with a concrete formula (`_perfect_pitch_multiplier()` in
   `Main.gd`) - a rolling window of the last `PERFECT_PITCH_WINDOW` (4) inter-hit intervals; the
   bonus applies whenever that window's standard deviation is at or under
   `PERFECT_PITCH_STDEV_THRESHOLD_MS` (90ms). Both constants are by-eye placeholders, same status
   as every other untested numeric constant in this doc - needs a real playtesting pass to tune.
5. **Harmonic Chain** *(new)* — stacking bonus for consecutive hits within the same musical chunk/
   motif (depends on the chunking generator, `TODO.md`). Levels scale the per-hit stack increment:
   **+2% / +3% / +4% / +5% / +6%** per consecutive in-motif hit. **L5 twist:** the stack no longer
   resets at the chunk boundary — it carries into the *next* motif too, as long as the streak
   continues unbroken. At L1-4 this is "a per-chunk combo bonus"; at L5 it becomes a whole-streak
   combo that just happens to accelerate fastest during motifs, a real step up in what the pick
   rewards.
6. **Fortissimo** *(power, milestone-gated — full redesign, was cap-relative)* — **new mechanic:**
   self-referential, like Perfect Pitch — keys off **beating your own longest streak this run**
   (`best_streak_this_run`, tracked live as the longest `_current_wave_length()` ever reached,
   independent of whether that streak was later cashed out or lost to a miss). Once your *current*
   streak passes that threshold, a multiplier applies for the rest of the streak. Levels tighten the
   margin needed and raise the payoff:
   - L1: kicks in 3+ steps past your best, ×1.3
   - L2: 2+ steps past, ×1.4
   - L3: 1+ step past, ×1.6
   - L4: ties your best (0 margin), ×1.8
   **L5 twist:** kicks in the instant you *tie* your best, at ×2.2 — and the moment your streak
   sets a genuinely *new* personal best while Fortissimo is active, it grants a one-time direct
   injection into the unbanked pool (a "personal-best fanfare" bonus) on top of the ongoing
   multiplier. This is the mastery payoff: at L5, doing something no version of you has done yet
   *this run* is rewarded twice, once by the multiplier and once by the fanfare. Suggested unlock
   unchanged: survive 10 waves in a single run (a real, countable run stat, unaffected by the cap's
   removal).

### Grace

Currently the thinnest category in the live game (Safety Net is its only member).

**Design invariant, binds every modifier in this category:** forgiveness never advances past the
failed step. Confirmed against the live code (`_on_pad_pressed`) — a forgiven miss never moves
`player_index`; the player is still required to land the *correct* pad at that exact position
before the round continues. Sequences are cumulative across rounds, so a modifier that skipped a
failed step would leave it permanently unverified and silently ambush the player every future
round. Forgiveness may waive the *penalty* for a wrong guess; it may never waive the requirement
to eventually get the step right.

**Note: the stale premise found during this pass has since been fixed in code.** A previous pass
of this doc found that the live code didn't reset `combo` on any miss (forgiven or otherwise) —
only at run start and game over — which made Muffled Strike's original pitch ("halves combo
instead of zeroing it") dead on arrival, since combo already survived every miss unconditionally.
That's now been corrected directly in `Main.gd` (and `docs/scoring-and-modifiers.md`): a forgiven
miss halves `combo` (integer division), rather than leaving it untouched or wiping it. Muffled
Strike below stays as its full redesign (a probabilistic backup under `mistake_charges`, unrelated
to combo) rather than reverting to the original pitch — the original idea is now simply *what a
forgiven miss always does*, baseline, with no modifier required, so re-offering it as a pick would
be offering the player something they already have for free. The redesign remains the right call,
just for a slightly different reason than when it was written.

1. **Safety Net** *(existing, shipped as flat uncapped charge stacking today, plus a hint-flash on
   forgiven misses shipped this session)* — forgive your next mistake, protecting both the run and
   the current streak's unbanked points (`docs/scoring-escalation.md`). Leveled target: each
   level-up grants charges equal to the new level (**L1 grants 1 charge, leveling to L2 grants 2
   more, L3 grants 3 more, L4 grants 4 more, L5 grants 5 more** — a level-5 Safety Net has been
   through 15 total granted charges across its leveling history, though some may already be spent).
   **L5 twist:** the shipped hint-flash (re-flashing the correct pad before a forgiven retry) shows
   the *next two* upcoming notes instead of just the one that was missed — at maximum investment,
   forgiveness comes with real foresight, not just a rescue. Exhausted charges do not unequip
   Safety Net; the Defense slot stays filled at 0 until a level-up grants more.
2. **Echo Chamber** *(new — full redesign, was a near-duplicate of Safety Net's new hint behavior)*
   — reframed from *reactive* (forgive + hint on a miss, which baseline Safety Net now already
   does) to **proactive**: a limited "Peek" action the player can spend *before* attempting a step
   they're unsure of, previewing/replaying the upcoming note on demand. This is a genuinely
   different resource-spending tradeoff from Safety Net — spend deliberately for certainty on a
   step you choose, vs. Safety Net's free-until-you-actually-fail reactive insurance — so the two
   Defense picks no longer read as flavors of the same thing. Leveled the same way as Safety Net
   (level-up grants charges equal to the new level). **L5 twist:** a Peek at level 5 doesn't reveal
   just the next note — it reveals the next *three*, for the cost of a single charge. A maxed Echo
   Chamber turns from "confirm one note at a time" into "read ahead," a real step up in what the
   resource buys, not just more of it.
   **Revision note:** originally excluded from Duet entirely (the Peek button hard-returned on
   `duet_mode`). Fixed — Peek now works mid-response in Duet too, pausing the response clock for
   its duration so spending a charge can't cost a miss (see the cross-mode audit above).
3. **Muffled Strike** *(new — full redesign, original premise is dead code per the note above)* —
   reframed as a **passive, probabilistic backup under `mistake_charges`**: when a miss would
   otherwise be fatal (no charges left), there's a chance it's forgiven anyway — unlimited,
   unlike Safety Net's countable charges, but never guaranteed. Levels raise the odds: **10% / 18%
   / 28% / 40% / 55%** at L1-L5. **L5 twist:** when the chance triggers at level 5, it also fully
   protects the current streak's unbanked points (Safety-Net-equivalent protection), not just the
   run — at maximum investment, a lucky save is a *full* save, points included, not merely a
   second chance. Distinct from Second Wind (below), which is deterministic-but-limited and always
   ends the streak; Muffled Strike is unlimited-but-unreliable and, on a normal (non-L5) success,
   keeps the streak running exactly where it was, like an extra Safety Net charge that only exists
   when you'd otherwise be out of them.
   **Implementation note:** the shipped forgiveness path (`_resolve_defense_on_miss()`,
   `docs/scoring-and-modifiers.md`) already leaves the unbanked pool untouched on *every* forgiven
   outcome unconditionally, not just at L5 — that was true before Muffled Strike existed and stays
   true for it at every level. The "L5 also protects points" line above doesn't get special-case
   code as a result; it's accurate as a description of what happens, just not as a *contrast* to
   L1-4 (which already behave the same way on that specific point). Left as-written above rather
   than edited, since it's a harmless overstatement rather than a wrong one.
4. **Grounding Resonance** *(redesigned a second time — the "slows the ramp" mechanic above shipped,
   then failed its own cross-mode audit)* — the original pitch generalized it from Chaos-only to
   "slows any mode's per-round escalation ramp," but Normal Mode was found to have no ramp at all,
   not just a low-value one: a full Normal-mode run made this pick a complete no-op, contradicting
   the audit standard the rest of this doc holds every modifier to. **New mechanic, identically real
   in every mode:** a fatal miss (one that would otherwise go to `_game_over()` with the streak's
   `unbanked_points` forfeited outright) banks a percentage of that unbanked pool instead of losing
   it all — same "protect the unbanked pool, not just run-continuation" spirit Safety Net already
   established, just triggered on the *unforgiven*, run-ending miss instead of an ordinary one.
   Leveled: **10% / 18% / 25% / 32% / 40%** of the forfeited pool banked at L1-L5. No L5 twist —
   still a pure loss-mitigation pick with nothing to qualitatively escalate into.
   **Implementation note:** `_game_over()` in `Main.gd` applies the refund (reading
   `grounding_resonance_pct`) before `final_score` is captured, so it lands in the run's recorded
   score. The old ramp-slowing code (`_generate_duet_phrase()`'s BPM ramp, `_play_sequence()`'s
   Chaos speed ramp) had its `grounding_resonance_pct` factor removed entirely.
5. **Second Wind** *(power, milestone-gated — full redesign, was redundant with baseline
   forgiveness)* — the original pitch ("once per wave, a miss triggers an early cash-out instead of
   losing unbanked progress") is now just what *any* forgiven miss already does by default (see
   `docs/scoring-escalation.md`'s forgiveness-protects-points behavior) — not a distinct pick
   anymore. **New mechanic: a true last resort, not a second Cash Out.** When a miss would otherwise
   be fatal, Second Wind keeps the run alive and resets the streak, at the cost of one use. It is
   deliberately worse than a voluntary cash-out so a refill cannot loop:

   - L1–4 bank **hit points only** (`unbanked_points`). No quadratic streak bonus, no
     `waves_completed` / Crescendo credit.
   - Combo halves, same as any other miss.
   - **L5 twist:** the save pays the full cash-out total plus a 25% clutch bonus — the mastery
     payoff for committing to this pick.
   - **Refill:** a *voluntary* cash-out (or Grand Finale win) at **Streak 5+** (the same `Streak N`
     number on the round HUD) restores one use, capped at the current level. The in-game
     description states this outright. A forced save never refills — the save is itself a
     cash-out-shaped event, so it cannot restock itself.
   - Uses still scale **1 / 2 / 3 / 4 / 5** by level; exhausting them does not unequip the
     modifier. The slot stays filled at 0 until a qualifying cash-out or a level-up.

   Distinct from Muffled Strike: Muffled Strike (if it triggers) keeps the streak *alive*; Second
   Wind always *ends* the streak, but is deterministic within its use count rather than a coin flip.
   Suggested unlock unchanged: complete a wave with zero misses first.
   **Implementation note:** `_force_cash_out_from_second_wind()` / `_try_refill_second_wind()` in
   `Main.gd`; threshold constant `SECOND_WIND_REFILL_STREAK = 5`.
6. **Unbreakable** *(power, milestone-gated)* — the first miss(es) each streak are forgiven free, no
   charge cost. Leveled: level *L* forgives the first *L* misses of each streak for free
   (**1 / 2 / 3 / 4 / 5**). No separate L5 twist — the numeric curve itself (going from "one free
   slip per streak" to "five") is already the mastery payoff for a power pick; it competes with
   Safety Net/Echo Chamber/Muffled Strike/Second Wind for the Defense slot and doesn't stack with
   them. Suggested unlock unchanged: complete a wave (streak) with zero misses.

### Tempo

Pacing/timing effects.

1. **Steady Hands** *(existing, shipped as flat uncapped multiplicative stacking today)* — sequence
   plays back slower. Leveled target: **8% / 15% / 22% / 30% / 40%** slower at L1-L5 (replacing the
   shipped `×1.15` per pick, uncapped). No L5 twist.
   **Revision note:** found dead in Duet during a later cross-mode audit (only wired into
   `_play_sequence()`, never `_play_duet_call()`) — fixed, see the cross-mode audit section above.
2. **Quick Rewind** *(replaces Patient Ear — that pick shipped, then failed its own cross-mode audit
   for a different reason: it was universally inert, not mode-specific)* — Patient Ear's "longer
   pause before your turn starts" turned out to have nothing to act on: the game has no timeout or
   reaction-speed penalty anywhere, so extra idle time before an already-untimed turn didn't give
   the player anything they didn't already have. **New mechanic:** an on-demand, charge-gated
   ability (a "Rewind" button alongside Peek/Gamble in the loadout HUD) that replays the *entire*
   current sequence (Normal/Chaos) or call phrase (Duet) at a fast, level-scaled speed. Unlike the
   original always-on pause, this is a real resource: leveling raises both replay speed (still
   "quick," but more perceivable at higher levels — **6.0x / 4.5x / 3.5x / 2.5x / 1.8x**) and the
   charge count (**1 / 2 / 3 / 4 / 5** uses), refilled the same way as Second Wind/Grand Finale — a
   voluntary cash-out (or Grand Finale win) at **Streak 5+** restores one use, capped at the current
   level. No L5 twist beyond the numeric curve. Works in Duet: using it mid-response pauses the
   response phase's clock for its duration (see the cross-mode audit above), so it can't cost a miss
   or skew the timing grade.
   **Implementation note:** `_use_quick_rewind()`/`_quick_rewind_sequence()`/
   `_try_refill_quick_rewind()` in `Main.gd`; threshold constant `QUICK_REWIND_REFILL_STREAK = 5`.
3. **Metronome** *(new)* — subtle rhythmic pulse cue during playback, a perceptual aid equally
   useful in Normal/Chaos/Duet, pairs naturally with Perfect Pitch's cadence bonus. Leveled: cue
   clarity/salience increases at each level (by-eye tuning, same status as the shimmer shader).
   No L5 twist — it's a passive perceptual aid, not a scoring effect, and a gimmick here risks
   crossing into "secretly also a Multiplier-category effect," which would blur the category
   boundary the slot system depends on.
4. **Slow Fade** *(new)* — pad glow/flash lingers longer after lighting, a visual-tracking aid, most
   valuable in Chaos. Leveled: **+0.2s / +0.4s / +0.6s / +0.8s / +1.0s** linger. No L5 twist.
5. **Breath Mark** *(new)* — every 4th step gets a slightly longer pause, an audible "phrase break"
   reinforcing chunk boundaries. Leveled: pause length scales **+10% / +20% / +32% / +45% / +60%**
   relative to the base gap. No L5 twist.
6. **Rubato** *(power, milestone-gated)* — adaptive pacing: the sequence only slows down when
   you've recently been slow/hesitant, full speed when you've been confident. Reads recent
   repeat-back duration, identical across Normal/Chaos/Duet. Levels raise how responsively it reacts
   (bigger slowdown when hesitant, faster return to full speed once confident again) through L1-L4.
   **L5 twist:** gains a second, opposite direction — when you've been *unusually* fast and
   confident recently, the sequence can play back *faster* than the mode's own baseline speed, not
   just return to it. At L1-4 Rubato only ever gives relief (slow down when struggling, normal
   speed otherwise); at L5 it becomes genuinely two-directional, rewarding a hot streak with actual
   speed instead of just refusing to punish a cold one. Suggested unlock unchanged: reach a 25-combo
   in a single run.
   **Revision note:** found dead in Duet alongside Steady Hands during the same cross-mode audit
   pass — fixed the same way (see the cross-mode audit section above).

### Ornament

Special one-off scoring moments.

1. **Golden Step** *(existing, shipped as flat uncapped stacking today)* — one extra step per round
   worth 3x points. Leveled target: level *L* sets `golden_step_count` to *L* directly (**1 / 2 / 3
   / 4 / 5** gold steps per round) — this one already maps cleanly onto the shipped `+= 1` per pick
   behavior, so "leveling" it is mostly a naming/UI change (showing "Golden Step Lv.3" instead of
   "active x3"), not a formula change. No L5 twist.
2. **Double Down** *(new)* — one flagged step per streak is a gamble: hit it and the cash-out
   formula treats the current step as further along the streak-length curve than it actually is
   (temporarily boosting `s` in `bonus(s)`); miss it and forfeit the streak's unbanked progress
   early without ending the run. Leveled: the temporary `s` boost on a successful hit scales up
   (**+2 / +3 / +5 / +7 / +10** effective steps). **L5 twist:** landing the gamble step
   successfully also flags a *second* gamble step later in the same streak — "doubling down on
   doubling down" — instead of a single bigger one-off jump, turning a maxed pick into a chain of
   escalating risk/reward moments within one streak rather than one bigger moment.
3. **Encore** *(new)* — on cash-out, immediately replay the streak's final phrase once more for a
   bonus before the reset happens. Leveled as a percentage of the cash-out value just banked:
   **50% / 65% / 80% / 95% / 110%** — at L5 the encore literally outpays the original performance,
   a clean, legible escalation to "the encore becomes the main event" without needing a separate
   qualitative mechanic change.
4. **Lucky Strike** *(new)* — small random chance per round of a surprise bonus-value pad appearing
   in the sequence, distinct from Golden Step's guaranteed extra step. Leveled: chance rises
   **5% / 9% / 14% / 20% / 28%** per round, with the bonus pad's own value also ticking up modestly
   at higher levels. No L5 twist.
5. **Motif Bonus** *(new)* — flat bonus for correctly landing a full repeated motif/chunk, the
   direct reward-side counterpart to Harmonic Chain and Breath Mark. Leveled: flat bonus amount
   scales up per level (by-eye tuning). No L5 twist.
6. **Grand Finale** *(power, milestone-gated — redesigned twice: first from the rejected wave-cap
   mechanic, then again from a single-note gamble to a round-scoped one)* — **shipped as an
   opt-in "Double or Nothing" gamble**, but not on the Cash Out button itself: a separate "Gamble"
   button that appears alongside Cash Out once equipped, so pressing Cash Out always just banks
   normally and the gamble is a deliberate second action, never an accidental one. The wager scope
   also changed from the original pitch: rather than betting on landing *exactly one more correct
   note*, Grand Finale now wagers the current unbanked pool on **completing the rest of the round
   already in progress** — a real, if-you-can-clear-it swing, not a single coin-flip press. Winning
   (clearing the round) banks the wager at a multiplier; missing anywhere in it forfeits the wager
   and forces a hard streak reset, bypassing Defense-category forgiveness entirely (the same
   self-contained-wager bypass Double Down already used, so a miss here still never consumes a
   Safety Net/Second Wind/Muffled Strike resource). Levels set the payout multiplier: **1.5x / 1.8x
   / 2.2x / 2.7x / 3.5x**. **Charges, not unlimited attempts:** unlike the original always-available
   pitch, each gamble now spends one charge from a pool (**1 / 1 / 2 / 2 / 3** uses at L1-L5,
   granted on level-up), refilled the same way as Second Wind — a voluntary cash-out at **Streak
   5+** restores one use, capped at the current level. **L5 twist, redefined for the round-scoped
   wager:** "insured" no longer means a free retry on the same note — a miss during an insured
   gamble banks the wager anyway (at no multiplier, just as if you'd cashed out normally) *and*
   refunds the spent charge, so a maxed Grand Finale genuinely cannot cost you anything, only fail
   to pay off; the capstone feeling (this pick becomes a cheat code once fully mastered) is
   unchanged from the original design intent, just re-grounded in the new mechanic. Works fully in
   Duet: `_handle_duet_miss()` checks a pending gamble before normal defense handling, and
   `_run_duet_response()` resolves a win on the phrase's natural completion. Suggested unlock
   unchanged: cash out 5 times in a single run.
   **Implementation note:** `_start_grand_finale_gamble()`/`_resolve_grand_finale_win()`/
   `_resolve_grand_finale_loss()`/`_try_refill_grand_finale()` in `Main.gd`; threshold constant
   `GRAND_FINALE_REFILL_STREAK = 5`.

## Milestone gating

Unchanged in shape — each category's power modifier unlocks via a milestone themed around the wave
economy (`waves_completed`, a real countable run stat unaffected by the cap's removal) rather than
reusing the Round/Score/Combo ladder, keeping it a distinct later-game progression layer:

| Power modifier | Category | Suggested unlock |
|---|---|---|
| Fortissimo | Dynamics | Survive 10 waves in one run |
| Unbreakable | Grace | Complete a wave with zero misses |
| Second Wind | Grace | Complete a wave with zero misses *(shares Unbreakable's gate — both are Grace, only one can ever be equipped, so this isn't a race, just two different rewards for the same proof of skill)* |
| Rubato | Tempo | Reach a 25-combo in one run |
| Grand Finale | Ornament | Cash out 5 times in one run |

Note Second Wind is now also milestone-gated (it wasn't in the original roster, which had only one
power pick per category) — its redesign above turns it into a genuinely strong, limited-use
run-saving effect, which fits the "power" tier better than an always-available Tier-1 pick would.

## Example builds

Because only one modifier can be equipped per category, a "build" is a cross-category combo, not
same-category stacking. Reassessed against every redesign above — two of the four original builds
needed real changes, not just relabeling.

**Marathon Runner** — *Crescendo* + *Second Wind* + *Rubato* + *Encore*
   Still holds, with the save nerfed so it cannot feed Crescendo: bank consistently, spend Second
   Wind as a last resort (hit points only unless L5), refill a use by cashing out at Streak 5+,
   let Crescendo climb off *voluntary* waves while Rubato keeps pace forgiving and Encore pads
   every real cash-out. A level-5 Crescendo is this build's real payoff moment — the multiplicative
   compounding is what turns "consistent" into "exponential" late in a long run.

**Precision Virtuoso** — *Perfect Pitch* + *Muffled Strike* + *Metronome* + *Double Down*
Mostly holds; Muffled Strike's redesign (passive probabilistic backup) fits this build's
philosophy slightly *better* than the original ("softens a miss") did — a precision player who
rarely misses doesn't want a guaranteed-charges Defense pick eating a slot for insurance they
rarely need, and a low-frequency passive chance costs less opportunity while they lean on skill
(cadence, timing) instead. Metronome gives the cue, Perfect Pitch pays off the steady rhythm,
Double Down is the payoff gamble.

**Chunk Master** — *Harmonic Chain* + *Grounding Resonance* + *Breath Mark* + *Motif Bonus*
Unchanged — every piece is still chunk-mechanic-adjacent, and a level-5 Harmonic Chain (stack
carries across chunk boundaries) is now this build's clear "you've mastered noticing the cue"
payoff moment, giving it a stronger endgame identity than it had before leveling existed.

**All-In Gambler** — *Fortissimo* + *Unbreakable* + *Steady Hands* + *Grand Finale*
Rewritten philosophy: a milestone-gated "boss build" across three categories, now genuinely
buildable since Fortissimo and Grand Finale both have real mechanics again. Ride every streak past
your own personal best (Fortissimo), never really lose a streak to one careless slip
(Unbreakable), and cap it off by wagering the whole unbanked pool on Grand Finale's Double or
Nothing — clearing the rest of the round pays out at the level's multiplier, and at level 5 a miss
can't actually cost the wager either (it banks anyway, and the spent charge refunds), turning the
build's capstone move into a guaranteed-payoff swing once fully earned. This is the build the
milestone gating is explicitly trying to make players *earn*, not stumble into.

**Deep Specialist** *(new — a fifth build, specifically about the leveling system)*
No fixed loadout — the build *is* the decision to max one category-defining pick to level 5 instead
of spreading four different category picks thin. The pitch: a level-5 Crescendo, Echo Chamber,
Rubato, or Grand Finale each fundamentally change how their slot plays (multiplicative compounding,
three-note lookahead, two-directional tempo, a wager that can no longer actually lose) in a way
four separate level-1 picks across categories never could. Worth calling out as its own build entry
because the leveling system is new enough this session that "should I diversify or commit" deserves
to be a named strategic question, not just an emergent property players discover on their own.

## Open items

- **Perfect Pitch's cadence-consistency measurement** still needs an actual formula (window size,
  variance-to-bonus mapping) before implementation or before its L1-L5 percentages mean anything
  concrete — unresolved by this pass, deliberately (see its entry above).
- **All leveling percentages/counts/seconds in this doc are placeholder tuning**, same status as
  `CASHOUT_QUADRATIC_K` and the shimmer-shader parameters — a real balance pass needs actual
  playtesting hours against the shipped cash-out economy, which itself is only one session old.
- ~~`docs/scoring-and-modifiers.md` currently states "a miss resets combo," which doesn't match the
  shipped code~~ **Fixed.** A forgiven miss now halves `combo` in `Main.gd`, and
  `docs/scoring-and-modifiers.md`/`GAME_OVERVIEW.md`/the onboarding copy all describe that
  accurately as of this session. This is what made Muffled Strike's original design dead on
  arrival (see its entry above) — the fix didn't revive that original pitch, since halving-on-miss
  is now baseline behavior, not something a modifier needs to grant.
- **Swap-or-skip UX** (for drafting a *different* modifier into a filled slot) still isn't designed
  — needs its own small UI spec alongside the modifier_panel work already done in Phase 1. The new
  same-modifier-levels-up path needs a UI treatment too (how a level-up draft offer visually differs
  from a fresh-pick offer), not just the swap-or-skip case.
- **The "forgiveness never advances past a step" invariant** (Defense category intro) needs to be a
  hard constraint at implementation time, not just a design note — same flag as before, now doubly
  true with Echo Chamber's proactive Peek and Second Wind's forced-cash-out path both needing to
  respect it too.
- ~~Grand Finale's and Double Down's gamble-note handling both need a shared implementation note~~
  **Resolved.** Both are self-contained wagers that bypass `_resolve_defense_on_miss()` entirely on
  their own miss (`_forfeit_streak_from_double_down()`, `_resolve_grand_finale_loss()`) — confirmed
  in both `_on_pad_pressed` (Normal/Chaos) and `_handle_duet_miss()` (Duet), so neither can
  accidentally consume a Safety Net/Echo Chamber/Muffled Strike/Second Wind resource. Grand Finale's
  wager scope changed from a single note to the rest of the current round in a later pass (see its
  roster entry above) — the bypass-defense-mods behavior itself didn't change.
- **Second Wind and Unbreakable sharing a milestone gate** (both "complete a wave with zero
  misses") is a deliberate choice (see the Milestone Gating note above) but hasn't been checked
  against whether the game's unlock-toast UI reads sensibly when a single achievement unlocks two
  modifiers at once — flagged for implementation-time UI review.
