extends Node3D
## The look test: every item in every state it can be seen in, by day and by night, drawn and checked without
## anyone looking. A case FAILS when it is plainly broken: nothing drawn, or one thing filling the whole cell. It
## is reported as CHANGED when its look has moved from the one on record (`tests/look_refs.json`: a coarse 6x6
## colour grid per case, forgiving of small renderer differences), so an unintended change to a model, a
## material or the lighting shows up as a list of names. Writes ci_shots/look_report.txt; pages with a finding
## are saved as ci_shots/look_<day|night>_<n>.png. Needs a renderer:
##   xvfb-run godot --rendering-method gl_compatibility --path . res://tools/look_test.tscn
## Options after `--`:  --update  rewrite the record from this run (after a look change you meant to make)
##                      --strict  CHANGED cases also fail the run     --shots  save every page
##                      --only=text  only cases whose id contains the text

const COLS := 6
const ROWS := 4
const WINDOW := Vector2i(1920, 1080)
const CELL_PX := 240.0              # a cell on screen
const CELL_UNITS := 4.2             # the same, in world units across the ground
const FOOT_FORESHORTEN := 0.5774    # a ground distance seen at the iso pitch (sin 35.26 degrees)
const SCALE := 0.62                 # of the contact sheets' size: a cell here is tighter than theirs
const CROP_HALF := 118              # pixels either side of a cell's centre that are looked at
const BG_DISTANCE := 0.05           # colour distance from the background that counts as the model
const MIN_COVER := 0.003            # less of its cell than this and it is not there
const GRID := 4                     # the coarse look: GRID x GRID mean colours
const DRIFT := 0.10                 # mean difference (0..1) of that grid that counts as changed (shaders move with time)
const MAX_COVER := 0.85             # more of its cell than this and it is far too big (or something fills the view)
const REFS := "res://tests/look_refs.json"
const HEX := "0123456789abcdef"

var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _refs := {}
var _fresh := {}
var _failed: Array[String] = []
var _changed: Array[String] = []
var _new: Array[String] = []
var _checked := 0
var _options := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		_options[arg.get_slice("=", 0)] = arg.get_slice("=", 1) if "=" in arg else "1"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ci_shots"))
	get_window().size = WINDOW
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = WINDOW.y / (CELL_PX / CELL_UNITS)
	add_child(_cam)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55, 35, 0)
	_sun.shadow_enabled = true
	add_child(_sun)
	var world := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("#cfe0ff")
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = _env
	add_child(world)
	Game.set_process(false)
	if FileAccess.file_exists(REFS):
		_refs = JSON.parse_string(FileAccess.get_file_as_string(REFS))
	var cases := LookModels.cases().filter(
		func(c: Dictionary) -> bool: return str(_options.get("--only", "")) in str(c["id"]))
	for night in [false, true]:
		_light(night)
		var per := COLS * ROWS
		for page in ceili(float(cases.size()) / per):
			await _page(night, page, cases.slice(page * per, (page + 1) * per))
	_finish()


func _light(night: bool) -> void:
	_sun.light_color = Color(0.62, 0.72, 1.0) if night else Color.WHITE
	_sun.light_energy = 0.25 if night else 1.0
	_env.ambient_light_energy = 0.2 if night else 0.55
	_env.background_color = Color("#1c2a3a") if night else Color("#8db864")
	ModelKit.set_window_glow(1.0 if night else 0.0)


## The ground position of a cell: a grid that is square on the screen (not on the ground).
func _cell_at(col: int, row: int) -> Vector3:
	var right := Vector3(1, 0, -1).normalized()
	var up := Vector3(-1, 0, -1).normalized()
	return right * (col - (COLS - 1) / 2.0) * CELL_UNITS + up * ((ROWS - 1) / 2.0 - row) * CELL_UNITS / FOOT_FORESHORTEN


