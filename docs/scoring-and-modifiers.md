# Scoring & Modifiers

## Combo/score math

`_register_hit()` on every correct pad press:

```gdscript
combo += 1
var multiplier := 1.0 + float(combo - 1) * combo_growth   # default combo_growth = 0.1
var points := int(round(10.0 * multiplier))
if player_index in gold_indices: points *= 3
points = int(round(points * (1.0 + score_bonus_percent)))
unbanked_points += points
```

Base 10 points, scaled by a multiplier that grows *linearly* with combo length (not
exponentially) — a deliberate choice so a long combo feels rewarding without runaway score
inflation making the "Best Score" unlock thresholds (500, 1500, etc.) trivially blown past by
anyone with a 50-combo run. `combo_growth` is itself a tunable the player can permanently raise
via the Sharper Ear modifier, which is what keeps that modifier meaningful late in a run instead
of being a fixed flat bonus that matters less as combo grows.

A forgiven miss halves `combo` (integer division, so it never fully wipes a streak the way it used
to) rather than zeroing it — see "Mistake forgiveness" below. Note that points no longer go
straight into `score` — see "Cash out: unbanked vs. banked score" immediately below, the mechanic
that changed this.

## Cash out: unbanked vs. banked score

Full design writeup, formula, and rationale: [scoring-escalation.md](scoring-escalation.md). Short
version, since it changes this file's ground truth: every hit's `points` accumulate into
`unbanked_points`, not `score`. `score` (the number shown as "Score: N" and the value
`_register_best()`/the Best Score unlock ladder read) only increases when the player taps the
**Cash Out** button, which is visible and enabled throughout a run whenever it's the player's turn.
Cashing out adds `unbanked_points` plus a bonus that scales quadratically with how long the current
streak has run (`_cash_out_streak_bonus()`) into `score`, zeroes `unbanked_points`, and resets the
streak (sequence truncated to 0 notes for Normal/Chaos, so the next round starts at exactly 1 note;
`duet_wave_round` zeroed for Duet). Combo, `combo_growth`, and all modifier state persist through a
cash-out untouched.

This means `score` can now sit flat for an entire streak and jump on cash-out — deliberate, and the
reason a miss can cost something beyond the combo reset described below.

## Gold steps

`_roll_gold_indices()` picks `golden_step_count` random indices in the current sequence to be
worth 3x. It re-rolls fresh positions every round rather than fixing them once, so Golden Step
stays a per-round tension point ("which of *this* round's steps is gold?") instead of becoming
predictable after round 1.

## Modifiers: every-3rd-round, stacking, permanent for the run

Every `MODIFIER_ROUND_INTERVAL` (3) rounds, `_offer_modifier_choice()` presents 3 random
modifiers (from a pool of 5) and blocks on a signal (`_modifier_picked`) until the player taps
one. Chosen modifiers apply immediately and **persist for the rest of the run** — they're not
per-round buffs. `modifier_stacks` tracks how many times each has been picked, and several
modifiers are explicitly designed to compound rather than cap at 1:

- **Sharper Ear** — `combo_growth += 0.05` each pick (additive, stacks cleanly)
- **Safety Net** — `mistake_charges += 1` each pick (literally a charge counter)
- **Steady Hands** — `sequence_speed_multiplier *= 1.15` (multiplicative — 3 picks is a real
  slowdown, not a diminishing one)

This stacking is why `GAME_DESIGN.md` §3.2 calls out that modifier cards need a visible stacking
indicator — the mechanic already lets you stack, so the UI needs to say so, or repeat picks look
like duplicates/mistakes rather than intentional reinforcement.

## Mistake forgiveness

A wrong pad press only ends the run if `mistake_charges <= 0`. Otherwise a charge is consumed
(see the `else` branch of `_on_pad_pressed`), `combo` is halved (not zeroed - a genuine but
softened cost, not "nothing happened"), and the correct pad is flashed once (`_flash_miss_hint`)
before input returns to the player - a blind retry only helps when the miss was a fumble, not a
forgotten note, so the hint is what makes the forgiveness actually usable rather than just
theoretical. This is the mechanism that makes Safety Net stacking meaningful: multiple charges
silently absorb multiple future mistakes across the rest of the run, in the order they happen,
each one costing half your current combo rather than the whole thing.

**Forgiveness now protects points, not just the run.** Since cash-out (above) introduced a real
at-risk pool (`unbanked_points`), a direct design call was made: *"protection from misses should
also provide protection for points, otherwise what's the point?"* The forgiveness branch never
touched score before `unbanked_points` existed, and it still doesn't — so a forgiven miss leaves
the entire current streak's unbanked value untouched, with no extra code needed to make that true.
Only a true run-ending miss (no charges left) forfeits it, and only because it was never in `score`
to begin with — `_game_over`'s `final_score` reads `score` (banked-only). Safety Net and its future
Defense-category siblings (`modifier-expansion.md`) are meaningfully more valuable under this
mechanic than they were when score was never at risk from any miss.
