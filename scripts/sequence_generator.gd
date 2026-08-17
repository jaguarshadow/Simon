class_name SequenceGenerator
extends RefCounted

# The procedural-generation math behind Music/Normal/Duet Mode - Euclidean
# rhythm (Bjorklund's algorithm), tonal-hierarchy resolution weighting, and
# the biased-random-walk melody step - pulled out of Main.gd. All static
# and already close to pure in their original form (only PAD_COUNT and a
# handful of tuning constants, duplicated below for the same reason as
# ModifierSystem's - self-contained, stable numbers Main.gd also needs at
# parse time). The mode-specific walk *state* (current degree, last
# direction, repeat streak, etc.) stays owned by Main as `_music_*`/
# `_normal_*` fields - these functions take that state as parameters and
# return the next value instead of mutating it themselves.

const PAD_COUNT := 8

const BASE_REPEAT_CHANCE := 0.30
const REPEAT_DECAY := 0.4
const STEP_TO_NON_REPEAT_RATIO := 0.55 / 0.70
const MUSIC_ARCH_BIAS := 0.3

const MUSIC_DEGREE_WEIGHT_TONIC := 2.4
const MUSIC_DEGREE_WEIGHT_TRIAD := 1.5
const MUSIC_DEGREE_WEIGHT_BOUNDARY_FACTOR := 0.4

# Euclidean rhythm (Bjorklund's algorithm): distributes `pulses` onsets as
# evenly as possible across `steps`, e.g. E(3,8) -> 10010010. Standard
# "fill two bucket lists, repeatedly fold the shorter into the longer"
# construction.
static func euclidean_rhythm(pulses: int, steps: int) -> Array[bool]:
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

# Reflecting boundary (Xenakis's random-walk barrier technique - see
# docs/music-mode.md): an out-of-range step bounces back into range by the
# amount it overshot, rather than clamping to the edge value. Clamping was
# forcing the walk to deterministically pick a single "safe" direction
# whenever it stood on an edge with no established direction yet (e.g.
# every game's opening note, always the tonic), which killed melodic
# variety right where it mattered most. Reflection keeps direction fully
# random and still guarantees real movement.
static func reflect_degree(raw_target: int) -> int:
	var reflected := raw_target
	if reflected < 0:
		reflected = -reflected
	elif reflected > PAD_COUNT - 1:
		reflected = (PAD_COUNT - 1) * 2 - reflected
	return clampi(reflected, 0, PAD_COUNT - 1)

# Semitone distance from the tonic (degree 0), via the scale's actual tuned
# frequencies rather than hardcoded per-scale music theory - works for any
# scale definition in GameData.SCALES, including ones with unusual/non-
# diatonic interval structure.
static func semitones_from_tonic(degree: int, scale: Dictionary) -> int:
	var tones: Array = scale.get("tones", [])
	if tones.is_empty() or degree >= tones.size() or float(tones[0]) <= 0.0:
		return 0
	var ratio: float = float(tones[degree]) / float(tones[0])
	var semitones := int(round(12.0 * log(ratio) / log(2.0))) % 12
	return semitones + 12 if semitones < 0 else semitones

