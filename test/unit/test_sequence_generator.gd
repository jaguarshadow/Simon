extends GutTest

# SequenceGenerator (sequence_generator.gd) - Euclidean rhythm generation is
# already covered by test_euclidean_rhythm.gd (via Main's wrapper); this
# covers the tonal-hierarchy resolution math and the walk step, using
# c_major_diatonic - a plain diatonic scale where semitone distances (and
# therefore expected weights) are easy to hand-verify.

func _c_major_diatonic() -> Dictionary:
	for scale in GameData.SCALES:
		if scale["id"] == "c_major_diatonic":
			return scale
	fail_test("c_major_diatonic not found in GameData.SCALES")
	return {}

# --- reflect_degree ---

func test_reflect_degree_passes_in_range_values_through() -> void:
	assert_eq(SequenceGenerator.reflect_degree(3), 3)

func test_reflect_degree_bounces_off_the_low_edge() -> void:
	assert_eq(SequenceGenerator.reflect_degree(-2), 2)

func test_reflect_degree_bounces_off_the_high_edge() -> void:
	# PAD_COUNT=8, so the high edge is index 7. Overshooting to 9 reflects
	# back to (7*2 - 9) = 5.
	assert_eq(SequenceGenerator.reflect_degree(9), 5)

# --- semitones_from_tonic / scale_degree_weight (c_major_diatonic) ---

func test_semitones_from_tonic_matches_diatonic_intervals() -> void:
	var scale := _c_major_diatonic()
	assert_eq(SequenceGenerator.semitones_from_tonic(0, scale), 0)   # C
	assert_eq(SequenceGenerator.semitones_from_tonic(2, scale), 4)   # E
	assert_eq(SequenceGenerator.semitones_from_tonic(4, scale), 7)   # G
	assert_eq(SequenceGenerator.semitones_from_tonic(7, scale), 0)   # C octave, mod 12

func test_scale_degree_weight_nonzero_only_for_tonic_and_triad() -> void:
	var scale := _c_major_diatonic()
	for d in [0, 2, 4, 7]:
		assert_true(SequenceGenerator.scale_degree_weight(d, scale) > 0.0, "degree %d should be a resolution tone" % d)
	for d in [1, 3, 5, 6]:
		assert_eq(SequenceGenerator.scale_degree_weight(d, scale), 0.0, "degree %d should not be a resolution tone" % d)

func test_scale_degree_weight_discounts_boundary_degrees() -> void:
	var scale := _c_major_diatonic()
	# Degree 0 and degree 7 (PAD_COUNT-1) are both tonic-class (0 semitones)
	# but at the boundary, so both get the same discounted weight - and it
	# must be strictly less than an interior tonic-class degree would get.
	var boundary_weight := SequenceGenerator.scale_degree_weight(0, scale)
	assert_eq(boundary_weight, SequenceGenerator.scale_degree_weight(7, scale))
	assert_lt(boundary_weight, SequenceGenerator.MUSIC_DEGREE_WEIGHT_TONIC)

func test_is_resolution_degree_matches_nonzero_weight() -> void:
	var scale := _c_major_diatonic()
	assert_true(SequenceGenerator.is_resolution_degree(4, scale))
	assert_false(SequenceGenerator.is_resolution_degree(3, scale))

# --- pick_resolution_degree ---

func test_pick_resolution_degree_only_ever_returns_resolution_tones() -> void:
	var scale := _c_major_diatonic()
	for i in 100:
		var d := SequenceGenerator.pick_resolution_degree(scale)
		assert_true(SequenceGenerator.is_resolution_degree(d, scale), "picked non-resolution degree %d" % d)

# --- nearest_chord_tone_degree ---

func test_nearest_chord_tone_degree_returns_self_if_already_one() -> void:
	var scale := _c_major_diatonic()
	assert_eq(SequenceGenerator.nearest_chord_tone_degree(4, scale), 4)

func test_nearest_chord_tone_degree_picks_the_closer_neighbor() -> void:
	var scale := _c_major_diatonic()
	# Degree 3 (F) sits between degree 2 (E, chord tone) and degree 4 (G,
	# chord tone), both distance 1 - ties resolve to the lower-index degree
	# since the scan runs 0..PAD_COUNT-1 and only updates on strict <.
	assert_eq(SequenceGenerator.nearest_chord_tone_degree(3, scale), 2)

# --- ring_side ---

func test_ring_side_splits_the_ring_order_in_half() -> void:
	var scale := _c_major_diatonic()
	var ring_order: Array = scale["ring_order"]
	assert_eq(SequenceGenerator.ring_side(ring_order[0], scale), 0)
	assert_eq(SequenceGenerator.ring_side(ring_order[7], scale), 1)

# --- walk_next_step ---

func test_walk_next_step_repeat_returns_zero_delta_and_preserves_direction() -> void:
	var scale := _c_major_diatonic()
	# repeat_streak so high the repeat-chance decay is negligible and
	# step/leap chance dominates would defeat the point - instead force the
	# repeat branch deterministically isn't possible without seeding RNG,
	# so this asserts the *contract* of a magnitude-0 result instead: delta
	# 0, direction unchanged, was_leap false. Run enough times to hit it at
	# least once at streak 1 (30% base chance).
	var saw_repeat := false
	for i in 200:
		var step: Dictionary = SequenceGenerator.walk_next_step(4, 1, 1, false, 3, scale, 0.5, 1)
		if step["delta"] == 0:
			saw_repeat = true
			assert_eq(step["direction"], 1)
			assert_false(step["was_leap"])
	assert_true(saw_repeat, "expected at least one repeat in 200 draws at 30% base chance")

func test_walk_next_step_post_leap_forces_a_single_step_reversal() -> void:
	var scale := _c_major_diatonic()
	for i in 50:
		var step: Dictionary = SequenceGenerator.walk_next_step(4, 1, 1, true, 3, scale, 0.5, 1)
		if step["delta"] != 0:
			# last_was_leap=true, last_direction=1 -> forced reversal, magnitude 1
			assert_eq(step["delta"], -1)
			assert_false(step["was_leap"])

func test_walk_next_step_delta_never_exceeds_max_leap() -> void:
	var scale := _c_major_diatonic()
	for i in 300:
		var step: Dictionary = SequenceGenerator.walk_next_step(4, 1, 0, false, 3, scale, 0.5, 1)
		assert_true(absi(step["delta"]) <= 4, "delta %d exceeded max_leap 4" % step["delta"])
