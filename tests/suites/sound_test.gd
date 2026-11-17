extends TestSuite

const SHORT_SECONDS := 2.0   # an effect's longest
const LONG_SECONDS := 5.0    # a recipe marked "long" (thunder)
const SOUND_ART := "res://art/sound"
const SOURCES := "res://art/sound/SOURCES.md"
const LEVELS := "res://data/sound_levels.json"   # every file's measures (tools/sound_cuts/audit.py --write)
const CALLS_SPREAD_DB := 2.0    # every call within this of the calls' middle, as a phone plays them
const CALLS_FULL_OVER_DB := 4.0 # and on full-range speakers no call this far over the calls' middle
const BEDS_SPREAD_DB := 1.5     # the farm's beds within this of each other
const PEAK_MOST_DB := -0.5      # no file touches full scale
const VOICE_GAIN_DB := -2.0     # Sound.voice plays a call this much under the base
const DEFAULT_AMBIENCE := 0.8   # Sound.ambience_volume before the player moves it
const DEFAULT_MUSIC := 0.6      # Sound.music_volume
const BED_UNDER_DB := 10.0
const MUSIC_UNDER_DB := 8.0
const RAIN_UNDER_CALL_DB := Vector2(2.0, 8.0)   # the heaviest rain this far under a call, least and most
const RAIN_OVER_DB := 8.0                       # the bed and the music this far under half the rain
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
		if r.has("files"):
			_check(not (r["files"] as Array).is_empty(), "%s has at least one take" % event)
			for path: String in r["files"]:
				_check(ResourceLoader.exists(path), "%s: its take %s exists" % [event, path])
			for take: AudioStream in Sound.takes_of(event):
				var length := take.get_length() if take != null else 0.0
				_check(length > 0.1 and length < 4.0, "%s: a take is a short call, not a track (%.2fs)" % [event, length])
			continue
		if r.get("loop", false):
			_loop_checks(event, r)
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
		# (an effect is short; a sound of the sky, "long": thunder rolling, may run a few seconds)
		var most := LONG_SECONDS if r.get("long", false) else SHORT_SECONDS
		_check(samples < Sound.MIX_RATE * most, "%s is an effect (under %.0f s), not a track" % [event, most])
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
	for family: String in data.get("young_voices", {}):
		_check(sounds.has(str(data["young_voices"][family])), "the young %s's voice is a real sound" % family)
		_check(AnimalRig.families().has(family), "a young voice is for a family the game has (%s)" % family)
	for key: String in data.get("voice_pitch", {}):
		var pitch := float(data["voice_pitch"][key])
		_check(pitch > 0.5 and pitch < 2.0, "%s's call is shifted, not mangled (%s)" % [key, pitch])


## A loop plays round without a click: it is whole samples, set to loop over all of them, and the step from its
## last sample to its first is no bigger than a step inside it.
func _loop_checks(event: String, r: Dictionary) -> void:
	var wav := Sound.synthesize(r)
	var samples := wav.data.size() / 2
	_check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops" % event)
	_check(wav.loop_end == samples, "%s loops over all of itself" % event)
	var biggest := 0
	var peak := 0
	for i in range(1, samples):
		biggest = maxi(biggest, absi(wav.data.decode_s16(i * 2) - wav.data.decode_s16((i - 1) * 2)))
		peak = maxi(peak, absi(wav.data.decode_s16(i * 2)))
	var seam := absi(wav.data.decode_s16(0) - wav.data.decode_s16((samples - 1) * 2))
	_check(seam <= biggest, "%s: its seam is as smooth as the rest of it (%d vs %d)" % [event, seam, biggest])
	_check(peak < 32767 and peak > 2000, "%s is audible and never clips (peak %d)" % [event, peak])
	_check(samples >= Sound.MIX_RATE / 2 and samples <= Sound.MIX_RATE * 4, "%s is a short bed that repeats" % event)


