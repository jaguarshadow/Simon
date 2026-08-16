extends Control

signal _modifier_picked(id: String)

const PAD_COUNT := 8
const PAD_WIDTH := 70.0
const PAD_HEIGHT := 170.0
const BASE_RADIUS := 60.0
const RING_CENTER := Vector2(400.0, 400.0)

const MODIFIER_ROUND_INTERVAL := 3

# --- Modifier slot system (docs/modifier-expansion.md) ---
# One equipped modifier per category at a time. Picking a *different*
# modifier into a filled slot prompts swap-or-skip; picking the *same*
# modifier already equipped in its slot levels it up (1-5, capped).
const MODIFIER_CATEGORIES := ["multiplier", "defense", "tempo", "bonus_event"]
const CATEGORY_LABELS := {"multiplier": "Dynamics", "defense": "Grace", "tempo": "Phrasing", "bonus_event": "Ornament"}
const CATEGORY_COLORS := {
	"multiplier": Color(1.0, 0.78, 0.28),
	"defense": Color(0.35, 0.82, 0.78),
	"tempo": Color(0.62, 0.55, 0.98),
	"bonus_event": Color(0.98, 0.48, 0.68),
}
const MAX_MODIFIER_LEVEL := 5

# Musical chunking: sequences are built out of reused 3-note motifs some of
# the time (instead of always-fresh notes), tagged with a shared chunk id so
# Harmonic Chain/Motif Bonus have a real "repeated phrase" signal to key off.
const CHUNK_SIZE := 3
const CHUNK_REPEAT_CHANCE := 0.35

# How many recent hit timestamps to remember (see hit_timestamps_ms) - just
# needs the last one for recent_response_ms_per_note's rolling average, but
# kept as a small trailing window rather than a single value in case a
# future modifier wants more than one interval of history.
const PERFECT_PITCH_WINDOW := 4

# Rubato: recent repeat-back pace (avg ms/note over the last completed round)
# vs. this baseline decides "hesitant" (slow down) or "confident" (L5: speed
# up) relative to the mode's own baseline note spacing.
const RUBATO_BASELINE_MS_PER_NOTE := 650.0
const RUBATO_HESITANT_RATIO := 1.35
const RUBATO_CONFIDENT_RATIO := 0.75

const FORTISSIMO_FANFARE_BONUS := 50

const MODIFIERS := [
	# --- Multiplier ---
	{"id": "sharper_ear", "category": "multiplier", "icon": "♪", "title": "Sharper Ear", "desc": "Combo multiplier grows faster per hit", "power": false,
		"levels": [{"combo_growth_bonus": 0.03}, {"combo_growth_bonus": 0.06}, {"combo_growth_bonus": 0.09}, {"combo_growth_bonus": 0.12}, {"combo_growth_bonus": 0.15}]},
	{"id": "resonance", "category": "multiplier", "icon": "♦", "title": "Resonance", "desc": "Flat score bonus on all hits and cash-outs", "power": false,
		"levels": [{"bonus": 0.04}, {"bonus": 0.08}, {"bonus": 0.12}, {"bonus": 0.16}, {"bonus": 0.20}]},
	{"id": "crescendo", "category": "multiplier", "icon": "⟿", "title": "Crescendo", "desc": "Multiplier grows with waves completed this run", "power": false,
		"levels": [{"per_wave": 0.05}, {"per_wave": 0.08}, {"per_wave": 0.12}, {"per_wave": 0.18}, {"per_wave": 0.25, "multiplicative": true}]},
	{"id": "perfect_pitch", "category": "multiplier", "icon": "◎", "title": "Perfect Pitch", "desc": "Bonus for a smooth, even pace - fast or slow both count, only stopping and starting doesn't (matches the beat itself in Duet)", "power": false,
		"levels": [{"bonus": 0.05, "tolerance": 0.18}, {"bonus": 0.08, "tolerance": 0.22}, {"bonus": 0.12, "tolerance": 0.26}, {"bonus": 0.16, "tolerance": 0.30}, {"bonus": 0.20, "tolerance": 0.35}]},
	{"id": "harmonic_chain", "category": "multiplier", "icon": "⛓", "title": "Harmonic Chain", "desc": "Stacking bonus for consecutive hits within a motif", "power": false,
		"levels": [{"increment": 0.02}, {"increment": 0.03}, {"increment": 0.04}, {"increment": 0.05}, {"increment": 0.06, "carry_across_chunks": true}]},
	{"id": "fortissimo", "category": "multiplier", "icon": "✺", "title": "Fortissimo", "desc": "Multiplier once your streak passes your own best this run", "power": true,
		"unlock": {"type": "waves", "value": 10, "text": "Survive 10 waves in one run"},
		"levels": [{"margin": 3, "mult": 1.3}, {"margin": 2, "mult": 1.4}, {"margin": 1, "mult": 1.6}, {"margin": 0, "mult": 1.8}, {"margin": -1, "mult": 2.2, "fanfare": true}]},
	# --- Defense ---
	{"id": "safety_net", "category": "defense", "icon": "❖", "title": "Safety Net", "desc": "Forgives a miss for free, with a hint, whenever you're at or past your best streak this run", "power": false,
		"levels": [{"grace": 0}, {"grace": 1}, {"grace": 2}, {"grace": 3}, {"grace": 4, "hint_notes": 2}]},
	{"id": "echo_chamber", "category": "defense", "icon": "☍", "title": "Echo Chamber", "desc": "The correct pad softly echoes on its own when you hesitate", "power": false,
		"levels": [{"hesitation_mult": 2.4}, {"hesitation_mult": 2.0}, {"hesitation_mult": 1.7}, {"hesitation_mult": 1.4}, {"hesitation_mult": 1.15, "peek_notes": 2}]},
	{"id": "muffled_strike", "category": "defense", "icon": "◔", "title": "Muffled Strike", "desc": "Chance to forgive a fatal miss, growing the deeper into your streak you are", "power": false,
		"levels": [{"chance": 0.10}, {"chance": 0.18}, {"chance": 0.28}, {"chance": 0.40}, {"chance": 0.55}]},
	{"id": "grounding_resonance", "category": "defense", "icon": "≋", "title": "Grounding Resonance", "desc": "A fatal miss banks a % of your unbanked pool instead of losing it all", "power": false,
		"levels": [{"pct": 0.10}, {"pct": 0.18}, {"pct": 0.25}, {"pct": 0.32}, {"pct": 0.40}]},
	{"id": "second_wind", "category": "defense", "icon": "↺", "title": "Second Wind", "desc": "Cashing out refills a heart once your streak is long enough", "power": true,
		"unlock": {"type": "flag", "key": "zero_miss_wave", "text": "Complete a wave with zero misses"},
		"levels": [{"refill_streak": 8}, {"refill_streak": 6}, {"refill_streak": 4}, {"refill_streak": 2}, {"refill_streak": 1, "bonus_max_heart": true}]},
	{"id": "unbreakable", "category": "defense", "icon": "⛨", "title": "Unbreakable", "desc": "The first miss each streak is forgiven free, retaining more of your combo the higher the level", "power": true,
		"unlock": {"type": "flag", "key": "zero_miss_wave", "text": "Complete a wave with zero misses"},
		"levels": [{"combo_retain_pct": 0.7}, {"combo_retain_pct": 0.78}, {"combo_retain_pct": 0.85}, {"combo_retain_pct": 0.92}, {"combo_retain_pct": 1.0}]},
	# --- Tempo ---
	{"id": "steady_hands", "category": "tempo", "icon": "⏱", "title": "Steady Hands", "desc": "Sequence plays back slower", "power": false,
		"levels": [{"pct": 0.08}, {"pct": 0.15}, {"pct": 0.22}, {"pct": 0.30}, {"pct": 0.40}]},
	{"id": "quick_rewind", "category": "tempo", "icon": "⏪", "title": "Quick Rewind", "desc": "Automatically replays the sequence when you're visibly stuck", "power": false,
		"levels": [{"speed_mult": 6.0, "hesitation_mult": 3.2}, {"speed_mult": 4.5, "hesitation_mult": 2.8}, {"speed_mult": 3.5, "hesitation_mult": 2.4}, {"speed_mult": 2.5, "hesitation_mult": 2.0}, {"speed_mult": 1.8, "hesitation_mult": 1.7}]},
	{"id": "constellation", "category": "tempo", "icon": "✷", "title": "Constellation", "desc": "Traces the sequence's shape across the ring as it plays, fading as your turn begins", "power": false,
		"levels": [{"trail": 4}, {"trail": 7}, {"trail": 10}, {"trail": 14}, {"trail": 20}]},
	{"id": "resonant_tones", "category": "tempo", "icon": "◈", "title": "Resonant Tones", "desc": "Chord tones (the tonic and fifth) ring out fuller and longer as the sequence plays", "power": false,
		"levels": [{"extra_sec": 0.15}, {"extra_sec": 0.25}, {"extra_sec": 0.35}, {"extra_sec": 0.45}, {"extra_sec": 0.6}]},
	{"id": "breath_mark", "category": "tempo", "icon": "❜", "title": "Breath Mark", "desc": "A slightly longer pause where a musical phrase actually ends", "power": false,
		"levels": [{"pct": 0.10}, {"pct": 0.20}, {"pct": 0.32}, {"pct": 0.45}, {"pct": 0.60}]},
	{"id": "rubato", "category": "tempo", "icon": "〜", "title": "Rubato", "desc": "Adaptive pacing: slows when you hesitate", "power": true,
		"unlock": {"type": "combo", "value": 25, "text": "Reach a 25-combo in one run"},
		"levels": [{"level": 1}, {"level": 2}, {"level": 3}, {"level": 4}, {"level": 5, "two_directional": true}]},
	# --- Bonus-Event ---
	{"id": "golden_step", "category": "bonus_event", "icon": "★", "title": "Golden Step", "desc": "Extra step(s) per round worth 3x points", "power": false,
		"levels": [{"count": 1}, {"count": 2}, {"count": 3}, {"count": 4}, {"count": 5}]},
	{"id": "double_down", "category": "bonus_event", "icon": "⚂", "title": "Double Down", "desc": "One flagged step per streak gambles the cash-out curve", "power": false,
		"levels": [{"boost": 2}, {"boost": 3}, {"boost": 5}, {"boost": 7}, {"boost": 10, "chain": true}]},
	{"id": "encore", "category": "bonus_event", "icon": "❢", "title": "Encore", "desc": "Cash-out replays the final phrase once more for a bonus", "power": false,
		"levels": [{"pct": 0.50}, {"pct": 0.65}, {"pct": 0.80}, {"pct": 0.95}, {"pct": 1.10}]},
	{"id": "lucky_strike", "category": "bonus_event", "icon": "✦", "title": "Lucky Strike", "desc": "Small chance of a surprise bonus-value pad each round", "power": false,
		"levels": [{"chance": 0.05, "value_mult": 2.0}, {"chance": 0.09, "value_mult": 2.2}, {"chance": 0.14, "value_mult": 2.4}, {"chance": 0.20, "value_mult": 2.6}, {"chance": 0.28, "value_mult": 3.0}]},
	{"id": "motif_bonus", "category": "bonus_event", "icon": "❦", "title": "Motif Bonus", "desc": "Flat bonus for correctly landing a full repeated motif", "power": false,
		"levels": [{"amount": 15}, {"amount": 25}, {"amount": 40}, {"amount": 60}, {"amount": 90}]},
	{"id": "grand_finale", "category": "bonus_event", "icon": "☀", "title": "Grand Finale", "desc": "Double or Nothing: wager the unbanked pool on completing one more round", "power": true,
		"unlock": {"type": "flag", "key": "five_cashouts", "text": "Cash out 5 times in one run"},
		"levels": [{"mult": 1.5}, {"mult": 1.8}, {"mult": 2.2}, {"mult": 2.7}, {"mult": 3.5, "insured": true}]},
]

# Wave-reset scoring escalation, player-triggered version: unlike the design
# doc's original forced-cap-at-a-climbing-ceiling shape, there is no forced
# reset - the player decides when to cash out a growing sequence/phrase for
# a bonus (deliberately rejected the forced version: interrupting a player's
# groove mid-sequence read as jarring rather than tense). The bonus scales
# quadratically with how long the current streak has run - risk of a miss
# (which forfeits the unbanked bonus, not the run or its already-earned
# score) is what discourages riding forever, not an artificial cutoff.
# Applies identically to Normal, Chaos, and Duet.
const WAVE_RESET_LENGTH := 0

# Visual/spatial sequence-memory research puts natural human span at ~8-10
# items (higher than plain digit span, likely because a pad's position/
# color/pitch are all encoding the same note at once - free dual coding);
# the hippocampus takes over past that, a real mode-switch to a less
# reliable system, not just gradual fatigue. Shared by the cash-out formula
# and Chaos's speed ramp below, so both curves inflect at the same real
# threshold instead of each using its own unrelated, by-feel number.
const MEMORY_SPAN_CEILING := 8

# Cash-out streak bonus: piecewise, not a pure quadratic from zero. Below
# MEMORY_SPAN_CEILING the bonus is pure linear growth - "normal" territory,
# a safe/disciplined cash-out here should feel calm, not like leaving a
# runaway curve on the table. Past it, the steep quadratic term kicks in
# specifically for the zone where the player is genuinely fighting the
# memory handoff, which is exactly where the thrill-of-beating-the-odds
# payout belongs. CASHOUT_LINEAR_K/CASHOUT_QUADRATIC_K were picked so the
# two pieces agree exactly at the ceiling (s=8 gives the same 128 either
# way) - a continuity anchor, not just two independently-guessed numbers.
const CASHOUT_LINEAR_K := 16.0
const CASHOUT_QUADRATIC_K := 10.0

# Cash-Out Floor: closes the "spam tiny risk-free cash-outs forever" loophole
# (a patient player could otherwise trivially satisfy every milestone gate -
# Fortissimo's 10 waves, the zero-miss-wave gate, Grand Finale's 5 cash-outs -
# without ever taking on real memory risk). Each cash-out raises the minimum
# `unbanked_points` required before Cash Out works again; the raise shrinks
# each time (diminishing curve) and never exceeds the cap, so a very long run
# doesn't eventually get locked out of ever cashing out safely again - it
# just can't be done in tiny, risk-free increments forever.
const CASHOUT_FLOOR_BASE := 35.0
const CASHOUT_FLOOR_DECAY := 0.85
const CASHOUT_FLOOR_CAP := 250

# Muffled Strike (Defense): redesigned per docs/modifier-audit.md - a flat
# per-miss chance was "a coin flip with no agency attached" (pillar 2, no
# decision the player could make about it). Its listed level chance is now
# the ceiling reached at/after this many combo hits, ramping linearly from 0
# below that - so pushing a streak deeper genuinely raises your own safety
# margin, mirroring Fortissimo's "reward for going further" shape but on the
# Defense axis instead of Multiplier.
const MUFFLED_STRIKE_RAMP_COMBO := 20.0

# Baseline per-hit combo-multiplier growth with no Sharper Ear equipped -
# shared between the reset in _recompute_pure_modifier_stats() and the
# counterfactual used to compute Sharper Ear's own cascade popup delta.
const BASE_COMBO_GROWTH := 0.1

# Music Mode: rhythm generated as a Euclidean pattern (Bjorklund's algorithm)
# over a fixed 16-step bar, re-rolled each phrase for variety.
const MUSIC_RHYTHM_STEPS := 16
const MUSIC_PULSES_MIN := 5
const MUSIC_PULSES_MAX := 9
# Scales with a half-step or tritone in them - capped to a smaller max leap
# than the (dissonance-proof) pentatonic scales to avoid the harshest jumps.
const MUSIC_NARROW_LEAP_SCALES := ["d_minor", "c_major_diatonic", "chromatic_run"]
const MUSIC_PENTATONIC_MAX_LEAP := 4
const MUSIC_NARROW_MAX_LEAP := 3
const MUSIC_PHRASE_BARS := 4
# Melodic arch (see docs/music-mode.md#melodic-arch) - corpus studies of real
# melodies (Huron 1996, Essen folksong database) find the single most common
# phrase-level shape by a wide margin is an arch: rise, then fall. The
# per-note step-inertia/post-skip-reversal rules above only shape local
# motion, with nothing steering the phrase's overall trajectory - this is a
# soft per-note nudge toward that trajectory, layered on top rather than
# replacing the local rules (it's checked after they pick a direction, and
# skipped for gap-fill reversals - see _music_next_delta()).
const MUSIC_ARCH_BIAS := 0.3
# Chord tones on strong beats (see docs/music-mode.md#chord-tones-on-strong-
# beats) - see _nearest_chord_tone_degree() for the mechanism.
const MUSIC_STRONG_BEAT_CHORD_TONE_CHANCE := 0.4
# Anchor-note return (handpan "ding"/drone technique - see
# docs/music-mode.md#idioms-borrowed-from-how-the-real-instrument-is-played):
# a small
# per-note chance of weaving back to the tonic mid-phrase, not just at the
# phrase-boundary resolution below. Frequency is player-tunable - see the
# "anchor_return" idiom slider (MUSIC_IDIOM_RANGES) above.
# Zigzag / alternating-side contour (see docs/music-mode.md#idioms-borrowed-from-how-the-real-instrument-is-played -
# handpan layouts are numbered so players alternate hands across the ring;
# this is that physical constraint expressed as a melodic bias). Only used
# when there's no established scale-degree direction to defer to (session
# start, right after a phrase-end or anchor-return reset) - see
# _music_next_delta(). Bias strength is player-tunable via the "zigzag_bias"
# idiom slider.
# Groove repetition (see docs/music-mode.md#idioms-borrowed-from-how-the-real-instrument-is-played - tongue-drum
# tutorials teach practicing over a repeating loop rather than constantly
# varying): after playing a bar's rhythm, a chance to hold that same
# Euclidean pattern for a couple more bars instead of re-rolling every bar.
# Hold chance is player-tunable via the "groove_repeats" idiom slider; the
# hold length itself is not.
const MUSIC_GROOVE_HOLD_BARS := 2
# Ghost notes (see docs/music-mode.md#idioms-borrowed-from-how-the-real-instrument-is-played) - very light, near-
# silent filler taps on the last-played pad, dropped into the Euclidean
# pattern's silent steps. Purely decorative: doesn't touch the melody walk.
# Frequency is player-tunable via the "ghost_notes" idiom slider.
const MUSIC_GHOST_VOLUME := 0.12
const MUSIC_GHOST_DECAY := 10.0
const MUSIC_GHOST_FLASH_FRACTION := 0.4
# Glissando sweep (see docs/music-mode.md#idioms-borrowed-from-how-the-real-instrument-is-played) - a rare full-ring
# run between phrases, single direction, quiet and quick. Frequency is
# player-tunable via the "glissando" idiom slider. Spacing/decay are
# clamped to a floor, not just a ceiling - the original fraction-of-
# step_duration-only version produced ~30ms blips with a fast decay, too
# short for the struck-tongue harmonic content to read as a pitch at all
# (sounded like electronic beeps instead of an instrument). Longer notes
# with a slower decay let each one ring into the next for a legato slide.
const MUSIC_GLISSANDO_SPACING_FRACTION := 0.6
const MUSIC_GLISSANDO_MIN_SPACING := 0.09
const MUSIC_GLISSANDO_MAX_SPACING := 0.16
const MUSIC_GLISSANDO_VOLUME := 0.28
const MUSIC_GLISSANDO_DECAY := 4.5
const MUSIC_GLISSANDO_FLASH_FRACTION := 0.75
# Canonical riff shapes (see docs/music-mode.md#idioms-borrowed-from-how-the-real-instrument-is-played) - small
# numbered shapes tongue-drum beginners are taught, expressed as scale-degree
# offsets from a phrase's opening tonic. Occasionally seeded instead of a
# pure random walk at the start of a phrase. Frequency is player-tunable via
# the "riff_shapes" idiom slider.
const MUSIC_RIFF_SHAPES := [[0, 2, 4, 2], [0, 1, 2, 3, 4], [0, 2, 1, 3, 0], [0, 4, 2, 0]]
# Normal Mode borrows three of these idioms (anchor return, zigzag contour,
# riff shapes) since they're pure note-selection bias - they change which
# pad the walk lands on but never add/remove a note from `sequence`, so the
# memorized sequence and its length are untouched (see
# docs/music-mode.md#idioms-borrowed-from-how-the-real-instrument-is-played).
# Fixed at their tuned defaults rather than wired to the
# Music Mode idiom sliders - those sliders are for passive-listening
# tuning and shouldn't silently change what a memory-game run sounds like.
# Ghost notes/groove repeats/glissando are NOT ported: ghost notes would
# read as an extra note to memorize, and groove/glissando have no meaning
# without Music Mode's bar/rhythm structure.
const NORMAL_ANCHOR_RETURN_CHANCE := 0.12
const NORMAL_ZIGZAG_BIAS := 0.75
const NORMAL_RIFF_CHANCE := 0.25
# The 30% flat "repeat" chance in the walk, combined with edges clamping a
# blocked step back onto the same degree, can otherwise chain into long
# runs of the identical note - hard-cap it instead of leaving it to chance.
const BASE_REPEAT_CHANCE := 0.30
const REPEAT_DECAY := 0.4
const STEP_TO_NON_REPEAT_RATIO := 0.55 / 0.70
# Normal Mode's sequence is one continuous, ever-growing phrase with no bar
# structure to hang periodic tonic resolution off of (unlike Music/Duet's
# 4-bar phrases) - so it gets its own note-count-based phrase length instead.
const NORMAL_PHRASE_LENGTH := 8
# Duet Mode timing-accuracy, scored on top of note-identity correctness (see
# docs/game-modes.md) - affects points only, never pass/fail. The multiplier
# is continuous rather than tiered: it's DUET_MULT_MAX exactly on the beat,
# falls off smoothly to DUET_MULT_MIN by DUET_MULT_FALLOFF_SEC offset, and
# stays at the floor beyond that - so a 20ms-off hit clearly outscores a
# 140ms-off one instead of both landing in the same bucket. DUET_PERFECT_WINDOW
# and DUET_GOOD_WINDOW are looser thresholds used only to pick which judgment
# word (_duet_timing_judgment) pops up after the press - cosmetic labeling on
# top of the continuous score, not a second scoring system.
# DUET_NOTE_GRACE_SEC is a flat, generous per-note deadline (unrelated to the
# rhythmic grid) so a miss reflects real inattention rather than
# reaction-time pressure.
const DUET_PERFECT_WINDOW := 0.06
const DUET_GOOD_WINDOW := 0.13
const DUET_MULT_FALLOFF_SEC := 0.2
const DUET_MULT_MAX := 1.5
const DUET_MULT_MIN := 0.5
const DUET_NOTE_GRACE_SEC := 1.2
# Tempo ramps with round count, same capped-ramp idea as Chaos Mode's speed
# increase (see docs/game-modes.md) - starts modest, never runs away.
const DUET_BPM_BASE_MIN := 88.0
const DUET_BPM_BASE_MAX := 100.0
const DUET_BPM_RAMP_PER_ROUND := 2.5
const DUET_BPM_CAP := 150.0
# Duet's timing gauge: a pie-style fill over the Resonator's own disc
# (radius DUET_RING_RADIUS) that fills from empty to full across the gap
# between the previous pulse and the note currently due, so the beat the
# player is echoing is visible, not just audible. Full = press now.
const DUET_RING_RADIUS := 78.0
const DUET_RING_FLASH_SEC := 0.28
# Randomized once per Music Mode session (not per phrase) so tempo doesn't
# jitter bar-to-bar.
const MUSIC_BPM_MIN := 55.0
const MUSIC_BPM_MAX := 85.0
const MUSIC_FLASH_FRACTION := 0.7
const MUSIC_FLASH_MAX := 0.35
# Faster decay than the default 3.2 (used for slow, one-note-at-a-time
# sequence recall) - at Music Mode's note spacing, the default's ~1.4s
# audible tail overlaps several notes at once and blurs the rhythm.
const MUSIC_DECAY_RATE := 8.0
const MUSIC_VOLUME := 0.4
# The Euclidean generator always places an onset at step 0 of the pattern,
# so accenting step 0 accents the bar's downbeat.
const MUSIC_ACCENT_DECAY := 5.0
const MUSIC_ACCENT_VOLUME := 0.55
const SCALES := [
	{"id": "d_minor_pentatonic", "name": "D Minor\nPentatonic", "tones": [146.83, 174.61, 196.0, 220.0, 261.63, 293.66, 349.23, 440.0], "notes": ["D", "F", "G", "A", "C", "D", "F", "A"], "ring_order": [0, 2, 4, 1, 6, 3, 7, 5]},
	{"id": "c_major_pentatonic", "name": "C Major\nPentatonic", "tones": [261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25], "notes": ["C", "D", "E", "G", "A", "C", "D", "E"], "ring_order": [0, 2, 7, 4, 1, 6, 3, 5]},
	{"id": "d_akebono", "name": "D Akebono", "tones": [293.66, 329.63, 349.23, 440.0, 466.16, 587.33, 659.25, 698.46], "notes": ["D", "E", "F", "A", "Bb", "D", "E", "F"], "ring_order": [0, 1, 6, 3, 2, 7, 4, 5]},
	{"id": "d_minor", "name": "D Minor\nDiatonic", "tones": [146.83, 164.81, 174.61, 196.0, 220.0, 233.08, 261.63, 293.66], "notes": ["D", "E", "F", "G", "A", "Bb", "C", "D"], "unlock": {"type": "round", "value": 10}, "ring_order": [0, 3, 5, 2, 6, 1, 4, 7]},
	{"id": "e_minor_pentatonic", "name": "E Minor\nPentatonic", "tones": [164.81, 196.0, 220.0, 246.94, 293.66, 329.63, 392.0, 440.0], "notes": ["E", "G", "A", "B", "D", "E", "G", "A"], "unlock": {"type": "round", "value": 5}, "ring_order": [0, 2, 7, 4, 1, 6, 3, 5]},
	{"id": "g_major_pentatonic", "name": "G Major\nPentatonic", "tones": [196.0, 220.0, 246.94, 293.66, 329.63, 392.0, 440.0, 493.88], "notes": ["G", "A", "B", "D", "E", "G", "A", "B"], "unlock": {"type": "score", "value": 500}, "ring_order": [0, 2, 7, 4, 1, 6, 3, 5]},
	{"id": "c_major_diatonic", "name": "C Major\nDiatonic", "tones": [130.81, 146.83, 164.81, 174.61, 196.0, 220.0, 246.94, 261.63], "notes": ["C", "D", "E", "F", "G", "A", "B", "C"], "unlock": {"type": "combo", "value": 15}, "ring_order": [0, 3, 1, 5, 2, 6, 4, 7]},
	{"id": "chromatic_run", "name": "Chromatic\nRun", "tones": [130.81, 138.59, 146.83, 155.56, 164.81, 174.61, 185.0, 196.0], "notes": ["C", "C#", "D", "D#", "E", "F", "F#", "G"], "unlock": {"type": "round", "value": 15}, "ring_order": [0, 4, 1, 6, 3, 7, 2, 5]},
	{"id": "a_minor_pentatonic", "name": "A Minor\nPentatonic", "tones": [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33], "notes": ["A", "C", "D", "E", "G", "A", "C", "D"], "unlock": {"type": "round", "value": 25}, "ring_order": [0, 2, 7, 4, 1, 6, 3, 5]},
	{"id": "a_akebono_pentatonic", "name": "A Akebono\nPentatonic", "tones": [220.0, 246.94, 261.63, 329.63, 349.23, 440.0, 493.88, 523.25], "notes": ["A", "B", "C", "E", "F", "A", "B", "C"], "unlock": {"type": "score", "value": 3000}, "ring_order": [0, 1, 6, 3, 2, 7, 4, 5]},
	{"id": "e_major_pentatonic", "name": "E Major\nPentatonic", "tones": [164.81, 185.0, 207.65, 246.94, 277.18, 329.63, 369.99, 415.3], "notes": ["E", "F#", "G#", "B", "C#", "E", "F#", "G#"], "unlock": {"type": "combo", "value": 25}, "ring_order": [0, 2, 7, 4, 1, 6, 3, 5]},
]

