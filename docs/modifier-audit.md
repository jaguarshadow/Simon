# Modifier Audit — Usefulness Pass

Two audit rounds so far, against a growing rule set. **Pass 1** (perceptibility + four supporting
pillars) is implemented. **Pass 2** (a sixth rule, added after a design conversation about how
*activating* a modifier should feel) is audited below but not yet implemented — see "Pass 2:
No Countable Resource".

## The six rules

1. **Show your work.** When it fires, the player can name this modifier, not just "something
   happened" — a cascade line, toast, pad flash, or playback change, some dedicated channel, never
   a silent fold into a shared number.
2. **Change the play.** Equipping it changes a decision, a skill to aim for, a resource to spend,
   or a moment to look forward to. Wallpaper that "helps in theory" is not a modifier.
3. **One job, one voice.** A single readable promise, in musical language, that stays inside its
   slot. It must not impersonate a sibling or leak into another category.
4. **Alive in every scored mode.** Real and measurable in Normal, Chaos, and Duet. Naturally
   weaker in one mode is fine; flatly dead or excluded is a redesign, not a footnote.
5. **Assist the performance, don't play it.** Never skip a missed step, never auto-bank, never
   remove Cash Out as a choice. Forgiveness waives the penalty, not the requirement to get the note
   right. The player is still the one performing.
6. **No countable resource.** Every modifier is either **Passive** (always evaluated automatically)
   or an automatic **Roll/state check** (a chance or a condition, evaluated live) — never a charge,
   a "uses" count, or a button, refillable or not, capped or not. The practical test: *if using this
   modifier ever requires the player to decide "should I do something right now," it fails* —
   whether that decision is about a countable resource or just about whether to click at all.
   Rule 6 is stricter than (and replaces) two narrower versions tried and rejected along the way: "no
   mid-sequence button" alone still allowed a bothersome pause-point button, and "no non-refilling
   charges" alone still left a number to watch and a spend-or-save decision to make even when it
   renews. A modifier with zero countable resource of any kind automatically satisfies both.

Rules 1-5 came out of the first pass, prompted by a concrete complaint (Metronome does nothing
perceptible). Rule 6 came out of a second conversation about *how* modifiers activate, prompted by
a different complaint: charge-tracking ("do I still have Ornament charges?") and mid-flow buttons
both pull attention away from playing the pads, which is the actual game. Balatro's jokers are the
reference point for rule 6 — they fire on their own condition, forever, with nothing to spend or
bank.

## Pass 1: Perceptibility & Agency (implemented)

**Status: implemented.** All 7 flagged modifiers (the 5 originally flagged, plus Unbreakable and
Slow Fade added to scope on review) have been redesigned in `Main.gd`. The verdicts table below is
kept as the diagnostic record; "Redesigns implemented" describes what actually shipped, which in
Metronome's case differs from the first proposal (see its note).

### Why this pass, and the bar it uses

Prompted by a concrete complaint: **Metronome does nothing perceptible.** Looking at its
implementation confirmed it — the only thing it drives is `round_label.scale = Vector2.ONE * (1.0
+ 0.03 * salience)`, a scale pulse on the round-number text that tops out at 15% at max level. No
score effect, no toast, no sound. A modifier can be equipped for an entire run and change nothing
the player experiences.

That's the wrong kind of invisible for this game specifically: `_register_hit()` already has a
built-in mechanism for making effects legible — a cascading score-popup stack (mirrors Balatro's
per-joker reveal) where Fortissimo, Perfect Pitch, Harmonic Chain, Golden Step, Lucky Strike,
Resonance, and Motif Bonus each get their own labeled `+N` line. That pattern exists; the question
per modifier is whether it actually uses it (or an equally legible substitute — a toast, a distinct
flash, a visible mechanical change) or quietly does nothing anyone would notice.

**Primary bar: perceptible impact.** Does the player feel or see this modifier doing something on
a hit, round, or run where it fires — not "does it help in theory," but "would a reasonably
attentive player ever consciously register this happened"? A modifier that provably changes score
but never tells you so, or tells you in a way indistinguishable from two other modifiers, fails
this bar exactly like one that does nothing at all.

**Secondary lenses**, applied only to modifiers that fail the primary bar, to decide *how* to fix
them rather than just *that* they need fixing:
- **Strategic weight** — does it change a real decision (risk-taking, timing, resource spend), or
  is it a passive number with no agency attached?
