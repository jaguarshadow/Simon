# Simon — Steel Tongue Drum Edition

A memory-sequence game (in the tradition of the classic *Simon*) reimagined as
a steel tongue drum instrument. Built in Godot 4 (GDScript, no external
plugins or asset packs — audio and animated skins are generated entirely in
code/shaders at runtime).

## Core concept

Eight tongue-shaped pads are arranged radially around a steel resonator disc,
each tuned to a note in the active musical scale. The game plays a growing
sequence of pad flashes/tones; the player must repeat it back correctly to
advance to the next round. A wrong pad ends the run (unless a mistake-
forgiveness perk is active).

## Game modes

- **Normal** — the standard escalating memory challenge. Pads stay in a fixed
  layout.
- **Chaos Mode** — same rules, but all 8 pads reshuffle to new positions on
  the ring every round, and sequence playback speed ramps up as rounds climb
  (capped so it never becomes unplayable). Forces players to find pads by
  color/note rather than muscle memory.
- **Zen Mode** — no sequence, scoring, or fail state. All pads are freely
  playable at any time, for open-ended noodling. Scale/palette can still be
  changed while in Zen.

## Scoring & escalation

- Each correct hit builds a **combo streak**, which increases a score
  multiplier (a forgiven miss halves the combo rather than resetting it).
- Landing a hit spawns a floating "+N" score popup and a small particle burst
  at the exact click position, plus a light screen-shake. A miss triggers a
  softer shake and a gentle amber screen flash (deliberately mellow, not a
  harsh "fail" sting, to keep the game feeling calm).
- Every 3rd round, play pauses and offers a choice of 3 random **modifiers**, drawn from a
  24-strong roster across four categories (Dynamics, Grace, Tempo, Ornament) — **one
  equipped per category at a time**, Hades-style. Picking the modifier already in a slot levels it
  up (1→5); picking a different one prompts a swap-or-skip choice instead of silently replacing or
  stacking. Full roster and rationale: `docs/modifier-expansion.md`.

## Scales (tunings)

Each scale defines the 8 pad frequencies and note letters. Three pentatonic scales are unlocked
from the start (a deliberate choice - every default scale guarantees no dissonant combination, so
a brand-new player's first experience always matches the "no wrong notes" pitch); everything else,
including the three diatonic/chromatic scales that can produce dissonant intervals, unlocks via
play milestones instead of being handed out for free. Scale/frequency data for the 7 scales with a
real-world equivalent is sourced from [Hapi Drum's own scale page](https://hapidrum.co/hapi-drum-scale.aspx),
since this is a steel-tongue-drum game and Hapi is a real manufacturer of the instrument.

| Scale | Unlock condition |
|---|---|
| D Minor Pentatonic | — (default) |
| C Major Pentatonic | — |
| D Akebono | — |
| E Minor Pentatonic | Reach Round 5 |
| D Minor (Diatonic) | Reach Round 10 |
| G Major Pentatonic | Score 500 in a run |
| C Major Diatonic | Build a combo of 15 |
| Chromatic Run | Reach Round 15 |
| A Minor Pentatonic | Reach Round 25 |
| A Akebono Pentatonic | Score 3000 in a run |
| E Major Pentatonic | Build a combo of 25 |

## Color palettes / skins

Ten total — eight are flat HSV-based color schemes generated procedurally
per-pad; two are fully animated shader skins.

| Palette | Unlock condition | Notes |
|---|---|---|
| Anodized | — (default) | Full hue spread |
| Pastel Dream | — | Soft, low-saturation |
| Sunset | — | Warm hues only |
| Ocean Steel | — | Cool blues/teals |
| Monochrome Steel | Reach Round 5 | Near-grayscale |
| Neon | Score 500 | High saturation/value |
| Forest | Combo x15 | Greens |
| Royal | Reach Round 15 | Purple range |
| **Galaxy** | Reach Round 20 | Animated shader: domain-warped fbm nebula clouds + twinkling starfield, glow pulse on press |
| **Aurora** | Score 1500 | Animated shader: flowing green/teal/pink curtain rays over a starfield, glow pulse on press |

The two shader skins are written from scratch (`shaders/galaxy.gdshader`,
`shaders/aurora.gdshader`) using value noise + fractal Brownian motion (fbm)
with domain warping for organic movement — no textures or external assets.

## Progression & persistence

- Best score, best round reached, and best combo are tracked and saved to
  `user://simon_save.json`, persisting across sessions.
- The Settings panel shows current bests and greys out locked scales/
  palettes with their unlock requirement, so progress is always visible.
- A **Reset Progress** button clears all bests and re-locks everything.

## Easter egg

Typing **"hubert"** anywhere in the game permanently unlocks every scale and
palette (persisted), with a gold screen flash, light shake, an ascending
arpeggio through the current scale, and a toast confirmation.

## Audio

All sound is synthesized at runtime (`scripts/sound.gd`) via
`AudioStreamGenerator` — no audio files. Pad tones are a fundamental plus
odd-harmonic overtones (3rd/5th/7th) with an exponential decay envelope,
approximating a real steel tongue's bright, sustained timbre. The "miss"
sound is a low, soft tone rather than a harsh buzzer, in keeping with the
game's relaxed tone.

## Technical structure

```
project.godot          — Godot 4 project config, autoloads Sound singleton
scenes/Main.tscn        — the single game scene: UI, pad ring container,
                          modifier/settings panels
scripts/Main.gd         — all game logic: rounds, scoring, modifiers, modes,
                          scales/palettes, save/load, easter egg
scripts/simon_button.gd — SimonButton: per-pad behavior (tongue-shaped
                          stylebox, press/flash feedback, optional shader skin)
scripts/sound.gd        — Sound singleton: procedural tone/buzzer synthesis
shaders/galaxy.gdshader — animated nebula/starfield pad skin
shaders/aurora.gdshader — animated aurora curtain pad skin
```

Pads are built entirely in code (not hand-placed in the scene) using polar
coordinates around a ring center, which is what makes Chaos Mode's reshuffle
and live scale/palette switching possible without rebuilding the scene tree.
