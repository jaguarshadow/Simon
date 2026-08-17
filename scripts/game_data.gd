extends Node

# All of the game's authored content tables - modifiers, scales, palettes,
# themes, onboarding copy, FAQ copy - pulled out of Main.gd (see
# docs/architecture.md) so the "what the game contains" data lives apart
# from "how the game runs" logic. An autoload rather than a plain class so
# every reference site keeps a simple `GameData.MODIFIERS` lookup instead
# of needing a shared instance threaded through.

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

## Real steel-tongue-drum/handpan tone fields are numbered in ascending pitch order but laid out
## physically alternating sides of the ring ("zigzag"/"zipper" layout) - a fixed, scale-independent
## pattern, not something re-derived per scale. HANDPAN_RING_ORDER encodes that: which scale degree
## sits at each physical ring position, walking clockwise from the tonic. Every scale uses it.
const HANDPAN_RING_ORDER := [0, 2, 4, 6, 7, 5, 3, 1]

const SCALES := [
	{"id": "d_minor_pentatonic", "name": "D Minor\nPentatonic", "tones": [146.83, 174.61, 196.0, 220.0, 261.63, 293.66, 349.23, 440.0], "notes": ["D", "F", "G", "A", "C", "D", "F", "A"], "ring_order": HANDPAN_RING_ORDER},
	{"id": "c_major_pentatonic", "name": "C Major\nPentatonic", "tones": [261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25], "notes": ["C", "D", "E", "G", "A", "C", "D", "E"], "ring_order": HANDPAN_RING_ORDER},
	{"id": "d_akebono", "name": "D Akebono", "tones": [293.66, 329.63, 349.23, 440.0, 466.16, 587.33, 659.25, 698.46], "notes": ["D", "E", "F", "A", "Bb", "D", "E", "F"], "ring_order": HANDPAN_RING_ORDER},
	{"id": "d_minor", "name": "D Minor\nDiatonic", "tones": [146.83, 164.81, 174.61, 196.0, 220.0, 233.08, 261.63, 293.66], "notes": ["D", "E", "F", "G", "A", "Bb", "C", "D"], "unlock": {"type": "round", "value": 10}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "e_minor_pentatonic", "name": "E Minor\nPentatonic", "tones": [164.81, 196.0, 220.0, 246.94, 293.66, 329.63, 392.0, 440.0], "notes": ["E", "G", "A", "B", "D", "E", "G", "A"], "unlock": {"type": "round", "value": 5}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "g_major_pentatonic", "name": "G Major\nPentatonic", "tones": [196.0, 220.0, 246.94, 293.66, 329.63, 392.0, 440.0, 493.88], "notes": ["G", "A", "B", "D", "E", "G", "A", "B"], "unlock": {"type": "score", "value": 500}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "c_major_diatonic", "name": "C Major\nDiatonic", "tones": [130.81, 146.83, 164.81, 174.61, 196.0, 220.0, 246.94, 261.63], "notes": ["C", "D", "E", "F", "G", "A", "B", "C"], "unlock": {"type": "combo", "value": 15}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "chromatic_run", "name": "Chromatic\nRun", "tones": [130.81, 138.59, 146.83, 155.56, 164.81, 174.61, 185.0, 196.0], "notes": ["C", "C#", "D", "D#", "E", "F", "F#", "G"], "unlock": {"type": "round", "value": 15}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "a_minor_pentatonic", "name": "A Minor\nPentatonic", "tones": [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33], "notes": ["A", "C", "D", "E", "G", "A", "C", "D"], "unlock": {"type": "round", "value": 25}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "a_akebono_pentatonic", "name": "A Akebono\nPentatonic", "tones": [220.0, 246.94, 261.63, 329.63, 349.23, 440.0, 493.88, 523.25], "notes": ["A", "B", "C", "E", "F", "A", "B", "C"], "unlock": {"type": "score", "value": 3000}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "e_major_pentatonic", "name": "E Major\nPentatonic", "tones": [164.81, 185.0, 207.65, 246.94, 277.18, 329.63, 369.99, 415.3], "notes": ["E", "F#", "G#", "B", "C#", "E", "F#", "G#"], "unlock": {"type": "combo", "value": 25}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "d_dorian", "name": "D Dorian", "tones": [146.83, 164.81, 174.61, 196.0, 220.0, 246.94, 261.63, 293.66], "notes": ["D", "E", "F", "G", "A", "B", "C", "D"], "unlock": {"type": "round", "value": 20}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "blues_hexatonic", "name": "A Blues", "tones": [220.0, 261.63, 293.66, 311.13, 329.63, 392.0, 440.0, 523.25], "notes": ["A", "C", "D", "Eb", "E", "G", "A", "C"], "unlock": {"type": "score", "value": 1000}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "d_hijaz", "name": "D Hijaz", "tones": [146.83, 155.56, 185.0, 196.0, 220.0, 233.08, 261.63, 293.66], "notes": ["D", "Eb", "F#", "G", "A", "Bb", "C", "D"], "unlock": {"type": "combo", "value": 20}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "hungarian_minor", "name": "E Hungarian\nMinor", "tones": [164.81, 185.0, 196.0, 233.08, 246.94, 261.63, 311.13, 329.63], "notes": ["E", "F#", "G", "A#", "B", "C", "D#", "E"], "unlock": {"type": "round", "value": 30}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "insen", "name": "C Insen", "tones": [261.63, 277.18, 349.23, 392.0, 466.16, 523.25, 554.37, 698.46], "notes": ["C", "Db", "F", "G", "Bb", "C", "Db", "F"], "unlock": {"type": "score", "value": 4000}, "ring_order": HANDPAN_RING_ORDER},
	{"id": "whole_tone", "name": "C Whole\nTone", "tones": [261.63, 293.66, 329.63, 369.99, 415.3, 466.16, 523.25, 587.33], "notes": ["C", "D", "E", "F#", "G#", "A#", "C", "D"], "unlock": {"type": "combo", "value": 30}, "ring_order": HANDPAN_RING_ORDER},
]

