# Round Goals & Compounding Scoring — Proposal

**Status: proposal, not implemented.** Written for stakeholder review — every decision below needs
a yes before any code changes. Supersedes nothing yet; `scoring-escalation.md` and
`modifier-expansion.md` remain accurate for the shipped system until/unless this is approved.

## Why this doc exists

Two problems surfaced in the same conversation, and they turned out to be more connected than they
looked at first:

1. **"There's no reason to press Cash Out."** Voluntary push-your-luck banking, even after the
   hearts/formula/ramp passes, still leaves a real gap between "why stop right now" (rare, since
   hearts absorb most failure) and "why stop eventually" (obviously true, but not felt moment to
   moment).
2. **"Scores never get big the way Balatro's do."** Balatro's numbers come from stacking multiple
   *multiplicative* sources at once (two ×3 jokers make ×9, not ×6); this game's scoring is
   deliberately additive/linear, and its one-modifier-per-category slot system structurally caps
   how many multiplicative sources can ever be active together.

The connecting insight: **if scoring compounds, the moment that compounding gets locked in becomes
the natural "why bank" answer on its own** — you're not banking out of fear, you're banking because
you just watched a number get big and you want to keep it. Fixing #2 well mostly fixes #1 for free.

## Part 1: Round Goals (replacing voluntary Cash Out)

### The change

Each round has a **known-in-advance target sequence length** (shown before the round starts, not
discovered by hitting it). Clearing the target **auto-banks** — no button, no floor, no "did I wait
too long" anxiety. A modifier draft (already happening every 3 rounds via
`MODIFIER_ROUND_INTERVAL`) becomes the between-rounds breather, the same beat Balatro's shop
occupies between blinds.

### Why this is the right call