const PALETTES := [
	{"id": "anodized", "name": "Anodized", "hue_start": 0.0, "hue_end": 1.0, "wrap": true, "sat": 0.55, "val": 0.55, "lit_sat": 0.4, "lit_val": 1.0},
	{"id": "pastel", "name": "Pastel Dream", "hue_start": 0.0, "hue_end": 1.0, "wrap": true, "sat": 0.35, "val": 0.78, "lit_sat": 0.25, "lit_val": 0.98},
	{"id": "sunset", "name": "Sunset", "hue_start": 0.0, "hue_end": 0.13, "wrap": false, "sat": 0.65, "val": 0.6, "lit_sat": 0.5, "lit_val": 1.0},
	{"id": "ocean", "name": "Ocean Steel", "hue_start": 0.48, "hue_end": 0.68, "wrap": false, "sat": 0.5, "val": 0.5, "lit_sat": 0.35, "lit_val": 0.95},
	{"id": "monochrome_steel", "name": "Monochrome\nSteel", "hue_start": 0.6, "hue_end": 0.62, "wrap": false, "sat": 0.08, "val": 0.55, "lit_sat": 0.05, "lit_val": 0.95, "unlock": {"type": "round", "value": 5}},
	{"id": "neon", "name": "Neon", "hue_start": 0.0, "hue_end": 1.0, "wrap": true, "sat": 0.85, "val": 0.95, "lit_sat": 0.7, "lit_val": 1.0, "unlock": {"type": "score", "value": 500}},
	{"id": "forest", "name": "Forest", "hue_start": 0.25, "hue_end": 0.42, "wrap": false, "sat": 0.55, "val": 0.5, "lit_sat": 0.4, "lit_val": 0.9, "unlock": {"type": "combo", "value": 15}},
	{"id": "royal", "name": "Royal", "hue_start": 0.7, "hue_end": 0.87, "wrap": false, "sat": 0.6, "val": 0.55, "lit_sat": 0.45, "lit_val": 0.95, "unlock": {"type": "round", "value": 15}},
	{"id": "galaxy", "name": "Galaxy", "shader": "res://shaders/galaxy.gdshader", "accent_color": Color(0.55, 0.35, 0.85), "unlock": {"type": "round", "value": 20}},
	{"id": "aurora", "name": "Aurora", "shader": "res://shaders/aurora.gdshader", "accent_color": Color(0.2, 0.85, 0.6), "unlock": {"type": "score", "value": 1500}},
	{"id": "graphite_spectrum", "name": "Graphite\nSpectrum", "colors": [Color(0.263, 0.733, 0.655), Color(0.216, 0.730, 0.717), Color(0.211, 0.722, 0.773), Color(0.250, 0.710, 0.823), Color(0.313, 0.695, 0.863), Color(0.384, 0.676, 0.893), Color(0.457, 0.656, 0.912), Color(0.526, 0.635, 0.918)]},
]

# Every theme carries its pad look directly as pad_style, so Theme is the
# only axis the player chooses in Settings - there's no separate Palette
# picker to fall out of sync with it.
const THEMES := [
	{"id": "premium_minimal", "name": "Premium &\nMinimal", "bg": Color(0.046, 0.053, 0.060), "panel": Color(0.082, 0.092, 0.103), "border": Color(0.165, 0.181, 0.199), "text": Color(0.914, 0.923, 0.932), "text_muted": Color(0.520, 0.540, 0.561), "accent": Color(0.000, 0.767, 0.859), "accent2": Color(0.523, 0.673, 1.000)},
	{"id": "cosmic_atmospheric", "name": "Cosmic &\nAtmospheric", "shader": "res://shaders/galaxy.gdshader", "resonator_color": Color(0.1, 0.08, 0.18, 1), "background_color": Color(0.02, 0.015, 0.05, 1), "bg": Color(0.039, 0.030, 0.085), "panel": Color(0.077, 0.066, 0.135), "border": Color(0.198, 0.181, 0.293), "text": Color(0.933, 0.931, 0.960), "text_muted": Color(0.595, 0.590, 0.644), "accent": Color(0.718, 0.526, 1.000), "accent2": Color(0.942, 0.438, 0.745), "unlock": {"type": "round", "value": 20},
		"pad_style": {"shader": "res://shaders/galaxy.gdshader", "accent_color": Color(0.718, 0.526, 1.000)}},
	{"id": "warm_tactile", "name": "Warm &\nTactile", "bg": Color(0.104, 0.082, 0.057), "panel": Color(0.157, 0.126, 0.091), "border": Color(0.253, 0.211, 0.164), "text": Color(0.949, 0.932, 0.913), "text_muted": Color(0.621, 0.592, 0.559), "accent": Color(0.791, 0.617, 0.199), "accent2": Color(0.921, 0.510, 0.481), "unlock": {"type": "round", "value": 3},
		"pad_style": {"colors": [Color(0.854, 0.506, 0.534), Color(0.857, 0.511, 0.487), Color(0.854, 0.519, 0.442), Color(0.846, 0.529, 0.398), Color(0.832, 0.542, 0.358), Color(0.813, 0.557, 0.323), Color(0.789, 0.573, 0.296), Color(0.759, 0.591, 0.279)]}},
	{"id": "playful_colorful", "name": "Playful &\nColorful", "bg": Color(0.956, 0.948, 0.919), "panel": Color(0.990, 0.987, 0.976), "border": Color(0.869, 0.858, 0.815), "text": Color(0.134, 0.123, 0.080), "text_muted": Color(0.402, 0.390, 0.340), "accent": Color(1.000, 0.412, 0.445), "accent2": Color(0.268, 0.646, 1.000), "unlock": {"type": "score", "value": 300},
		"pad_style": {"colors": [Color(0.983, 0.425, 0.627), Color(0.992, 0.473, 0.201), Color(0.816, 0.613, 0.000), Color(0.437, 0.738, 0.225), Color(0.000, 0.780, 0.662), Color(0.000, 0.724, 0.973), Color(0.477, 0.606, 1.000), Color(0.808, 0.491, 0.944)]}},
	{"id": "monochrome_noir", "name": "Monochrome\nNoir", "bg": Color(0.007, 0.007, 0.007), "panel": Color(0.028, 0.028, 0.028), "border": Color(0.141, 0.141, 0.141), "text": Color(0.961, 0.961, 0.961), "text_muted": Color(0.445, 0.445, 0.445), "accent": Color(0.703, 0.134, 0.158), "accent2": Color(0.806, 0.806, 0.806), "unlock": {"type": "combo", "value": 8},
		"pad_style": {"colors": [Color(0.104, 0.104, 0.104), Color(0.189, 0.189, 0.189), Color(0.281, 0.281, 0.281), Color(0.378, 0.378, 0.378), Color(0.782, 0.293, 0.280), Color(0.585, 0.585, 0.585), Color(0.694, 0.694, 0.694), Color(0.806, 0.806, 0.806)]}},
	{"id": "retro_arcade", "name": "Retro\nArcade", "bg": Color(0.008, 0.029, 0.012), "panel": Color(0.022, 0.064, 0.030), "border": Color(0.116, 0.230, 0.121), "text": Color(0.499, 0.926, 0.401), "text_muted": Color(0.316, 0.501, 0.275), "accent": Color(0.499, 0.926, 0.401), "accent2": Color(1.000, 0.669, 0.000), "unlock": {"type": "score", "value": 1000},
		"pad_style": {"shader": "res://shaders/scanline.gdshader", "accent_color": Color(0.499, 0.926, 0.401)}},
	{"id": "zen_garden", "name": "Zen\nGarden", "bg": Color(0.896, 0.916, 0.891), "panel": Color(0.953, 0.965, 0.950), "border": Color(0.787, 0.817, 0.781), "text": Color(0.112, 0.141, 0.106), "text_muted": Color(0.366, 0.401, 0.359), "accent": Color(0.420, 0.617, 0.460), "accent2": Color(0.320, 0.607, 0.694), "unlock": {"type": "round", "value": 8},
		"pad_style": {"colors": [Color(0.636, 0.603, 0.403), Color(0.590, 0.619, 0.422), Color(0.541, 0.633, 0.453), Color(0.492, 0.644, 0.493), Color(0.446, 0.651, 0.539), Color(0.408, 0.654, 0.587), Color(0.385, 0.653, 0.634), Color(0.380, 0.647, 0.678)]}},
	{"id": "raw_steel", "name": "Raw\nSteel", "bg": Color(0.099, 0.105, 0.111), "panel": Color(0.144, 0.151, 0.160), "border": Color(0.248, 0.262, 0.277), "text": Color(0.916, 0.922, 0.929), "text_muted": Color(0.551, 0.563, 0.575), "accent": Color(0.568, 0.629, 0.694), "accent2": Color(0.801, 0.454, 0.332), "unlock": {"type": "combo", "value": 20},
		"pad_style": {"colors": [Color(0.456, 0.638, 0.624), Color(0.453, 0.636, 0.642), Color(0.454, 0.633, 0.660), Color(0.459, 0.629, 0.675), Color(0.467, 0.625, 0.689), Color(0.479, 0.620, 0.701), Color(0.493, 0.614, 0.710), Color(0.510, 0.608, 0.717)]}},
	{"id": "solar_flare", "name": "Solar\nFlare", "bg": Color(0.091, 0.047, 0.040), "panel": Color(0.145, 0.087, 0.077), "border": Color(0.255, 0.177, 0.164), "text": Color(0.973, 0.940, 0.929), "text_muted": Color(0.608, 0.545, 0.533), "accent": Color(0.986, 0.353, 0.276), "accent2": Color(0.905, 0.625, 0.000), "unlock": {"type": "score", "value": 2500},
		"pad_style": {"shader": "res://shaders/ember.gdshader", "accent_color": Color(0.986, 0.353, 0.276)}},
]
const DEFAULT_RESONATOR_COLOR := Color(0.35, 0.37, 0.4, 1)
const DEFAULT_BACKGROUND_COLOR := Color(0.05, 0.05, 0.07, 1)

const SAVE_PATH := "user://simon_save.json"
const EASTER_EGG_CODE := "hubert"

const ONBOARDING_STEPS := [
	{"title": "Watch, Then Repeat", "body": "Each round, the pads flash a sequence of notes. Repeat it back by pressing the same pads in order - the sequence grows by one note every round you clear."},
	{"title": "Score & Combo", "body": "Correct hits build a combo streak, which boosts your score multiplier. A forgiven miss halves your combo instead of wiping it out."},
	{"title": "Cash Out Anytime", "body": "Your points build up as an unbanked streak total while you play. Tap Cash Out whenever you want to bank them - plus a bonus that grows the longer the streak ran - and start a fresh, short sequence. A miss before you cash out forfeits that streak's points, so bank when you don't want to risk it."},
	{"title": "Five Ways to Play", "body": "Normal Mode is the standard growing sequence. Chaos reshuffles the pads and speeds up each round. Duet has the game play a short phrase for you to echo back exactly. Zen has no sequence or fail state - just play freely. Music plays itself for chill, hands-off listening."},
	{"title": "Modifier Choices", "body": "Every 3rd round, pick one of three modifiers. Dynamics, Grace, Tempo, and Ornament each get one equipped slot - picking the same one again levels it up, picking a new one swaps it in."},
]

# FAQ panel copy - short, direct, a little playful. Built into a scrollable
# list at runtime (_build_faq_content) rather than hand-laid-out in the
# scene, same reasoning as everything else generated from data in this file.
const FAQ_ENTRIES := [
	{"q": "What is this?", "a": "A memory game, rebuilt as a steel tongue drum."},
	{"q": "Why did you build this?", "a": "To practice with godot, other dev tools, and have fun."},
	{"q": "How does Music Mode write its own songs?", "a": "Two generators, recomputed every bar. Rhythm comes from Bjorklund's algorithm, which spaces out N hits as evenly as possible across 16 steps - the same math behind a lot of real-world grooves. Melody is a random walk over the scale, biased so a step tends to keep going the same direction and a leap tends to reverse right after, because that's roughly how real melodies move - and each phrase quietly arcs upward then back down, the single most common shape in a 6000-song corpus study of folk melodies. On top of that walk sit six idioms borrowed from actual handpan/tongue-drum playing technique - drone returns to the tonic, a zigzag contour across the ring, glissando sweeps, ghost notes, groove repeats, and canonical riff shapes. Full writeup in docs/music-mode.md."},
	{"q": "Why does the music favor some notes over others?", "a": "On purpose - real melodies lean on the tonic and its chord tones instead of spreading evenly across the scale (music-cognition researchers call this 'tonal hierarchy'), and the strong beat of every bar leans toward a chord tone too, the same way real melodies put stable notes on the downbeat and save the in-between tones for passing through. Getting the balance right took three rounds of tuning against real playback logs - the first two fixes looked plausible until the numbers said otherwise."},
	{"q": "What do the sliders in Music Mode's Tune panel do?", "a": "Each of the six playing idioms above gets its own slider, defaulting to the middle (exactly the tuned amount that ships by default). Drag toward 0% to turn an idiom off, or toward 100% for a lot more of it. They're session-only - back to 50% every time you start Music Mode - and they don't touch Normal/Chaos Mode's sequence generation at all."},
	{"q": "How does scoring work?", "a": "Points pile up in an unbanked pool while you play. Hit Cash Out whenever you want to lock them in - longer streak, bigger bonus - but a miss before you cash out forfeits whatever's still unbanked. Everything already banked is yours forever."},
	{"q": "What are modifiers?", "a": "Every 3rd round you draft one. Four slots - Dynamics, Grace, Tempo, Ornament - one modifier equipped per slot at a time. Picking the same one again levels it up (1 to 5); picking a different one swaps it in. 24 to find."},
	{"q": "Normal, Chaos, Duet, Zen, Music - what's the difference?", "a": "Normal is the standard climb. Chaos reshuffles the pads and speeds up. Duet has the game play a phrase for you to echo back. Zen has no sequence or fail state, just noodling. Music plays itself - hands in your lap, just listen."},
	{"q": "How's the audio made?", "a": "Synthesized at runtime, harmonics and all. There isn't a single audio file anywhere in this game. Same story for the two animated pad skins - shader math, not textures."},
]

@onready var background_rect: ColorRect = $Background
@onready var resonator_panel: Panel = $Resonator
@onready var duet_ring: Control = $DuetRing
@onready var constellation_layer: Control = $ConstellationLayer
@onready var pad_ring: Control = $PadRing
@onready var start_button: Button = $ModeBar/StartButton
@onready var hearts_label: Label = $HeartsLabel
@onready var round_label: Label = $RoundLabel
@onready var combo_label: Label = $ComboLabel
@onready var score_label: Label = $ScoreLabel
@onready var cash_out_button: Button = $CashOutButton
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var modifier_panel: Control = $ModifierPanel
@onready var modifier_vbox: Control = $ModifierPanel/CenterContainer/VBoxContainer
@onready var modifier_buttons: Array[Button] = [
	$ModifierPanel/CenterContainer/VBoxContainer/OptionsRow/Option1,
	$ModifierPanel/CenterContainer/VBoxContainer/OptionsRow/Option2,
	$ModifierPanel/CenterContainer/VBoxContainer/OptionsRow/Option3,
]
@onready var settings_button: Button = $SettingsButton
@onready var settings_panel: Control = $SettingsPanel
@onready var settings_scroll: Control = $SettingsPanel/CenterContainer/ContentBox
@onready var settings_tabs: TabContainer = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer
@onready var settings_panel_bg: PanelContainer = $SettingsPanel/CenterContainer/ContentBox/PanelBG
@onready var scale_grid: GridContainer = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Scales/Margin/ScaleGrid
var scale_buttons: Array[Button] = []
var scale_card_badges: Array[PanelContainer] = []
var scale_card_notes_rows: Array[HBoxContainer] = []
var scale_card_unlock_labels: Array[Label] = []
@onready var theme_grid: GridContainer = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Themes/Margin/VBoxContainer/ThemeCenterContainer/ThemeGrid
@onready var palette_section: Control = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Themes/Margin/VBoxContainer/PaletteSection
@onready var palette_grid: GridContainer = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Themes/Margin/VBoxContainer/PaletteSection/PaletteGrid
var palette_buttons: Array[Button] = []
var theme_buttons: Array[Button] = []
var theme_card_badges: Array[PanelContainer] = []
var theme_card_unlock_labels: Array[Label] = []
var palette_card_badges: Array[PanelContainer] = []
var palette_card_unlock_labels: Array[Label] = []
@onready var settings_close_button: Button = $SettingsPanel/CenterContainer/ContentBox/ButtonRow/CloseButton
@onready var settings_close_x_button: Button = $SettingsPanel/CenterContainer/ContentBox/HeaderRow/CloseXButton
@onready var settings_reset_button: Button = $SettingsPanel/CenterContainer/ContentBox/ButtonRow/ResetButton
@onready var settings_confirm_row: HBoxContainer = $SettingsPanel/CenterContainer/ContentBox/ButtonRow/ConfirmRow
@onready var settings_confirm_yes_button: Button = $SettingsPanel/CenterContainer/ContentBox/ButtonRow/ConfirmRow/ConfirmYesButton
@onready var settings_confirm_no_button: Button = $SettingsPanel/CenterContainer/ContentBox/ButtonRow/ConfirmRow/ConfirmNoButton
@onready var best_score_label: Label = $SettingsPanel/CenterContainer/ContentBox/HeaderRow/StatRow/ScoreTile/ValueLabel
@onready var best_round_label: Label = $SettingsPanel/CenterContainer/ContentBox/HeaderRow/StatRow/RoundTile/ValueLabel
@onready var best_combo_label: Label = $SettingsPanel/CenterContainer/ContentBox/HeaderRow/StatRow/ComboTile/ValueLabel

@onready var help_button: Button = $HelpButton
@onready var onboarding_panel: Control = $OnboardingPanel
@onready var faq_button: Button = $FaqButton
@onready var faq_panel: Control = $FaqPanel
@onready var faq_qa_list: VBoxContainer = $FaqPanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/ScrollContainer/QAList
@onready var faq_close_button: Button = $FaqPanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/CloseButton
@onready var onboarding_step_label: Label = $OnboardingPanel/CenterContainer/VBoxContainer/StepIndicatorLabel
@onready var onboarding_title_label: Label = $OnboardingPanel/CenterContainer/VBoxContainer/TitleLabel
@onready var onboarding_body_label: Label = $OnboardingPanel/CenterContainer/VBoxContainer/BodyLabel
@onready var onboarding_skip_button: Button = $OnboardingPanel/CenterContainer/VBoxContainer/ButtonRow/SkipButton
@onready var onboarding_next_button: Button = $OnboardingPanel/CenterContainer/VBoxContainer/ButtonRow/NextButton

@onready var game_over_panel: Control = $GameOverPanel
@onready var game_over_stats_label: Label = $GameOverPanel/CenterContainer/VBoxContainer/StatsLabel
@onready var game_over_best_label: Label = $GameOverPanel/CenterContainer/VBoxContainer/BestLabel
@onready var game_over_close_button: Button = $GameOverPanel/CenterContainer/VBoxContainer/CloseButton

@onready var reduce_motion_check: CheckBox = $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Accessibility/Margin/CenterContainer/VBoxContainer/ReduceMotionCheck

const MIX_BUSES := ["Master", "Tones", "UI"]
const MIX_DEFAULTS := {"Master": 1.0, "Tones": 0.9, "UI": 0.5}
@onready var mix_sliders: Dictionary = {
	"Master": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/MasterRow/Slider,
	"Tones": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/TonesRow/Slider,
	"UI": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/UIRow/Slider,
}
@onready var mix_pct_labels: Dictionary = {
	"Master": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/MasterRow/PctLabel,
	"Tones": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/TonesRow/PctLabel,
	"UI": $SettingsPanel/CenterContainer/ContentBox/PanelBG/TabContainer/Audio/Margin/CenterContainer/VBoxContainer/UIRow/PctLabel,
}
# Music Mode idiom sliders (see docs/music-mode.md#idioms-borrowed-from-how-the-real-instrument-is-played) - each
# controls how often one of the steel-tongue-drum idioms fires, as a 0..1
# slider position mapped through MUSIC_IDIOM_RANGES (min at 0, "default" at
# 0.5 - always the tuned constant each idiom shipped with - max at 1) via
# _music_idiom_value()'s two-segment lerp. Split into two segments (instead
# of one lerp(min, max, slider)) so an idiom whose tuned default is far from
# a satisfying "extreme" - e.g. glissando's default of a rare 10% chance -
# can still have a max worth dragging to (was capped at 20% under a
# symmetric range, which a player at 100% would barely ever hear).
const MUSIC_IDIOM_KEYS := ["anchor_return", "zigzag_bias", "groove_repeats", "ghost_notes", "glissando", "riff_shapes"]
const MUSIC_IDIOM_RANGES := {
	"anchor_return": {"min": 0.0, "default": 0.12, "max": 0.45},
	"zigzag_bias": {"min": 0.5, "default": 0.75, "max": 1.0},
	"groove_repeats": {"min": 0.0, "default": 0.35, "max": 0.7},
	"ghost_notes": {"min": 0.0, "default": 0.18, "max": 0.45},
	"glissando": {"min": 0.0, "default": 0.1, "max": 0.85},
	"riff_shapes": {"min": 0.0, "default": 0.25, "max": 0.6},
}
@onready var music_idiom_sliders: Dictionary = {
	"anchor_return": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/AnchorRow/Slider,
	"zigzag_bias": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/ZigzagRow/Slider,
	"groove_repeats": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/GrooveRow/Slider,
	"ghost_notes": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/GhostRow/Slider,
	"glissando": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/GlissandoRow/Slider,
	"riff_shapes": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/RiffRow/Slider,
}
@onready var music_idiom_pct_labels: Dictionary = {
	"anchor_return": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/AnchorRow/PctLabel,
	"zigzag_bias": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/ZigzagRow/PctLabel,
	"groove_repeats": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/GrooveRow/PctLabel,
	"ghost_notes": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/GhostRow/PctLabel,
	"glissando": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/GlissandoRow/PctLabel,
	"riff_shapes": $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/RiffRow/PctLabel,
}
@onready var zen_button: Button = $ModeBar/ZenButton
@onready var zen_bar: Control = $ZenBar
@onready var exit_zen_button: Button = $ZenBar/ExitZenButton
@onready var chaos_button: Button = $ModeBar/ChaosButton
@onready var music_button: Button = $ModeBar/MusicButton
@onready var music_bar: Control = $MusicBar
@onready var exit_music_button: Button = $MusicBar/ExitMusicButton
@onready var music_tune_button: Button = $MusicBar/TuneButton
@onready var music_tune_panel: Control = $MusicTunePanel
@onready var music_tune_close_button: Button = $MusicTunePanel/CenterContainer/ContentBox/PanelBG/Margin/VBoxContainer/CloseButton
@onready var duet_button: Button = $ModeBar/DuetButton

