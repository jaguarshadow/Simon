# Audio

Everything audible is synthesized at runtime in `sound.gd` via `AudioStreamGenerator` — no audio
files, no imported assets. This keeps the whole game's footprint tiny and every sound trivially
re-tunable (a scale change just means computing new frequencies, not swapping asset files).

## Harmonic synthesis is the sonic signature

`_generate_harmonic(freq, duration, volume, decay_rate)` is the function nearly every sound in
the game routes through (pad tones, the fail tone, Music Mode notes) — the one exception is
`play_ui_tick()`, which has its own short, separate inline synthesis loop rather than calling
`_generate_harmonic`, since UI clicks skip the strike-noise transient and use a fixed envelope.
`_generate_harmonic` sums a fundamental plus odd harmonics (3rd/5th/7th, decreasing amplitude)
with an exponential decay envelope:

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

## Buses: Tones / UI

Two `AudioServer` buses (`BUS_NAMES := ["Tones", "UI"]`), both routed to the engine's implicit
Master bus, exist so the mix panel can let a player turn down pad tones without silencing UI
clicks (or vice versa). `_setup_buses()` creates them idempotently on ready (checks
`get_bus_index` first) since Godot buses aren't declared statically in code elsewhere. An
earlier design considered a third, scale-reactive ambient drone bus/layer; it was never
implemented — `set_ambient_root()` doesn't exist in the code, and there's no drone anywhere in
`sound.gd`.

## Voice pool: overlap without hard-cutting, and its two failure modes

Up to `VOICE_POOL_SIZE` (4) notes can ring concurrently via a small round-robin pool of
`AudioStreamPlayer`s (a single shared player previously hard-cut every prior note, which killed
anything meant to overlap, like the glissando sweep). That overlap creates two problems the pool
alone doesn't solve, both fixed on the `Tones` bus/voice level rather than by reducing overlap:

- **Clipping**: Godot sums bus inputs linearly, so 4 overlapping full-volume notes can sum well
  past ±1.0. `_setup_buses()` attaches an `AudioEffectLimiter` to the `Tones` bus for exactly
  this case.
- **Voice-steal click**: the 5th+ concurrent note reuses (steals) the oldest pool slot. Calling
  `stop()` on a still-ringing voice hard-cut it mid-decay, producing an audible click — the same
  problem the pool exists to solve, reappearing one voice-count higher. `_fade_out_voice()` now
  ramps the stolen voice's `volume_db` down over `VOICE_STEAL_FADE_SEC` (8ms) before cutting it,
  short enough to be inaudible as latency but long enough to smooth the transition.

## Sample generation is chunked across frames, not real-time synthesis

`_generate_harmonic()` and `play_ui_tick()` used to compute their entire sample buffer (up to
~70,560 samples for a full-duration pad tone) in one uninterrupted loop — fast in absolute CPU
terms, but a real synchronous cost dumped into a single frame, worse on Web export/low-end
hardware. Generation now proceeds in `SYNTH_CHUNK_SAMPLES` (4096-sample, ~93ms of audio) chunks,
`await get_tree().process_frame`-ing between them. This is still much faster than real-time —
each chunk generates roughly 5-6x faster than it's consumed at 60fps, so the buffer stays
comfortably ahead of playback — the point is spreading the CPU cost across frames, not
synthesizing audio live. If a chunked note's voice gets stolen mid-generation (see above),
`_voice_is_current()` detects the buffer is no longer the player's active one and the generator
bails out rather than wastefully finishing a buffer nobody will hear. `push_frame()`'s return
value is also checked now; a full generator buffer logs a warning and stops instead of silently
continuing.

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
