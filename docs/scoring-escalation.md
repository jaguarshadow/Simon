# Scoring Escalation — Design Doc

**Status: wave/cash-out mechanic is implemented and shipped** (`scripts/Main.gd`) — this doc now
describes the actual shipped behavior for that piece, not a design proposal. The other three
`TODO.md` bullets this doc covers (modifier slot system, roster expansion, musical chunking) are
still design-only, not yet implemented; those sections keep their forward-looking, proposal tone.

**The shipped mechanic differs substantially from this doc's original design** — the original
"forced reset at a climbing wave cap" was built, then explicitly rejected by the user during
implementation review: interrupting a player's growing sequence mid-groove read as jarring, not
tense, which cuts against the "calm, gently punishing" tone `GAME_OVERVIEW.md` establishes. What
shipped instead is **fully player-triggered, with no cap at all** — see "What shipped instead"
below for the full account; the sections after it describe the current, real mechanic.

The full modifier roster this depends on (24 modifiers, 4 categories, milestone gating, a 1-5
leveling system, example builds) is already written up in
[modifier-expansion.md](modifier-expansion.md) — this doc doesn't repeat that content, only how the
roster's slot system interacts with the cash-out economy below. **That doc's cap-dependent entries
(Fortissimo, Grand Finale) and the redundant-with-shipped-behavior ones (Second Wind, Echo Chamber)
have all been redesigned as of the same session** — none of the roster is still designed against
the rejected cap. Current, *shipped* scoring behavior (combo math, gold steps, cash-out, the
5-modifier stacking model) is in
[scoring-and-modifiers.md](scoring-and-modifiers.md); read that first for the ground truth on what
actually runs today.

## The problem

