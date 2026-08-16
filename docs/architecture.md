# Architecture

## File layout

```
project.godot              Godot 4 project config, autoloads Sound/GameData/SaveManager
scenes/Main.tscn            the single scene: UI chrome, panels; pads are NOT hand-placed here
scripts/Main.gd              round/scoring/mode orchestration, UI construction, input
scripts/game_data.gd         GameData singleton: modifiers/scales/palettes/themes/FAQ content
scripts/save_manager.gd      SaveManager singleton: generic JSON-dictionary file I/O
scripts/modifier_system.gd   ModifierSystem: draft/equip/level-up rules, per-level lookups
scripts/sequence_generator.gd SequenceGenerator: Euclidean rhythm + melodic-walk math
scripts/simon_button.gd      SimonButton: one pad's own press/flash/skin behavior
scripts/sound.gd             Sound singleton: procedural synthesis, voice pool, buses
shaders/*.gdshader           animated pad skins and shared flat-palette shimmer
addons/gut/                  GUT (Godot Unit Test) framework
test/unit/*.gd                the test suite - see "Testing" below
docs/                        this folder
```

Most of the game's *state* still lives in `Main.gd` - that's a deliberate tradeoff, not an
oversight, and it's worth being specific about why. `equipped_modifiers`/`modifier_levels`
alone are read or written at ~40 functions spanning the entire gameplay loop (hit registration,
cash-out, Duet response, hesitation-assist, heart management, streak resets); `sequence`,
`combo`, and the per-mode walk state (`_music_*`/`_normal_*`) are similarly threaded through
everything. Moving that ownership into separate objects would mean touching nearly every
gameplay function in the file, not isolating a subsystem - the coupling is real, not an
organizational accident.

What *did* get split out, and why each boundary was chosen where it was:

- **`GameData`** — pure content (the `MODIFIERS`/`SCALES`/`PALETTES`/`THEMES`/`ONBOARDING_STEPS`/
  `FAQ_ENTRIES` tables). Zero logic, zero coupling risk - moving it out just separates "what the
  game contains" from "how it runs."
- **`SaveManager`** — the generic "get a `Dictionary` to/from disk safely" mechanism (open,
  null-check, parse, validate). `Main.gd` still owns *which* fields exist in the save file and
  what they mean; `SaveManager` never sees a specific field name.
- **`ModifierSystem`** and **`SequenceGenerator`** — both **stateless** (every function is
  `static`). Rather than relocating `equipped_modifiers`/`modifier_levels` or the walk state
  (the high-risk move described above), these classes take that state as parameters and return
  results - `Main.gd` keeps ownership and calls through same-named wrapper methods
  (`_mod_val()`, `_euclidean_rhythm()`, etc.) so none of their ~120 existing call sites had to
  change. This is "extract behavior, not state": the *rules* (how a draft pool is built, how a
  walk step is biased) are now independently testable without a scene tree; the *state* they
  operate on stays exactly where the rest of the gameplay loop already expects to find it.
- **`SimonButton`** and **`Sound`** (pre-existing) — reused identically by many callers and have
  no game-rule knowledge of their own; `Sound` is autoloaded so anything can call
  `Sound.play_tone(...)` without a reference.

## Testing

`test/unit/*.gd` (GUT framework, `addons/gut/`) covers the pure logic extracted above -
`ModifierSystem`, `SequenceGenerator`, `SaveManager`, plus `Main.gd`'s own cash-out math and
requirement checks - by constructing a bare `Main.new()` (or calling the static classes
directly) without adding it to the scene tree, since none of the tested functions touch
`@onready` nodes. Run headless from the project root:
`godot --headless -s addons/gut/gut_cmdln.gd` (config in `.gutconfig.json`). UI-building,
animation/timing, and the audio-synthesis code are not covered - they're either hard to assert
on meaningfully or require a running scene tree.

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

Modes are `chaos_mode`, `zen_mode`, `music_mode`, `duet_mode` — independent booleans, not a
single `enum Mode`. This works because exactly one is ever true at a time by construction (each
mode's entry point turns its own flag on and leaves the others alone, and menu buttons are
disabled/hidden during a run so you can't reach a second entry point). An enum would centralize
that invariant, but at four modes the boolean-per-mode style keeps each mode's guard clauses
(`if zen_mode: return`, `if music_mode: return`) local and readable at the call site, which is
where they're actually needed. If a fifth or sixth mode ever needs *combinations* (not just
mutual exclusion), that's the point to switch to an enum or state machine — the flags don't
scale past "one of N."

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