- **Power budget parity** — is its impact competitive with the other options in its slot at the
  same level, independent of whether it's legible?
- **Uniqueness** — does it do something no sibling modifier already does?

**Method:** design review against the actual implementation in `Main.gd` (not just the roster
descriptions, which can drift from what the code does), not fresh instrumentation — the mechanisms
here are simple enough to read directly. Flagged for follow-up: if any verdict below is disputed
after playtesting, that's the case to add logging for (same approach as the note-distribution
histogram work in `docs/music-mode.md`), not a reason to re-litigate by re-reading the code harder.

### Verdicts

| Modifier | Category | Verdict | Why |
|---|---|---|---|
| Sharper Ear | Multiplier | **Weak** | Real effect (`combo_growth` bonus), but folds silently into the base `+N` popup number — no dedicated cascade line like Resonance gets for the same kind of bonus. |
| Resonance | Multiplier | Pass | Own cascade popup (`"Resonance +%d"`). |
| Crescendo | Multiplier | **Weak** | Real effect on the cash-out multiplier, but the cash-out total is a single lump number — no breakdown line attributing any of it to Crescendo. |
| Perfect Pitch | Multiplier | Pass | Own cascade popup; the underlying skill (steady tapping cadence) is itself a legible thing to aim for. |
| Harmonic Chain | Multiplier | Pass | Own cascade popup, escalates visibly across a motif. |
| Fortissimo | Multiplier | Pass | Own cascade popup plus a one-time fanfare toast on first personal-best crossing. |
| Safety Net | Defense | Pass (see Muffled Strike/Unbreakable) | Forgiveness fires a screen flash + shows the correct pad — clearly "something saved me." |
| Echo Chamber | Defense | Pass | Player-activated (Peek button) — can't be missed, it's a deliberate spend. |
| Muffled Strike | Defense | **Weak** | Forgiveness uses the exact same generic flash+hint as Safety Net and Unbreakable, with no toast or distinct visual — you can tell *something* saved you, never *this*. Also zero strategic weight: a passive dice roll with no decision attached. |
| Grounding Resonance | Defense | **Fail** | Fires silently at the moment of death, folded into the final score with no toast/breakdown on the Game Over screen. Worse than Muffled Strike — there isn't even a shared "you got saved" flash, because the run still ends. |
| Second Wind | Defense | Pass | Distinct toast (`"Second Wind! Hits banked."`), clear framing as a power option. |
| Unbreakable | Defense | **Weak** | Has a persistent HUD charge counter (`(2/3)` suffix), which helps, but the forgiveness moment itself is the same undifferentiated flash as Safety Net/Muffled Strike — no toast naming it. |
| Steady Hands | Tempo | Pass | Directly, audibly slows every playback — impossible to miss. |
| Quick Rewind | Tempo | Pass | Player-activated, plus a refill toast. |
| Metronome | Tempo | **Fail** | The complaint that started this audit — a 3%-per-level label wiggle, nothing else. |
| Slow Fade | Tempo | Pass, weak strategic weight | Visibly changes every pad flash's glow tail — passes perceptibility outright, unlike Metronome. But it's unclear the longer glow does anything for the player beyond looking nice; flagged for the secondary lenses even though it clears the primary bar. |
| Breath Mark | Tempo | Pass | Audibly changes the rhythm's pacing every 4th step. |
| Rubato | Tempo | Pass | Adaptive pacing is expressed directly through the primary channel the player is already parsing (playback speed) — perceptible by construction, even with no toast. |
| Golden Step | Bonus Event | Pass | Own cascade popup (`"Golden Step +%d"`) when the flagged step lands; the surprise-reveal-after-the-fact is the intended design, not a bug. |
| Double Down | Bonus Event | Pass | Toast + screen flash on both outcomes (boost landed, or forfeited). |
| Encore | Bonus Event | Pass | A whole extra animated replay sequence at cash-out — maximally visible. |
| Lucky Strike | Bonus Event | Pass | Toast + own cascade popup. |
| Motif Bonus | Bonus Event | Pass | Own cascade popup. |
| Grand Finale | Bonus Event | Pass | Toasts at gamble-start, win, and loss; clear high-tension framing. |

**Score: 17 pass outright, 5 weak, 1 fail, 1 pass-with-caveat (Slow Fade).** Every failure and weak
verdict is concentrated in two places: modifiers whose numeric effect is real but gets folded
anonymously into a shared number (Sharper Ear, Crescendo), and Defense forgiveness modifiers that
all currently share one undifferentiated "you got saved" flash (Muffled Strike, Unbreakable, and by
extension the otherwise-fine Safety Net). Metronome and Grounding Resonance are the two genuine
do-nothing-visible cases.

