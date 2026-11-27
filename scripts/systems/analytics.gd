class_name Analytics
extends Node
## Play statistics (data/analytics.json; owner, 27 Nov: measure real players, as studios do): a few design events
## from the farm's own event stream (Game.did, the verbs listed in the file), level-ups, and each session's start
## and length, sent in batches to GameAnalytics' collector (its REST API: signed HTTPS POSTs, no native plugin).
## Anonymous: a random id kept on the phone. Nothing is sent without keys in the file, or when the player turns
## "Share play statistics" off in Settings (PlayerSettings "privacy"/"stats"). As GameAnalytics' own SDKs do: an
## init call first (it says whether the game is enabled and the server's clock, so event times are the server's),
## events kept on the phone until the collector takes them (offline play loses nothing), the game's errors sent as
## error events (each message at most ERROR_REPEATS times a session), and purchases as business events.

const CONFIG := "res://data/analytics.json"
const ID_FILE := "user://analytics_id.txt"
const HOST := "https://api.gameanalytics.com"
const SANDBOX_HOST := "https://sandbox-api.gameanalytics.com"
const SDK := "rest api v2"   # not-ui
const JSON_TYPE := "Content-Type: application/json"   # not-ui (a header)
const SETTINGS := ["privacy", "stats"]
const QUEUE_FILE := "user://analytics_queue.json"
const ERROR_REPEATS := 10   # the same error message, at most this many times a session (GameAnalytics' advice)
const ERRORS_MOST := 50     # errors sent in one session in all
const MESSAGE_MOST := 8000  # characters of an error's message (the collector's limit is 8192)

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
var _clock_offset := 0     # the collector's clock minus the phone's, in seconds (from init)
var _enabled := true       # the collector's say (init): false stops sending
var _errors := {}          # error message -> times sent this session
var _tap: ErrorTap


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
	_load_queue()
	_init_call()
	_tap = ErrorTap.new()
	OS.add_logger(_tap)
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
		_save_queue()
		flush()
	elif what == NOTIFICATION_PREDELETE and _tap != null:
		OS.remove_logger(_tap)


## A purchase, as GameAnalytics' business event: `event_id` "type:item" ("gems:gems_medium"), the price in the
## currency's smallest unit (paise, cents) and its ISO code, and how many purchases this player has made.
func business(event_id: String, amount: int, currency: String) -> void:
	var n := int(PlayerSettings.value(SETTINGS[0], "purchases", 0)) + 1
	PlayerSettings.keep(SETTINGS[0], {"purchases": n})
	var e := _base("business")
	e.merge({"event_id": event_id, "amount": amount, "currency": currency, "transaction_num": n, "cart_type": "shop"})
	_add(e)


## The errors the game logged since the last look (ErrorTap, from any thread), as error events: each message a
## few times a session at most, and only so many in all.
func _send_errors() -> void:
	for m: String in ErrorTap.take():
		if _errors.size() >= ERRORS_MOST and not _errors.has(m):
			continue
		var times := int(_errors.get(m, 0))
		if times >= ERROR_REPEATS:
			continue
		_errors[m] = times + 1
		var e := _base("error")
		e.merge({"severity": "error", "message": m.left(MESSAGE_MOST)})
		_add(e)


## The collector's init: whether the game is enabled, and its clock (event times are sent in its time).
func _init_call() -> void:
	if not on():
		return
	var body := JSON.stringify({"platform": _platform(), "os_version": _os_version(), "sdk_version": SDK})
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, b: PackedByteArray) -> void:
		http.queue_free()
		var answer: Variant = JSON.parse_string(b.get_string_from_utf8()) if code == 200 else null
		if answer is Dictionary:
			_enabled = bool(answer.get("enabled", true))
			if answer.has("server_ts"):
				_clock_offset = int(answer["server_ts"]) - int(Time.get_unix_time_from_system()))
	http.request(_host() + "/v2/%s/init" % config["game_key"],
		["Authorization: " + signature(body, str(config["secret_key"])), JSON_TYPE],   # not-ui (headers)
		HTTPClient.METHOD_POST, body)


func _load_queue() -> void:
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_FILE)) \
		if FileAccess.file_exists(QUEUE_FILE) else null
	if kept is Array:
		for e: Variant in kept:
			if e is Dictionary:
				queue.append(e)


func _save_queue() -> void:
	var f := FileAccess.open(QUEUE_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(queue))


func _host() -> String:
	return SANDBOX_HOST if bool(config.get("sandbox", true)) else HOST


static func _platform() -> String:
	return "android" if OS.has_feature("android") else OS.get_name().to_lower()


static func _os_version() -> String:
	return "%s %s" % [_platform(), OS.get_version()]


func _add(e: Dictionary) -> void:
	if not on():
		return
	queue.append(e)
	if queue.size() > int(config.get("queue_most", 500)):
		queue.pop_front()   # (the oldest go first when the phone has been offline a long time)


## Sends what is queued, at most batch_most at a time; kept for the next try if the collector does not take it.
func flush() -> void:
	_send_errors()
	if _sending or queue.is_empty() or not on() or not _enabled:
		return
	var batch: Array[Dictionary] = queue.slice(0, int(config.get("batch_most", 50)))
	var body := JSON.stringify(batch)
	var http := HTTPRequest.new()
	add_child(http)
	_sending = true
	http.request_completed.connect(func(_result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		_sending = false
		http.queue_free()
		if code == 200 or code == 400:   # (400: the collector refused the batch as malformed; resending won't help)
			queue = queue.slice(batch.size())
			_save_queue())
	var url := "%s/v2/%s/events" % [_host(), config["game_key"]]
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
		"client_ts": int(Time.get_unix_time_from_system()) + _clock_offset, "sdk_version": SDK,
		"platform": _platform(), "os_version": _os_version(),
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


## The game's errors, caught as Godot logs them (OS.add_logger): from any thread, so kept under a lock until the
## main thread takes them (Analytics._send_errors). Warnings are left out; a script error says where it was.
class ErrorTap extends Logger:
	static var _lock := Mutex.new()
	static var _waiting: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var m := "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
		_lock.lock()
		if _waiting.size() < ERRORS_MOST:
			_waiting.append(m)
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	## What was logged since the last call, oldest first.
	static func take() -> Array[String]:
		_lock.lock()
		var out := _waiting.duplicate()
		_waiting.clear()
		_lock.unlock()
		return out