This game already ran this experiment once and it failed — a climbing wave cap that forced a reset,
rejected specifically because it interrupted the player "at the exact moment they're most invested"
(`scoring-escalation.md`'s own history). It would be reasonable to assume this is the same idea
again. **It isn't, and the difference is the whole argument:** the old cap was an undiscovered
number the player only learned about by hitting it, on a sequence that was otherwise growing
forever with no destination. A round goal is a **visible finish line from the start** — the player
is working *toward* it, not being cut off by it. Reaching it reads as "I did it," the same way
clearing a Balatro blind does, not as being stopped. Same mechanical shape as the rejected design,
opposite psychological framing, because the one variable that mattered (was the target known in
advance) flipped.

It also directly answers the "why cash out" gap from Part 1 of the earlier research pass: there's no
gap to answer, because there's no moment where "should I stop" is even a question — the round has
an end, you're always playing toward it, and banking happens because you won, not because you chose
to.

### What this breaks, honestly

- **Cash Out button, `cash_out_floor`** — gone. There's no "whenever you feel like it" banking
  moment to gate.
- **Grand Finale** — its whole premise (wager a big accumulated pool) stops making sense once there
  is no big idle pool sitting around. Proposed replacement: wager *this round's* bank on clearing
  one extra note beyond the target, for a multiplier — same "double or nothing" identity, rescoped
  to a bounded stake instead of an open-ended one.
- **Second Wind's heart refill** — trigger moves from "on voluntary cash-out" to "on round-goal
  clear." Nearly a no-op change; the hook already lives right where the bank happens.
- **Milestone flags** (`five_cashouts`, `zero_miss_wave`) — `five_cashouts` becomes `five_round_
  clears`; `zero_miss_wave` is unaffected (already round-scoped).
- **Hearts** — unaffected, and still doing real work: a miss inside a round still costs a heart,
  still bounded per-run. Round goals bound the *upside* (how much you can lose in one failure);
  hearts bound the *downside* (how many failures the whole run survives). They're solving different
  problems and both stay.

### Concrete mechanics

- **Target length curve**, anchored to `MEMORY_SPAN_CEILING = 8` the same way the retired cash-out
  formula was: early rounds short and forgiving (target 3, 4, 5 — round 3 already lines up with the
  first modifier draft), climbing toward the real ceiling by round 6-8, and continuing to climb
  after it for players with a build that can handle it. Exact curve is a tuning pass, not a design
  decision — flagging the shape (gentle-then-real), not the constants.
- **Duet Mode** already has an analogous per-round-scoped quantity (`duet_wave_round` driving
  phrase length/tempo, reset on what's currently a cash-out) — round goals map onto it almost
  directly, less new work than it might look like.
- **Chaos Mode's reshuffle** and the **inflected speed ramp** (already keyed to
  `MEMORY_SPAN_CEILING`) are untouched — they still apply within a round exactly as now.

## Part 2: Compounding Scoring (the "big numbers" fix)

### The change

Stop treating every modifier's contribution as an independent addition to a shared pool. Introduce
**deliberate multiplicative compounding** in specific, chosen places, and make the round-goal clear
(Part 1) the moment that compounding pays off in one dramatic number — the equivalent of a Balatro
hand's score cascade, not spread thin across many small hits.

### Why this is the right call

The mechanism is well-documented and not a matter of taste: Balatro's score formula is `Chips ×
Mult`, and two ×3 Mult sources produce ×9 together, not ×6 — multiplicative stacking is
*combinatorially* bigger than additive stacking, and that gap is *why* Balatro run scores reach
into the billions while this game's scores sit in the low thousands by design. That's not an
accident either — `combo_growth` is explicitly linear "so scores don't blow past the Best Score
unlock thresholds," a deliberate anti-Balatro choice already on record. Wanting Balatro-scale
numbers means consciously reversing that specific call, not tuning a constant, and it's worth being
honest that this is a real design reversal before it's approved, not just a numbers buff.

What doesn't need to change: `_register_hit()`'s cascade of per-modifier "+N" popups already *is*
Balatro's per-joker reveal mechanism (the code comment says so directly) — the visual/psychological
device for "watch a number climb step by step" is already built. Only the math underneath it is too
small to be dramatic.

### Concrete mechanics

- **Extend the one compounding example that already exists.** Crescendo's L5 is already
  `pow(1 + per_wave, waves_completed)` — genuinely exponential, not a bigger flat number. Proposal:
  more of the Multiplier category's top levels adopt this shape instead of a flat percentage bump,
  so reaching a modifier's max level is a qualitative change in scoring shape, not just a bigger
  additive bonus.
- **Cross-category synergy** — a modifier that scales its own strength off *which other categories
  are equipped*, not just off game state. This is the actual Balatro-joker-synergy move, scoped to
  what a 4-slot system can realistically do: not "stack 5 xMult jokers" (there's no slot budget for
  that here), but "did you build a combination that compounds," which is a real deckbuilding
  decision distinct from "which single pick is individually strongest."
- **Concentrate the reveal at round-goal clear**, not every hit. A Balatro hand's score is the big
  number, not any single played card — round-goal clear is this game's equivalent unit, and Part 1
  already gives it a clean, guaranteed moment to happen in.

### What this breaks, honestly

- **The Best Score unlock ladder (500 / 1500 / 3000)** needs a full rebalance, not a tweak — those
  thresholds were sized for the current ceiling and would become trivial almost immediately once
  compounding is real, the same way Balatro's early antes are trivial once a run is geared up.
  This needs its own numbers pass once the scoring shape is settled, not before.
- **Any remaining "keep scores sane" assumptions** elsewhere in the codebase (worth an explicit
  audit once this is approved, not assumed clean) — the linear-combo-growth comment is the one
  that's already flagged; there may be others written against the same assumption.

## How the two parts fit together

Part 2 needs Part 1 more than the reverse: compounding scoring wants a clean, guaranteed "big
reveal" moment to pay off in, and round-goal clears are exactly that moment. Compounding could
technically be added on top of the current voluntary Cash Out instead, but it would inherit the same
felt-urgency gap Part 1 exists to fix — the payoff would still only land when the player *chose* to
claim it, which is the thing already established as the weak point. Recommended order: **Part 1
first**, Part 2 built to land inside the structure Part 1 creates.

## Open questions for the stakeholder

Each of these is a real fork, not a detail — flagging them explicitly rather than picking silently:

1. Does the round-goal shape (Part 1) match what you pictured, or is there a different structure in
   mind?
2. Grand Finale's rescoped "wager this round's bank for one extra note" replacement — right
   direction, or does that modifier need a completely different identity once there's no big idle
   pool to gamble?
3. How aggressive should compounding get — extend the Crescendo-style shape to a few more top
   levels, or go further (cross-category synergy) in the same pass?
4. Is a full unlock-ladder rebalance in scope now, or is it explicitly deferred to "once the new
   scoring shape has real playtime behind it"?
