extends Node
## The game's sound and touch feedback, autoloaded as `Sound`. Every sound is described in data/sounds.json:
## either a recording (a "file", or takes of one: "files", a different take each time) or a synthesis recipe,
## which is turned into audio once, the first time it plays, and kept. Sounds play on their own "SFX" bus
## through a small pool of voices (the oldest is reused when all are busy), each with a slight random pitch so
## repeats don't sound mechanical.
## `buzz` gives a short vibration on phones. Every button in the game clicks when pressed. Animals answer a tap
## with their family's call (`voice`: a baby with its own, or the adult's higher), never more than one call per
## VOICE_GAP_MS each. The farm's background sound and music are its `Soundscape` (data/soundscape.json), on
## the "Ambience" and "Music" buses. Effects, ambience and music volumes, mute (all three) and vibration are the
## player's settings, kept in user://settings.cfg.

const DATA := "res://data/sounds.json"
const MIX_RATE := 22050
const VOICES := 8
const MAX_LOOPS := 3   # engines humming at once; a fourth stays silent (an "always" loop, the rain, never)
const BUS := "SFX"  # not-ui
const AMBIENCE_BUS := "Ambience"  # not-ui
const MUSIC_BUS := "Music"  # not-ui
const VOICE_GAP_MS := 700   # an animal tapped again sooner stays quiet (tapping fast never machine-guns a moo)
const YOUNG_PITCH := 1.3    # a baby without a call of its own uses the adult's, this much higher


var volume := 1.0: set = set_volume      # 0..1, the player's sound-effects volume
var muted := false: set = set_muted
var vibration := true: set = set_vibration
var ambience_volume := 0.8: set = set_ambience_volume   # 0..1, the farm's background sound
var music_volume := 0.6: set = set_music_volume         # 0..1
var soundscape: Soundscape


var _recipes := {}
var _voices_by_family := {}
var _young_voices := {}
var _voice_pitch := {}
var _voiced_at := {}                      # family (and young) -> when it last called, in ms
var _last_take := {}                      # event -> the take played last
var _base_db := 0.0
var _cache := {}                          # event -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _loops: Array[AudioStreamPlayer] = []
var _loading := false
var _warm: Array = []                     # sounds still to synthesise ahead of time


