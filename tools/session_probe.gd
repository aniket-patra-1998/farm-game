extends Node
## The session probe (owner, 21 Nov: "a detailed thorough performance check, nothing skipped"): the real game
## played as a player plays it, every frame timed. On each farm (a new farm, the showcase, the showcase filled as
## players' farms fill) it runs scenes: sitting still at the playing zoom, panning, zooming, every panel opened
## and closed, things bought and placed, a field harvested and replanted, rain, storm, snow, fog, night, an hour
## skipped. For each scene: frames, the frame time at the 50th, 95th and 99th percentile, the slowest 1% averaged,
## the longest frame, hitches (frames over HITCH_TIMES the scene's median, and over HITCH_MS), and how memory,
## nodes and objects moved (a leak shows as a climb that the second round repeats). Then what each script that
## runs every frame costs, and the costly one-off jobs.
## Headless (godot --headless), a frame's wall time is its CPU cost: the GPU needs a phone (phone_bench.yml).
## Run: godot --headless --path . res://tools/session_probe.tscn -- [--quality=low] [--rounds=2] [--farms=new,played,showcase,filled]
## Prints "SESSION <farm> <scene> ..." lines and one "SESSION_JSON {...}" line with everything.

const STILL_FRAMES := 240
const MOVE_FRAMES := 240
const WEATHER_FRAMES := 240
const PANEL_FRAMES := 20       # frames each panel stays open (its open motion and a few frames after)
const SETTLE_LIMIT := 4000     # frames waited at most for a farm to stand
const HITCH_TIMES := 2.0       # a frame this many times the scene's median is a hitch
const HITCH_MS := 50.0         # and one over this is a hitch whatever the median
const PLAY_ZOOM := 1.6         # the camera zoom a player farms at (LoadBenchmark.PLAY_ZOOM)
const PLACE_COUNT := 6         # things bought and placed in the placing scene
const PROCESS_RUNS := 30       # calls timed for each script's _process
const TOP_SCRIPTS := 15        # scripts listed by cost
const LIMITED_TRIED: Array[String] = ["silkie_chicken", "peacock_turkey", "mandarin_duck", "galaxy_chicken"]
const LONG_SHOWN := 4          # long frames printed for each scene, with what they went to
const PLAYED_DAYS := 30        # days the "played" farm is played by the goal bot first
const BOT := preload("res://tools/balance_sim.gd")

