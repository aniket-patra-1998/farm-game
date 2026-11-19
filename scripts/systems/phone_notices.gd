class_name PhoneNotices
extends RefCounted
## Phone notifications (owner, 19 Nov: "that should have been the first thing we build"): when the game goes to
## the background it plans the few moments worth telling the player about from the farm's own timers, and the
## phone shows them while the game is closed; coming back cancels the rest. Local only, no server.
## What is said, at most how many, how far apart and the quiet night hours are data (Balance `notify.*`); the
## Android side is the FarmNotices plugin (android/plugins/farm_notices), absent on a computer (then nothing).

const PLUGIN := "FarmNotices"           # not-ui (the Android plugin's singleton)
const SETTINGS := "notify"              # not-ui (the player's settings section)
const ON_KEY := "on"                    # not-ui
const HOUR := 3600


## Whether the player wants them (Settings; on unless they turned it off).
static func wanted() -> bool:
	return bool(PlayerSettings.value(SETTINGS, ON_KEY, true))


static func set_wanted(on: bool) -> void:
	PlayerSettings.keep(SETTINGS, {ON_KEY: on})
	if not on:
		cancel_all()


## The moments to tell the player about, soonest first: [{"at": unix time, "text": words}], at most
## `notify.most`, at least `notify.gap` seconds apart, none in the quiet night hours (moved to their end).
static func plan(g: GameState) -> Array:
	var raw: Array = []
	var crop_at := -1
	var crop := ""
	var wither_at := -1
	for i in g.plots.size():
		var p: Dictionary = g.plots[i]
		if p.get("state") != "planted" or not g.on_farm(i):
			continue
		var left := g.field.seconds_until_ripe(i)
		if left > 0 and (crop_at < 0 or left < crop_at):
			crop_at = left
			crop = str(p["crop"])
		var withers := left + g.field.ripe_window(g.crops[p["crop"]]) - Balance.i("notify.wither_warning")
		if withers > 0 and (wither_at < 0 or withers < wither_at):
			wither_at = withers
	if crop_at > 0:
		raw.append({"at": g.now() + crop_at, "text": TranslationServer.translate("NOTIFY_CROPS") %
			str(g.crops[crop].get("name", crop))})
	if wither_at > 0 and wither_at > crop_at + HOUR:
		raw.append({"at": g.now() + wither_at, "text": TranslationServer.translate("NOTIFY_WITHER")})
	var animals_at := -1
	for o: Dictionary in g.objects:
		if g.kind_of(o) == "animal" and not o.get("stray", false):
			var left := g.seconds_until_ready(o)
			if left > 0 and (animals_at < 0 or left < animals_at):
				animals_at = left
	if animals_at > 0:
		raw.append({"at": g.now() + animals_at, "text": TranslationServer.translate("NOTIFY_ANIMALS")})
	var bias := DayCycle.device_bias_minutes() * 60
	var tomorrow := (g.day_number() + 1) * 86400 - bias
	raw.append({"at": tomorrow, "text": TranslationServer.translate("NOTIFY_GIFT")})
	for r: Dictionary in raw:
		r["at"] = _out_of_quiet(int(r["at"]), bias)
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))
	var out: Array = []
	for r: Dictionary in raw:
		if out.size() >= Balance.i("notify.most"):
			break
		if not out.is_empty() and int(r["at"]) - int(out[-1]["at"]) < Balance.i("notify.gap"):
			continue
		out.append(r)
	return out


## A moment in the quiet night hours (Balance notify.quiet: [from, to] local hours) moved to their end.
static func _out_of_quiet(at: int, bias: int) -> int:
	var quiet: Array = Balance.a("notify.quiet")
	var local := at + bias
	var day := floori(local / 86400.0) * 86400
	var hour := float(local - day) / HOUR
	var from := float(quiet[0])
	var to := float(quiet[1])
	if hour >= from:
		return day + 86400 + int(to * HOUR) - bias
	if hour < to:
		return day + int(to * HOUR) - bias
	return at


## The game went to the background: the phone is given the plan (nothing on a computer, or when turned off).
static func schedule(g: GameState) -> void:
	if not Engine.has_singleton(PLUGIN):
		return
	var phone := Engine.get_singleton(PLUGIN)
	phone.call("cancelAll")
	if not wanted() or g.save_path != GameState.SAVE_PATH:   # (never from the showcase)
		return
	var title: String = g.player.farm_name
	if title == "":
		title = str(TranslationServer.translate("NOTIFY_TITLE"))
	var k := 0
	for r: Dictionary in plan(g):
		phone.call("schedule", k, title, str(r["text"]), maxi(int(r["at"]) - g.now(), 1))
		k += 1


## The game is back: what was planned is no longer news.
static func cancel_all() -> void:
	if Engine.has_singleton(PLUGIN):
		Engine.get_singleton(PLUGIN).call("cancelAll")


## Android 13 and later ask the player once whether the game may notify (asked after the first session's start).
static func ask_permission() -> void:
	if Engine.has_singleton(PLUGIN) and wanted():
		Engine.get_singleton(PLUGIN).call("askPermission")