func test_99_every_sound_asked_for_directly_exists() -> void:
	var asked := {}
	var re := RegEx.create_from_string("Sound\\.play\\(\"([a-z_]+)\"")
	for dir in SCAN_DIRS:
		for path in _scripts_in(dir):
			for m in re.search_all(FileAccess.get_file_as_string(path)):
				asked[m.get_string(1)] = path
	# (The game's moments ask for their sounds through Feedback, checked in feedback_test; what asks directly is
	# checked here, whatever is left of it.)
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
	# The farm's background sound and the music: each its own bus and volume, kept, and silenced by mute.
	var levels := [Sound.ambience_volume, Sound.music_volume]
	Sound.ambience_volume = 0.4
	Sound.music_volume = 0.25
	Sound.set("_loading", true)
	Sound.ambience_volume = 1.0
	Sound.music_volume = 1.0
	Sound.set("_loading", false)
	Sound.load_settings()
	_check(is_equal_approx(Sound.ambience_volume, 0.4), "the farm sounds' volume is remembered")
	_check(is_equal_approx(Sound.music_volume, 0.25), "the music's volume is remembered")
	for name: String in [Sound.AMBIENCE_BUS, Sound.MUSIC_BUS]:
		var b := AudioServer.get_bus_index(name)
		_check(b != -1, "%s has its own bus" % name)
		Sound.muted = true
		_check(AudioServer.is_bus_mute(b), "mute silences %s too" % name)
		Sound.muted = before[1]
	Sound.ambience_volume = levels[0]
	Sound.music_volume = levels[1]


## An animal tapped over and over calls once per VOICE_GAP_MS, not every tap; a baby and its parent each call.
func test_101_animals_call_once_in_a_while_and_babies_have_their_own() -> void:
	Sound.set("_voiced_at", {})
	Sound.voice("cow")
	var first: Dictionary = (Sound.get("_voiced_at") as Dictionary).duplicate()
	Sound.voice("cow")
	_eq(Sound.get("_voiced_at"), first, "a second moo straight after the first stays quiet")
	Sound.voice("cow", true)
	_check((Sound.get("_voiced_at") as Dictionary).has("cow+young"), "a calf calls even while its mother just did")
	_check(Sound.has_sound("moo_young"), "and a calf has its own call")


## The soundscape: every bed is a recording that loops, every part of the day has a bed in every season, the
## weather's loops are beds, and a day keeps its bed while the next may differ.
func test_102_the_farm_always_has_a_background_and_it_follows_the_day() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Soundscape.DATA))
	var beds: Dictionary = data["beds"]
	for name: String in beds:
		_check(ResourceLoader.exists(str(beds[name])), "the %s bed's recording exists" % name)
	var scape := Sound.soundscape
	_check(scape != null, "Sound has a soundscape")
	for phase: String in ["dawn", "morning", "midday", "afternoon", "dusk", "night"]:
		for season: String in ["Spring", "Summer", "Monsoon", "Autumn", "Winter"]:
			var bed := scape.bed_for(phase, season, 3)
			_check(beds.has(bed), "%s in %s has a bed (%s)" % [phase, season, bed])
	_eq(scape.bed_for("midday", "Winter", 7), scape.bed_for("midday", "Winter", 7), "a day keeps its bed")
	_check(scape.bed_for("midday", "Summer", 7) != scape.bed_for("midday", "Summer", 8), "the next day sounds different")
	_check(not scape.bed_for("midday", "Winter", 2).begins_with("summer"), "the summer bed waits for summer")
	for state: String in data["weather"]:
		_check(Weather.STATES.has(state), "the soundscape's %s is a real weather" % state)
	for path: String in (data["music"] as Dictionary).get("tracks", []):
		_check(ResourceLoader.exists(path), "music track %s exists" % path)
	scape.look()
	_check(scape.bed_name == "" or beds.has(scape.bed_name), "looking now picks a real bed")


func _scripts_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_in(dir.path_join(d)))
	return out


