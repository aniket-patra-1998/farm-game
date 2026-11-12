extends Node
## The game's polish in one place, autoloaded as `Feedback`: what each moment sounds and feels like, and the
## colour of each kind of floating number or word. All of it is data (data/feedback.json), so tuning the feel
## of the game is editing one file, and a test checks that everything the code asks for is there. Code asks by
## name: `Feedback.moment("place")` plays the sound and the vibration of that moment; `Feedback.color("coins")` is
## the colour of a coin gain. Volume, mute and vibration stay the player's (Sound).

const DATA := "res://data/feedback.json"

var _moments := {}
var _floats := {}


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_moments = data.get("moments", {})
	for style: String in data.get("floats", {}):
		_floats[style] = Color(str(data["floats"][style]))


## The sound and the buzz of a moment (either may be missing from it).
func moment(name: String) -> void:
	var m: Dictionary = _moments.get(name, {})
	if m.is_empty():
		push_warning("Feedback: no moment called %s" % name)
		return
	var sound := str(m.get("sound", ""))
	if sound != "":
		Sound.play(sound, float(m.get("gain_db", 0.0)))
	var ms := int(m.get("buzz", 0))
	if ms > 0:
		Sound.buzz(ms)


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


func has_float(style: String) -> bool:
	return _floats.has(style)


func floats() -> Dictionary:
	return _floats
