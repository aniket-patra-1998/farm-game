class_name Season
extends RefCounted
## The seasons (our own touch: FarmVille had none). The season follows the real calendar where the player lives:
## a region gives each month its season (data/seasons.json), so June is the monsoon in India, summer in Europe and
## winter in Australia. The region is guessed from the phone (its country, then its clock) and can be chosen in
## Settings. A season sets the weather's odds, the lawn's colour, and which crops are at home: a crop planted
## outside its seasons is off-season, sells for more and withers sooner (FieldSystem, Balance `seasons.*`).
## Pure functions of a time and a region, so they are easy to test; only the chosen region is kept.

const DATA := "res://data/seasons.json"
const SETTINGS := "farm"       # not-ui: the player's settings section the region is kept in
const REGION_KEY := "region"   # not-ui
const PLAIN := "Summer"        # not-ui: the season when seasons are off (tests, tools): what the game always had

## The switch on top of Balance `seasons.enabled`: tests and picture tools turn it off, so what they measure and
## draw does not change with the month they run in.
static var active := true

static var _data := {}
static var _region := ""       # the region in use ("" not read yet)


static func data() -> Dictionary:
	if _data.is_empty():
		_data = DataFile.read(DATA)
	return _data


static func enabled() -> bool:
	return active and Balance.i("seasons.enabled") != 0


static func regions() -> Array[String]:
	var out: Array[String] = []
	out.assign((data()["regions"] as Dictionary).keys())
	return out


## The region in use: the one chosen in Settings, or guessed from the phone.
static func region() -> String:
	if _region == "":
		_region = str(PlayerSettings.value(SETTINGS, REGION_KEY, ""))
		if not (data()["regions"] as Dictionary).has(_region):
			_region = guess_region(OS.get_locale(), DayCycle.device_bias_minutes())
	return _region


## Chooses the region (Settings), kept on the phone. `keep` false uses it without keeping it (tests), and "" then
## goes back to the kept or guessed one.
static func set_region(id: String, keep := true) -> void:
	if not keep:
		_region = id
	elif (data()["regions"] as Dictionary).has(id):
		_region = id
		PlayerSettings.keep(SETTINGS, {REGION_KEY: id})


## The region a phone is most likely in: by its country ("en_IN" -> IN), else by its clock's offset from UTC in
## minutes (a phone set to English (US) in Kolkata is still in the monsoon), else the default.
static func guess_region(locale: String, bias_minutes: int) -> String:
	var parts := locale.split("_")
	var country := parts[parts.size() - 1].to_upper() if parts.size() > 1 else ""
	var all: Dictionary = data()["regions"]
	for id: String in all:
		if country != "" and (all[id]["countries"] as Array).has(country):
			return id
	for id: String in all:
		for bias: float in all[id]["bias"]:
			if int(bias) == bias_minutes:
				return id
	return str(data()["default_region"])


## The season at a time (unix seconds; `bias_minutes` is the clock's offset from UTC), in a region (the one in
## use when not given). PLAIN when seasons are off.
static func at(unix_time: int, bias_minutes: int, region_id := "") -> String:
	if not enabled():
		return PLAIN
	var all: Dictionary = data()["regions"]
	var months: Array = all[region_id if all.has(region_id) else region()]["months"]
	var date := Time.get_datetime_dict_from_unix_time(unix_time + bias_minutes * 60)
	return str(months[int(date["month"]) - 1])


## The weather odds (a key of Balance `weather.odds`) a season uses in a region: the region's own for that season
## when it has them (no snow in an Indian winter), else the season's.
static func odds_key(season: String, region_id := "") -> String:
	if not enabled():
		return season
	var all: Dictionary = data()["regions"]
	var own: Dictionary = all[region_id if all.has(region_id) else region()].get("odds", {})
	return str(own.get(season, season))


## The seasons a crop is at home in ([] all year).
static func seasons_of(crop_id: String) -> Array:
	return (data()["crops"] as Dictionary).get(crop_id, [])


## Whether a crop planted in `season` is off-season (never when seasons are off, or for a crop at home all year).
static func is_off(crop_id: String, season: String) -> bool:
	if not enabled():
		return false
	var home := seasons_of(crop_id)
	return not home.is_empty() and not home.has(season)


## The farm's lawn in a season: {grass_light, grass_dark, dryness} for the ground's shader ({} when seasons are
## off: the lawn keeps its own).
static func lawn(season: String) -> Dictionary:
	if not enabled():
		return {}
	var look: Dictionary = (data()["lawn"] as Dictionary).get(season, {})
	var out := {}
	for key: String in look:
		var v: Variant = look[key]
		out[key] = Color(float(v[0]), float(v[1]), float(v[2])) if v is Array else float(v)
	return out
