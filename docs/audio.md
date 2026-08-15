# Audio

Everything audible is synthesized at runtime in `sound.gd` via `AudioStreamGenerator` — no audio
files, no imported assets. This keeps the whole game's footprint tiny and every sound trivially
re-tunable (a scale change just means computing new frequencies, not swapping asset files).

## Harmonic synthesis is the sonic signature

`_generate_harmonic(freq, duration, volume, decay_rate)` is the one function nearly every sound
in the game routes through (pad tones, the fail tone, Music Mode notes). It sums a fundamental
plus odd harmonics (3rd/5th/7th, decreasing amplitude) with an exponential decay envelope:

```gdscript
const HARMONICS := [[1.0, 0.61], [3.0, 0.21], [5.0, 0.11], [7.0, 0.06]]
```

Odd harmonics (not the full harmonic series) approximate a real steel tongue's bright, bell-like
timbre — this is the deliberate "sonic signature" `GAME_DESIGN.md` §2 says any new audio should
keep, which is why Music Mode reuses `play_tone` rather than introducing a new synthesis voice.

Two small realism details layered on top, both kept subtle by design (comments in the code call
this out explicitly):
- **Inharmonicity** (`INHARMONICITY_B`) — real plate/bar resonators aren't a perfect harmonic
  series; higher partials run slightly sharp. Stretching partial `n` by `sqrt(1 + B*n^2)` with a
  very small `B` adds "a touch of realism without reading as tinny/out-of-tune."
- **Strike noise** — a short, heavily-lowpassed filtered-noise burst under the attack, standing
  in for the transient thump of a mallet hitting metal.

## Buses: Tones / Ambient / UI / Master

Four `AudioServer` buses exist so the mix panel (`GAME_DESIGN.md` §2.4) can let a player turn
down, say, the ambient bed without silencing pad tones or UI clicks. `_setup_buses()` creates
them idempotently on ready (checks `get_bus_index` first) since Godot buses aren't declared
statically in code elsewhere.

## The ambient layer is scale-reactive, not per-round

`set_ambient_root(freq)` re-tunes three low drone layers (two octaves down, one octave down, an
octave-down fifth below the root) whenever the *scale* changes. It deliberately does **not**
retune on Chaos Mode's per-round pad reshuffle — the drone tracks musical key, not pad layout, so
Chaos Mode's chaos stays visual/positional without also destabilizing the audio bed under it.
Retuning is a glide (`AMBIENT_GLIDE`), not a hard restart, so scale changes don't pop.

## Why `play_tone`/`flash` gained optional `decay_rate`/`volume` params

Originally `play_tone(freq, duration, volume)` always used a fixed `decay_rate = 3.2`, and
`SimonButton.flash()` always called `Sound.play_tone(tone_freq)` with no override — fine when
notes play one at a time, ~0.5-1s apart, as in Normal/Chaos sequence playback. Music Mode plays
notes far closer together (~150ms), and at that density a ~1.4s audible tail means many notes are
still decaying simultaneously — a wash, not a rhythm. `decay_rate` and `volume` became optional
parameters (defaulting to the original values, so every existing call site is unaffected) so
Music Mode can request a much faster, quieter, more percussive envelope without a second
synthesis path. See [music-mode.md](music-mode.md#note-envelope) for the reasoning and sources
behind the specific numbers chosen.