# Music Mode "Style" presets - reparametrize the generator (Main.gd's
# _music_*/_normal_* functions, SequenceGenerator's resolution weighting)
# per real-world melodic idiom, without new instruments or per-style
# exception code. Every entry shares the exact same field shape; different
# styles pick different *values*, never a field/guard the others lack -
# see docs/music-mode.md#style-presets for the full research writeup and
# per-style reasoning.
#
#   accent_mode                 "downbeat" | "offbeat" - which rhythm pulse
#                                gets the accent (see Main.gd's
#                                _music_is_accented_step()).
#   resolution_mode              "triad" | "fourth_octave" - which degrees
#                                count as the secondary tonal-hierarchy tier
#                                (see SequenceGenerator.scale_degree_weight()).
#   resolution_secondary_weight  overrides that tier's weight relative to
#                                the tonic (MUSIC_DEGREE_WEIGHT_TRIAD=1.5 is
#                                the unmodified baseline; higher = stronger/
#                                more bassline-like pull, lower = looser).
#   chord_tone_nudge_chance      per-note (not just strong-beat) chance to
#                                nudge onto the nearest chord tone.
#   rhythm_pulses_min/max        Euclidean onset count out of 16 steps.
#   idiom_overrides              sparse {idiom_key: {min,default,max}}
#                                merged over MUSIC_IDIOM_RANGES.
#   max_leap_override            overrides the narrow/pentatonic max-leap
#                                pick when non-null.
#   phrase_structure              "arch" | "flat_arch" | "call_response".
#   groove_lock                  true forces groove_repeats/riff_shapes
#                                near-permanently on instead of the normal
#                                per-bar roll (Junkanoo's locked ostinato).
const MUSIC_STYLES := [
	{"id": "western", "name": "Western",
		"accent_mode": "downbeat", "resolution_mode": "triad", "resolution_secondary_weight": 1.5,
		"chord_tone_nudge_chance": 0.0,
		"rhythm_pulses_min": 5, "rhythm_pulses_max": 9,
		"idiom_overrides": {}, "max_leap_override": null,
		"phrase_structure": "arch", "groove_lock": false},
	{"id": "reggae", "name": "Reggae\n(Jamaica)",
		"accent_mode": "offbeat", "resolution_mode": "triad", "resolution_secondary_weight": 2.1,
		"chord_tone_nudge_chance": 0.75,
		"rhythm_pulses_min": 3, "rhythm_pulses_max": 6,
		"idiom_overrides": {"groove_repeats": {"min": 0.35, "default": 0.75, "max": 0.95}},
		"max_leap_override": null, "phrase_structure": "arch", "groove_lock": false},
	{"id": "junkanoo", "name": "Junkanoo\n(Bahamas)",
		"accent_mode": "downbeat", "resolution_mode": "triad", "resolution_secondary_weight": 1.6,
		"chord_tone_nudge_chance": 0.4,
		"rhythm_pulses_min": 11, "rhythm_pulses_max": 13,
		"idiom_overrides": {}, "max_leap_override": null,
		"phrase_structure": "call_response", "groove_lock": true},
	{"id": "middle_eastern", "name": "Middle\nEastern",
		"accent_mode": "downbeat", "resolution_mode": "triad", "resolution_secondary_weight": 0.9,
		"chord_tone_nudge_chance": 0.05,
		"rhythm_pulses_min": 4, "rhythm_pulses_max": 8,
		"idiom_overrides": {"glissando": {"min": 0.0, "default": 0.55, "max": 0.9}, "ghost_notes": {"min": 0.0, "default": 0.32, "max": 0.6}},
		"max_leap_override": null, "phrase_structure": "arch", "groove_lock": false},
	{"id": "balkan", "name": "Balkan /\nGypsy",
		"accent_mode": "downbeat", "resolution_mode": "triad", "resolution_secondary_weight": 1.5,
		"chord_tone_nudge_chance": 0.15,
		"rhythm_pulses_min": 6, "rhythm_pulses_max": 10,
		"idiom_overrides": {"riff_shapes": {"min": 0.0, "default": 0.55, "max": 0.8}, "zigzag_bias": {"min": 0.5, "default": 0.85, "max": 1.0}},
		"max_leap_override": null, "phrase_structure": "arch", "groove_lock": false},
	{"id": "japanese", "name": "Japanese /\nEastern",
		"accent_mode": "downbeat", "resolution_mode": "fourth_octave", "resolution_secondary_weight": 1.9,
		"chord_tone_nudge_chance": 0.05,
		"rhythm_pulses_min": 3, "rhythm_pulses_max": 5,
		"idiom_overrides": {"anchor_return": {"min": 0.0, "default": 0.05, "max": 0.2}},
		"max_leap_override": 2, "phrase_structure": "flat_arch", "groove_lock": false},
	{"id": "jazz", "name": "Jazz",
		"accent_mode": "downbeat", "resolution_mode": "triad", "resolution_secondary_weight": 1.5,
		"chord_tone_nudge_chance": 0.4,
		"rhythm_pulses_min": 6, "rhythm_pulses_max": 10,
		"idiom_overrides": {"zigzag_bias": {"min": 0.5, "default": 0.95, "max": 1.0}},
		"max_leap_override": null, "phrase_structure": "arch", "groove_lock": false},
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
