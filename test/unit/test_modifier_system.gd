extends GutTest

# ModifierSystem (modifier_system.gd) - the draft/equip/level-up rules and
# per-level lookups, extracted out of Main.gd. All static; state
# (equipped_modifiers/modifier_levels) is passed in by the caller rather
# than owned here, so these tests build their own throwaway dicts matching
# Main.gd's shape rather than instantiating Main.

func _fresh_equipped() -> Dictionary:
	return {"multiplier": "", "defense": "", "tempo": "", "bonus_event": ""}

# --- build_offer ---

func test_build_offer_returns_at_most_three() -> void:
	var offer := ModifierSystem.build_offer({}, func(_mod): return true)
	assert_lte(offer.size(), 3)

func test_build_offer_excludes_maxed_modifiers() -> void:
	# sharper_ear at MAX_MODIFIER_LEVEL should never appear in the pool.
	var levels := {"sharper_ear": ModifierSystem.MAX_MODIFIER_LEVEL}
	for i in 50:
		var offer: Array = ModifierSystem.build_offer(levels, func(_mod): return true)
		for mod in offer:
			assert_ne(mod["id"], "sharper_ear")

func test_build_offer_excludes_locked_power_modifiers() -> void:
	var always_locked := func(_mod): return false
	for i in 50:
		var offer: Array = ModifierSystem.build_offer({}, always_locked)
		for mod in offer:
			assert_false(mod["power"], "power modifier %s should be excluded when locked" % mod["id"])

func test_build_offer_includes_unlocked_power_modifiers_eventually() -> void:
	# Non-power modifiers always pass; power ones only when unlocked=true.
	# Over enough draws with everything unlocked, at least one power
	# modifier should show up (rubato/fortissimo/second_wind/etc. exist).
	var found_power := false
	for i in 200:
		var offer: Array = ModifierSystem.build_offer({}, func(_mod): return true)
		for mod in offer:
			if mod["power"]:
				found_power = true
	assert_true(found_power)

# --- is_direct_equip ---

func test_is_direct_equip_true_for_empty_slot() -> void:
	assert_true(ModifierSystem.is_direct_equip(_fresh_equipped(), "sharper_ear"))

func test_is_direct_equip_true_when_same_id_already_equipped() -> void:
	var equipped := _fresh_equipped()
	equipped["multiplier"] = "sharper_ear"
	assert_true(ModifierSystem.is_direct_equip(equipped, "sharper_ear"))

func test_is_direct_equip_false_when_a_different_id_fills_the_slot() -> void:
	var equipped := _fresh_equipped()
	equipped["multiplier"] = "resonance"
	assert_false(ModifierSystem.is_direct_equip(equipped, "sharper_ear"))

# --- apply_pick ---

func test_apply_pick_equips_into_the_right_category_at_level_one() -> void:
	var equipped := _fresh_equipped()
	var levels := {}
	var result := ModifierSystem.apply_pick(equipped, levels, "sharper_ear")
	assert_eq(equipped["multiplier"], "sharper_ear")
	assert_eq(levels["sharper_ear"], 1)
	assert_eq(result["to_level"], 1)
	assert_eq(result["category"], "multiplier")

func test_apply_pick_levels_up_an_already_equipped_modifier() -> void:
	var equipped := _fresh_equipped()
	equipped["multiplier"] = "sharper_ear"
	var levels := {"sharper_ear": 2}
	var result := ModifierSystem.apply_pick(equipped, levels, "sharper_ear")
	assert_eq(levels["sharper_ear"], 3)
	assert_eq(result["to_level"], 3)

func test_apply_pick_caps_at_max_level() -> void:
	var equipped := _fresh_equipped()
	var levels := {"sharper_ear": ModifierSystem.MAX_MODIFIER_LEVEL}
	var result := ModifierSystem.apply_pick(equipped, levels, "sharper_ear")
	assert_eq(result["to_level"], ModifierSystem.MAX_MODIFIER_LEVEL)

