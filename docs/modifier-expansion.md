# Modifier Expansion — Design Proposal

Design proposal for the modifier roster feeding the "Scoring escalation" work in `TODO.md`. Not
yet implemented — current, shipped modifier behavior (simple additive/multiplicative stacking, no
levels, no slots) is documented in `docs/scoring-and-modifiers.md`. This doc assumes the shipped
cash-out economy (`docs/scoring-escalation.md`) is in place and adds two things on top of it: the
four-category slot system, and — new in this pass — a **1-5 leveling curve for every modifier**,
replacing the earlier "just stacks forever" model this doc originally proposed.

**Revision history:** an earlier pass rejected the wave-cap mechanic this doc was first written
against (sequence length climbing toward a forced-reset cap) in favor of the shipped
player-triggered, no-cap cash-out — see
[scoring-escalation.md](scoring-escalation.md#what-shipped-instead-of-a-forced-cap). That left
three roster entries (Fortissimo, Grand Finale, Second Wind) and one non-power entry (Echo
Chamber) specified against mechanics that no longer exist or are now redundant with shipped
behavior. **This pass resolves all four** with real redesigns (below) rather than leaving them
flagged — see each entry's own note on what changed and why.

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
- **Grounding Resonance** — generalized from Chaos-only to reducing *any* mode's per-round
  escalation rate (Chaos's speed/reshuffle ramp, Duet's tempo ramp). Normal has no ramp to slow, so
  it's naturally low-value there — expected, same pattern as Slow Fade being disproportionately
  useful in Chaos without being inert elsewhere.
- **Metronome** and **Rubato** were already mode-agnostic mechanically, just under-described as
  Duet-flavored extras — wording only.
- **Harmonic Chain** and **Motif Bonus** depend on the (not-yet-implemented) musical-chunking
  generator being shared across Normal/Chaos's sequences *and* Duet's call-phrases, not
  Normal/Chaos-only.

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
completed"** means a voluntary cash-out (win *or* lose a Grand Finale gamble both count, since both
resolve and reset the streak). Only a true run-ending miss (charges exhausted, and not otherwise
converted by Second Wind — see below) doesn't count.

## Categories & roster

Each category = one equip slot. A *different* modifier into a filled slot prompts swap-or-skip; the
*same* modifier into its own filled slot levels it up (see "Leveling" above).

### Multiplier

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
   steady. No L5 twist — the "cadence consistency" measurement itself still needs a real formula
   (window size, variance-to-bonus mapping) before implementation, flagged in Open Items; adding a
   mastery gimmick on top of an unspecified base mechanic would be premature.
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

### Defense

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
   forgiveness comes with real foresight, not just a rescue.
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
4. **Grounding Resonance** *(new)* — slows any mode's *intra-streak* per-round escalation rate
   (Chaos's speed/reshuffle ramp, Duet's tempo ramp) by a flat percentage; Normal has no ramp to
   slow, so it's naturally low-value there, same pattern as Slow Fade in Chaos. Explicitly scoped
   to in-streak pressure only — confirmed still correct under the shipped no-cap model, it never
   touched the cash-out formula and doesn't need to change now that there's no cap to protect
   either. Leveled: **10% / 18% / 25% / 32% / 40%** slower ramp at L1-L5 (diminishing-returns
   curve — deliberately front-loaded so early levels feel like the biggest relief). No L5 twist —
   this is a pure pressure-relief pick with nothing to qualitatively escalate into.
