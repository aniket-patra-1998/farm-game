class_name Balance
extends RefCounted
## The game's numbers, from data/balance.json: chances, gaps, timers, payouts, caps. Code asks by key
## ("harvest.golden_chance") instead of holding a constant, so tuning is a data change and every number can be
## listed, checked and simulated in one place (tools/balance_lint.py, tools/balance_sim.tscn).
## A key that isn't there is a bug: it's reported once and reads as 0 (a test and the lint catch it before it ships).

const PATH := "res://data/balance.json"

static var revision := 0                  # counts every change of the numbers, so what is cached from them can tell
static var _values: Dictionary = {}     # "section.name" -> value
static var _notes: Dictionary = {}      # "section.name" -> what it is
static var _loaded := false
static var _missing: Dictionary = {}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("balance.json can't be read")
		return
	for section: String in parsed:
		if section.begins_with("_"):
			continue
		var entries: Dictionary = parsed[section]
		for name: String in entries:
			var e: Dictionary = entries[name]
			_values["%s.%s" % [section, name]] = e["v"]
			_notes["%s.%s" % [section, name]] = str(e.get("note", ""))


## A number as a float.
static func f(key: String) -> float:
	return float(_value(key))


## A whole number.
static func i(key: String) -> int:
	return int(_value(key))


## A list of numbers (a table).
static func a(key: String) -> Array:
	var v: Variant = _value(key)
	return v if v is Array else []


## A table of named numbers (a dictionary).
static func d(key: String) -> Dictionary:
	var v: Variant = _value(key)
	return v if v is Dictionary else {}


static func has(key: String) -> bool:
	_load()
	return _values.has(key)


## Every key, for tools and tests.
static func keys() -> Array:
	_load()
	return _values.keys()


static func note(key: String) -> String:
	_load()
	return str(_notes.get(key, ""))


## Replaces a value for the rest of the run (a simulation trying a change); `reload` puts the file back.
static func override(key: String, value: Variant) -> void:
	_load()
	_values[key] = value
	revision += 1


static func reload() -> void:
	_loaded = false
	_values = {}
	_notes = {}
	revision += 1
	_load()


static func _value(key: String) -> Variant:
	_load()
	if not _values.has(key):
		if not _missing.has(key):
			_missing[key] = true
			push_error("Balance: no number called %s" % key)
		return 0
	return _values[key]