var pads_by_name: Dictionary = {}
var pad_names: Array[String] = []
var pad_slots: Array = []
var pad_slot_order: Array[String] = []
var note_labels: Dictionary = {}
var chaos_mode := false
var sequence: Array[String] = []
var gold_indices: Array[int] = []
var player_index := 0
var accepting_input := false
var score := 0
var combo := 0
# Hearts: a baseline, build-independent safety net (docs/scoring-escalation.md's
# "cash-out economy" pass) - a miss with no Defense-modifier save spends a
# heart instead of ending the run outright, closing the previously
# structurally-guaranteed "zero forgiveness for the whole run unless you
# draft into Defense" gap. Run-scoped, not streak-scoped - a cash-out resets
# the streak but never touches hearts; only Second Wind explicitly refills
# them (on a long-enough voluntary cash-out), and only at max level raises
# the ceiling above the run-start default.
const RUN_START_HEARTS := 3
var max_hearts := RUN_START_HEARTS
var hearts := RUN_START_HEARTS
var current_offer: Array = []
var current_scale_index := 0
var current_palette_index := 0
var current_theme_index := 0
var zen_mode := false
var music_mode := false
var duet_mode := false
var duet_round := 0
var duet_rhythm: Array[bool] = []
var duet_step_duration := 0.0
var duet_pulse_times: Array[float] = []
var _duet_last_press := ""
var _duet_last_press_pos := Vector2.ZERO
var _duet_note_deadline_ms := 0
var _duet_note_wait_start_ms := 0
var _duet_ability_pause := false
var _duet_ring_frozen_now_t := 0.0
var _duet_ring_flash_start_ms := -100000
var _duet_ring_flash_color := Color.WHITE
var _normal_current_degree := 0
var _normal_last_direction := 0
var _normal_last_was_leap := false
var _normal_repeat_streak := 1
var _normal_riff: Array = []
var _normal_riff_index := 0
var _normal_riff_base := 0
var _music_repeat_streak := 1
var _music_current_degree := 0
var _music_last_direction := 0
var _music_last_was_leap := false
var _music_bar_index := 0
var _music_groove_rhythm: Array[bool] = []
var _music_groove_bars_left := 0
# Debug instrumentation to check whether the walk/idiom biases skew note
# selection more than expected - see _music_log_degree() and
# _print_music_degree_distribution(). Session-only, matches how the idiom
# sliders reset (see _reset_music_idiom_sliders()).
const MUSIC_LOG_INTERVAL := 32
var _music_degree_counts: Dictionary = {}
var _music_notes_logged := 0
var best_score := 0
var best_round := 0
var best_combo := 0
var cheat_all_unlocked := false
var onboarding_seen := false
var onboarding_step := 0
var mix_levels: Dictionary = MIX_DEFAULTS.duplicate()
var reduce_motion := false
var music_idiom_levels: Dictionary = {"anchor_return": 0.5, "zigzag_bias": 0.5, "groove_repeats": 0.5, "ghost_notes": 0.5, "glissando": 0.5, "riff_shapes": 0.5}
var run_start_best_score := 0
var run_start_best_round := 0
var run_start_best_combo := 0
var run_new_unlocks: Array[Dictionary] = []
var _typed_buffer := ""

# Modifier-driven run stats, reset each new run.
var combo_growth := BASE_COMBO_GROWTH
var golden_step_count := 0
var sequence_speed_multiplier := 1.0
var score_bonus_percent := 0.0

# --- Modifier slot system state ---
# One id (or "") equipped per category; levels/resources persist for the
# whole run even across a swap-out, so re-equipping a modifier later in the
# same run resumes it rather than starting over.
var equipped_modifiers: Dictionary = {"multiplier": "", "defense": "", "tempo": "", "bonus_event": ""}
var modifier_levels: Dictionary = {}
# No modifier tracks a countable resource (docs/modifier-audit.md rule 6) -
# every modifier is Passive or an automatic Roll/state check. Echo Chamber
# and Quick Rewind used to be player-clicked charge spends; they're now
# automatic hesitation-triggered assists, tracked here per-note so each only
# fires once per note wait rather than every frame past its threshold.
# _hesitation_assist_busy guards Quick Rewind's replay (which disables pads
# and awaits) from Echo Chamber firing mid-replay or a re-trigger overlap.
var _last_input_ms := 0
var _echo_chamber_hinted_this_note := false
var _quick_rewind_triggered_this_note := false
var _hesitation_assist_busy := false
# Constellation (Phrasing): points/colors traced as the call plays, and a
# fade multiplier tweened to 0 once the response phase opens - see
# _constellation_reset_for_new_call/_constellation_note_played/
# _constellation_fade_out/_on_constellation_draw.
var _constellation_points: Array[Vector2] = []
var _constellation_colors: Array[Color] = []
var _constellation_alpha := 0.0

# Pure per-level stat caches, recomputed by `_recompute_pure_modifier_stats()`
# whenever equip/level state changes (cheap to recompute - unlike charges,
# nothing here is ever "spent").
var quick_rewind_speed_mult := 0.0
var breath_mark_pct := 0.0
var grounding_resonance_pct := 0.0
var rubato_level := 0
var rubato_two_directional := false

# Per-streak / per-run mechanic state.
var best_streak_this_run := 0
var current_streak_had_miss := false
var run_cashout_count := 0
var cash_out_floor := 0
var unbreakable_forgiven_this_streak := 0
var double_down_index := -1
var double_down_chain_pending := false
var double_down_boost_amount := 0
var grand_finale_pending := false
var grand_finale_wager := 0
var hit_timestamps_ms: Array[int] = []
var recent_response_ms_per_note: float = RUBATO_BASELINE_MS_PER_NOTE
# The actual pace the current round's call was just played back at (real
# elapsed time / note count, measured in _play_sequence/_play_duet_call) -
# Perfect Pitch's target, so "keep a nice cadence" means something concrete
# and perceivable: the rhythm you just watched, not an invisible number.
var _call_step_ms_per_note: float = RUBATO_BASELINE_MS_PER_NOTE
var _wave_start_ms := 0
var _wave_hit_count := 0
# Sequence/phrase length grows at the start of a round, before the player
# has acted. Cash-out must not count that queued round until a hit lands.
var current_round_has_hit := false
var sequence_chunk_id: Array[int] = []
var chunk_history: Array[Array] = []
var _next_chunk_id := 0
var harmonic_chain_stack := 0.0
var lucky_strike_index := -1

# Persisted across runs (milestone gates for power modifiers).
var best_waves := 0
var zero_miss_wave_achieved := false
var five_cashouts_achieved := false

# Loadout HUD - built entirely at runtime (see _build_loadout_hud), same
# pattern as _show_toast/_spawn_score_popup, so no scene-file changes are
# needed for the slot system's UI.
var loadout_hud: Control
var loadout_slot_panels: Dictionary = {}
var loadout_slot_labels: Dictionary = {}
var gamble_button: Button

# Wave-reset state. `waves_completed` only increments on a voluntary cash
# out (no forced cap to hit). Duet needs its own wave-local round counter
# since its ramp (bpm/pulses in `_generate_duet_phrase`) is driven by round
# count, not a cumulative sequence - `duet_wave_round` resets on cash out
# while `duet_round` (below) keeps incrementing for modifier cadence.
var waves_completed := 0
var duet_wave_round := 0
# Per-hit points earned since the last cash out - not added to `score` (the
# real, permanent total) until banked. A forgiven miss (Safety Net, Muffled
# Strike, or Unbreakable saving you) leaves this untouched - forgiveness
# protects points, not just the run,
# per the design call: "otherwise what's the point [of forgiveness]?" A
# true run-ending miss forfeits it, since it's never added to `score`.
var unbanked_points := 0
# Monotonic round counter, distinct from `sequence.size()` which now resets
# on cash out - keeps MODIFIER_ROUND_INTERVAL/best-round tracking on a
# steady cadence across resets ("round count keeps incrementing across
# resets"). Duet Mode already has its own `duet_round` for this purpose and
# is unaffected.
var total_round := 0

func _ready() -> void:
	# Godot's global random functions default to a fixed seed - without this,
	# every fresh launch replays the exact same "random" sequence from the
	# first call onward (Chaos reshuffles, Normal/Music/Duet note walks, gold
	# steps, modifier offers, everything that uses randi()/randf()/.shuffle()).
	randomize()
	_load_progress()
	start_button.pressed.connect(_on_start_pressed.bind("normal"))
	chaos_button.pressed.connect(_on_start_pressed.bind("chaos"))
	settings_button.pressed.connect(_on_settings_button_pressed)
	settings_close_button.pressed.connect(_on_settings_close_pressed)
	settings_close_x_button.pressed.connect(_on_settings_close_pressed)
	settings_reset_button.pressed.connect(_on_reset_ask_pressed)
	settings_confirm_yes_button.pressed.connect(_on_reset_progress_pressed)
	settings_confirm_no_button.pressed.connect(_on_reset_cancel_pressed)
	zen_button.pressed.connect(_on_zen_button_pressed)
	exit_zen_button.pressed.connect(_on_exit_zen_pressed)
	music_button.pressed.connect(_on_music_button_pressed)
	exit_music_button.pressed.connect(_on_exit_music_pressed)
	music_tune_button.pressed.connect(_on_music_tune_button_pressed)
	music_tune_close_button.pressed.connect(_on_music_tune_close_pressed)
	duet_button.pressed.connect(_on_start_pressed.bind("duet"))
	cash_out_button.pressed.connect(_on_cash_out_button_pressed)
	for i in modifier_buttons.size():
		modifier_buttons[i].pressed.connect(_on_modifier_button_pressed.bind(i))
	_build_scale_cards()
	_build_palette_and_theme_buttons()
	for i in palette_buttons.size():
		palette_buttons[i].pressed.connect(_on_palette_button_pressed.bind(i))
	for i in theme_buttons.size():
		theme_buttons[i].pressed.connect(_on_theme_button_pressed.bind(i))
	settings_tabs.tab_changed.connect(_on_settings_tab_changed)
	help_button.pressed.connect(_on_help_button_pressed)
	onboarding_skip_button.pressed.connect(_on_onboarding_close_pressed)
	onboarding_next_button.pressed.connect(_on_onboarding_next_pressed)
	game_over_close_button.pressed.connect(_on_game_over_close_pressed)
	faq_button.pressed.connect(_on_faq_button_pressed)
	faq_close_button.pressed.connect(_on_faq_close_pressed)
	duet_ring.draw.connect(_on_duet_ring_draw)
	constellation_layer.draw.connect(_on_constellation_draw)
	_build_faq_content()
	_connect_ui_clicks()
	_setup_mix_sliders()
	_setup_music_idiom_sliders()
	reduce_motion_check.button_pressed = reduce_motion
	reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)
	_apply_theme()
	_build_pads()
	_build_loadout_hud()
	if not onboarding_seen:
		_show_onboarding()

# A small pill used by scale/palette/theme cards to show "ACTIVE" or a lock
# icon. Built as a PanelContainer + Label (not a bare Label) because Label
# never draws a background stylebox on its own - only a Panel-family control
# does, so the pill's accent-colored background needs the wrapper to render.
func _make_pick_badge(parent: Control) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	parent.add_child(badge)
	return badge

func _style_pick_badge(badge: PanelContainer, active: bool, locked: bool, accent: Color, accent_text: Color) -> void:
	var label: Label = badge.get_child(0)
	if active:
		label.text = "ACTIVE"
		label.add_theme_color_override("font_color", accent_text)
		var sb := StyleBoxFlat.new()
		sb.bg_color = accent
		sb.set_corner_radius_all(5)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", sb)
	else:
		label.text = "🔒" if locked else ""
		label.remove_theme_color_override("font_color")
		# Explicit transparent stylebox rather than removing the override -
		# without it the badge falls back to the global "PanelContainer"
		# theme style (a visible rounded/bordered box) even with empty text.
		badge.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _style_pick_card(card: Button, active: bool, locked: bool, accent: Color, border: Color, corner_radius: int) -> void:
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = border.darkened(0.15) if locked else Color(border, 0.5)
	card_sb.border_color = accent if active else border
	card_sb.set_border_width_all(2 if active else 1)
	card_sb.set_corner_radius_all(corner_radius)
	card.add_theme_stylebox_override("normal", card_sb)
	card.add_theme_stylebox_override("disabled", card_sb)
	var card_hover_sb: StyleBoxFlat = card_sb.duplicate()
	card_hover_sb.border_color = accent
	card.add_theme_stylebox_override("hover", card_hover_sb)
	card.modulate.a = 0.65 if locked else 1.0

# Cards are built here rather than hand-placed in the scene, same reasoning as
# `_build_pads()` - 11 near-identical nodes are far less error-prone generated
# from `SCALES` than hand-authored in the .tscn.
func _build_scale_cards() -> void:
	for i in SCALES.size():
		var scale: Dictionary = SCALES[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(280, 108)
		card.focus_mode = Control.FOCUS_NONE
		card.clip_contents = true
		card.pressed.connect(_on_scale_button_pressed.bind(i))
		scale_grid.add_child(card)
		scale_buttons.append(card)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vbox)

		var header := HBoxContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(header)

		var name_label := Label.new()
		name_label.text = scale["name"]
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = 2
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(name_label)

		scale_card_badges.append(_make_pick_badge(header))

		var notes_row := HBoxContainer.new()
		notes_row.add_theme_constant_override("separation", 4)
		notes_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(notes_row)
		for note in scale["notes"]:
			var chip := PanelContainer.new()
			chip.custom_minimum_size = Vector2(24, 24)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var chip_sb := StyleBoxFlat.new()
			chip_sb.bg_color = Color(1, 1, 1, 0.08)
			chip_sb.set_corner_radius_all(5)
			chip.add_theme_stylebox_override("panel", chip_sb)
			var chip_label := Label.new()
			chip_label.text = note
			chip_label.add_theme_font_size_override("font_size", 10)
			chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(chip_label)
			notes_row.add_child(chip)
		scale_card_notes_rows.append(notes_row)

		var unlock_label := Label.new()
		unlock_label.add_theme_font_size_override("font_size", 11)
		unlock_label.autowrap_mode = 2
		unlock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unlock_label.visible = false
		if scale.has("unlock"):
			unlock_label.text = _requirement_text(scale["unlock"])
		vbox.add_child(unlock_label)
		scale_card_unlock_labels.append(unlock_label)

func _build_palette_and_theme_buttons() -> void:
	for i in PALETTES.size():
		var palette: Dictionary = PALETTES[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_contents = true
		palette_grid.add_child(btn)
		palette_buttons.append(btn)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		btn.add_child(margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(row)

		var swatch_row := HBoxContainer.new()
		swatch_row.add_theme_constant_override("separation", 3)
		swatch_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in _palette_preview_colors(palette):
			var chip := ColorRect.new()
			chip.color = c
			chip.custom_minimum_size = Vector2(18, 18)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch_row.add_child(chip)
		row.add_child(swatch_row)

		var name_label := Label.new()
		name_label.text = palette["name"]
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)

		if palette.get("animated", false):
			var animated_tag := Label.new()
			animated_tag.text = "ANIMATED"
			animated_tag.add_theme_font_size_override("font_size", 9)
			animated_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(animated_tag)

		palette_card_badges.append(_make_pick_badge(row))

		var unlock_label := Label.new()
		unlock_label.add_theme_font_size_override("font_size", 11)
		unlock_label.visible = false
		unlock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if palette.has("unlock"):
			unlock_label.text = _requirement_text(palette["unlock"])
		row.add_child(unlock_label)
		palette_card_unlock_labels.append(unlock_label)

	for i in THEMES.size():
		var theme_data: Dictionary = THEMES[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(196, 120)
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_contents = true
		theme_grid.add_child(btn)
		theme_buttons.append(btn)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		btn.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vbox)

		var preview := PanelContainer.new()
		preview.custom_minimum_size = Vector2(0, 44)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var preview_sb := StyleBoxFlat.new()
		preview_sb.bg_color = theme_data["panel"]
		preview_sb.border_color = theme_data["border"]
		preview_sb.set_border_width_all(1)
		preview_sb.set_corner_radius_all(6)
		preview_sb.content_margin_left = 8
		preview_sb.content_margin_top = 6
		preview.add_theme_stylebox_override("panel", preview_sb)
		var preview_row := HBoxContainer.new()
		preview_row.add_theme_constant_override("separation", 6)
		preview_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in [theme_data["bg"], theme_data["accent"], theme_data["accent2"]]:
			var dot := ColorRect.new()
			dot.color = c
			dot.custom_minimum_size = Vector2(14, 14)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview_row.add_child(dot)
		preview.add_child(preview_row)
		vbox.add_child(preview)

		var header := HBoxContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(header)

		var name_label := Label.new()
		name_label.text = theme_data["name"].replace("\n", " ")
		name_label.add_theme_font_size_override("font_size", 12.5)
		name_label.autowrap_mode = 2
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(name_label)

		theme_card_badges.append(_make_pick_badge(header))

		var unlock_label := Label.new()
		unlock_label.add_theme_font_size_override("font_size", 10.5)
		unlock_label.autowrap_mode = 2
		unlock_label.visible = false
		unlock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if theme_data.has("unlock"):
			unlock_label.text = "🔒 " + _requirement_text(theme_data["unlock"])
		vbox.add_child(unlock_label)
		theme_card_unlock_labels.append(unlock_label)

func _palette_preview_colors(palette: Dictionary) -> Array[Color]:
	if palette.has("colors"):
		var explicit: Array[Color] = []
		explicit.assign(palette["colors"])
		return explicit
	if palette.has("shader"):
		var c: Color = palette["accent_color"]
		var shader_colors: Array[Color] = [c, c.lightened(0.15), c.lightened(0.3), c.darkened(0.15)]
		return shader_colors
	var colors: Array[Color] = []
	for i in PAD_COUNT:
		var hue := _pad_hue(i, palette)
		colors.append(Color.from_hsv(hue, palette["sat"], palette["val"]))
	return colors

func _connect_ui_clicks() -> void:
	# Soft UI SFX for routine interactions - distinct from gameplay pad tones.
	var ui_click_buttons: Array[Button] = [
		start_button, chaos_button, zen_button, exit_zen_button,
		music_button, exit_music_button, duet_button,
		settings_button, settings_close_button, settings_close_x_button, settings_reset_button,
		settings_confirm_yes_button, settings_confirm_no_button,
		help_button, onboarding_skip_button, onboarding_next_button,
		game_over_close_button, cash_out_button, faq_button, faq_close_button,
		music_tune_button, music_tune_close_button,
	]
	ui_click_buttons.append_array(scale_buttons)
	ui_click_buttons.append_array(palette_buttons)
	ui_click_buttons.append_array(theme_buttons)
	ui_click_buttons.append_array(modifier_buttons)
	for button in ui_click_buttons:
		button.pressed.connect(Sound.play_ui_tick.bind(660.0, 0.22))

func _setup_mix_sliders() -> void:
	for bus_name in MIX_BUSES:
		var slider: HSlider = mix_sliders[bus_name]
		slider.value = mix_levels[bus_name]
		Sound.set_bus_volume_linear(bus_name, mix_levels[bus_name])
		_update_mix_pct_label(bus_name)
		slider.value_changed.connect(_on_mix_slider_changed.bind(bus_name))

func _on_mix_slider_changed(value: float, bus_name: String) -> void:
	mix_levels[bus_name] = value
	Sound.set_bus_volume_linear(bus_name, value)
	_update_mix_pct_label(bus_name)
	_save_progress()

func _update_mix_pct_label(bus_name: String) -> void:
	var label: Label = mix_pct_labels[bus_name]
	label.text = "%d%%" % round(mix_levels[bus_name] * 100.0)

func _setup_music_idiom_sliders() -> void:
	for key in MUSIC_IDIOM_KEYS:
		var slider: HSlider = music_idiom_sliders[key]
		slider.value = music_idiom_levels[key]
		_update_music_idiom_pct_label(key)
		slider.value_changed.connect(_on_music_idiom_slider_changed.bind(key))

func _on_music_idiom_slider_changed(value: float, key: String) -> void:
	music_idiom_levels[key] = value
	_update_music_idiom_pct_label(key)

func _update_music_idiom_pct_label(key: String) -> void:
	var label: Label = music_idiom_pct_labels[key]
	label.text = "%d%%" % round(music_idiom_levels[key] * 100.0)

# Music idiom sliders are session-only tuning, not a saved preference (see
# _on_music_button_pressed()) - every fresh Music Mode session starts back
# at 50% (the tuned default) for all six, regardless of where they were
# left last time.
func _reset_music_idiom_sliders() -> void:
	for key in MUSIC_IDIOM_KEYS:
		music_idiom_levels[key] = 0.5
		var slider: HSlider = music_idiom_sliders[key]
		slider.value = 0.5
		_update_music_idiom_pct_label(key)

# Maps a slider's 0..1 position through MUSIC_IDIOM_RANGES to the actual
# probability/bias value the Music Mode generators use - see the
# MUSIC_IDIOM_KEYS declaration for why 0.5 always reproduces the tuned
# default, and why this is two lerps (0..0.5 and 0.5..1) instead of one.
func _music_idiom_value(key: String) -> float:
	var idiom_range: Dictionary = MUSIC_IDIOM_RANGES[key]
	var slider: float = music_idiom_levels[key]
	if slider <= 0.5:
		return lerpf(idiom_range["min"], idiom_range["default"], slider / 0.5)
	return lerpf(idiom_range["default"], idiom_range["max"], (slider - 0.5) / 0.5)

func _on_reduce_motion_toggled(is_on: bool) -> void:
	reduce_motion = is_on
	Sound.play_ui_tick()
	_save_progress()

func _on_settings_tab_changed(_tab: int) -> void:
	Sound.play_ui_tick()

func _on_help_button_pressed() -> void:
	_show_onboarding()

func _build_faq_content() -> void:
	for entry in FAQ_ENTRIES:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)
		var q := Label.new()
		q.text = String(entry["q"])
		q.add_theme_font_size_override("font_size", 15)
		q.autowrap_mode = 2
		block.add_child(q)
		var a := Label.new()
		a.text = String(entry["a"])
		a.add_theme_font_size_override("font_size", 13)
		a.modulate.a = 0.75
		a.autowrap_mode = 2
		block.add_child(a)
		faq_qa_list.add_child(block)

func _on_faq_button_pressed() -> void:
	faq_panel.visible = true
	_refresh_loadout_hud()

func _on_faq_close_pressed() -> void:
	faq_panel.visible = false

func _on_music_tune_button_pressed() -> void:
	music_tune_panel.visible = true

func _on_music_tune_close_pressed() -> void:
	music_tune_panel.visible = false
	_refresh_loadout_hud()

func _show_onboarding() -> void:
	onboarding_step = 0
	_refresh_onboarding_step()
	onboarding_panel.visible = true

func _refresh_onboarding_step() -> void:
	var step: Dictionary = ONBOARDING_STEPS[onboarding_step]
	onboarding_step_label.text = "Step %d / %d" % [onboarding_step + 1, ONBOARDING_STEPS.size()]
	onboarding_title_label.text = step["title"]
	onboarding_body_label.text = step["body"]
	var is_last := onboarding_step == ONBOARDING_STEPS.size() - 1
	onboarding_next_button.text = "Start Playing" if is_last else "Next"

func _on_onboarding_next_pressed() -> void:
	if onboarding_step == ONBOARDING_STEPS.size() - 1:
		_on_onboarding_close_pressed()
		return
	onboarding_step += 1
	_refresh_onboarding_step()

func _on_onboarding_close_pressed() -> void:
	onboarding_panel.visible = false
	if not onboarding_seen:
		onboarding_seen = true
		_save_progress()

func _input(event: InputEvent) -> void:
	if cheat_all_unlocked:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var ch := char(event.unicode).to_lower()
	if ch.length() != 1 or ch < "a" or ch > "z":
		return
	_typed_buffer += ch
	if _typed_buffer.length() > EASTER_EGG_CODE.length():
		_typed_buffer = _typed_buffer.substr(_typed_buffer.length() - EASTER_EGG_CODE.length())
	if _typed_buffer == EASTER_EGG_CODE:
		_trigger_easter_egg()

func _trigger_easter_egg() -> void:
	cheat_all_unlocked = true
	_save_progress()
	_flash_screen(Color(1, 0.85, 0.3, 0.5))
	_screen_shake(6.0, 0.3)
	_show_toast("* Hubert Mode: Everything Unlocked! *")
	_play_unlock_fanfare()
	if settings_panel.visible:
		_on_settings_button_pressed()

func _play_unlock_fanfare() -> void:
	var scale: Dictionary = SCALES[current_scale_index]
	for freq in scale["tones"]:
		Sound.play_tone(freq, 0.4)
		await get_tree().create_timer(0.06).timeout

func _show_toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 160.0
	label.offset_bottom = 200.0
	label.modulate.a = 0.0
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.3)
	t.tween_interval(1.8)
	t.tween_property(label, "modulate:a", 0.0, 0.5)
	t.tween_callback(label.queue_free)