# Tonal-hierarchy weight for a degree: tonic (0 or 12 semitones - i.e. any
# octave) highest, then a secondary tier next, everything else (passing
# tones) excluded from resolution entirely (weight 0). Degrees at either
# edge of the pad range (0 or PAD_COUNT-1) get discounted, since
# reflect_degree() gives a boundary degree exactly one neighbor - see
# docs/music-mode.md#note-distribution-bias-fix.
#
# `style` (optional, defaults to {} so every non-Music-Mode call site is
# unaffected) is a small resolved-context dict, not a raw GameData.MUSIC_STYLES
# entry - see Main.gd's _resolution_style_context(). Two knobs, both computed
# generically from the scale's own tuned frequencies (no scale-type guard,
# works on any scale):
#   resolution_secondary_weight - the secondary tier's weight relative to the
#   tonic (defaults to MUSIC_DEGREE_WEIGHT_TRIAD). Raising it toward the tonic
#   weight gives a stronger, bassline-like pull (Reggae); lowering it gives a
#   looser, less-resolved feel (Middle Eastern). A per-style constant, not
#   Tune-panel-tunable.
#   fourth_octave_blend (0..1, live-tunable via the "fourth_octave" idiom
#   slider) - blends how much of the secondary weight goes to the Western
#   triad tier (minor/major 3rd or perfect 5th - 3, 4, or 7 semitones from
#   the tonic) versus the perfect 4th (5 semitones), per Koizumi's Japanese
#   nuclear-tone theory. 0 = pure triad (today's original behavior), 1 = pure
#   4th. The octave itself already falls under the tonic tier (0 semitones
#   after the mod-12 fold), so it needs no separate case here.
static func scale_degree_weight(degree: int, scale: Dictionary, style: Dictionary = {}) -> float:
	var secondary_weight: float = style.get("resolution_secondary_weight", MUSIC_DEGREE_WEIGHT_TRIAD)
	var fourth_blend: float = style.get("fourth_octave_blend", 0.0)
	var semitones := semitones_from_tonic(degree, scale)
	var weight := 0.0
	if semitones == 0:
		weight = MUSIC_DEGREE_WEIGHT_TONIC
	else:
		var is_triad_tier := semitones == 3 or semitones == 4 or semitones == 7
		var is_fourth_tier := semitones == 5
		if is_triad_tier:
			weight += secondary_weight * (1.0 - fourth_blend)
		if is_fourth_tier:
			weight += secondary_weight * fourth_blend
		if weight <= 0.0:
			return 0.0
	if degree == 0 or degree == PAD_COUNT - 1:
		weight *= MUSIC_DEGREE_WEIGHT_BOUNDARY_FACTOR
	return weight

static func pick_resolution_degree(scale: Dictionary, style: Dictionary = {}) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for d in PAD_COUNT:
		var w := scale_degree_weight(d, scale, style)
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

static func is_resolution_degree(degree: int, scale: Dictionary, style: Dictionary = {}) -> bool:
	return scale_degree_weight(degree, scale, style) > 0.0

# Chord tones on strong beats (see docs/music-mode.md#chord-tones-on-
# strong-beats): standard tonal/counterpoint practice puts chord tones on
# strong metrical positions and reserves passing tones for weak ones.
# Finds the closest degree with a nonzero scale_degree_weight() (a local
# nudge, not a jump to a weighted-random one).
static func nearest_chord_tone_degree(degree: int, scale: Dictionary, style: Dictionary = {}) -> int:
	var best := degree
	var best_dist := PAD_COUNT
	for d in PAD_COUNT:
		if scale_degree_weight(d, scale, style) <= 0.0:
			continue
		var dist := absi(d - degree)
		if dist < best_dist:
			best_dist = dist
			best = d
	return best

# Which physical half of the ring a scale degree sits on, per the scale's
# ring_order - used for the zigzag contour bias, not for lookup.
static func ring_side(degree: int, scale: Dictionary) -> int:
	var ring_order: Array = scale.get("ring_order", [0, 1, 2, 3, 4, 5, 6, 7])
	var ring_pos: int = ring_order.find(degree)
	if ring_pos == -1:
		return 0
	return 0 if ring_pos < PAD_COUNT / 2 else 1

