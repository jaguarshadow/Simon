# Architecture

## File layout

```
project.godot          Godot 4 project config, autoloads Sound as a singleton
scenes/Main.tscn        the single scene: UI chrome, panels; pads are NOT hand-placed here
scripts/Main.gd         all game logic - rounds, scoring, modes, scales/palettes, save/load
scripts/simon_button.gd SimonButton: one pad's own press/flash/skin behavior
scripts/sound.gd        Sound singleton: procedural synthesis, buses, ambient layer
shaders/*.gdshader      animated pad skins and shared flat-palette shimmer
docs/                   this folder
```

Almost everything lives in `Main.gd`. That's a deliberate tradeoff, not an oversight: this is a
small, single-scene game where most systems (scoring, modes, scales, unlocks) all need to touch
each other on every round. Splitting it into many small scripts would mean more cross-script
signal plumbing for very little isolation benefit at this size. The two things that *did* get
split out — `SimonButton` (self-contained per-pad visual/audio behavior) and `Sound` (a
genuinely independent subsystem, autoloaded so anything can call `Sound.play_tone(...)` without
a reference) — are split because they're reused identically by many callers and have no
game-rule knowledge of their own.

## Pads are built in code, not placed in the scene

`_build_pads()` in `Main.gd` constructs all 8 `SimonButton` nodes at runtime, positioning them
with polar coordinates around `RING_CENTER`:

```gdscript
var angle_deg := -90.0 + i * (360.0 / PAD_COUNT)
var dir := Vector2(cos(deg_to_rad(angle_deg)), sin(deg_to_rad(angle_deg)))
var slot_position := RING_CENTER + dir * BASE_RADIUS - Vector2(PAD_WIDTH / 2.0, 0.0)
```

This is what makes two other systems possible without rebuilding the scene tree:

- **Chaos Mode's reshuffle** (`_reshuffle_pad_positions`) — just shuffles which pad node sits in
  which precomputed slot, and re-tweens position/rotation. If pads were scene nodes, "reshuffle
  positions" would mean either 8 hand-authored alternate layouts or runtime scene surgery.
- **Live scale/palette switching** — changing scale in Settings mid-play just re-tunes and
  re-colors the existing 8 nodes (`_apply_scale_and_palette`); nothing is destroyed/recreated.

## Two separate identity systems for a pad

There are two different orderings of the 8 pads, and conflating them is the easiest way to
introduce a bug in this codebase:

- **`pad_names`** — the fixed identity order pads were built in (`pad_0`..`pad_7`). Scale tuning
  is indexed against this: `pads_by_name[pad_names[i]].tone_freq = scale["tones"][ring_order[i]]`.
  This order **never changes**, even in Chaos Mode.
- **`pad_slot_order`** — which pad currently sits in which *visual ring slot*. This is what Chaos
  Mode shuffles. It only affects `.position`/`.rotation`, never tuning.

A pad's note is therefore always determined by its `pad_names` index, never by where it's
currently sitting on the ring. This is why Chaos Mode can reshuffle pad *positions* every round
without needing to also reshuffle or recompute tuning — the two are orthogonal by construction.

## Boolean mode flags, not an enum

Modes are `chaos_mode`, `zen_mode`, `music_mode` — independent booleans, not a single `enum Mode`.
This works because exactly one is ever true at a time by construction (each mode's entry point
turns its own flag on and leaves the others alone, and menu buttons are disabled/hidden during a
run so you can't reach a second entry point). An enum would centralize that invariant, but at
three modes the boolean-per-mode style keeps each mode's guard clauses (`if zen_mode: return`,
`if music_mode: return`) local and readable at the call site, which is where they're actually
needed. If a fourth or fifth mode ever needs *combinations* (not just mutual exclusion), that's
the point to switch to an enum or state machine — the flags don't scale past "one of N."

## `randomize()` is called once, in `_ready()`

Godot's global random functions (`randi()`, `randf()`, `Array.shuffle()`, etc. - used throughout
for Chaos reshuffles, gold steps, modifier offers, and the Normal/Music/Duet melodic walks) default
to a **fixed seed** unless `randomize()` is called explicitly. This was missing for a while, which
meant every fresh launch replayed the identical "random" sequence from the first RNG call onward -
invisible in most modes (continuous/varied-feeling playback still looks random within one session)
but glaring in Normal Mode, which replays its entire accumulated sequence from the start every
round, so the same first few notes showed up on every fresh launch. Called once, first thing, in
`Main._ready()` - not per-mode-entry, since it only needs to happen once per process lifetime.

## The cross-fade mode-switch pattern

`_cross_fade_mode_switch(apply_state: Callable)` is a small helper every mode-entry/exit function
uses: fade the screen to near-black, call an arbitrary `Callable` that swaps all the UI
visibility/state, then fade back in. This exists because every mode transition was originally a
hard `.visible = true/false` snap (see `GAME_DESIGN.md` §1.3) — wrapping the *state swap* in a
`Callable` rather than duplicating the fade logic per-mode means adding a new mode's entry/exit
(Music Mode's `_on_music_button_pressed`/`_on_exit_music_pressed`) was a copy of the Zen version
with different visibility targets, not a new transition system.
