class_name ModifierSystem
extends RefCounted

# The modifier draft/equip/level-up rules and per-level lookups, pulled out
# of Main.gd so "how a modifier pick resolves" and "what a given level
# grants" are testable without a Control node or scene tree. Main.gd still
# owns the actual `equipped_modifiers`/`modifier_levels` state (they're
# read from ~40 gameplay-flow functions across the file - genuinely moving
# that ownership would mean rewriting all of them, not just this system) -
# every function here takes that state as parameters/reference instead.
# All static: this class holds no state of its own.

# --- Pure lookups ---

static func mod_def(id: String) -> Dictionary:
	for mod in GameData.MODIFIERS:
		if mod["id"] == id:
			return mod
	return {}

static func mod_level(modifier_levels: Dictionary, id: String) -> int:
	return int(modifier_levels.get(id, 0))

# Reads a per-level numeric field for `id`. Defaults to the *current* level;
# pass an explicit level (1-5) to preview a different one (used by the draft
# panel to show what a level-up would grant).
static func mod_val(modifier_levels: Dictionary, id: String, key: String, level := -1, fallback: Variant = 0) -> Variant:
	var lvl: int = level if level > 0 else mod_level(modifier_levels, id)
	if lvl <= 0:
		lvl = 1
	var mod := mod_def(id)
	if mod.is_empty():
		return fallback
	var levels: Array = mod["levels"]
	var idx: int = clampi(lvl, 1, levels.size()) - 1
	return levels[idx].get(key, fallback)

static func mod_category(id: String) -> String:
	return String(mod_def(id).get("category", ""))

# --- Draft offer ---

# `is_unlocked` is injected as a Callable (Dictionary -> bool) rather than
# this class reaching into Main's best_round/best_score/cheat_all_unlocked
# state directly - keeps the pool-filtering rule (not-maxed, unlocked if a
# power modifier) independent of how "unlocked" is decided.
static func build_offer(modifier_levels: Dictionary, is_unlocked: Callable) -> Array:
	var pool: Array = []
	for mod in GameData.MODIFIERS:
		if mod_level(modifier_levels, mod["id"]) >= MAX_MODIFIER_LEVEL:
			continue
		if mod["power"] and not is_unlocked.call(mod):
			continue
		pool.append(mod)
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size()))

# --- Equip/level-up resolution ---

# True if picking `id` into its category slot is a direct equip/level-up
# (empty slot, or already the incumbent) rather than a swap-or-skip
# decision the player needs to confirm.
static func is_direct_equip(equipped_modifiers: Dictionary, id: String) -> bool:
	var cat := mod_category(id)
	var incumbent: String = equipped_modifiers[cat]
	return incumbent == id or incumbent == ""

# Mutates `equipped_modifiers`/`modifier_levels` in place (GDScript
# Dictionaries are reference types, so Main's own instances update
# directly) and returns what happened, for the caller to react to
# (toast text, forgiveness-counter reset, stat recompute).
static func apply_pick(equipped_modifiers: Dictionary, modifier_levels: Dictionary, id: String) -> Dictionary:
	var cat := mod_category(id)
	var from_level := mod_level(modifier_levels, id)
	var to_level: int = mini(from_level + 1, MAX_MODIFIER_LEVEL)
	equipped_modifiers[cat] = id
	modifier_levels[id] = to_level
	return {
		"category": cat,
		"to_level": to_level,
		"mod": mod_def(id),
		"reset_forgiveness": id == "unbreakable" or id == "second_wind",
	}

# --- Derived stats ---

# Duplicated from Main.gd rather than referenced cross-class: these are
# stable balance numbers Main.gd also needs at parse time for its own var
# initializers (e.g. `var hearts := RUN_START_HEARTS`), and keeping this
# class fully self-contained matters more here than a single source of
# truth for numbers this unlikely to drift independently.
const MAX_MODIFIER_LEVEL := 5
const BASE_COMBO_GROWTH := 0.1
const RUN_START_HEARTS := 3

# Pure (non-consumable) per-level stats, recomputed fully from scratch any
# time equip/level state changes - unlike charges/uses which are spent
# during play and must only ever be granted incrementally. Callers apply
# the returned values to their own fields and refresh whatever UI depends
# on them (hearts HUD, score labels) themselves.
static func recompute_pure_stats(equipped_modifiers: Dictionary, modifier_levels: Dictionary, current_hearts: int) -> Dictionary:
	var stats := {
		"combo_growth": BASE_COMBO_GROWTH,
		"score_bonus_percent": 0.0,
		"golden_step_count": 0,
		"sequence_speed_multiplier": 1.0,
		"quick_rewind_speed_mult": 0.0,
		"breath_mark_pct": 0.0,
		"rubato_level": 0,
		"rubato_two_directional": false,
		"grounding_resonance_pct": 0.0,
		"max_hearts": RUN_START_HEARTS,
	}

	var mult_id: String = equipped_modifiers["multiplier"]
	if mult_id == "sharper_ear":
		stats["combo_growth"] += mod_val(modifier_levels, mult_id, "combo_growth_bonus")
	elif mult_id == "resonance":
		stats["score_bonus_percent"] += mod_val(modifier_levels, mult_id, "bonus")

	if equipped_modifiers["bonus_event"] == "golden_step":
		stats["golden_step_count"] = int(mod_val(modifier_levels, "golden_step", "count"))

	if equipped_modifiers["tempo"] == "steady_hands":
		stats["sequence_speed_multiplier"] = 1.0 + float(mod_val(modifier_levels, "steady_hands", "pct"))

	var tempo_id: String = equipped_modifiers["tempo"]
	match tempo_id:
		"quick_rewind":
			stats["quick_rewind_speed_mult"] = float(mod_val(modifier_levels, tempo_id, "speed_mult"))
		"breath_mark":
			stats["breath_mark_pct"] = float(mod_val(modifier_levels, tempo_id, "pct"))
		"rubato":
			stats["rubato_level"] = mod_level(modifier_levels, tempo_id)
			stats["rubato_two_directional"] = bool(mod_val(modifier_levels, tempo_id, "two_directional"))

	if equipped_modifiers["defense"] == "grounding_resonance":
		stats["grounding_resonance_pct"] = float(mod_val(modifier_levels, "grounding_resonance", "pct"))

	# Second Wind L5 raises the heart ceiling by 1 - recomputed here (not
	# granted once) so swapping Second Wind out mid-run correctly drops the
	# bonus max, clamping current hearts down with it if needed.
	if equipped_modifiers["defense"] == "second_wind" and bool(mod_val(modifier_levels, "second_wind", "bonus_max_heart")):
		stats["max_hearts"] = RUN_START_HEARTS + 1
	stats["hearts"] = mini(current_hearts, stats["max_hearts"])

	return stats
