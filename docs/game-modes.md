# Game Modes

Five modes, each entered via its own button and exited back to the same menu. See
[architecture.md](architecture.md) for the shared boolean-flag/cross-fade mechanics.

## Normal

The baseline loop: `_next_round()` appends one random pad to `sequence`, plays it back
(`_play_sequence`), then waits for the player to repeat it via `_on_pad_pressed`. A correct
final hit chains into the next round; a wrong hit ends the run (`_game_over`) unless a heart
remains (`hearts > 0`, starting at `RUN_START_HEARTS`) or a defense modifier (Safety Net,
Muffled Strike, Unbreakable, Grounding Resonance) forgives it - see
[scoring-and-modifiers.md](scoring-and-modifiers.md).

## Chaos Mode

Same rules as Normal, plus two changes, both gated on `chaos_mode`:
- `_reshuffle_pad_positions()` runs every round — pads keep their tuning (see
  [architecture.md](architecture.md#two-separate-identity-systems-for-a-pad)) but move to new
  ring slots, forcing the player to find pads by color/note rather than muscle memory.
- Playback speeds up with round count, floored at `0.5` (never faster than 2x) because an uncapped
  ramp eventually turns "challenging" into "physically can't react in time," which is a difficulty
  cliff, not difficulty. The ramp itself now inflects at `MEMORY_SPAN_CEILING` (a real natural
  visual-sequence memory span, ~8 items, not a by-feel number) instead of climbing at one flat rate
  the whole way: gentle before it (still "normal" memory territory), steeper past it (the same real
  cliff the cash-out bonus formula is built around — see the cash-out formula section of
  [scoring-escalation.md](scoring-escalation.md)), reaching the floor a little sooner than the old
  flat ramp did.

## Zen Mode

No sequence, no score, no fail state — `_on_pad_pressed` returns immediately when `zen_mode` is
true, and pads are left permanently enabled instead of being toggled per-round. This is the
simplest mode by design: it's explicitly *not* a challenge, it's open-ended noodling, so it has
no state machine of its own beyond "pads are live."

## Music Mode

An auto-playing "idle/demo" mode — pads light themselves up in a generated, self-similar musical
phrase, no player input required. Scoped and implemented as a deliberate exception to
`GAME_DESIGN.md`'s "no new game modes" boundary (that boundary was written for the *polish pass*,
before Music Mode was scoped as a separate, additive feature). Full writeup, including the
research behind its rhythm/melody design: [music-mode.md](music-mode.md).

Structurally it follows the Zen pattern (no score/round UI, pads-and-tone only) but drives pads
itself via `_music_loop()` instead of waiting on `_on_pad_pressed`, which is why pads are left
*disabled* in Music Mode (`_set_pads_disabled(true)` in `_on_music_button_pressed`) — unlike Zen,
there's nothing meaningful for a stray tap to do, since there's no free-play concept here, only
playback.

## Duet Mode

A call-and-response mode: the game plays a musical phrase (reusing Music Mode's Euclidean-rhythm
+ melody-walk generators, see [music-mode.md](music-mode.md)), then the player answers by
pressing the same pads in the same order - like Normal Mode's positional matching - but timed
against the call's actual rhythmic schedule.

Two things deliberately differ from Normal Mode:

- **Not cumulative.** Each round is a fresh single-bar phrase (`_generate_duet_phrase()`), not a
  growing memorized sequence - Duet's challenge is precision within a phrase, not memory span
  (that's Normal Mode's job). Since phrase length no longer tracks round number, round counting,
  every-3rd-round modifiers, and best-round unlocks all go through a `_current_round()` helper
  instead of assuming `sequence.size()` means "round reached" (see
  [architecture.md](architecture.md)).
- **Timing affects score, not just pass/fail.** Note *identity* still gates success exactly like
  Normal Mode (wrong pad, or no press within a generous flat grace window, behaves like a miss -
  forgiven by Safety Net charges or ends the run). Timing *accuracy* only scales the points a
  correct hit is worth (`_register_hit`'s `timing_multiplier`), and does so continuously rather
  than in tiers: 1.5x exactly on the beat, falling off smoothly to a 0.5x floor by 200ms off
  (`DUET_MULT_FALLOFF_SEC`), so a 20ms-off hit clearly outscores a 140ms-off one instead of both
  landing in the same bucket. Every correct press also pops a judgment word
  (`_duet_timing_judgment`: "Perfect!" within 60ms, "Good!" within 130ms, else "Early!"/"Late!"
  depending on which side of the beat it landed) - cosmetic labeling layered on the continuous
  score, not a second scoring system of its own. Deliberately never a
  fail condition of its own - sloppy timing costs points, not the run. A growing-circle gauge over
  the Resonator (`_on_duet_ring_draw`) shows the beat coming due before you press, and the ring
  flash afterward is colored along the same red -> yellow -> green gradient as the score falloff
  (`_duet_timing_color`), so the feedback reads as one continuous scale end to end.

Both difficulty knobs (notes per phrase, tempo) ramp with round count on a Chaos-style capped
curve rather than jumping straight to full density/speed - round 1 starts at 2-3 notes around
88-100 BPM; an early version skipped the ramp entirely and reused Music Mode's fixed 5-9 note
density from round 1, which played closer to "memorize 7 notes cold" than a call-and-response
warmup.

The ramp is driven by `duet_wave_round`, not `duet_round` — a distinction introduced by the
cash-out mechanic ([scoring-escalation.md](scoring-escalation.md)). `duet_round` increments every
round for the run's whole duration and still drives `MODIFIER_ROUND_INTERVAL`/best-round tracking
via `_current_round()`; `duet_wave_round` is a separate counter that resets to `0` whenever the
player taps Cash Out, so a cashed-out Duet run's phrase length/tempo restart at the easy end of the
ramp along with the rest of the streak, the same way Normal/Chaos's `sequence` gets truncated on a
cash-out.

## Why every mode reuses the same pad/tuning/palette machinery

None of the four modes have their own copy of pad construction, tuning, or coloring — they all
call into `_apply_scale_and_palette()` and the same `pads_by_name`/`SimonButton` instances built
once in `_build_pads()`. This is what makes "change scale while in Zen" or "Music Mode retunes
instantly on scale change" work for free (see `music-mode.md`'s retuning note) — there is no
per-mode tuning state to keep in sync, only one shared source of truth.
