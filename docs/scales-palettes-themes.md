# Scales, Palettes & Themes

Three independent unlock tracks, all defined as data arrays (`SCALES`, `PALETTES`, `THEMES`) in
`Main.gd`, and all unlocked the same generic way:

```gdscript
"unlock": {"type": "round" | "score" | "combo", "value": N}
```

`_meets_requirement()` checks a single entry against current best stats; `_check_new_unlocks()`
diffs *previous* run-start bests against *current* bests after every run so newly-crossed
thresholds get surfaced once, on the end-of-run summary, rather than interrupting play mid-run
(explicitly called out as "was too jarring" in the code comment). One generic unlock-requirement
shape for all three tracks means Settings' locked/unlocked grid rendering, the end-of-run
unlock-toast list, and the easter egg's "unlock everything" all work against a single check
function instead of three parallel systems.

## Why Theme subsumes Palette

`GAME_OVERVIEW.md` originally treated Palette (pad color) as its own axis. `GAME_DESIGN.md`
introduced Theme (whole-app mood) as a second, independent axis on top of it — but the current
`THEMES` array comment says otherwise:

> Every theme carries its pad look directly as `pad_style`, so Theme is the only axis the player
> chooses in Settings — there's no separate Palette picker to fall out of sync with it.

This is a deliberate simplification made during implementation: letting Theme and Palette vary
fully independently means `9 themes x 10 palettes` combinations to visually sanity-check, several
of which (e.g. an animated shader palette under a theme also using a full-screen shader) fight
each other. Folding palette choice into each theme's `pad_style` cuts that down to one coherent,
curated look per theme, at the cost of losing free recombination. `PALETTES` still exists as a
standalone array (used by the legacy/flat palette rendering path), but the *player-facing*
picker is themes-only.

## Scales are sourced from the real Hapi Drum product line

All 11 scales' note/frequency data is sourced from [Hapi Drum's own scale page](https://hapidrum.co/hapi-drum-scale.aspx)
where an equivalent exists, since this is a steel-tongue-drum game and Hapi is a real
manufacturer of the instrument - authenticity matters more than an arbitrary made-up tuning
would. Scale/frequency data is factual (equal-tempered pitch values, traditional scale patterns
like "Akebono" or "minor pentatonic"), not creative expression, so replicating a real
instrument's tuning is the same kind of thing a guitar-tuner app replicating standard tuning
does - no copyright concern. Three scales (D Minor Pentatonic, D Akebono, C Major Pentatonic)
were corrected from earlier, close-but-not-exact approximations once checked against Hapi's
actual page; G Major Pentatonic already matched exactly. Three genuinely new scales (A Minor
Pentatonic, A Akebono Pentatonic, E Major Pentatonic) were added as further unlock-progression
tiers (Round 25 / Score 3000 / Combo 25) beyond the existing milestones, rather than as free
defaults, to extend the existing curve instead of flattening it.

Each new/corrected scale's `ring_order` was recomputed with the same brute-force
dissonance-minimization method described in `TODO.md` (score every adjacent degree pair by
interval-class dissonance - unison lowest, tritone highest - and search all 5040 rotations fixing
degree 0 at ring position 0). Scales whose interval *pattern* didn't change (C Major Pentatonic
was only transposed up an octave) keep their existing `ring_order`, since dissonance between
scale degrees is transposition-invariant.

## `ring_order`: visual position vs. scale degree

Each scale entry has a `tones` array (frequencies, index = scale degree 0-7) and a `ring_order`
array (which degree sits at which *visual ring position*, e.g. `[0, 2, 7, 4, 1, 6, 3, 5]`).
`_apply_scale_and_palette()` uses it as:

```gdscript
var degree: int = ring_order[i]          # ring slot i holds this scale degree
pad.tone_freq = scale["tones"][degree]
```

Degrees aren't placed around the ring in ascending order (`0,1,2,...`) because that would put
adjacent scale steps next to each other physically, which makes accidental adjacent-pad mistakes
sound like *near-misses* (a half-step off) rather than clearly wrong notes — worse for a memory
game where the player should be able to tell "close in scale" apart from "close on the ring" by
ear. Scrambling degree-to-position (while keeping each scale's `ring_order` fixed per scale, not
random per session) keeps that physical/tonal separation consistent and learnable.

This same `ring_order` is what Music Mode uses in reverse (`ring_order.find(degree)`) to find
which physical pad to light for a given scale-degree note — see
[music-mode.md](music-mode.md#retuning-for-free).

## Non-pentatonic scales get special handling in Music Mode

Six of the eight scales are pentatonic, which — per the reasoning in `music-mode.md` — guarantees
no dissonant combination of scale degrees. The other two (`d_minor`, `c_major_diatonic`) plus
`chromatic_run` contain half-steps/tritones and get a smaller max melodic leap in Music Mode's
random walk (`MUSIC_NARROW_LEAP_SCALES` in `Main.gd`) as a cheap mitigation, rather than building
a full harmonic-dissonance model for three scales.
