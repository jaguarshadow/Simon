# Scales, Palettes & Themes

Three independent unlock tracks, all defined as data arrays (`GameData.SCALES`,
`GameData.PALETTES`, `GameData.THEMES` in `scripts/game_data.gd`), and all unlocked the same
generic way:

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
`GameData.THEMES` array comment says otherwise:

> Every theme carries its pad look directly as `pad_style`, so Theme is the only axis the player
> chooses in Settings — there's no separate Palette picker to fall out of sync with it.

This is a deliberate simplification made during implementation: letting Theme and Palette vary
fully independently means `9 themes x 10 palettes` combinations to visually sanity-check, several
of which (e.g. an animated shader palette under a theme also using a full-screen shader) fight
each other. Folding palette choice into each theme's `pad_style` cuts that down to one coherent,
curated look per theme, at the cost of losing free recombination. `GameData.PALETTES` still exists as a
standalone array (used by the legacy/flat palette rendering path), but the *player-facing*
picker is themes-only.

## Scales are sourced from the real Hapi Drum product line (plus 6 further-afield additions)

The original 11 scales' note/frequency data is sourced from [Hapi Drum's own scale page](https://hapidrum.co/hapi-drum-scale.aspx)
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

A second wave of 6 scales was added alongside Music Mode's Style presets (see
[music-mode.md](music-mode.md#style-presets) for the full research writeup) - these reach beyond
Hapi's product line into other real, documented scales/modes, since the styles they pair well
with (Reggae, Middle Eastern, Balkan/Gypsy, Japanese/Eastern, jazz/impressionist) needed tunings
Hapi doesn't offer. Same policy as before - real, sourced scales, not invented ones:

| id | Name | Sourced from |
|---|---|---|
| `d_dorian` | D Dorian | Derived from `d_minor` (natural minor's flat 6th swapped for Dorian's natural 6th) |
| `blues_hexatonic` | A Blues | Minor pentatonic + the "blue" flat-5, the standard blues hexatonic |
| `d_hijaz` | D Hijaz | Middle Eastern/Arabic maqam family; also a real, common handpan scale name |
| `hungarian_minor` | E Hungarian Minor | Balkan/Klezmer/Gypsy-jazz tradition |
| `insen` | C Insen | Japanese shakuhachi tradition |
| `whole_tone` | C Whole Tone | Impressionist (Debussy) / jazz-over-augmented-chord |

Unlock thresholds continue the existing round/score/combo curve rather than starting a new one.

## `ring_order`: the physical zigzag layout, one fixed pattern for every scale

Each scale entry has a `tones` array (frequencies, index = scale degree 0-7) and a `ring_order`
array (which degree sits at which *visual ring position*). `_apply_scale_and_palette()` uses it
as:

```gdscript
var degree: int = ring_order[i]          # ring slot i holds this scale degree
pad.tone_freq = scale["tones"][degree]
```

**This used to be computed per scale** via a brute-force dissonance-minimization search (score
every adjacent degree pair by interval-class dissonance, search all 5040 rotations fixing degree
0 at ring position 0, keep the lowest-scoring arrangement) - the reasoning being that ascending
scale-degrees shouldn't sit physically adjacent, so an accidental miss on a neighboring pad reads
as clearly wrong rather than a near-miss a half-step off.

Researching how real handpans/steel tongue drums are actually laid out (Hapi Drum's own site,
handpan builder guides - see [music-mode.md](music-mode.md#style-presets) sources) found they use
a **fixed, scale-independent** pattern: tone fields are numbered in ascending pitch order but
placed physically alternating sides of the ring as you go - the "zipper"/zigzag layout, the same
structural pattern regardless of which scale/tuning is on the instrument. That's now
`GameData.HANDPAN_RING_ORDER := [0, 2, 4, 6, 7, 5, 3, 1]`, walking clockwise from the tonic,
shared by every scale entry (`ring_order` in each `SCALES` dict just points at this one constant
array rather than holding its own computed permutation - safe to share since nothing in
`Main.gd`/`sequence_generator.gd` ever mutates a `ring_order` array, only reads/searches it).

This is a genuine behavior change from the old per-scale computation, not just a naming cleanup -
switching to it changed the physical pad layout on scales that had already shipped, not only the
6 new ones. It turns out not to sacrifice the original goal, though: the zigzag naturally keeps
physical ring-neighbors 2 scale-degrees apart, so an accidental miss still reads as clearly wrong
rather than a near-miss - except at exactly one seam, where the pattern wraps back to the tonic
(ring positions 7→0, scale degrees 1→0, which *are* a step apart). Real handpans have that same
seam; it isn't a regression introduced by simplifying to one shared pattern.

This same `ring_order` is what Music Mode uses in reverse (`ring_order.find(degree)`) to find
which physical pad to light for a given scale-degree note — see
[music-mode.md](music-mode.md#retuning-for-free).

## Non-pentatonic scales get special handling in Music Mode

Scales that contain a half-step or tritone get a smaller max melodic leap in Music Mode's random
walk (`MUSIC_NARROW_LEAP_SCALES` in `Main.gd`: `d_minor`, `c_major_diatonic`, `chromatic_run`,
plus `d_dorian`, `d_hijaz`, `hungarian_minor`, and `whole_tone` from the second scale wave) as a
cheap mitigation, rather than building a full harmonic-dissonance model. The rest (the original
pentatonic/Akebono scales, plus `blues_hexatonic`/`insen` from the second wave) are treated as
dissonance-safe by the same reasoning `music-mode.md` documents for the original pentatonic set.
