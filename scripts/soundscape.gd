class_name Soundscape
extends Node
## The farm's background sound and music (our own touch: FarmVille 2 let the farm itself be the soundtrack, wind
## and birds; Stardew Valley's music follows the seasons). data/soundscape.json says it all:
## - a bed: one looping recording for the part of the day (birds at dawn, the farmyard by day, crickets at night),
##   chosen among the phase's beds by the day, so each day sounds a little different; a bed can be kept to seasons;
## - the weather: under rain, storm, snow or fog the bed and the music step back (`bed_db`, `music_db`), so in a
##   shower the rain itself is what is heard (WeatherEvents' loop, as loud as it falls, on the Ambience bus);
## - music: tracks played one at a time with a long rest between them, so the farm is heard most of the time.
## Every change cross-fades. It looks again every `check_every` seconds (not each frame). Beds play on the
## "Ambience" bus, music on "Music", each with the player's own volume (Sound), muted with everything else.
## Owned by Sound; `look()` makes it look now (tests).

const DATA := "res://data/soundscape.json"
const SILENT_DB := -60.0
const DAY_SECONDS := 86400

var bed_name := ""        # the bed playing (or fading in) now; "" for none
var track := ""           # the music playing now; "" while resting
var released := false     # let go before quitting: plays nothing more

var _data := {}
var _streams := {}                            # path -> AudioStream, each loaded once
var _bed: Array[AudioStreamPlayer] = []       # two, cross-fading
var _music: AudioStreamPlayer
var _bed_db := 0.0
var _music_db := 0.0                          # the music's level now: its gain, less what the weather takes
var _aimed := {}                              # player -> the level it is fading towards (no fade begun twice)
var _tweens := {}                             # player -> its fade, ended when another begins
var _rest_until := 0.0                        # music rests until this time (seconds since start)
var _since := 0.0


func _ready() -> void:
	_data = DataFile.read(DATA)
	for k in 2:
		_bed.append(_player(Sound.AMBIENCE_BUS))
	_music = _player(Sound.MUSIC_BUS)
	_music.finished.connect(_on_track_done)
	_rest_until = float(_music_data().get("first_after", 20.0))


## Before quitting (Sound.silence, a few frames ahead, so the audio thread lets go too; and again on exit):
## every player stopped and let go of its stream, the fades ended, the loaded streams dropped, and no more looks,
## so nothing is decoding, or held, when the engine shuts down.
func _exit_tree() -> void:
	release()


func release() -> void:
	released = true
	for t: Tween in _tweens.values():
		if t.is_valid():
			t.kill()
	_tweens.clear()
	_aimed.clear()
	for p in _bed + [_music]:
		if p != null:
			p.stop()
			p.stream = null
	_streams.clear()
	bed_name = ""
	track = ""


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _process(delta: float) -> void:
	if released:
		return
	_since += delta
	if fmod(_since, float(_data.get("check_every", 2.0))) < delta:
		look()


## Works out what should be heard now and moves towards it.
func look() -> void:
	var hour := DayCycle.lit_hour(DayCycle.local_hour(Game.now(), DayCycle.device_bias_minutes()))
	var weather: Dictionary = (_data.get("weather", {}) as Dictionary).get(str(Game.weather().get("state", "")), {})
	_bed_db = float(_data.get("gain_db", 0.0)) + float(weather.get("bed_db", 0.0))
	_music_db = float(_music_data().get("gain_db", 0.0)) + float(weather.get("music_db", 0.0))
	var wanted := bed_for(DayCycle.phase_name(hour), Game.season(), int(Game.now() / DAY_SECONDS))
	if Sound.ambience_volume <= 0.0:
		wanted = ""   # nothing to hear: nothing playing, nothing decoding
	_set_bed(wanted)
	_look_music()


## The bed for a part of the day ("dawn", "night"...) in a season on a day: one of the phase's beds that may play in
## that season, the same all day and another the next.
func bed_for(phase: String, season: String, day: int) -> String:
	var allowed: Array = []
	var seasons: Dictionary = _data.get("seasons", {})
	for name: String in (_data.get("phases", {}) as Dictionary).get(phase, []):
		if not seasons.has(name) or (seasons[name] as Array).has(season):
			allowed.append(name)
	return "" if allowed.is_empty() else str(allowed[posmod(day, allowed.size())])


func has_music() -> bool:
	return not (_music_data().get("tracks", []) as Array).is_empty()


func _music_data() -> Dictionary:
	return _data.get("music", {})


func _stream(path: String, loop: bool) -> AudioStream:
	if not _streams.has(path):
		var s := load(path) as AudioStream
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = loop
		_streams[path] = s
	return _streams[path]


func _bed_path(name: String) -> String:
	return str((_data.get("beds", {}) as Dictionary).get(name, ""))


func _fade(p: AudioStreamPlayer, to_db: float, then_stop := false) -> void:
	if is_equal_approx(float(_aimed.get(p, INF)), to_db) and not then_stop:
		return
	_aimed[p] = to_db
	if _tweens.has(p) and (_tweens[p] as Tween).is_valid():
		(_tweens[p] as Tween).kill()
	var t := create_tween()
	_tweens[p] = t
	t.tween_property(p, "volume_db", to_db, float(_data.get("fade", 5.0)))
	if then_stop:
		t.tween_callback(p.stop)


## Cross-fades to another bed (or to none); the same bed only follows the weather's level.
func _set_bed(name: String) -> void:
	if name == bed_name:
		if name != "":
			_fade(_bed[0], _bed_db)
		return
	bed_name = name
	var old := _bed[0]
	_bed.reverse()
	if old.playing:
		_fade(old, SILENT_DB, true)
	if name == "":
		return
	var fresh := _bed[0]
	fresh.stream = _stream(_bed_path(name), true)
	fresh.volume_db = SILENT_DB
	_aimed.erase(fresh)
	fresh.play(randf() * maxf(fresh.stream.get_length() - 1.0, 0.0))   # a loop heard from anywhere in it
	_fade(fresh, _bed_db)


## Music: after its rest, the next track (never the one just heard twice running), faded in; none while the
## player has music at zero.
func _look_music() -> void:
	var tracks: Array = _music_data().get("tracks", [])
	if tracks.is_empty() or Sound.music_volume <= 0.0:
		if _music.playing:
			_fade(_music, SILENT_DB, true)
			track = ""
		return
	if _music.playing:
		_fade(_music, _music_db)   # follows the weather while it plays
		return
	if _since < _rest_until:
		return
	var choices := tracks.filter(func(t: String) -> bool: return t != track or tracks.size() == 1)
	track = str(choices[randi() % choices.size()])
	_music.stream = _stream(track, false)
	_music.volume_db = SILENT_DB
	_aimed.erase(_music)
	_music.play()
	_fade(_music, _music_db)


func _on_track_done() -> void:
	var gap: Array = _music_data().get("gap", [90.0, 240.0])
	_rest_until = _since + randf_range(float(gap[0]), float(gap[1]))
