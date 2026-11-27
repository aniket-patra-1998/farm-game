class_name LoadBenchmark
extends Node
## Measures loading and smoothness on the device it runs on (a phone, not a desktop: the cloud renders in software
## and cannot judge it). It opens the showcase farm cold, goes back to your own farm, opens the showcase again
## warm, then plays at the playing zoom for a few seconds, and reports for each: when every thing was built, when
## the loading cover lifted (the farm seen whole), the long frames on the way (a first draw of a material, its
## shaders made, shows as one), and the frame times and draws while playing. One JSON line in the log ("BENCH ")
## and in user://load_benchmark.json, written again after every phase ("done" false until the end, the newest line
## last), so a phone run cut short still reports what it measured; a summary for Settings > Testing.
## Runs by itself in a build exported with the "benchmark" feature (the benchmark APK, Firebase Test Lab), or from
## Settings > Testing. Never touches the player's own save (saving is off while it runs).

signal finished(report: Dictionary)

const FILE := "user://load_benchmark.json"
const FEATURE := StartMarks.BENCHMARK_FEATURE   # (an export feature tag)
const MARK := "BENCH "           # not-ui (what starts the report's log line; phone_bench.yml reads it)
const LONG_FRAME_MS := 100.0     # a frame this long is a stall (a material drawn the first time, a load)
const PLAY_SECONDS := 5.0        # playing at the playing zoom, measured
const PLAY_ZOOM := 1.6           # the camera zoom a player farms at
const GPU_FRAMES := 15           # frames timed for each GPU median of the owner sweep
const GPU_SETTLE := 4            # frames waited first (the GPU's timestamps lag a few frames)
const MOST_WAIT_SECONDS := 90.0  # never wait longer than this for one phase
const SPLIT_OWNERS := ["Ground3D"]   # not-ui (owners whose GPU time is told part by part: owner_of)
const SCENE_FRAMES := 30         # frames each scene plays on a phone (about 3 seconds on the A05s)
const PANEL_FRAMES := 5          # frames each panel stays open
const PART_MARK := "BENCH_PART "   # not-ui (a part of the report on a line of its own: _tell)
const PARTS := ["gpu", "scenes", "filled", "filled_play", "filled_scenes", "start"]
const LINE_MOST := 3000          # a part longer than this goes a line for each of its own parts
## The ground's shader changed one part at a time (_ground_tries): [the name, the code, what it becomes].
const GROUND_TRIES := [
	["ground_unlit", "render_mode cull_disabled",   # not-ui (both shaders: per pixel and per corner)
		"render_mode unshaded, cull_disabled"],   # not-ui
	["ground_no_grain", "fine = noise(p * 7.3);", "fine = 0.5;"],   # not-ui
	["ground_no_shade", "vec2 sw = texture(shade_map, suv).rg;", "vec2 sw = vec2(0.0);"]]   # not-ui
const FILLED_SCENES: Array[String] = ["still", "pan", "place", "harvest", "night"]   # on the full farm

var _main: Node


## Notes that the start reached `step` now (StartMarks.mark, which the start-up scripts call: they never name
## this script, so it is not compiled before the first screen).
static func start_mark(step: String) -> void:
	StartMarks.mark(step)


## The start's steps so far, in ms since the engine began, for the report's "start": the engine up (the first
## autoload, StartClock), the scripts compiled (Game made), its systems made, the other autoloads made, the
## catalog, the data and the save loaded (Game ready), the main scene's turn (main made, its 3D world, its HUD,
## main built). Where a phone's startup_ms goes.
static func start_marks() -> Dictionary:
	return StartMarks.marks()


## Whether this build runs the benchmark by itself on start (the benchmark APK).
static func wanted() -> bool:
	return OS.has_feature(FEATURE)


## Starts the benchmark on `main` (the game's main scene); `finished` tells the report.
static func start(main: Node) -> LoadBenchmark:
	var b := LoadBenchmark.new()
	b._main = main
	main.add_child(b)
	b._run.call_deferred()
	return b


