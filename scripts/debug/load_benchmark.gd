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
const FEATURE := "benchmark"     # not-ui (an export feature tag)
const MARK := "BENCH "           # not-ui (what starts the report's log line; phone_bench.yml reads it)
const LONG_FRAME_MS := 100.0     # a frame this long is a stall (a material drawn the first time, a load)
const PLAY_SECONDS := 5.0        # playing at the playing zoom, measured
const PLAY_ZOOM := 1.6           # the camera zoom a player farms at
const MOST_WAIT_SECONDS := 90.0  # never wait longer than this for one phase
const ENGINE_MARK := &"start_clock_ms"   # the Engine meta autoload/start_clock.gd sets as the engine is up


## When the start's steps were done, in ms since the engine began (start_mark), for the report's "start": the
## engine up (the first autoload, StartClock), the scripts compiled (Game made), its systems made, the other
## autoloads made, the catalog, the data and the save loaded (Game ready), the main scene's turn (main made, its
## 3D world, its HUD, main built). Where a phone's startup_ms goes.
static var _start_marks := {}

var _main: Node


## Notes that the start reached `step` now, the first time only (a farm made again later is not the start; a
## few calls, cheap, every build).
static func start_mark(step: String) -> void:
	if not _start_marks.has(step):
		_start_marks[step] = Time.get_ticks_msec()


## The start's steps so far (start_mark).
static func start_marks() -> Dictionary:
	var marks := _start_marks.duplicate()
	if Engine.has_meta(ENGINE_MARK):
		marks["engine"] = int(Engine.get_meta(ENGINE_MARK))
	return marks


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
	print(line)
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


## Plays at the playing zoom for PLAY_SECONDS: frame times (average, 95th percentile, longest) and draws.
func _play() -> Dictionary:
	var cam: FarmCamera = _main.get("camera")
	var grid: FarmGrid = _main.get("grid")
	if cam != null and grid != null:
		cam.snap(grid.to_global(grid.center_of(Game.index_of(Game.farm_size / 2, Game.farm_size / 2))), PLAY_ZOOM)
	for k in 10:
		await get_tree().process_frame
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
		draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		tris = maxi(tris, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	times.sort()
	var sum := 0.0
	for t in times:
		sum += t
	return {"avg_ms": snappedf(sum / maxf(times.size(), 1.0), 0.1),
		"p95_ms": snappedf(times[int(times.size() * 0.95)] if not times.is_empty() else 0.0, 0.1),
		"longest_ms": snappedf(times[-1] if not times.is_empty() else 0.0, 0.1), "draws": draws, "triangles": tris}


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
	return "\n".join(lines)
