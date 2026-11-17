class_name SurfaceWeather
extends Node
## What the weather leaves on the farm's surfaces. Rain wets everything (darker, glossier, puddles in the
## hollows) and wetness lingers after it stops; snow settles on what faces up and melts slowly. The shaders
## read global values, `wetness` and `snow_cover` (0..1), eased here toward what the weather asks, so a
## shower darkens the farm over half a minute and a snowfall whitens it over a minute: never a jump. `rain`
## (0..1) is how hard it rains this moment: the rings on every water (shaders/water3d.gdshader).

const WET_RISE := 1.0 / 30.0      # per second while it rains
const WET_FALL := 1.0 / 150.0     # and drying out afterwards
const SNOW_RISE := 1.0 / 60.0
const SNOW_MELT := 1.0 / 120.0
const RAIN_FOR_FULL := 0.7        # a rain level (Weather's "rain") that soaks everything
const SNOW_FOR_FULL := 0.7
const RAIN_EASE := 1.0 / 4.0       # how fast the rain on the water comes on and lets up, per second
const MIN_CHANGE := 0.002         # globals are only set when they moved this much

var wet := 0.0
var snow := 0.0
var rain := 0.0                   # how hard it rains now, 0..1 (the rings on every water)
var _sent_wet := -1.0
var _sent_snow := -1.0
var _sent_rain := -1.0


func _process(delta: float) -> void:
	advance(Game.weather(), delta)


## Eases wetness and snow toward `weather` (the Weather dictionary) over `delta` seconds, and tells the shaders.
func advance(weather: Dictionary, delta: float) -> void:
	wet = ease_toward(wet, minf(float(weather.get("rain", 0.0)) / RAIN_FOR_FULL, 1.0), delta, WET_RISE, WET_FALL)
	snow = ease_toward(snow, minf(float(weather.get("snow", 0.0)) / SNOW_FOR_FULL, 1.0), delta, SNOW_RISE, SNOW_MELT)
	if absf(wet - _sent_wet) > MIN_CHANGE:
		_sent_wet = wet
		ShaderGlobals.set_value(&"wetness", wet)
	if absf(snow - _sent_snow) > MIN_CHANGE:
		_sent_snow = snow
		ShaderGlobals.set_value(&"snow_cover", snow)
	rain = ease_toward(rain, minf(float(weather.get("rain", 0.0)) / RAIN_FOR_FULL, 1.0), delta, RAIN_EASE, RAIN_EASE)
	if absf(rain - _sent_rain) > MIN_CHANGE:
		_sent_rain = rain
		ShaderGlobals.set_value(&"rain", rain)


## `current` moved toward `target` at `rise` per second going up, `fall` going down.
static func ease_toward(current: float, target: float, delta: float, rise: float, fall: float) -> float:
	if target > current:
		return minf(current + rise * delta, target)
	return maxf(current - fall * delta, target)
