class_name Weather
extends RefCounted
## The weather: one state per 3-hour block, picked from the date so it's the same every time you look,
## easing in and out at the edges of each block. Pure functions, so they're easy to test.
## Looks only for now (FarmVille had no weather); gameplay effects can hang off state() later.

const STATES := ["clear", "partly_cloudy", "cloudy", "rain", "storm", "fog", "snow"]
## From fair to foul: weather drifts along this line, so a clear spell clouds over, then rains, and clears again
## the same way, instead of jumping from sun to storm.
const ORDER := ["clear", "partly_cloudy", "cloudy", "rain", "snow", "storm"]
const FOGGY_BY := ["clear", "partly_cloudy", "cloudy"]   # fog forms out of these
# Display names, as keys in locale/strings.csv (shown with tr()).
const NAMES := {"clear": "WEATHER_SUNNY", "partly_cloudy": "WEATHER_PARTLY_CLOUDY", "cloudy": "WEATHER_CLOUDY",
	"rain": "WEATHER_RAIN", "storm": "WEATHER_STORM", "fog": "WEATHER_FOG", "snow": "WEATHER_SNOW"}
## What each state does to the picture, at full strength.
const LOOKS := {
	"clear":         {
		"cover": 0.10,
		"dim": 0.00,
		"desat": 0.00,
		"rain": 0.0,
		"snow": 0.0,
		"fog": 0.0,
		"lightning": 0.0
	},
	"partly_cloudy": {
		"cover": 0.40,
		"dim": 0.04,
		"desat": 0.05,
		"rain": 0.0,
		"snow": 0.0,
		"fog": 0.0,
		"lightning": 0.0
	},
	"cloudy":        {
		"cover": 0.80,
		"dim": 0.14,
		"desat": 0.22,
		"rain": 0.0,
		"snow": 0.0,
		"fog": 0.0,
		"lightning": 0.0
	},
	"rain":          {
		"cover": 0.95,
		"dim": 0.22,
		"desat": 0.30,
		"rain": 0.7,
		"snow": 0.0,
		"fog": 0.10,
		"lightning": 0.0
	},
	"storm":         {
		"cover": 1.00,
		"dim": 0.38,
		"desat": 0.40,
		"rain": 1.0,
		"snow": 0.0,
		"fog": 0.15,
		"lightning": 1.0
	},
	"fog":           {
		"cover": 0.60,
		"dim": 0.08,
		"desat": 0.30,
		"rain": 0.0,
		"snow": 0.0,
		"fog": 0.75,
		"lightning": 0.0
	},
	"snow":          {
		"cover": 0.85,
		"dim": 0.06,
		"desat": 0.25,
		"rain": 0.0,
		"snow": 0.8,
		"fog": 0.15,
		"lightning": 0.0
	},
}


static var _spread: Dictionary = {}   # persistence -> sorted samples of the noise, to turn it into an even 0..1


## Seconds in one weather block.
static func block() -> int:
	return Balance.i("weather.block_seconds")


## The state for the block holding this time (hour = local hour, for the fog rule). A pure function of the time:
## a smooth noise over the blocks (so weather persists for `weather.correlation_blocks`), spread evenly over 0..1
## and read against the season's odds laid out from fair to foul, so each season's odds are the share of time
## each kind really gets, and neighbouring blocks are alike.
static func state_at(unix_time: int, season: String, hour: float) -> String:
	var length := block()
	var index := int(floor(unix_time / float(length)))
	var odds: Dictionary = (Balance.d("weather.odds") as Dictionary).get(
		season,
		(Balance.d("weather.odds") as Dictionary)["Summer"]
	)
	var corr := maxf(Balance.f("weather.correlation_blocks"), 1.0)
	var fog := float(odds.get("fog", 0))
	var total := 0.0
	for s: String in odds:
		total += float(odds[s])
	var rest := total - fog
	var pick := "clear"
	var roll := _even(index / corr, corr, "sky") * rest
	for s: String in ORDER:
		roll -= float(odds.get(s, 0))
		if roll <= 0.0:
			pick = s
			break
	var block_hour := fposmod(hour - (unix_time % length) / 3600.0, 24.0) # local hour when the block began
	var span := Balance.a("weather.fog_hours")
	var from := float(span[0])
	var until := float(span[1])
	if pick in FOGGY_BY and fog > 0.0 and block_hour >= from and block_hour < until:
		# Fog can only form in the morning, so it's likelier then by as much as the day is longer than the morning.
		var chance := fog / total * 24.0 / maxf(until - from, 1.0)
		if _even(index / 2.0, 2.0, "fog") < chance:
			pick = "fog"
	elif pick == "fog":
		pick = "partly_cloudy"
	return pick


## A smooth value in 0..1 along `x` (blocks over the persistence length), the same for the same salt and x.
static func _smooth(x: float, salt: String) -> float:
	var i := int(floor(x))
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_hash01(i, salt), _hash01(i + 1, salt), f)


static func _hash01(n: int, salt: String) -> float:
	# (a string hash alone moves only its low bits between neighbours: mixed here so each block is its own roll)
	var h := (hash(salt) + n * 2654435761) & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0


## `_smooth`, spread evenly over 0..1 (smoothing bunches values at the middle; ranking them against a long
## run of the same noise undoes that, so the odds come out as written).
static func _even(x: float, corr: float, salt: String) -> float:
	var key := "%s|%.2f" % [salt, corr]
	if not _spread.has(key):
		var samples := PackedFloat32Array()
		for k in 4096:
			samples.append(_smooth(k * 0.6180339 + 1000.0, "spread"))
		samples.sort()
		_spread[key] = samples
	var sorted: PackedFloat32Array = _spread[key]
	return float(sorted.bsearch(_smooth(x, salt))) / float(sorted.size())


## 0 to 1: how far the block's weather has faded in (it eases in and out over `weather.ease_seconds`).
static func strength_at(unix_time: int) -> float:
	var length := block()
	var into := unix_time % length
	return clampf(minf(into, length - into) / Balance.f("weather.ease_seconds"), 0.0, 1.0)


## The look right now: the block's look blended from clear by its strength.
## {state, name, cover, dim, desat, rain, snow, fog, lightning}
static func current(unix_time: int, season: String, hour: float, override := "") -> Dictionary:
	var state := override if override != "" else state_at(unix_time, season, hour)
	var s := 1.0 if override != "" else strength_at(unix_time)
	var base: Dictionary = LOOKS["clear"]
	var full: Dictionary = LOOKS[state]
	var out := {"state": state, "name": NAMES[state]}
	for k in base:
		out[k] = lerpf(float(base[k]), float(full[k]), s)
	return out
