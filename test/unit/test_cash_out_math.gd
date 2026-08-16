extends GutTest

# Cash-out scoring math (Main.gd) - the piece the docs call out as
# piecewise-continuous at MEMORY_SPAN_CEILING and the one place a modifier
# audit already found a real bug (Resonance not reaching the streak bonus).
# No scene tree needed: these all read/write plain instance vars, not
# @onready nodes.

var main: Main

func before_each() -> void:
	main = autofree(Main.new())
	# combo defaults to 0, which (via the `combo - 1` term in the streak-
	# bonus multiplier) reads as *below* baseline, not "no combo yet" - set
	# it to 1 (the real in-game floor once a streak has actually started)
	# so tests default to a clean 1.0x multiplier unless testing combo
	# scaling itself.
	main.combo = 1

func _fill_sequence(n: int) -> void:
	var seq: Array[String] = []
	seq.resize(n)
	seq.fill("pad_0")
	main.sequence = seq

# --- _cash_out_base_bonus: linear below the ceiling, quadratic beyond it ---

func test_base_bonus_is_purely_linear_at_zero() -> void:
	assert_eq(main._cash_out_base_bonus(0), 0.0)

func test_base_bonus_below_ceiling_is_linear() -> void:
	# CASHOUT_LINEAR_K = 16.0, MEMORY_SPAN_CEILING = 8 -> no quadratic term yet.
	assert_eq(main._cash_out_base_bonus(5), 80.0)

func test_base_bonus_at_ceiling_has_no_quadratic_contribution_yet() -> void:
	assert_eq(main._cash_out_base_bonus(8), 128.0)

func test_base_bonus_beyond_ceiling_adds_quadratic_term() -> void:
	# beyond = 10 - 8 = 2; 16*10 + 10*2^2 = 160 + 40 = 200
	assert_eq(main._cash_out_base_bonus(10), 200.0)

# --- _current_wave_length: counts the in-progress streak, Normal/Chaos vs Duet ---

func test_wave_length_normal_mode_counts_sequence_when_hit_landed() -> void:
	_fill_sequence(6)
	main.current_round_has_hit = true
	assert_eq(main._current_wave_length(), 6)

func test_wave_length_normal_mode_excludes_unresolved_note() -> void:
	_fill_sequence(6)
	main.current_round_has_hit = false
	assert_eq(main._current_wave_length(), 5)

func test_wave_length_never_goes_negative() -> void:
	_fill_sequence(0)
	main.current_round_has_hit = false
	assert_eq(main._current_wave_length(), 0)

func test_wave_length_duet_mode_uses_duet_wave_round_not_sequence() -> void:
	_fill_sequence(99)
	main.duet_mode = true
	main.duet_wave_round = 4
	main.current_round_has_hit = true
	assert_eq(main._current_wave_length(), 4)

# --- _cash_out_streak_bonus: combo/Resonance/Crescendo/Fortissimo compounding ---

func test_streak_bonus_with_no_modifiers_and_baseline_combo() -> void:
	_fill_sequence(5)
	main.current_round_has_hit = true
	assert_eq(main._cash_out_streak_bonus(), 80)

func test_streak_bonus_scales_with_combo_growth() -> void:
	_fill_sequence(5)
	main.current_round_has_hit = true
	main.combo = 4
	main.combo_growth = 0.1
	# multiplier = 1 + 3*0.1 = 1.3; 80 * 1.3 = 104
	assert_eq(main._cash_out_streak_bonus(), 104)

func test_streak_bonus_includes_resonance_flat_bonus_percent() -> void:
	# Regression guard for the audited bug: Resonance previously only
	# reached unbanked_points, never this streak bonus.
	_fill_sequence(5)
	main.current_round_has_hit = true
	main.score_bonus_percent = 0.2
	# 80 * 1.2 = 96
	assert_eq(main._cash_out_streak_bonus(), 96)

func test_streak_bonus_applies_crescendo_multiplier_per_wave() -> void:
	_fill_sequence(5)
	main.current_round_has_hit = true
	main.equipped_modifiers["multiplier"] = "crescendo"
	main.waves_completed = 2
	# Level 1 crescendo: per_wave = 0.05, additive -> 1 + 0.05*2 = 1.10
	# 80 * 1.10 = 88
	assert_eq(main._cash_out_streak_bonus(), 88)

func test_streak_bonus_applies_fortissimo_once_streak_passes_best() -> void:
	_fill_sequence(5)
	main.current_round_has_hit = true
	main.equipped_modifiers["multiplier"] = "fortissimo"
	main.best_streak_this_run = 1
	# Level 1 fortissimo: margin 3, mult 1.3; wave length 5 >= 1+3.
	# 80 * 1.3 = 104
	assert_eq(main._cash_out_streak_bonus(), 104)

func test_streak_bonus_fortissimo_inactive_before_margin_is_reached() -> void:
	_fill_sequence(5)
	main.current_round_has_hit = true
	main.equipped_modifiers["multiplier"] = "fortissimo"
	main.best_streak_this_run = 10
	assert_eq(main._cash_out_streak_bonus(), 80)

func test_streak_bonus_includes_double_down_boost() -> void:
	_fill_sequence(5)
	main.current_round_has_hit = true
	main.double_down_boost_amount = 3
	# s = 5 + 3 = 8, still under the ceiling: 16*8 = 128
	assert_eq(main._cash_out_streak_bonus(), 128)

func test_streak_bonus_without_crescendo_excludes_only_crescendo() -> void:
	_fill_sequence(5)
	main.current_round_has_hit = true
	main.equipped_modifiers["multiplier"] = "crescendo"
	main.waves_completed = 2
	main.combo = 4
	main.combo_growth = 0.1
	var with_crescendo := main._cash_out_streak_bonus()
	var without_crescendo := main._cash_out_streak_bonus_without_crescendo()
	assert_true(with_crescendo > without_crescendo)
	# without_crescendo still reflects the combo multiplier: 80 * 1.3 = 104
	assert_eq(without_crescendo, 104)

func test_cash_out_total_adds_unbanked_points_to_streak_bonus() -> void:
	_fill_sequence(5)
	main.current_round_has_hit = true
	main.unbanked_points = 40
	assert_eq(main._cash_out_total(), 120)