### Redesigns implemented

- **Metronome.** First proposal (above, superseded) was to port the Duet timing gauge into
  Normal/Chaos. **Implemented instead:** `_metronome_pulse()` now plays a real tick
  (`Sound.play_ui_tick`, UI bus, never hard-cuts a ringing pad tone) and pulses the Resonator's own
  scale, both scaling with level — replacing the 3% `round_label` wiggle entirely rather than
  layering onto it. Also now fires during `_run_duet_response`'s wait loop (once per note, timed to
  `_duet_note_span`), the one phase the original never reached at all — pillar 4 (alive in every
  mode) was failing even harder than pillar 1 once you looked at *when* it fired, not just *how
  visibly*. Stayed inside Tempo's lane (pillar 3): purely audio/visual, touches no score.
- **Grounding Resonance.** Fires the same bank-a-fraction-of-`unbanked_points` mechanic as before
  (unchanged — it was never the mechanic that failed), now surfaced as a durable callout line
  (`"Grounding Resonance banked +%d"`) on the Game Over summary panel instead of folding silently
  into `final_score` — a summary-panel line survives being read at leisure, unlike a toast under
  the game-over screen shake.
- **Muffled Strike.** Pillar 2 named it specifically: "a coin flip with no agency attached." A
  toast alone wouldn't fix that, so the chance itself changed — the roster's five level values are
  now the *ceiling* chance, reached at `MUFFLED_STRIKE_RAMP_COMBO` (20) combo and ramping linearly
  from 0 below that, so pushing a streak deeper genuinely raises your own safety margin (real
  agency: "how far do I push this streak"). Also gets its own toast on trigger, naming both itself
  and the current chance.
- **Unbreakable.** Mechanic unchanged (still N free misses per streak) — only needed pillar 1: its
  own toast on the forgiveness moment instead of sharing Safety Net's silent flash.
- **Safety Net.** Wasn't flagged, but given a matching toast too while touching this code, for the
  same reason — three Defense modifiers sharing one anonymous flash meant even the *passing* one
  only passed by comparison.
- **Sharper Ear.** Given the same before/after cascade-popup treatment Resonance already had:
  `"Sharper Ear +%d"` shows the delta its `combo_growth` bonus added over `BASE_COMBO_GROWTH`,
  display-only — doesn't change what actually scores, just names it.
- **Crescendo.** Same idea at the cash-out moment: `_cash_out_streak_bonus_without_crescendo()`
  isolates its contribution to the streak bonus, shown as a `"Crescendo +%d"` popup next to the
  cash-out total instead of one undifferentiated lump.
- **Slow Fade.** Pillar 2's borderline case — visibly changes every flash, but changed nothing
  about *how you play*. `_flash_duration_for_pad()`'s linger previously only reached scripted
  playback flashes; `SimonButton.extra_glow_linger` (pushed out from `slow_fade_linger` in
  `_recompute_pure_modifier_stats`) now also extends the fade on the player's *own* press/release,
  so a long or Chaos-reshuffled sequence leaves a real trail of already-correct presses to track
  progress by — a genuine tracking skill, not just a prettier flash.

## Pass 2: No Countable Resource

**Status: implemented.** All six failures below are redesigned in `Main.gd`. Both hard problems
were resolved as part of the redesign rather than left open — see "How the two hard problems were
resolved" and "Redesigns implemented" after the verdicts.

### Verdicts

18 of 24 already pass outright: every Multiplier modifier, every Tempo modifier, and every Bonus
Event modifier are Passive or an automatic Roll with nothing to bank, spend, or click — none of
them were ever gated behind a resource. That leaves six, all in categories that touch "spend
something to be saved or get an edge":

