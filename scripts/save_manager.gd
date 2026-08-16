extends Node

# Generic JSON-dictionary file I/O, pulled out of Main.gd's save/load so the
# "how to get a dictionary to/from disk safely" concern (open, null-check,
# parse, validate) is isolated from "what fields the save file has" - Main.gd
# still owns the latter entirely; this never sees a specific field name.
# The null-checks here are load-bearing: a locked/unwritable save file (AV
# scan, cloud-sync lock) previously crashed the game outright instead of
# falling back gracefully.

func read_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open '%s' for reading: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data

func write_dict(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open '%s' for writing: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(data))

# Type-checked field readers for hand-corrupted/malformed saves: a plain
# int(data.get(key, default)) coerces unpredictably if the field is itself
# a Dictionary/Array (e.g. a save hand-edited or corrupted mid-write)
# instead of failing loudly - these fall back to `default` and warn instead,
# so a bad field is visible in the log rather than silently misread.

func get_int(data: Dictionary, key: String, default: int) -> int:
	var value: Variant = data.get(key, default)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		push_warning("Save field '%s' has unexpected type %s, using default %s" % [key, type_string(typeof(value)), default])
		return default
	return int(value)

func get_float(data: Dictionary, key: String, default: float) -> float:
	var value: Variant = data.get(key, default)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		push_warning("Save field '%s' has unexpected type %s, using default %s" % [key, type_string(typeof(value)), default])
		return default
	return float(value)

func get_bool(data: Dictionary, key: String, default: bool) -> bool:
	var value: Variant = data.get(key, default)
	if typeof(value) != TYPE_BOOL:
		push_warning("Save field '%s' has unexpected type %s, using default %s" % [key, type_string(typeof(value)), default])
		return default
	return value
