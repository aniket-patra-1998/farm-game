class_name PhoneNotices
extends RefCounted
## Phone notifications (owner, 19 Nov: "that should have been the first thing we build"): when the game goes to
## the background it plans the few moments worth telling the player about from the farm's own timers, and the
## phone shows them while the game is closed; coming back cancels the rest. Local only, no server.
## What is said, at most how many, how far apart and the quiet night hours are data (Balance `notify.*`); the
## Android side is the Notification Scheduler plugin (addons/NotificationSchedulerPlugin, MIT: exact alarms where
## allowed, Android 13's permission, and notices kept through a phone restart), absent on a computer (then nothing).
## Its small icon is the white barn in assets/NotificationSchedulerPlugin/android.

const PLUGIN := "NotificationSchedulerPlugin"   # not-ui (the Android plugin's singleton)
const SCRIPT := "res://addons/NotificationSchedulerPlugin/NotificationScheduler.gd"   # not-ui
const SETTINGS := "notify"              # not-ui (the player's settings section)
const ON_KEY := "on"                    # not-ui
const HOUR := 3600
const CHANNEL := "farm"                 # not-ui (the notification channel's id)
const ICON := "ic_barnlight"            # not-ui (the small icon's drawable)

static var _phone: Node   # the plugin's NotificationScheduler, made on first need (Android only)


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
		var withers := g.field.withers_at(i) - g.now() - Balance.i("notify.wither_warning")
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
	var worn_at := -1
	var worn := ""
	for o: Dictionary in g.objects:   # (a building nearly worn out: once, before it stops; docs/WEAR.md)
		var left := g.wear.seconds_until_level(o, Balance.i("wear.spoil_from"))
		if left > 0 and (worn_at < 0 or left < worn_at):
			worn_at = left
			worn = g.name_of(str(o["id"]))
	if worn_at > 0:
		raw.append({"at": g.now() + worn_at, "text": TranslationServer.translate("NOTIFY_WEAR") % worn})
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
	var phone := _scheduler()
	if phone == null:
		return
	cancel_all()
	if not wanted() or g.save_path != GameState.SAVE_PATH:   # (never from the showcase)
		return
	var title: String = g.player.farm_name
	if title == "":
		title = str(TranslationServer.translate("NOTIFY_TITLE"))
	var k := 1
	for r: Dictionary in plan(g):
		phone.call("schedule", NotificationData.new().set_id(k).set_channel_id(CHANNEL).set_title(title)   # not-ui
			.set_content(str(r["text"])).set_small_icon_name(ICON).set_delay(maxi(int(r["at"]) - g.now(), 1)))
		k += 1


## The game is back: what was planned is no longer news.
static func cancel_all() -> void:
	var phone := _scheduler()
	if phone == null:
		return
	for k in range(1, Balance.i("notify.most") + 1):
		phone.call("cancel", k)   # not-ui


## Android 13 and later ask the player once whether the game may notify (asked after the first session's start).
static func ask_permission() -> void:
	var phone := _scheduler()
	if phone != null and wanted() and not bool(phone.call("has_post_notifications_permission")):   # not-ui
		phone.call("request_post_notifications_permission")   # not-ui


## The plugin's node, made once and kept in the tree, with the farm's channel (null where there is no plugin).
static func _scheduler() -> Node:
	if _phone != null and is_instance_valid(_phone):
		return _phone
	if not Engine.has_singleton(PLUGIN):
		return null
	_phone = (load(SCRIPT) as GDScript).new()
	_phone.name = "PhoneNotices"   # not-ui (a node name)
	(Engine.get_main_loop() as SceneTree).root.add_child(_phone)
	_phone.call("initialize")   # not-ui
	_phone.call("create_notification_channel", NotificationChannel.new().set_id(CHANNEL)   # not-ui
		.set_name(str(TranslationServer.translate("NOTIFY_CHANNEL")))
		.set_description(str(TranslationServer.translate("NOTIFY_CHANNEL_SAYS")))
		.set_importance(NotificationChannel.Importance.DEFAULT))
	return _phone