## The soundscape follows the sky: the bed goes quieter in the rain and back up when it clears; the farm sounds at
## zero play nothing; the rain is the recording, looping, on the farm sounds' bus; the music has real tracks.
func test_103_the_background_follows_the_weather_and_the_players_volume() -> void:
	var scape := Sound.soundscape
	var before := [Game.weather_override, Sound.ambience_volume]
	Sound.ambience_volume = 0.8
	Game.weather_override = "rain"
	scape.look()
	_check(scape.bed_name != "", "in the rain there is still a bed (%s)" % scape.bed_name)
	var wet := float(scape.get("_bed_db"))
	Game.weather_override = "clear"
	scape.look()
	_check(float(scape.get("_bed_db")) > wet, "the bed is quieter in the rain than under a clear sky")
	Sound.ambience_volume = 0.0
	scape.look()
	_eq(scape.bed_name, "", "with farm sounds at zero nothing plays")
	var rain := Sound.start_loop("rain")
	_check(rain != null and rain.bus == Sound.AMBIENCE_BUS, "the rain plays on the farm sounds' bus")
	_check(rain != null and (rain.stream as AudioStreamOggVorbis).loop, "the rain's recording loops")
	Sound.stop_loop(rain)
	_check(scape.has_music(), "there is music")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Soundscape.DATA))
	for path: String in data["music"]["tracks"]:
		var track := load(path) as AudioStream
		_check(track != null and track.get_length() > 30.0, "%s is a piece of music, not a call" % path)
	Game.weather_override = before[0]
	Sound.ambience_volume = before[1]


## Every sound file can be traced: art/sound/SOURCES.md has a row for it, and the row is either a Freesound page
## (CC0, the licence the whole table is under) or made here. A file with no row, or a row with no source, fails.
func test_104_every_sound_file_says_where_it_came_from() -> void:
	var sources := FileAccess.get_file_as_string(SOURCES)
	_check(sources.contains("creativecommons.org/publicdomain/zero/1.0"), "the recordings' licence is CC0")
	var rows: Array[String] = []
	for line in sources.split("\n"):
		if line.begins_with("| `"):
			rows.append(line)
	var files := _sound_files("")
	_check(files.size() > 20, "the sound files are found (%d)" % files.size())
	for file: String in files:
		var row := ""
		for r in rows:
			if file.match(r.get_slice("`", 1)):
				row = r
		_check(row != "", "%s has a row in SOURCES.md" % file)
		_check(row == "" or row.contains("freesound.org/s/") or row.contains("made here"),
			"%s comes from a Freesound page or was made here" % file)


## Every .ogg under art/sound/ (path relative to it).
func _sound_files(sub: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(SOUND_ART.path_join(sub))
	if dir == null:
		return found
	for name in dir.get_files():
		if name.get_extension() == "ogg":
			found.append(sub.path_join(name) if sub != "" else name)
	for folder in dir.get_directories():
		found.append_array(_sound_files(sub.path_join(folder) if sub != "" else folder))
	return found


## The mix: what plays in the background sits well under what the player does, and in a shower the rain is what
## is heard. From each kind's measured loudness as a phone plays it (data/sound_levels.json), with the game's
## gains and the default volumes: under a clear sky the beds
## sit BED_UNDER_DB or more under a tapped animal's call and the music MUSIC_UNDER_DB or more; while it rains (or
## storms) the rain at its heaviest still lets a call through (RAIN_UNDER_CALL_DB), the bed and the music step back
## under it (RAIN_OVER_DB at half the rain), and even the lightest rain is heard over them.
func test_105_the_background_sits_under_the_calls_and_the_rain_leads_in_a_shower() -> void:
	var sounds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sounds.json"))
	var scape: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Soundscape.DATA))
	var feedback: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/feedback.json"))
	var weather: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weather.json"))
	var base := float(sounds["volume_db"])
	var call := _middle("voices/", "phone_db") + base + VOICE_GAIN_DB
	var bed := _middle("ambience/", "phone_db", "ambience/rain") + float(scape["gain_db"]) + linear_to_db(DEFAULT_AMBIENCE)
	var music := _middle("music/", "phone_db") + float(scape["music"]["gain_db"]) + linear_to_db(DEFAULT_MUSIC)
	_check(call - bed >= BED_UNDER_DB, "under a clear sky the farm's sound sits under a call (%.1f dB)" % (call - bed))
	_check(call - music >= MUSIC_UNDER_DB, "and the music too (%.1f dB under)" % (call - music))
	var rain_file := float(_levels()["ambience/rain.ogg"]["phone_db"])
	var rain := rain_file + base + float(feedback["hums"]["rain"]["gain_db"]) + linear_to_db(DEFAULT_AMBIENCE)
	var rule: Dictionary = weather["rain_sound"]
	var least := float(rule["least_db"])
	var lightest := rain + lerpf(least, 0.0, float(rule["from"]))
	var half := rain + lerpf(least, 0.0, 0.5)
	var under := call - rain
	_check(under >= RAIN_UNDER_CALL_DB.x and under <= RAIN_UNDER_CALL_DB.y,
		"the heaviest rain leads but a call still comes through (%.1f dB under it)" % under)
	_check(bool(sounds["sounds"]["rain"].get("always", false)), "the rain is never refused for engines humming")
	for state: String in ["rain", "storm"]:
		var step: Dictionary = scape["weather"][state]
		var wet_bed := bed + float(step.get("bed_db", 0.0))
		var wet_music := music + float(step.get("music_db", 0.0))
		_check(half - wet_bed >= RAIN_OVER_DB, "in %s the bed steps back under the rain (%.1f dB)" % [state, half - wet_bed])
		_check(half - wet_music >= RAIN_OVER_DB,
			"in %s the music steps back under the rain (%.1f dB)" % [state, half - wet_music])
		_check(lightest > maxf(wet_bed, wet_music), "in %s even the lightest rain is heard over them" % state)