func _ready() -> void:
	var parsed := DataFile.read(DATA)
	_recipes = parsed.get("sounds", {})
	_voices_by_family = parsed.get("voices", {})
	_young_voices = parsed.get("young_voices", {})
	_voice_pitch = parsed.get("voice_pitch", {})
	_base_db = float(parsed.get("volume_db", 0.0))
	for bus: String in [BUS, AMBIENCE_BUS, MUSIC_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")  # not-ui
	for k in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_players.append(p)
	_load_settings()
	_apply_bus()
	soundscape = Soundscape.new()
	add_child(soundscape)
	get_tree().node_added.connect(_on_node_added)
	_warm = _recipes.keys()


## Synthesises one not-yet-built sound a frame after start, so no tap ever waits for its sound.
func _process(_delta: float) -> void:
	if _warm.is_empty():
		set_process(false)
		return
	stream_of(str(_warm.pop_back()))


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(play.bind("tap", 0.0))


## Plays a sound by its name in data/sounds.json (nothing happens for an unknown name, with a warning). `pitch`
## raises or lowers it (2.0: an octave up), for a run of the same sound that climbs (Feedback.moment's `step`).
func play(event: String, gain_db := 0.0, pitch := 1.0) -> void:
	if not audible():
		return
	var stream := _take_of(event)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	var jitter := float((_recipes.get(event, {}) as Dictionary).get("pitch_jitter", 0.05))
	p.stream = stream
	p.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	p.volume_db = _base_db + gain_db + float((_recipes.get(event, {}) as Dictionary).get("gain_db", 0.0))
	p.play()


## Starts a looping sound (a recipe with `"loop": true`) on a player of its own and returns it, so the caller can
## change its pitch and volume as things change and hand it back to `stop_loop`. Null for an unknown name or when
## MAX_LOOPS are already humming. Mute and volume are the bus's, so they still apply.
func start_loop(event: String, gain_db := 0.0) -> AudioStreamPlayer:
	var stream := stream_of(event)
	var always := bool((_recipes.get(event, {}) as Dictionary).get("always", false))
	if stream == null or (_capped_loops() >= MAX_LOOPS and not always):
		return null
	var p := AudioStreamPlayer.new()
	p.bus = str((_recipes.get(event, {}) as Dictionary).get("bus", BUS))
	p.stream = stream
	p.volume_db = _base_db + gain_db
	add_child(p)
	p.play()
	_loops.append(p)
	if always:
		p.set_meta(&"always", true)   # (the rain and the like never take an engine's place under MAX_LOOPS)
	return p


## The loops counted under MAX_LOOPS: the engines, not the "always" ones (in a storm a tractor still hums).
func _capped_loops() -> int:
	return _loops.filter(func(p: AudioStreamPlayer) -> bool:
		return is_instance_valid(p) and not p.has_meta(&"always")).size()


## Before quitting, a few frames ahead (Game's close, the test runner, the screenshots): every sound stopped and
## let go of (the soundscape, the loops, the pool's players, the cached streams). The audio thread drops a stopped
## sound only on its next pass, so stopping at exit is too late: a track still playing is left loaded and the
## engine reports it in use. Done again on exit, in case.
func silence() -> void:
	if soundscape != null:
		soundscape.release()
	for p in _loops.duplicate():
		stop_loop(p)
	for p in _players:
		p.stop()
		p.stream = null
	_cache.clear()


func _exit_tree() -> void:
	silence()


func stop_loop(p: AudioStreamPlayer) -> void:
	if p == null:
		return
	_loops.erase(p)
	if is_instance_valid(p):
		p.queue_free()


## The loops humming that count under MAX_LOOPS (the "always" ones, the rain, are not counted).
func loops_running() -> int:
	return _capped_loops()


## An animal's call, by its family (a cow moos, a hen clucks); `young`: a baby's (a calf's own, or the adult's
## higher); `item_id` may have a pitch of its own (voice_pitch), else the family's. Quiet when this family (and
## age) called within VOICE_GAP_MS.
func voice(family: String, young := false, item_id := "") -> void:
	var key := family + ("+young" if young else "")  # not-ui
	var now := Time.get_ticks_msec()
	if _voiced_at.has(key) and now - int(_voiced_at[key]) < VOICE_GAP_MS:
		return
	var event := str(_young_voices.get(family, "")) if young else ""
	var pitch := 1.0
	if event == "":
		event = str(_voices_by_family.get(family, ""))
		pitch = YOUNG_PITCH if young else 1.0
	if event == "":
		return
	_voiced_at[key] = now
	pitch *= float(_voice_pitch.get(item_id, _voice_pitch.get(family, 1.0)))
	play(event, -2.0, pitch)


## A short vibration (phones only), if the player has vibration on.
func buzz(ms := 12) -> void:
	if vibration:
		Input.vibrate_handheld(ms)


func audible() -> bool:
	return volume > 0.0 and not muted


func has_sound(event: String) -> bool:
	return _recipes.has(event)


## The takes of an event with recordings in takes ("files"), each loaded once.
func takes_of(event: String) -> Array:
	var key := event + "#takes"  # not-ui
	if not _cache.has(key):
		var list: Array = []
		for path: String in (_recipes.get(event, {}) as Dictionary).get("files", []):
			list.append(load(path) as AudioStream)
		_cache[key] = list
	return _cache[key]


## What to play for an event now: one of its takes (never the one just played, when it has more), or its sound.
func _take_of(event: String) -> AudioStream:
	if not (_recipes.get(event, {}) as Dictionary).has("files"):
		return stream_of(event)
	var takes := takes_of(event)
	if takes.is_empty():
		return null
	var k := randi() % takes.size()
	if takes.size() > 1 and k == int(_last_take.get(event, -1)):
		k = (k + 1) % takes.size()
	_last_take[event] = k
	return takes[k]


## The audio for an event: its recording (its first take), or its recipe synthesised (once, then cached).
func stream_of(event: String) -> AudioStream:
	if _cache.has(event):
		return _cache[event]
	var r: Dictionary = _recipes.get(event, {})
	if r.is_empty():
		push_warning("no sound called " + event)
		return null
	if r.has("files"):
		var takes := takes_of(event)
		_cache[event] = takes[0] if not takes.is_empty() else null
		return _cache[event]
	var stream: AudioStream
	if r.has("file"):
		stream = load(str(r["file"])) as AudioStream
		if stream is AudioStreamOggVorbis and r.get("loop", false):
			(stream as AudioStreamOggVorbis).loop = true
	elif ResourceLoader.exists(baked_path(event, r)):
		stream = load(baked_path(event, r)) as AudioStream   # made ahead of time, in the game (bake_all)
	else:
		stream = synthesize(r)
	_cache[event] = stream
	return stream


## Where a recipe's sound is kept in the game, made ahead of time by CI (`bake_all`): its name and its recipe's
## hash, so a changed recipe is never played from an old file.
static func baked_path(event: String, r: Dictionary) -> String:
	return "%s/sounds/%s-%x.res" % [ModelStore.SHIPPED, event, hash(r)]


## Makes every recipe's sound and keeps it in the game (CI, before the phone build: no sound is made on a phone).
func bake_all() -> int:
	DirAccess.make_dir_recursive_absolute(ModelStore.SHIPPED + "/sounds")
	var made := 0
	for event: String in _recipes:
		var r: Dictionary = _recipes[event]
		if not r.has("file") and not r.has("files") and ResourceSaver.save(synthesize(r), baked_path(event, r)) == OK:
			made += 1
	return made


## Builds a sound from its recipe: each layer rendered and mixed, the whole repeated if asked, then
## soft-limited so layers adding up never clip.
static func synthesize(r: Dictionary) -> AudioStreamWAV:
	var layers: Array = r.get("layers", [])
	var length := 0.0
	for l: Dictionary in layers:
		length = maxf(length, float(l.get("delay", 0.0)) + float(l.get("dur", 0.1)))
	var rep: Array = r.get("repeat", [1, 0.0])
	var count := maxi(1, int(rep[0]))
	var gap := float(rep[1])
	var total := length * count + gap * (count - 1)
	var looping := bool(r.get("loop", false))
	var n := int(total * MIX_RATE) + (0 if looping else 1)   # a loop is whole samples: its end meets its start
	var mix := PackedFloat32Array()
	mix.resize(n)
	for k in count:
		var start := int((length + gap) * k * MIX_RATE)
		for l: Dictionary in layers:
			_render_layer(l, mix, start, looping)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := tanh(mix[i] * 1.2) * 0.9
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav


static func _render_layer(l: Dictionary, mix: PackedFloat32Array, start: int, looping := false) -> void:
	var wave := str(l.get("wave", "sine"))
	var f0 := float(l.get("freq", 440.0))
	var f1 := float(l.get("freq_end", f0))
	var dur := float(l.get("dur", 0.1))
	var attack := maxf(float(l.get("attack", 0.005)), 0.0005)
	var release := maxf(float(l.get("release", 0.05)), 0.0005)
	var gain := float(l.get("gain", 0.5))
	var vib: Array = l.get("vibrato", [0.0, 0.0])
	var trem: Array = l.get("tremolo", [0.0, 0.0])
	var cutoff := float(l.get("lowpass", 0.0))
	var alpha := 1.0 - exp(-TAU * cutoff / MIX_RATE) if cutoff > 0.0 else 1.0
	var first := start + int(float(l.get("delay", 0.0)) * MIX_RATE)
	var samples := int(dur * MIX_RATE)
	var phase := 0.0
	var low := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(l)
	for i in samples:
		var at := first + i
		if at >= mix.size():
			break
		var t := float(i) / MIX_RATE
		var u := t / dur
		var f := lerpf(f0, f1, u) * (1.0 + float(vib[1]) * sin(TAU * float(vib[0]) * t))
		phase = fposmod(phase + f / MIX_RATE, 1.0)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if phase < 0.5 else -1.0
			"saw":
				s = phase * 2.0 - 1.0
			"triangle":
				s = 1.0 - 4.0 * absf(phase - 0.5)
			"noise":
				s = rng.randf_range(-1.0, 1.0)
			_:
				s = sin(TAU * phase)
		low += alpha * (s - low)
		var env := 1.0 if looping else minf(t / attack, 1.0) * minf((dur - t) / release, 1.0)
		var am := 1.0 - float(trem[1]) * (0.5 + 0.5 * sin(TAU * float(trem[0]) * t))
		mix[at] += low * env * am * gain


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply_bus()
	_save_settings()


func set_muted(on: bool) -> void:
	muted = on
	_apply_bus()
	_save_settings()


func set_vibration(on: bool) -> void:
	vibration = on
	_save_settings()


func set_ambience_volume(v: float) -> void:
	ambience_volume = clampf(v, 0.0, 1.0)
	_apply_bus()
	_save_settings()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus()
	_save_settings()


## Each bus at its own volume; mute silences all three.
func _apply_bus() -> void:
	for pair: Array in [[BUS, volume], [AMBIENCE_BUS, ambience_volume], [MUSIC_BUS, music_volume]]:
		var bus := AudioServer.get_bus_index(str(pair[0]))
		if bus != -1:
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(pair[1]), 0.0001)))
			AudioServer.set_bus_mute(bus, muted or float(pair[1]) <= 0.0)


## Reads the player's settings back (the defaults when there are none yet).
func load_settings() -> void:
	_load_settings()


func _load_settings() -> void:
	_loading = true
	volume = float(PlayerSettings.value("sound", "volume", 1.0))
	muted = bool(PlayerSettings.value("sound", "muted", false))
	vibration = bool(PlayerSettings.value("sound", "vibration", true))
	ambience_volume = float(PlayerSettings.value("sound", "ambience", 0.8))
	music_volume = float(PlayerSettings.value("sound", "music", 0.6))
	_loading = false


func _save_settings() -> void:
	if _loading or not is_inside_tree():
		return
	PlayerSettings.keep("sound", {"volume": volume, "muted": muted, "vibration": vibration,
		"ambience": ambience_volume, "music": music_volume})