| Modifier | Category | Verdict | Why |
|---|---|---|---|
| Safety Net | Defense | **Fail** | `modifier_resource["safety_net"]`, granted only on level-up, never refilled — a lifetime-capped pool the player has to track and can run completely dry. |
| Echo Chamber | Defense | **Fail** | Same non-refilling charge pool as Safety Net, *and* a player-clicked Peek button — fails rule 6 twice over. |
| Second Wind | Defense | **Fail** | `"uses"`, refilled at Streak 5+ cash-outs — no button, but still a number to track and a implicit "do I have one banked" question during risky play. |
| Unbreakable | Defense | **Fail** | `unbreakable_forgiven_this_streak < lvl` is a per-streak countable allowance — resets automatically each streak (better than Safety Net's lifetime cap) but still a count to watch. |
| Quick Rewind | Tempo | **Fail** | `"uses"` charge pool *and* a player-clicked Rewind button — the original "fumbling for a button mid-flow" complaint's other poster child alongside Echo Chamber. |
| Grand Finale | Bonus Event | **Fail** | `"uses"` charge pool *and* a player-clicked Gamble button — but see "Grand Finale's tension" below before touching this one. |

Muffled Strike (Defense) and Grounding Resonance (Defense) are worth naming explicitly as the
proof this rule is achievable without losing the category's identity: both already redesigned in
Pass 1 into pure automatic Rolls/state checks with zero countable resource, and neither reads as
weaker for it.

### How the two hard problems were resolved

**Defense's identity collision.** Once Safety Net and Unbreakable dropped their charge/count, all
three "forgive a miss" modifiers were separated by *trigger condition* instead, so each answers a
different question:
- **Muffled Strike** — *how deep is this streak?* Probability ramping with combo (unchanged from
  Pass 1).
- **Unbreakable** — *is this the streak's first miss?* Guaranteed, but only once per streak; leveling
  now scales how much combo survives the save (`combo_retain_pct`, 0.7→1.0) instead of how many
  misses are covered.
- **Safety Net** — *am I past my own best streak this run?* Guaranteed forgiveness (plus its
  existing hint) only in new-territory play; leveling adds `grace`, a small buffer *before* the
  record that still counts. Literally a net for falling from a new height — and it means Safety Net
  is unconditionally live on a player's very first streak of a run (nothing to be "past" yet),
  which reads as a pleasant, not accidental, side effect.

**Grand Finale's rule 2 vs. rule 6 tension.** Resolved by taking the second option from the audit:
the Gamble button stays, as a **documented, narrow exception to rule 6** — it sits at the same
pause point as Cash Out, never mid-sequence, so it isn't the thing rule 6 was written to stop. What
did change: the `"uses"` cap is gone. Gambling is always available whenever there's a pool to
wager; the wager's own risk (losing it all) is what balances the modifier, the same logic already
used to drop Second Wind's cap.

### Redesigns implemented

- **Safety Net.** Charge pool replaced by a live check: `_current_wave_length() >=
  best_streak_this_run - grace`. Toast on trigger names it explicitly.
- **Echo Chamber.** Player-clicked Peek replaced by `_check_hesitation_assists()`, an automatic,
  per-frame check comparing how long it's been since your last correct press
  (`Time.get_ticks_msec() - _last_input_ms`) against your own recent pace
  (`recent_response_ms_per_note`, the same signal Rubato already reads). Past
  `hesitation_mult × baseline`, the next note's pad softly echoes on its own — no pads disabled, no
  clock paused, since it's meant to be caught mid-stride, not to interrupt.
- **Quick Rewind.** Same hesitation signal, a higher `hesitation_mult` (so it only fires once Echo
  Chamber's milder nudge wasn't enough), triggers the existing full-sequence replay automatically
  instead of via the Rewind button.
- **Second Wind.** `"uses"` cap dropped — always triggers on a fatal miss when equipped.
  `clutch_bonus` (previously an L5-only unlock) now scales across all 5 levels and always applies,
  since it's the modifier's only remaining leveling axis.
- **Unbreakable.** See "Defense's identity collision" above.
- **Grand Finale.** See "Grand Finale's rule 2 vs. rule 6 tension" above.

### Synergies to keep watching (rule 6 didn't just remove mechanics, it created new pairings)

- **Fortissimo + Safety Net.** Both key off the exact same state — streak length vs. personal
  best — so drafting them together makes "push past your record" the build's whole identity: the
  Multiplier and the safety net both reward the same risk at the same moment.
- **Echo Chamber + Quick Rewind.** Different categories (Defense/Tempo), same hesitation signal, an
  explicit escalation ladder if both are equipped: mild pause → single-note echo, real hesitation →
  full replay. Worth calling out in-game once there's a natural spot to (e.g. FAQ or a tooltip
  cross-reference), since the synergy isn't otherwise obvious from either description alone.
- **Unbreakable + any combo-scaling Multiplier** (Sharper Ear, Harmonic Chain, Perfect Pitch).
  Unbreakable's `combo_retain_pct` directly protects whatever those modifiers have been compounding
  — a "protect the investment" pairing distinct from Fortissimo/Safety Net's "chase the record" one.