Per `GAME_OVERVIEW.md`, sequence length only ever grows one step per round, and human working
memory puts a real ceiling on how long a sequence can get before "challenging" becomes "physically
unplayable" — Chaos Mode already runs into this with its speed-ramp clamp
(`clamp(1.0 - float(sequence.size() - 1) * 0.05, 0.5, 1.0)`, floored at 2x speed for exactly this
reason, see [game-modes.md](game-modes.md#chaos-mode)). Before this mechanic, there was no cap on
`sequence.size()` at all beyond what a run's wrong-pad failure naturally imposes — score only ever
grew by playing one ever-longer sequence until a miss ended the run outright, and `_register_hit`'s
combo multiplier grows linearly, not compounding, specifically so scores don't blow past the Best
Score unlock thresholds (500, 1500) on a single lucky long run (see
[scoring-and-modifiers.md](scoring-and-modifiers.md#combosscore-math)).

Balatro's answer to a structurally-similar problem (a hand of cards is also a bounded resource) is
to decouple score growth from the bounded thing: score compounds across *many* short hands via
persistent jokers, not by making one hand infinitely long. This doc's mechanic adapts that shape to
Simon's memory-game constraint: **sequence length stays bounded per streak and resets on the
player's own call; the things that make a reset worth more (multiplier, modifiers) persist and
compound across resets.**

## What shipped instead of a forced cap

The original design (preserved below in "Rejected: the forced wave-cap design" for the record) had
sequence length grow toward a climbing cap that forced a reset once reached, with cash-out as a
voluntary *early* alternative to that forced reset. Two rounds of playtest feedback during
implementation changed this:

1. **"It's hard to test the cap because I keep failing before it resets."** Surfaced that a
   cap set anywhere near the pre-existing difficulty ceiling (the game already starts every run
   with zero mistake forgiveness) makes the *first* wave demand near-flawless play with no
   cushion — a tuning problem on its own, but it also exposed the deeper issue below.
2. **"The cap thing feels weird — when you're on a groove with a pattern it's jarring to have it
   change in the middle of a run... it should be up to the player when to trigger the reset."**
   This is the real objection: a forced reset, however well-telegraphed, takes control away from
   the player at the exact moment (a long, successful streak) when they're most invested in it.

The fix wasn't a smaller/gentler cap — it was removing the cap entirely. **There is no
`sequence.size()` (or Duet phrase-ramp) ceiling in the shipped code.** A streak can grow
indefinitely; only the player decides when it ends via the Cash Out button. This does remove the
original design's answer to "why does a run ever end regardless of build quality" (the climbing cap
guaranteed it, Balatro-blind-style) — see "Why no artificial 'game goes on forever' fix is needed"
below for what replaces that guarantee.

## Cash Out: a standing, player-triggered action

A **Cash Out** button (`cash_out_button` / `CashOutButton` in `scenes/Main.tscn`) is visible
throughout any Normal, Chaos, or Duet run (not Zen/Music, which have no scoring). It's enabled
exactly when it's the player's turn to act — its `disabled` state is driven off the same
`_set_pads_disabled()` calls that enable/disable the pads themselves, so it can't be tapped
mid-sequence-playback or during the round-clear pause into an inconsistent state. Its label shows
the live total the player would bank right now, e.g. `Cash Out (+142)`, refreshed on every hit via
`_update_score_labels()`.

This replaces the original design's "reuse the round-clear pause beat, continue-by-default" UI
concept entirely — there's no per-round prompt; the option is just always there when it's your
turn, and doing nothing costs nothing (no beat to sit through, no default to accept).

### Two-pool scoring: unbanked vs. banked

This is the mechanic's core structural change from the original design, driven by a further round
of feedback ("my score is going up before I've cashed out... it's supposed to be a kaching — bank
your points"). Score is now split into two pools:

- **`unbanked_points`** — every correct hit's points (`_register_hit`'s existing point math,
  unchanged) accumulate here, *not* into `score` directly.
- **`score`** (shown as "Score: N") — only increases when the player actually cashes out. It stays
  visibly flat through an entire streak, then jumps on cash-out — the "kaching" moment the player
  asked for, and the reason a miss can now genuinely cost something beyond combo.

`_register_best()` (Best Score/Round/Combo tracking, `GAME_DESIGN.md`'s unlock ladder) reads `score`
only — a fluky in-progress streak can't set a new best until it's actually banked, matching the
"protection" spirit below.

### Cash-out formula (as shipped)

```gdscript
func _current_wave_length() -> int:
	var queued := duet_wave_round if duet_mode else sequence.size()
	if current_round_has_hit:
		return queued
	return max(0, queued - 1)

func _cash_out_streak_bonus() -> int:
	var s := _current_wave_length()
	var multiplier := 1.0 + float(combo - 1) * combo_growth
	return int(round(CASHOUT_QUADRATIC_K * float(s) * float(s) * multiplier))
```

`_next_round()` appends the new note (or increments `duet_wave_round`) *before* the player acts, so
`sequence.size()` / `duet_wave_round` are one step ahead of anything earned. Cash-out bonus, Fortissimo,
and the button label all read `_current_wave_length()` instead, which stays on the previous completed
length until a hit lands this round (`current_round_has_hit`). The round HUD's `(Streak N)` still
shows the queued length — that's "what you're facing," not "what you've banked."

`CASHOUT_QUADRATIC_K = 2.0` is a placeholder tuning constant — same by-eye/balance-pass status as
the shimmer shader parameters and other numeric placeholders elsewhere in these docs, not a
considered final value. The **quadratic-in-streak-length shape** is preserved from the original
design intent (small early, dramatically larger late — the same "just one more step" tension
push-your-luck games like Incan Gold lean on) even though the cap-relative framing
(`bonus = k × cap(n) × (s/cap(n))²`) is gone; without a cap to normalize against, it's now a direct
`k × s²`, uncapped in principle since `s` itself is uncapped.

On cash-out (`_on_cash_out_button_pressed`): `score += unbanked_points + streak_bonus`;
`unbanked_points` resets to `0`; the streak itself resets — `sequence` truncated to length 0 for
Normal/Chaos (`WAVE_RESET_LENGTH = 0`; `_next_round()` always appends one note before playing, so
the next round plays exactly 1 note) or `duet_wave_round = 0` for Duet; `waves_completed`
increments. Combo, `combo_growth`, all modifier state, and `mistake_charges` are untouched — this
part of the original "what persists" intent is unchanged even though the trigger mechanism is
completely different now.

### Unifying Duet Mode's ramp — now genuinely player-triggered too

Duet Mode's own per-round ramp (call-phrase length and tempo, see
[game-modes.md](game-modes.md#duet-mode)) is unified onto the same streak-reset mechanism as
Normal/Chaos, exactly as the original design intended, just without a cap driving it:

- **`duet_round`** keeps incrementing every round, forever, for the run's whole duration — it still
  drives `MODIFIER_ROUND_INTERVAL` gating via `_current_round()` and best-round tracking, unaffected
  by cash-outs.
- **`duet_wave_round`** is a new, separate counter that drives `_generate_duet_phrase()`'s bpm/pulse
  ramp instead of `duet_round`, and resets to `0` on cash-out. This is what makes Duet's difficulty
  ramp restart with the rest of the streak on a cash-out, and it's also what `_current_wave_length()`
  reads for Duet's cash-out bonus (in place of `sequence.size()`, since a Duet phrase isn't
  cumulative the way Normal/Chaos's sequence is).

Concretely: both modes trace back to one shared idea (a streak-local counter that resets on cash-out
and drives that mode's own escalating quantity), even though — as the original doc anticipated —
the exact numbers aren't literally shared, since phrase length/tempo and cumulative sequence length
aren't the same kind of quantity.

### Why no artificial "game goes on forever" fix is needed

The original design's forced climbing cap existed specifically to guarantee no build could make a
run un-losable, Balatro-rising-blind-style. Removing it raised the same question during design
discussion: what stops a sufficiently good build from riding one streak forever?

The answer that shipped: **nothing needs to, because the incentive structure already discourages
it, and the real ceiling — human recall — was never removed.** Two separate forces do this work
without any forced mechanic:

- **Riding one streak forever is strictly worse expected value than periodically cashing out.**
  The moment a player cashes out, they start compounding a *fresh* quadratic bonus curve from a
  short streak again, while their multiplier/modifiers (which persist) keep applying. A player who
  never cashes out never realizes any of that compounding — they're leaving score on the table by
  definition, since `score` never moves until a cash-out happens at all.
- **The risk of a miss is real and growing.** A longer unbanked streak is strictly more points at
  risk (see "What a miss costs" below) *and* a harder sequence to hold in memory. Nothing artificial
  needs to end a run — the same real, human recall ceiling that has always bounded this game is
  still there; the mechanic just gives the player a reason to bank periodically instead of grinding
  toward it.

No forced-swap/debuff mechanic (à la Balatro's boss blinds periodically muting a joker) was ever
adopted here either. It was considered and rejected in the original design on tone grounds — that
kind of spiky, punitive device fits Balatro's aggressive tone but cuts against this game's
established "calm, gently punishing, never harsh" identity (`GAME_OVERVIEW.md`'s soft-miss
philosophy) — and that rejection holds even more strongly now that there's no forced-reset moment
left for a forced-swap to pair with.

### What a miss costs (as shipped)

A wrong pad press still behaves per the existing forgiveness rule (`mistake_charges`, see
[scoring-and-modifiers.md](scoring-and-modifiers.md#mistake-forgiveness)) for whether the *run*
ends. What changed is what a miss costs **beyond** that, following a direct design call from the
user: *"protection from misses should also provide protection for points, otherwise what's the
point?"*

- **A forgiven miss (a `mistake_charges` charge is available) leaves `unbanked_points` completely
  untouched.** Safety Net and its future Defense-category siblings (`modifier-expansion.md`) now
  protect the run *and* the currently-unbanked streak value — not just run-continuation. This falls
  out of the code with no extra logic: the forgiveness branch in `_on_pad_pressed` never touched
  score before this mechanic existed, and it still doesn't — `unbanked_points` simply isn't in the
  forgiveness code path at all.
- **A true run-ending miss (no charges left) forfeits `unbanked_points`** — not because anything
  explicitly clears it, but because it was never added to `score` in the first place.
  `_game_over`'s `final_score` reads `score` (banked-only), so whatever was unbanked at the moment
  of failure simply never counted.

This is a real behavioral change from the pre-cash-out game, where score was never at risk from any
miss, forgiven or not (see [scoring-and-modifiers.md](scoring-and-modifiers.md#combosscore-math)
for that older philosophy). The new rule only applies to the *unbanked* pool introduced by this
mechanic — score that's already been cashed out is exactly as permanent as it always was.

## Rejected: the forced wave-cap design

Kept for the record, since `modifier-expansion.md` still designs a few not-yet-implemented
modifiers against it (flagged there) and a future implementer needs to know not to resurrect it by
accident.

The original shape: sequence length would grow toward a **wave cap** that itself climbed wave over
wave — gentle linear growth for several waves, then an accelerating phase (`cap(n)` roughly
8, 10, 12, 14, 16, 18, 21, 25, 30, 36, 43 for waves 1–11) — reaching the cap forced a reset
automatically, paying out the cash-out curve's guaranteed maximum. Cash-out before the cap was the
only voluntary option, surfaced via the round-clear pause beat with continue-by-default.

This shipped in an intermediate form (as `WAVE_CAP_START`/`WAVE_CAP_PHASE1_*`/`WAVE_CAP_PHASE2_*`
constants and a `_wave_cap()`/`_reset_wave()` pair in `Main.gd`), was tuned once in response to
playtest difficulty feedback (`WAVE_CAP_START` dropped from 8 to 5), and was then removed entirely
in the same session once the "jarring mid-groove interruption" feedback landed. None of that code
exists in the current file — this section is design history, not a description of anything live.

## Interaction with the modifier slot system

The slot system itself (four categories — Dynamics / Grace / Tempo / Ornament, one equipped
modifier per category, swap-or-skip on a re-pick) is specified in full in
[modifier-expansion.md](modifier-expansion.md#categories--roster); this section is only about how
it plugs into the cash-out economy above. None of this is implemented yet.

- **Picks still happen every 3rd round**, unchanged — `MODIFIER_ROUND_INTERVAL` doesn't need to
  know about streaks at all, since `total_round` (Normal/Chaos) and `duet_round` (Duet) keep
  incrementing across cash-outs exactly as they were designed to. A long run crosses many streaks
  and keeps hitting modifier picks on the same cadence it always has.
- **Slot contents are exactly the "persists" list above** — a cash-out is deliberately *not* a
  build-reset. This is what makes a build (per `modifier-expansion.md`'s example builds) a
  run-length investment rather than something you rebuild from scratch every streak.
- **Every modifier now levels 1→5 on a redraft instead of stacking flat forever** — picking a
  *different* modifier into a filled slot still prompts swap-or-skip, but picking the modifier
  already equipped in that slot levels it up. Full curves for all 24 (plus leveled-target versions
  of the 5 shipped modifiers) are in `modifier-expansion.md`; several get a qualitative level-5
  "mastery" effect, not just a bigger number.
  - **Crescendo** (Multiplier) is the direct answer to "should cash-out pay out more" — it scales
    off **waves completed this run** (`waves_completed`, incremented only by a voluntary cash-out),
    not combo (which already persists 100% across a cash-out with nothing to refund — see
    `modifier-expansion.md`'s opening section for why the base formula doesn't need a combo-based
    cash-out bonus). At level 5, Crescendo's per-wave bonus becomes multiplicative rather than
    additive — a real snowball, not just a bigger flat rate.
  - **Fortissimo, Second Wind, and Grand Finale** — all three were designed against the now-rejected
    cap and have been fully redesigned in `modifier-expansion.md` (self-referential "beat your own
    best streak," a true last-resort forced-cash-out on an otherwise-fatal miss, and an opt-in
    "Double or Nothing" gamble, respectively). None of them key off a cap anymore. Grand Finale's
    gamble later moved off the Cash Out button onto its own separate "Gamble" action once it became
    charge-limited, so Cash Out always just banks normally — see `modifier-expansion.md` for the
    current mechanic.
  - **Echo Chamber** was also redesigned (not cap-related, but redundant with Safety Net's new
    hint-flash behavior) into a proactive "Peek" the player spends *before* an uncertain step,
    distinct from Safety Net's reactive, only-on-failure protection.
- **Milestone gating for the five power modifiers** (Second Wind joined the power tier in the
  redesign) is themed around wave counts specifically because `waves_completed` is a real,
  countable run stat — unaffected by the cap's removal, since it was always "voluntary or forced
  completion," and now it's only ever voluntary.

## Musical chunking

Independent of the cash-out mechanic above, not yet implemented, no changes needed from the
original design — bundled into the same "Scoring escalation" initiative because it's the other
lever for making a single streak's sequence feel trackable at lengths beyond raw digit-span.

### The idea

Instead of generating each streak's sequence as pure independent random pad picks, build it out of
**reused, recognizable motifs** — short phrases that repeat within the sequence, the same way a
piece of music reuses a riff rather than being a string of unrelated notes. This reuses Music
Mode's existing generators (Euclidean-rhythm timing + the melody random-walk, see
[music-mode.md](music-mode.md)) rather than inventing a new generation system — a motif is
generated once per streak the way Music Mode generates one bar, then reinserted at later points in
the sequence instead of generating fresh random content for every step.

The payoff: human short-term memory for *arbitrary* sequences tops out fast, but memory for
*structured* sequences (ones with internal repetition/pattern) reaches meaningfully further —
players can track a longer effective sequence than raw digit-span would suggest, because part of
what they're recalling is "that riff again" rather than eight new independent facts. Since there's
no cap anymore, this doesn't need to justify pushing a wave-cap number higher — it's now purely
about making longer voluntary streaks (and their larger cash-out payouts) more humanly reachable.

### Why the visual cue has to be subtle

When a motif repeats within a streak's sequence, the pads involved get a **very subtle** visual
tell — explicitly not a callout, banner, or anything that reads as "the game is telling you the
answer." The whole value of chunking as a design tool is that it works on the *player's* ear/pattern
recognition; an explicit "here's the repeated bit" indicator would short-circuit that and turn a
cognition-aid into a cheat sheet, which defeats the purpose (it would effectively hand the player
the sequence rather than help them remember it). The bar for "subtle enough" is deliberately strict:
a player who isn't consciously listening for repetition shouldn't notice the cue at all; a player
who *is* engaging with the pattern should get a faint confirming signal, not a spoiler. Concretely
this should land in the same register as the existing shimmer/glow language already established by
the flat-palette shimmer upgrade (`GAME_DESIGN.md` §1.2) — a slight shift in the ambient shimmer's
character during a repeated motif, not a new UI element, badge, or color change layered on top of
existing hit/lit feedback. Exact shader parameters are a by-eye tuning task for implementation, same
as the flat-palette shimmer's own tuning pass was — this doc fixes the intent (barely perceptible,
rewards attentive players, never explicit), not pixel values.

### Hooks into the modifier roster

Chunking is the direct mechanical basis for three `modifier-expansion.md` entries, cross-referenced
here so the connection isn't only visible from that doc's side:

- **Harmonic Chain** (Multiplier) — a per-hit stacking bonus scoped to "hits within the current
  motif," resetting at the next chunk boundary. This is what gives the subtle visual cue actual
  mechanical stakes for a player who's built around noticing it, not just an ear-candy detail.
- **Breath Mark** (Tempo) — a slightly longer pause every 4th step, which is deliberately tunable to
  land on chunk/phrase boundaries so the rhythm itself reinforces where a motif ends, audibly rather
  than visually.
- **Motif Bonus** (Bonus-Event) — a flat reward for correctly landing an entire repeated motif,
  the direct scoring payoff to Harmonic Chain's per-hit version and Breath Mark's pacing support.

`modifier-expansion.md` calls the resulting build ("Chunk Master": Harmonic Chain + Grounding
Resonance + Breath Mark + Motif Bonus) "the build most likely to make players *notice* the chunking
system exists" — worth keeping in mind during implementation as an informal check on subtlety: if a
player *not* running that build starts noticing the cue unprompted, it's probably not subtle enough.

## Open items for implementation

- **Exact `CASHOUT_QUADRATIC_K`** — the shipped value (`2.0`) is a placeholder, not a considered
  balance pass. Needs real playtesting once the mechanic has had more hands-on time: does an
  unbounded quadratic streak bonus stay sane at very long streaks, or does it need a soft ceiling
  after all (a much later concern than the original per-wave cap, and voluntary/soft rather than
  forced if it's ever added)?
- **Fortissimo, Second Wind, Grand Finale, and Echo Chamber have all been redesigned** (a later
  pass, same session) — see `modifier-expansion.md` for the resolved mechanics. None of the roster
  is still designed against the rejected cap. The full 1-5 leveling system introduced in that same
  pass is a bigger open item now: every numeric curve in it is placeholder tuning, unplaytested.
- **How chunking's motif generation interacts with Chaos Mode's per-round reshuffle** — Chaos
  changes which physical pad is which note every round; a motif is defined by *note* sequence
  (reusing Music Mode's degree-based generation), so a repeated motif should still be audibly/
  structurally identical even though the physical pads a player presses for it change round to
  round. Worth an explicit check during implementation that the visual cue is keyed off the right
  identity (note/degree, not physical pad slot) given the two-separate-identity-systems pattern
  documented in [architecture.md](architecture.md#two-separate-identity-systems-for-a-pad).
- **Swap-or-skip UX** for the modifier slot system is already flagged as undesigned in
  `modifier-expansion.md`'s own open items — repeated here since it blocks this doc's "picks still
  happen every 3rd round" section from being fully implementable, not just modifier-expansion's.
