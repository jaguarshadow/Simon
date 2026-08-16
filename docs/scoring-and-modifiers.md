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
cash-out untouched. Streak length for the bonus is the last **earned** length (`_current_wave_length()`):
the queued next round is not counted until the player lands a hit on it, so the Cash Out total
cannot jump before a turn has been taken.

This means `score` can now sit flat for an entire streak and jump on cash-out — deliberate, and the
reason a miss can cost something beyond the combo reset described below.

## Gold steps

`_roll_gold_indices()` picks `golden_step_count` random indices in the current sequence to be
worth 3x. It re-rolls fresh positions every round rather than fixing them once, so Golden Step
stays a per-round tension point ("which of *this* round's steps is gold?") instead of becoming
predictable after round 1.

## Modifiers: slot system, 24-strong roster, 1→5 leveling

**Superseded the free-stacking 5-modifier pool described in earlier revisions of this doc.** Full
roster, per-modifier rationale, and leveling curves: `docs/modifier-expansion.md`. Short version of
what's actually live in `Main.gd`:

Every `MODIFIER_ROUND_INTERVAL` (3) rounds, `_offer_modifier_choice()` presents 3 random modifiers
drawn from all 24 (power modifiers only appear once their milestone is met; anything already at
level 5 stops appearing) and blocks on a signal (`_modifier_picked`) until the player taps one.
Modifiers are grouped into four categories (Dynamics, Grace, Tempo, Ornament) with **one
equipped modifier per category at a time** (`equipped_modifiers`):

- Picking the modifier **already equipped** in its category's slot levels it up (1→5, capped) —
  `_apply_modifier_pick`.
- Picking a **different** modifier into a filled slot pauses on a real swap-or-skip confirmation
  (`_show_swap_or_skip_dialog`, built at runtime, no `.tscn` changes) rather than silently
  replacing or stacking.
- Swapping a modifier out doesn't reset its level/charges — they go dormant, not lost, so
  re-drafting it later in the same run resumes where it left off.

Non-consumable per-level stats (combo-growth bonus, score-bonus percent, golden step count,
playback-speed multiplier, etc.) are recomputed fresh from equip/level state on every change via
`_recompute_pure_modifier_stats()`. Consumable resources (Safety Net/Echo Chamber charges, Second
Wind uses) are granted incrementally on level-up instead (`_grant_resource_on_levelup`) so already
spent charges never come back from a recompute. Exhausting a charge pool does **not** unequip the
modifier — the slot stays filled at 0, and the next miss that needs a charge is fatal (same as
having no Defense). Restock is a later level-up (or, for Second Wind, a qualifying cash-out; see
below). A runtime-built Loadout HUD (`_build_loadout_hud`, top-left, hidden on the menu and during
overlays) shows all four slots, each colored by category so a draft card's border matches the slot
it would replace.

## Mistake forgiveness

A wrong pad press routes through `_resolve_defense_on_miss()`, which checks whichever single
Defense modifier is currently equipped (only one can be, per the slot system above) and returns
one of three outcomes: `"forgiven_hint"` (Safety Net charges, Unbreakable's per-streak free misses,
or a lucky Muffled Strike roll), `"forced_cashout"` (Second Wind: the run continues, hit points
bank, the streak resets — not a full voluntary cash-out), or `"game_over"` (no Defense modifier
equipped, or its resource is exhausted). `combo` is halved (not zeroed) on any forgiven outcome
**and** on a Second Wind save, and the
correct pad is flashed once (`_flash_miss_hint`, showing further-ahead notes too at Safety Net
L5) before input returns to the player — a blind retry only helps when the miss was a fumble, not
a forgotten note, so the hint is what makes the forgiveness actually usable rather than just
theoretical. Double Down's flagged gamble step and Grand Finale's Double-or-Nothing round (a wager
on completing the rest of the round in progress, not a single note — see `modifier-expansion.md`)
are deliberately routed *around* this function entirely — their misses are self-contained wagers,
not normal sequence misses, and never consume a Defense resource.

**Forgiveness protects points, not just the run.** Since cash-out (above) introduced a real
at-risk pool (`unbanked_points`), a direct design call was made: *"protection from misses should
also provide protection for points, otherwise what's the point?"* The forgiveness branch never
touches score — so any `"forgiven_hint"` outcome leaves the entire current streak's unbanked value
untouched, with no extra code needed to make that true (this is also why Muffled Strike's
documented "L5 also protects points" doesn't need special-case code — it was already universally
true of every forgiven outcome; see `docs/modifier-expansion.md`'s implementation note on that
entry). Only a true `"game_over"` outcome forfeits the unbanked pool, and only because it was never
in `score` to begin with — `_game_over`'s `final_score` reads `score` (banked-only).
