extends GutTest

# _euclidean_rhythm(pulses, steps) implements Bjorklund's algorithm (see the
# comment above it in Main.gd, which documents E(3,8) -> 10010010 itself -
# these are the standard reference patterns used to sanity-check any
# from-scratch Bjorklund implementation.

var main: Main

func before_each() -> void:
	main = autofree(Main.new())

func _bools_to_string(pattern: Array[bool]) -> String:
	var out := ""
	for on in pattern:
		out += "1" if on else "0"
	return out

func test_e_3_8_matches_documented_pattern() -> void:
	assert_eq(_bools_to_string(main._euclidean_rhythm(3, 8)), "10010010")

func test_e_4_8_is_a_steady_backbeat() -> void:
	assert_eq(_bools_to_string(main._euclidean_rhythm(4, 8)), "10101010")

func test_e_2_5() -> void:
	assert_eq(_bools_to_string(main._euclidean_rhythm(2, 5)), "10100")

func test_e_5_8() -> void:
	assert_eq(_bools_to_string(main._euclidean_rhythm(5, 8)), "10110110")

func test_zero_pulses_is_all_off() -> void:
	var pattern := main._euclidean_rhythm(0, 8)
	assert_eq(pattern.size(), 8)
	assert_eq(pattern.count(true), 0)

func test_negative_pulses_is_all_off() -> void:
	var pattern := main._euclidean_rhythm(-1, 8)
	assert_eq(pattern.size(), 8)
	assert_eq(pattern.count(true), 0)

func test_pulses_equal_to_steps_is_all_on() -> void:
	var pattern := main._euclidean_rhythm(8, 8)
	assert_eq(pattern.count(true), 8)

func test_pulses_exceeding_steps_is_all_on_and_clamped_to_step_count() -> void:
	var pattern := main._euclidean_rhythm(12, 8)
	assert_eq(pattern.size(), 8)
	assert_eq(pattern.count(true), 8)

func test_onset_count_always_matches_requested_pulses_in_range() -> void:
	# The one invariant every valid Euclidean rhythm must hold regardless of
	# the exact rotation/phase Bjorklund's construction lands on.
	for steps in range(1, 17):
		for pulses in range(0, steps + 1):
			var pattern := main._euclidean_rhythm(pulses, steps)
			assert_eq(pattern.size(), steps, "steps=%d pulses=%d" % [steps, pulses])
			assert_eq(pattern.count(true), pulses, "steps=%d pulses=%d" % [steps, pulses])