# Persistent build-at-a-glance HUD: one chip per category slot (empty
# outline if unequipped, icon/title/level if equipped, full description on
# hover via tooltip_text) plus a Gamble button that only appears while Grand
# Finale is equipped - the roster's one modifier that still needs a manual
# activation (docs/modifier-audit.md rule 6's documented exception). Built
# purely from code - same pattern as the score popups/toasts above - so no
# scene-file changes were needed for the whole slot system's UI. Stacked
# vertically on the left edge (x=14, below the top HUD row, left of the pad
# ring) so it never overlaps ModeBar/RoundLabel/ComboLabel or the pads
# themselves.
func _build_loadout_hud() -> void:
	loadout_hud = VBoxContainer.new()
	loadout_hud.add_theme_constant_override("separation", 6)
	loadout_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	loadout_hud.position = Vector2(12, 156)
	add_child(loadout_hud)
	for cat in MODIFIER_CATEGORIES:
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(128, 44)
		# STOP (not IGNORE) so the chip actually receives hover events -
		# that's what makes tooltip_text work at all.
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.06, 0.75)
		sb.border_color = Color(1, 1, 1, 0.25)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", sb)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 1)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(vbox)
		var cat_color: Color = CATEGORY_COLORS[cat]
		sb.border_color = Color(cat_color, 0.45)
		var cat_lbl := Label.new()
		cat_lbl.text = CATEGORY_LABELS[cat].to_upper()
		cat_lbl.add_theme_font_size_override("font_size", 9)
		cat_lbl.add_theme_color_override("font_color", cat_color)
		cat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(cat_lbl)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.clip_contents = true
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)
		loadout_hud.add_child(chip)
		loadout_slot_panels[cat] = chip
		loadout_slot_labels[cat] = lbl
	# Echo Chamber and Quick Rewind no longer have manual-activation buttons
	# (docs/modifier-audit.md rule 6 - they fire automatically off
	# hesitation now, see _check_hesitation_assists). Grand Finale keeps
	# Gamble: the one sanctioned exception, a pause-point choice rather than
	# a mid-sequence click.
	gamble_button = Button.new()
	gamble_button.text = "Gamble"
	gamble_button.custom_minimum_size = Vector2(128, 0)
	gamble_button.visible = false
	gamble_button.focus_mode = Control.FOCUS_NONE
	gamble_button.tooltip_text = "Grand Finale: wager the unbanked pool on completing the rest of this round."
	gamble_button.pressed.connect(_start_grand_finale_gamble)
	gamble_button.pressed.connect(Sound.play_ui_tick.bind(660.0, 0.22))
	loadout_hud.add_child(gamble_button)
	_refresh_loadout_hud()

func _loadout_hud_should_show() -> bool:
	if zen_mode or music_mode:
		return false
	if not cash_out_button.visible:
		return false
	if modifier_panel.visible or game_over_panel.visible:
		return false
	if settings_panel.visible or faq_panel.visible:
		return false
	return true

func _refresh_loadout_hud() -> void:
	if loadout_hud == null:
		return
	loadout_hud.visible = _loadout_hud_should_show()
	for cat in MODIFIER_CATEGORIES:
		var id: String = equipped_modifiers[cat]
		var lbl: Label = loadout_slot_labels[cat]
		var chip: PanelContainer = loadout_slot_panels[cat]
		var sb: StyleBoxFlat = chip.get_theme_stylebox("panel")
		var cat_color: Color = CATEGORY_COLORS[cat]
		if id == "":
			lbl.text = "— empty —"
			lbl.modulate.a = 0.5
			sb.bg_color = Color(0.05, 0.05, 0.06, 0.75)
			sb.border_color = Color(cat_color, 0.4)
			chip.tooltip_text = "%s slot: no modifier equipped yet." % CATEGORY_LABELS[cat]
		else:
			var mod := _mod_def(id)
			# No resource-count suffix anymore (docs/modifier-audit.md rule
			# 6) - nothing left in the roster is a countable charge to show.
			lbl.text = "%s %s Lv.%d" % [mod["icon"], mod["title"], _mod_level(id)]
			lbl.modulate.a = 1.0
			sb.bg_color = Color(cat_color, 0.16)
			sb.border_color = cat_color
			chip.tooltip_text = "%s (Lv.%d/%d)\n%s" % [mod["title"], _mod_level(id), MAX_MODIFIER_LEVEL, mod["desc"]]
	# Echo Chamber and Quick Rewind fire automatically now (no Peek/Rewind
	# buttons - see _check_hesitation_assists). Grand Finale keeps its
	# Gamble button - the one sanctioned exception, see
	# _start_grand_finale_gamble - with no charge count in the label since
	# it's never capped.
	if equipped_modifiers["bonus_event"] == "grand_finale":
		gamble_button.visible = true
		gamble_button.disabled = unbanked_points < cash_out_floor or grand_finale_pending or not accepting_input
		gamble_button.text = "Gambling..." if grand_finale_pending else "Gamble (x%.1f)" % float(_mod_val("grand_finale", "mult"))
	else:
		gamble_button.visible = false

func _build_pads() -> void:
	for i in PAD_COUNT:
		var angle_deg := -90.0 + i * (360.0 / PAD_COUNT)
		var angle_rad := deg_to_rad(angle_deg)
		var dir := Vector2(cos(angle_rad), sin(angle_rad))
		var slot_position := RING_CENTER + dir * BASE_RADIUS - Vector2(PAD_WIDTH / 2.0, 0.0)
		var slot_rotation := angle_deg - 90.0
		pad_slots.append({"position": slot_position, "rotation": slot_rotation, "dir": dir})
		var pad := SimonButton.new()
		pad.pad_name = "pad_%d" % i
		pad.custom_minimum_size = Vector2(PAD_WIDTH, PAD_HEIGHT)
		pad.size = Vector2(PAD_WIDTH, PAD_HEIGHT)
		pad.pivot_offset = Vector2(PAD_WIDTH / 2.0, 0.0)
		pad.rotation_degrees = slot_rotation
		pad.position = slot_position
		pad.focus_mode = Control.FOCUS_NONE
		pad.disabled = true
		pad_ring.add_child(pad)
		pads_by_name[pad.pad_name] = pad
		pad_names.append(pad.pad_name)
		pad_slot_order.append(pad.pad_name)
		pad.pressed.connect(_on_pad_pressed.bind(pad.pad_name))

		var label := Label.new()
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(44, 28)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad_ring.add_child(label)
		note_labels[pad.pad_name] = label
		_position_label(pad.pad_name, dir)
	_apply_scale_and_palette()

func _position_label(pad_name: String, dir: Vector2) -> void:
	var label: Label = note_labels[pad_name]
	var center := RING_CENTER + dir * (BASE_RADIUS + PAD_HEIGHT * 0.55)
	label.position = center - label.size / 2.0

func _reshuffle_pad_positions() -> void:
	pad_slot_order.shuffle()
	for i in PAD_COUNT:
		var slot: Dictionary = pad_slots[i]
		var pad: SimonButton = pads_by_name[pad_slot_order[i]]
		pad.position = slot["position"]
		pad.rotation_degrees = slot["rotation"]
		_position_label(pad_slot_order[i], slot["dir"])

func _reset_pad_positions() -> void:
	pad_slot_order = pad_names.duplicate()
	for i in PAD_COUNT:
		var slot: Dictionary = pad_slots[i]
		var pad: SimonButton = pads_by_name[pad_slot_order[i]]
		pad.position = slot["position"]
		pad.rotation_degrees = slot["rotation"]
		_position_label(pad_slot_order[i], slot["dir"])

func _pad_hue(i: int, palette: Dictionary) -> float:
	if palette["wrap"]:
		return palette["hue_start"] + float(i) / PAD_COUNT * (palette["hue_end"] - palette["hue_start"])
	return lerp(float(palette["hue_start"]), float(palette["hue_end"]), float(i) / float(PAD_COUNT - 1))

func _apply_scale_and_palette() -> void:
	var scale: Dictionary = SCALES[current_scale_index]
	var palette: Dictionary = THEMES[current_theme_index].get("pad_style", PALETTES[current_palette_index])
	var is_shader_palette: bool = palette.has("shader")
	var ring_order: Array = scale.get("ring_order", [0, 1, 2, 3, 4, 5, 6, 7])
	for i in PAD_COUNT:
		var degree: int = ring_order[i]
		var pad: SimonButton = pads_by_name[pad_names[i]]
		pad.tone_freq = scale["tones"][degree]
		note_labels[pad_names[i]].text = scale["notes"][degree]
		if is_shader_palette:
			pad.base_color = palette["accent_color"]
			pad.lit_color = (palette["accent_color"] as Color).lightened(0.4)
			pad.set_shader_skin(load(palette["shader"]), float(i) * 1.37 + randf() * 0.5)
		elif palette.has("colors"):
			pad.clear_shader_skin()
			pad.base_color = palette["colors"][i]
			pad.lit_color = (palette["colors"][i] as Color).lightened(0.35)
		else:
			pad.clear_shader_skin()
			var hue := _pad_hue(i, palette)
			pad.base_color = Color.from_hsv(hue, palette["sat"], palette["val"])
			pad.lit_color = Color.from_hsv(hue, palette["lit_sat"], palette["lit_val"])
		pad.refresh()
		_apply_label_contrast(note_labels[pad_names[i]], pad.base_color, pad.lit_color)

# Picks black-or-white note-label text (with a matching soft shadow) by
# whichever contrasts better against BOTH the pad's resting and lit color -
# many of the newer mid-tone palettes read poorly with fixed white text,
# especially once lightened() brightens them further on a hit.
func _apply_label_contrast(label: Label, base_color: Color, lit_color: Color) -> void:
	var white := Color(0.95, 0.95, 0.95, 0.95)
	var black := Color(0.06, 0.06, 0.08, 0.95)
	var white_worst: float = min(_contrast_ratio(white, base_color), _contrast_ratio(white, lit_color))
	var black_worst: float = min(_contrast_ratio(black, base_color), _contrast_ratio(black, lit_color))
	var text_color := white if white_worst >= black_worst else black
	var is_light_text := text_color == white
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6) if is_light_text else Color(1, 1, 1, 0.55))

func _color_luminance(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

func _contrast_ratio(a: Color, b: Color) -> float:
	var la := _color_luminance(a)
	var lb := _color_luminance(b)
	var lighter: float = max(la, lb)
	var darker: float = min(la, lb)
	return (lighter + 0.05) / (darker + 0.05)

func _apply_theme() -> void:
	var theme_data: Dictionary = THEMES[current_theme_index]
	theme = _build_ui_theme(theme_data)

	var accent: Color = theme_data["accent"]
	for stat_label in [best_score_label, best_round_label, best_combo_label]:
		stat_label.add_theme_color_override("font_color", accent)
	for bus_name in MIX_BUSES:
		(mix_pct_labels[bus_name] as Label).add_theme_color_override("font_color", accent)

	# The background shader (full-viewport, same cost as a pad's but at much
	# higher resolution) was a major contributor to Web-only audio/frame
	# stutter - dropped in favor of a flat fill. The pad_style shader skin
	# (much smaller per-instance area) stays, so themes like Cosmic &
	# Atmospheric keep their shader look on the pads themselves.
	background_rect.material = null
	background_rect.color = theme_data.get("background_color", theme_data["bg"])

	var settings_bg_sb := StyleBoxFlat.new()
	settings_bg_sb.bg_color = theme_data["panel"]
	settings_bg_sb.border_color = theme_data["border"]
	settings_bg_sb.set_border_width_all(1)
	settings_bg_sb.set_corner_radius_all(14)
	settings_bg_sb.shadow_color = Color(0, 0, 0, 0.4)
	settings_bg_sb.shadow_size = 12
	settings_panel_bg.add_theme_stylebox_override("panel", settings_bg_sb)

	var resonator_color: Color = theme_data.get("resonator_color", theme_data["panel"])
	var resonator_sb := StyleBoxFlat.new()
	resonator_sb.bg_color = resonator_color
	resonator_sb.corner_radius_top_left = 80
	resonator_sb.corner_radius_top_right = 80
	resonator_sb.corner_radius_bottom_right = 80
	resonator_sb.corner_radius_bottom_left = 80
	resonator_sb.border_color = theme_data["border"]
	resonator_sb.set_border_width_all(1)
	resonator_sb.shadow_color = Color(0, 0, 0, 0.35)
	resonator_sb.shadow_size = 10
	resonator_panel.add_theme_stylebox_override("panel", resonator_sb)

# Builds a full Godot Theme resource from a THEMES entry's 7 chrome colors and
# assigns it to the whole scene tree via the root Control's `theme` property
# (Godot cascades it to every descendant; per-node color overrides elsewhere -
# e.g. the gold combo/best-callout labels - still win over this).
# The default theme font's embedded glyph set doesn't cover the rarer
# symbol/dingbat codepoints the modifier icons use (e.g. U+26E8 ⛨, U+2766
# ❦, U+224B ≋). Desktop Godot silently falls back to system-installed
# fonts for missing glyphs; the Web export can't reach system fonts at
# all, so those icons render blank there. Registering these two bundled
# Noto Sans Symbols fonts as fallbacks fixes every current and future
# icon glyph without changing how any existing text renders.
func _build_icon_fallback_font() -> Font:
	var combined := FontVariation.new()
	combined.base_font = ThemeDB.fallback_font
	var fallback_fonts: Array[Font] = []
	for path in ["res://assets/fonts/NotoSansSymbols2-Regular.ttf", "res://assets/fonts/NotoSansSymbols[wght].ttf"]:
		var f := load(path)
		if f is Font:
			fallback_fonts.append(f)
	combined.fallbacks = fallback_fonts
	return combined

func _build_ui_theme(theme_data: Dictionary) -> Theme:
	var panel_color: Color = theme_data["panel"]
	var border_color: Color = theme_data["border"]
	var text_color: Color = theme_data["text"]
	var text_muted_color: Color = theme_data["text_muted"]
	var accent_color: Color = theme_data["accent"]

	var ui_theme := Theme.new()
	ui_theme.default_font = _build_icon_fallback_font()

	ui_theme.set_color("font_color", "Label", text_color)
	ui_theme.set_color("font_color", "Button", text_color)
	ui_theme.set_color("font_hover_color", "Button", accent_color)
	ui_theme.set_color("font_pressed_color", "Button", accent_color)
	ui_theme.set_color("font_focus_color", "Button", text_color)
	ui_theme.set_color("font_disabled_color", "Button", text_muted_color)
	ui_theme.set_color("font_color", "CheckBox", text_color)
	ui_theme.set_color("font_hover_color", "CheckBox", accent_color)

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = panel_color
	normal_sb.border_color = border_color
	normal_sb.set_border_width_all(1)
	normal_sb.set_corner_radius_all(8)
	normal_sb.content_margin_left = 10
	normal_sb.content_margin_right = 10
	normal_sb.content_margin_top = 6
	normal_sb.content_margin_bottom = 6

	var hover_sb: StyleBoxFlat = normal_sb.duplicate()
	hover_sb.bg_color = panel_color.lightened(0.1)
	hover_sb.border_color = accent_color

	var pressed_sb: StyleBoxFlat = normal_sb.duplicate()
	pressed_sb.bg_color = accent_color.darkened(0.15)
	pressed_sb.border_color = accent_color

	var disabled_sb: StyleBoxFlat = normal_sb.duplicate()
	disabled_sb.bg_color = panel_color.darkened(0.15)
	disabled_sb.border_color = border_color.darkened(0.2)

	var focus_sb: StyleBoxFlat = normal_sb.duplicate()
	focus_sb.border_color = accent_color
	focus_sb.set_border_width_all(2)

	ui_theme.set_stylebox("normal", "Button", normal_sb)
	ui_theme.set_stylebox("hover", "Button", hover_sb)
	ui_theme.set_stylebox("pressed", "Button", pressed_sb)
	ui_theme.set_stylebox("disabled", "Button", disabled_sb)
	ui_theme.set_stylebox("focus", "Button", focus_sb)

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = panel_color
	panel_sb.border_color = border_color
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(14)
	ui_theme.set_stylebox("panel", "PanelContainer", panel_sb)

	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = border_color
	slider_track.set_corner_radius_all(6)
	ui_theme.set_stylebox("slider", "HSlider", slider_track)

	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = accent_color
	slider_fill.set_corner_radius_all(6)
	ui_theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	ui_theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	var tab_selected_sb := StyleBoxFlat.new()
	tab_selected_sb.bg_color = Color(accent_color, 0.16)
	tab_selected_sb.border_color = accent_color
	tab_selected_sb.border_width_bottom = 2
	tab_selected_sb.content_margin_left = 12
	tab_selected_sb.content_margin_right = 12
	tab_selected_sb.content_margin_top = 8
	tab_selected_sb.content_margin_bottom = 8
	var tab_unselected_sb: StyleBoxFlat = tab_selected_sb.duplicate()
	tab_unselected_sb.bg_color = Color.TRANSPARENT
	tab_unselected_sb.border_color = Color.TRANSPARENT
	ui_theme.set_stylebox("tab_selected", "TabContainer", tab_selected_sb)
	ui_theme.set_stylebox("tab_unselected", "TabContainer", tab_unselected_sb)
	ui_theme.set_stylebox("tab_hovered", "TabContainer", tab_unselected_sb)
	ui_theme.set_stylebox("tab_disabled", "TabContainer", tab_unselected_sb)
	ui_theme.set_color("font_selected_color", "TabContainer", accent_color)
	ui_theme.set_color("font_unselected_color", "TabContainer", text_muted_color)
	ui_theme.set_color("font_hovered_color", "TabContainer", text_color)

	return ui_theme

func _meets_requirement(req: Dictionary) -> bool:
	match req["type"]:
		"round":
			return best_round >= int(req["value"])
		"score":
			return best_score >= int(req["value"])
		"combo":
			return best_combo >= int(req["value"])
		"waves":
			return best_waves >= int(req["value"])
		"flag":
			var key := String(req["key"])
			if key == "zero_miss_wave":
				return zero_miss_wave_achieved
			if key == "five_cashouts":
				return five_cashouts_achieved
			return false
	return true

func _is_unlocked(entry: Dictionary) -> bool:
	if cheat_all_unlocked:
		return true
	if not entry.has("unlock"):
		return true
	return _meets_requirement(entry["unlock"])

func _requirement_text(req: Dictionary) -> String:
	match req["type"]:
		"round":
			return "Reach Round %d" % int(req["value"])
		"score":
			return "Score %d" % int(req["value"])
		"combo":
			return "Combo x%d" % int(req["value"])
		"waves", "flag":
			return String(req.get("text", ""))
	return ""

func _on_settings_button_pressed() -> void:
	_refresh_settings_content()
	if settings_panel.visible:
		return
	await _slide_in_panel(settings_panel, settings_scroll, Vector2(70, 0))
	_refresh_loadout_hud()

func _refresh_settings_content() -> void:
	settings_confirm_row.visible = false
	settings_reset_button.visible = true
	best_score_label.text = str(best_score)
	best_round_label.text = str(best_round)
	best_combo_label.text = str(best_combo)
	var accent: Color = THEMES[current_theme_index]["accent"]
	var accent_text: Color = THEMES[current_theme_index].get("accent_text", Color.BLACK)
	var border: Color = THEMES[current_theme_index]["border"]
	for i in scale_buttons.size():
		var unlocked := _is_unlocked(SCALES[i])
		var active := unlocked and i == current_scale_index
		scale_buttons[i].disabled = not unlocked
		scale_card_notes_rows[i].visible = unlocked
		scale_card_unlock_labels[i].visible = not unlocked
		_style_pick_badge(scale_card_badges[i], active, not unlocked, accent, accent_text)
		_style_pick_card(scale_buttons[i], active, not unlocked, accent, border, 10)
	# Only Premium & Minimal leaves the pad palette to the player - every other
	# theme carries its own fixed pad_style, so the palette picker only makes
	# sense (and only appears) while Premium & Minimal is active.
	palette_section.visible = current_theme_index == 0
	for i in palette_buttons.size():
		var unlocked := _is_unlocked(PALETTES[i])
		var active := unlocked and i == current_palette_index and current_theme_index == 0
		palette_buttons[i].disabled = not unlocked
		palette_card_unlock_labels[i].visible = not unlocked
		_style_pick_badge(palette_card_badges[i], active, not unlocked, accent, accent_text)
		_style_pick_card(palette_buttons[i], active, not unlocked, accent, border, 8)
	for i in theme_buttons.size():
		var unlocked := _is_unlocked(THEMES[i])
		var active := unlocked and i == current_theme_index
		theme_buttons[i].disabled = not unlocked
		theme_card_unlock_labels[i].visible = not unlocked
		_style_pick_badge(theme_card_badges[i], active, not unlocked, accent, accent_text)
		_style_pick_card(theme_buttons[i], active, not unlocked, accent, border, 10)

func _on_settings_close_pressed() -> void:
	await _slide_out_panel(settings_panel, settings_scroll, Vector2(70, 0))
	_refresh_loadout_hud()

# Quick slide-in/out from the edge, used for panel open/close transitions.
func _slide_in_panel(panel: Control, content: Control, offset: Vector2, duration := 0.22) -> void:
	panel.visible = true
	content.modulate.a = 0.0
	await get_tree().process_frame
	var target := content.position
	content.position = target + offset
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(content, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(content, "modulate:a", 1.0, duration)
	await t.finished

func _slide_out_panel(panel: Control, content: Control, offset: Vector2, duration := 0.18) -> void:
	var start := content.position
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(content, "position", start + offset, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(content, "modulate:a", 0.0, duration)
	await t.finished
	panel.visible = false
	content.position = start
	content.modulate.a = 1.0

func _on_scale_button_pressed(index: int) -> void:
	if not _is_unlocked(SCALES[index]):
		return
	current_scale_index = index
	_apply_scale_and_palette()
	_on_settings_button_pressed()

func _on_palette_button_pressed(index: int) -> void:
	if not _is_unlocked(PALETTES[index]):
		return
	current_palette_index = index
	_apply_scale_and_palette()
	_save_progress()
	_on_settings_button_pressed()

func _on_theme_button_pressed(index: int) -> void:
	if not _is_unlocked(THEMES[index]):
		return
	current_theme_index = index
	_apply_theme()
	_apply_scale_and_palette()
	_save_progress()
	_on_settings_button_pressed()

func _on_reset_ask_pressed() -> void:
	settings_reset_button.visible = false
	settings_confirm_row.visible = true

func _on_reset_cancel_pressed() -> void:
	settings_confirm_row.visible = false
	settings_reset_button.visible = true

func _on_reset_progress_pressed() -> void:
	best_score = 0
	best_round = 0
	best_combo = 0
	cheat_all_unlocked = false
	current_scale_index = 0
	current_palette_index = 0
	current_theme_index = 0
	_save_progress()
	_apply_theme()
	_apply_scale_and_palette()
	settings_confirm_row.visible = false
	settings_reset_button.visible = true
	_on_settings_button_pressed()
	_show_toast("Progress Reset")

func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	best_score = int(data.get("best_score", 0))
	best_round = int(data.get("best_round", 0))
	best_combo = int(data.get("best_combo", 0))
	best_waves = int(data.get("best_waves", 0))
	zero_miss_wave_achieved = bool(data.get("zero_miss_wave_achieved", false))
	five_cashouts_achieved = bool(data.get("five_cashouts_achieved", false))
	cheat_all_unlocked = bool(data.get("cheat_all_unlocked", false))
	onboarding_seen = bool(data.get("onboarding_seen", false))
	# Selected-id persistence for Palette and Theme (Theme mirrors Palette's
	# schema per GAME_DESIGN.md 1.1/open-items: no separate "unlocked set" is
	# stored for either - unlock state is derived fresh from best_round/
	# best_score/best_combo via _is_unlocked()/_meets_requirement() every load,
	# same as Scales - only the player's *selected* index is persisted here.
	# Falls back to 0 (the always-unlocked default entry) if the saved index
	# is out of range or points at something no longer unlocked (e.g. after a
	# Reset Progress on a different save, or a shortened array), so a corrupt
	# or stale save can never select a locked/nonexistent entry on load.
	var saved_palette_index := int(data.get("current_palette_index", 0))
	if saved_palette_index >= 0 and saved_palette_index < PALETTES.size() and _is_unlocked(PALETTES[saved_palette_index]):
		current_palette_index = saved_palette_index
	var saved_theme_index := int(data.get("current_theme_index", 0))
	if saved_theme_index >= 0 and saved_theme_index < THEMES.size() and _is_unlocked(THEMES[saved_theme_index]):
		current_theme_index = saved_theme_index
	var saved_mix: Variant = data.get("mix_levels", {})
	if typeof(saved_mix) == TYPE_DICTIONARY:
		for bus_name in MIX_BUSES:
			mix_levels[bus_name] = float(saved_mix.get(bus_name, MIX_DEFAULTS[bus_name]))
	reduce_motion = bool(data.get("reduce_motion", false))

func _save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"best_score": best_score,
		"best_round": best_round,
		"best_combo": best_combo,
		"best_waves": best_waves,
		"zero_miss_wave_achieved": zero_miss_wave_achieved,
		"five_cashouts_achieved": five_cashouts_achieved,
		"cheat_all_unlocked": cheat_all_unlocked,
		"onboarding_seen": onboarding_seen,
		"mix_levels": mix_levels,
		"reduce_motion": reduce_motion,
		"current_palette_index": current_palette_index,
		"current_theme_index": current_theme_index,
	}))

func _register_best(round_reached: int, current_score: int, current_combo: int) -> void:
	var prev_round := best_round
	var prev_score := best_score
	var prev_combo := best_combo
	var improved := false
	if round_reached > best_round:
		best_round = round_reached
		improved = true
	if current_score > best_score:
		best_score = current_score
		improved = true
	if current_combo > best_combo:
		best_combo = current_combo
		improved = true
	if improved:
		_save_progress()
		if not cheat_all_unlocked:
			_check_new_unlocks(prev_round, prev_score, prev_combo)

func _meets_requirement_values(req: Dictionary, round_val: int, score_val: int, combo_val: int) -> bool:
	match req["type"]:
		"round":
			return round_val >= int(req["value"])
		"score":
			return score_val >= int(req["value"])
		"combo":
			return combo_val >= int(req["value"])
	return true

func _check_new_unlocks(prev_round: int, prev_score: int, prev_combo: int) -> void:
	# Accumulated silently during play - surfaced once on the end-of-run
	# summary rather than as a mid-run interruption (was too jarring).
	for entry in SCALES + PALETTES + THEMES:
		if not entry.has("unlock"):
			continue
		var req: Dictionary = entry["unlock"]
		var was_met := _meets_requirement_values(req, prev_round, prev_score, prev_combo)
		if _meets_requirement(req) and not was_met:
			run_new_unlocks.append(entry)

