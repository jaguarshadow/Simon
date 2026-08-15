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

## Future: idioms borrowed from how the real instrument is played

Everything above is a general-purpose generative-melody/rhythm design (Euclidean rhythm,
biased random walk, reflecting boundaries) - none of it is specific to steel tongue drums or
handpans as physical instruments. Researched real playing technique (tutorials/guides from Beat
Root, Healing Sounds, Cosmos Handpan, the Malte Marten Method, and The Sound Artist - see sources
below) to find patterns that are idiomatic to *this instrument* rather than generically
"algorithmic." None of these are implemented yet; tracked as a TODO item.

- **Anchor-note return (drone technique)** - players weave back to the lowest/tonic pad *between*
  melodic notes, not just at phrase boundaries (mirrors a handpan's central "ding" used as a
  drone under a melody). Music Mode currently only resolves to the tonic every
  `MUSIC_PHRASE_BARS` bars; a small per-bar chance of a mid-phrase "ghost return" to the tonic
  between two melodic notes would be closer to actual played technique.
- **Zigzag / alternating-side contour** - handpan note layouts are numbered in a zigzag
  specifically so players alternate hands across the ring rather than run scalar sequences; it's a
  *physical* constraint that becomes a melodic signature. This project's pads are already laid
  out on a ring via `ring_order` (see the ring-reorder TODO entry), so a contour bias toward
  alternating sides of the ring - instead of by scale-degree adjacency, as `_music_next_delta()`
  does now - would sound distinctly more "played on this instrument."
- **Glissando sweep** - sliding a mallet across several tongues in quick succession is a named
  technique, not an accident of a rhythm generator. A rare full-ring run (single direction, short
  spacing, low volume) inserted as a special event between phrases would read as idiomatic rather
  than as "the algorithm rolled a big leap."
- **Ghost notes** - very light, near-silent filler taps between main notes, used to keep flow
  between phrases. Could be inserted at low volume between Euclidean pulses without affecting the
  "real" scale walk at all - cheap given `flash`/`play_tone` already take `decay_rate`/`volume`
  params (see [audio.md](audio.md#why-play_toneflash-gained-optional-decay_ratevolume-params)).
- **Groove repetition instead of always re-rolling** - tutorials teach practicing over a repeating
  8-beat loop rather than constantly varying; suggests occasionally *holding* the same Euclidean
  pattern for 2 bars before re-rolling, rather than recomputing every bar as it does now. Mirrors a
  real player settling into a groove.
- **Canonical riff shapes** - beginner tongue-drum material is taught as small numbered shapes
  (1-3-5-3, 1-2-3-4-5, etc.) rather than free improvisation. Occasionally seeding a phrase with one
  of these instead of a pure random walk would give recognizable "riff" moments rather than
  everything sounding like a stochastic process.

Of these, the anchor-note return and zigzag contour are the most idiomatic-*and*-cheap given the
existing `ring_order`/tonic-return machinery, so they're the natural starting point when this gets
implemented.

Sources: [Beat Root - tongue drum improvisation](https://www.beatrootdrum.com/tutorial-2-learn-how-to-improvise-tongue-drum),
[Healing Sounds - steel tongue drum guide](https://healing-sounds.com/blogs/tongue-drum/steel-tongue-drum-beginners-guide),
[Cosmos Handpan - notes chart guide](https://www.cosmoshandpan.com/blogs/news/handpan-drum-notes-chart-complete-guide-for-players-buyers),
[Malte Marten Method - zig-zag fundamentals](https://www.maltemartenmethod.com/handpan-fundamentals),
[The Sound Artist - handpan rhythm patterns](https://thesoundartist.com/blogs/news/handpan-tutorial-learning-rhythms-and-music-patterns).
