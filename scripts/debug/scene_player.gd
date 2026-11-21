class_name ScenePlayer
extends RefCounted
## Plays the farm as a player does, one scene at a time, and times every frame: sitting still at the playing
## zoom, panning, zooming, every panel opened and closed, things bought and placed, limited animals placed for the
## first time, a field harvested and replanted, rain, storm, snow, fog, night falling, an hour skipped. Each scene's
## frames come back as `stats` (the 50th, 95th and 99th percentile, the slowest 1% averaged, the longest, hitches)
## with its long frames named by the game's timed parts (PerfReadout). The same scenes on a PC (tools/session_probe)
## and on the phones (LoadBenchmark), so a stall a player would feel is measured where it happens.

const SCENES: Array[String] = ["still", "pan", "zoom", "panels", "place", "limited", "harvest", "rain", "storm",
	"snow", "fog", "night", "skip_hour"]
const HITCH_TIMES := 2.0       # a frame this many times the scene's median is a hitch
const HITCH_MS := 50.0         # and one over this is a hitch whatever the median
const LONG_NOTE_MS := 20.0     # a frame this long is noted with what it went to
const NOTES_KEPT := 6          # long frames kept for each scene
const PLAY_ZOOM := 1.6         # the camera zoom a player farms at
const LIMITED_TRIED: Array[String] = ["silkie_chicken", "peacock_turkey", "mandarin_duck", "galaxy_chicken"]
const NIGHT_HOUR := 22
const PANELS_MOST := 10        # panels opened in the panels scene (the book's, then buildings')

var main: Node
var frames := 240              # frames each timed scene runs (still, moving, weather)
var panel_frames := 20         # frames each panel stays open
var place_count := 6
var place_frames := 20         # frames after each placing
var uncapped := false          # frames as fast as they go (a PC's probe: each frame's cost shows)
var _notes: Array[String] = []
var _doing := ""               # what the scene has just done (the thing placed), for its long frames' notes


func _init(main_scene: Node) -> void:
	main = main_scene


func _tree() -> SceneTree:
	return main.get_tree()


func camera() -> FarmCamera:
	return main.get("camera")


## The camera at the farm's middle, at `zoom`.
func view(zoom := PLAY_ZOOM) -> void:
	var grid: FarmGrid = main.get("grid")
	if camera() != null and grid != null:
		camera().snap(grid.to_global(grid.center_of(Game.index_of(Game.farm_size / 2, Game.farm_size / 2))), zoom)


## Plays `scene`, its frames timed; what it did (things placed, plots harvested) comes back with the stats.
func play(scene: String) -> Dictionary:
	_notes.clear()
	PerfReadout._spans = {}
	var told := {}
	var times: Array[float] = []
	var cam := camera()
	var hud: Node = main.get("hud")
	match scene:
		"still":
			times = await frames_of(frames, Callable())
		"pan":
			var step := Vector2(18, 7)
			var leg := maxi(frames / 4, 1)
			times = await frames_of(frames, func(k: int) -> void:
				cam.pan_by(step if (k / leg) % 2 == 0 else -step))
			view()
		"zoom":
			var mid := main.get_viewport().get_visible_rect().size / 2.0
			var leg := maxi(frames / 6, 1)
			times = await frames_of(frames, func(k: int) -> void:
				cam.zoom_by(1.02 if (k / leg) % 2 == 0 else 1.0 / 1.02, mid, true))
			view()
		"panels":
			var opens: Array[Callable] = [hud.show_seeds, hud.show_market, hud.show_collections, hud.show_ribbons,
				hud.show_inbox, func() -> void: hud.show_goals(0)]
			for o in Game.objects:
				if opens.size() >= PANELS_MOST:
					break
				if Game.is_building_item(str(o["id"])) and not Game.under_construction(o):
					var uid := int(o["uid"])
					opens.append(func() -> void: hud.show_building(uid))
			for open in opens:
				open.call()
				times.append_array(await frames_of(panel_frames, Callable()))
				hud.close_panels()
				times.append_array(await frames_of(maxi(panel_frames / 2, 1), Callable()))
			Game.modal_open = false
			told["panels"] = opens.size()
		"place":
			Game.debug_add_coins(1000000)
			Game.debug_add_materials(50)
			var ids: Array[String] = []
			for o in Game.objects:
				if not ids.has(str(o["id"])) and not o.get("stray", false):
					ids.append(str(o["id"]))
			told["placed"] = await _place(ids, place_count, times)
		"limited":   # (each placed for the first time: its model read and built then)
			Game.debug_add_coins(1000000)
			var placed := 0
			for id in LIMITED_TRIED:
				if Game.items.has(id):
					placed += await _place([id], 1, times)
			told["placed"] = placed
		"harvest":
			Game.debug_skip(24 * 3600)
			var crops := {}
			for i in Game.plots.size():
				if Game.on_farm(i) and Game.field.phase(i) == GameState.Phase.RIPE:
					crops[i] = Game.field.crop_at(i)
			for i: int in crops:
				Game.field.harvest(i)
				Game.field.plow(i)
				Game.field.plant(i, crops[i])
			told["plots"] = crops.size()
			times = await frames_of(frames, Callable())
		"rain", "storm", "snow", "fog":
			Game.weather_override = scene
			times = await frames_of(frames, Callable())
			Game.weather_override = ""
		"night":
			var hour := int(Time.get_datetime_dict_from_unix_time(Game.now())["hour"])
			Game.debug_time_offset += ((NIGHT_HOUR - hour + 24) % 24) * 3600
			times = await frames_of(frames, Callable())
		"skip_hour":
			Game.debug_skip(3600)
			times = await frames_of(frames, Callable())
	var out := stats(times)
	out["long_frames"] = _notes.duplicate()
	out.merge(told)
	return out