# Biased random walk step: mostly stepwise motion, some repeats, occasional
# leaps. Direction follows two documented melodic tendencies (Huron, "Sweet
# Anticipation"; Narmour's implication-realization model) rather than an
# arbitrary streak-count rule:
# - step inertia: a stepwise move tends to be followed by another step in
#   the same direction, not a reversal.
# - post-skip reversal: a leap tends to be followed by stepwise motion back
#   the other way, "filling the gap" it just opened.
# `arch_direction` is evaluated eagerly by the caller even though it's only
# applied on the arch-bias roll below - it's a deterministic, side-effect-
# free lookup, so that costs nothing and keeps this function's
# randf()/randi_range() call order (and therefore the generated melodies)
# stable regardless of caller.
static func walk_next_step(max_leap: int, repeat_streak: int, last_direction: int, last_was_leap: bool, current_degree: int, scale: Dictionary, zigzag_bias: float, arch_direction: int, arch_bias: float = MUSIC_ARCH_BIAS) -> Dictionary:
	var repeat_chance: float = BASE_REPEAT_CHANCE * pow(REPEAT_DECAY, float(repeat_streak - 1))
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
		return {"delta": 0, "direction": last_direction, "was_leap": false, "used_zigzag": false}
	var direction: int
	var is_gap_fill := false
	# Whether zigzag_bias actually had an asymmetric crossing option to lean
	# on for this step (vs. both/neither direction crossing, where it has
	# nothing to prefer) - lets the Tune panel visualizer mark exactly the
	# notes zigzag_bias shaped, instead of a color the player can't verify.
	var used_zigzag := false
	if last_was_leap and last_direction != 0:
		direction = -last_direction
		magnitude = 1
		is_gap_fill = true
	elif last_direction != 0 and magnitude == 1:
		# Step inertia's 70/30 continue-vs-reverse split (Chiu & Temperley)
		# is the baseline, but which option actually crosses to the other
		# physical ring side gets pulled toward per zigzag_bias - previously
		# zigzag only applied when there was no established direction at
		# all (session start / a reset), which left it barely perceptible
		# since ordinary continuing steps like this one are most of the
		# walk. zigzag_bias's tuned range is [0.5, 1.0]; 0.5 maps to
		# crossing_pull=0 (pure step inertia, unchanged), 1.0 to
		# crossing_pull=1 (near-certain to take whichever option crosses).
		var current_side := ring_side(current_degree, scale)
		var continue_side := ring_side(reflect_degree(current_degree + last_direction), scale)
		var reverse_side := ring_side(reflect_degree(current_degree - last_direction), scale)
		var continue_prob := 0.70
		var crossing_pull: float = clampf((zigzag_bias - 0.5) * 2.0, 0.0, 1.0)
		if continue_side != current_side and reverse_side == current_side:
			continue_prob = lerpf(0.70, 0.95, crossing_pull)
			used_zigzag = true
		elif reverse_side != current_side and continue_side == current_side:
			continue_prob = lerpf(0.70, 0.30, crossing_pull)
			used_zigzag = true
		direction = last_direction if randf() < continue_prob else -last_direction
	else:
		# No established scale-degree direction to defer to (session start,
		# or right after a phrase-end/anchor-return reset) - bias toward
		# whichever direction lands on the opposite side of the physical
		# ring, rather than a flat coin flip, per the zigzag idiom.
		var current_side := ring_side(current_degree, scale)
		var plus_side := ring_side(reflect_degree(current_degree + magnitude), scale)
		var minus_side := ring_side(reflect_degree(current_degree - magnitude), scale)
		if plus_side != current_side and minus_side == current_side:
			direction = 1 if randf() < zigzag_bias else -1
			used_zigzag = true
		elif minus_side != current_side and plus_side == current_side:
			direction = -1 if randf() < zigzag_bias else 1
			used_zigzag = true
		else:
			direction = 1 if randf() < 0.5 else -1
	# Melodic arch (see docs/music-mode.md#melodic-arch) - not applied to a
	# gap-fill reversal, since that's a hard contour rule (Narmour) the arch
	# shouldn't second-guess.
	if not is_gap_fill and randf() < arch_bias:
		direction = arch_direction
	return {"delta": direction * magnitude, "direction": direction, "was_leap": magnitude >= 2, "used_zigzag": used_zigzag}