func _on_zen_button_pressed() -> void:
	await _cross_fade_mode_switch(func():
		zen_mode = true
		_reset_pad_positions()
		start_button.visible = false
		chaos_button.visible = false
		zen_button.visible = false
		music_button.visible = false
		duet_button.visible = false
		round_label.visible = false
		combo_label.visible = false
		score_label.visible = false
		cash_out_button.visible = false
		zen_bar.visible = true
		settings_button.disabled = false
		_set_pads_disabled(false)
	)

func _on_exit_zen_pressed() -> void:
	await _cross_fade_mode_switch(func():
		zen_mode = false
		start_button.visible = true
		chaos_button.visible = true
		zen_button.visible = true
		music_button.visible = true
		duet_button.visible = true
		round_label.visible = true
		combo_label.visible = true
		score_label.visible = true
		zen_bar.visible = false
		round_label.text = "Round: 0"
		score_label.text = "Score: 0"
		start_button.disabled = false
		chaos_button.disabled = false
		zen_button.disabled = false
		music_button.disabled = false
		duet_button.disabled = false
		settings_button.disabled = false
		_set_pads_disabled(true)
	)

func _on_music_button_pressed() -> void:
	await _cross_fade_mode_switch(func():
		music_mode = true
		_reset_pad_positions()
		start_button.visible = false
		chaos_button.visible = false
		zen_button.visible = false
		music_button.visible = false
		duet_button.visible = false
		round_label.visible = false
		combo_label.visible = false
		score_label.visible = false
		cash_out_button.visible = false
		music_bar.visible = true
		settings_button.disabled = false
		_set_pads_disabled(true)
		_reset_music_idiom_sliders()
	)
	_music_loop()

func _on_exit_music_pressed() -> void:
	_print_music_degree_distribution()
	await _cross_fade_mode_switch(func():
		music_mode = false
		start_button.visible = true
		chaos_button.visible = true
		zen_button.visible = true
		music_button.visible = true
		duet_button.visible = true
		round_label.visible = true
		combo_label.visible = true
		score_label.visible = true
		music_bar.visible = false
		music_tune_panel.visible = false
		round_label.text = "Round: 0"
		score_label.text = "Score: 0"
		start_button.disabled = false
		chaos_button.disabled = false
		zen_button.disabled = false
		music_button.disabled = false
		duet_button.disabled = false
		settings_button.disabled = false
		_set_pads_disabled(true)
	)

# Euclidean rhythm (Bjorklund's algorithm): distributes `pulses` onsets as
# evenly as possible across `steps`, e.g. E(3,8) -> 10010010. Standard
# "fill two bucket lists, repeatedly fold the shorter into the longer"
# construction.
func _euclidean_rhythm(pulses: int, steps: int) -> Array[bool]:
	if pulses <= 0:
		var empty: Array[bool] = []
		empty.resize(steps)
		empty.fill(false)
		return empty
	if pulses >= steps:
		var full: Array[bool] = []
		full.resize(steps)
		full.fill(true)
		return full
	var a: Array = []
	for i in pulses:
		a.append([true])
	var b: Array = []
	for i in steps - pulses:
		b.append([false])
	while b.size() > 1:
		var m: int = min(a.size(), b.size())
		var new_a: Array = []
		for i in m:
			new_a.append(a[i] + b[i])
		var remainder_a: Array = a.slice(m)
		var remainder_b: Array = b.slice(m)
		a = new_a
		b = remainder_a if not remainder_a.is_empty() else remainder_b
	var flat: Array[bool] = []
	for group in a:
		for v in group:
			flat.append(v)
	for group in b:
		for v in group:
			flat.append(v)
	return flat

# One bar's worth of onsets for a Music Mode phrase - pulse count re-rolled
# each call so successive bars don't feel mechanically identical.
func _generate_music_rhythm() -> Array[bool]:
	var pulses := randi_range(MUSIC_PULSES_MIN, MUSIC_PULSES_MAX)
	return _euclidean_rhythm(pulses, MUSIC_RHYTHM_STEPS)

# Reflecting boundary (Xenakis's random-walk barrier technique - see
# docs/music-mode.md): an out-of-range step bounces back into range by the
# amount it overshot, rather than clamping to the edge value. Clamping was
# forcing the walk to deterministically pick a single "safe" direction
# whenever it stood on an edge with no established direction yet (e.g. every
# game's opening note, always the tonic), which killed melodic variety right
# where it mattered most. Reflection keeps direction fully random and still
# guarantees real movement.
func _reflect_degree(raw_target: int) -> int:
	var reflected := raw_target
	if reflected < 0:
		reflected = -reflected
	elif reflected > PAD_COUNT - 1:
		reflected = (PAD_COUNT - 1) * 2 - reflected
	return clampi(reflected, 0, PAD_COUNT - 1)

# Fix for a measured note-frequency bias (see docs/music-mode.md#note-
# distribution-bias-fix). Round 1 (superseded) always resolved anchor-
# return/phrase-end to degree 0 specifically - one edge of the walk's range,
# not the middle - which is textbook random-walk "mean reversion": an
# excursion away from a reset point gets cut short before it can reach the
# far edge, so degree 0's *neighborhood* got over-visited. Splitting the
# reset target across the tonic's every in-range octave fixed that lopsided
# decay, but logged histograms of the "fixed" version were still uneven in a
# musically wrong way: the b3 degree (F, adjacent to the tonic's two
# reset points) consistently out-visited the 5th/dominant degree (A) 2-4x
# over, even though real tonal melodies favor the dominant on par with the
# tonic - see Krumhansl & Kessler's tonal-hierarchy probe-tone studies
# (docs/music-mode.md#note-distribution-bias-fix has the full writeup and
# sources). The walk had no concept of *which* degrees are musically
# important - "close to a reset point" isn't the same thing as "structurally
# stable" - so proximity to the tonic's magnets, not real tonal function,
# was deciding what got favored.
#
# Round 2: resolution now targets any scale degree in the tonic triad
# (tonic, third, fifth - identified generically via semitone distance from
# the tonic, not hardcoded per scale), weighted by tonal-hierarchy tier
# (tonic weighted highest, third/fifth next, passing tones excluded
# entirely - resolving to an unstable degree would defeat the point of
# "resolution"). This generalizes round 1: the tonic's octave is still in
# the stable set (0 semitones from the tonic, same as the tonic itself) and
# still gets the highest weight, but the dominant and mediant now get a
# real, weighted share of resolution traffic instead of none.
const MUSIC_DEGREE_WEIGHT_TONIC := 2.4
const MUSIC_DEGREE_WEIGHT_TRIAD := 1.5
# Round 3 (see docs/music-mode.md#note-distribution-bias-fix): round 2's
# weighting was fair among stable degrees, but the *overall* histogram still
# showed the mediant (F) beating the tonic (D) - traced to degree 0 being a
# hard wall. `_reflect_degree()` means a boundary degree has exactly one
# neighbor, so any stepwise departure from it is forced onto that single
# neighbor 100% of the time (no coin flip), inflating whichever degree
# happens to sit next to a wall regardless of its own tonal importance. An
# interior instance of the same pitch class (e.g. degree 5, this scale's
# other D) doesn't have that problem - stepwise departures from it split
# across two neighbors like everywhere else. Discounting boundary degrees
# relative to interior ones so resolution prefers the interior instance when
# one exists (falling back to the boundary degree when it's the only option,
# e.g. `chromatic_run`'s single, non-repeating tonic) removes the forced-
# neighbor effect without touching the tonal-hierarchy tiering itself.
const MUSIC_DEGREE_WEIGHT_BOUNDARY_FACTOR := 0.4

# Semitone distance from the tonic (degree 0), via the scale's actual tuned
# frequencies rather than hardcoded per-scale music theory - works for any
# scale definition in SCALES, including ones with unusual/non-diatonic
# interval structure.
func _semitones_from_tonic(degree: int, scale: Dictionary) -> int:
	var tones: Array = scale.get("tones", [])
	if tones.is_empty() or degree >= tones.size() or float(tones[0]) <= 0.0:
		return 0
	var ratio: float = float(tones[degree]) / float(tones[0])
	var semitones := int(round(12.0 * log(ratio) / log(2.0))) % 12
	return semitones + 12 if semitones < 0 else semitones

# Tonal-hierarchy weight for a degree: tonic (0 or 12 semitones - i.e. any
# octave) highest, minor/major third (3-4 semitones) or perfect fifth
# (7 semitones) next, everything else (passing tones - 2nds, 4ths, 6ths,
# 7ths) excluded from resolution entirely (weight 0). Degrees at either edge
# of the pad range (0 or PAD_COUNT-1) get discounted - see
# MUSIC_DEGREE_WEIGHT_BOUNDARY_FACTOR above.
func _scale_degree_weight(degree: int, scale: Dictionary) -> float:
	var semitones := _semitones_from_tonic(degree, scale)
	var weight := 0.0
	if semitones == 0:
		weight = MUSIC_DEGREE_WEIGHT_TONIC
	elif semitones == 3 or semitones == 4 or semitones == 7:
		weight = MUSIC_DEGREE_WEIGHT_TRIAD
	else:
		return 0.0
	if degree == 0 or degree == PAD_COUNT - 1:
		weight *= MUSIC_DEGREE_WEIGHT_BOUNDARY_FACTOR
	return weight

func _pick_resolution_degree(scale: Dictionary) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for d in PAD_COUNT:
		var w := _scale_degree_weight(d, scale)
		weights.append(w)
		total += w
	if total <= 0.0:
		return 0
	var r := randf() * total
	for d in PAD_COUNT:
		r -= weights[d]
		if r <= 0.0:
			return d
	return PAD_COUNT - 1

func _is_resolution_degree(degree: int, scale: Dictionary) -> bool:
	return _scale_degree_weight(degree, scale) > 0.0

# Chord tones on strong beats (see docs/music-mode.md#chord-tones-on-strong-
# beats): standard tonal/counterpoint practice puts chord tones on strong
# metrical positions and reserves passing tones for weak ones. Finds the
# closest degree with a nonzero _scale_degree_weight() (a local nudge, not a
# jump to a weighted-random one - see the call site in
# _generate_music_bar_melody() for why).
func _nearest_chord_tone_degree(degree: int, scale: Dictionary) -> int:
	var best := degree
	var best_dist := PAD_COUNT
	for d in PAD_COUNT:
		if _scale_degree_weight(d, scale) <= 0.0:
			continue
		var dist := absi(d - degree)
		if dist < best_dist:
			best_dist = dist
			best = d
	return best

func _music_reset_walk() -> void:
	# Random starting degree, not always the tonic - so each Music/Duet
	# session opens differently rather than sounding like the same song
	# restarting (mid-session phrase resolution still lands on the tonic
	# every MUSIC_PHRASE_BARS bars, same as before).
	_music_current_degree = randi() % PAD_COUNT
	_music_last_direction = 0
	_music_last_was_leap = false
	_music_bar_index = 0
	_music_repeat_streak = 1
	_music_groove_bars_left = 0
	_music_degree_counts = {}
	_music_notes_logged = 0

# Biased random walk step: mostly stepwise motion, some repeats, occasional
# leaps. Direction follows two documented melodic tendencies (Huron, "Sweet
# Anticipation"; Narmour's implication-realization model) rather than an
# arbitrary streak-count rule:
# - step inertia: a stepwise move tends to be followed by another step in
#   the same direction, not a reversal.
# - post-skip reversal: a leap tends to be followed by stepwise motion back
#   the other way, "filling the gap" it just opened.
func _music_next_delta(max_leap: int) -> int:
	var repeat_chance: float = BASE_REPEAT_CHANCE * pow(REPEAT_DECAY, float(_music_repeat_streak - 1))
	var step_chance := (1.0 - repeat_chance) * STEP_TO_NON_REPEAT_RATIO
	var r := randf()
	var magnitude: int
	if r < repeat_chance:
		magnitude = 0
	elif r < repeat_chance + step_chance:
		magnitude = 1
	else:
		magnitude = randi_range(2, max_leap)
	if magnitude == 0:
		_music_last_was_leap = false
		return 0
	var direction: int
	var is_gap_fill := false
	if _music_last_was_leap and _music_last_direction != 0:
		direction = -_music_last_direction
		magnitude = 1
		is_gap_fill = true
	elif _music_last_direction != 0 and magnitude == 1:
		direction = _music_last_direction if randf() < 0.70 else -_music_last_direction
	else:
		# No established scale-degree direction to defer to (session start,
		# or right after a phrase-end/anchor-return reset) - bias toward
		# whichever direction lands on the opposite side of the physical
		# ring, rather than a flat coin flip, per the zigzag idiom.
		var zigzag_bias := _music_idiom_value("zigzag_bias")
		var current_side := _music_ring_side(_music_current_degree)
		var plus_side := _music_ring_side(_reflect_degree(_music_current_degree + magnitude))
		var minus_side := _music_ring_side(_reflect_degree(_music_current_degree - magnitude))
		if plus_side != current_side and minus_side == current_side:
			direction = 1 if randf() < zigzag_bias else -1
		elif minus_side != current_side and plus_side == current_side:
			direction = -1 if randf() < zigzag_bias else 1
		else:
			direction = 1 if randf() < 0.5 else -1
	# Melodic arch (see docs/music-mode.md#melodic-arch) - not applied to a
	# gap-fill reversal, since that's a hard contour rule (Narmour) the arch
	# shouldn't second-guess.
	if not is_gap_fill and randf() < MUSIC_ARCH_BIAS:
		direction = _music_arch_direction()
	_music_last_direction = direction
	_music_last_was_leap = magnitude >= 2
	return direction * magnitude

# Which way the phrase-level melodic arch wants the walk to move right now -
# up through the first half of a phrase, down through the second half. See
# docs/music-mode.md#melodic-arch.
func _music_arch_direction() -> int:
	return 1 if (_music_bar_index % MUSIC_PHRASE_BARS) * 2 < MUSIC_PHRASE_BARS else -1

# One bar's worth of scale degrees (0-7), one per rhythm pulse. Forced back
# to a resolution degree (tonic/third/fifth, weighted by tonal-hierarchy
# tier - see _pick_resolution_degree()) on the last note of every
# MUSIC_PHRASE_BARS-th bar, so phrases have a clear landing point.
func _generate_music_bar_melody(pulse_count: int) -> Array[int]:
	if pulse_count <= 0:
		return []
	var scale: Dictionary = SCALES[current_scale_index]
	var is_narrow: bool = MUSIC_NARROW_LEAP_SCALES.has(scale["id"])
	var max_leap := MUSIC_NARROW_MAX_LEAP if is_narrow else MUSIC_PENTATONIC_MAX_LEAP
	var degrees: Array[int] = []
	# Canonical riff shape: only offered at the start of a phrase (mirrors
	# how these are taught - fixed little patterns, not spliced into the
	# middle of an improvised line). Expressed as offsets from wherever the
	# walk currently sits, not hardcoded to degree 0, so it still works when
	# a session opens on a non-tonic degree (see _music_reset_walk()).
	var riff: Array = []
	if _music_bar_index % MUSIC_PHRASE_BARS == 0 and randf() < _music_idiom_value("riff_shapes"):
		riff = MUSIC_RIFF_SHAPES[randi() % MUSIC_RIFF_SHAPES.size()]
	var riff_base := _music_current_degree
	for i in pulse_count:
		if i < riff.size():
			var riff_degree := _reflect_degree(riff_base + int(riff[i]))
			degrees.append(riff_degree)
			_music_current_degree = riff_degree
			_music_last_direction = 0
			_music_repeat_streak = 1
			continue
		var degree := _music_current_degree
		# Chord tones on strong beats (see docs/music-mode.md#chord-tones-on-
		# strong-beats): pulse 0 is always the bar's downbeat (the Euclidean
		# generator always places an onset at step 0 - see
		# _euclidean_rhythm()), so nudge it to the nearest chord tone when the
		# walk happens to be sitting on a passing tone there, rather than
		# leaving harmonic placement to chance. A nudge to the *nearest*
		# chord tone, not a jump to a weighted-random one like anchor-return -
		# this is meant to read as "the walk's current position resolved
		# slightly," not a deliberate drone return.
		if i == 0 and not _is_resolution_degree(degree, scale) and randf() < MUSIC_STRONG_BEAT_CHORD_TONE_CHANCE:
			degree = _nearest_chord_tone_degree(degree, scale)
			_music_current_degree = degree
		if not _is_resolution_degree(degree, scale) and randf() < _music_idiom_value("anchor_return"):
			# Ghost return to a tonal-hierarchy-weighted tonic/third/fifth,
			# same reset the phrase-end resolution below does - so the walk
			# resumes cleanly from the anchor rather than carrying momentum
			# from before the jump. See _pick_resolution_degree() for why
			# this isn't just degree 0.
			degree = _pick_resolution_degree(scale)
			_music_current_degree = degree
			_music_last_direction = 0
			_music_repeat_streak = 1
		degrees.append(degree)
		var delta := _music_next_delta(max_leap)
		var raw_target := degree + delta
		var new_degree := _reflect_degree(raw_target)
		if new_degree != raw_target and delta != 0:
			# Bounced off the scale's edge - flip the stored direction so
			# step inertia continues in the direction the walk actually
			# reflected toward, not the blocked one.
			_music_last_direction = -_music_last_direction
		if new_degree == degree:
			_music_repeat_streak += 1
		else:
			_music_repeat_streak = 1
		_music_current_degree = new_degree
	_music_bar_index += 1
	if _music_bar_index % MUSIC_PHRASE_BARS == 0:
		var resolution_degree := _pick_resolution_degree(scale)
		degrees[degrees.size() - 1] = resolution_degree
		_music_current_degree = resolution_degree
		_music_last_direction = 0
	return degrees

# Looks up the pad currently tuned to a scale degree, per the ring_order
# mapping _apply_scale_and_palette() already maintains - stays correct
# across scale changes without any Music-Mode-specific retuning logic.
func _music_pad_for_degree(degree: int) -> SimonButton:
	var scale: Dictionary = SCALES[current_scale_index]
	var ring_order: Array = scale.get("ring_order", [0, 1, 2, 3, 4, 5, 6, 7])
	var ring_pos: int = ring_order.find(degree)
	if ring_pos == -1:
		return null
	return pads_by_name[pad_names[ring_pos]]

# Which physical half of the ring a scale degree sits on, per the current
# scale's ring_order - used for the zigzag contour bias, not for lookup.
func _music_ring_side(degree: int) -> int:
	var scale: Dictionary = SCALES[current_scale_index]
	var ring_order: Array = scale.get("ring_order", [0, 1, 2, 3, 4, 5, 6, 7])
	var ring_pos: int = ring_order.find(degree)
	if ring_pos == -1:
		return 0
	return 0 if ring_pos < PAD_COUNT / 2 else 1

# Glissando sweep (see docs/music-mode.md#idioms-borrowed-from-how-the-real-instrument-is-played) - a quick single-
# direction run across every pad, played as a rare special event between
# phrases rather than folded into the normal rhythm/melody roll. Swept by
# scale degree (pitch order), not by ring_pos (physical ring layout) - the
# ring is deliberately zigzagged for playability, so a ring-order sweep
# jumps around in pitch rather than sliding, which read as random blips
# instead of a glissando. Degree order is pitch-ascending (see the `tones`
# arrays in SCALES), so this always slides smoothly up or down even though
# it lights pads in their zigzagged physical positions on screen.
func _music_glissando_sweep(step_duration: float) -> void:
	var spacing: float = clampf(step_duration * MUSIC_GLISSANDO_SPACING_FRACTION, MUSIC_GLISSANDO_MIN_SPACING, MUSIC_GLISSANDO_MAX_SPACING)
	var flash_dur := spacing * MUSIC_GLISSANDO_FLASH_FRACTION
	var degrees := range(PAD_COUNT)
	if randf() < 0.5:
		degrees.reverse()
	for degree in degrees:
		if not music_mode:
			return
		var pad := _music_pad_for_degree(degree)
		if pad:
			await pad.flash(flash_dur, MUSIC_GLISSANDO_DECAY, MUSIC_GLISSANDO_VOLUME)
		var remaining := spacing - flash_dur
		if remaining > 0.0:
			await get_tree().create_timer(remaining).timeout

# Debug instrumentation - tallies how often each scale degree gets played
# and prints a running histogram every MUSIC_LOG_INTERVAL notes, so a
# suspected "the walk favors certain notes" bias can be checked against
# actual numbers rather than ear/memory. Remove once the walk's balance is
# confirmed one way or the other.
func _music_log_degree(degree: int) -> void:
	_music_degree_counts[degree] = _music_degree_counts.get(degree, 0) + 1
	_music_notes_logged += 1
	if _music_notes_logged % MUSIC_LOG_INTERVAL == 0:
		_print_music_degree_distribution()

func _print_music_degree_distribution() -> void:
	var total := 0
	for count in _music_degree_counts.values():
		total += count
	if total == 0:
		return
	var scale: Dictionary = SCALES[current_scale_index]
	var notes: Array = scale.get("notes", [])
	var expected_pct := 100.0 / PAD_COUNT
	var parts: Array[String] = []
	for degree in range(PAD_COUNT):
		var count: int = _music_degree_counts.get(degree, 0)
		var pct := 100.0 * count / total
		var note_name: String = notes[degree] if degree < notes.size() else str(degree)
		parts.append("%s=%d(%.0f%%)" % [note_name, count, pct])
	print("[MusicMode] n=%d, uniform=%.0f%%: %s" % [total, expected_pct, ", ".join(parts)])

# Drives Music Mode: generates one Euclidean-rhythm bar + melody phrase at a
# time and plays it, looping until the player exits. Tempo is fixed for the
# whole session; scale/theme changes take effect on the next note lookup
# automatically, so no explicit "retune" step is needed.
func _music_loop() -> void:
	_music_reset_walk()
	var bpm := randf_range(MUSIC_BPM_MIN, MUSIC_BPM_MAX)
	var step_duration := 60.0 / bpm / 4.0
	var flash_duration: float = min(step_duration * MUSIC_FLASH_FRACTION, MUSIC_FLASH_MAX)
	var last_played_pad: SimonButton = null
	while music_mode:
		if _music_bar_index > 0 and _music_bar_index % MUSIC_PHRASE_BARS == 0 and randf() < _music_idiom_value("glissando"):
			await _music_glissando_sweep(step_duration)
			if not music_mode:
				return
		var rhythm: Array[bool]
		if _music_groove_bars_left > 0:
			rhythm = _music_groove_rhythm
			_music_groove_bars_left -= 1
		else:
			rhythm = _generate_music_rhythm()
			if randf() < _music_idiom_value("groove_repeats"):
				_music_groove_rhythm = rhythm
				_music_groove_bars_left = MUSIC_GROOVE_HOLD_BARS
		var pulse_count := 0
		for on in rhythm:
			if on:
				pulse_count += 1
		var melody := _generate_music_bar_melody(pulse_count)
		var note_i := 0
		for step_index in rhythm.size():
			if not music_mode:
				return
			if rhythm[step_index]:
				var degree := melody[note_i]
				var pad := _music_pad_for_degree(degree)
				note_i += 1
				_music_log_degree(degree)
				var is_downbeat := step_index == 0
				var decay := MUSIC_ACCENT_DECAY if is_downbeat else MUSIC_DECAY_RATE
				var volume := MUSIC_ACCENT_VOLUME if is_downbeat else MUSIC_VOLUME
				if pad:
					await pad.flash(flash_duration, decay, volume)
					last_played_pad = pad
				var remaining := step_duration - flash_duration
				if remaining > 0.0:
					await get_tree().create_timer(remaining).timeout
			elif last_played_pad and randf() < _music_idiom_value("ghost_notes"):
				# Ghost note: quiet filler tap on the last real note's pad,
				# doesn't touch the melody walk at all.
				var ghost_flash: float = min(step_duration * MUSIC_GHOST_FLASH_FRACTION, flash_duration)
				await last_played_pad.flash(ghost_flash, MUSIC_GHOST_DECAY, MUSIC_GHOST_VOLUME)
				var remaining := step_duration - ghost_flash
				if remaining > 0.0:
					await get_tree().create_timer(remaining).timeout
			else:
				await get_tree().create_timer(step_duration).timeout

