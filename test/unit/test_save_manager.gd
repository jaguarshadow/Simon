extends GutTest

# SaveManager (autoload) - generic JSON-dictionary file I/O extracted out of
# Main.gd's save/load. Uses a scratch path under user:// so these tests
# never touch the real save file.

const TEST_PATH := "user://gut_test_save_manager.json"

func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func test_read_dict_returns_empty_for_missing_file() -> void:
	assert_eq(SaveManager.read_dict(TEST_PATH), {})

func test_write_then_read_round_trips() -> void:
	# JSON has no int/float distinction, so numbers always come back as
	# float regardless of what was written - real callers always wrap reads
	# in int()/bool()/float() (see Main.gd's _load_progress), so this test
	# writes/expects float to match what actually round-trips.
	var payload := {"best_score": 42.0, "nested": {"a": 1.0}}
	SaveManager.write_dict(TEST_PATH, payload)
	assert_eq(SaveManager.read_dict(TEST_PATH), payload)

func test_read_dict_returns_empty_when_json_is_not_a_dictionary() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	assert_eq(SaveManager.read_dict(TEST_PATH), {})

# --- get_int/get_float/get_bool: type-checked field readers ---

func test_get_int_reads_a_valid_int() -> void:
	assert_eq(SaveManager.get_int({"x": 5}, "x", 0), 5)

func test_get_int_accepts_float_json_numbers() -> void:
	# JSON round-trips ints as float - see test_write_then_read_round_trips.
	assert_eq(SaveManager.get_int({"x": 5.0}, "x", 0), 5)

func test_get_int_falls_back_to_default_for_missing_key() -> void:
	assert_eq(SaveManager.get_int({}, "x", 7), 7)

func test_get_int_falls_back_to_default_for_wrong_type() -> void:
	# A hand-corrupted save with "x" as a Dictionary/Array instead of a
	# number - must not crash or silently misconvert.
	assert_eq(SaveManager.get_int({"x": {"y": 1}}, "x", 7), 7)
	assert_eq(SaveManager.get_int({"x": [1, 2]}, "x", 7), 7)
	assert_eq(SaveManager.get_int({"x": "not a number"}, "x", 7), 7)

func test_get_bool_reads_a_valid_bool() -> void:
	assert_eq(SaveManager.get_bool({"x": true}, "x", false), true)

func test_get_bool_falls_back_to_default_for_wrong_type() -> void:
	assert_eq(SaveManager.get_bool({"x": 1}, "x", false), false)
	assert_eq(SaveManager.get_bool({"x": "true"}, "x", false), false)

func test_get_float_reads_a_valid_number() -> void:
	assert_eq(SaveManager.get_float({"x": 0.75}, "x", 0.0), 0.75)

func test_get_float_falls_back_to_default_for_wrong_type() -> void:
	assert_eq(SaveManager.get_float({"x": [1]}, "x", 0.5), 0.5)
