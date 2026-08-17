# Cash-out Economy v2 / Big Numbers — Design Doc

**Status: design approved, numbers unplaytested.** Supersedes this doc's own prior version entirely — see
"What changed from the original proposal" below. `scoring-escalation.md` and
`scoring-and-modifiers.md` remain accurate for the *shipped* system until this is approved and
built.

## Why this doc exists

Two problems, from the same conversation:

1. **"There's no reason to press Cash Out."** Even after hearts and the piecewise cash-out formula,
   there's a real gap between "why stop right now" (rare — hearts absorb most failure) and "why stop
   eventually" (true, but not felt moment to moment).
2. **"Scores never get big the way Balatro's do."** Balatro's numbers come from stacking
   *multiplicative* sources (two ×3 jokers make ×9, not ×6); this game's scoring is deliberately
   additive/linear (`combo_growth` is explicitly linear "so scores don't blow past the Best Score
   unlock thresholds" — a real anti-Balatro design call already on record), and the one-modifier-
   per-category slot system caps how many multiplicative sources can ever stack at once.

## What changed from the original proposal

The original version of this doc (Part 1) proposed replacing voluntary Cash Out with **auto-banking
Round Goals** — a known target sequence length per round, banked automatically on clear, no button.
A later design session explored this in real depth (independently, as the "fully-automatic
bank-on-every-complete-sequence ante loop") and **rejected it**: it deletes the "continue or stop"
decision entirely rather than answering it, which is the one thing Cash Out exists for. **Cash Out
stays voluntary, with its own button, exactly as shipped.** Grand Finale therefore does *not* need
the rescope the original doc proposed either — "wager the accumulated pool" still makes sense once
there's still a pool.

What survives from the original doc: the core diagnosis (multiplicative stacking is why Balatro
scores get big; additive/linear is why this game's don't) and the instinct that the "why bank"
answer should come from *watching a number compound*, not from fear of loss. The mechanism below is
different — compounding lives inside the existing voluntary cash-out formula instead of a new
auto-bank system.

## Resolved design

- **Per-round payout compounds multiplicatively**, with two rates: gentle below the player's
  personal ceiling, steep at/past it. Clearing "one more round" is meant to feel like a real
  percentage jump each time, not a smooth curve.
- **A permanent, run-wide multiplier grows on every cash-out — but only from the portion of a streak
  past the ceiling.** Cashing out below the ceiling still always banks real points (no floor/gate on
  banking itself), but contributes nothing to the permanent multiplier. This closes a real exploit:
  without this restriction, a player could spam trivial 1-note cash-outs (risk-free) and compound a
  tiny bump into something enormous for free.
- **The ceiling is personal: `best_streak_this_run`**, not a fixed constant — the same "beat your own
  record" condition Fortissimo and the redesigned Safety Net already use. Self-scales to the actual
  player, and only ever rises, so it can't be kept artificially low to farm the permanent multiplier.
  Must be read *before* the current round updates it (same ordering Fortissimo already relies on), or
  `beyond` collapses to zero the instant a new record is set.
- **Bootstrap ceiling:** a run's first streak has no recorded `best_streak_this_run` (starts at 0).
  Resolved: use `max(best_streak_this_run, BOOTSTRAP_FLOOR)` with `BOOTSTRAP_FLOOR = 3`, so the first
  streak gets a brief calm ramp instead of sitting entirely in the steep zone.
- **Grand Finale keeps its current identity** (wager the accumulated pool) — unaffected, since Cash
  Out staying voluntary means the pool it wagers still exists.
- **Miss-recovery stays scoped as today** (single-note hint, no replay) — but the hint becomes
  **visual-only**: the hinted pad(s) glow without playing their tone. Applies to both the base
  single-note hint and Safety Net L5's extended further-ahead hint. This is a real behavior change:
  `_flash_miss_hint()` currently calls `pads_by_name[pad_name].flash(...)`, and `flash()`
  (`simon_button.gd`) plays `Sound.play_tone()` on every call — a silent variant (or a
  volume/play-tone flag) is needed specifically for miss hints.
- **Unlock ladder rebalance (500/1500/3000) stays explicitly deferred** until the new scoring shape
  has real playtime behind it — those thresholds will need a full rebalance once compounding ships,
  but not before.

## Concrete formula (proposed — needs your sign-off on the constants)

Reuses the existing `_cash_out_base_bonus(s)` function's signature and call sites
(`scripts/Main.gd`) — only the body changes, and it's still multiplied by the existing combo
multiplier and `score_bonus_percent` exactly as today.

```gdscript
const BOOTSTRAP_FLOOR := 3
const CASHOUT_BASE := 70.0
const GENTLE_RATE := 0.08   # +8% per round, below ceiling
const STEEP_RATE := 0.35    # +35% per round, past ceiling
const PERMANENT_GROWTH_PER_BEYOND := 0.05

func _cash_out_ceiling() -> int:
    return max(best_streak_this_run, BOOTSTRAP_FLOOR)

func _cash_out_base_bonus(s: int) -> float:
    var ceiling := _cash_out_ceiling()
    var capped := min(s, ceiling)
    var beyond := max(0, s - ceiling)
    return CASHOUT_BASE * pow(1.0 + GENTLE_RATE, capped) * pow(1.0 + STEEP_RATE, beyond) * permanent_mult

# On cash-out, before best_streak_this_run updates for this streak:
func _grow_permanent_mult(s: int) -> void:
    var beyond := max(0, s - _cash_out_ceiling())
    permanent_mult += float(beyond) * PERMANENT_GROWTH_PER_BEYOND
```

`permanent_mult` starts at `1.0` per run, persists across cash-outs (like combo/modifiers), and
applies multiplicatively to every future payout — including ones below the ceiling, since it
represents banked *past* risk, not a bonus tied to the current streak.

**Why these numbers, and how they compare to the shipped formula** (`CASHOUT_LINEAR_K = 16`,
`CASHOUT_QUADRATIC_K = 10`, ceiling anchored at `MEMORY_SPAN_CEILING = 8`):

| streak `s` | beyond ceiling(8) | shipped formula | proposed formula (permanent_mult=1) |
|---|---|---|---|
| 8 (at ceiling) | 0 | 128 | 130 |
| 12 | 4 | 352 | 430 |
| 16 | 8 | 896 | 1,148 |
| 20 | 12 | 1,760 | 4,277 |

`CASHOUT_BASE = 70` was picked so the two formulas roughly agree *at* the ceiling — parity there
means early/typical runs won't feel like they suddenly got a stealth buff — and diverge increasingly
past it, which is the whole point: pushing past your personal record should compound harder than the
old quadratic tail did. Past `s=20`, growth is intentionally steep (a 12-round push past ceiling is
already a ~33x multiplier from `STEEP_RATE` alone) — this is the "Balatro-big" territory the doc set
out to reach, but it's the part most likely to need retuning once it's actually played.

**Resolved on the numbers themselves** (2026-08-16 follow-up):

1. `GENTLE_RATE = 0.08` / `STEEP_RATE = 0.35` confirmed as proposed — the table above stands as the
   real target curve, not just an illustrative first pass.
2. `PERMANENT_GROWTH_PER_BEYOND = 0.05` grows `permanent_mult` **additively**
   (`permanent_mult += beyond * 0.05`), not multiplicatively — deliberately avoids a second layer of
   runaway exponential growth stacked on top of the already-exponential per-round formula.
3. **Crescendo stacking is intended, not an oversight.** `permanent_mult` (unconditional baseline,
   keyed off beating your own record) and Crescendo L5 (opt-in modifier, keyed off cash-out count)
   are different signals and are meant to compound together — a build that lands both is meant to
   feel like a jackpot combo.
4. `permanent_mult` grows **unbounded** for the life of a run, matching Balatro's own unbounded
   joker scaling — hearts and miss-risk already bound how long a run can realistically run, so no
   separate soft ceiling/decay is needed on the multiplier itself.

## What this doesn't touch

- Cash Out button, `unbanked_points`/`score` two-pool split, hearts, the modifier slot system, Duet's
  `duet_wave_round` — all unaffected, exactly as `scoring-and-modifiers.md` and
  `scoring-escalation.md` already describe them.
- Musical chunking (motif generation, the subtle repeat-cue, Harmonic Chain/Breath Mark/Motif Bonus)
  — independent work, not part of this pass. If it ships, the doc's original notes on it (subtlety
  bar, Chaos Mode's pad-identity gotcha) still apply unchanged; not repeated here since nothing about
  them changed.

## Open items for implementation

- All design questions are resolved; remaining work is implementation and playtesting the constants
  above (`CASHOUT_BASE`, `GENTLE_RATE`, `STEEP_RATE`, `PERMANENT_GROWTH_PER_BEYOND`,
  `BOOTSTRAP_FLOOR`) at real long-run lengths — expect these to move after real play.
- Unlock ladder rebalance (500/1500/3000) — deferred, own pass, after this ships and has playtime.
- Miss-hint silence needs a `flash()` variant/param that skips `Sound.play_tone()` — small, isolated
  change, not blocked on anything else here.
