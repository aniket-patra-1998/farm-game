class_name Analytics
extends Node
## Play statistics (data/analytics.json; owner, 27 Nov: measure real players, as studios do): a few design events
## from the farm's own event stream (Game.did, the verbs listed in the file), level-ups, and each session's start
## and length, sent in batches to GameAnalytics' collector (its REST API: signed HTTPS POSTs, no native plugin).
## Anonymous: a random id kept on the phone. Nothing is sent without keys in the file, or when the player turns
## "Share play statistics" off in Settings (PlayerSettings "privacy"/"stats").

const CONFIG := "res://data/analytics.json"
const ID_FILE := "user://analytics_id.txt"
const HOST := "https://api.gameanalytics.com"
const SANDBOX_HOST := "https://sandbox-api.gameanalytics.com"
const SDK := "rest api v2"   # not-ui
const JSON_TYPE := "Content-Type: application/json"   # not-ui (a header)
const SETTINGS := ["privacy", "stats"]

static var shared: Analytics

var config := {}
var user_id := ""
var session_id := ""
var session_num := 1
var queue: Array[Dictionary] = []
var _started := 0.0
var _sending := false
var _clock: Timer
var _verbs := {}


## Made once by the game (like AssetPacks): reads the file, listens to the farm and starts the session.
static func begin(game: GameState) -> Analytics:
	var a := Analytics.new()
	a.name = "Analytics"   # not-ui (a node name)
	a.config = game.read_json(CONFIG)
	for v: String in a.config.get("events", []):
		a._verbs[v] = true
	shared = a
	game.add_child(a)
	game.did.connect(a._did)
	game.leveled_up.connect(func(level: int) -> void: a.design("level:%d" % level))
	a._start()
	return a


## Whether events go out: keys in the file and the player not opted out.
func on() -> bool:
	return str(config.get("game_key", "")) != "" and str(config.get("secret_key", "")) != "" \
		and bool(PlayerSettings.value(SETTINGS[0], SETTINGS[1], true))


## A design event ("buy:cow", "ad:rescue:taken"), with an optional number.
func design(event_id: String, value := NAN) -> void:
	var e := _base("design")
	e["event_id"] = event_id
	if not is_nan(value):
		e["value"] = value
	_add(e)


func _did(verb: String, subject: String, _n: int) -> void:
	if _verbs.has(verb):
		design("%s:%s" % [verb, subject] if subject != "" else verb)


func _start() -> void:
	user_id = _id()
	session_num = int(PlayerSettings.value(SETTINGS[0], "sessions", 0)) + 1
	PlayerSettings.keep(SETTINGS[0], {"sessions": session_num})
	session_id = _uuid()
	_started = Time.get_unix_time_from_system()
	_add(_base("user"))
	_clock = Timer.new()
	_clock.wait_time = float(config.get("flush_seconds", 60))
	_clock.timeout.connect(flush)
	add_child(_clock)
	_clock.start()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		var e := _base("session_end")
		e["length"] = int(Time.get_unix_time_from_system() - _started)
		_add(e)
		flush()


func _add(e: Dictionary) -> void:
	if not on():
		return
	queue.append(e)
	if queue.size() > int(config.get("queue_most", 500)):
		queue.pop_front()   # (the oldest go first when the phone has been offline a long time)


## Sends what is queued, at most batch_most at a time; kept for the next try if the collector does not take it.
func flush() -> void:
	if _sending or queue.is_empty() or not on():
		return
	var batch: Array[Dictionary] = queue.slice(0, int(config.get("batch_most", 50)))
	var body := JSON.stringify(batch)
	var http := HTTPRequest.new()
	add_child(http)
	_sending = true
	http.request_completed.connect(func(_result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		_sending = false
		http.queue_free()
		if code == 200:
			queue = queue.slice(batch.size()))
	var url := "%s/v2/%s/events" % [SANDBOX_HOST if bool(config.get("sandbox", true)) else HOST, config["game_key"]]
	var auth := "Authorization: " + signature(body, str(config["secret_key"]))   # not-ui (a header)
	http.request(url, [auth, JSON_TYPE], HTTPClient.METHOD_POST, body)


## The collector's Authorization header: base64 of the HMAC-SHA256 of the body, keyed by the secret.
static func signature(body: String, secret: String) -> String:
	var h := HMACContext.new()
	h.start(HashingContext.HASH_SHA256, secret.to_utf8_buffer())
	h.update(body.to_utf8_buffer())
	return Marshalls.raw_to_base64(h.finish())


func _base(category: String) -> Dictionary:
	return {"category": category, "v": 2, "user_id": user_id, "session_id": session_id, "session_num": session_num,
		"client_ts": int(Time.get_unix_time_from_system()), "sdk_version": SDK,
		"platform": "android" if OS.has_feature("android") else OS.get_name().to_lower(),
		"os_version": "%s %s" % ["android" if OS.has_feature("android") else OS.get_name().to_lower(),
			OS.get_version()],
		"device": OS.get_model_name(), "manufacturer": "unknown", "build": str(ProjectSettings.get_setting(
			"application/config/version", "0"))}


func _id() -> String:
	if FileAccess.file_exists(ID_FILE):
		return FileAccess.get_file_as_string(ID_FILE).strip_edges()
	var id := _uuid()
	var f := FileAccess.open(ID_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(id)
	return id


static func _uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20)]