func _run() -> void:
	var report := {"device": _device(), "startup_ms": Time.get_ticks_msec(), "start": start_marks(), "done": false}
	_tell(report)   # (the report so far after every phase: a phone run cut short still says what it measured)
	var saving := Game.saving_enabled
	Game.saving_enabled = false
	AutoQuality.paused = true   # (one level from start to end: a level stepped down halfway mixed two in one number)
	PerfReadout.timing = true   # (a long frame says what it went to)
	await _until_whole()
	report["own_farm_first"] = {"ms_since_start": Time.get_ticks_msec()}
	_tell(report)
	report["showcase_cold"] = await _phase(func() -> void: Game.open_showcase())
	_tell(report)
	report["own_farm"] = await _phase(func() -> void: Game.open_own_farm())
	_tell(report)
	report["showcase_warm"] = await _phase(func() -> void: Game.open_showcase())
	_tell(report)
	report["play"] = await _play()
	_tell(report)
	report["gpu"] = await _gpu_by_owner()
	_tell(report)
	report["scenes"] = await _scenes()
	_tell(report)
	report["filled"] = await _phase(func() -> void:
		Game.open_showcase()
		ShowcaseFarm.fill(Game))
	report["filled_play"] = await _play()
	report["filled_scenes"] = await _scenes(FILLED_SCENES)
	_tell(report)
	AutoQuality.paused = false
	PerfReadout.timing = false
	Game.open_own_farm()
	Game.saving_enabled = saving
	report["done"] = true
	_tell(report)
	finished.emit(report)
	if wanted():
		get_tree().quit()


## The report so far, as the log line (phone_bench.yml keeps a log's done line, else its longest) and in FILE.
static func line_of(report: Dictionary) -> String:
	return MARK + JSON.stringify(report)


func _tell(report: Dictionary) -> void:
	var line := line_of(report)
	# (A phone's log cuts a line at about 4 KB: the big parts go on lines of their own, PART_MARK and their key,
	# and phone_bench.yml puts them back together.)
	var core := {}
	for key: String in report:
		if not PARTS.has(key):
			core[key] = report[key]
		elif report[key] is Dictionary and JSON.stringify(report[key]).length() > LINE_MOST:
			for sub: String in report[key]:   # (each scene on its own line: "scenes.place")
				print("%s%s.%s %s" % [PART_MARK, key, sub, JSON.stringify(report[key][sub])])
		else:
			print("%s%s %s" % [PART_MARK, key, JSON.stringify(report[key])])
	print(line_of(core))
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(line.trim_prefix(MARK))


## One farm opening: `open` lays it out; then the time until every thing is built, until the cover lifts (the
## farm seen whole), and the long frames on the way.
func _phase(open: Callable) -> Dictionary:
	var began := Time.get_ticks_usec()
	open.call()
	var built := -1.0
	var frames := 0
	var long_frames := 0
	var long_ms := 0.0
	var longest := 0.0
	var last := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - began) / 1e6 < MOST_WAIT_SECONDS:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		frames += 1
		longest = maxf(longest, ms)
		if ms >= LONG_FRAME_MS:
			long_frames += 1
			long_ms += ms
		if built < 0.0 and Objects3D.progress_in(get_tree()) >= 1.0 and _all_settled():
			built = (now - began) / 1000.0
		if built >= 0.0 and LoadingCover.covering == 0:
			break
	return {"built_ms": roundi(built), "whole_ms": roundi((Time.get_ticks_usec() - began) / 1000.0),
		"frames": frames, "long_frames": long_frames, "long_ms": roundi(long_ms), "longest_ms": roundi(longest),
		"objects": Game.objects.size()}


