extends Node
## The interface audit (owner, 20 Nov: "nothing should get missed by the audit bot"): the real game, on every phone
## shape, played for days by the play bot (tools/balance_sim), and checked after every visit as the owner checks
## it by hand. Each check is a target in data/ui_targets.json, with the gap that put it there:
## - every HUD part stands whole on the screen and none overlaps another (icons in an iQOO 15R's corners);
## - every panel opens on the screen and closes, leaving nothing covering the farm (no stuck menu);
## - a tap on each kind of thing on the farm answers in time (a stray's adoption froze the game);
## - nothing floods (60 things waited in a new farm's inbox);
## - no script error, anywhere.
## Prints "ui targets: all N met" or "UI TARGETS MISSED (...)" with each problem; tools/audit.sh and the
## Economy audit workflow run it. Run: godot --headless --path . res://tools/ui_audit.tscn -- [--days=N] [--seed=S]

const MAIN_SCENE := preload("res://scenes/main.tscn")
const BOT := preload("res://tools/balance_sim.gd")
const TARGETS := "res://data/ui_targets.json"
## Screens checked (width x height, landscape): computer, phones from 16:9 to 20:9 (the owner's iQOO 15R is
## 2800 x 1260), tablets at 4:3.
const SHAPES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1600, 720),
	Vector2i(2340, 1080), Vector2i(2800, 1260), Vector2i(3200, 1440), Vector2i(1024, 768), Vector2i(2048, 1536)]
const PANEL_SHAPES: Array[Vector2i] = [Vector2i(1024, 768), Vector2i(2800, 1260)]   # panels: the squarest, the longest
const SETTLE_FRAMES := 3
const PANEL_SETTLE := 0.8  # seconds a panel's open or close motion takes to settle (BookPanel's glide)
const MOST_SHOWN := 20     # problems printed

var _days := 5
var _seed := 1
var _main: Node
var _hud: FarmHud
var _errors := 0
var _measured := {"worst_frame_ms": 0.0, "tap_ms": 0.0, "errors": 0, "offscreen": 0, "in_corners": 0, "overlaps": 0,
	"panel_offscreen": 0, "panel_stuck": 0, "inbox_most": 0, "checks": 0}
var _problems: Array[String] = []
var _last_frame := 0