# Full-screen cross-fade for a mode switch that swaps the whole UI layout
# (currently Zen entry/exit) - covers the abrupt visibility toggle.
func _cross_fade_mode_switch(apply_state: Callable) -> void:
	var t := create_tween()
	t.tween_property(flash_overlay, "color", Color(0.05, 0.05, 0.07, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	apply_state.call()
	var t2 := create_tween()
	t2.tween_property(flash_overlay, "color:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t2.finished

func _on_start_pressed(mode: String) -> void:
	run_start_best_score = best_score
	run_start_best_round = best_round
	run_start_best_combo = best_combo
	run_new_unlocks.clear()
	chaos_mode = mode == "chaos"
	duet_mode = mode == "duet"
	duet_round = 0
	if duet_mode:
		_music_reset_walk()
	elif not chaos_mode:
		_normal_reset_walk()
	if not chaos_mode:
		_reset_pad_positions()
	sequence.clear()
	gold_indices.clear()
	player_index = 0
	score = 0
	combo = 0
	waves_completed = 0
	duet_wave_round = 0
	total_round = 0
	unbanked_points = 0
	run_cashout_count = 0
	cash_out_floor = 0
	best_streak_this_run = 0
	equipped_modifiers = {"multiplier": "", "defense": "", "tempo": "", "bonus_event": ""}
	modifier_levels.clear()
	max_hearts = RUN_START_HEARTS
	hearts = RUN_START_HEARTS
	_recompute_pure_modifier_stats()
	_start_new_streak_modifier_state()
	_refresh_loadout_hud()
	_refresh_hearts_hud()
	_update_score_labels()
	start_button.disabled = true
	chaos_button.disabled = true
	start_button.text = "Normal Mode"
	chaos_button.text = "Chaos Mode"
	duet_button.text = "Duet Mode"
	settings_button.disabled = true
	zen_button.disabled = true
	music_button.disabled = true
	duet_button.disabled = true
	cash_out_button.visible = true
	_next_round()

func _current_round() -> int:
	return duet_round if duet_mode else total_round

# Current streak length since the last cash out - the quantity the cash-out
# bonus scales off of. Sequence length for Normal/Chaos (cumulative); Duet's
# own wave-local round counter for Duet (its phrase isn't cumulative).
# Both of those increment when a round is *queued*, so until the player
# actually lands a hit this round we report the previous completed length.
func _current_wave_length() -> int:
	var queued := duet_wave_round if duet_mode else sequence.size()
	if current_round_has_hit:
		return queued
	return max(0, queued - 1)

# The streak-length bonus only - additional on top of `unbanked_points`,
# which already holds the streak's real per-hit score. Includes
# score_bonus_percent (Resonance) alongside the combo-growth multiplier
# (Sharper Ear) - both are "current score multiplier" effects, and both
# should compound into cash-outs, not just per-hit score. This was a real
# gap found in a modifier audit: Resonance's bonus previously only reached
# `unbanked_points` (via `_register_hit`), never the streak bonus itself.
# Crescendo (Multiplier): scales off waves completed *this run*, additive
# by default, multiplicative (^waves_completed) at L5 - a genuinely
# different growth shape for the mastery payoff, not just a bigger number.
func _crescendo_multiplier() -> float:
	if equipped_modifiers["multiplier"] != "crescendo":
		return 1.0
	var per_wave := float(_mod_val("crescendo", "per_wave"))
	if bool(_mod_val("crescendo", "multiplicative")):
		return pow(1.0 + per_wave, float(waves_completed))
	return 1.0 + per_wave * float(waves_completed)

# Fortissimo (Multiplier, power): active once the *current* streak passes
# your own best streak this run by the level's margin.
func _fortissimo_multiplier() -> float:
	if equipped_modifiers["multiplier"] != "fortissimo":
		return 1.0
	var margin := int(_mod_val("fortissimo", "margin"))
	if _current_wave_length() >= best_streak_this_run + margin:
		return float(_mod_val("fortissimo", "mult"))
	return 1.0

# Perfect Pitch (Multiplier): "a nice cadence" means something genuinely
# different per mode, so this now branches rather than using one formula
# everywhere - an earlier version matched the call's playback pace in every
# mode, which fixed Duet (see below) but broke Normal/Chaos: a player who's
# mastered the sequence and blazes through it correctly got *penalized* for
# being fast, which is backwards - real mastery should never be a liability.
#
# Duet: matching `_call_step_ms_per_note` (the real pace the phrase was just
# played back at) is the right target, because Duet's whole premise is
# echoing a rhythm back accurately - staying aligned with, not blind to,
# the mode's own shipped timing-accuracy scoring.
#
# Normal/Chaos: there's no correct tempo to match - fast, confident recall
# is good, not a mistake - so instead this rewards a *smooth, non-erratic*
# pace: coefficient of variation (stdev / mean) of recent hit intervals,
# which is scale-invariant by construction, so a fast player tapping evenly
# scores exactly as well as a slow one. Only genuinely erratic pacing
# (long pause, burst, long pause) fails it, regardless of overall speed.
func _perfect_pitch_multiplier() -> float:
	if equipped_modifiers["multiplier"] != "perfect_pitch":
		return 1.0
	var tolerance := float(_mod_val("perfect_pitch", "tolerance"))
	if duet_mode:
		if hit_timestamps_ms.size() < 2:
			return 1.0
		var ratio := recent_response_ms_per_note / maxf(_call_step_ms_per_note, 1.0)
		if absf(ratio - 1.0) <= tolerance:
			return 1.0 + float(_mod_val("perfect_pitch", "bonus"))
		return 1.0
	if hit_timestamps_ms.size() < PERFECT_PITCH_WINDOW + 1:
		return 1.0
	var intervals: Array[float] = []
	for i in range(1, hit_timestamps_ms.size()):
		intervals.append(float(hit_timestamps_ms[i] - hit_timestamps_ms[i - 1]))
	var mean := 0.0
	for v in intervals:
		mean += v
	mean /= intervals.size()
	if mean <= 0.0:
		return 1.0
	var variance := 0.0
	for v in intervals:
		variance += (v - mean) * (v - mean)
	variance /= intervals.size()
	var coeff_of_variation := sqrt(variance) / mean
	if coeff_of_variation <= tolerance:
		return 1.0 + float(_mod_val("perfect_pitch", "bonus"))
	return 1.0

# Harmonic Chain (Multiplier): stacking bonus for consecutive hits within
# the same musical chunk/motif - resets at the chunk boundary unless L5
# ("carry_across_chunks"), in which case it just keeps growing.
func _harmonic_chain_bonus_points(base_points: int) -> int:
	if equipped_modifiers["multiplier"] != "harmonic_chain":
		return 0
	var cid := _chunk_id_at(player_index)
	var prev_cid := _chunk_id_at(player_index - 1) if player_index > 0 else -1
	var carries := bool(_mod_val("harmonic_chain", "carry_across_chunks"))
	if player_index > 0 and (cid == prev_cid or carries):
		harmonic_chain_stack += float(_mod_val("harmonic_chain", "increment"))
	else:
		harmonic_chain_stack = float(_mod_val("harmonic_chain", "increment"))
	return int(round(float(base_points) * harmonic_chain_stack))

func _register_wave_completed() -> void:
	var floor_increment := CASHOUT_FLOOR_BASE * pow(CASHOUT_FLOOR_DECAY, float(run_cashout_count))
	cash_out_floor = min(CASHOUT_FLOOR_CAP, cash_out_floor + int(round(floor_increment)))
	run_cashout_count += 1
	if waves_completed > best_waves:
		var was_unlocked := best_waves >= 10
		best_waves = waves_completed
		_save_progress()
		if not was_unlocked and best_waves >= 10:
			run_new_unlocks.append({"name": "10 Waves Survived (Fortissimo)"})
	if not current_streak_had_miss and not zero_miss_wave_achieved:
		zero_miss_wave_achieved = true
		_save_progress()
		run_new_unlocks.append({"name": "Zero-Miss Wave (Second Wind / Unbreakable)"})
	if run_cashout_count >= 5 and not five_cashouts_achieved:
		five_cashouts_achieved = true
		_save_progress()
		run_new_unlocks.append({"name": "5 Cash-Outs in a Run (Grand Finale)"})

# See the MEMORY_SPAN_CEILING comment above for why this is linear-then-
# quadratic instead of a pure s² curve.
func _cash_out_base_bonus(s: int) -> float:
	var beyond := maxf(0.0, float(s) - float(MEMORY_SPAN_CEILING))
	return CASHOUT_LINEAR_K * float(s) + CASHOUT_QUADRATIC_K * beyond * beyond

func _cash_out_streak_bonus() -> int:
	var s := _current_wave_length() + double_down_boost_amount
	var multiplier := (1.0 + float(combo - 1) * combo_growth) * (1.0 + score_bonus_percent)
	multiplier *= _crescendo_multiplier()
	multiplier *= _fortissimo_multiplier()
	return int(round(_cash_out_base_bonus(s) * multiplier))

# Crescendo's own contribution to the streak bonus above, isolated the same
# "before/after" way Resonance's cascade line already works - Crescendo used
# to fold invisibly into one lump cash-out total with no attribution (audit
# pillar 1 fail). Display-only; doesn't change what _cash_out_streak_bonus()
# actually banks.
func _cash_out_streak_bonus_without_crescendo() -> int:
	var s := _current_wave_length() + double_down_boost_amount
	var multiplier := (1.0 + float(combo - 1) * combo_growth) * (1.0 + score_bonus_percent)
	multiplier *= _fortissimo_multiplier()
	return int(round(_cash_out_base_bonus(s) * multiplier))

# Total the player would bank right now: this streak's real per-hit points
# (`unbanked_points`) plus the streak-length bonus.
func _cash_out_total() -> int:
	return unbanked_points + _cash_out_streak_bonus()

# Player-triggered cash out ("kaching"): banks `unbanked_points` plus the
# streak bonus into real `score`, then resets the streak (sequence
# truncated to 0 notes for Normal/Chaos, `duet_wave_round` zeroed for Duet)
# while combo/combo_growth and all modifiers persist untouched.
func _on_cash_out_button_pressed() -> void:
	if zen_mode or music_mode or not accepting_input:
		return
	if grand_finale_pending:
		return
	if unbanked_points < cash_out_floor:
		return
	var total := _cash_out_total()
	if total <= 0:
		return
	var crescendo_delta := _cash_out_streak_bonus() - _cash_out_streak_bonus_without_crescendo()
	var fortissimo_new_best: bool = equipped_modifiers["multiplier"] == "fortissimo" and _mod_level("fortissimo") >= 5 and _current_wave_length() > best_streak_this_run
	if fortissimo_new_best:
		total += FORTISSIMO_FANFARE_BONUS
	# Captured before the streak resets below - Encore needs the phrase that
	# was just cashed out, not whatever's left after truncation/clearing.
	var final_phrase: Array = sequence.duplicate()
	score += total
	unbanked_points = 0
	waves_completed += 1
	_register_wave_completed()
	_try_second_wind_refill()
	accepting_input = false
	_set_pads_disabled(true)
	if duet_mode:
		duet_wave_round = 0
	else:
		sequence = sequence.slice(0, min(WAVE_RESET_LENGTH, sequence.size()))
	_start_new_streak_modifier_state()
	_update_score_labels()
	_punch(score_label)
	_spawn_score_popup(cash_out_button.global_position + cash_out_button.size / 2.0, "+%d" % total, Color(1, 0.85, 0.3))
	if crescendo_delta > 0:
		get_tree().create_timer(0.16).timeout.connect(_spawn_score_popup.bind(cash_out_button.global_position + cash_out_button.size / 2.0 + Vector2(-24, -22), "Crescendo +%d" % crescendo_delta, CATEGORY_COLORS["multiplier"]))
	_flash_screen(Color(1, 0.85, 0.3, 0.22))
	if fortissimo_new_best:
		_show_toast("Personal-Best Fanfare! +%d" % FORTISSIMO_FANFARE_BONUS)
	if equipped_modifiers["bonus_event"] == "encore":
		await _play_encore(total, final_phrase)
	_next_round()

# Encore (Bonus-Event): immediately replays the streak's final phrase once
# more for a bonus before the reset - a legible payoff on top of an already
# healthy cash-out, scaling to genuinely outpay the original at L5.
func _play_encore(cashout_total: int, final_phrase: Array) -> void:
	var pct := float(_mod_val("encore", "pct"))
	var bonus := int(round(float(cashout_total) * pct))
	if bonus <= 0 or final_phrase.is_empty():
		return
	await get_tree().create_timer(0.3).timeout
	var replay: Array = final_phrase.slice(max(0, final_phrase.size() - 4), final_phrase.size())
	for pad_name in replay:
		await pads_by_name[pad_name].flash(0.22)
		await get_tree().create_timer(0.12).timeout
	score += bonus
	_update_score_labels()
	_spawn_score_popup(cash_out_button.global_position + cash_out_button.size / 2.0, "Encore +%d" % bonus, Color(1, 0.6, 0.9))

# Grand Finale (Bonus-Event, power): opt-in "Double or Nothing" - wager the
# entire unbanked pool on completing the rest of the round currently in
# progress. Resolves through the normal hit/miss flow in _on_pad_pressed
# (Normal/Chaos) or _run_duet_response/_handle_duet_miss (Duet) rather than
# a single flagged note, so it plays exactly like the round would anyway -
# the wager only changes the payoff and the failure cost. No charge/cap
# (docs/modifier-audit.md rule 6) - always available whenever there's a
# pool to wager. The Gamble button is a deliberate, documented exception to
# "no manual activation": it sits at the same pause point as Cash Out
# (never mid-sequence), and the choice to gamble - not a resource to spend -
# is the entire point of the modifier.
func _start_grand_finale_gamble() -> void:
	if equipped_modifiers["bonus_event"] != "grand_finale" or not accepting_input:
		return
	if grand_finale_pending or unbanked_points <= 0:
		return
	if unbanked_points < cash_out_floor:
		return
	grand_finale_wager = unbanked_points
	grand_finale_pending = true
	_show_toast("Double or Nothing! Clear this round for x%.1f or bust." % float(_mod_val("grand_finale", "mult")))
	_update_score_labels()

func _resolve_grand_finale_win() -> void:
	var payout := int(round(float(grand_finale_wager) * float(_mod_val("grand_finale", "mult"))))
	unbanked_points = 0
	score += payout
	waves_completed += 1
	_register_wave_completed()
	_try_second_wind_refill()
	grand_finale_pending = false
	accepting_input = false
	_set_pads_disabled(true)
	if duet_mode:
		duet_wave_round = 0
	else:
		sequence = sequence.slice(0, min(WAVE_RESET_LENGTH, sequence.size()))
	_start_new_streak_modifier_state()
	_update_score_labels()
	_spawn_score_popup(cash_out_button.global_position, "Double! +%d" % payout, Color(1, 0.85, 0.3))
	_flash_screen(Color(1, 0.85, 0.3, 0.3))
	_next_round()

# insured (Lv.5): a loss can't actually cost the wager - it banks anyway,
# just at no multiplier, so a maxed Grand Finale never has a downside beyond
# "no bonus this time."
func _resolve_grand_finale_loss() -> void:
	var insured := bool(_mod_val("grand_finale", "insured"))
	if insured:
		_show_toast("Insured - wager banked anyway.")
		score += grand_finale_wager
	else:
		_show_toast("Nothing. Wager lost.")
	unbanked_points = 0
	grand_finale_pending = false
	accepting_input = false
	_set_pads_disabled(true)
	if duet_mode:
		duet_wave_round = 0
	else:
		sequence.clear()
	_start_new_streak_modifier_state()
	_update_score_labels()
	_flash_screen(Color(1, 0.3, 0.5, 0.25) if not insured else Color(1, 1, 1, 0.2))
	_next_round()

func _next_round() -> void:
	accepting_input = false
	current_round_has_hit = false
	_set_pads_disabled(true)
	if chaos_mode:
		_reshuffle_pad_positions()
	if duet_mode:
		duet_round += 1
		duet_wave_round += 1
		_generate_duet_phrase()
	elif chaos_mode:
		sequence.append(pad_names[randi() % pad_names.size()])
		total_round += 1
		_tag_chunk_for_new_note()
	else:
		sequence.append(_normal_next_pad_name())
		total_round += 1
		_tag_chunk_for_new_note()
	var round_prefix := "Chaos - " if chaos_mode else ("Duet - " if duet_mode else "")
	var queued := duet_wave_round if duet_mode else sequence.size()
	var wave_suffix := "  (Streak %d)" % queued
	round_label.text = (round_prefix + "Round: %d") % _current_round() + wave_suffix
	_roll_gold_indices()
	_roll_lucky_strike_index()
	await _play_sequence()
	if duet_mode:
		await _run_duet_response()
		return
	player_index = 0
	accepting_input = true
	_last_input_ms = Time.get_ticks_msec()
	_echo_chamber_hinted_this_note = false
	_quick_rewind_triggered_this_note = false
	_constellation_fade_out()
	_set_pads_disabled(false)
	_update_score_labels()

# One bar's call phrase for Duet Mode - reuses Music Mode's rhythm/melody
# generators (see docs/music-mode.md) rather than Normal/Chaos's uniform
# random note. Not cumulative like `sequence` normally is: each round is a
# fresh phrase, since Duet's challenge is timing/note precision per phrase,
# not memorizing an ever-growing sequence (that's Normal Mode's job).
func _generate_duet_phrase() -> void:
	var ramp_per_round := DUET_BPM_RAMP_PER_ROUND
	var bpm_lo := minf(DUET_BPM_BASE_MIN + float(duet_wave_round) * ramp_per_round, DUET_BPM_CAP - 10.0)
	var bpm_hi := minf(DUET_BPM_BASE_MAX + float(duet_wave_round) * ramp_per_round, DUET_BPM_CAP)
	var bpm := randf_range(bpm_lo, bpm_hi)
	duet_step_duration = 60.0 / bpm / 4.0
	var pulses_lo := clampi(1 + duet_wave_round, 2, MUSIC_PULSES_MIN)
	var pulses_hi := clampi(2 + duet_wave_round, 3, MUSIC_PULSES_MAX)
	duet_rhythm = _euclidean_rhythm(randi_range(pulses_lo, pulses_hi), MUSIC_RHYTHM_STEPS)
	var pulse_count := 0
	duet_pulse_times.clear()
	var t := 0.0
	for on in duet_rhythm:
		if on:
			pulse_count += 1
			duet_pulse_times.append(t)
		t += duet_step_duration
	var melody := _generate_music_bar_melody(pulse_count)
	sequence.clear()
	sequence_chunk_id.clear()
	for degree in melody:
		var pad := _music_pad_for_degree(degree)
		sequence.append(pad.pad_name if pad else pad_names[0])
		_tag_chunk_for_new_note()

func _normal_reset_walk() -> void:
	# Unlike Music/Duet's phrases, which always open on the tonic, Normal
	# Mode's run is the only "opening note" a player hears repeatedly across
	# many runs - starting it on a random degree keeps that moment from
	# feeling identical every time. Mid-run phrase resolution (every
	# NORMAL_PHRASE_LENGTH notes) still lands on the tonic, same as Music/Duet.
	_normal_current_degree = randi() % PAD_COUNT
	_normal_last_direction = 0
	_normal_last_was_leap = false
	_normal_repeat_streak = 1
	_normal_riff = []
	_normal_riff_index = 0

# Normal Mode's per-round note pick. Independent state from Music/Duet's
# walk (`_music_*` vars) since Normal's sequence is one continuously
# growing phrase for the whole run, not a per-bar/per-round reset - same
# step-inertia/post-skip-reversal bias as _music_next_delta (see
# docs/music-mode.md), duplicated rather than shared so the three modes'
# walks can't interfere with each other's state.
func _normal_next_delta(max_leap: int) -> int:
	var repeat_chance: float = BASE_REPEAT_CHANCE * pow(REPEAT_DECAY, float(_normal_repeat_streak - 1))
	var step_chance := (1.0 - repeat_chance) * STEP_TO_NON_REPEAT_RATIO
	var r := randf()
	var magnitude: int
	if r < repeat_chance:
		magnitude = 0
	elif r < repeat_chance + step_chance:
		magnitude = 1
	else:
		magnitude = randi_range(2, max_leap)
	if magnitude == 0:
		_normal_last_was_leap = false
		return 0
	var direction: int
	var is_gap_fill := false
	if _normal_last_was_leap and _normal_last_direction != 0:
		direction = -_normal_last_direction
		magnitude = 1
		is_gap_fill = true
	elif _normal_last_direction != 0 and magnitude == 1:
		direction = _normal_last_direction if randf() < 0.70 else -_normal_last_direction
	else:
		# Zigzag/alternating-side contour bias, same technique as
		# _music_next_delta() but at the fixed NORMAL_ZIGZAG_BIAS default
		# rather than the player-tunable Music Mode slider - see the
		# NORMAL_ANCHOR_RETURN_CHANCE comment above.
		var current_side := _music_ring_side(_normal_current_degree)
		var plus_side := _music_ring_side(_reflect_degree(_normal_current_degree + magnitude))
		var minus_side := _music_ring_side(_reflect_degree(_normal_current_degree - magnitude))
		if plus_side != current_side and minus_side == current_side:
			direction = 1 if randf() < NORMAL_ZIGZAG_BIAS else -1
		elif minus_side != current_side and plus_side == current_side:
			direction = -1 if randf() < NORMAL_ZIGZAG_BIAS else 1
		else:
			direction = 1 if randf() < 0.5 else -1
	# Melodic arch, same technique as _music_next_delta() but keyed off
	# sequence length instead of bar count, since Normal Mode has no bars -
	# see docs/music-mode.md#melodic-arch.
	if not is_gap_fill and randf() < MUSIC_ARCH_BIAS:
		direction = _normal_arch_direction()
	_normal_last_direction = direction
	_normal_last_was_leap = magnitude >= 2
	return direction * magnitude

# Which way the phrase-level melodic arch wants the walk to move right now -
# up through the first half of a phrase, down through the second half.
func _normal_arch_direction() -> int:
	return 1 if (sequence.size() % NORMAL_PHRASE_LENGTH) * 2 < NORMAL_PHRASE_LENGTH else -1

func _normal_next_pad_name() -> String:
	var scale: Dictionary = SCALES[current_scale_index]
	var is_narrow: bool = MUSIC_NARROW_LEAP_SCALES.has(scale["id"])
	var max_leap := MUSIC_NARROW_MAX_LEAP if is_narrow else MUSIC_PENTATONIC_MAX_LEAP
	# Riff shape seeding, phrase start only (mirrors _generate_music_bar_melody
	# but one note at a time, since Normal's sequence grows one note per
	# call) - state spans multiple calls via _normal_riff/_normal_riff_index.
	if _normal_riff.is_empty() and sequence.size() % NORMAL_PHRASE_LENGTH == 0 and randf() < NORMAL_RIFF_CHANCE:
		_normal_riff = MUSIC_RIFF_SHAPES[randi() % MUSIC_RIFF_SHAPES.size()]
		_normal_riff_index = 0
		_normal_riff_base = _normal_current_degree
	var degree: int
	if _normal_riff_index < _normal_riff.size():
		degree = _reflect_degree(_normal_riff_base + int(_normal_riff[_normal_riff_index]))
		_normal_riff_index += 1
		if _normal_riff_index >= _normal_riff.size():
			_normal_riff = []
		_normal_current_degree = degree
		_normal_last_direction = 0
		_normal_repeat_streak = 1
	else:
		degree = _normal_current_degree
		if not _is_resolution_degree(degree, scale) and randf() < NORMAL_ANCHOR_RETURN_CHANCE:
			# Ghost return to a tonal-hierarchy-weighted tonic/third/fifth,
			# same technique as Music Mode's anchor return - see
			# _pick_resolution_degree() for why not always degree 0
			# (docs/music-mode.md#note-distribution-bias-fix).
			degree = _pick_resolution_degree(scale)
			_normal_current_degree = degree
			_normal_last_direction = 0
			_normal_repeat_streak = 1
	var delta := _normal_next_delta(max_leap)
	var raw_target := degree + delta
	var new_degree := _reflect_degree(raw_target)
	if new_degree != raw_target and delta != 0:
		_normal_last_direction = -_normal_last_direction
	if new_degree == degree:
		_normal_repeat_streak += 1
	else:
		_normal_repeat_streak = 1
	_normal_current_degree = new_degree
	var play_degree := degree
	# Phrase resolution, same idea as Music/Duet's every-4-bar tonic return
	# (see docs/music-mode.md) - gives the ever-growing sequence periodic
	# "landing points" instead of wandering indefinitely.
	if (sequence.size() + 1) % NORMAL_PHRASE_LENGTH == 0:
		play_degree = _pick_resolution_degree(scale)
		_normal_current_degree = play_degree
		_normal_repeat_streak = 1
		_normal_last_direction = 0
		_normal_riff = []
	var ring_order: Array = scale.get("ring_order", [0, 1, 2, 3, 4, 5, 6, 7])
	var ring_pos: int = ring_order.find(play_degree)
	return pad_names[ring_pos if ring_pos != -1 else 0]

func _roll_gold_indices() -> void:
	gold_indices.clear()
	if golden_step_count <= 0:
		return
	var pool: Array[int] = []
	for i in sequence.size():
		pool.append(i)
	pool.shuffle()
	var take: int = min(golden_step_count, pool.size())
	gold_indices = pool.slice(0, take)

# Quick Rewind (Tempo): full-sequence replay (Normal/Chaos) or call-phrase
# replay (Duet). No charge/button (docs/modifier-audit.md rule 6) - fires
# automatically from _check_hesitation_assists() when the player is visibly
# stuck on the current note, at a higher hesitation threshold than Echo
# Chamber so the two form a natural escalation if both are equipped: a mild
# pause gets Echo Chamber's single-note nudge, real hesitation gets this
# full replay.
func _quick_rewind_sequence() -> void:
	if sequence.is_empty():
		return
	var flash_dur: float = max(0.05, 0.4 / quick_rewind_speed_mult)
	var gap: float = max(0.02, 0.1 / quick_rewind_speed_mult)
	for pad_name in sequence:
		await pads_by_name[pad_name].flash(flash_dur)
		await get_tree().create_timer(gap).timeout

# Rubato (Tempo, power): adaptive pacing off recent tapping pace vs. the
# mode's own baseline - relief-only through L4 (never faster than normal),
# genuinely two-directional at L5 (a confident streak plays back faster).
func _rubato_speed_factor() -> float:
	if equipped_modifiers["tempo"] != "rubato" or rubato_level <= 0:
		return 1.0
	var responsiveness := float(rubato_level) / float(MAX_MODIFIER_LEVEL)
	var ratio := recent_response_ms_per_note / RUBATO_BASELINE_MS_PER_NOTE
	if ratio >= RUBATO_HESITANT_RATIO:
		return 1.0 + 0.35 * responsiveness
	if rubato_two_directional and ratio <= RUBATO_CONFIDENT_RATIO:
		return 1.0 - 0.25 * responsiveness
	return 1.0

# Resonant Tones (Phrasing): reuses the tonal-hierarchy weighting Music
# Mode's generator already computes (_scale_degree_weight) to identify chord
# tones (tonic/third/fifth) regardless of which mode is playing - a pad's
# degree is fixed by its name via the scale's ring_order (_apply_scale_and_
# palette), independent of Chaos's on-screen reshuffling.
func _pad_is_chord_tone(pad_name: String) -> bool:
	var i := int(pad_name.replace("pad_", ""))
	var scale: Dictionary = SCALES[current_scale_index]
	var ring_order: Array = scale.get("ring_order", [0, 1, 2, 3, 4, 5, 6, 7])
	if i < 0 or i >= ring_order.size():
		return false
	var degree: int = ring_order[i]
	return _scale_degree_weight(degree, scale) > 0.0

# Extra visual hold time for `pad_name`'s call-phase flash - Resonant Tones'
# only effect (its "fuller and longer" ring is the same glow-persistence
# mechanism Slow Fade used to use, just conditional on chord-tone-ness
# instead of applying to every note).
func _flash_duration_for_pad(pad_name: String) -> float:
	if equipped_modifiers["tempo"] == "resonant_tones" and _pad_is_chord_tone(pad_name):
		return float(_mod_val("resonant_tones", "extra_sec"))
	return 0.0

# Constellation (Phrasing): traces a fading line between consecutively-
# played pads across the ring as the call plays - see _on_constellation_draw
# for the actual drawing. Each pad's connection point is its pivot (the
# base near the Resonator, per SimonButton's "local (0,0) is the base"
# shape convention), which stays correct even after Chaos reshuffles pad
# positions since it reads the pad's *current* transform, not a cached one.
func _constellation_reset_for_new_call() -> void:
	_constellation_points.clear()
	_constellation_colors.clear()
	_constellation_alpha = 1.0

func _constellation_note_played(pad_name: String) -> void:
	if equipped_modifiers["tempo"] != "constellation":
		return
	var pad: SimonButton = pads_by_name[pad_name]
	_constellation_points.append(pad.position + pad.pivot_offset)
	_constellation_colors.append(pad.lit_color)

func _constellation_fade_out() -> void:
	if equipped_modifiers["tempo"] != "constellation":
		return
	var t := create_tween()
	t.tween_property(self, "_constellation_alpha", 0.0, 0.8)

func _play_sequence() -> void:
	if duet_mode:
		await _play_duet_call()
		return
	var chaos_speed := 1.0
	if chaos_mode:
		# Ramp now inflects at MEMORY_SPAN_CEILING instead of climbing at one
		# flat rate the whole way - gentle below it (still "normal" memory
		# territory, shouldn't be adding much extra pressure on top of just
		# holding the sequence), steeper past it (the same real cliff the
		# cash-out formula is built around), reaching the same 0.5x floor a
		# little sooner than the old flat ramp did.
		var n := sequence.size()
		var pre_ceiling: float = minf(float(n - 1), float(MEMORY_SPAN_CEILING - 1))
		var past_ceiling: float = maxf(0.0, float(n - MEMORY_SPAN_CEILING))
		chaos_speed = clamp(1.0 - pre_ceiling * 0.02 - past_ceiling * 0.09, 0.5, 1.0)
	var duration_scale := sequence_speed_multiplier * chaos_speed * _rubato_speed_factor()
	await get_tree().create_timer(0.6).timeout
	var call_start_ms := Time.get_ticks_msec()
	_constellation_reset_for_new_call()
	for i in sequence.size():
		var pad_name: String = sequence[i]
		_constellation_note_played(pad_name)
		await pads_by_name[pad_name].flash(0.4 * duration_scale + _flash_duration_for_pad(pad_name))
		var gap := 0.25 * duration_scale
		# Breath Mark used to pause every 4th step - an interval that didn't
		# match CHUNK_SIZE (3), the game's actual repeated-motif grouping
		# (what Harmonic Chain/Motif Bonus reward), so the pause reinforced
		# a rhythm that didn't correspond to anything real in the sequence.
		# Fixed to land on real chunk boundaries instead.
		if breath_mark_pct > 0.0 and (i + 1) % CHUNK_SIZE == 0:
			gap *= 1.0 + breath_mark_pct
		await get_tree().create_timer(gap).timeout
	# Perfect Pitch's real target pace: how fast this call was actually just
	# played back, not an abstract/fixed number - see _perfect_pitch_multiplier.
	if sequence.size() > 0:
		_call_step_ms_per_note = float(Time.get_ticks_msec() - call_start_ms) / float(sequence.size())

# Plays the Duet call phrase on its actual Euclidean-rhythm grid (not
# uniform gaps like Normal/Chaos) so the call's timing is the thing the
# player is meant to reproduce.
func _play_duet_call() -> void:
	await get_tree().create_timer(0.6).timeout
	# Steady Hands/Rubato scale only the call's playback pacing here, not
	# `duet_step_duration` itself - the response phase grades timing against
	# the original tempo grid (`duet_pulse_times`), which must stay untouched.
	var duration_scale := sequence_speed_multiplier * _rubato_speed_factor()
	var step_duration := duet_step_duration * duration_scale
	var flash_duration: float = min(step_duration * MUSIC_FLASH_FRACTION, MUSIC_FLASH_MAX)
	var note_i := 0
	var call_start_ms := Time.get_ticks_msec()
	_constellation_reset_for_new_call()
	for step_on in duet_rhythm:
		if step_on:
			var pad_name: String = sequence[note_i]
			note_i += 1
			_constellation_note_played(pad_name)
			await pads_by_name[pad_name].flash(flash_duration + _flash_duration_for_pad(pad_name))
			var remaining := step_duration - flash_duration
			if breath_mark_pct > 0.0 and note_i % CHUNK_SIZE == 0:
				remaining += step_duration * breath_mark_pct
			if remaining > 0.0:
				await get_tree().create_timer(remaining).timeout
		else:
			await get_tree().create_timer(step_duration).timeout
	# Same real-pace tracking as _play_sequence - Perfect Pitch's target in
	# Duet is "match this phrase's actual pace," which stays coherent with
	# (rather than competing against) the mode's own timing-accuracy scoring.
	if note_i > 0:
		_call_step_ms_per_note = float(Time.get_ticks_msec() - call_start_ms) / float(note_i)

# Duet Mode's response phase: strict positional match like Normal Mode (see
# docs/game-modes.md) but timed against `duet_pulse_times`, the same
# schedule the call was just played on. Note identity determines pass/fail
# (wrong pad or no press within the grace window behaves exactly like a
# Normal Mode miss - forgiven by whichever Defense modifier is equipped or
# ends the run); timing accuracy only scales the score via `_register_hit`'s
# `timing_multiplier`, never fails a round on its own.
func _run_duet_response() -> void:
	accepting_input = true
	_last_input_ms = Time.get_ticks_msec()
	_echo_chamber_hinted_this_note = false
	_quick_rewind_triggered_this_note = false
	_constellation_fade_out()
	_set_pads_disabled(false)
	_update_score_labels()
	var i := 0
	while i < sequence.size():
		player_index = i
		_duet_last_press = ""
		_duet_note_wait_start_ms = Time.get_ticks_msec()
		_duet_note_deadline_ms = _duet_note_wait_start_ms + int(DUET_NOTE_GRACE_SEC * 1000.0)
		while duet_mode and _duet_last_press == "" and (_duet_ability_pause or Time.get_ticks_msec() < _duet_note_deadline_ms):
			await get_tree().process_frame
		if not duet_mode:
			return
		if _duet_last_press == "" or _duet_last_press != sequence[i]:
			if not await _handle_duet_miss():
				return
			continue
		# Graded against the same real, per-note-relative window the gauge
		# animates (`_duet_note_span`), not the absolute fixed grid - grading
		# against the grid meant ordinary human reaction time on note 0 alone
		# (a couple hundred ms) put every note after it permanently behind
		# schedule, so *everything* scored as "late" regardless of how
		# consistently the player actually played the rhythm back.
		var press_elapsed := float(Time.get_ticks_msec() - _duet_note_wait_start_ms) / 1000.0
		var span := _duet_note_span(i)
		var offset := absf(press_elapsed - span)
		var accuracy := 1.0 - clampf(offset / DUET_MULT_FALLOFF_SEC, 0.0, 1.0)
		var timing_multiplier := lerpf(DUET_MULT_MIN, DUET_MULT_MAX, accuracy)
		_duet_ring_flash_color = _duet_timing_color(accuracy)
		_duet_ring_flash_start_ms = Time.get_ticks_msec()
		_register_hit(_duet_last_press, _duet_last_press_pos, timing_multiplier)
		var judgment := _duet_timing_judgment(offset, press_elapsed < span)
		get_tree().create_timer(0.16).timeout.connect(_spawn_score_popup.bind(_duet_last_press_pos + Vector2(-24, -22), judgment, _duet_timing_color(accuracy)))
		i += 1
	if grand_finale_pending:
		_resolve_grand_finale_win()
		return
	accepting_input = false
	_set_pads_disabled(true)
	_play_round_clear_beat()
	await get_tree().create_timer(0.6).timeout
	if _current_round() % MODIFIER_ROUND_INTERVAL == 0:
		await _offer_modifier_choice()
	_next_round()

# Freezes Duet's response-phase clock (the current note's grace deadline
# shifts forward by however long the ability took) so an automatic Quick
# Rewind replay can play out mid-response without costing a miss or
# wrecking the timing grade - every modifier should behave the same in
# Duet as it does in Normal/Chaos. No-ops outside Duet.
func _pause_duet_clock_start() -> int:
	if not duet_mode:
		return 0
	_duet_ability_pause = true
	return Time.get_ticks_msec()

func _pause_duet_clock_end(started_at_ms: int) -> void:
	if not duet_mode:
		return
	var elapsed := Time.get_ticks_msec() - started_at_ms
	_duet_note_deadline_ms += elapsed
	_duet_note_wait_start_ms += elapsed
	_duet_ability_pause = false

# Maps timing accuracy (1.0 = dead-on, 0.0 = at/past DUET_MULT_FALLOFF_SEC)
# to a continuous red -> yellow -> green gradient for the ring flash, so the
# flash color itself communicates "how close", not just a tier label.
func _duet_timing_color(accuracy: float) -> Color:
	var a := clampf(accuracy, 0.0, 1.0)
	if a >= 0.5:
		return Color(1.0, 0.9, 0.4).lerp(Color(0.4, 1.0, 0.6), (a - 0.5) * 2.0)
	return Color(1.0, 0.35, 0.35).lerp(Color(1.0, 0.9, 0.4), a * 2.0)

# Picks the judgment word for the score popup that follows every correct
# press - three near-miss tiers (offset-based, same idea as the old scoring
# tiers but purely cosmetic now) plus a direction hint on the loosest one,
# since "you're rushing" and "you're dragging" call for different fixes.
func _duet_timing_judgment(offset: float, was_early: bool) -> String:
	if offset <= DUET_PERFECT_WINDOW:
		return "Perfect!"
	if offset <= DUET_GOOD_WINDOW:
		return "Good!"
	return "Early!" if was_early else "Late!"

# How long note `i`'s window naturally is on the rhythmic grid (the gap from
# the previous pulse, or from 0 for the first note) - used as the target
# duration for both the gauge fill and the score grading, anchored to real
# wait-start rather than the absolute grid (see _run_duet_response).
func _duet_note_span(i: int) -> float:
	var target_t: float = duet_pulse_times[i]
	var start_t: float = duet_pulse_times[i - 1] if i > 0 else 0.0
	return maxf(target_t - start_t, duet_step_duration)

# Returns true if forgiven/converted (caller should retry the same note
# index or the round already got re-triggered), false if the run ended.
func _handle_duet_miss() -> bool:
	_duet_ring_flash_color = Color(1.0, 0.3, 0.3)
	_duet_ring_flash_start_ms = Time.get_ticks_msec()
	if grand_finale_pending:
		_resolve_grand_finale_loss()
		return false
	if double_down_index == player_index and equipped_modifiers["bonus_event"] == "double_down":
		_forfeit_streak_from_double_down()
		return false
	var outcome := _resolve_defense_on_miss()
	match outcome:
		"forgiven_hint":
			combo = _combo_after_forgiveness()
			_update_score_labels()
			_flash_forgiven()
			await _flash_miss_hint(sequence[player_index])
			return true
	_game_over()
	return false

func _process(_delta: float) -> void:
	if duet_mode:
		duet_ring.queue_redraw()
	if equipped_modifiers["tempo"] == "constellation":
		constellation_layer.queue_redraw()
	_check_hesitation_assists()

# Constellation (Phrasing): draws a fading trail between consecutively-
# played pads, capped to the equipped level's `trail` segment count so a
# long streak reads as a trailing comet rather than an ever-thickening
# tangle. Each segment is colored by the pad it leads *to*, so the trail
# still only ever means "this is the pad" - it never invents a second
# meaning for the glow channel, it's drawn entirely in the gaps between
# pads. `_constellation_alpha` (tweened to 0 in _constellation_fade_out)
# fades the whole trail out once the response phase opens.
func _on_constellation_draw() -> void:
	if _constellation_points.size() < 2 or _constellation_alpha <= 0.0:
		return
	var trail: int = int(_mod_val("constellation", "trail"))
	var count := _constellation_points.size()
	var start_i := maxi(0, count - trail - 1)
	var span := maxi(count - 1 - start_i, 1)
	for i in range(start_i, count - 1):
		var recency := float(i - start_i) / float(span)
		var color := _constellation_colors[i + 1]
		color.a = lerpf(0.1, 0.8, recency) * _constellation_alpha
		constellation_layer.draw_line(_constellation_points[i], _constellation_points[i + 1], color, 2.5, true)

# Echo Chamber and Quick Rewind (docs/modifier-audit.md rule 6) both trigger
# off the same signal - how long it's been since the player's last correct
# press, relative to their own recent pace (`recent_response_ms_per_note`,
# the same signal Rubato already uses for pacing) - but at different
# thresholds, so equipping both forms a natural escalation: a mild pause
# gets Echo Chamber's single-note nudge first, real hesitation gets Quick
# Rewind's full replay. Each fires at most once per note wait (guarded by
# the _..._this_note flags, reset in _register_hit and at response start).
func _check_hesitation_assists() -> void:
	if not accepting_input or zen_mode or music_mode or _hesitation_assist_busy:
		return
	if sequence.is_empty() or player_index >= sequence.size():
		return
	if duet_mode and _duet_ability_pause:
		return
	var hesitation_ms := float(Time.get_ticks_msec() - _last_input_ms)
	var baseline := maxf(recent_response_ms_per_note, 200.0)
	if equipped_modifiers["defense"] == "echo_chamber" and not _echo_chamber_hinted_this_note:
		var threshold: float = baseline * float(_mod_val("echo_chamber", "hesitation_mult"))
		if hesitation_ms >= threshold:
			_echo_chamber_hinted_this_note = true
			_trigger_echo_chamber_hint()
	if equipped_modifiers["tempo"] == "quick_rewind" and not _quick_rewind_triggered_this_note:
		var threshold: float = baseline * float(_mod_val("quick_rewind", "hesitation_mult"))
		if hesitation_ms >= threshold:
			_quick_rewind_triggered_this_note = true
			_trigger_quick_rewind_replay()

func _trigger_quick_rewind_replay() -> void:
	_hesitation_assist_busy = true
	_show_toast("Quick Rewind! Replaying...")
	var pause_at := _pause_duet_clock_start()
	_set_pads_disabled(true)
	await _quick_rewind_sequence()
	_set_pads_disabled(false)
	_pause_duet_clock_end(pause_at)
	_hesitation_assist_busy = false
	_last_input_ms = Time.get_ticks_msec()
	_echo_chamber_hinted_this_note = false
	_quick_rewind_triggered_this_note = false

# Draws Duet's timing cue as a dot that grows into a disc over the
# Resonator: a filled circle, colored to match the pad the player needs to
# hit, that grows from a point out to DUET_RING_RADIUS across the gap
# between the previous pulse and the note currently due (`_duet_note_span`)
# - reaching full size exactly `span` seconds after we started waiting on
# this note, the same real-time-anchored window `_run_duet_response` grades
# against. Full size = press now; still small = wait. Holds at full size
# (doesn't reset) if the player runs past the deadline, so "it's overdue"
# reads as "still full, nothing changed" - deliberately inert rather than
# adding another moving element to parse. A short colored flash reports the
# grade after the press. Frozen (not cleared) during `_duet_ability_pause`
# so an ability use doesn't yank the gauge forward the frame the clock
# resumes.
func _on_duet_ring_draw() -> void:
	var now_ms := Time.get_ticks_msec()
	var flash_t := float(now_ms - _duet_ring_flash_start_ms) / 1000.0
	if not duet_mode or not accepting_input or player_index >= sequence.size() or duet_pulse_times.is_empty():
		if flash_t < DUET_RING_FLASH_SEC:
			var idle_flash := _duet_ring_flash_color
			idle_flash.a = 1.0 - flash_t / DUET_RING_FLASH_SEC
			duet_ring.draw_arc(RING_CENTER, DUET_RING_RADIUS, 0.0, TAU, 48, idle_flash, 6.0, true)
		return
	var fill_color := Color(0.85, 0.85, 0.9)
	var expected_pad: String = sequence[player_index]
	if pads_by_name.has(expected_pad):
		fill_color = pads_by_name[expected_pad].lit_color
	fill_color.a = 0.9
	var span := _duet_note_span(player_index)
	if not _duet_ability_pause:
		_duet_ring_frozen_now_t = float(now_ms - _duet_note_wait_start_ms) / 1000.0
	var progress: float = clampf(_duet_ring_frozen_now_t / span, 0.0, 1.0)
	if progress > 0.0:
		duet_ring.draw_circle(RING_CENTER, DUET_RING_RADIUS * progress, fill_color)
	if flash_t < DUET_RING_FLASH_SEC:
		var flash_color := _duet_ring_flash_color
		flash_color.a = 1.0 - flash_t / DUET_RING_FLASH_SEC
		duet_ring.draw_arc(RING_CENTER, DUET_RING_RADIUS, 0.0, TAU, 48, flash_color, 6.0, true)

func _on_pad_pressed(pad_name: String) -> void:
	if zen_mode or music_mode:
		return
	if not accepting_input:
		return
	if duet_mode:
		_duet_last_press = pad_name
		_duet_last_press_pos = get_viewport().get_mouse_position()
		return
	if pad_name == sequence[player_index]:
		if double_down_index == player_index and equipped_modifiers["bonus_event"] == "double_down":
			_land_double_down()
		_register_hit(pad_name, get_viewport().get_mouse_position())
		player_index += 1
		if player_index == sequence.size():
			if grand_finale_pending:
				_resolve_grand_finale_win()
				return
			accepting_input = false
			_set_pads_disabled(true)
			_play_round_clear_beat()
			await get_tree().create_timer(0.6).timeout
			if _current_round() % MODIFIER_ROUND_INTERVAL == 0:
				await _offer_modifier_choice()
			_next_round()
	else:
		if grand_finale_pending:
			_resolve_grand_finale_loss()
			return
		if double_down_index == player_index and equipped_modifiers["bonus_event"] == "double_down":
			_forfeit_streak_from_double_down()
			return
		var outcome := _resolve_defense_on_miss()
		match outcome:
			"forgiven_hint":
				combo = _combo_after_forgiveness()
				_update_score_labels()
				_flash_forgiven()
				await _flash_miss_hint(sequence[player_index])
			_:
				_game_over()

# Double Down's flagged gamble step: a hit temporarily boosts the effective
# streak length the cash-out formula reads (docs/modifier-expansion.md);
# a miss forfeits the streak early without ending the run or costing a
# Defense resource - it's a self-contained wager, not a normal miss.
func _land_double_down() -> void:
	var boost := int(_mod_val("double_down", "boost"))
	double_down_boost_amount += boost
	_spawn_score_popup(pads_by_name[sequence[player_index]].global_position + Vector2(35, 85), "Double Down!", Color(1, 0.6, 0.9))
	if bool(_mod_val("double_down", "chain")) and not double_down_chain_pending:
		double_down_chain_pending = true
		double_down_index = player_index + randi_range(2, 5)
	else:
		double_down_index = -1

func _forfeit_streak_from_double_down() -> void:
	_show_toast("Double Down missed - streak forfeited")
	_screen_shake(4.0, 0.15)
	_flash_screen(Color(1, 0.3, 0.5, 0.2))
	unbanked_points = 0
	double_down_boost_amount = 0
	accepting_input = false
	_set_pads_disabled(true)
	if duet_mode:
		duet_wave_round = 0
	else:
		sequence.clear()
	_start_new_streak_modifier_state()
	_update_score_labels()
	_next_round()

# Second Wind (Defense, power): redesigned around the hearts baseline
# (docs/scoring-escalation.md "cash-out economy" pass) - its old job (a
# true last-resort forced-cashout on an otherwise-fatal miss) is now
# redundant with hearts, which already give every build that cushion. Its
# new job: refill a heart on a voluntary cash-out, once the streak's long
# enough (`refill_streak`, shrinking by level so higher levels refill more
# often), capped at `max_hearts`. At L5 it also raises `max_hearts` itself
# by 1 (`bonus_max_heart`) - a real "power" payoff, not just a bigger number.
func _try_second_wind_refill() -> void:
	if equipped_modifiers["defense"] != "second_wind":
		return
	if hearts >= max_hearts:
		return
	if _current_wave_length() < int(_mod_val("second_wind", "refill_streak")):
		return
	hearts += 1
	_refresh_hearts_hud()
	_show_toast("Second Wind! Heart refilled (%d/%d)." % [hearts, max_hearts])

func _register_hit(pad_name: String, click_pos: Vector2, timing_multiplier := 1.0) -> void:
	combo += 1
	_wave_hit_count += 1
	current_round_has_hit = true
	var now_ms := Time.get_ticks_msec()
	if not hit_timestamps_ms.is_empty():
		var interval := float(now_ms - hit_timestamps_ms[hit_timestamps_ms.size() - 1])
		if interval > 0.0 and interval < 6000.0:
			recent_response_ms_per_note = lerpf(recent_response_ms_per_note, interval, 0.35)
	hit_timestamps_ms.append(now_ms)
	if hit_timestamps_ms.size() > PERFECT_PITCH_WINDOW + 1:
		hit_timestamps_ms.pop_front()
	# Hesitation-assist clock (Echo Chamber/Quick Rewind) restarts on every
	# correct press - see _check_hesitation_assists().
	_last_input_ms = now_ms
	_echo_chamber_hinted_this_note = false
	_quick_rewind_triggered_this_note = false
	# Each step below tracks its own delta and, if it actually changed
	# anything this hit, queues a cascading popup in that modifier's
	# category color - so a build's modifiers are visibly, individually
	# doing something on every hit, not just baked into one opaque total
	# (mirrors Balatro's per-joker score reveal).
	var popups: Array[Dictionary] = []
	var base_multiplier := 1.0 + float(combo - 1) * combo_growth
	var points := int(round(10.0 * base_multiplier * timing_multiplier))
	var base_points := points

	# Sharper Ear (Multiplier): its combo_growth bonus is baked directly into
	# base_multiplier above, before base_points is even captured, so it used
	# to disappear into the plain "+N" popup with no attribution (audit
	# pillar 1 fail - same failure mode Resonance already avoids below).
	# Doesn't change the actual score, just names the delta already earned.
	if equipped_modifiers["multiplier"] == "sharper_ear":
		var baseline_multiplier := 1.0 + float(combo - 1) * BASE_COMBO_GROWTH
		var baseline_points := int(round(10.0 * baseline_multiplier * timing_multiplier))
		var sharper_ear_delta := base_points - baseline_points
		if sharper_ear_delta > 0:
			popups.append({"text": "Sharper Ear +%d" % sharper_ear_delta, "color": CATEGORY_COLORS["multiplier"]})

	var fortissimo_mult := _fortissimo_multiplier()
	if fortissimo_mult > 1.0:
		var before := points
		points = int(round(float(points) * fortissimo_mult))
		popups.append({"text": "Fortissimo +%d" % (points - before), "color": CATEGORY_COLORS["multiplier"]})

	var pitch_mult := _perfect_pitch_multiplier()
	if pitch_mult > 1.0:
		var before := points
		points = int(round(float(points) * pitch_mult))
		popups.append({"text": "Perfect Pitch +%d" % (points - before), "color": CATEGORY_COLORS["multiplier"]})

	if player_index in gold_indices:
		var before := points
		points *= 3
		popups.append({"text": "Golden Step +%d" % (points - before), "color": CATEGORY_COLORS["bonus_event"]})

	if player_index == lucky_strike_index:
		var before := points
		points = int(round(points * float(_mod_val("lucky_strike", "value_mult"))))
		lucky_strike_index = -1
		_show_toast("Lucky Strike!")
		popups.append({"text": "Lucky Strike +%d" % (points - before), "color": CATEGORY_COLORS["bonus_event"]})

	var chain_bonus := _harmonic_chain_bonus_points(points)
	if chain_bonus != 0:
		points += chain_bonus
		popups.append({"text": "Harmonic Chain +%d" % chain_bonus, "color": CATEGORY_COLORS["multiplier"]})

	if score_bonus_percent > 0.0:
		var before := points
		points = int(round(points * (1.0 + score_bonus_percent)))
		popups.append({"text": "Resonance +%d" % (points - before), "color": CATEGORY_COLORS["multiplier"]})

	unbanked_points += points
	if _completed_repeated_chunk(player_index) and equipped_modifiers["bonus_event"] == "motif_bonus":
		var motif_bonus := int(_mod_val("motif_bonus", "amount"))
		unbanked_points += motif_bonus
		popups.append({"text": "Motif +%d" % motif_bonus, "color": CATEGORY_COLORS["bonus_event"]})

	var cur_wave: int = _current_wave_length()
	if cur_wave > best_streak_this_run:
		best_streak_this_run = cur_wave
	_register_best(_current_round(), score, combo)
	_update_score_labels()
	_punch(combo_label)
	_spawn_score_popup(click_pos, "+%d" % base_points, pads_by_name[pad_name].lit_color)
	_spawn_score_popup_cascade(click_pos, popups)
	_spawn_burst(click_pos, pads_by_name[pad_name].lit_color)
	_screen_shake(3.0, 0.12)

# --- Modifier slot system: data lookups ---

func _mod_def(id: String) -> Dictionary:
	for mod in MODIFIERS:
		if mod["id"] == id:
			return mod
	return {}

func _mod_level(id: String) -> int:
	return int(modifier_levels.get(id, 0))

# Reads a per-level numeric field for `id`. Defaults to the *current* level;
# pass an explicit level (1-5) to preview a different one (used by the draft
# panel to show what a level-up would grant).
func _mod_val(id: String, key: String, level := -1, fallback: Variant = 0) -> Variant:
	var lvl: int = level if level > 0 else _mod_level(id)
	if lvl <= 0:
		lvl = 1
	var mod := _mod_def(id)
	if mod.is_empty():
		return fallback
	var levels: Array = mod["levels"]
	var idx: int = clampi(lvl, 1, levels.size()) - 1
	return levels[idx].get(key, fallback)

func _mod_category(id: String) -> String:
	return String(_mod_def(id).get("category", ""))

# Pure (non-consumable) per-level stats - safe to fully recompute from
# scratch any time equip/level state changes, unlike charges/uses which are
# spent during play and must only ever be granted incrementally.
func _recompute_pure_modifier_stats() -> void:
	combo_growth = BASE_COMBO_GROWTH
	score_bonus_percent = 0.0
	var mult_id: String = equipped_modifiers["multiplier"]
	if mult_id == "sharper_ear":
		combo_growth += _mod_val(mult_id, "combo_growth_bonus")
	elif mult_id == "resonance":
		score_bonus_percent += _mod_val(mult_id, "bonus")

	golden_step_count = 0
	if equipped_modifiers["bonus_event"] == "golden_step":
		golden_step_count = int(_mod_val("golden_step", "count"))

	sequence_speed_multiplier = 1.0
	if equipped_modifiers["tempo"] == "steady_hands":
		sequence_speed_multiplier = 1.0 + float(_mod_val("steady_hands", "pct"))

	quick_rewind_speed_mult = 0.0
	breath_mark_pct = 0.0
	rubato_level = 0
	rubato_two_directional = false
	var tempo_id: String = equipped_modifiers["tempo"]
	match tempo_id:
		"quick_rewind":
			quick_rewind_speed_mult = float(_mod_val(tempo_id, "speed_mult"))
		"breath_mark":
			breath_mark_pct = float(_mod_val(tempo_id, "pct"))
		"rubato":
			rubato_level = _mod_level(tempo_id)
			rubato_two_directional = bool(_mod_val(tempo_id, "two_directional"))

	grounding_resonance_pct = 0.0
	if equipped_modifiers["defense"] == "grounding_resonance":
		grounding_resonance_pct = float(_mod_val("grounding_resonance", "pct"))

	# Second Wind L5 raises the heart ceiling by 1 - recomputed here (not
	# granted once) so swapping Second Wind out mid-run correctly drops the
	# bonus max, clamping current hearts down with it if needed.
	max_hearts = RUN_START_HEARTS
	if equipped_modifiers["defense"] == "second_wind" and bool(_mod_val("second_wind", "bonus_max_heart")):
		max_hearts = RUN_START_HEARTS + 1
	hearts = mini(hearts, max_hearts)
	_refresh_hearts_hud()
	_update_score_labels()

# Per-streak state: reset at run start and on every cash-out (a streak is
# one growing sequence/phrase between resets).
func _start_new_streak_modifier_state() -> void:
	unbreakable_forgiven_this_streak = 0
	current_streak_had_miss = false
	double_down_index = -1
	double_down_chain_pending = false
	double_down_boost_amount = 0
	grand_finale_pending = false
	harmonic_chain_stack = 0.0
	lucky_strike_index = -1
	sequence_chunk_id.clear()
	chunk_history.clear()
	_next_chunk_id = 0
	_wave_start_ms = Time.get_ticks_msec()
	_wave_hit_count = 0
	current_round_has_hit = false
	if equipped_modifiers["bonus_event"] == "double_down":
		_roll_double_down_index()

func _roll_double_down_index() -> void:
	# Flags a future step (a few rounds out) as the streak's gamble note -
	# picked once per streak, not re-rolled every round.
	double_down_index = randi_range(2, 6)

# Re-rolled every round (unlike Double Down's once-per-streak flag) - a
# small chance *this specific round* has a surprise bonus-value pad, at
# whichever index the player is about to reach next.
func _roll_lucky_strike_index() -> void:
	lucky_strike_index = -1
	if equipped_modifiers["bonus_event"] != "lucky_strike":
		return
	if sequence.is_empty():
		return
	if randf() < float(_mod_val("lucky_strike", "chance")):
		lucky_strike_index = sequence.size() - 1

# --- Musical chunking: tags newly-appended sequence notes as belonging to a
# repeated motif some of the time, giving Harmonic Chain/Motif Bonus a real
# "is this note part of a repeated phrase" signal. Only engages once a full
# CHUNK_SIZE-note chunk has completed elsewhere in the sequence.
func _tag_chunk_for_new_note() -> void:
	var idx := sequence.size() - 1
	var pos_in_chunk := idx % CHUNK_SIZE
	if pos_in_chunk == 0 and idx >= CHUNK_SIZE and randf() < CHUNK_REPEAT_CHANCE and not chunk_history.is_empty():
		var reused: Array = chunk_history[randi() % chunk_history.size()]
		if idx + reused.size() <= sequence.size() + CHUNK_SIZE - 1:
			var reuse_id: int = reused[0]
			for i in range(sequence_chunk_id.size(), idx):
				sequence_chunk_id.append(_next_chunk_id)
			sequence_chunk_id.append(reuse_id)
			return
	for i in range(sequence_chunk_id.size(), idx):
		sequence_chunk_id.append(_next_chunk_id)
	sequence_chunk_id.append(_next_chunk_id)
	if pos_in_chunk == CHUNK_SIZE - 1:
		chunk_history.append([_next_chunk_id])
		_next_chunk_id += 1

func _chunk_id_at(idx: int) -> int:
	return sequence_chunk_id[idx] if idx < sequence_chunk_id.size() else -1

# True if the chunk containing `idx` is a repeat of an earlier chunk (i.e.
# its id was reused rather than freshly minted) and `idx` is the chunk's
# final note - the moment "you just landed a whole repeated motif."
func _completed_repeated_chunk(idx: int) -> bool:
	if (idx + 1) % CHUNK_SIZE != 0:
		return false
	var cid := _chunk_id_at(idx)
	if cid < 0:
		return false
	var first_use := true
	for i in range(idx + 1):
		if i != idx and _chunk_id_at(i) == cid:
			first_use = false
			break
	return not first_use

# --- Defense resolution ---

# Returns "forgiven_hint" (combo halves, correct pad hinted, unbanked points
# already always protected by this codebase's forgiveness path) or
# "game_over". Hearts (docs/scoring-escalation.md "cash-out economy" pass) are the
# baseline safety net every run gets regardless of build - a miss with no
# Defense-modifier save just spends a heart and continues instead of ending
# the run outright. Safety Net, Unbreakable, and Muffled Strike differ by
# trigger *condition* (docs/modifier-audit.md rule 6 removed the countable
# charges that used to be their only distinction) - territory (are you past
# your best streak this run) vs. position (is this the streak's first miss)
# vs. probability (scaling with how deep the current streak already is) -
# and each makes a save cost *no heart at all* rather than forgiving the
# miss independently of the heart pool. Only once hearts hit zero (with no
# modifier save available) does a miss actually end the run.
func _resolve_defense_on_miss() -> String:
	current_streak_had_miss = true
	var def_id: String = equipped_modifiers["defense"]
	match def_id:
		"safety_net":
			var grace := float(_mod_val("safety_net", "grace"))
			if float(_current_wave_length()) >= float(best_streak_this_run) - grace:
				_show_toast("Safety Net! New-territory miss - no heart lost.")
				return "forgiven_hint"
		"unbreakable":
			if unbreakable_forgiven_this_streak < 1:
				unbreakable_forgiven_this_streak = 1
				_show_toast("Unbreakable! First miss this streak - no heart lost.")
				return "forgiven_hint"
		"muffled_strike":
			var ceiling := float(_mod_val("muffled_strike", "chance"))
			var effective_chance := ceiling * clampf(float(combo) / MUFFLED_STRIKE_RAMP_COMBO, 0.0, 1.0)
			if randf() < effective_chance:
				_show_toast("Muffled Strike! No heart lost (%d%% this deep in the streak)." % int(round(effective_chance * 100.0)))
				return "forgiven_hint"
	if hearts > 0:
		hearts -= 1
		_refresh_hearts_hud()
		_show_toast("A heart is spent (%d left)." % hearts)
		return "forgiven_hint"
	return "game_over"

# Unbreakable's redesign (docs/modifier-audit.md rule 6) traded "up to N
# misses per streak" for "the first miss, always, retaining more combo at
# higher levels" - so its payoff now lives in how much combo survives
# rather than in a spendable count. Only one Defense modifier can ever be
# equipped, so checking the slot here is enough to know Unbreakable (not
# some other modifier) is what just granted "forgiven_hint".
func _combo_after_forgiveness() -> int:
	if equipped_modifiers["defense"] == "unbreakable":
		return int(round(float(combo) * float(_mod_val("unbreakable", "combo_retain_pct"))))
	return combo / 2

func _hint_note_count() -> int:
	if equipped_modifiers["defense"] == "safety_net" and _mod_level("safety_net") >= 5:
		return int(_mod_val("safety_net", "hint_notes", -1, 1))
	return 1

# --- Draft flow ---

# Builds one draft card's full content from scratch (cleared and rebuilt
# every offer, same "rebuild rather than diff" approach as the rest of the
# UI in this file). Same structural pattern as _build_scale_cards() - a
# Button with MarginContainer/VBoxContainer children carrying the real
# content, mouse_filter IGNORE throughout so clicks still land on the button.
func _build_modifier_card(button: Button, mod: Dictionary) -> void:
	for child in button.get_children():
		child.queue_free()
	button.text = ""
	var id: String = mod["id"]
	var cat: String = mod["category"]
	var cat_color: Color = CATEGORY_COLORS[cat]
	var cur_level := _mod_level(id)
	var incumbent: String = equipped_modifiers[cat]
	var status_text: String
	var status_color: Color
	if incumbent == id:
		status_text = "▲ LEVEL UP  Lv.%d → Lv.%d" % [cur_level, cur_level + 1]
		status_color = Color(0.45, 0.85, 0.55)
	elif incumbent != "":
		var incumbent_title: String = String(_mod_def(incumbent).get("title", incumbent))
		status_text = "⇄ REPLACES %s" % incumbent_title
		status_color = Color(1.0, 0.62, 0.28)
	else:
		status_text = "+ NEW PICK"
		status_color = Color(0.45, 0.7, 1.0)
	if cur_level > 0 and incumbent != id:
		status_text += "  (resumes at Lv.%d)" % cur_level

	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(cat_color, 0.10)
	card_sb.border_color = cat_color
	card_sb.set_border_width_all(3)
	card_sb.set_corner_radius_all(10)
	card_sb.content_margin_left = 16
	card_sb.content_margin_right = 16
	card_sb.content_margin_top = 14
	card_sb.content_margin_bottom = 14
	button.add_theme_stylebox_override("normal", card_sb)
	var hover_sb: StyleBoxFlat = card_sb.duplicate()
	hover_sb.bg_color = Color(cat_color, 0.20)
	button.add_theme_stylebox_override("hover", hover_sb)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)
	var icon_label := Label.new()
	icon_label.text = mod["icon"]
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon_label)
	var title_label := Label.new()
	title_label.text = mod["title"]
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.autowrap_mode = 2
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_label)

	var cat_label := Label.new()
	cat_label.text = "%s%s" % [CATEGORY_LABELS[cat].to_upper(), "  ·  POWER" if mod["power"] else ""]
	cat_label.add_theme_font_size_override("font_size", 15)
	cat_label.add_theme_color_override("font_color", cat_color)
	cat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cat_label)

	var status_badge := PanelContainer.new()
	status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = status_color
	badge_sb.set_corner_radius_all(5)
	badge_sb.content_margin_left = 10
	badge_sb.content_margin_right = 10
	badge_sb.content_margin_top = 5
	badge_sb.content_margin_bottom = 5
	status_badge.add_theme_stylebox_override("panel", badge_sb)
	var status_label := Label.new()
	status_label.text = status_text
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color.BLACK)
	status_label.autowrap_mode = 2
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_badge.add_child(status_label)
	vbox.add_child(status_badge)

	var desc_label := Label.new()
	desc_label.text = mod["desc"]
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.autowrap_mode = 2
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)
	button.disabled = false