var _main: Node
var _rounds := 1
var _farms: PackedStringArray = ["new", "played", "showcase", "filled"]
var _report := {}
var _errors := 0
var _hitch_notes: Array[String] = []   # the long frames of the scene running now, and what they went to


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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			Quality._level = a.trim_prefix("--quality=")
			Quality.notifier.emitted.emit()
		elif a.begins_with("--rounds="):
			_rounds = maxi(1, int(a.trim_prefix("--rounds=")))
		elif a.begins_with("--farms="):
			_farms = a.trim_prefix("--farms=").split(",")
	var counter := Counter.new()
	OS.add_logger(counter)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Game.saving_enabled = false
	PerfReadout.timing = true
	var t0 := Time.get_ticks_usec()
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_report["main_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	Engine.max_fps = 0   # (after the game set the level's cap: frames as fast as they go, so each one's cost shows)
	print("SESSION start main_ms=%.0f quality=%s" % [_report["main_ms"], Quality.level()])
	for farm in _farms:
		await _farm(farm)
	_report["errors"] = counter.count
	_report["first_errors"] = counter.first
	print("SESSION errors=%d %s" % [counter.count, counter.first])
	print("SESSION_JSON " + JSON.stringify(_report))
	get_tree().quit()


## One farm: opened (timed), then every scene, `_rounds` times; then the per-script costs.
func _farm(farm: String) -> void:
	var t0 := Time.get_ticks_usec()
	match farm:
		"new":
			Game.open_own_farm()
			Game.reset_game()
		"played":   # (a farm as the goal bot plays it for PLAYED_DAYS days: what a player's farm grows into)
			Game.open_own_farm()
			var sim: Node = BOT.new()
			sim.set("game", Game)
			sim.set("style", "goals")
			var hours: Array = sim.call("_visit_hours")
			sim.call("new_farm")
			sim.call("play_first_hour")
			for day in range(1, PLAYED_DAYS + 1):
				for v in hours.size():
					if day == 1 and v == 0:
						continue
					Game.debug_time_offset += int(sim.call("_seconds_until", hours[v], Game.now()))
					Game.persistence.watch_clock()
					sim.call("_visit", sim.call("_visits_after", hours, v))
			sim.free()
			t0 = Time.get_ticks_usec()
		"showcase":
			Game.open_showcase()
		"filled":
			Game.open_showcase()
			ShowcaseFarm.fill(Game)
	var open := await _settle()
	open["build_ms"] = open["ms"]
	open["open_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	open["objects"] = Game.objects.size()
	print("SESSION %s open: %.0f ms, %d frames, longest %.0f ms, %d objects" % [farm, open["open_ms"],
		open["frames"], open["longest_ms"], open["objects"]])
	var farm_report := {"open": open, "rounds": []}
	_view(PLAY_ZOOM)
	for r in _rounds:
		var scenes := {}
		for scene in ["still", "pan", "zoom", "panels", "place", "limited", "harvest", "rain", "storm", "snow", "fog", "night",
				"skip_hour"]:
			scenes[scene] = await _scene(farm, scene)
		farm_report["rounds"].append(scenes)
	farm_report["scripts"] = _scripts(farm)
	farm_report["jobs"] = _jobs(farm)
	_report[farm] = farm_report


## Waits until every 3D object stands; the frames meanwhile.
func _settle() -> Dictionary:
	var times: Array[float] = []
	var t0 := Time.get_ticks_usec()
	var last := t0
	for k in SETTLE_LIMIT:
		var all := true
		for o: Objects3D in get_tree().get_nodes_in_group(Objects3D.GROUP):
			all = all and o.settled()
		if all and k > 2:
			break
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		times.append(ms)
		var parts := PerfReadout._spans
		PerfReadout._spans = {}
		if ms > HITCH_MS * 2.0:
			print("SESSION opening   long frame %.0f ms: %s" % [ms, _parts_line(parts, ms)])
		last = now
	return {"ms": (last - t0) / 1000.0, "frames": times.size(), "longest_ms": times.max() if times.size() else 0.0}


func _camera() -> FarmCamera:
	return _main.get("camera")


func _center() -> Vector2:
	return (_main.get("grid") as Node).call("get_bounds").get_center()


func _view(zoom: float) -> void:
	_camera().snap(_center(), zoom)


## One scene: what it does each frame, its frames timed, memory before and after.
func _scene(farm: String, scene: String) -> Dictionary:
	var before := _counts()
	_hitch_notes.clear()
	var times: Array[float] = []
	var cam := _camera()
	var hud: Node = _main.get("hud")
	match scene:
		"still":
			times = await _frames(STILL_FRAMES, Callable())
		"pan":
			var step := Vector2(18, 7)
			times = await _frames(MOVE_FRAMES, func(k: int) -> void:
				cam.pan_by(step if (k / 60) % 2 == 0 else -step))
		"zoom":
			var mid := get_viewport().get_visible_rect().size / 2.0
			times = await _frames(MOVE_FRAMES, func(k: int) -> void:
				cam.zoom_by(1.02 if (k / 40) % 2 == 0 else 1.0 / 1.02, mid, true))
			_view(PLAY_ZOOM)
		"panels":
			var opens: Array[Callable] = [hud.show_seeds, hud.show_market, hud.show_collections, hud.show_ribbons,
				hud.show_inbox, func() -> void: hud.show_goals(0)]
			for o in Game.objects:
				var id := str(o["id"])
				if Game.is_building_item(id) and not Game.under_construction(o) and opens.size() < 10:
					var uid := int(o["uid"])
					opens.append(func() -> void: hud.show_building(uid))
			for open in opens:
				open.call()
				times.append_array(await _frames(PANEL_FRAMES, Callable()))
				hud.close_panels()
				times.append_array(await _frames(PANEL_FRAMES / 2, Callable()))
			Game.modal_open = false
		"place":
			Game.debug_add_coins(1000000)
			Game.debug_add_materials(50)
			var ids: Array[String] = []
			for o in Game.objects:
				var id := str(o["id"])
				if not ids.has(id) and not o.get("stray", false):
					ids.append(id)
			var placed := 0
			var tries := 0
			while placed < PLACE_COUNT and tries < 400 and not ids.is_empty():
				tries += 1
				var id := ids[tries % ids.size()]
				if Game.buy_and_place(id, randi() % GameState.MAX_SIZE, randi() % GameState.MAX_SIZE):
					placed += 1
					times.append_array(await _frames(20, Callable()))
			before["placed"] = placed
		"harvest":
			Game.debug_skip(24 * 3600)
			var crops := {}
			for i in Game.plots.size():
				if Game.on_farm(i) and Game.field.phase(i) == GameState.Phase.RIPE:
					crops[i] = Game.field.crop_at(i)
			var t := Time.get_ticks_usec()
			for i in crops:
				Game.field.harvest(i)
				Game.field.plow(i)
				Game.field.plant(i, crops[i])
			before["harvest_call_ms"] = (Time.get_ticks_usec() - t) / 1000.0
			before["plots"] = crops.size()
			times = await _frames(STILL_FRAMES, Callable())
		"limited":   # (limited animals, each placed for the first time: its model read and built then)
			Game.debug_add_coins(1000000)
			var placed := 0
			for id in LIMITED_TRIED:
				var tries := 0
				while tries < 200:
					tries += 1
					if Game.buy_and_place(id, randi() % GameState.MAX_SIZE, randi() % GameState.MAX_SIZE):
						placed += 1
						times.append_array(await _frames(30, Callable()))
						break
			before["placed"] = placed
		"rain", "storm", "snow", "fog":
			Game.weather_override = scene
			times = await _frames(WEATHER_FRAMES, Callable())
			Game.weather_override = ""
		"night":
			var hour := Time.get_datetime_dict_from_unix_time(Game.now())["hour"] as int
			Game.debug_time_offset += ((22 - hour + 24) % 24) * 3600
			times = await _frames(STILL_FRAMES, Callable())
		"skip_hour":
			var t := Time.get_ticks_usec()
			Game.debug_skip(3600)
			before["skip_call_ms"] = (Time.get_ticks_usec() - t) / 1000.0
			times = await _frames(STILL_FRAMES, Callable())
	var out := _stats(times)
	out["long_frames"] = _hitch_notes.duplicate()
	var after := _counts()
	out["mem_mb"] = after["mem_mb"]
	out["mem_change_mb"] = snappedf(after["mem_mb"] - before["mem_mb"], 0.01)
	out["nodes_change"] = after["nodes"] - before["nodes"]
	out["objects_change"] = after["objects"] - before["objects"]
	for k in before:
		if not k in ["mem_mb", "nodes", "objects"]:
			out[k] = before[k]
	print("SESSION %s %s: n=%d p50=%.1f p95=%.1f p99=%.1f low1=%.1f max=%.1f hitches=%d over%d=%d mem%+.1fMB nodes%+d %s" % [
		farm, scene, out["frames"], out["p50"], out["p95"], out["p99"], out["low1"], out["max"], out["hitches"],
		int(HITCH_MS), out["over_ms"], out["mem_change_mb"], out["nodes_change"],
		"" if out["worst_at"] < 0 else "(worst at frame %d)" % out["worst_at"]])
	for note: String in (out["long_frames"] as Array).slice(0, LONG_SHOWN):
		print("SESSION %s %s   long frame %s" % [farm, scene, note])
	return out


## Waits `n` frames, calling `each` (with the frame's number) before each; the frames' times in ms.
func _frames(n: int, each: Callable) -> Array[float]:
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for k in n:
		if each.is_valid():
			each.call(k)
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		times.append(ms)
		var parts := PerfReadout._spans
		PerfReadout._spans = {}
		if ms > HITCH_MS * 0.4:   # (what the long frames went to: the game's timed parts, and the rest)
			_hitch_notes.append("%.0f ms: %s" % [ms, _parts_line(parts, ms)])
		last = now
		Engine.max_fps = 0
	return times


## A long frame's timed parts, the longest first, and what no part accounts for.
func _parts_line(parts: Dictionary, ms: float) -> String:
	var names := parts.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return int(parts[a]) > int(parts[b]))
	var out := PackedStringArray()
	var timed := 0.0
	for part: String in names:
		timed += int(parts[part]) / 1000.0
		if out.size() < 4 and int(parts[part]) >= 500:
			out.append("%s %.1f" % [part, int(parts[part]) / 1000.0])
	out.append("untimed %.1f" % (ms - timed))
	return ", ".join(out)


func _stats(times: Array[float]) -> Dictionary:
	if times.is_empty():
		return {"frames": 0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "low1": 0.0, "max": 0.0, "hitches": 0, "over_ms": 0,
			"worst_at": -1}
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


func _counts() -> Dictionary:
	return {"mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT))}


## What each script that runs every frame costs (its _process called PROCESS_RUNS times), the dearest first.
func _scripts(farm: String) -> Array:
	var by := {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != self and n.is_processing() and n.get_script() != null and n.has_method("_process"):
			var path := (n.get_script() as Script).resource_path.get_file()
			var list: Array = by.get(path, [])
			list.append(n)
			by[path] = list
		stack.append_array(n.get_children())
	var rows: Array = []
	for path in by:
		var t := Time.get_ticks_usec()
		for r in PROCESS_RUNS:
			for n: Node in by[path]:
				if is_instance_valid(n):
					n._process(1.0 / 60.0)
		rows.append([path, by[path].size(), snappedf((Time.get_ticks_usec() - t) / 1000.0 / PROCESS_RUNS, 0.001)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	var total := 0.0
	for row in rows:
		total += row[2]
	print("SESSION %s scripts: %d running every frame, %.2f ms a frame in all" % [farm, rows.size(), total])
	for row in rows.slice(0, TOP_SCRIPTS):
		print("SESSION %s   %s x%d: %.3f ms" % [farm, row[0], row[1], row[2]])
	return rows


## The costly one-off jobs: saving, loading, a full look over the 3D objects, rebuilding the ground and fields.
func _jobs(farm: String) -> Dictionary:
	var out := {}
	var t := Time.get_ticks_usec()
	var data := Game.persistence.snapshot()
	out["snapshot_ms"] = (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	var text := JSON.stringify(data)
	out["save_json_ms"] = (Time.get_ticks_usec() - t) / 1000.0
	out["save_bytes"] = text.length()
	for pair in [["Crops3D", "rebuild"], ["Plots3D", "rebuild"], ["Ground3D", "rebuild"], ["Objects3D", "sync"]]:
		var n := get_tree().root.find_child(pair[0], true, false)
		if n != null and n.has_method(pair[1]):
			t = Time.get_ticks_usec()
			for r in 3:
				n.call(pair[1])
			out["%s.%s_ms" % pair] = snappedf((Time.get_ticks_usec() - t) / 3000.0, 0.01)
	print("SESSION %s jobs: %s" % [farm, out])
	return out
