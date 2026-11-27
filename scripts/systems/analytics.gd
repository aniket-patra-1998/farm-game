class_name Analytics
extends Node
## Play statistics (data/analytics.json; owner, 27 Nov: measure real players, as studios do), through GameAnalytics'
## own Godot SDK (addons/GameAnalytics, a GDExtension: its native Android SDK underneath; free plan): sessions,
## the queue kept on the phone while offline, the user id and the server's clock are the SDK's. The game sends a
## few design events from the farm's own event stream (Game.did, the verbs listed in the file) and level-ups,
## purchases as business events, rewarded ads as ad events, and its own errors (a Godot Logger, ErrorTap) as error
## events, each message at most ERROR_REPEATS times a session. GameAnalytics' remote configs, when the dashboard
## has a "tuning" config (the hosted tuning file's form: {"values": {...}}), tune Balance (Balance.take_remote).
## Nothing is sent without keys in the file, or when the player turns "Share play statistics" off in Settings
## (PlayerSettings "privacy"/"stats"). Where the SDK isn't loaded (a 32-bit phone: it ships for arm64), no statistics.

const CONFIG := "res://data/analytics.json"
const SINGLETON := "GameAnalytics"   # not-ui
const SETTINGS := ["privacy", "stats"]
const ERROR_REPEATS := 10   # the same error message, at most this many times a session (GameAnalytics' advice)
const ERRORS_MOST := 50     # errors sent in one session in all
const MESSAGE_MOST := 8000  # characters of an error's message (the collector's limit is 8192)
const TUNING := "tuning"    # the remote config whose value (JSON) tunes Balance
const ERROR_LOOK_SECONDS := 5.0

static var shared: Analytics

var config := {}
var sdk: Object             # the SDK's singleton, or a stand-in (tests); null: nothing is sent
var _verbs := {}
var _errors := {}           # error message -> times sent this session
var _started := false
var _tap: ErrorTap


## Made once by the game (like AssetPacks): reads the file, listens to the farm and starts the SDK.
static func begin(game: GameState) -> Analytics:
	var a := Analytics.new()
	a.name = "Analytics"   # not-ui (a node name)
	a.config = game.read_json(CONFIG)
	a.sdk = Engine.get_singleton(SINGLETON) if Engine.has_singleton(SINGLETON) else null
	shared = a
	game.add_child(a)
	game.did.connect(a._did)
	game.leveled_up.connect(func(level: int) -> void: a.design("level:%d" % level))
	a._count_session()
	a.start()
	return a


## Whether events go out: the SDK here, keys in the file and the player not opted out.
func on() -> bool:
	return sdk != null and str(config.get("game_key", "")) != "" and str(config.get("secret_key", "")) != "" \
		and bool(PlayerSettings.value(SETTINGS[0], SETTINGS[1], true))


## Starts the SDK once (when on), or stops sending while the player has statistics off.
func start() -> void:
	for v: String in config.get("events", []):
		_verbs[v] = true
	if sdk == null:
		return
	if not _started and on():
		_started = true
		var build := str(ProjectSettings.get_setting("application/config/version", "0"))
		sdk.call("configureBuild", build)   # not-ui (an SDK call)
		sdk.call("setEnabledErrorReporting", true)   # not-ui (an SDK call)
		sdk.connect("remote_configs_updated", _on_configs)
		sdk.call("init", str(config["game_key"]), str(config["secret_key"]))
		_tap = ErrorTap.new()
		OS.add_logger(_tap)
		var look := Timer.new()
		look.wait_time = ERROR_LOOK_SECONDS
		look.timeout.connect(_send_errors)
		add_child(look)
		look.start()
	if _started:
		sdk.call("setEnabledEventSubmission", on())   # not-ui (an SDK call)


## A design event ("buy:cow", "level:7"), with an optional number.
func design(event_id: String, value := NAN) -> void:
	if not on():
		return
	if is_nan(value):
		sdk.call("addDesignEvent", event_id, {})   # not-ui (an SDK call)
	else:
		sdk.call("addDesignEventWithValue", event_id, value)   # not-ui (an SDK call)


## A purchase, as GameAnalytics' business event: `item_type` and `item_id` ("gems", "gems_medium"), the price in the
## currency's smallest unit (paise, cents) and its ISO code.
func business(item_type: String, item_id: String, amount: int, currency: String) -> void:
	if on():
		sdk.call("addBusinessEvent", currency, amount, item_type, item_id, "shop", {})   # not-ui (an SDK call)


## A rewarded ad: `action` "show" or "reward_received", at `placement` ("gift", "rescue").
func ad(action: String, placement: String) -> void:
	if on():
		sdk.call("addAdEvent", action, "rewarded_video", "admob", placement, {})   # not-ui (an SDK call)


func _did(verb: String, subject: String, _n: int) -> void:
	if _verbs.has(verb):
		design("%s:%s" % [verb, subject] if subject != "" else verb)


## The sessions played on this phone (the review ask waits for a few), counted whether or not statistics go out.
func _count_session() -> void:
	var n := int(PlayerSettings.value(SETTINGS[0], "sessions", 0)) + 1
	PlayerSettings.keep(SETTINGS[0], {"sessions": n})


## The errors the game logged since the last look (ErrorTap, from any thread), as error events: each message a
## few times a session at most, and only so many in all.
func _send_errors() -> void:
	for m: String in ErrorTap.take():
		if _errors.size() >= ERRORS_MOST and not _errors.has(m):
			continue
		var times := int(_errors.get(m, 0))
		if times >= ERROR_REPEATS or not on():
			continue
		_errors[m] = times + 1
		sdk.call("addErrorEvent", "error", m.left(MESSAGE_MOST), {})   # not-ui (an SDK call)


## GameAnalytics' remote configs came: a "tuning" one tunes Balance as the hosted file does.
func _on_configs(configs: String) -> void:
	var all: Variant = JSON.parse_string(configs)
	if not all is Dictionary or not (all as Dictionary).has(TUNING):
		return
	var tuning: Variant = JSON.parse_string(str(all[TUNING]))
	if tuning is Dictionary:
		Balance.take_remote(tuning)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _started:
		sdk.call("onQuit")   # not-ui (an SDK call)
	elif what == NOTIFICATION_PREDELETE and _tap != null:
		OS.remove_logger(_tap)


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
