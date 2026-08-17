# Music Mode

An idle/demo mode: pads light up and play themselves in a generated, pleasant-sounding phrase, no
player input required. This doc covers the generative system's design and the reasoning (and
research) behind its specific parameters. For how it fits into the mode system structurally, see
[game-modes.md](game-modes.md#music-mode).

## Why it was scoped as an exception

`GAME_DESIGN.md`'s explicit scope boundary excludes "new game modes." Music Mode is a new mode,
so it was deliberately scoped and approved as a standalone addition *before* implementation,
rather than folded into that polish pass — see the TODO checklist entry and the scoping
conversation that preceded this code. It reuses everything it can from existing systems (scales,
palettes/themes, the pad/tone machinery, the ambient layer) specifically so it stays a thin
addition rather than a second, parallel game.

## Two generators, recomputed every bar

**Rhythm** — `_euclidean_rhythm(pulses, steps)` implements Bjorklund's algorithm: distribute
`pulses` onsets as evenly as possible across a 16-step bar. This isn't an arbitrary choice of
"randomize note timing" — Euclidean rhythms are the mathematical structure behind many
real-world rhythms found across musical traditions (Cuban tresillo = E(3,8), Brazilian bossa nova
= E(5,16)), because "spread as evenly as possible" is close to what "good rhythm" tends to mean
across cultures ([Toussaint, *The Euclidean Algorithm Generates Traditional Musical Rhythms*](https://cgm.cs.mcgill.ca/~godfried/publications/banff.pdf)).
Pulse count is re-rolled each bar (5-9 of 16 steps) so bars don't feel mechanically identical.

**Melody** — `_generate_music_bar_melody()` walks scale degrees (0-7) one note per rhythm pulse.
Each step the walk is either a repeat (30%), a single scale-degree step (55%), or a leap of 2+
degrees (15%). Direction isn't a coin flip — see below.

## Why pentatonic scales make this safe

6 of the game's 8 scales are pentatonic. Pentatonic scales have no interval combination that
reads as dissonant, so the melody walk needs no harmonic filtering for those scales — any degree
sequence is safe. The 2 diatonic-ish scales (`d_minor`, `c_major_diatonic`) and `chromatic_run`
do contain half-steps/tritones, so those get a smaller max leap (`MUSIC_NARROW_MAX_LEAP = 3` vs.
`MUSIC_PENTATONIC_MAX_LEAP = 4`) as a cheap mitigation rather than a full harmony model — see
[scales-palettes-themes.md](scales-palettes-themes.md#non-pentatonic-scales-get-special-handling-in-music-mode).

## Melodic direction: step inertia + post-skip reversal

The first implementation reversed direction after 2 consecutive same-direction steps — an
arbitrary rule that didn't match how real melodies move and produced a walk that felt aimless.
It was replaced with two documented tendencies from music cognition research:

- **Step inertia** — a stepwise move tends to be followed by *another step in the same
  direction*, not a reversal
  ([Chiu & Temperley, "Melodic Differences Between Styles: Modeling Music With Step Inertia," 2024](https://journals.sagepub.com/doi/full/10.1177/20592043231225731)).
- **Post-skip reversal** ("gap fill") — after a *leap*, melodies tend to move back the other way,
  stepwise, as if filling in the gap the leap just opened
  (Narmour's implication-realization model; discussed in
  [Huron, *Sweet Anticipation*](https://www.marcus-pearce.com/assets/papers/huron06-review.pdf)).

`_music_next_delta()` implements exactly these two rules and nothing more elaborate (no explicit
arch-contour modeling) — the every-4-bar forced return to the tonic already gives phrases a
global shape, so local direction bias only needed to fix the *moment-to-moment* motion.

## Repeat probability decays with streak length

The walk's "repeat" outcome (30% chance to hold the same degree) can chain into runs by pure
independent chance. An early version fixed this with a hard cap (never more than 2 identical notes
in a row) - but that's not how real melodies behave (deliberate repeated-note runs of 3+ are
common, e.g. rhythmic emphasis, ostinatos) and produced a mechanical "always breaks at exactly 2"
tell. Replaced with a decaying probability instead: each additional consecutive repeat multiplies
the *next* repeat chance by `REPEAT_DECAY = 0.4` (30% -> 12% -> 4.8% -> ...), so short repeats stay
as likely as ever, occasional longer ones can still happen the way they would in a real phrase, and
runaway streaks become vanishingly rare without being flatly forbidden.

## Reflecting boundaries, not clamping

The walk originally used `clampi()` to keep degrees in `[0, 7]` - an out-of-range step just landed
on the edge value. Two problems, both variety-killers: (1) a blocked step reproduces the same note
as a no-op, and near an edge with step inertia biasing toward continuing the same direction, that
compounds into stuck-feeling runs; (2) a stopgap fix forced the *direction itself* deterministically
away from whichever edge the walk stood on when picking a fresh direction - which, combined with
every run/phrase starting at the tonic (degree 0, itself an edge), meant the opening of every Normal
Mode run had close to zero variety: same first note, near-deterministic second note.

The actual fix is reflection: an out-of-range step bounces back into range by the amount it
overshot, rather than clamping. This is the same "reflecting barrier" random-walk technique Xenakis
used for pitch generation in his own stochastic compositions (rather than an absorbing/sticking
barrier) - see
[iannis-xenakis.org on Random Walk](https://www.iannis-xenakis.org/en/random-walk/), and matches
the general finding in generative-melody literature that hard clipping "trap[s] values near the
boundaries, making for passages that sound unnatural" while mirror/bounce boundaries mitigate it
([Brown, Gifford & Davidson, "Techniques for Generative Melodies Inspired by Music Cognition,"
*Computer Music Journal* 39(1), 2015](https://direct.mit.edu/comj/article/39/1/11/94494/Techniques-for-Generative-Melodies-Inspired-by)).
`_reflect_degree()` implements this; direction-picking itself stays fully random (no forced
direction), and the existing "flip the stored direction after a bounce" logic now correctly tracks
the direction the walk actually reflected toward, not a blocked one.

## Note envelope

The initial version called `pad.flash()` with its default tone (decay_rate 3.2, ~1.4s audible
tail) — the same envelope used for Normal/Chaos sequence playback, where notes are ~0.5-1s apart.
Music Mode's notes are ~150ms apart, so multiple notes were still ringing when new ones started:
a wash, not a distinguishable rhythm. Short decay times (order 50-200ms) are standard practice
for keeping percussive/rhythmic material clear rather than blurred
([Signal Flux, "Percussion Synthesis Building Blocks"](https://signalflux.org/knowledge-blog/percussion-synthesis-building-blocks);
[MasterClass, "ADSR Envelopes Explained"](https://www.masterclass.com/articles/adsr-envelope-explained)).
`MUSIC_DECAY_RATE = 8.0` (vs. the default 3.2) gives roughly that range. This is also why
`play_tone`/`flash` gained optional `decay_rate`/`volume` parameters — see
[audio.md](audio.md#why-play_toneflash-gained-optional-decay_ratevolume-params).

## Downbeat accent

`_euclidean_rhythm`'s construction always places an onset at step 0 of the pattern (the first
"pulse" bucket always starts the flattened sequence), so accenting step 0 — slightly louder,
slightly longer decay (`MUSIC_ACCENT_VOLUME`/`MUSIC_ACCENT_DECAY`) — reliably accents the bar's
downbeat. Toussaint's analysis of Euclidean rhythms notes accented downbeats as part of what
makes these patterns read as coherent "good rhythms" rather than just evenly-spaced clicks; this
is a cheap way to get some of that without a full accent-pattern model.

## Retuning for free

`_music_pad_for_degree(degree)` looks up the pad currently tuned to a degree via the active
scale's `ring_order` (`ring_order.find(degree)` → ring position → `pad_names[pos]`) — the same
mapping `_apply_scale_and_palette()` already maintains for every other mode. Because the lookup
happens fresh on every note rather than being cached, a scale change mid-playback takes effect on
the very next note with no explicit "retune Music Mode" step required.

## Tempo and starting note

Tempo is randomized once per Music Mode session (55-85 BPM), not per phrase/bar - a tempo that
drifted bar-to-bar would read as unsteady/broken rather than intentional, so it's picked once and
held for the session. An earlier version used 80-130 BPM for more session-to-session variety
(see below), but at 16th-note density that read as consistently too energetic for what's meant to
be a calm, idle-listening mode - the range was pulled down to match the game's established
"deliberately mellow" tone (see `GAME_OVERVIEW.md`) rather than optimizing for variety alone. The walk's starting degree is also randomized per session rather than always
opening on the tonic (mid-session phrase resolution still lands on the tonic every
`MUSIC_PHRASE_BARS` bars, unchanged). Together these mean two Music Mode sessions rarely sound like
the same song restarting - different opening note, different tempo, different rhythm/melody rolls
throughout.

## Idioms borrowed from how the real instrument is played

Everything above is a general-purpose generative-melody/rhythm design (Euclidean rhythm,
biased random walk, reflecting boundaries) - none of it is specific to steel tongue drums or
handpans as physical instruments. Researched real playing technique (tutorials/guides from Beat
Root, Healing Sounds, Cosmos Handpan, the Malte Marten Method, and The Sound Artist - see sources
below) to find patterns that are idiomatic to *this instrument* rather than generically
"algorithmic." All six are now implemented in `_music_loop()`/`_generate_music_bar_melody()`.

- **Anchor-note return (drone technique)** (`MUSIC_IDIOM_RANGES["anchor_return"]`, default 12%) -
  players weave back to the lowest/tonic pad *between* melodic notes, not just at phrase
  boundaries (mirrors a handpan's central "ding" used as a drone under a melody). Implemented as
  a small per-note chance, checked before each note's degree is chosen, of overriding the walk's
  next note to a resolution degree (tonic or in-range octave - see
  [Note distribution bias fix](#note-distribution-bias-fix) below) and resetting momentum, so the
  walk resumes cleanly from the anchor rather than carrying direction from before the jump.
- **Zigzag / alternating-side contour** (`MUSIC_IDIOM_RANGES["zigzag_bias"]`, range 0.5-1.0, default
  0.75) - handpan note layouts are numbered in a zigzag specifically so players alternate hands
  across the ring rather than run scalar sequences; it's a *physical* constraint that becomes a
  melodic signature. Pads are laid out on a ring via `ring_order`, so `SequenceGenerator.walk_next_step()`
  biases direction choice toward whichever candidate note lands on the opposite ring side from the
  current note, instead of the raw scale-degree-adjacency bias it used before.

  The first version only applied this when there was no established direction to defer to (session
  start, or right after a phrase-end/anchor-return reset) - a real player report ("cranking the
  slider doesn't audibly/visibly change anything") turned out to be correct, not just a
  visualization gap: that condition is rare on its own, *and* even then only a minority of scale
  degrees have an asymmetric crossing option to lean on (for `d_minor_pentatonic`'s ring layout,
  exactly 1 of 8), so the slider's effect was buried in noise. Verified directly - simulating 2000
  steps of `walk_next_step()` at `zigzag_bias=0.5` (the tuned-range floor) vs. `1.0` and measuring
  how often consecutive notes land on opposite ring sides gave 30% vs. 43%, i.e. the floor produced
  essentially the same alternation rate a fresh coin-flip walk would.

  Broadened to also weigh in on step inertia's ordinary continue-vs-reverse pick (the 70/30 split,
  most of the walk's steps) rather than only the rare no-established-direction case: whichever of
  "continue" or "reverse" actually crosses to the other ring side gets pulled toward, scaled by
  `zigzag_bias` (0.5 = pure step inertia, unchanged from before; 1.0 = near-certain to take
  whichever option crosses). `walk_next_step()` returns a `used_zigzag` flag marking exactly which
  notes this decided, consumed by the Tune panel visualizer (see
  [Visualizing the idioms](#visualizing-the-idioms) below) rather than left for the player to
  infer. Re-verified after the change: 30% (unchanged floor) vs. 43% (up from a pre-fix ~31-33%) -
  now driven by most of the walk's steps instead of a handful of resets per phrase.
- **Glissando sweep** (`_music_glissando_sweep()`, chance range default 10%) - sliding a mallet
  across several tongues in quick succession is a named technique, not an accident of a rhythm
  generator. A rare run across the full scale (single direction, quiet) is inserted as a special
  event right as a new phrase starts, rather than folded into the normal rhythm/melody roll. Swept
  in *pitch* order (ascending/descending scale degree), not physical ring order - a ring-order
  sweep jumps around unpredictably in pitch, since the ring is deliberately zigzagged for
  playability rather than laid out by pitch. Notes are held long enough (90-160ms, decay 4.5) to
  actually ring as pitches and blend into each other - an earlier version used ~30ms blips with a
  fast decay (9.0) that read as electronic beeps rather than an instrument.
- **Ghost notes** (`MUSIC_IDIOM_RANGES["ghost_notes"]`, default 18%) - very light, near-silent filler
  taps on the last-played pad, dropped into the Euclidean pattern's silent steps. Purely
  decorative - doesn't touch the melody walk's state at all.
- **Groove repetition instead of always re-rolling** (`MUSIC_IDIOM_RANGES["groove_repeats"]`, default
  35%; hold length fixed at `MUSIC_GROOVE_HOLD_BARS = 2`) - tutorials teach practicing over a
  repeating 8-beat loop rather than constantly varying; after a bar's Euclidean rhythm is rolled,
  there's a chance to hold that same pattern for 2 more bars instead of re-rolling every bar
  (melody still walks normally underneath). Mirrors a real player settling into a groove.
- **Canonical riff shapes** (`MUSIC_RIFF_SHAPES`, chance range default 25%) - beginner tongue-drum
  material is taught as small numbered shapes (1-3-5-3, 1-2-3-4-5, etc.) rather than free
  improvisation. At the start of a phrase, there's a chance to seed the melody with one of four
  fixed shapes (expressed as scale-degree offsets from wherever the walk currently sits, so it
  still works when a session opens on a non-tonic degree) instead of a pure random walk.

### Player-tunable via Music Mode's Tune panel

Each of the six idioms above has a slider in Music Mode's own "Tune" panel (`MusicTunePanel`,
opened via the Tune button next to Exit Music - deliberately *not* in the main Settings panel,
since these are playback-feel knobs specific to a listening mode, not persistent game settings).
Sliders are 0-1 and map through `MUSIC_IDIOM_RANGES` (`_music_idiom_value()`) via two lerps
(0..0.5 and 0.5..1) rather than one: each idiom has its own `min`/`default`/`max`, and the slider's
midpoint (50%) always reproduces the tuned default above, regardless of what `min`/`max` are. This
two-segment shape exists because a single `lerp(min, max, slider)` forces the default to sit at
the *midpoint* of the range, which doesn't work when an idiom's tuned default is deliberately rare
(e.g. glissando's 10%) but a satisfying "100%" extreme needs to be much higher than double that
(glissando's max is 85%, not 20%) - a real, reported bug: at a naively-computed 20% ceiling,
100%-glissando was rare enough a player could listen for a minute without hearing one.

Sliders reset to 50% (not saved) every time Music Mode starts (`_reset_music_idiom_sliders()`,
called from `_on_music_button_pressed()`) - they're session-only tuning, not a persistent
preference, so a Tune-panel experiment never silently carries over into the next session.

### Only three ported to Normal/Chaos Mode

Anchor return, zigzag contour, and riff shapes were also ported into Normal/Chaos Mode's sequence
generator (`_normal_next_pad_name()`, fixed at their tuned defaults - `NORMAL_ANCHOR_RETURN_CHANCE`
etc. - not wired to the Music Mode sliders). These three are safe there because they're pure
*note-selection* bias: they change which pad the walk lands on for a note that's being generated
anyway, never adding or removing a note from `sequence`, so the memorized sequence's length is
untouched. Ghost notes, groove repeats, and glissando were **not** ported: ghost notes are an
extra audible tap that isn't part of `sequence`, which in a memory game reads as "a note I need to
repeat" rather than decoration; groove repeats and glissando are built around Music Mode's
per-bar rhythm grid, which Normal/Chaos Mode doesn't have (every note there is one
memorize-and-repeat beat, not a grid position).

Of the six, anchor-note return and zigzag contour were flagged up front as the most
idiomatic-*and*-cheap given the existing `ring_order`/tonic-return machinery - which is exactly
why they were also the two picked for the Normal/Chaos Mode port.

Sources: [Beat Root - tongue drum improvisation](https://www.beatrootdrum.com/tutorial-2-learn-how-to-improvise-tongue-drum),
[Healing Sounds - steel tongue drum guide](https://healing-sounds.com/blogs/tongue-drum/steel-tongue-drum-beginners-guide),
[Cosmos Handpan - notes chart guide](https://www.cosmoshandpan.com/blogs/news/handpan-drum-notes-chart-complete-guide-for-players-buyers),
[Malte Marten Method - zig-zag fundamentals](https://www.maltemartenmethod.com/handpan-fundamentals),
[The Sound Artist - handpan rhythm patterns](https://thesoundartist.com/blogs/news/handpan-tutorial-learning-rhythms-and-music-patterns).

## Visualizing the idioms

Player-reported: turning the Tune panel sliders up/down didn't produce an audible/visible
difference they could actually pin on a specific idiom - "it works but I can't tell what changed."
Three pieces, all in `Main.gd`/`Main.tscn`, none of which touch note selection (except the
zigzag_bias fix above, which was a real generator bug the visualizer surfaced rather than a
rendering issue):

- **Contour strip** (`ContourStrip`, drawn in `_on_music_contour_draw()`) - a scrolling plot of the
  last `MUSIC_VIZ_HISTORY_MAX` notes, x = time, y = scale degree, dot color = which physical ring
  side the note's pad sits on (`_music_ring_side()`). Only real walk notes are connected by the
  contour line - ghost notes and glissando sweeps are pushed to the same history for their
  timeline position, but excluded from the line, since they never touch `_music_current_degree`
  (see [Idioms](#idioms-borrowed-from-how-the-real-instrument-is-played) above) and connecting them
  would draw a melodic contour that never happened. Ghost notes render as a small hollow ring
  instead of a filled dot for the same reason - visually distinct from a real note, not just a
  fainter one.
- **Ripple pulse** (`MusicIdiomRippleLayer`, `_on_music_ripple_draw()`) - when a note is tagged
  with an idiom that has a Tune-panel slider (anchor return, riff, ghost, glissando) or is a
  phrase's tonic landing point (resolve), the pad that note actually plays on flashes an expanding,
  fading colored ring, tagged in `MUSIC_VIZ_TAG_COLORS`. This is the primary way to judge an
  idiom's slider - crank Anchor Return to max and pads should flash gold almost constantly; at 0%,
  never. A line graph of an abstract history array asks the player to spot a *pattern*; a colored
  pulse on the actual pad they're already watching just asks them to notice a *color*, tying the
  slider directly to the physical instrument metaphor the rest of the mode already uses.
- **Event log** (`EventLog`, `_music_viz_log_event()`) - a fading text list of the same events
  ("anchor return", "riff shape", ...), newest on top. Expiry is driven by a timestamp check in
  `_process()` (`_music_viz_prune_log()`), not a per-label `Tween` callback - a `Tween` whose
  captured `Label` gets `queue_free()`'d elsewhere first (e.g. `_music_reset_walk()` clearing the
  log wholesale at the start of a new session) fires later against an already-freed object and logs
  an engine-level "Lambda capture was freed" error. Same reasoning applied to ripple expiry
  (`_music_ripples`, pruned in `_process()`) even though ripples don't hold Object references and
  so weren't actually at risk - kept consistent with the log's approach rather than mixing two
  expiry strategies for what's conceptually the same kind of timed visual.

Every color the player can see (ripple, ring outline, log entry) has a matching swatch next to its
slider in `MusicTunePanel` - `chord` (the fixed, non-tunable strong-beat nudge) deliberately stays
text-only in the log rather than showing a color with no slider to explain it. Each slider row also
carries an ELI5 `tooltip_text` in `Main.tscn` explaining what the idiom does in plain language, since
the docs above assume familiarity with the generator that a player tuning sliders won't have.

## Note distribution bias fix

Player-reported: "the music algorithm is favoriting certain notes between runs too often."
Verified rather than guessed at - added `_music_log_degree()`/`_print_music_degree_distribution()`
to tally how often each scale degree got played and print a running histogram (every 32 notes,
plus a final one on exit) to the Godot output console. Real sessions confirmed it, and the shape
was informative, not just "the tonic is loud":

```
n=102, uniform=13%: D=24(24%), F=23(23%), G=17(17%), A=13(13%), C=8(8%), D=6(6%), F=6(6%), A=5(5%)
```

Visitation drops off almost monotonically from the tonic (D, degree 0) down to its octave
(degree 7) - not just the tonic itself spiking, but a smooth decay across the whole lower half of
the range, with the far octave barely touched (0-9% across several sessions, vs. a uniform 12.5%).

### Round 1: de-anchor the boundary (insufficient on its own)

**Root cause:** both phrase-end resolution (every `MUSIC_PHRASE_BARS` bars) and anchor-return
forced the walk back to degree 0 specifically - one specific edge of the `[0, 7]` range, not the
middle. This is a textbook random-walk "mean reversion" / anti-persistence pattern: an excursion
away from a reset point keeps getting cut short before it can reach the far edge, so the reset
point's *neighborhood* (not just the point itself) gets visited disproportionately. The general
dynamic is well documented (e.g. the
[Hurst-exponent/mean-reversion framing](https://www.vortexcapitalgroup.com/insights/the-hurst-exponent-mean-reversion-random-walk-or-trend-what-h-actually-measures)
of anti-persistent series), and Max/MSP and Pure Data's `drunk` object - the standard bounded
random-walk melody generator in those environments, architecturally the same idea as this
project's walk - has the
[same reported symptom](https://cycling74.com/forums/help-with-random-walkdrunk) in practice.

**Round-1 attempt:** resolve to *any* degree that shares the tonic's note name within the 8-pad
range (its octave, where the scale has one) instead of hardcoding degree 0, so reset traffic
splits across both ends of the range instead of concentrating at one.

**This was checked against more logging, not assumed correct - and it wasn't enough.**
Re-running the histogram and aggregating by *pitch class* (both physical copies of D counted
together, both copies of A counted together, etc. - what actually matters for how a listener
perceives note variety, since the ear doesn't care which physical pad played a given pitch)
across five real sessions:

```
n= 32  D=44% F=34% G=16% A=6%  C=0%
n= 63  D=43% F=22% G=21% A=10% C=5%
n= 32  D=25% F=22% G=16% A=16% C=22%
n= 64  D=23% F=23% G=17% A=19% C=17%
n= 96  D=31% F=25% G=11% A=14% C=19%
```

Two problems with treating this as "fixed": first, it's still session-dependent and skewed (the
first session alone hit D=44%/C=0%, nothing close to uniform). Second - and more fundamentally -
**uniform was never the right target to check against in the first place.**

### Round 2: weight by tonal function, not walk-distance-from-a-magnet

Real tonal melodies are not evenly distributed across scale degrees, and shouldn't be - that's
what "uniform=13%" as a baseline in the histogram's own header was implicitly assuming, and it's
wrong. Krumhansl & Kessler's classic probe-tone studies ([tonal hierarchy ratings](https://www.researchgate.net/figure/Krumhansl-and-Kesslers-major-and-minor-tonal-hierarchies_fig1_275025321))
found real tonal perception/usage is tiered: the **tonic** (scale degree 1) rates highest, the
**tonic triad** (degrees 3 and 5 - the mediant and dominant) rates next, and the remaining scale
degrees (2, 4, 6, 7 - passing tones) trail well behind. A steel-tongue-drum melody should sound
like it's built on this hierarchy - tonic and dominant both prominent, passing tones present but
subordinate - not flat, and not "whichever degree happens to sit next to a reset point."

That's exactly the round-1 blind spot: for D minor pentatonic (D-F-G-A-C = scale degrees
1-b3-4-5-b7), F (the mediant, at scale-degree b3) sits physically adjacent to *both* of round 1's
reset points (degrees 0 and 5), while A (the **dominant** - musically the second most important
degree after the tonic) sits far from both. Every session above shows F out-visiting A, sometimes
by 4-6x - backwards from what real tonal hierarchy predicts. Round 1 fixed *where* the walk kept
restarting from, but had no notion of *why* certain scale degrees matter musically, so "closer to
a magnet" kept substituting for "structurally important."

**Fix:** `_scale_degree_weight()` computes each degree's semitone distance from the tonic directly
from the scale's tuned frequencies (`12 * log2(tones[degree] / tones[0])`, not a hardcoded
per-scale table, so it works for any scale definition in `GameData.SCALES`), and classifies it into the
Krumhansl-Kessler tiers: 0 semitones (tonic, any octave) gets the highest weight
(`MUSIC_DEGREE_WEIGHT_TONIC`), 3/4 semitones (minor/major third) or 7 semitones (perfect fifth)
get the next tier (`MUSIC_DEGREE_WEIGHT_TRIAD`), and everything else (passing tones) is excluded
from resolution entirely - resolving to an unstable degree would defeat the point of "resolution."
`_pick_resolution_degree()` does a weighted random pick across whichever degrees in the current
scale qualify. For D minor pentatonic this yields stable degrees {D (tonic ×2), F (third ×2),
A (fifth ×2)} with D weighted above F and A, but F and A now getting a real, comparable share
instead of A getting almost none. Passing tones (G, C) still get played plenty as transient notes
during the walk between resolutions - which is correct; they're supposed to be transient, not
absent - they're just never the thing the walk deliberately resolves *to*.

Applied everywhere the round-1 fix was: Music Mode's phrase-end resolution and anchor-return
(`_generate_music_bar_melody()`), and the same two spots in the Normal/Chaos Mode port
(`_normal_next_pad_name()`).

**Checked again rather than declared done - round 2 was closer, but still had a real wrinkle.**
Aggregating fresh sessions by pitch class *and* by tonal-hierarchy tier (triad tones D/F/A vs.
passing tones G/C):

```
n= 32  D=16% F=31% G=9% A=25% C=19%   | triad=72% passing=28%
n= 64  D=19% F=33% G=8% A=25% C=16%   | triad=77% passing=23%
n= 96  D=23% F=35% G=8% A=22% C=11%   | triad=80% passing=20%
```

The categorical shape is now right - chord tones dominant (72-80%), passing tones clearly
subordinate (20-28%), matching the Krumhansl-Kessler tiering. But F is consistently *ahead* of
the tonic D, not just competitive with it, across every session.

### Round 3: boundary degrees have fewer neighbors, so they distort local step traffic

**Root cause:** the resolution weighting itself is fair - D's two copies total ~44% of resolution
picks vs. ~28% each for F and A - so the skew isn't coming from resolution. It's downstream, in
the ordinary step-by-step walk between resolutions. D's tonic copy at degree 0 sits at a **hard
wall**: `_reflect_degree()` means degree 0 has exactly one neighbor (degree 1, which is F in this
scale), so *every* stepwise departure from that copy of the tonic lands on F, deterministically -
not a coin flip, not a bias, a certainty. D's other copy (degree 5) is interior and splits its
neighbor traffic normally between two degrees. Whichever degree happens to sit next to a wall
gets structurally inflated, independent of its own tonal importance - the same underlying
mechanism as round 1's bug (reflecting boundaries distorting local behavior), just one hop removed
from the reset point instead of at it.

**Fix:** discount resolution weight for degrees sitting at either wall (0 or `PAD_COUNT - 1`) by
`MUSIC_DEGREE_WEIGHT_BOUNDARY_FACTOR = 0.4`, so resolution prefers an interior instance of the
same pitch class when one exists (for D minor pentatonic, degree 5 over degree 0 by roughly 71/29
odds), and only falls back to the boundary instance when it's the only option (`chromatic_run`'s
tonic, which doesn't repeat anywhere else in the 8-pad range). This doesn't touch the
tonal-hierarchy tiering from round 2 - it's an orthogonal correction for the walk-mechanics
artifact wall degrees introduce, layered on top.

Re-verify the same way as round 2 (pitch-class + tier aggregation); expect the triad/passing split
to hold, and D to no longer trail F.

## Melodic arch

Surveyed further AI/algorithmic-music-generation literature after the note-distribution work
above, specifically looking for techniques not yet represented in this generator. Two were
directly actionable (this section and the next); a third - Markov-chain transition matrices
trained on a corpus of real melodies - was judged *not* worth adopting: the literature treats
hand-derived transition rules (music theory encoded directly, rather than learned from a training
corpus) as a legitimate, established alternative, and that's what step inertia, post-skip
reversal, and the tonal-hierarchy weighting above already are. A full Markov rewrite would be
architecturally heavier for no clear musical benefit over rules already grounded in the same
domain knowledge a trained matrix would otherwise learn statistically.

Every direction-picking rule up to this point (step inertia, post-skip reversal, zigzag, tonal
hierarchy) only shapes **local** motion - the next note relative to the current one. None of them
say anything about a phrase's overall shape. Corpus research fills that gap with a strong,
specific finding: analyzing the Essen folksong database (6000+ pieces), Huron found the single
most common melodic shape by a wide margin is an **arch** - pitch rises through roughly the first
half of a phrase, then falls through the second
([Huron, "The Melodic Arch in Western Folksongs," 1996](https://www.researchgate.net/publication/239063783_The_Melodic_Arch_in_Western_Folksongs);
corroborated in later corpus work on arch vs. other contour shapes).

**Implementation:** `_music_arch_direction()` returns the phrase-position-appropriate direction
(+1 through the first half of a `MUSIC_PHRASE_BARS`-bar phrase, -1 through the second), and
`_music_next_delta()` has a `MUSIC_ARCH_BIAS = 0.3` chance, after the existing step-inertia/
post-skip-reversal/zigzag rules pick a direction, to override it with the arch's preferred
direction instead. This is a soft nudge layered on top of the local rules, not a replacement for
them - at 30%, most notes still follow local contour rules untouched, but enough of them lean
toward the phrase's overall trajectory to produce a net rise-then-fall shape without eliminating
local variety. Explicitly **not** applied during a gap-fill reversal (the mandatory step back after
a leap, from the post-skip-reversal rule) - that's a hard, well-grounded local contour rule the
arch shouldn't second-guess.

Ported to Normal/Chaos Mode too (`_normal_next_delta()`/`_normal_arch_direction()`, same bias
constant, keyed off `sequence.size() % NORMAL_PHRASE_LENGTH` instead of bar count since Normal
Mode has no bars) - like the round-1/round-2 idioms ported earlier, this is pure direction bias
that never adds or removes a note from `sequence`, so it's safe there.

## Chord tones on strong beats

The other actionable finding: tonal/counterpoint theory's standard treatment of harmonic rhythm
puts chord tones on strong metrical positions and reserves passing/non-harmonic tones for weak
ones - the textbook chord-tone–passing-tone–chord-tone figure on a beat/off-beat pattern
(see e.g. [Open Music Theory on species counterpoint](https://viva.pressbooks.pub/openmusictheory/chapter/second-species-counterpoint/)
and the nonharmonic-tones literature on metrically weak placement). This generator had no notion
of that at all - scale-degree selection was identical whether a note landed on the beat or not.

The Euclidean rhythm generator already gives Music Mode a well-defined "strong beat": it always
places an onset at step 0 of the pattern (see [Downbeat accent](#downbeat-accent) above), which is
also always the *first* melody note generated for the bar (`i == 0` in
`_generate_music_bar_melody()`'s per-pulse loop), since pulse indices map onto rhythm onsets in
order. `_nearest_chord_tone_degree()` finds the closest degree with a nonzero
`_scale_degree_weight()` (tonic/third/fifth - the same tonal-hierarchy classification the
note-distribution fix uses), and on the bar's downbeat there's a `MUSIC_STRONG_BEAT_CHORD_TONE_CHANCE
= 0.4` chance of nudging the walk onto it if it isn't already sitting on one. Deliberately a
*nudge to the nearest* chord tone, not a jump to a weighted-random one the way anchor-return
works - anchor-return is meant to read as a deliberate drone return; this is meant to read as "the
walk's landing note happened to resolve," a much smaller and more local correction. Off-beat notes
are untouched and can still be full passing tones, same as before - only the strong beat is
biased.

Not ported to Normal/Chaos Mode: that mode has no rhythm grid at all (every note is one
memorize-and-repeat beat, not a position within a bar), so there's no meaningful "strong beat" to
key this off - same reasoning as why groove repetition and glissando didn't port earlier.

## Style presets

Everything above produces one sound - a blend of handpan playing idioms layered on Western
tonal-hierarchy theory (Krumhansl-Kessler resolution weighting, Huron's melodic arch), never
labeled as such because there was only ever the one option. **Style** presets
(`GameData.MUSIC_STYLES` in `scripts/game_data.gd`) name that default ("Western") and add six
more, each a reparametrization of the same generator for a different real-world melodic idiom -
no new instruments, no per-style special-case code.

### Design principle: no style-specific exceptions

Every style shares the exact same field shape (`accent_mode`, `resolution_mode`,
`resolution_secondary_weight`, `chord_tone_nudge_chance`, `rhythm_pulses_min/max`,
`idiom_overrides`, `max_leap_override`, `phrase_structure`, `groove_lock`). Styles differ only in
which *values* they pick for these shared fields - never in which fields they have access to.

This was a real correction, not a design that arrived this way from the start. An early draft of
the Chinese style needed a unique `resolution_mode: "reroot"` (re-interpreting an existing
pentatonic scale's degree as the tonic at runtime) plus a `requires_pentatonic` guard nothing else
needed - flagged and rejected specifically because it broke the uniform-shape rule, and the
Chinese style was dropped entirely rather than reworked to fit. The practical payoff of keeping
every style scale-agnostic: **Music Mode lets the player pick any scale and any style
independently** (17 scales × 7 styles, no locked pairings) - a style that needed to know something
special about which scale was loaded couldn't support that.

### The seven styles

- **Western (default)** - today's baseline behavior, unchanged, just given an explicit name.
- **Reggae (Jamaica)** - born late-1960s out of ska/rocksteady; the "one drop," where the downbeat
  is deliberately left empty and the offbeat gets the accent instead, plus a bass-led melody that
  leans hard on chord tones. Pairs with the new D Dorian scale.
- **Junkanoo (Bahamas)** - West African-rooted street-parade drumming, the sound of Nassau's
  Junkanoo carnival; dense polyrhythm, a locked repeating rhythm+riff ostinato, and
  call-and-response horn riffs. Downbeat-accented (unlike Reggae) - it drives *on* the beat rather
  than syncopating off it.
- **Middle Eastern** - an approximation of maqam-based music (Arab world/Turkey/Persia). Real
  maqam needs quarter-tones this equal-tempered game can't reproduce, so this borrows the ornament
  vocabulary instead - heavy glissando (standing in for melisma/trills) and a loose, low
  chord-tone pull rather than tidy resolution. Pairs with the new Hijaz scale.
- **Balkan/Gypsy** - Klezmer, Balkan brass-band, and Gypsy-jazz; fast and riff-driven. Pairs with
  the new Hungarian Minor scale.
- **Japanese/Eastern** - gagaku/shakuhachi tradition; spacious and unhurried (*ma*, the deliberate
  use of silence), narrow stepwise motion, and resolves to the 4th/octave rather than the Western
  3rd/5th (Koizumi's nuclear-tone theory). Pairs with the new Insen scale or the existing Akebono
  scales.
- **Jazz** - wide, unpredictable melodic leaps and chord-tone-targeting ("enclosure," approximated
  - true swing-eighth timing and the real two-note chromatic lead-in aren't implemented yet).
  Pairs with the new Whole Tone scale.

Sources: [One-drop rhythm](https://en.wikipedia.org/wiki/One_drop_rhythm),
[Music of the Bahamas](https://en.wikipedia.org/wiki/Music_of_the_Bahamas),
[maqamworld.com](https://www.maqamworld.com/en/maqam.php),
[Hungarian Minor scale](https://yonamariemusic.com/yona/blog/299/all-about-the-hungarian-minor-scale),
[Japanese musical scales](https://en.wikipedia.org/wiki/Japanese_musical_scales),
[Jazzadvice - Approach Notes & Enclosures](https://www.jazzadvice.com/5-easy-tricks-with-approach-notes-in-jazz-improvisation/).

### New idioms this required

- **Offbeat accent** - `_music_is_accented_step()` generalizes the old hardcoded "step 0 is always
  the accent" into a lookup on `style.accent_mode`. `"downbeat"` is unchanged; `"offbeat"` (Reggae)
  accents whichever onset sits closest to 16-step position 12 (beat 3 of 4, the one-drop
  placement), excluding step 0, falling back to the first onset found if a sparse pattern has none
  near there.
- **Chord-tone bias** - the existing strong-beat chord-tone nudge (see [Chord tones on strong
  beats](#chord-tones-on-strong-beats) above) generalized two ways: it now checks whichever pulse
  is *actually* accented (via the offbeat-accent lookup above) rather than hardcoded pulse 0, and a
  second, independent per-style `chord_tone_nudge_chance` rolls on *every* note, not just the
  accented one - this is what makes Reggae's melody read as bass-led rather than scalar.
- **Call-and-response phrasing** - `phrase_structure: "call_response"` (Junkanoo). A phrase's first
  half (bars 0-1, the "call") generates and plays normally while its degree sequence is cached
  into `_music_call_phrase`; the second half (bars 2-3, the "response") drains that cache in order
  instead of walking, so the response is a direct echo of the call. v1 scope is exact echo, no
  transposition/variation - matches the existing `MUSIC_RIFF_SHAPES` precedent of canonical fixed
  shapes rather than generated variation.
- **4th/octave resolution** - `resolution_mode: "fourth_octave"` (Japanese/Eastern) is a second
  branch in `SequenceGenerator.scale_degree_weight()` alongside the original `"triad"` tiering: the
  secondary tonal-hierarchy tier keys off 5 semitones (perfect 4th) from the tonic instead of 3/4/7
  (3rd/5th). Both modes are computed the same way, generically, from the scale's own tuned
  frequencies - no scale-type branch, so it works on any scale, including ones with no degree that
  qualifies (resolution then falls back to the tonic tier alone, the same fallback that already
  existed).

### `resolution_secondary_weight`: one knob for two opposite-sounding effects

`SequenceGenerator.scale_degree_weight()`'s secondary tier (3rd/5th under `"triad"` mode, 4th under
`"fourth_octave"`) used to be a fixed constant (`MUSIC_DEGREE_WEIGHT_TRIAD = 1.5`). Each style can
now override it via `resolution_secondary_weight`. Raising it toward the tonic weight
(`MUSIC_DEGREE_WEIGHT_TONIC = 2.4`) produces a *stronger* pull - Reggae's bassline-like insistence
on chord tones. Lowering it produces a *weaker*, looser pull - Middle Eastern's less-resolved
wandering. Same one mechanism, just tuned in opposite directions per style, rather than two
separate features.

### Where a style is "live": Music Mode vs. Normal/Chaos/Duet

`_active_music_style()` is the single accessor every idiom/resolution/rhythm call site goes
through: `_music_current_style` (Music Mode's own player-picked style, from the new Style panel -
see below) while `music_mode` is true, otherwise `_run_current_style` (rolled once at the start of
every Normal/Chaos/Duet run via `GameData.MUSIC_STYLES[randi() % ...]`, in `_on_start_pressed()`).
Two separate fields, not one shared "current style," so Music Mode's picker can never leak into a
Normal/Chaos/Duet run and vice versa.

Deliberately **not** symmetric with scale selection: Music Mode lets the player choose scale and
style freely; Normal/Chaos/Duet roll a random style but leave scale exactly as it already worked
(the player's Settings choice, persisted, unlock-rewarded). Scale determines the physical ring
layout a player has practiced for a memory game - auto-randomizing it every run would fight the
actual skill mechanic and would need redesigning the existing scale-unlock reward loop for no
clear benefit, since style (a generation-flavor layer) doesn't carry that cost. This puts style in
the same category as the idioms already ported to these modes (anchor return, zigzag, riff shapes,
arch) - a run-flavoring detail underneath, not a player-facing choice with its own progression
track. Since Normal/Chaos/Duet have no Tune-panel sliders, a style's `idiom_overrides` still
reaches their ported idioms via `_normal_idiom_default()`: if the rolled style defines an override
for a key, its `"default"` value substitutes for the mode's normal fixed constant
(`NORMAL_ANCHOR_RETURN_CHANCE` etc.) - reusing each style's tuning intent without needing slider
machinery that doesn't exist in these modes.

Styles carry no `unlock` key (free/always available from the start) and Music Mode's choice is
session-only, resetting to Western on every fresh entry - same precedent as the Tune panel
sliders' "session-only tuning, not a persistent preference."

### Music Style panel

A new card-grid picker (`_build_music_style_panel()`/`_build_style_cards()` in `Main.gd`), reached
via a `Style` button next to Tune/Exit on `MusicBar`. Built entirely in code rather than
hand-authored in the .tscn - same reasoning as `_build_scale_cards()`: a handful of near-identical
cards generated from `GameData.MUSIC_STYLES` is far less error-prone than hand-placing them. A
sibling of `MusicTunePanel`, not nested inside it, so the Tune panel's existing layout is
untouched. No unlock chrome on any card, since styles carry no `unlock` key.