## Every sound file was measured (tools/sound_cuts/audit.py), and the measures are of the file in the repo (its
## sha256); the calls are one loudness on a phone and none booms on full-range speakers, the beds match, and no
## file touches full scale. A file changed without measuring it again fails here.
func test_106_every_sound_was_measured_and_is_in_balance() -> void:
	var levels := _levels()
	for file: String in _sound_files(""):
		var row: Dictionary = levels.get(file, {})
		_check(not row.is_empty(), "%s was measured" % file)
		if row.is_empty():
			continue
		_eq(str(row["sha256"]), FileAccess.get_sha256(SOUND_ART.path_join(file)), "%s's measures are of this file" % file)
		_check(float(row["peak_db"]) <= PEAK_MOST_DB, "%s never touches full scale (%.1f dB)" % [file, row["peak_db"]])
	var calls := _middle("voices/", "phone_db")
	var beds := _middle("ambience/", "phone_db", "ambience/rain")
	for file: String in levels:
		var row: Dictionary = levels[file]
		if file.begins_with("voices/"):
			_check(absf(float(row["phone_db"]) - calls) <= CALLS_SPREAD_DB,
				"%s is as loud as the other calls on a phone (%.1f, the calls %.1f)" % [file, row["phone_db"], calls])
			_check(float(row["full_db"]) - calls <= CALLS_FULL_OVER_DB,
				"%s doesn't boom on headphones (%.1f)" % [file, row["full_db"]])
		elif file.begins_with("ambience/") and not file.begins_with("ambience/rain"):
			_check(absf(float(row["phone_db"]) - beds) <= BEDS_SPREAD_DB, "%s matches the other beds" % file)


## The measures by file (data/sound_levels.json).
func _levels() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LEVELS))
	return (parsed as Dictionary).get("files", {}) if parsed is Dictionary else {}


## The middle (median) of one measure over the files under `under`, leaving out those starting with `but`.
func _middle(under: String, measure: String, but := "") -> float:
	var values: Array[float] = []
	var levels := _levels()
	for file: String in levels:
		if file.begins_with(under) and (but == "" or not file.begins_with(but)):
			values.append(float(levels[file][measure]))
	values.sort()
	return values[int(values.size() / 2.0)] if not values.is_empty() else 0.0


## Quitting lets every sound go: a soundscape released (as on quit) has nothing playing and holds no stream, so the
## engine never finds a background loop or a track still loaded at exit (it did, now and then, before).
func test_107_quitting_lets_the_background_go() -> void:
	var scape := Soundscape.new()
	Sound.add_child(scape)
	scape.look()
	scape.release()
	_eq(scape.bed_name, "", "no bed after release")
	_eq((scape.get("_streams") as Dictionary).size(), 0, "no stream kept")
	for p: AudioStreamPlayer in scape.get("_bed") + [scape.get("_music")]:
		_check(not p.playing and p.stream == null, "a player stopped and empty")
	scape.queue_free()
	Sound.soundscape.look()
