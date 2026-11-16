extends Node
## The game's polish in one place, autoloaded as `Feedback`: what each moment sounds and feels like, and the
## colour of each kind of floating number or word. All of it is data (data/feedback.json), so tuning the feel
## of the game is editing one file, and a test checks that everything the code asks for is there. Code asks by
## name: `Feedback.moment("place")` plays the sound and the vibration of that moment; `Feedback.color("coins")` is
## the colour of a coin gain. Volume, mute and vibration stay the player's (Sound).

const DATA := "res://data/feedback.json"

var _moments := {}
var _floats := {}
var _hums := {}
var _rarities := {}


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_moments = data.get("moments", {})
	_hums = data.get("hums", {})
	_rarities = data.get("rarities", {})
	for style: String in data.get("floats", {}):
		_floats[style] = Color(str(data["floats"][style]))


## The sound and the buzz of a moment (either may be missing from it). `step` is how far into a run of the same
## moment this one is (a swipe's plots, a streak of harvests): each step plays a note higher up the scale
## (Balance `feel.run_scale`, in semitones), and past its end the top note holds.
func moment(name: String, step := 0) -> void:
	var m: Dictionary = _moments.get(name, {})
	if m.is_empty():
		push_warning("Feedback: no moment called %s" % name)
		return
	var sound := str(m.get("sound", ""))
	if sound != "":
		Sound.play(sound, float(m.get("gain_db", 0.0)), pitch_of(step))
	var ms := int(m.get("buzz", 0))
	if ms > 0:
		Sound.buzz(ms)


## How much higher the note `step` steps into a run plays (1.0 for the first).
static func pitch_of(step: int) -> float:
	if step <= 0:
		return 1.0
	var scale := Balance.a("feel.run_scale")
	if scale.is_empty():
		return 1.0
	return pow(2.0, float(scale[mini(step, scale.size() - 1)]) / 12.0)


## A sound that hums for as long as something goes on (an engine): start it, drive its pitch_scale and volume_db,
## and hand it to `Sound.stop_loop`. Null when it can't start (too many humming, or an unknown name).
func hum(name: String) -> AudioStreamPlayer:
	var h: Dictionary = _hums.get(name, {})
	if h.is_empty():
		push_warning("Feedback: no hum called %s" % name)
		return null
	return Sound.start_loop(str(h.get("sound", "")), float(h.get("gain_db", 0.0)))


func has_hum(name: String) -> bool:
	return _hums.has(name)


func hums() -> Dictionary:
	return _hums


func has_moment(name: String) -> bool:
	return _moments.has(name)


func moments() -> Dictionary:
	return _moments


## The colour of a kind of floating text ("coins", "xp", "cost", ...); white for one that isn't there.
func color(style: String) -> Color:
	if not _floats.has(style):
		push_warning("Feedback: no float style called %s" % style)
		return Color.WHITE
	return _floats[style]


## The one look and sound of a find by how rare it is ("common", "uncommon", "rare", "legendary"; anything else
## is common): {color, moment, sparks, reach, size, words, hold}. Every find uses it, so a colour always means
## the same rarity: in the field's glints, the burst when it is found, and what a mystery item opens to.
func rarity(name: String) -> Dictionary:
	var look: Dictionary = _rarities.get(name, _rarities.get("common", {}))
	var out := look.duplicate()
	out["color"] = Color(str(look.get("color", "#ffffff")))
	return out


func rarities() -> Array:
	return _rarities.keys()


func has_float(style: String) -> bool:
	return _floats.has(style)


func floats() -> Dictionary:
	return _floats
