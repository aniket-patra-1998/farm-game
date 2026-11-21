extends Node
## The session probe (owner, 21 Nov: "a detailed thorough performance check, nothing skipped"): the real game
## played as a player plays it, every frame timed. On each farm (a new farm, the showcase, the showcase filled as
## players' farms fill) it runs scenes: sitting still at the playing zoom, panning, zooming, every panel opened
## and closed, things bought and placed, a field harvested and replanted, rain, storm, snow, fog, night, an hour
## skipped. For each scene: frames, the frame time at the 50th, 95th and 99th percentile, the slowest 1% averaged,
## the longest frame, hitches (ScenePlayer: the scenes and their stats, shared with the phone benchmark), and
## how memory, nodes and objects moved (a leak shows as a climb that the second round repeats). Then what each
## script that runs every frame costs, and the costly one-off jobs.
## Headless (godot --headless), a frame's wall time is its CPU cost: the GPU needs a phone (phone_bench.yml).
## Run: godot --headless --path . res://tools/session_probe.tscn -- [--quality=low] [--rounds=2]
##   [--farms=new,played,showcase,filled]
## Prints "SESSION <farm> <scene> ..." lines and one "SESSION_JSON {...}" line with everything. With --targets
## (CI, every push) each farm is held to data/perf_targets.json: "perf targets: all met" or "PERF TARGETS MISSED"
## and the exit code 1, each miss with what its long frames went to.

const SETTLE_LIMIT := 4000     # frames waited at most for a farm to stand
const PROCESS_RUNS := 30       # calls timed for each script's _process
const TOP_SCRIPTS := 15        # scripts listed by cost
const PLAYED_DAYS := 30        # days the "played" farm is played by the goal bot first
const SEED := 7
const TARGETS := "res://data/perf_targets.json"
const BOT := preload("res://tools/balance_sim.gd")

var _main: Node
var _rounds := 1
var _farms: PackedStringArray = ["new", "played", "showcase", "filled"]
var _report := {}
var _errors := 0
var _frames_each := 0          # frames each scene plays (--frames; 0: ScenePlayer's own)
var _hold := false             # --targets: hold the times to TARGETS and fail when one is missed (CI)
var _scale := 1.0              # this machine's slowness against the runner the targets were set on
var _player: ScenePlayer        # plays each scene and times it (shared with the phone benchmark)


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
		elif a.begins_with("--frames="):
			_frames_each = maxi(10, int(a.trim_prefix("--frames=")))
		elif a == "--targets":
			_hold = true
	var counter := Counter.new()
	OS.add_logger(counter)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Game.saving_enabled = false
	seed(SEED)   # (the same spots and things each run: a target holds the same scene every time)
	PerfReadout.timing = true
	var t0 := Time.get_ticks_usec()
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_player = ScenePlayer.new(_main)
	_player.uncapped = true
	if _frames_each > 0:
		_player.frames = _frames_each
	_scale = _machine_scale()
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
	var missed: Array[String] = []
	if _hold:
		missed = _missed()
	if _hold:
		if missed.is_empty() and counter.count == 0:
			print("perf targets: all met (times scaled by %.2f for this machine)" % _scale)
		else:
			if counter.count > 0:
				missed.append("%d script errors" % counter.count)
			print("PERF TARGETS MISSED (%d): %s" % [missed.size(), "; ".join(PackedStringArray(missed))])
	get_tree().quit(1 if not missed.is_empty() or (_hold and counter.count > 0) else 0)


## How much slower this machine ran TestSuite's fixed work than the runner the targets were set on (1: as fast or
## faster; a faster machine is never scaled up, so a target stays a target). Times are scaled down by it.
func _machine_scale() -> float:
	var best := INF
	for t in TestSuite.TIMING_TRIES:
		var began := Time.get_ticks_usec()
		TestSuite._yardstick()
		best = minf(best, (Time.get_ticks_usec() - began) / 1000.0)
	return maxf(best / TestSuite.YARDSTICK_MS, 1.0)


## Every target in TARGETS a farm played here missed: each scene's longest frame (scaled to the runner's speed),
## the scripts' cost a frame, the farm's opening.
func _missed() -> Array[String]:
	var t: Dictionary = Game.read_json(TARGETS)
	var out: Array[String] = []
	for farm: String in _farms:
		if not _report.has(farm):
			continue
		var fr: Dictionary = _report[farm]
		for scenes: Dictionary in fr["rounds"]:
			for scene: String in scenes:
				var most := float((t.get("farm_scenes", {}) as Dictionary).get(farm, {}).get(scene,
					(t.get("scenes", {}) as Dictionary).get(scene, t.get("default_max_ms", INF))))
				var ms := float(scenes[scene]["max"]) / _scale
				if ms > most:
					out.append("%s %s: a %.0f ms frame (at most %.0f): %s" % [farm, scene, ms, most,
						" | ".join(PackedStringArray(scenes[scene].get("long_frames", [])))])
		var scripts := 0.0
		for row: Array in fr.get("scripts", []):
			scripts += float(row[2])
		scripts /= _scale
		var most_scripts := float((t.get("scripts_ms", {}) as Dictionary).get(farm, INF))
		if scripts > most_scripts:
			out.append("%s: the scripts cost %.2f ms a frame (at most %.2f)" % [farm, scripts, most_scripts])
		var open := float(fr["open"]["open_ms"]) / _scale
		var most_open := float((t.get("open_ms", {}) as Dictionary).get(farm, INF))
		if open > most_open:
			out.append("%s: opening took %.0f ms (at most %.0f)" % [farm, open, most_open])
	return out


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
	_player.view()
	for r in _rounds:
		var scenes := {}
		for scene in ScenePlayer.SCENES:
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
		if ms > ScenePlayer.HITCH_MS * 2.0:
			print("SESSION opening   long frame %.0f ms: %s" % [ms, ScenePlayer.parts_line(parts, ms, FrameClock.process_ms())])
		last = now
	return {"ms": (last - t0) / 1000.0, "frames": times.size(), "longest_ms": times.max() if times.size() else 0.0}


## One scene: what it does each frame, its frames timed, memory before and after.
func _scene(farm: String, scene: String) -> Dictionary:
	var before := _counts()
	var out := await _player.play(scene)
	var after := _counts()
	out["mem_mb"] = after["mem_mb"]
	out["mem_change_mb"] = snappedf(after["mem_mb"] - before["mem_mb"], 0.01)
	out["nodes_change"] = after["nodes"] - before["nodes"]
	out["objects_change"] = after["objects"] - before["objects"]
	print(("SESSION %s %s: n=%d p50=%.1f p95=%.1f p99=%.1f low1=%.1f max=%.1f hitches=%d over%d=%d scripts=%.2f"
		+ " mem%+.1fMB nodes%+d") % [farm, scene, out["frames"], out["p50"], out["p95"], out["p99"], out["low1"],
		out["max"], out["hitches"], int(ScenePlayer.HITCH_MS), out["over_ms"], out["scripts_p50"],
		out["mem_change_mb"], out["nodes_change"]])
	for note: String in out["long_frames"]:
		print("SESSION %s %s   long frame %s" % [farm, scene, note])
	return out


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
