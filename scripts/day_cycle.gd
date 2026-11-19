class_name DayCycle
extends RefCounted
## Time of day and the colours that go with it. Pure functions, so they're easy to test.
## The season is fixed to summer for now; regional seasons come later.

const SEASON := "Summer"  # not-ui: a season id (ODDS key); shown as tr("SEASON_SUMMER")
const SUNRISE := 5.5   # hours, local time (summer)
const SUNSET := 18.75
const SETTINGS := "graphics"
const ALWAYS_DAY_KEY := "always_day"

## Colour keyframes through the day: hour -> sky top, sky horizon, light on the farm.
## The last entry repeats the first so midnight wraps smoothly.
const KEYS := [
	[0.0,   "#0b1430", "#1d2b55", "#6b78b4"],
	[4.5,   "#141f48", "#3a3f6e", "#7680aa"],
	[5.5,   "#4a6fb0", "#f6a96b", "#e2b08f"],
	[7.0,   "#5fb1e8", "#cfe9f5", "#f4ecdb"],
	[12.0,  "#3fa6ea", "#bfe6fa", "#ffffff"],
	[16.5,  "#4aa3df", "#f3e2b0", "#fff6e6"],
	[18.75, "#5c5fa8", "#ff9a5c", "#f3c4a0"],
	[19.75, "#26305e", "#7a5a8a", "#8d84b2"],
	[21.0,  "#0b1430", "#1d2b55", "#6b78b4"],
	[24.0,  "#0b1430", "#1d2b55", "#6b78b4"],
]

static var _always := -1   # "always daytime": -1 not read yet, 0 off, 1 on


## "Always daytime" (Settings; our own touch): the farm keeps the day's light through the night. Kept in the
## player's settings, read once.
static func always_day() -> bool:
	if _always < 0:
		_always = 1 if bool(PlayerSettings.value(SETTINGS, ALWAYS_DAY_KEY, false)) else 0
	return _always == 1


static func set_always_day(on: bool) -> void:
	_always = 1 if on else 0
	PlayerSettings.keep(SETTINGS, {ALWAYS_DAY_KEY: on})


## The hour the farm is lit for: the real one, or with "always daytime" held inside the day's light (the evening
## stays at its golden end until midnight, and the morning starts at its bright one).
static func lit_hour(real_hour: float) -> float:
	if not always_day():
		return real_hour
	var h := fposmod(real_hour, 24.0)
	if h > SUNSET - 0.25:
		return SUNSET - 0.25
	if h < SUNRISE + 0.75:
		return SUNRISE + 0.75
	return h


## The summer hour that looks like local `hour` in `season`: the day's colours are summer's (KEYS, SUNRISE,
## SUNSET), so this season's sunrise and sunset (data/seasons.json `daylight`) are stretched onto summer's; a
## winter evening at 6 pm is dark, a summer one still light (owner, 19 Nov).
static func summer_hour(hour: float, season: String) -> float:
	var sun: Array = Season.data().get("daylight", {}).get(season, [SUNRISE, SUNSET])
	var rise := float(sun[0])
	var fall := float(sun[1])
	var h := fposmod(hour, 24.0)
	if h < rise:
		return h / rise * SUNRISE
	if h < fall:
		return SUNRISE + (h - rise) / (fall - rise) * (SUNSET - SUNRISE)
	return SUNSET + (h - fall) / (24.0 - fall) * (24.0 - SUNSET)


## Local hour of the day (0 to 24) for a unix time, using the device's time zone.
static func local_hour(unix_time: int, bias_minutes: int) -> float:
	var secs := posmod(unix_time + bias_minutes * 60, 86400)
	return secs / 3600.0


static func device_bias_minutes() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))


## {"top", "horizon", "light"} colours and "dark" (0 = full day, 1 = full night) for an hour.
static func sample(hour: float) -> Dictionary:
	var h := fposmod(hour, 24.0)
	for k in KEYS.size() - 1:
		var a: Array = KEYS[k]
		var b: Array = KEYS[k + 1]
		if h >= a[0] and h <= b[0]:
			var t := (h - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			t = t * t * (3.0 - 2.0 * t) # smoothstep, so changes ease in and out
			return {
				"top": Color.html(a[1]).lerp(Color.html(b[1]), t),
				"horizon": Color.html(a[2]).lerp(Color.html(b[2]), t),
				"light": Color.html(a[3]).lerp(Color.html(b[3]), t),
				"dark": darkness(h),
			}
	return {
		"top": Color.html(KEYS[0][1]),
		"horizon": Color.html(KEYS[0][2]),
		"light": Color.html(KEYS[0][3]),
		"dark": 1.0
	}


## 0 in daylight, 1 at night, easing over the hour around sunrise and sunset.
static func darkness(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h >= SUNRISE + 0.75 and h <= SUNSET - 0.25:
		return 0.0
	if h > SUNSET + 1.25 or h < SUNRISE - 0.75:
		return 1.0
	if h < 12.0:
		return clampf((SUNRISE + 0.75 - h) / 1.5, 0.0, 1.0)
	return clampf((h - (SUNSET - 0.25)) / 1.5, 0.0, 1.0)


## Sun's path: 0 at sunrise, 1 at sunset, or -1 when it's below the horizon.
static func sun_progress(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h < SUNRISE or h > SUNSET:
		return -1.0
	return (h - SUNRISE) / (SUNSET - SUNRISE)


## Moon's path across the night: 0 at sunset, 1 at sunrise, or -1 during the day.
static func moon_progress(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	var night_len := 24.0 - SUNSET + SUNRISE
	if h >= SUNSET:
		return (h - SUNSET) / night_len
	if h <= SUNRISE:
		return (h + 24.0 - SUNSET) / night_len
	return -1.0


## "7:42 pm" style clock text.
static func clock_text(hour: float) -> String:
	# Round to the nearest minute so float error never shows 7:41 for 7:42.
	var total := int(round(fposmod(hour, 24.0) * 60.0)) % 1440
	var h := int(total / 60.0)
	var m := total % 60
	var suffix := TranslationServer.translate("CLOCK_AM") if h < 12 else TranslationServer.translate("CLOCK_PM")
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


## Which part of the day it is, for labels and tests.
static func phase_name(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	if h < SUNRISE - 0.75 or h >= SUNSET + 1.25:
		return "night"
	if h < SUNRISE + 1.5:
		return "dawn"
	if h < 11.0:
		return "morning"
	if h < 15.0:
		return "midday"
	if h < SUNSET - 0.5:
		return "afternoon"
	return "dusk"