## Counts every script and engine error while the audit runs.
class Counter extends Logger:
	var count := 0
	var first: Array[String] = []

	func _log_error(_function: String, file: String, line: int, _code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		count += 1
		if first.size() < 5:
			first.append("%s:%d %s" % [file, line, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			_days = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			_seed = int(arg.get_slice("=", 1))
	var counter := Counter.new()
	OS.add_logger(counter)
	Game.saving_enabled = false
	Display.as_phone = true   # (laid out as on a phone: its edges kept)
	seed(_seed)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	_hud = _main.get("hud")
	var sim: Node = BOT.new()
	sim.set("game", Game)
	sim.set("style", "goals")
	# (not added to the tree: its own _ready would play a run of its own)
	# A new farm, played as the goal bot plays it, checked after every visit.
	var hours: Array = sim.call("_visit_hours")
	sim.call("new_farm")
	await _frames(SETTLE_FRAMES)
	sim.call("play_first_hour")
	await _checkpoint("new farm, first hour", true)
	for day in range(1, _days + 1):
		for v in hours.size():
			if day == 1 and v == 0:
				continue
			Game.debug_time_offset += int(sim.call("_seconds_until", hours[v], Game.now()))
			Game.persistence.watch_clock()
			sim.call("_visit", sim.call("_visits_after", hours, v))   # (the bot's own time is not the game's)
			await _checkpoint("day %d, visit %d" % [day, v + 1], v == hours.size() - 1)
	# The showcase: every feature in one place.
	Game.open_showcase()
	await _frames(SETTLE_FRAMES * 3)
	await _checkpoint("showcase", true)
	Game.open_own_farm()
	_measured["errors"] = counter.count
	for e in counter.first:
		_problems.append("error: " + e)
	_report()
	get_tree().quit()


## Everything checked at one moment of play: the HUD on every screen, then (when `panels`) every panel, a tap on
## each kind of thing on the farm, and the floods.
func _checkpoint(when: String, panels: bool) -> void:
	await _frames(SETTLE_FRAMES)
	var window := get_tree().root
	var was := window.size
	for shape in SHAPES:
		window.size = shape
		await _frames(SETTLE_FRAMES)
		_check_hud(when, shape)
		if panels and PANEL_SHAPES.has(shape):
			await _check_panels(when, shape)
	window.size = was
	await _frames(SETTLE_FRAMES)
	if panels:
		await _check_taps(when)
	_measured["inbox_most"] = maxi(int(_measured["inbox_most"]), Game.social.inbox.size())


## The HUD's parts: each whole on the screen, none over another (test 584's rule, here after days of play).
func _check_hud(when: String, shape: Vector2i) -> void:
	var parts: Array = []
	for c: Control in _hud.top.hideable() + _hud.side.hideable():
		parts.append([str(c.name), c])
	parts.append(["toolbar", _hud.tools.panel])
	parts.append(["goal faces", _hud.goals.column])
	parts.append(["hint", _hud.get("_tutorial")])
	var screen := Rect2(Vector2.ZERO, _main.get_viewport().get_visible_rect().size).grow(1.0)
	var ex := UiTheme.size("phone_edge_x") - 1.0
	var ey := UiTheme.size("phone_edge_y") - 1.0
	var inner := screen.grow_individual(-ex, -ey, -ex, -ey)   # (a phone's rounded corners and edges)
	var rects: Array = []
	for p: Array in parts:
		var c: Control = p[1]
		if c == null or not c.is_visible_in_tree() or c.get_global_rect().size == Vector2.ZERO:
			continue
		var r := c.get_global_rect()
		_measured["checks"] += 1
		if not screen.encloses(r):
			_measured["offscreen"] += 1
			_problem("%s, %dx%d: %s off the screen (%s)" % [when, shape.x, shape.y, p[0], r])
		elif not inner.encloses(r):
			_measured["in_corners"] += 1
			_problem("%s, %dx%d: %s in a phone's edge (%s)" % [when, shape.x, shape.y, p[0], r])
		rects.append([p[0], r.grow(-2.0)])
	for a in rects.size():
		for b in range(a + 1, rects.size()):
			if (rects[a][1] as Rect2).intersects(rects[b][1]):
				_measured["overlaps"] += 1
				_problem("%s, %dx%d: %s over %s" % [when, shape.x, shape.y, rects[a][0], rects[b][0]])


## Every panel: opens whole on the screen, closes, and leaves no menu over the farm.
func _check_panels(when: String, shape: Vector2i) -> void:
	var opens: Array = [["seeds", _hud.show_seeds], ["market", _hud.show_market],
		["collections", _hud.show_collections], ["ribbons", _hud.show_ribbons], ["inbox", _hud.show_inbox],
		["goals", func() -> void: _hud.show_goals(0)]]
	for o in Game.objects:   # (a home, a crafting building and the Barn, when the farm has them)
		var id := str(o["id"])
		if Game.is_building_item(id) and not Game.under_construction(o) and not opens.any(
				func(p: Array) -> bool: return p[0] == Game.building_def(id).wear_kind()):
			var uid := int(o["uid"])
			opens.append([Game.building_def(id).wear_kind(), func() -> void: _hud.show_building(uid)])
	for p: Array in opens:
		var t0 := Time.get_ticks_usec()
		(p[1] as Callable).call()
		_note_frame_gap(t0)
		await _settle()
		var screen := Rect2(Vector2.ZERO, _main.get_viewport().get_visible_rect().size).grow(1.0)
		for c: Control in _open_panels():
			_measured["checks"] += 1
			if not screen.encloses(c.get_global_rect()):
				_measured["panel_offscreen"] += 1
				_problem("%s, %dx%d: the %s panel off the screen (%s)" % [when, shape.x, shape.y, p[0],
					c.get_global_rect()])
		_hud.close_panels()
		await _settle()
		if Game.modal_open or not _open_panels().is_empty():
			_measured["panel_stuck"] += 1
			_problem("%s, %dx%d: after closing the %s panel something still covers the farm" % [when, shape.x,
				shape.y, p[0]])
			_hud.close_panels()
			Game.modal_open = false


## The panels open now (the book, the building sheet).
func _open_panels() -> Array[Control]:
	var out: Array[Control] = []
	if _hud.book != null and _hud.book.is_open():
		out.append(_hud.book)
	if _hud.sheet != null and _hud.sheet.is_open():
		out.append(_hud.sheet)
	return out


## A tap by hand on one thing of each kind on the farm (and a stray, fed until adopted) answers in time.
func _check_taps(when: String) -> void:
	var grid: FarmGrid = _main.get("grid")
	if grid == null:
		return
	Game.strays._spawn_stray()
	var seen := {}
	for o: Dictionary in Game.objects.duplicate():
		var kind := "stray" if o.get("stray", false) else Game.kind_of(o)
		if seen.has(kind) or Game.object_by_uid(int(o["uid"])).is_empty():
			continue
		seen[kind] = true
		for k in (Game.strays.feeds_needed() if kind == "stray" else 1):
			var t0 := Time.get_ticks_usec()
			grid._act_on_object(Game.object_by_uid(int(o["uid"])), true)
			var took := (Time.get_ticks_usec() - t0) / 1000.0
			await _frames(SETTLE_FRAMES)
			if took > float(_measured["tap_ms"]):
				_measured["tap_ms"] = took
			if took > _target("tap_ms"):
				_problem("%s: a tap on a %s took %d ms" % [when, kind, roundi(took)])
		_hud.close_panels()
		await _frames(SETTLE_FRAMES)


## Waits for a panel's motion to end (it runs on real time, and headless frames come fast).
func _settle() -> void:
	await _frames(SETTLE_FRAMES)
	await get_tree().create_timer(PANEL_SETTLE).timeout
	await _frames(SETTLE_FRAMES)


## Waits `n` frames, keeping the longest gap between two.
func _frames(n: int) -> void:
	for k in n:
		_last_frame = Time.get_ticks_usec()
		await get_tree().process_frame
		_note_frame_gap(_last_frame)


func _note_frame_gap(since: int) -> void:
	var ms := (Time.get_ticks_usec() - since) / 1000.0
	if ms > float(_measured["worst_frame_ms"]):
		_measured["worst_frame_ms"] = ms


func _problem(what: String) -> void:
	_problems.append(what)


func _target(key: String) -> float:
	for t: Dictionary in _targets():
		if str(t["metric"]) == key and t.has("most"):
			return float(t["most"])
	return INF


func _targets() -> Array:
	return (Game.read_json(TARGETS).get("targets", []) as Array)


## The verdict, as the economy audit prints it.
func _report() -> void:
	var missed: Array[String] = []
	var checked := 0
	var limits := {"inbox_most": float(Balance.i("social.inbox_limit"))}
	for t: Dictionary in _targets():
		var key := str(t["metric"])
		if not _measured.has(key):
			continue
		checked += 1
		var most := float(t.get("most", limits.get(key, INF)))
		if float(_measured[key]) > most:
			missed.append("%s %s (target at most %s)" % [key, str(snappedf(float(_measured[key]), 0.1)), str(most)])
	print("ui audit: %d checks; worst frame %d ms; slowest tap %d ms" % [int(_measured["checks"]),
		roundi(float(_measured["worst_frame_ms"])), roundi(float(_measured["tap_ms"]))])
	for k in mini(_problems.size(), MOST_SHOWN):
		print("  " + _problems[k])
	if missed.is_empty():
		print("ui targets: all %d met" % checked)
	else:
		print("UI TARGETS MISSED (%d of %d): %s" % [missed.size(), checked, "; ".join(PackedStringArray(missed))])
