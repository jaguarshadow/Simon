extends GutTest

# _meets_requirement/_meets_requirement_values (Main.gd) - unlock-gate
# checks for Scales/Palettes/Themes/Modifiers. Two separate code paths that
# must stay in sync by hand (see the "flag"/"waves" gap documented on
# _meets_requirement_values) - these tests pin down both paths' current,
# intentional behavior so a future edit to one doesn't silently drift from
# the other without a test noticing.

var main: Main

func before_each() -> void:
	main = autofree(Main.new())

# --- _meets_requirement: reads *current* best_*/achieved state ---

func test_round_requirement_met_at_threshold() -> void:
	main.best_round = 5
	assert_true(main._meets_requirement({"type": "round", "value": 5}))

func test_round_requirement_not_met_below_threshold() -> void:
	main.best_round = 4
	assert_false(main._meets_requirement({"type": "round", "value": 5}))

func test_score_requirement() -> void:
	main.best_score = 1500
	assert_true(main._meets_requirement({"type": "score", "value": 1500}))
	assert_false(main._meets_requirement({"type": "score", "value": 1501}))

func test_combo_requirement() -> void:
	main.best_combo = 25
	assert_true(main._meets_requirement({"type": "combo", "value": 25}))
	assert_false(main._meets_requirement({"type": "combo", "value": 26}))

func test_waves_requirement() -> void:
	main.best_waves = 10
	assert_true(main._meets_requirement({"type": "waves", "value": 10}))
	assert_false(main._meets_requirement({"type": "waves", "value": 11}))

func test_flag_requirement_zero_miss_wave() -> void:
	main.zero_miss_wave_achieved = true
	assert_true(main._meets_requirement({"type": "flag", "key": "zero_miss_wave"}))
	main.zero_miss_wave_achieved = false
	assert_false(main._meets_requirement({"type": "flag", "key": "zero_miss_wave"}))

func test_flag_requirement_five_cashouts() -> void:
	main.five_cashouts_achieved = true
	assert_true(main._meets_requirement({"type": "flag", "key": "five_cashouts"}))

func test_flag_requirement_unknown_key_is_never_met() -> void:
	main.zero_miss_wave_achieved = true
	main.five_cashouts_achieved = true
	assert_false(main._meets_requirement({"type": "flag", "key": "some_future_flag"}))

func test_unhandled_requirement_type_falls_through_to_met() -> void:
	# Documented, intentional: any type not explicitly matched (there is
	# none today besides round/score/combo/waves/flag) is treated as
	# already-satisfied rather than blocking content.
	assert_true(main._meets_requirement({"type": "totally_unknown"}))

# --- _meets_requirement_values: diffs a prior round/score/combo baseline ---
# only supports round/score/combo (see the push_warning it raises for
# anything else) - used solely to detect "just crossed this threshold" for
# the end-of-run unlock toast.

func test_values_round_requirement_uses_passed_value_not_current_best() -> void:
	main.best_round = 999
	assert_true(main._meets_requirement_values({"type": "round", "value": 5}, 5, 0, 0))
	assert_false(main._meets_requirement_values({"type": "round", "value": 5}, 4, 0, 0))

func test_values_score_and_combo_requirements() -> void:
	assert_true(main._meets_requirement_values({"type": "score", "value": 100}, 0, 100, 0))
	assert_true(main._meets_requirement_values({"type": "combo", "value": 10}, 0, 0, 10))

func test_values_unhandled_type_falls_through_to_true() -> void:
	# waves/flag aren't diffable against a "before this run" baseline here
	# (see the function's comment) - falls through to true, same as the
	# live _meets_requirement() default, so an unlock never silently blocks.
	assert_true(main._meets_requirement_values({"type": "waves", "value": 10}, 0, 0, 0))
	assert_true(main._meets_requirement_values({"type": "flag", "key": "zero_miss_wave"}, 0, 0, 0))
