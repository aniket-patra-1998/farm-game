class_name Weather
extends RefCounted
## The weather: one state per 3-hour block, picked from the date so it's the same every time you look,
## easing in and out at the edges of each block. Pure functions, so they're easy to test.
## Looks only for now (FarmVille had no weather); gameplay effects can hang off state() later.

const BLOCK := 10800          # seconds per weather block (3 hours)
const EASE := 1200            # seconds to fade between blocks (20 minutes)
const STATES := ["clear", "partly_cloudy", "cloudy", "rain", "storm", "fog", "snow"]
const NAMES := {"clear": "Sunny", "partly_cloudy": "Partly cloudy", "cloudy": "Cloudy", "rain": "Rain",
	"storm": "Storm", "fog": "Fog", "snow": "Snow"}
## How often each state comes up, by season. Fog only in the early morning, snow only in winter.
const ODDS := {
	"Summer": {"clear": 46, "partly_cloudy": 26, "cloudy": 11, "rain": 9, "storm": 3, "fog": 5},
	"Spring": {"clear": 34, "partly_cloudy": 26, "cloudy": 14, "rain": 16, "storm": 4, "fog": 6},
	"Autumn": {"clear": 30, "partly_cloudy": 24, "cloudy": 18, "rain": 16, "storm": 3, "fog": 9},
	"Winter": {"clear": 28, "partly_cloudy": 20, "cloudy": 20, "rain": 4, "fog": 8, "snow": 20},
}
## What each state does to the picture, at full strength.
const LOOKS := {
	"clear":         {"cover": 0.10, "dim": 0.00, "desat": 0.00, "rain": 0.0, "snow": 0.0, "fog": 0.0, "lightning": 0.0},
	"partly_cloudy": {"cover": 0.40, "dim": 0.04, "desat": 0.05, "rain": 0.0, "snow": 0.0, "fog": 0.0, "lightning": 0.0},
	"cloudy":        {"cover": 0.80, "dim": 0.14, "desat": 0.22, "rain": 0.0, "snow": 0.0, "fog": 0.0, "lightning": 0.0},
	"rain":          {"cover": 0.95, "dim": 0.22, "desat": 0.30, "rain": 0.7, "snow": 0.0, "fog": 0.10, "lightning": 0.0},
	"storm":         {"cover": 1.00, "dim": 0.38, "desat": 0.40, "rain": 1.0, "snow": 0.0, "fog": 0.15, "lightning": 1.0},
	"fog":           {"cover": 0.60, "dim": 0.08, "desat": 0.30, "rain": 0.0, "snow": 0.0, "fog": 0.75, "lightning": 0.0},
	"snow":          {"cover": 0.85, "dim": 0.06, "desat": 0.25, "rain": 0.0, "snow": 0.8, "fog": 0.15, "lightning": 0.0},
}


## The state for the block holding this time (hour = local hour, for the fog rule).
static func state_at(unix_time: int, season: String, hour: float) -> String:
	var block := int(floor(unix_time / float(BLOCK)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("weather-%d" % block)
	var odds: Dictionary = ODDS.get(season, ODDS["Summer"])
	var total := 0
	for s in odds:
		total += int(odds[s])
	var roll := rng.randi_range(1, total)
	var pick := "clear"
	for s in odds:
		roll -= int(odds[s])
		if roll <= 0:
			pick = s
			break
	var block_hour := fposmod(hour - (unix_time % BLOCK) / 3600.0, 24.0) # local hour when the block began
	if pick == "fog" and not (block_hour >= 3.0 and block_hour < 9.0):
		pick = "partly_cloudy"
	return pick


## 0 to 1: how far the block's weather has faded in (it eases in and out over EASE seconds).
static func strength_at(unix_time: int) -> float:
	var into := unix_time % BLOCK
	return clampf(minf(into, BLOCK - into) / float(EASE), 0.0, 1.0)


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
