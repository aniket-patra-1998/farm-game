class_name WeatherEvents
extends Node
## What the weather does, moment to moment (docs/WEATHER.md, data/weather.json; our own touch): lightning in a
## storm and the thunder after it, and the sound of rain. Main sets `look` (Weather.current) every frame. A
## strike is told once (`struck`: how far out, 0 near..1 far, and which way round the farm) and everything that
## shows it listens: the 3D bolt and its flash (Farm3D), the screen flash (WeatherLayer); the thunder follows
## after the delay its distance gives, near ones a crack (and a tick in the hand), far ones a long rumble.
## Strikes come more often the stronger the storm; nothing on the farm is ever struck.

signal struck(far: float, toward: float)

const DATA := "res://data/weather.json"
const NEAR_UP_TO := 0.3   # a strike this far out (0..1) is near: a crack; further, a rumble
const MID_UP_TO := 0.65

static var _rules: Dictionary = {}

var look := {}
var _next := 0.0          # seconds to the next strike (while the storm lasts)
var _rain: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_next = _gap(1.0)


## A section of data/weather.json (storm, fog, rain_sound).
static func data(section: String) -> Dictionary:
	if _rules.is_empty():
		_rules = DataFile.read(DATA)
	return _rules.get(section, {})


## One rule of data/weather.json.
static func rule(section: String, key: String) -> Variant:
	return data(section).get(key)


func _process(delta: float) -> void:
	_rain_sound(float(look.get("rain", 0.0)))
	var lightning := float(look.get("lightning", 0.0))
	if lightning <= 0.0:
		_next = maxf(_next, _gap(1.0))
		return
	_next -= delta * lightning   # (a storm easing in or out strikes less often)
	if _next <= 0.0:
		_next = _gap(lightning)
		strike()


## One strike now: near or far (data's share), which way round the farm, then thunder after its delay.
func strike(far := -1.0) -> void:
	var near := _rng.randf() < float(rule("storm", "near_share"))
	var how_far := far if far >= 0.0 else (_rng.randf_range(0.0, NEAR_UP_TO) if near else _rng.randf_range(0.35, 1.0))
	struck.emit(how_far, _rng.randf() * TAU)
	var delay: Array = rule("storm", "thunder_delay")
	var moment := "thunder_near" if how_far < NEAR_UP_TO else ("thunder_mid" if how_far < MID_UP_TO else "thunder_far")
	get_tree().create_timer(lerpf(float(delay[0]), float(delay[1]), how_far)).timeout.connect(
		func() -> void: Feedback.moment(moment))


## Seconds to the next strike at storm strength `strength` (strikes a minute from data, at random between).
func _gap(strength: float) -> float:
	var rate: Array = rule("storm", "strikes_per_minute")
	var per_minute := _rng.randf_range(float(rate[0]), float(rate[1])) * maxf(strength, 0.05)
	return 60.0 / maxf(per_minute, 0.01)


## The rain's sound: one loop while it rains, as loud as the rain is heavy; gone when it stops.
func _rain_sound(rain: float) -> void:
	var from := float(rule("rain_sound", "from"))
	if rain < from:
		if _rain != null:
			Sound.stop_loop(_rain)
			_rain = null
		return
	if _rain == null:
		_rain = Feedback.hum("rain")
		if _rain == null:
			return
		_rain.set_meta(&"base_db", _rain.volume_db)
	var least := float(rule("rain_sound", "least_db"))
	_rain.volume_db = float(_rain.get_meta(&"base_db")) + lerpf(least, 0.0, clampf(rain, 0.0, 1.0))