- **Grand Finale + Encore + (uncapped) Second Wind.** All three now reward riding a streak as long
  as possible with no scarcity anywhere in the chain — gamble repeatedly, get a bonus replay on
  every cash-out, and never worry about a Second Wind save being "used up." This is the closest
  thing to a dedicated go-long archetype the roster has post-redesign.

## Pass 3: Playtest findings (Perfect Pitch, Metronome)

**Status: implemented.** Two modifiers that scored **Pass** in Pass 1 turned out to fail once
actually played, not just read — a reminder that a design-review-only audit can mark something
"perceptible" and "alive" while still missing whether the target it asks the player to hit is one
they can actually perceive or act on.

- **Perfect Pitch — rule 2 fail, missed in Pass 1, then re-broken by its own first fix.** The
  original design (low-variance stdev of the player's own consecutive hit intervals) had no
  external reference at all: "keep a nice cadence" meant nothing perceivable, and in Duet it
  measured something orthogonal to (and sometimes at odds with) the mode's own shipped
  timing-accuracy scoring. **First fix** (matching `_call_step_ms_per_note`, the call's real
  playback pace, in every mode) solved Duet but broke Normal/Chaos worse than the original: a
  player who's mastered the sequence and blazes through it correctly got *penalized* for being
  fast, directly punishing mastery. **Actual fix:** the formula now branches by mode instead of
  using one target everywhere, because "a nice cadence" genuinely means something different in
  each. Duet keeps the pace-matching check (its premise is echoing a real rhythm, so staying
  aligned with the mode's own scoring is correct there). Normal/Chaos instead checks the
  *coefficient of variation* (stdev / mean) of recent hit intervals — scale-invariant by
  construction, so a fast player tapping evenly scores exactly as well as a slow one; only
  genuinely erratic pacing (a long pause, a burst, another pause) fails it. This is the concept the
  original design had (self-consistency), just finally paired with an honest description
  (`"a smooth, even pace - fast or slow both count, only stopping and starting doesn't"`) instead
  of an unstated, unperceivable target.
- **Metronome — rule 4's blind spot, and now slated for a full replacement.** Pass 1's redesign
  (audible tick + Resonator pulse, every mode) passed every rule as written, but rule 4 only asks
  "is it alive," not "is being alive here actually good" — in Normal/Chaos, where there's no timing
  mechanic for a tick to mark, the sound was just noise layered over the pad tones with no payoff,
  reported as actively distracting rather than merely weak. Interim fix shipped: the audible tick
  now plays only in Duet; the visual Resonator pulse still fires everywhere, so Normal/Chaos is
  quieter rather than silent. Worth stating as a sharper version of rule 4 going forward: **a
  distracting no-op in a mode is worse than a silent one** — "naturally weaker is fine" assumes the
  weaker version is still neutral-to-positive, not a cost with no offsetting benefit. That said, the
  interim fix only papers over the deeper problem — a beat-cue modifier is structurally mismatched
  to two of the three modes it has to live in — so Metronome is being retired rather than patched
  again; see "Pass 4" below for the replacement.

## Pass 4: Category rename + Metronome/Slow Fade replacement

**Status: implemented.**

Two more rules came out of a design conversation about *how* a modifier's cue should be delivered,
prompted by nearly shipping two bad ideas (Anchor Glow, Call Back) that passed rules 1-6 on paper:

**Rule 7 — One channel, one meaning.** Any signal that already carries meaning for the player (pad
glow = the note to press) may only ever be reused for that *same* meaning. Extending the correct
pad's own glow a little longer is fine; lighting a *different* pad, or the same pad for an unrelated
reason, is not.

**Rule 8 — Match effect frequency to payoff.** A cue firing every note has to earn its keep every
note; a cue firing once per round only has to earn it once. This is the precise reason Metronome's
tick failed in Normal/Chaos and a once-per-round cue like Pickup wouldn't have.

(A third process rule, "simulate before proposing" - narrate one concrete round with a candidate
active before adding it to the list, not just a rule-by-rule pass - governed how the rest of this
pass was run, but isn't a property of the modifiers themselves the way 1-8 are.)

**Category rename.** `CATEGORY_LABELS["tempo"]` is now **"Phrasing"**, not "Tempo" - the internal
`"tempo"` id is unchanged (too many call sites to rename safely for a label-only change). The old
name undersold what the category actually contains: Breath Mark and Slow Fade were never about
speed, and neither are the two replacements below. "Phrasing" - how a passage is shaped and
delivered - fits Steady Hands/Quick Rewind/Breath Mark/Rubato just as well as it fits what's new,
and keeps the Dynamics/Grace/Ornament musical-language convention intact.

**What shipped**, chosen from a much larger explored set (research-grounded candidates spanning
chunking, the serial-position effect, method of loci, dual coding theory, and several more; the
full audit isn't reproduced here since the roster only had two open slots):

- **Constellation** replaces Metronome. As the call plays, a fading line traces between
  consecutively-played pads across the ring's open space (each pad's *pivot point* - the base near
  the Resonator, `pad.position + pad.pivot_offset`, which stays correct through Chaos's on-screen
  reshuffling since it reads the pad's live transform). Grounded in the method of loci - the most
  substantiated memory technique in the literature, whose own research says effectiveness depends
  on explicit binding between items and spatial positions, which is exactly what the trace does.
  Fades out once the response phase opens (`_constellation_alpha` tweened to 0). Trail length is
  capped by level (`trail`, 4→20 segments) so a long streak reads as a trailing comet, not a
  tangle - the one scaling risk flagged when this was proposed.
- **Resonant Tones** replaces Slow Fade. Reuses the tonal-hierarchy weighting Music Mode's
  generator already computes (`_scale_degree_weight`) to identify chord tones (tonic/third/fifth)
  for *any* mode's sequence - a pad's degree is fixed by its name via the scale's `ring_order`,
  independent of Chaos's reshuffling. Chord tones get a longer visual hold as they play
  (`extra_sec`, level-scaled), passing tones don't. Grounded in dual coding theory: giving
  structurally important notes their own distinct treatment is a second, independent encoding
  channel layered on top of pitch and order alone.

Both stayed inside Phrasing's actual lane (presentation only, no score, no forgiveness) and pass
rule 7 by construction: Constellation draws in the gaps between pads, never on them; Resonant Tones
only ever extends the *correct* pad's own glow, never adds a second one.

**Held for a later pass, not built now:** Echo of the Ring (stereo-panning notes to match ring
position - strong idea, but silent on mono audio/speaker setups, a real perceptibility risk) and
Contour (pitch-height-as-glow-intensity - unresolved overlap with Resonant Tones' "pitch
significance" territory, worth revisiting once Resonant Tones has actually been played and felt).

## Pass 5: Breath Mark's interval bug

**Status: implemented.** Playtest report: Breath Mark "feels kinda useless." Diagnosis didn't
need a new rule, just closer reading against rule 2 - it paused every **4th** step, but the game's
actual repeated-motif grouping (`CHUNK_SIZE`, what Harmonic Chain and Motif Bonus already key off)
is **3**. The pause was reinforcing a rhythm that didn't correspond to anything real in the
sequence, which is exactly the shape of a modifier that's technically perceptible (rule 1: you can
hear the pause) but doesn't actually change the play (rule 2: it's not teaching you anything true).
This is the same fix already scoped as "Phrase Break" during the Metronome search - kept the
existing name and slot rather than introducing a new identity, since a real breath mark belongs at
true phrase boundaries anyway; fixing the interval makes the name accurate for the first time.
Fixed in both `_play_sequence` (`(i + 1) % CHUNK_SIZE`) and `_play_duet_call` (`note_i %
CHUNK_SIZE`, corrected to count actual notes rather than raw Euclidean-rhythm steps including
rests). Levels/magnitude unchanged - only the interval was wrong.

## Pass 6: Second Wind re-scoped for the hearts baseline

**Status: implemented.** Not a modifier-audit finding on its own — see
`docs/scoring-escalation.md`'s "Hearts: the memory-research pass" for the full reasoning (a
build-independent life pool closing the "zero forgiveness for the first 2 rounds of every run" gap
the cash-out research surfaced). Noted here because it changes a Pass 2 entry: Second Wind's old
job (`"uses"`-capped forced-cashout on an otherwise-fatal miss) is retired, replaced with refilling
a heart on a voluntary cash-out once the streak's long enough (`refill_streak`, 8→1 by level),
raising `max_hearts` by 1 at L5. Safety Net/Unbreakable/Muffled Strike are otherwise unchanged from
Pass 2 - they now make a save cost no heart instead of independently forgiving the miss, but their
trigger conditions and rule-6 compliance are exactly as before.