func _offer_modifier_choice() -> void:
	var pool: Array = []
	for mod in MODIFIERS:
		if _mod_level(mod["id"]) >= MAX_MODIFIER_LEVEL:
			continue
		if mod["power"] and not _is_unlocked(mod):
			continue
		pool.append(mod)
	pool.shuffle()
	current_offer = pool.slice(0, min(3, pool.size()))
	for i in modifier_buttons.size():
		if i >= current_offer.size():
			modifier_buttons[i].visible = false
			continue
		modifier_buttons[i].visible = true
		_build_modifier_card(modifier_buttons[i], current_offer[i])
	await _reveal_modifier_panel()
	var chosen_id: String = await _modifier_picked
	modifier_panel.visible = false
	await _resolve_modifier_pick(chosen_id)
	_refresh_loadout_hud()

# Dramatic reveal for the modifier choice - it's a meaningful decision point,
# so it gets a heavier scale + glow-in treatment than routine panel opens.
func _reveal_modifier_panel() -> void:
	modifier_panel.visible = true
	_refresh_loadout_hud()
	var vbox: Control = modifier_vbox
	await get_tree().process_frame
	vbox.pivot_offset = vbox.size / 2.0
	vbox.scale = Vector2(0.55, 0.55)
	vbox.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(vbox, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(vbox, "modulate:a", 1.0, 0.25)
	_flash_screen(Color(0.7, 0.5, 1.0, 0.18))
	await t.finished

func _on_modifier_button_pressed(index: int) -> void:
	if index < current_offer.size():
		_modifier_picked.emit(current_offer[index]["id"])

# Routes a drafted pick: level-up (same id already equipped), direct equip
# (empty slot), or swap-or-skip (a different id already fills that slot).
func _resolve_modifier_pick(id: String) -> void:
	var cat := _mod_category(id)
	var incumbent: String = equipped_modifiers[cat]
	if incumbent == id or incumbent == "":
		_apply_modifier_pick(id)
		return
	await _show_swap_or_skip_dialog(id, incumbent)

func _apply_modifier_pick(id: String) -> void:
	var cat := _mod_category(id)
	var from_level := _mod_level(id)
	var to_level: int = min(from_level + 1, MAX_MODIFIER_LEVEL)
	equipped_modifiers[cat] = id
	modifier_levels[id] = to_level
	if id == "unbreakable" or id == "second_wind":
		unbreakable_forgiven_this_streak = 0
	_recompute_pure_modifier_stats()
	_refresh_loadout_hud()
	var mod := _mod_def(id)
	_show_toast("%s %s -> Lv.%d" % [mod["icon"], mod["title"], to_level])

# Runtime-built confirm popup (same pattern as _show_toast/_spawn_score_popup
# - no new scene nodes needed). Resolves once the player confirms or skips.
func _show_swap_or_skip_dialog(new_id: String, incumbent_id: String) -> void:
	var new_mod := _mod_def(new_id)
	var old_mod := _mod_def(incumbent_id)
	if loadout_hud != null:
		loadout_hud.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position -= Vector2(160, 90)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.1, 0.97)
	sb.border_color = CATEGORY_COLORS[_mod_category(new_id)]
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	box.add_theme_stylebox_override("panel", sb)
	dim.add_child(box)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	box.add_child(vbox)
	var label := Label.new()
	label.text = "%s slot is filled by %s.\nSwap in %s, or keep %s?" % [CATEGORY_LABELS[_mod_category(new_id)], old_mod["title"], new_mod["title"], old_mod["title"]]
	label.autowrap_mode = 2
	label.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	var swap_btn := Button.new()
	swap_btn.text = "Swap to %s" % new_mod["title"]
	row.add_child(swap_btn)
	var skip_btn := Button.new()
	skip_btn.text = "Keep %s" % old_mod["title"]
	row.add_child(skip_btn)
	var done := false
	var do_swap := false
	swap_btn.pressed.connect(func():
		do_swap = true
		done = true)
	skip_btn.pressed.connect(func():
		done = true)
	while not done:
		await get_tree().process_frame
	dim.queue_free()
	if do_swap:
		# The incumbent's level/resources are left untouched (dormant, not
		# lost) - re-drafting it later in the same run resumes where it
		# left off rather than starting over.
		_apply_modifier_pick(new_id)