func test_apply_pick_flags_forgiveness_reset_for_unbreakable_and_second_wind() -> void:
	var equipped := _fresh_equipped()
	assert_true(ModifierSystem.apply_pick(equipped, {}, "unbreakable")["reset_forgiveness"])
	assert_true(ModifierSystem.apply_pick(_fresh_equipped(), {}, "second_wind")["reset_forgiveness"])
	assert_false(ModifierSystem.apply_pick(_fresh_equipped(), {}, "sharper_ear")["reset_forgiveness"])

func test_apply_pick_swaps_out_the_incumbent_in_the_same_category() -> void:
	var equipped := _fresh_equipped()
	equipped["multiplier"] = "resonance"
	ModifierSystem.apply_pick(equipped, {}, "sharper_ear")
	assert_eq(equipped["multiplier"], "sharper_ear")

# --- recompute_pure_stats ---

func test_recompute_pure_stats_defaults_with_nothing_equipped() -> void:
	var stats := ModifierSystem.recompute_pure_stats(_fresh_equipped(), {}, 3)
	assert_eq(stats["combo_growth"], ModifierSystem.BASE_COMBO_GROWTH)
	assert_eq(stats["score_bonus_percent"], 0.0)
	assert_eq(stats["max_hearts"], ModifierSystem.RUN_START_HEARTS)
	assert_eq(stats["hearts"], 3)

func test_recompute_pure_stats_sharper_ear_boosts_combo_growth() -> void:
	var equipped := _fresh_equipped()
	equipped["multiplier"] = "sharper_ear"
	var stats := ModifierSystem.recompute_pure_stats(equipped, {"sharper_ear": 1}, 3)
	assert_eq(stats["combo_growth"], ModifierSystem.BASE_COMBO_GROWTH + 0.03)

func test_recompute_pure_stats_resonance_sets_score_bonus_not_combo_growth() -> void:
	var equipped := _fresh_equipped()
	equipped["multiplier"] = "resonance"
	var stats := ModifierSystem.recompute_pure_stats(equipped, {"resonance": 1}, 3)
	assert_eq(stats["combo_growth"], ModifierSystem.BASE_COMBO_GROWTH)
	assert_eq(stats["score_bonus_percent"], 0.04)

func test_recompute_pure_stats_second_wind_l5_raises_max_hearts_and_keeps_current() -> void:
	var equipped := _fresh_equipped()
	equipped["defense"] = "second_wind"
	var stats := ModifierSystem.recompute_pure_stats(equipped, {"second_wind": 5}, 3)
	assert_eq(stats["max_hearts"], ModifierSystem.RUN_START_HEARTS + 1)
	assert_eq(stats["hearts"], 3)

func test_recompute_pure_stats_clamps_hearts_down_when_bonus_heart_is_lost() -> void:
	# Simulates swapping Second Wind L5 out mid-run while at the bonus max.
	var stats := ModifierSystem.recompute_pure_stats(_fresh_equipped(), {}, ModifierSystem.RUN_START_HEARTS + 1)
	assert_eq(stats["max_hearts"], ModifierSystem.RUN_START_HEARTS)
	assert_eq(stats["hearts"], ModifierSystem.RUN_START_HEARTS)

func test_recompute_pure_stats_rubato_reads_level_and_two_directional_flag() -> void:
	var equipped := _fresh_equipped()
	equipped["tempo"] = "rubato"
	var stats := ModifierSystem.recompute_pure_stats(equipped, {"rubato": 5}, 3)
	assert_eq(stats["rubato_level"], 5)
	assert_true(stats["rubato_two_directional"])
	stats = ModifierSystem.recompute_pure_stats(equipped, {"rubato": 3}, 3)
	assert_eq(stats["rubato_level"], 3)
	assert_false(stats["rubato_two_directional"])