## Plays at the playing zoom for PLAY_SECONDS: frame times (average, 95th percentile, longest), draws, and the level
## and frame cap played at (the device's level at start may since have been stepped down: `quality_start` says the
## level it began on). Where each frame goes, as medians (`split`): the renderer's CPU and GPU time for the farm's
## view (the GPU's own timestamps), and the scripts' process and physics time, so a phone's slow frame says whether
## the GPU or the CPU is the wall; with the draws and triangles' medians (the maxima above may come from a level
## stepped down from).
func _play() -> Dictionary:
	var cam: FarmCamera = _main.get("camera")
	var grid: FarmGrid = _main.get("grid")
	if cam != null and grid != null:
		cam.snap(grid.to_global(grid.center_of(Game.index_of(Game.farm_size / 2, Game.farm_size / 2))), PLAY_ZOOM)
	for k in 10:
		await get_tree().process_frame
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var quality_start := Quality.level()
	var samples := {"render_cpu_ms": [], "render_gpu_ms": [], "script_ms": [], "physics_ms": [], "draws": [],
		"triangles": []}
	var times: Array[float] = []
	var draws := 0
	var tris := 0
	var last := Time.get_ticks_usec()
	var began := last
	while (Time.get_ticks_usec() - began) / 1e6 < PLAY_SECONDS:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		var d := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var t := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		draws = maxi(draws, d)
		tris = maxi(tris, t)
		samples["draws"].append(float(d))
		samples["triangles"].append(float(t))
		samples["render_cpu_ms"].append(RenderingServer.viewport_get_measured_render_time_cpu(rid)
			+ RenderingServer.get_frame_setup_time_cpu())
		samples["render_gpu_ms"].append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		samples["script_ms"].append(FrameClock.process_ms())   # (this frame's: the engine's own is a second's worst)
		samples["physics_ms"].append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	RenderingServer.viewport_set_measure_render_time(rid, false)
	times.sort()
	var sum := 0.0
	for t in times:
		sum += t
	return {"avg_ms": snappedf(sum / maxf(times.size(), 1.0), 0.1),
		"p95_ms": snappedf(times[int(times.size() * 0.95)] if not times.is_empty() else 0.0, 0.1),
		"longest_ms": snappedf(times[-1] if not times.is_empty() else 0.0, 0.1), "draws": draws, "triangles": tris,
		"quality": Quality.level(), "max_fps": Engine.max_fps,   # (the level played at: AutoQuality may have moved it)
		"quality_start": quality_start, "split": medians(samples)}


## The farm played as a player plays it (ScenePlayer: the same scenes as tools/session_probe on a PC), each scene's
## frames: percentiles, the longest, hitches, and its long frames named by part (as a phone has them).
func _scenes(which: Array[String] = ScenePlayer.SCENES) -> Dictionary:
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)   # (each long frame's render time in its note)
	var player := ScenePlayer.new(_main)
	player.frames = SCENE_FRAMES
	player.panel_frames = PANEL_FRAMES
	player.place_count = 3
	player.place_frames = 10
	player.view()
	var out := {}
	for scene in which:
		var s := await player.play(scene)
		s.erase("worst_at")
		out[scene] = s
	RenderingServer.viewport_set_measure_render_time(rid, false)
	return out