## Buys and places up to `count` of `ids` (in turn) where there is room; each followed by `place_frames` frames
## (into `times`). Returns how many it placed.
func _place(ids: Array, count: int, times: Array[float]) -> int:
	var placed := 0
	var tries := 0
	while placed < count and tries < 400 and not ids.is_empty():
		tries += 1
		var id := str(ids[tries % ids.size()])
		if Game.buy_and_place(id, randi() % GameState.MAX_SIZE, randi() % GameState.MAX_SIZE):
			placed += 1
			_doing = id
			times.append_array(await frames_of(place_frames, Callable()))
			_doing = ""
	return placed


## Waits `n` frames, calling `each` (with the frame's number) before each; the frames' times in ms. A long one is
## noted with what it went to.
func frames_of(n: int, each: Callable) -> Array[float]:
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for k in n:
		if each.is_valid():
			each.call(k)
		await _tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		times.append(ms)
		var parts := PerfReadout._spans
		PerfReadout._spans = {}
		if ms > LONG_NOTE_MS and _notes.size() < NOTES_KEPT:
			_notes.append("%.0f ms%s: %s" % [ms, (" (%s)" % _doing) if _doing != "" else "",   # not-ui
				parts_line(parts, ms, FrameClock.process_ms())])
		last = now
		if uncapped:
			Engine.max_fps = 0
	return times


## A long frame's timed parts, the longest first, the scripts' time and what no part accounts for.
static func parts_line(parts: Dictionary, ms: float, script_ms := -1.0) -> String:
	var names := parts.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return int(parts[a]) > int(parts[b]))
	var out := PackedStringArray()
	var timed := 0.0
	for part: String in names:
		timed += int(parts[part]) / 1000.0
		if out.size() < 4 and int(parts[part]) >= 500:
			out.append("%s %.1f" % [part, int(parts[part]) / 1000.0])
	out.append("untimed %.1f" % (ms - timed))
	if script_ms >= 0.0:
		out.append("scripts %.1f" % script_ms)
	return ", ".join(out)


## A scene's frames: how many, the 50th/95th/99th percentile, the slowest 1% averaged (`low1`), the longest and
## where it fell, hitches (over HITCH_TIMES the median) and frames over HITCH_MS.
static func stats(times: Array[float]) -> Dictionary:
	if times.is_empty():
		return {"frames": 0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "low1": 0.0, "max": 0.0, "hitches": 0,
			"over_ms": 0, "worst_at": -1}
	var s := times.duplicate()
	s.sort()
	var pick := func(q: float) -> float: return s[mini(s.size() - 1, int(q * s.size()))]
	var med: float = pick.call(0.5)
	var hitches := 0
	var over := 0
	for t in times:
		if t > med * HITCH_TIMES:
			hitches += 1
		if t > HITCH_MS:
			over += 1
	var tail := s.slice(int(s.size() * 0.99))
	var low1 := 0.0
	for t in tail:
		low1 += t
	low1 /= maxf(1.0, tail.size())
	return {"frames": times.size(), "p50": snappedf(med, 0.01), "p95": snappedf(pick.call(0.95), 0.01),
		"p99": snappedf(pick.call(0.99), 0.01), "low1": snappedf(low1, 0.01), "max": snappedf(s[-1], 0.01),
		"hitches": hitches, "over_ms": over, "worst_at": times.find(s[-1])}
