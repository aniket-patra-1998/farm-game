extends Node
## The game's sound and touch feedback, autoloaded as `Sound`. Every sound is described in data/sounds.json:
## either a recording (a "file") or a synthesis recipe, which is turned into audio once, the first time it
## plays, and kept. Sounds play on their own "SFX" bus through a small pool of voices (the oldest is
## reused when all are busy), each with a slight random pitch so repeats don't sound mechanical.
## `buzz` gives a short vibration on phones. Every button in the game clicks when pressed. Volume, mute
## and vibration are the player's settings, kept in user://settings.cfg.

const DATA := "res://data/sounds.json"
const SETTINGS := "user://settings.cfg"
const MIX_RATE := 22050
const VOICES := 8
const BUS := "SFX"  # not-ui


var volume := 1.0: set = set_volume      # 0..1, the player's sound-effects volume
var muted := false: set = set_muted
var vibration := true: set = set_vibration


var _recipes := {}
var _voices_by_family := {}
var _base_db := 0.0
var _cache := {}                          # event -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _loading := false
var _warm: Array = []                     # sounds still to synthesise ahead of time


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(DATA + " is missing or not valid JSON")
		parsed = {}
	_recipes = parsed.get("sounds", {})
	_voices_by_family = parsed.get("voices", {})
	_base_db = float(parsed.get("volume_db", 0.0))
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")  # not-ui
	for k in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_players.append(p)
	_load_settings()
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


## Plays a sound by its name in data/sounds.json (nothing happens for an unknown name, with a warning).
func play(event: String, gain_db := 0.0) -> void:
	if not audible():
		return
	var stream := stream_of(event)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	var jitter := float((_recipes.get(event, {}) as Dictionary).get("pitch_jitter", 0.05))
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	p.volume_db = _base_db + gain_db
	p.play()


## An animal's voice, by its family (a cow moos, a hen clucks).
func voice(family: String) -> void:
	var event := str(_voices_by_family.get(family, ""))
	if event != "":
		play(event, -2.0)


## A short vibration (phones only), if the player has vibration on.
func buzz(ms := 12) -> void:
	if vibration:
		Input.vibrate_handheld(ms)


func audible() -> bool:
	return volume > 0.0 and not muted


func has_sound(event: String) -> bool:
	return _recipes.has(event)


## The audio for an event: its recording, or its recipe synthesised (once, then cached).
func stream_of(event: String) -> AudioStream:
	if _cache.has(event):
		return _cache[event]
	var r: Dictionary = _recipes.get(event, {})
	if r.is_empty():
		push_warning("no sound called " + event)
		return null
	var stream: AudioStream
	if r.has("file"):
		stream = load(str(r["file"])) as AudioStream
	else:
		stream = synthesize(r)
	_cache[event] = stream
	return stream


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
	var n := int(total * MIX_RATE) + 1
	var mix := PackedFloat32Array()
	mix.resize(n)
	for k in count:
		var start := int((length + gap) * k * MIX_RATE)
		for l: Dictionary in layers:
			_render_layer(l, mix, start)
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
	return wav


static func _render_layer(l: Dictionary, mix: PackedFloat32Array, start: int) -> void:
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
		var env := minf(t / attack, 1.0) * minf((dur - t) / release, 1.0)
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


func _apply_bus() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus != -1:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
		AudioServer.set_bus_mute(bus, not audible())


## Reads the player's settings back (the defaults when there are none yet).
func load_settings() -> void:
	_load_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	_loading = true
	volume = float(cfg.get_value("sound", "volume", 1.0))
	muted = bool(cfg.get_value("sound", "muted", false))
	vibration = bool(cfg.get_value("sound", "vibration", true))
	_loading = false


func _save_settings() -> void:
	if _loading or not is_inside_tree():
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("sound", "volume", volume)
	cfg.set_value("sound", "muted", muted)
	cfg.set_value("sound", "vibration", vibration)
	cfg.save(SETTINGS)
