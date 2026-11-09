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
var _ready: Array = []  # pieces showing something ready, kept fresh by refresh_all and sync


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
			else:
				p.uid = int(str(key).substr(1))
			pieces[key] = p
			add_child(p)
		_place(p)
		p.refresh()
	_ready = pieces.values().filter(func(p): return p.is_ready())


func refresh_all() -> void:
	for p in pieces.values():
		(p as FarmPiece).refresh()
	_ready = pieces.values().filter(func(p): return p.is_ready())


## Every piece redrawn (art arrived, day changed...).
func redraw_all() -> void:
	for p in pieces.values():
		(p as FarmPiece).force_redraw()


## Pieces showing something ready to collect (the overlay twinkles over them).
func ready_pieces() -> Array:
	return _ready.filter(func(p): return is_instance_valid(p) and p.is_ready())


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
		if p.is_ready() and not _ready.has(p):
			_ready.append(p)


func _place(p: FarmPiece) -> void:
	if p.plot >= 0:
		p.z_index = plot_z(int(p.plot / float(GameState.MAX_SIZE)), p.plot % GameState.MAX_SIZE)
	else:
		var o := Game.object_by_uid(p.uid)
		p.z_index = object_z(int(o["row"]), int(o["col"]), Game.footprint(o["id"]))
