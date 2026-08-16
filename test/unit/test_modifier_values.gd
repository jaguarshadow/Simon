extends GutTest

# _mod_def/_mod_level/_mod_val/_mod_category (Main.gd) - the lookup layer
# every modifier's live behavior reads through. _mod_val's level-clamping
# in particular is the one thing standing between a bad level (out of
# range, unset) and an out-of-bounds array read.

var main: Main

func before_each() -> void:
	main = autofree(Main.new())

func test_mod_def_finds_entry_by_id() -> void:
	var mod := main._mod_def("sharper_ear")
	assert_eq(mod.get("id"), "sharper_ear")
	assert_eq(mod.get("category"), "multiplier")

func test_mod_def_returns_empty_dict_for_unknown_id() -> void:
	assert_eq(main._mod_def("not_a_real_modifier"), {})

func test_mod_level_defaults_to_zero_when_unequipped() -> void:
	assert_eq(main._mod_level("sharper_ear"), 0)

func test_mod_level_reflects_modifier_levels_dict() -> void:
	main.modifier_levels["sharper_ear"] = 3
	assert_eq(main._mod_level("sharper_ear"), 3)

func test_mod_val_reads_explicit_level() -> void:
	# sharper_ear L3 combo_growth_bonus = 0.09
	assert_eq(main._mod_val("sharper_ear", "combo_growth_bonus", 3), 0.09)

func test_mod_val_defaults_to_level_one_when_unequipped_and_no_level_given() -> void:
	assert_eq(main._mod_val("sharper_ear", "combo_growth_bonus"), 0.03)

func test_mod_val_reads_current_equipped_level_when_no_level_given() -> void:
	main.modifier_levels["sharper_ear"] = 5
	assert_eq(main._mod_val("sharper_ear", "combo_growth_bonus"), 0.15)

func test_mod_val_clamps_level_above_max() -> void:
	# levels.size() == 5 for sharper_ear; asking for level 99 should clamp
	# to the top entry rather than index out of range.
	assert_eq(main._mod_val("sharper_ear", "combo_growth_bonus", 99), 0.15)

func test_mod_val_clamps_non_positive_level_to_one() -> void:
	assert_eq(main._mod_val("sharper_ear", "combo_growth_bonus", -5), 0.03)

func test_mod_val_returns_fallback_for_missing_key() -> void:
	assert_eq(main._mod_val("sharper_ear", "not_a_real_key", 1, 42.0), 42.0)

func test_mod_val_returns_fallback_for_unknown_modifier_id() -> void:
	assert_eq(main._mod_val("not_a_real_modifier", "x", 1, "fallback"), "fallback")

func test_mod_category_matches_definition() -> void:
	assert_eq(main._mod_category("quick_rewind"), "tempo")

func test_mod_category_empty_for_unknown_id() -> void:
	assert_eq(main._mod_category("not_a_real_modifier"), "")
