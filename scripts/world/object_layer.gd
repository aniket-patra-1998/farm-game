class_name ObjectLayer
extends Node2D
## Everything standing on the farm, one FarmPiece node each, drawn in correct depth order.
##
## Depth: on an isometric grid a 1x1 tile (r, c) is drawn by its diagonal r + c. A footprint of w x h
## tiles starting at (r, c) must come after every tile that overlaps it on screen from behind and before
## every tile in front; for footprints whose sides differ by at most one tile that is exactly "after the
## diagonal r + c + min(w, h) - 1". So plots get z = 2 * (r + c) and objects 2 * (r + c + min(w, h) - 1) + 1,
## which keeps tiles and objects correctly interleaved without any per-frame sorting.

const Z_BASE := -2000   # pieces sit below the overlay and effects (z >= 0) and above the ground

var grid: FarmGrid
var pieces := {}        # "p<index>" or "o<uid>" -> FarmPiece
var _sync_queued := false
var _ready_list: Array = []  # pieces showing something ready, kept fresh by refresh_all and sync


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 1.0  # crops change stage and things become ready over time
	timer.autostart = true
	timer.timeout.connect(refresh_all)
	add_child(timer)


static func plot_z(row: int, col: int) -> int:
	return Z_BASE + 2 * (row + col)


static func object_z(row: int, col: int, fp: Vector2i) -> int:
	return Z_BASE + 2 * (row + col + mini(fp.x, fp.y) - 1) + 1


## Coalesces many change signals in one frame into a single sync.
func queue_sync() -> void:
	if not _sync_queued:
		_sync_queued = true
		call_deferred("sync")


## A single plot changed: add, drop or redraw just its piece.
func on_plot(i: int) -> void:
	if i < 0:
		queue_sync()
		return
	_sync_plot(i)


func sync() -> void:
	_sync_queued = false
	var want := {}
	var n := Game.farm_size
	for r in n:
		for c in n:
			var i := Game.index_of(r, c)
			if _wants_plot(i):
				want["p%d" % i] = true
	var lifted := int(grid.placing.get("uid", -1))
	for o in Game.objects:
		if int(o["uid"]) != lifted:
			want["o%d" % int(o["uid"])] = true
	for key in pieces.keys():
		if not want.has(key):
			(pieces[key] as FarmPiece).queue_free()
			pieces.erase(key)
	for key in want:
		var p: FarmPiece = pieces.get(key)
		if p == null:
			p = FarmPiece.new()
			p.grid = grid
			if str(key).begins_with("p"):
				p.plot = int(str(key).substr(1))
				p.plants = CropPlants.new()
				p.plants.piece = p
				p.plants.position = Vector2(0, -PlaceholderArt.SLAB)
				p.add_child(p.plants)
			else:
				p.uid = int(str(key).substr(1))
			p.phase = randf() * TAU
			p.next_move = randf_range(1.0, 8.0)
			pieces[key] = p
			add_child(p)
		_place(p)
		p.refresh()
	_ready_list = pieces.values().filter(func(p): return p.is_ready())


func refresh_all() -> void:
	wind = {"clear": 0.6, "partly_cloudy": 0.8, "cloudy": 1.0, "rain": 1.5, "storm": 2.4, "fog": 0.35, "snow": 0.9}.get(Game.weather()["state"], 0.6)
	for p in pieces.values():
		(p as FarmPiece).refresh()
	_ready_list = pieces.values().filter(func(p): return p.is_ready())


## Every piece redrawn (art arrived, day changed...).
func redraw_all() -> void:
	for p in pieces.values():
		(p as FarmPiece).force_redraw()


## Pieces showing something ready to collect (the overlay twinkles over them).
func ready_pieces() -> Array:
	return _ready_list.filter(func(p): return is_instance_valid(p) and p.is_ready())


func _wants_plot(i: int) -> bool:
	return Game.phase(i) != GameState.Phase.GRASS and not Game.is_occupied(i)