func _page(night: bool, page: int, cases: Array) -> void:
	var holder := Node3D.new()
	add_child(holder)
	var spots: Array[Vector3] = []
	for k in cases.size():
		var at := _cell_at(k % COLS, k / COLS)
		spots.append(at)
		var c: Dictionary = cases[k]
		var node := LookModels.model(str(c["id"]), str(c["state"]), page * 100 + k)
		if node == null:
			continue
		var fp := Game.footprint(str(c["id"])) if not LookModels.is_crop(str(c["id"])) else Vector2i.ONE
		node.scale = Vector3.ONE * LookModels.fit_scale(str(c["id"])) * SCALE
		node.position = at - Vector3(fp.x, 0, fp.y) * node.scale.x / 2.0
		holder.add_child(node)
	_cam.look_at_from_position(Vector3(14, 14, 14), Vector3.ZERO)
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var before := _failed.size() + _changed.size()
	var bg := img.get_pixel(4, 4)
	for k in cases.size():
		var c: Dictionary = cases[k]
		_look_at(img, bg, spots[k] + Vector3(0, 0.9, 0), "%s|%s|%s" % [c["id"], c["state"], "night" if night else "day"])
	if _failed.size() + _changed.size() > before or _options.has("--shots"):
		img.save_png("res://ci_shots/look_%s_%d.png" % ["night" if night else "day", page])
	holder.queue_free()
	Game.set_objects([])
	await get_tree().process_frame


## Checks the cell round a point: what it covers, whether it fits, and what it looks like next to the record.
func _look_at(img: Image, bg: Color, world: Vector3, key: String) -> void:
	var centre := _cam.unproject_position(world)
	var rect := Rect2i(int(centre.x) - CROP_HALF, int(centre.y) - CROP_HALF, CROP_HALF * 2, CROP_HALF * 2) \
		.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var covered := 0
	var sums := PackedFloat32Array()
	sums.resize(GRID * GRID * 3)
	var counts := PackedInt32Array()
	counts.resize(GRID * GRID)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var p := img.get_pixel(x, y)
			if absf(p.r - bg.r) + absf(p.g - bg.g) + absf(p.b - bg.b) > BG_DISTANCE:
				covered += 1
			var gx := (x - rect.position.x) * GRID / rect.size.x
			var gy := (y - rect.position.y) * GRID / rect.size.y
			var cell := gy * GRID + gx
			sums[cell * 3] += p.r
			sums[cell * 3 + 1] += p.g
			sums[cell * 3 + 2] += p.b
			counts[cell] += 1
	_checked += 1
	if float(covered) / float(rect.size.x * rect.size.y) < MIN_COVER:
		_failed.append("%s: nothing is drawn" % key)
		return
	if float(covered) / float(rect.size.x * rect.size.y) > MAX_COVER:
		_failed.append("%s: fills the whole cell" % key)
	var sig := ""
	for i in GRID * GRID:
		for ch in 3:
			sig += "%x" % clampi(roundi(sums[i * 3 + ch] / maxf(counts[i], 1) * 15.0), 0, 15)
	_fresh[key] = sig
	if _refs.has(key):
		var diff := 0.0
		var old: String = _refs[key]
		for i in sig.length():
			diff += absf(HEX.find(sig[i]) - HEX.find(old[i])) / 15.0
		if diff / sig.length() > DRIFT:
			_changed.append("%s: looks different (%.3f)" % [key, diff / sig.length()])
	else:
		_new.append(key)


func _finish() -> void:
	var lines: Array[String] = ["checked %d cases: %d broken, %d changed, %d not on record" % [
		_checked, _failed.size(), _changed.size(), _new.size()]]
	for f in _failed:
		lines.append("BROKEN   " + f)
	for c in _changed:
		lines.append("CHANGED  " + c)
	if _new.size() > 0 and not _options.has("--update"):
		lines.append("NEW      %d cases have no record yet (run with --update)" % _new.size())
	if _options.has("--update"):
		var merged: Dictionary = _refs.duplicate()
		merged.merge(_fresh, true)
		FileAccess.open(REFS, FileAccess.WRITE).store_string(JSON.stringify(merged, "", true))
		lines.append("record rewritten: %d cases" % merged.size())
	var text := "\n".join(lines)
	print(text)
	FileAccess.open("res://ci_shots/look_report.txt", FileAccess.WRITE).store_string(text + "\n")
	var bad := _failed.size() > 0 or (_options.has("--strict") and (_changed.size() > 0 or _new.size() > 0))
	get_tree().quit(1 if bad else 0)
