extends TestSuite
## The number files outside the catalog (balance, rolls, prizes, finds...) are checked as data, so a typo in a
## tuning change fails the build instead of the game: no negative number, no chance over 1, no missing field,
## every weighted prize list able to roll. The look files (crowding, linking, seasons...) hold signed offsets and
## are not number files.

const NUMBER_FILES: Array[String] = ["balance", "rolls", "mystery_box", "mystery_eggs", "finds", "social",
	"expansions", "feeds", "home_boosts", "synergies", "ribbons", "collections"]
const FRACTION_ENDINGS: Array[String] = ["chance", "_share"]   # a key named so is a chance or a share: 0 to 1
const WEIGHT_NOTE := "weight"   # a balance entry whose note starts so is a weight, not a fraction
const FIELDS := {   # the fields every record of a list must have: file -> {record list -> fields}
	"rolls": {"rolls": ["vip", "what"]},
	"expansions": {"steps": ["size", "level", "coins", "gems"]},
	"ribbons": {"ribbons": ["id", "name", "stat", "thresholds"]},
	"collections": {"collections": ["id", "name", "items", "rewards"]},
	"finds": {"families": ["name", "trigger", "kinds"]},
}


func _read(file: String) -> Dictionary:
	return DataFile.read("res://data/%s.json" % file)


func _is_fraction(name: String) -> bool:
	return FRACTION_ENDINGS.any(func(e: String) -> bool: return name.ends_with(e))


## Every number in `value` (found under `name`, its nearest key) is 0 or more, and 0 to 1 under a fraction's name.
func _walk(value: Variant, path: String, name: String, fraction: bool, out: Array[String]) -> void:
	if value is Dictionary:
		var weight := str(value.get("note", "")).begins_with(WEIGHT_NOTE)
		for k: String in value:
			if k.begins_with("_") or k == "note":
				continue
			var inner := name if k == "v" else k
			_walk(value[k], "%s.%s" % [path, k], inner, (fraction or _is_fraction(inner)) and not weight, out)
	elif value is Array:
		for n in value.size():
			_walk(value[n], "%s[%d]" % [path, n], name, fraction, out)
	elif value is float or value is int:
		if value < 0:
			out.append("%s is negative (%s)" % [path, str(value)])
		elif fraction and value > 1:
			out.append("%s is a chance or share over 1 (%s)" % [path, str(value)])


## A weighted prize list: each prize is [kind, amount or item, weight] with a weight above 0.
func _prizes(prizes: Variant, path: String, out: Array[String]) -> void:
	if not prizes is Array or prizes.is_empty():
		out.append("%s has no prizes" % path)
		return
	for n in prizes.size():
		var p: Variant = prizes[n]
		if not p is Array or p.size() != 3 or not (p[2] is float or p[2] is int) or p[2] <= 0:
			out.append("%s[%d] is not [kind, amount, weight above 0]" % [path, n])


## What is wrong with one number file, as readable lines (none when it is sound).
func problems(file: String, data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if data.is_empty():
		out.append("%s is missing or empty" % file)
		return out
	_walk(data, file, "", false, out)
	if file == "balance":
		for section: String in data:
			if section.begins_with("_"):
				continue
			for entry: String in data[section]:
				if not data[section][entry] is Dictionary or not data[section][entry].has("v"):
					out.append("balance.%s.%s has no value (v)" % [section, entry])
	for list: String in FIELDS.get(file, {}):
		var records: Variant = data.get(list)
		if records is Dictionary:
			records = records.values()
		if not records is Array or records.is_empty():
			out.append("%s.%s is missing" % [file, list])
			continue
		for n in records.size():
			for field: String in FIELDS[file][list]:
				if not records[n] is Dictionary or not records[n].has(field):
					out.append("%s.%s[%d] has no %s" % [file, list, n, field])
	if file == "mystery_box":
		_prizes(data.get("prizes"), "mystery_box.prizes", out)
	if file == "mystery_eggs":
		for colour: String in data.get("colours", {}):
			_prizes(data["colours"][colour].get("prizes"), "mystery_eggs.%s.prizes" % colour, out)
	if file == "ribbons":
		var tiers: int = data.get("tiers", []).size()
		for key in ["tier_reward_coins", "tier_reward_xp"]:
			if data.get(key, []).size() != tiers:
				out.append("ribbons.%s has %d tiers' worth, not %d" % [key, data.get(key, []).size(), tiers])
		for r: Dictionary in data.get("ribbons", []):
			if r.get("thresholds", []).size() != tiers:
				out.append("ribbons %s has %d thresholds, not %d" % [r.get("id"), r.get("thresholds", []).size(), tiers])
	return out


func test_442_number_files_have_no_negative_no_chance_over_one_and_no_missing_field() -> void:
	for file in NUMBER_FILES:
		_eq(problems(file, _read(file)), [] as Array[String], "%s.json is sound" % file)
	# The check itself catches each kind of mistake (a file planted with one of each):
	var bad := problems("balance", {"harvest": {"golden_chance": {"v": 1.5, "note": "a chance"},
		"payout": {"v": -10, "note": "coins"}, "kind_share": {"v": 2, "note": "weight: a share"}, "lost": {"note": "x"}}})
	_eq(bad.size(), 3, "a chance over 1, a negative cost and a missing value are found, a weight is not (%s)" % str(bad))
	_eq(problems("mystery_box", {"prizes": [["coins", 100, 0]]}).size(), 1, "a prize that can never roll is found")
	_eq(problems("expansions", {"steps": [{"size": 14, "level": 5, "coins": 5000}]}).size(), 1,
		"a step without its gem price is found")
	_eq(problems("ribbons", {"tiers": ["Yellow"], "tier_reward_coins": [100], "tier_reward_xp": [],
		"ribbons": [{"id": "a", "name": "A", "stat": "s", "thresholds": [1]}]}).size(), 1, "a missing tier's reward is found")