## Where the GPU's time goes at the playing view (the phone's frame is GPU-bound: run 21): the farm view's GPU time
## (median of GPU_FRAMES frames, ms) with everything drawn (`all`), then with each owner's meshes hidden (the
## nearest named script above a mesh: Animal3D, Objects3D, DecorLayer...) as the time that goes away, and with the
## 3D resolution halved (`half_scale`: what is left once fewer pixels are shaded; little change means the vertices
## or the draws are the cost, a big one the pixels). Last, `animals_posing`: the time that goes away while the
## animals stand as they are, still drawn (what animating them costs, apart from drawing them). Nothing is saved;
## everything is shown again and moves again after.
func _gpu_by_owner() -> Dictionary:
	var vp := get_viewport()
	var rid := vp.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var groups := {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is GeometryInstance3D and (n as GeometryInstance3D).is_visible_in_tree():
			var key := owner_of(n)
			if not groups.has(key):
				groups[key] = []
			groups[key].append(n)
	var all := await _gpu_median(rid)
	var out := {"all": all}
	for key: String in groups:
		for n: GeometryInstance3D in groups[key]:
			n.visible = false
		var without := await _gpu_median(rid)
		for n: GeometryInstance3D in groups[key]:
			if is_instance_valid(n):
				n.visible = true
		out[key] = snappedf(all - without, 0.1)
	var scale := vp.scaling_3d_scale
	vp.scaling_3d_scale = scale * 0.5
	out["half_scale"] = await _gpu_median(rid)
	vp.scaling_3d_scale = scale
	out.merge(await _ground_tries(rid, all))
	out["context"] = _context()
	# What animating the animals costs the GPU, apart from drawing them: the time that goes away while they stand
	# as they are (an animal's shapes are blended again whenever it is posed). Measured between two fresh readings
	# of the whole view, since a phone's GPU time drifts over the sweep.
	var before := await _gpu_median(rid)
	Animal3D.posing = false
	var still := await _gpu_median(rid)
	Animal3D.posing = true
	out["animals_posing"] = snappedf((before + await _gpu_median(rid)) * 0.5 - still, 0.1)
	RenderingServer.viewport_set_measure_render_time(rid, false)
	return out


## What the sweep saw (the same farm differs by the hour and the weather): the weather now, how wet and snowy the
## ground is, the local hour, the lights lit and the ground's shader.
func _context() -> Dictionary:
	var lights := 0
	for n: Node in get_tree().root.find_children("*", "Light3D", true, false):   # not-ui
		if (n as Light3D).is_visible_in_tree():
			lights += 1
	var shader := ""
	var grounds := get_tree().root.find_children("*", "Ground3D", true, false)   # not-ui
	if not grounds.is_empty():
		var lawn := grounds[0].get_node_or_null("Lawn") as MeshInstance3D   # not-ui
		var m := _face_material(lawn) if lawn != null else null
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
			shader = (m as ShaderMaterial).shader.resource_path.get_file()
	return {"weather": Game.weather_state_at(Game.now()), "wetness": ShaderGlobals.value(&"wetness"),
		"snow": ShaderGlobals.value(&"snow_cover"), "hour": snappedf(DayCycle.local_hour(Game.now(),
		DayCycle.device_bias_minutes()), 0.1), "lights": lights, "ground_shader": shader}


## What the ground's own shading costs (it was 41 of the A05s's 101 ms): the GPU time that goes away with its
## painted look turned off (`ground_live`: negative, what the bake saves), with the lawn and meadow drawn in one
## plain unlit colour (`ground_plain`: what its shader and lighting cost beyond filling the pixels), and with only
## the farm's view of it shrunk (none). Everything is put back after; nothing is saved.
func _ground_tries(rid: RID, all: float) -> Dictionary:
	var out := {}
	var grounds := get_tree().root.find_children("*", "Ground3D", true, false)   # not-ui
	if grounds.is_empty():
		return out
	var ground := grounds[0] as Node3D
	var faces: Array[MeshInstance3D] = []
	for name in ["Lawn", "Meadow"]:   # not-ui
		var n := ground.get_node_or_null(name) as MeshInstance3D
		if n != null:
			faces.append(n)
	var was: Array = faces.map(_face_material)
	var baked: Array = []
	for m: Variant in was:
		baked.append((m as ShaderMaterial).get_shader_parameter("use_bake") if m is ShaderMaterial else null)
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("use_bake", false)
	out["ground_live"] = snappedf(all - await _gpu_median(rid), 0.1)
	for k in was.size():
		if was[k] is ShaderMaterial and baked[k] != null:
			(was[k] as ShaderMaterial).set_shader_parameter("use_bake", baked[k])
	# The ground's own shader changed one part at a time (a copy, put back after): unlit, without the fine grain
	# over the painted look, without the shade and wear under things.
	for t: Array in GROUND_TRIES:
		var swapped: Array = []
		for m: Variant in was:
			if not m is ShaderMaterial:
				swapped.append(null)
				continue
			var code := ((m as ShaderMaterial).shader as Shader).code
			if not code.contains(str(t[1])):
				swapped.append(null)
				continue
			var shader := Shader.new()
			shader.code = code.replace(str(t[1]), str(t[2]))
			var copy := (m as ShaderMaterial).duplicate() as ShaderMaterial
			copy.shader = shader
			swapped.append(copy)
		for k in faces.size():
			if swapped[k] != null:
				_set_face_material(faces[k], swapped[k])
		out[str(t[0])] = snappedf(all - await _gpu_median(rid), 0.1)
		for k in faces.size():
			_set_face_material(faces[k], was[k])
	var plain := StandardMaterial3D.new()
	plain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plain.albedo_color = Color(0.3, 0.45, 0.2)
	for n in faces:
		_set_face_material(n, plain)
	out["ground_plain"] = snappedf(all - await _gpu_median(rid), 0.1)
	for k in faces.size():
		_set_face_material(faces[k], was[k])
	out["ground_baked"] = baked.map(func(b: Variant) -> String: return str(b))
	return out


static func _face_material(n: MeshInstance3D) -> Material:
	return n.material_override if n.material_override != null else n.get_surface_override_material(0)


static func _set_face_material(n: MeshInstance3D, m: Material) -> void:
	if n.material_override != null or n.get_surface_override_material(0) == null:
		n.material_override = m
	else:
		n.set_surface_override_material(0, m)


## The farm view's median GPU time over GPU_FRAMES frames, after GPU_SETTLE frames (its timestamps lag a few).
func _gpu_median(rid: RID) -> float:
	for k in GPU_SETTLE:
		await get_tree().process_frame
	var times := []
	for k in GPU_FRAMES:
		await get_tree().process_frame
		times.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	return float(medians({"gpu": times})["gpu"])


## The nearest named script above a node (itself included): whose mesh it is. "(none)" when no script names it.
## The ground is split into its parts ("Ground3D/Tufts"): it was 41 of the A05s's 101 ms, and which part costs is
## the question.
static func owner_of(n: Node) -> String:
	var a: Node = n
	var below: Node = null
	while a != null:
		var sc: Script = a.get_script()
		if sc != null and sc.get_global_name() != &"":
			var key := str(sc.get_global_name())
			return key + "/" + str(below.name) if SPLIT_OWNERS.has(key) and below != null else key
		below = a
		a = a.get_parent()
	return "(none)"   # not-ui (a measurement key)


## The median of each list of samples, to a tenth (an empty list: 0).
static func medians(samples: Dictionary) -> Dictionary:
	var out := {}
	for key in samples:
		var list: Array = (samples[key] as Array).duplicate()
		list.sort()
		out[key] = snappedf(float(list[list.size() / 2]), 0.1) if not list.is_empty() else 0.0
	return out


func _until_whole() -> void:
	var began := Time.get_ticks_msec()
	while (Objects3D.progress_in(get_tree()) < 1.0 or not _all_settled() or LoadingCover.covering > 0) \
			and Time.get_ticks_msec() - began < MOST_WAIT_SECONDS * 1000.0:
		await get_tree().process_frame


func _all_settled() -> bool:
	for o: Objects3D in get_tree().get_nodes_in_group(Objects3D.GROUP):
		if not o.settled():
			return false
	return true


func _device() -> Dictionary:
	return {"model": OS.get_model_name(), "os": OS.get_name() + " " + OS.get_version(),
		"gpu": RenderingServer.get_video_adapter_name(), "gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"cores": OS.get_processor_count(), "screen": str(DisplayServer.screen_get_size()),
		"quality": Quality.level(), "renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))}


## The report in a few lines, for Settings > Testing.
static func summary(report: Dictionary) -> String:
	var lines: Array[String] = []
	var d: Dictionary = report.get("device", {})
	lines.append("%s, %s" % [d.get("model", "?"), d.get("gpu", "?")])   # not-ui (a measurement report)
	for phase in ["showcase_cold", "own_farm", "showcase_warm"]:
		var p: Dictionary = report.get(phase, {})
		lines.append("%s: built %s ms, whole %s ms, %s long frames (%s ms)" % [phase, p.get("built_ms"),   # not-ui
			p.get("whole_ms"), p.get("long_frames"), p.get("long_ms")])
	var play: Dictionary = report.get("play", {})
	lines.append("play: %s ms a frame (95%%: %s), %s draws" % [play.get("avg_ms"), play.get("p95_ms"),   # not-ui
		play.get("draws")])
	var split: Dictionary = play.get("split", {})
	lines.append("frame: render CPU %s ms, GPU %s ms, scripts %s ms" % [split.get("render_cpu_ms"),   # not-ui
		split.get("render_gpu_ms"), split.get("script_ms")])
	return "\n".join(lines)
