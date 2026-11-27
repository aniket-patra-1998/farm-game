class_name Balance
extends RefCounted
## The game's numbers, from data/balance.json: chances, gaps, timers, payouts, caps. Code asks by key
## ("harvest.golden_chance") instead of holding a constant, so tuning is a data change and every number can be
## listed, checked and simulated in one place (tools/balance_lint.py, tools/balance_sim.tscn).
## A key that isn't there is a bug: it's reported once and reads as 0 (a test and the lint catch it before it ships).

const PATH := "res://data/balance.json"
## Remote tuning (docs/PACKS.md, Online): numbers fetched from the packs' host (tuning.json beside the manifest) and
## kept here; read at the next start, so a number never changes under a running session. Only keys this file
## knows are taken, so a typo there changes nothing.
const REMOTE := "user://tuning.json"

static var revision := 0                  # counts every change of the numbers, so what is cached from them can tell
static var _values: Dictionary = {}     # "section.name" -> value
static var _notes: Dictionary = {}      # "section.name" -> what it is
static var _loaded := false
static var _missing: Dictionary = {}
static var _remote: Dictionary = {}     # "section.name" -> the value tuning.json sets (wins over the file and Release)
static var remote_on := true            # tests and tools that want the file's numbers only turn it off


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed := DataFile.read(PATH)
	if parsed.is_empty():
		return
	for section: String in parsed:
		if section.begins_with("_"):
			continue
		var entries: Dictionary = parsed[section]
		for name: String in entries:
			var e: Dictionary = entries[name]
			_values["%s.%s" % [section, name]] = e["v"]
			_notes["%s.%s" % [section, name]] = str(e.get("note", ""))
	if remote_on:
		take_remote(DataFile.read_optional(REMOTE))


## The values of a tuning file (`{"values": {"section.name": value}}`) this file knows; the rest are left out.
## Returns how many were taken.
static func take_remote(tuning: Dictionary) -> int:
	_remote = {}
	var values: Dictionary = tuning.get("values", {})
	for key: String in values:
		if _values.has(key) and typeof(values[key]) == typeof(_values[key]):
			_remote[key] = values[key]
	revision += 1
	return _remote.size()


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
	_remote = {}
	_notes = {}
	revision += 1
	_load()


static func _value(key: String) -> Variant:
	_load()
	if _remote.has(key):
		return _remote[key]
	var released: Variant = Release.balance(key)   # (this release's own value: docs/V1.md)
	if released != null:
		return released
	if not _values.has(key):
		if not _missing.has(key):
			_missing[key] = true
			push_error("Balance: no number called %s" % key)
		return 0
	return _values[key]