5. **Second Wind** *(power, milestone-gated — full redesign, was redundant with baseline
   forgiveness)* — the original pitch ("once per wave, a miss triggers an early cash-out instead of
   losing unbanked progress") is now just what *any* forgiven miss already does by default (see
   `docs/scoring-escalation.md`'s forgiveness-protects-points behavior) — not a distinct pick
   anymore. **New mechanic: a true last resort.** When a miss would otherwise be fatal (no charges
   left, and Muffled Strike either isn't equipped or didn't trigger), Second Wind converts *that
   specific miss* into a forced cash-out at the streak's current value instead of ending the run —
   the streak ends (banking whatever was unbanked, same formula as a normal cash-out) but the *run*
   continues into a fresh streak, at the cost of consuming one of Second Wind's own limited uses.
   This is meaningfully different from Muffled Strike: Muffled Strike (if it triggers) keeps the
   streak *alive*; Second Wind always *ends* the streak, but is deterministic within its use count
   rather than a coin flip. Levels set uses per run: **1 / 2 / 3 / 4 / 5** uses. **L5 twist:** at
   maximum investment, triggering Second Wind also pays a "clutch save" bonus — the forced cash-out
   is worth an extra 25% — so at L5 a near-death moment, resolved with your last available save,
   pays out *more* than an ordinary cash-out at the same streak length would have, not less.
   Suggested unlock unchanged: complete a wave with zero misses first (proving you don't *need* the
   safety net before the game hands you the strongest version of one).
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
2. **Patient Ear** *(new)* — longer pause before your turn starts. Leveled: **+0.3s / +0.5s / +0.8s
   / +1.1s / +1.5s**. No L5 twist — a pure prep-time buffer with nothing to qualitatively escalate
   into.
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

### Bonus-Event

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
6. **Grand Finale** *(power, milestone-gated — full redesign, was cap-relative)* — **new mechanic:**
   an opt-in **"Double or Nothing"** gamble that sits alongside the normal Cash Out button once
   equipped. Instead of banking normally, the player can wager the entire current unbanked pool on
   landing exactly one more correct note: win it, and the wagered total is banked at a multiplier
   (the streak ends either way, same as a normal cash-out — this is a supercharged cash-out
   variant, not a separate risk layered on top of the run itself); miss it, and the wagered
   unbanked pool is forfeited (the streak still ends, but the run does not — this miss is
   self-contained to the wager and doesn't consume a Safety Net/Second Wind/Muffled Strike
   resource, since it isn't a normal sequence miss). Levels set the payout multiplier: **1.5x /
   1.8x / 2.2x / 2.7x / 3.5x**. **L5 twist:** missing the gamble note is forgiven for free (the
   wager itself is insured once per gamble, at no charge cost) — at maximum investment, the "double
   or nothing" bet stops being able to actually cost you the wager, turning Grand Finale from a real
   gamble into a guaranteed-multiplier cash-out variant once fully mastered, which is the intended
   capstone feeling for this pick specifically (a Bonus-Event power modifier should eventually feel
   like a cheat code for the category's whole "special one-off moment" identity). Suggested unlock
   unchanged: cash out 5 times in a single run (the "complete 5 waves" language restated in shipped
   terms).

## Milestone gating

Unchanged in shape — each category's power modifier unlocks via a milestone themed around the wave
economy (`waves_completed`, a real countable run stat unaffected by the cap's removal) rather than
reusing the Round/Score/Combo ladder, keeping it a distinct later-game progression layer:

| Power modifier | Category | Suggested unlock |
|---|---|---|
| Fortissimo | Multiplier | Survive 10 waves in one run |
| Unbreakable | Defense | Complete a wave with zero misses |
| Second Wind | Defense | Complete a wave with zero misses *(shares Unbreakable's gate — both are Defense, only one can ever be equipped, so this isn't a race, just two different rewards for the same proof of skill)* |
| Rubato | Tempo | Reach a 25-combo in one run |
| Grand Finale | Bonus-Event | Cash out 5 times in one run |

Note Second Wind is now also milestone-gated (it wasn't in the original roster, which had only one
power pick per category) — its redesign above turns it into a genuinely strong, limited-use
run-saving effect, which fits the "power" tier better than an always-available Tier-1 pick would.

## Example builds

Because only one modifier can be equipped per category, a "build" is a cross-category combo, not
same-category stacking. Reassessed against every redesign above — two of the four original builds
needed real changes, not just relabeling.

**Marathon Runner** — *Crescendo* + *Second Wind* + *Rubato* + *Encore*
Still holds, arguably stronger now: never really fail (Second Wind's redesign is an even better fit
for "safety net" than its original version), bank consistently, let Crescendo's multiplier climb
purely off wave count while Rubato keeps pace forgiving and Encore pads every cash-out. A level-5
Crescendo is this build's real payoff moment — the multiplicative compounding is what turns
"consistent" into "exponential" late in a long run.

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
Nothing — at level 5, that wager can no longer actually lose, turning the build's capstone move
into a guaranteed multiplier once fully earned. This is the build the milestone gating is
explicitly trying to make players *earn*, not stumble into.

**Deep Specialist** *(new — a fifth build, specifically about the leveling system)*
No fixed loadout — the build *is* the decision to max one category-defining pick to level 5 instead
of spreading four different category picks thin. The pitch: a level-5 Crescendo, Echo Chamber,
Rubato, or Grand Finale each fundamentally change how their slot plays (multiplicative compounding,
three-note lookahead, two-directional tempo, a can't-lose gamble) in a way four separate level-1
picks across categories never could. Worth calling out as its own build entry because the leveling
system is new enough this session that "should I diversify or commit" deserves to be a named
strategic question, not just an emergent property players discover on their own.

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
- **Grand Finale's and Double Down's gamble-note handling both need a shared implementation note**:
  neither should consume a Safety Net/Echo Chamber/Muffled Strike/Second Wind resource on their own
  internal miss — they're self-contained wagers with their own win/lose resolution, not normal
  sequence misses. Worth a code comment at implementation time given how easy it'd be to
  accidentally wire a gamble-note miss into the general `_on_pad_pressed` forgiveness branch.
- **Second Wind and Unbreakable sharing a milestone gate** (both "complete a wave with zero
  misses") is a deliberate choice (see the Milestone Gating note above) but hasn't been checked
  against whether the game's unlock-toast UI reads sensibly when a single achievement unlocks two
  modifiers at once — flagged for implementation-time UI review.