func _game_over() -> void:
	accepting_input = false
	_set_pads_disabled(true)
	# Grounding Resonance (Defense): a fatal miss would otherwise forfeit
	# `unbanked_points` entirely (it was never added to `score`) - bank a
	# fraction of it before `final_score` is read below, same "protect the
	# unbanked pool, not just run-continuation" spirit as Safety Net. Used to
	# fold silently into `final_score` with no attribution at all (audit
	# pillar 1 fail) - now surfaced as its own callout on the summary panel,
	# a durable line rather than a toast that might get missed under the
	# game-over screen shake.
	var grounding_resonance_banked := 0
	if equipped_modifiers["defense"] == "grounding_resonance" and unbanked_points > 0:
		grounding_resonance_banked = int(round(float(unbanked_points) * grounding_resonance_pct))
		score += grounding_resonance_banked
		unbanked_points = 0
	var final_round := _current_round() - 1
	var final_score := score
	var final_combo := combo
	var new_best_score := final_score > run_start_best_score
	var new_best_round := final_round > run_start_best_round
	var new_best_combo := final_combo > run_start_best_combo
	var celebrate := new_best_score or new_best_round or new_best_combo or not run_new_unlocks.is_empty()
	combo = 0
	cash_out_button.visible = false
	_update_score_labels()
	Sound.play_fail()
	round_label.text = "Game Over! Round %d" % final_round
	start_button.disabled = false
	chaos_button.disabled = false
	settings_button.disabled = false
	zen_button.disabled = false
	music_button.disabled = false
	duet_button.disabled = false
	_screen_shake(5.0, 0.25)
	if celebrate:
		_flash_screen(Color(1, 0.85, 0.3, 0.35))
		_play_unlock_fanfare()
	else:
		_flash_screen(Color(1, 0.65, 0.3, 0.2))
	_show_game_over_summary(final_round, final_score, final_combo, new_best_score, new_best_round, new_best_combo, grounding_resonance_banked)

func _show_game_over_summary(round_reached: int, final_score: int, final_combo: int, new_best_score: bool, new_best_round: bool, new_best_combo: bool, grounding_resonance_banked := 0) -> void:
	game_over_stats_label.text = "Score: %d   Round: %d   Combo: %d" % [final_score, round_reached, final_combo]
	var callouts: Array[String] = []
	if grounding_resonance_banked > 0:
		callouts.append("Grounding Resonance banked +%d" % grounding_resonance_banked)
	if new_best_score:
		callouts.append("New Best Score!")
	if new_best_round:
		callouts.append("New Best Round!")
	if new_best_combo:
		callouts.append("New Best Combo!")
	for entry in run_new_unlocks:
		callouts.append("Unlocked: %s!" % String(entry["name"]).replace("\n", " "))
	game_over_best_label.visible = not callouts.is_empty()
	game_over_best_label.text = "\n".join(callouts)
	game_over_panel.visible = true

func _on_game_over_close_pressed() -> void:
	game_over_panel.visible = false
	# Brief cooldown before the top mode buttons (one of which now reads
	# "Restart") become clickable again - dismissing the summary shouldn't
	# hand you a hot "do it again" button with zero breathing room.
	start_button.disabled = true
	chaos_button.disabled = true
	zen_button.disabled = true
	music_button.disabled = true
	duet_button.disabled = true
	await get_tree().create_timer(0.35).timeout
	start_button.disabled = false
	chaos_button.disabled = false
	zen_button.disabled = false
	music_button.disabled = false
	duet_button.disabled = false

func _flash_forgiven() -> void:
	_screen_shake(6.0, 0.15)
	_flash_screen(Color(1, 1, 1, 0.35))

# Audit finding: a blind retry only helps when the miss was a fumble, not a
# forgotten note - if you didn't know the note, guessing again with zero new
# information usually just fails again. Any "forgiven_hint" outcome (Safety
# Net, Unbreakable, Muffled Strike) replays the correct pad once before
# handing input back, so forgiveness actually saves the player rather than
# just delaying the same failure. Pads stay disabled during the hint so a
# stray click can't sneak in ahead of it.
func _flash_miss_hint(pad_name: String) -> void:
	_set_pads_disabled(true)
	var extra := _hint_note_count() - 1
	await pads_by_name[pad_name].flash(0.35)
	for i in extra:
		var idx: int = player_index + 1 + i
		if idx >= sequence.size():
			break
		await get_tree().create_timer(0.15).timeout
		await pads_by_name[sequence[idx]].flash(0.3)
	_set_pads_disabled(false)

# Echo Chamber (Defense): a soft, quiet echo of the pad(s) you need next.
# No button/charge (docs/modifier-audit.md rule 6) - fires automatically
# from _check_hesitation_assists() the moment you hesitate past its
# threshold. Doesn't disable pads or pause any clock - it's a passive
# in-flow nudge, not an interruption, so you can act on it the instant it
# appears.
func _trigger_echo_chamber_hint() -> void:
	var peek_count: int = int(_mod_val("echo_chamber", "peek_notes", -1, 1))
	for i in peek_count:
		var idx: int = player_index + i
		if idx >= sequence.size():
			break
		await pads_by_name[sequence[idx]].flash(0.28, 3.0, 0.28)
		await get_tree().create_timer(0.1).timeout

func _refresh_hearts_hud() -> void:
	var filled := "♥ ".repeat(hearts)
	var empty := "♡ ".repeat(max_hearts - hearts)
	hearts_label.text = (filled + empty).strip_edges()

func _update_score_labels() -> void:
	score_label.text = "Score: %d" % score
	if combo > 1:
		var multiplier := 1.0 + float(combo - 1) * combo_growth
		combo_label.text = "Combo x%d  (%.1fx)" % [combo, multiplier]
	else:
		combo_label.text = ""
	var total := _cash_out_total()
	var under_floor := unbanked_points < cash_out_floor
	if grand_finale_pending:
		cash_out_button.text = "Clear the round! (x%.1f)" % float(_mod_val("grand_finale", "mult"))
	elif under_floor:
		cash_out_button.text = "Cash Out (need %d more)" % (cash_out_floor - unbanked_points)
	else:
		cash_out_button.text = "Cash Out (+%d)" % total if total > 0 else "Cash Out"
	if accepting_input:
		cash_out_button.disabled = grand_finale_pending or total <= 0 or under_floor
	_refresh_loadout_hud()

func _set_pads_disabled(value: bool) -> void:
	for pad_name in pads_by_name:
		pads_by_name[pad_name].disabled = value
	# Cash out is only offered on the player's turn - not while the sequence
	# is playing back or during the round-clear pause, so it can't be tapped
	# mid-animation into an inconsistent state. Also stays off until there
	# is something to bank (a hit this streak), so the queued next round
	# can't inflate the payout before the player has acted.
	var under_floor := unbanked_points < cash_out_floor
	cash_out_button.disabled = value or grand_finale_pending or under_floor or _cash_out_total() <= 0
	_refresh_loadout_hud()

func _play_round_clear_beat() -> void:
	_punch(round_label)
	_flash_screen(Color(0.4, 1.0, 0.6, 0.15))

func _punch(node: Control) -> void:
	node.scale = Vector2(1.35, 1.35)
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _screen_shake(strength: float, duration: float) -> void:
	if reduce_motion:
		return
	var steps := 6
	var t := create_tween()
	for i in steps:
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		t.tween_property(self, "position", offset, duration / steps)
	t.tween_property(self, "position", Vector2.ZERO, duration / steps)

func _flash_screen(color: Color) -> void:
	var display_color := color
	if reduce_motion:
		display_color.a *= 0.25
	flash_overlay.color = display_color
	var t := create_tween()
	t.tween_property(flash_overlay, "color:a", 0.0, 0.5)

func _spawn_score_popup(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos - Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", label.position.y - 40, 0.6)
	t.tween_property(label, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(label.queue_free)

# Fires each entry's popup a beat after the last, staggered upward and
# slightly wider each time, so a hit with several modifiers active reads as
# a legible cascade (base amount, then each bonus in turn) instead of a
# stack of overlapping labels landing all at once.
func _spawn_score_popup_cascade(pos: Vector2, entries: Array[Dictionary]) -> void:
	var delay := 0.16
	var offset := Vector2(24, -22)
	for entry in entries:
		var text: String = entry["text"]
		var color: Color = entry["color"]
		var spawn_pos := pos + offset
		get_tree().create_timer(delay).timeout.connect(_spawn_score_popup.bind(spawn_pos, text, color))
		delay += 0.16
		offset += Vector2(24, -22)

func _spawn_burst(pos: Vector2, color: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 14
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 180.0
	particles.gravity = Vector2(0, 300)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = color
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(particles.queue_free)