func _sync_plot(i: int) -> void:
	var key := "p%d" % i
	var has := pieces.has(key)
	if _wants_plot(i) != has:
		queue_sync()
	elif has:
		var p := pieces[key] as FarmPiece
		p.refresh()
		if p.is_ready() and not _ready_list.has(p):
			_ready_list.append(p)


func _place(p: FarmPiece) -> void:
	if p.plot >= 0:
		p.z_index = plot_z(int(p.plot / float(GameState.MAX_SIZE)), p.plot % GameState.MAX_SIZE)
		p.base = grid.center_of(p.plot)
	else:
		var o := Game.object_by_uid(p.uid)
		var fp := Game.footprint(o["id"])
		p.z_index = object_z(int(o["row"]), int(o["col"]), fp)
		var g := grid.corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
		var new_base := (g[0] + g[2]) / 2.0
		if new_base != p.base:
			p.wander = Vector2.ZERO
			p.wander_to = Vector2.ZERO
		p.base = new_base
		p.motion = motion_of(o)
		p.flip = -1.0 if o.get("flip", false) else 1.0
		if p.motion != "animal" and p.motion != "bird":
			p.scale = Vector2(p.flip, 1.0)
	p.position = p.base + p.wander


## How a thing moves: animals wander and breathe, birds also peck, trees sway; buildings stay put.
static func motion_of(o: Dictionary) -> String:
	if o.get("stray", false):
		return "animal"
	match Game.kind_of(o):
		"animal":
			var fam := str(Game.item_data(o["id"]).get("family", ""))
			return "bird" if fam in ["chicken", "duck", "goose", "turkey"] else "animal"
		"tree":
			return "tree"
	return ""


# ---------------------------------------------------------------- motion (FarmVille's farm was never still)

const WANDER := 0.22      # how far an animal strays from its tile centre, in tiles
const WALK_SPEED := 16.0  # px per second
var wind := 0.6           # from the weather: how hard plants and trees sway
var _clock := 0.0


func _process(delta: float) -> void:
	_clock += delta
	var t := _clock
	for v in pieces.values():
		var p := v as FarmPiece
		if p.plants != null:
			# Plants sway from the stem; each plot on its own beat, harder in wind.
			p.plants.skew = sin(t * 1.7 + p.phase) * 0.05 * wind
			continue
		match p.motion:
			"tree":
				p.skew = sin(t * 0.8 + p.phase) * 0.018 * wind
			"animal", "bird":
				_animate_animal(p, t, delta)


func _animate_animal(p: FarmPiece, t: float, delta: float) -> void:
	p.next_move -= delta
	if p.next_move <= 0.0:
		# Pick a new spot near home, or stay a while.
		p.next_move = randf_range(3.0, 11.0)
		if randf() < 0.6:
			var a := randf() * TAU
			var r := randf() * WANDER
			p.wander_to = Vector2(cos(a) * r * FarmGrid.TILE_W / 2.0, sin(a) * r * FarmGrid.TILE_H / 2.0)
	var to := p.wander_to - p.wander
	var walking := to.length() > 0.5
	if walking:
		var step := minf(to.length(), WALK_SPEED * delta)
		p.wander += to.normalized() * step
		if absf(to.x) > 0.5:
			p.facing = -1.0 if to.x < 0.0 else 1.0
	var hop := absf(sin(t * 9.0 + p.phase)) * 2.5 if walking else 0.0
	p.position = p.base + p.wander - Vector2(0, hop)
	var breathe := 1.0 + 0.018 * sin(t * 2.2 + p.phase)
	p.scale = Vector2(p.facing * p.flip, breathe)
	if p.motion == "bird" and not walking:
		# A quick peck every few seconds.
		var peck := maxf(0.0, sin(t * 1.3 + p.phase * 3.0) - 0.92) * 12.0
		p.rotation = peck * 0.25 * p.facing
	else:
		p.rotation = 0.0
