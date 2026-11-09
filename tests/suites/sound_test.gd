extends TestSuite
## Sound and touch feedback: every sound builds into clean audio, every sound the game asks for exists,
## every animal has a voice, and the player's settings are kept.

const SCAN_DIRS := ["res://scripts", "res://autoload"]


func test_98_every_sound_builds_clean_and_every_animal_has_a_voice() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sound.DATA))
	var sounds: Dictionary = data["sounds"]
	for event: String in sounds:
		var r: Dictionary = sounds[event]
		if r.has("file"):
			_check(ResourceLoader.exists(str(r["file"])), "%s: its recording exists" % event)
			continue
		var wav := Sound.synthesize(r)
		var samples := wav.data.size() / 2
		var peak := 0
		var energy := 0.0
		for i in samples:
			var v := absi(wav.data.decode_s16(i * 2))
			peak = maxi(peak, v)
			energy += float(v) * v
		var rms := sqrt(energy / maxf(samples, 1.0)) / 32767.0
		_check(samples > Sound.MIX_RATE * 0.03, "%s lasts long enough to hear (%d samples)" % [event, samples])
		_check(samples < Sound.MIX_RATE * 2.0, "%s is a short effect, not a track" % event)
		_check(peak < 32767, "%s never clips (peak %d)" % [event, peak])
		_check(rms > 0.02, "%s is audible (rms %.3f)" % [event, rms])
		# Starts and ends at silence, so it never clicks.
		_check(absi(wav.data.decode_s16(0)) < 2000, "%s starts quietly" % event)
		_check(absi(wav.data.decode_s16((samples - 1) * 2)) < 2000, "%s ends quietly" % event)
	# The same recipe always builds the same sound (noise is seeded), so tests and players hear one thing.
	_eq(Sound.synthesize(sounds["plow"]).data, Sound.synthesize(sounds["plow"]).data, "a sound builds the same each time")
	# Every animal family in the game has a voice, and the voice is a sound that exists.
	var voices: Dictionary = data["voices"]
	for family in AnimalRig.families():
		_check(voices.has(family), "the %s has a voice" % family)
		_check(sounds.has(str(voices.get(family, ""))), "the %s's voice is a real sound" % family)


func test_99_every_sound_the_game_plays_exists() -> void:
	var asked := {}
	var re := RegEx.create_from_string("(?:Sound\\.play|_feel)\\(\"([a-z_]+)\"")
	for dir in SCAN_DIRS:
		for path in _scripts_in(dir):
			for m in re.search_all(FileAccess.get_file_as_string(path)):
				asked[m.get_string(1)] = path
	_check(asked.size() >= 10, "the game asks for its sounds by name (%d found)" % asked.size())
	for event: String in asked:
		_check(Sound.has_sound(event), "%s (asked for in %s) is in sounds.json" % [event, asked[event]])
	# Sounds are built ahead of time and cached: asking twice gives the same audio.
	var first := Sound.stream_of("harvest")
	_check(first != null and Sound.stream_of("harvest") == first, "a sound is built once and kept")


func test_100_the_players_sound_settings_are_kept() -> void:
	var before := [Sound.volume, Sound.muted, Sound.vibration]
	Sound.volume = 0.35
	Sound.muted = true
	Sound.vibration = false
	_check(not Sound.audible(), "muted, nothing plays")
	var bus := AudioServer.get_bus_index(Sound.BUS)
	_check(bus != -1, "sound effects have their own bus")
	_check(AudioServer.is_bus_mute(bus), "and muting mutes it")
	# Change them in memory only, then read the file back: the saved values return.
	Sound.set("_loading", true)
	Sound.volume = 1.0
	Sound.muted = false
	Sound.vibration = true
	Sound.set("_loading", false)
	Sound.load_settings()
	_check(is_equal_approx(Sound.volume, 0.35), "the volume is remembered (%s)" % Sound.volume)
	_check(Sound.muted, "mute is remembered")
	_check(not Sound.vibration, "vibration off is remembered")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.35)), "the bus follows the volume")
	Sound.muted = false
	_check(Sound.audible() and not AudioServer.is_bus_mute(bus), "unmuted, it plays again")
	Sound.volume = 0.0
	_check(not Sound.audible(), "at zero volume nothing plays")
	Sound.volume = before[0]
	Sound.muted = before[1]
	Sound.vibration = before[2]


func _scripts_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_in(dir.path_join(d)))
	return out
