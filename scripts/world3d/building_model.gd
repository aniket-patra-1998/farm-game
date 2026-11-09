class_name BuildingModel
extends RefCounted
## Builds a building in 3D from its description in data/building_models.json: a stone footing, walls with
## their pattern, a roof, a door and windows, white trim at the corners, and the features that make each
## kind of building its own (a coop on stilts with a ramp, a dairy's silo and loft door, a stable's row of
## half-doors, yards, troughs, hay, hives, a pond...). The node's origin is the footprint's back corner;
## x runs along its columns and z along its rows, one unit a tile.

const PATH := "res://data/building_models.json"
const PLINTH := 0.09
const DOOR := &"door_swing"   # meta on a door's hinge: which way it swings open
# A building site's stages, as shares of the materials put in (see build_site).
const SITE_FOOTING := 0.08
const SITE_FLOOR := 0.25
const SITE_BEAMS := 0.38
const SITE_WALLS := 0.45
const SITE_RAFTERS := 0.75
const SITE_BOARDS := 0.92
const STONE := Color("#9b958a")
const WOOD := Color("#8a5a36")
const DARK := Color("#3b2a20")
const HAY := Color("#e2c25a")
const FENCE := Color("#f1ece0")
const RAIL := Color("#a07446")
const GROUNDS := {"dirt": Color("#9a7a52"), "straw": Color("#d9bf6a"), "grass": Color("#79a845"),
	"mud": Color("#6e5236")}

static var _data := {}


## How a building is built at a size (`level`, 1 the smallest): its own description over the defaults,
## then each size's changes up to `level` laid on in turn (data "levels": {"2": {...}, "3": {...}}).
## A size's "drop" first removes features of those types; its "features" are added; anything else
## (body, roof, door: merged; windows, window_rows: replaced) changes the building itself.
static func spec(id: String, level := 1) -> Dictionary:
	_load()
	var out: Dictionary = (_data["default"] as Dictionary).duplicate(true)
	var own: Dictionary = ((_data.get("buildings", {}) as Dictionary).get(id, {}) as Dictionary).duplicate(true)
	var sizes: Dictionary = own.get("levels", {})
	own.erase("levels")
	_lay_on(out, own)
	for l in range(2, level + 1):
		var step: Dictionary = sizes.get(str(l), {})
		var dropped: Array = step.get("drop", [])
		out["features"] = (out.get("features", []) as Array).filter(
			func(f: Dictionary) -> bool: return not dropped.has(f.get("type")))
		(out["features"] as Array).append_array(step.get("features", []))
		var rest := step.duplicate(true)
		rest.erase("drop")
		rest.erase("features")
		_lay_on(out, rest)
	return out


## The sizes a building has changes for (2, 3...), from its description (tests check them).
static func sizes_of(id: String) -> Array:
	_load()
	var own: Dictionary = (_data.get("buildings", {}) as Dictionary).get(id, {})
	return (own.get("levels", {}) as Dictionary).keys().map(func(k: String) -> int: return int(k))


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"default": {}, "buildings": {}}
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(PATH + " is missing or not valid JSON")


static func _lay_on(out: Dictionary, changes: Dictionary) -> void:
	for k in changes:
		if typeof(changes[k]) == TYPE_DICTIONARY and typeof(out.get(k)) == TYPE_DICTIONARY:
			(out[k] as Dictionary).merge(changes[k], true)
		else:
			out[k] = changes[k]


## What a building at `spec` takes up on its footprint, as rectangles on the ground (x along columns, y
## along rows): its main block and its annexes, and what stands beside it (a silo, a trough, a deck...).
## Where animals can stand in the yard is the rest (BuildingFill).
static func taken(s: Dictionary, fp: Vector2i) -> Array[Rect2]:
	var fw := float(fp.x)
	var fd := float(fp.y)
	var body: Dictionary = s["body"]
	var bw := float(body.get("w", 0.7)) * fw
	var bd := float(body.get("d", 0.66)) * fd
	var at: Array = body.get("at", [0.5, 0.42])
	var lo := Vector2(float(at[0]) * fw - bw / 2.0, float(at[1]) * fd - bd / 2.0)
	var hi := lo + Vector2(bw, bd)
	var out: Array[Rect2] = []
	if bw > 0.0:
		out.append(Rect2(lo, hi - lo))
	for f: Dictionary in s.get("features", []):
		match str(f.get("type", "")):
			"wing":
				var depth := float(f.get("depth", 0.32))
				if str(f.get("side", "right")) == "front":
					out.append(Rect2(lo.x, hi.y, bw, depth))
				else:
					out.append(Rect2(hi.x, lo.y, depth, bd))
			"lean_to", "terrace", "barrels", "hay_bales":
				out.append(Rect2(hi.x, lo.y, minf(0.5, fw - hi.x), bd))
			"porch", "stall_doors":
				out.append(Rect2(lo.x, hi.y, bw, 0.32))
			"water_trough":
				var x := minf(hi.x + 0.45, fw - 0.3)
				var z := minf(hi.y + 0.35, fd - 0.2)
				out.append(Rect2(x - 0.22, z - 0.09, 0.44, 0.18))
			"silo":
				var p: Array = f.get("at", [0.85, 0.2])
				var r := float(f.get("r", 0.22)) + 0.04
				out.append(Rect2(float(p[0]) * fw - r, float(p[1]) * fd - r, r * 2.0, r * 2.0))
			"duck_house":
				var p: Array = f.get("at", [0.82, 0.2])
				out.append(Rect2(float(p[0]) * fw - 0.2, float(p[1]) * fd - 0.17, 0.4, 0.34))
			"beehives":
				var n := int(f.get("count", 3))
				for k in n:
					var x := lerpf(0.4, fw - 0.4, k / maxf(n - 1.0, 1.0))
					out.append(Rect2(x - 0.18, fd * (0.4 + 0.2 * (k % 2)) - 0.16, 0.36, 0.32))
			"ramp":
				out.append(Rect2((lo.x + hi.x) / 2.0 - 0.1, hi.y, 0.2, 0.45))
			"nest_boxes":
				out.append(Rect2(hi.x, lo.y, 0.14, bd))
	return out


## The whole building at its size, under a new node. `fp` is the footprint in tiles (columns, rows).
static func build(it: Dictionary, fp: Vector2i, level := 1) -> Node3D:
	var root := Node3D.new()
	var s := spec(str(it.get("id", "")), level)
	var fw := float(fp.x)
	var fd := float(fp.y)
	var body: Dictionary = s["body"]
	var bw := float(body.get("w", 0.7)) * fw
	var bd := float(body.get("d", 0.66)) * fd
	var bh := float(body.get("h", 0.85))
	var at: Array = body.get("at", [0.5, 0.42])
	var centre := Vector3(float(at[0]) * fw, 0.0, float(at[1]) * fd)
	var lift := 0.0
	for f: Dictionary in s.get("features", []):
		if f.get("type") == "stilts":
			lift = float(f.get("h", 0.2))
	var wall_col := Color.html(str(it.get("color", "#c0392b")))
	var ctx := {"root": root, "fw": fw, "fd": fd, "centre": centre, "bw": bw, "bd": bd, "bh": bh, "lift": lift,
		"wall": wall_col, "spec": s, "it": it}
	# Yards go down first (they're on the ground, under everything).
	for f: Dictionary in s.get("features", []):
		if f.get("type") == "yard":
			_yard(ctx, f)
	if bw > 0.0 and bh > 0.0:
		_body(ctx)
	for f: Dictionary in s.get("features", []):
		if f.get("type") != "yard":
			_feature(ctx, f)
	return root


## A building going up (FarmVille's frame), at `progress` 0..1, the share of its materials put in. It
## builds up as they arrive, in the order a real one would: stakes and string over bare earth, the stone
## footing laid side by side, a plank floor and the timber posts, beams across the top, walls (its own
## kind) rising inside scaffolding, the roof's rafters, then its boards. The pile of materials beside it
## shrinks as they're used. Its size is the finished building's, so it ends where the building begins.
static func build_site(it: Dictionary, fp: Vector2i, progress: float, level := 1) -> Node3D:
	var root := Node3D.new()
	var s := spec(str(it.get("id", "")), level)
	var body: Dictionary = s["body"]
	var fw := float(fp.x)
	var fd := float(fp.y)
	var bw := maxf(float(body.get("w", 0.7)), 0.5) * fw
	var bd := maxf(float(body.get("d", 0.66)), 0.5) * fd
	var bh := maxf(float(body.get("h", 0.85)), 0.6)
	var at: Array = body.get("at", [0.5, 0.42])
	var c := Vector3(float(at[0]) * fw, 0, float(at[1]) * fd)
	var lo := Vector3(c.x - bw / 2.0, 0, c.z - bd / 2.0)
	var hi := Vector3(c.x + bw / 2.0, bh, c.z + bd / 2.0)
	var p := clampf(progress, 0.0, 1.0)
	var timber := ModelKit.surface(Color("#c79a62"), "boards", 0.3)
	# Bare, trodden earth over the site.
	ModelKit.box(root, Vector3(lo.x - 0.18, 0, lo.z - 0.18), Vector3(hi.x + 0.18, 0.01, hi.z + 0.18),
		ModelKit.surface(GROUNDS["dirt"], "plaster", 0.0), false)
	if p < SITE_FOOTING:
		_stakes(root, lo, hi)
	# The footing, a side at a time.
	var footing := _stage(p, SITE_FOOTING, SITE_FLOOR)
	if footing > 0.0:
		var sides := [[Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z)], [Vector3(hi.x, 0, lo.z), Vector3(hi.x, 0, hi.z)],
			[Vector3(hi.x, 0, hi.z), Vector3(lo.x, 0, hi.z)], [Vector3(lo.x, 0, hi.z), Vector3(lo.x, 0, lo.z)]]
		for k in 4:
			var share := clampf(footing * 4.0 - k, 0.0, 1.0)
			if share <= 0.0:
				break
			var a: Vector3 = sides[k][0]
			var b: Vector3 = a.lerp(sides[k][1], share)
			ModelKit.box(root, Vector3(minf(a.x, b.x), 0, minf(a.z, b.z)) - Vector3(0.05, 0, 0.05),
				Vector3(maxf(a.x, b.x), PLINTH, maxf(a.z, b.z)) + Vector3(0.05, 0, 0.05), ModelKit.surface(STONE, "stone", 0.3))
	if p >= SITE_FLOOR:
		ModelKit.box(root, Vector3(lo.x, PLINTH * 0.5, lo.z), Vector3(hi.x, PLINTH + 0.01, hi.z), timber)
		_posts(root, lo, hi, timber)
	if p >= SITE_BEAMS:
		for y: float in [bh * 0.5, bh]:
			_rail(root, Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z), y, timber)
			_rail(root, Vector3(lo.x, 0, hi.z), Vector3(hi.x, 0, hi.z), y, timber)
			_rail(root, Vector3(lo.x, 0, lo.z), Vector3(lo.x, 0, hi.z), y, timber)
			_rail(root, Vector3(hi.x, 0, lo.z), Vector3(hi.x, 0, hi.z), y, timber)
	# The walls, rising inside the frame: thin panels of the building's own walls, open at the top.
	var rising := _stage(p, SITE_WALLS, SITE_RAFTERS)
	var wall_top := PLINTH
	if rising > 0.0:
		wall_top = lerpf(PLINTH + 0.1, bh, rising)
		var wall := ModelKit.surface(Color.html(str(it.get("color", "#c0392b"))), str(body.get("walls", "boards")))
		var t := 0.03
		ModelKit.box(root, Vector3(lo.x, PLINTH, lo.z), Vector3(hi.x, wall_top, lo.z + t), wall)
		ModelKit.box(root, Vector3(lo.x, PLINTH, hi.z - t), Vector3(hi.x, wall_top, hi.z), wall)
		ModelKit.box(root, Vector3(lo.x, PLINTH, lo.z), Vector3(lo.x + t, wall_top, hi.z), wall)
		ModelKit.box(root, Vector3(hi.x - t, PLINTH, lo.z), Vector3(hi.x, wall_top, hi.z), wall)
	if p >= SITE_FLOOR:
		_scaffold(root, lo, hi, minf(wall_top + 0.12, bh + 0.05), timber)
	# The roof: rafters across the ridge, then boards over them.
	var r: Dictionary = s["roof"]
	var span := minf(bw, bd)
	var rise := float(r.get("pitch", 0.7)) * span / 2.0
	var rafters := _stage(p, SITE_RAFTERS, SITE_BOARDS)
	if rafters > 0.0 and str(r.get("type", "gable")) != "none":
		_rafters(root, lo, hi, rise, rafters, timber)
	if p >= SITE_BOARDS and str(r.get("type", "gable")) != "none":
		ModelKit.roof(root, "gable", lo, hi, rise, 0.06, ModelKit.surface(Color("#d8b483"), "boards", 0.0), timber)
	_materials_pile(root, Vector3(minf(hi.x + 0.3, fw - 0.2), 0, minf(c.z + 0.1, fd - 0.3)), 1.0 - p, timber)
	return root


## How far into a stage the site is, 0..1, for a stage running from `start` to `end` of the progress.
static func _stage(p: float, start: float, end: float) -> float:
	return clampf((p - start) / (end - start), 0.0, 1.0)


## Stakes at the corners and string between them: where it will stand.
static func _stakes(root: Node3D, lo: Vector3, hi: Vector3) -> void:
	var wood := ModelKit.paint(Color("#b98a55"))
	var string := ModelKit.paint(Color("#f1ece0"))
	var corners := [Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z), Vector3(hi.x, 0, hi.z), Vector3(lo.x, 0, hi.z)]
	for k in 4:
		var a: Vector3 = corners[k]
		ModelKit.box(root, a - Vector3(0.015, 0, 0.015), a + Vector3(0.015, 0.16, 0.015), wood)
		var b: Vector3 = corners[(k + 1) % 4]
		ModelKit.box(root, Vector3(minf(a.x, b.x), 0.12, minf(a.z, b.z)) - Vector3(0.004, 0, 0.004),
			Vector3(maxf(a.x, b.x), 0.128, maxf(a.z, b.z)) + Vector3(0.004, 0, 0.004), string)


## The frame's posts: at the corners and along the walls, full height.
static func _posts(root: Node3D, lo: Vector3, hi: Vector3, timber: Material) -> void:
	var nx := maxi(2, int(ceil((hi.x - lo.x) / 0.45)) + 1)
	var nz := maxi(2, int(ceil((hi.z - lo.z) / 0.45)) + 1)
	for i in nx:
		for j in nz:
			if i != 0 and i != nx - 1 and j != 0 and j != nz - 1:
				continue
			var p := Vector3(lerpf(lo.x, hi.x, i / (nx - 1.0)), PLINTH, lerpf(lo.z, hi.z, j / (nz - 1.0)))
			ModelKit.box(root, p - Vector3(0.03, 0, 0.03), Vector3(p.x + 0.03, hi.y, p.z + 0.03), timber)


## Scaffolding on the two sides the camera sees: poles a hand's width out, planks at each lift up to
## where the work is, and a ladder.
static func _scaffold(root: Node3D, lo: Vector3, hi: Vector3, up_to: float, timber: Material) -> void:
	var pole := ModelKit.paint(Color("#9aa0a4"), 0.4)
	var plank := ModelKit.surface(Color("#d6b07a"), "boards", 0.0)
	var out := 0.16
	var top := up_to + 0.25
	var x := hi.x + out
	var z := hi.z + out
	for k in 3:
		var pz := lerpf(lo.z, hi.z, k / 2.0)
		ModelKit.box(root, Vector3(x - 0.012, 0, pz - 0.012), Vector3(x + 0.012, top, pz + 0.012), pole)
		var px := lerpf(lo.x, hi.x, k / 2.0)
		ModelKit.box(root, Vector3(px - 0.012, 0, z - 0.012), Vector3(px + 0.012, top, z + 0.012), pole)
	var lift := 0.3
	var y := lift
	while y <= up_to + 0.001:
		ModelKit.box(root, Vector3(hi.x + 0.03, y, lo.z), Vector3(x + 0.04, y + 0.025, hi.z + out), plank)
		ModelKit.box(root, Vector3(lo.x, y, hi.z + 0.03), Vector3(hi.x + out, y + 0.025, z + 0.04), plank)
		y += lift
	# A ladder up the front scaffold.
	var lx := lo.x + 0.15
	for side: float in [-0.07, 0.07]:
		ModelKit.box(root, Vector3(lx + side - 0.01, 0, z + 0.05), Vector3(lx + side + 0.01, top - 0.1, z + 0.07), timber)
	var rung := 0.1
	while rung < top - 0.15:
		ModelKit.box(root, Vector3(lx - 0.07, rung, z + 0.05), Vector3(lx + 0.07, rung + 0.015, z + 0.07), timber)
		rung += 0.1


## Rafters: A-frames across the ridge, put up one after another along it (`share` of them so far), and the
## ridge beam once the first two stand.
static func _rafters(root: Node3D, lo: Vector3, hi: Vector3, rise: float, share: float, timber: Material) -> void:
	var along_x := (hi.x - lo.x) >= (hi.z - lo.z)
	var u0 := lo.x if along_x else lo.z
	var u1 := hi.x if along_x else hi.z
	var v0 := lo.z if along_x else lo.x
	var v1 := hi.z if along_x else hi.x
	var vm := (v0 + v1) / 2.0
	var y := hi.y
	var count := maxi(3, int(ceil((u1 - u0) / 0.22)) + 1)
	var up := int(ceil(count * share))
	for k in up:
		var u := lerpf(u0, u1, k / (count - 1.0))
		for v: float in [v0, v1]:
			var a := Vector3(u, y, v) if along_x else Vector3(v, y, u)
			var b := Vector3(u, y + rise, vm) if along_x else Vector3(vm, y + rise, u)
			_beam(root, a, b, 0.03, timber)
	if up >= 2:
		var a := Vector3(u0, y + rise, vm) if along_x else Vector3(vm, y + rise, u0)
		var u_end := lerpf(u0, u1, (up - 1) / (count - 1.0))
		var b := Vector3(u_end, y + rise, vm) if along_x else Vector3(vm, y + rise, u_end)
		_beam(root, a, b, 0.035, timber)


## A square timber from `a` to `b`.
static func _beam(root: Node3D, a: Vector3, b: Vector3, t: float, mat: Material) -> void:
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var mi := ModelKit.box(root, Vector3(-t / 2.0, -t / 2.0, -length / 2.0), Vector3(t / 2.0, t / 2.0, length / 2.0), mat)
	var dir := (b - a) / length
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD
	mi.transform = Transform3D(Basis.looking_at(dir, up), (a + b) / 2.0)


## The materials still to go in: stacked boards, a pallet of bricks, a keg of nails; less as `left` falls.
static func _materials_pile(root: Node3D, at: Vector3, left: float, timber: Material) -> void:
	if left <= 0.02:
		return
	var boards := maxi(1, int(ceil(left * 6.0)))
	for k in boards:
		var y := k * 0.03
		ModelKit.box(root, at + Vector3(-0.12, y, -0.22), at + Vector3(0.12, y + 0.026, 0.22), timber)
	var bricks := maxi(1, int(ceil(left * 3.0)))
	var b := at + Vector3(0.0, 0, 0.42)
	ModelKit.box(root, b + Vector3(-0.12, 0, -0.1), b + Vector3(0.12, 0.03, 0.1), ModelKit.paint(WOOD))
	ModelKit.box(root, b + Vector3(-0.1, 0.03, -0.08), b + Vector3(0.1, 0.03 + bricks * 0.04, 0.08),
		ModelKit.surface(Color("#b4553c"), "stone", 0.0))
	if left > 0.4:
		ModelKit.cylinder(root, at + Vector3(0.0, 0, -0.38), 0.06, 0.12, ModelKit.surface(Color("#7c4a2a"), "boards", 0.2))


# ---------------------------------------------------------------- the main block


static func _body(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var s: Dictionary = ctx["spec"]
	var c: Vector3 = ctx["centre"]
	var bw: float = ctx["bw"]
	var bd: float = ctx["bd"]
	var bh: float = ctx["bh"]
	var lift: float = ctx["lift"]
	var lo := Vector3(c.x - bw / 2.0, lift, c.z - bd / 2.0)
	var hi := Vector3(c.x + bw / 2.0, lift + bh, c.z + bd / 2.0)
	var walls := str((s["body"] as Dictionary).get("walls", "boards"))
	var trim := Color.html(str(s.get("trim", "#f3eee2")))
	if lift <= 0.0:
		# A stone footing a little wider than the walls: the building stands on something.
		ModelKit.box(root, lo - Vector3(0.04, 0, 0.04), Vector3(hi.x + 0.04, PLINTH, hi.z + 0.04),
			ModelKit.surface(STONE, "stone", 0.3))
	var wall_mat := ModelKit.surface(ctx["wall"], walls)
	ModelKit.box(root, Vector3(lo.x, maxf(lo.y, PLINTH * 0.5), lo.z), hi, wall_mat)
	# White corner boards.
	var t := 0.035
	for corner: Vector2 in [Vector2(lo.x, lo.z), Vector2(hi.x, lo.z), Vector2(hi.x, hi.z), Vector2(lo.x, hi.z)]:
		ModelKit.box(root, Vector3(corner.x - t, lo.y, corner.y - t), Vector3(corner.x + t, hi.y, corner.y + t),
			ModelKit.paint(trim))
	# Roof.
	var r: Dictionary = s["roof"]
	var kind := str(r.get("type", "gable"))
	var top := hi.y
	if kind != "none":
		var span := minf(bw, bd)
		var rise := float(r.get("pitch", 0.7)) * span / 2.0
		var roof_mat := ModelKit.surface(Color.html(str(r.get("color", "#8e3b2c"))), str(r.get("style", "shingles")),
			0.0)
		top = ModelKit.roof(root, kind, lo, hi, rise, float(r.get("overhang", 0.08)), roof_mat, wall_mat)
	ctx["top"] = top
	ctx["lo"] = lo
	ctx["hi"] = hi
	_door(ctx, trim)
	_windows(ctx, int(s.get("windows", 2)), trim, int(s.get("window_rows", 1)))


## The door, on the front (the +z face, toward the camera's left).
static func _door(ctx: Dictionary, trim: Color) -> void:
	var d: Dictionary = (ctx["spec"] as Dictionary)["door"]
	var style := str(d.get("style", "barn"))
	if style == "none":
		return
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var bw: float = ctx["bw"]
	var w := float(d.get("w", 0.28)) * bw / 0.7
	var h := float(d.get("h", 0.55))
	var x := (lo.x + hi.x) / 2.0
	var z := hi.z
	var y0 := lo.y + (PLINTH if lo.y <= 0.0 else 0.0)
	# A dark doorway behind the door itself, which hangs on hinges (kept whole when the building is baked)
	# so it can swing open when you collect.
	if style != "mesh":
		ModelKit.box(root, Vector3(x - w / 2, y0, z), Vector3(x + w / 2, y0 + h, z + 0.004), ModelKit.paint(DARK))
	match style:
		"barn":
			for side: float in [-1.0, 1.0]:
				# Each half hinges at its outer edge and swings out toward you.
				var leaf := _hinge(root, Vector3(x + side * w / 2.0, y0, z), side)
				var cx := x + side * w / 4.0
				ModelKit.box(leaf, Vector3(cx - w / 4.0, y0, z + 0.004), Vector3(cx + w / 4.0, y0 + h, z + 0.029),
					ModelKit.surface((ctx["wall"] as Color).darkened(0.25), "boards"))
				# The white X-braces of a barn door.
				var brace := ModelKit.paint(trim)
				ModelKit.box(leaf, Vector3(cx - w / 4.0, y0, z + 0.029), Vector3(cx + w / 4.0, y0 + 0.04, z + 0.044),
					brace)
				ModelKit.box(leaf, Vector3(cx - w / 4.0, y0 + h - 0.04, z + 0.029),
					Vector3(cx + w / 4.0, y0 + h, z + 0.044), brace)
				var diag := ModelKit.box(leaf, Vector3(cx - 0.02, y0, z + 0.029), Vector3(cx + 0.02, y0 + h * 1.05, z + 0.044),
					brace)
				if diag != null:
					diag.rotation.z = side * atan2(w / 2.0, h)
			ModelKit.box(root, Vector3(x - w / 2 - 0.03, y0 + h, z), Vector3(x + w / 2 + 0.03, y0 + h + 0.04, z + 0.05),
				ModelKit.paint(trim))
		"roller":
			var shutter := _hinge(root, Vector3(x, y0, z), 0.0)
			shutter.get_parent().set_meta("slide", h * 0.85)
			ModelKit.box(shutter, Vector3(x - w / 2, y0, z + 0.004), Vector3(x + w / 2, y0 + h, z + 0.024),
				ModelKit.surface(Color("#c9ced2"), "metal"))
		"mesh", "hatch":
			var flap := _hinge(root, Vector3(x - w / 2, y0, z), -1.0)
			ModelKit.box(flap, Vector3(x - w / 2, y0, z + 0.004), Vector3(x + w / 2, y0 + h, z + 0.024), ModelKit.paint(DARK)
				if style == "mesh" else ModelKit.surface(WOOD, "boards"))
			ModelKit.box(root, Vector3(x - w / 2 - 0.02, y0 + h, z), Vector3(x + w / 2 + 0.02, y0 + h + 0.03, z + 0.04),
				ModelKit.paint(trim))
		_:
			# A painted door in a frame (and, for an arch, a rounded top).
			ModelKit.box(root, Vector3(x - w / 2 - 0.03, y0 + h, z), Vector3(x + w / 2 + 0.03, y0 + h + 0.03, z + 0.02),
				ModelKit.paint(trim))
			for side: float in [-1.0, 1.0]:
				ModelKit.box(root, Vector3(x + side * (w / 2 + 0.015) - 0.015, y0, z),
					Vector3(x + side * (w / 2 + 0.015) + 0.015, y0 + h, z + 0.02), ModelKit.paint(trim))
			var door := _hinge(root, Vector3(x - w / 2, y0, z), -1.0)
			ModelKit.box(door, Vector3(x - w / 2, y0, z + 0.006), Vector3(x + w / 2, y0 + h, z + 0.026),
				ModelKit.paint(Color("#6b3f26")))
			ModelKit.ball(door, Vector3(x + w / 2 - 0.04, y0 + h * 0.5, z + 0.03), 0.012, ModelKit.paint(Color("#d4b04a"), 0.7))
			if style == "arch":
				var arch := ModelKit.cylinder(root, Vector3(x, y0 + h, z + 0.02), w / 2.0, 0.02, ModelKit.paint(trim))
				arch.rotation.x = PI / 2.0
				arch.position = Vector3(x, y0 + h, z + 0.02)
	# A step up to the door.
	if lo.y <= 0.0:
		ModelKit.box(root, Vector3(x - w / 2 - 0.05, 0, z), Vector3(x + w / 2 + 0.05, PLINTH * 0.7, z + 0.1),
			ModelKit.surface(STONE, "stone", 0.2))


## A hinge for a door at `at` (on its outer edge, at the foot): returns the node to build the door under,
## in the building's own coordinates. `swing` is which way it opens (+1 or -1 turns, 0 for none).
static func _hinge(root: Node3D, at: Vector3, swing: float) -> Node3D:
	var hinge := Node3D.new()
	hinge.position = at
	hinge.set_meta(ModelKit.KEEP, true)
	hinge.set_meta(DOOR, swing)
	root.add_child(hinge)
	var inner := Node3D.new()
	inner.position = -at
	hinge.add_child(inner)
	return inner


## Windows on the side the camera sees (+x): `count` to a row, a row to a floor.
static func _windows(ctx: Dictionary, count: int, trim: Color, rows := 1) -> void:
	if count <= 0:
		return
	var wall_h: float = (ctx["hi"] as Vector3).y - (ctx["lo"] as Vector3).y
	var size := minf(0.2, wall_h * (0.3 if rows == 1 else 0.42 / rows))
	for row in rows:
		var share := 0.58 if rows == 1 else lerpf(0.32, 0.74, row / (rows - 1.0))
		_window_row(ctx, count, trim, share, size)


static func _window_row(ctx: Dictionary, count: int, trim: Color, share: float, size: float) -> void:
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var y := lo.y + (hi.y - lo.y) * share
	for k in count:
		var z := lerpf(lo.z, hi.z, (k + 1.0) / (count + 1.0))
		ModelKit.box(root, Vector3(hi.x, y - size / 2 - 0.025, z - size / 2 - 0.025),
			Vector3(hi.x + 0.02, y + size / 2 + 0.025, z + size / 2 + 0.025), ModelKit.paint(trim))
		ModelKit.box(root, Vector3(hi.x + 0.02, y - size / 2, z - size / 2), Vector3(hi.x + 0.03, y + size / 2, z + size / 2),
			ModelKit.glass())
		# A sill with a shadow under it.
		ModelKit.box(root, Vector3(hi.x, y - size / 2 - 0.05, z - size / 2 - 0.04),
			Vector3(hi.x + 0.06, y - size / 2 - 0.025, z + size / 2 + 0.04), ModelKit.paint(trim))


# ---------------------------------------------------------------- features


static func _feature(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var fw: float = ctx["fw"]
	var fd: float = ctx["fd"]
	var c: Vector3 = ctx["centre"]
	var lo: Vector3 = ctx.get("lo", c)
	var hi: Vector3 = ctx.get("hi", c)
	match str(f.get("type", "")):
		"stilts":
			var lift: float = ctx["lift"]
			for corner: Vector2 in [Vector2(lo.x + 0.05, lo.z + 0.05), Vector2(hi.x - 0.05, lo.z + 0.05),
					Vector2(hi.x - 0.05, hi.z - 0.05), Vector2(lo.x + 0.05, hi.z - 0.05)]:
				ModelKit.box(root, Vector3(corner.x - 0.03, 0, corner.y - 0.03), Vector3(corner.x + 0.03, lift, corner.y + 0.03),
					ModelKit.paint(WOOD))
		"ramp":
			var ramp := ModelKit.box(
				root,
				Vector3(-0.07, -0.01, 0),
				Vector3(0.07, 0.01, 0.42),
				ModelKit.surface(WOOD, "boards")
			)
			if ramp != null:
				ramp.position = Vector3((lo.x + hi.x) / 2.0, float(ctx["lift"]) / 2.0, hi.z + 0.17)
				ramp.rotation.x = atan2(float(ctx["lift"]), 0.4)
		"nest_boxes":
			for k in 3:
				var z := lerpf(lo.z + 0.08, hi.z - 0.08, k / 2.0)
				ModelKit.box(root, Vector3(hi.x, lo.y + 0.05, z - 0.06), Vector3(hi.x + 0.1, lo.y + 0.17, z + 0.06),
					ModelKit.surface(WOOD, "boards"))
				ModelKit.ball(root, Vector3(hi.x + 0.07, lo.y + 0.19, z), 0.035, ModelKit.paint(Color("#f6ecd2")),
					Vector3(1, 1.25, 1))
		"silo":
			var at: Array = f.get("at", [0.85, 0.2])
			var base := Vector3(float(at[0]) * fw, 0, float(at[1]) * fd)
			var r := float(f.get("r", 0.22))
			var h := float(f.get("h", 1.6))
			ModelKit.cylinder(root, base, r + 0.03, 0.08, ModelKit.surface(STONE, "stone", 0.2), -1.0, 20)
			ModelKit.cylinder(root, base, r, h, ModelKit.surface(Color("#d9dcde"), "metal", 0.35), -1.0, 20)
			for k in 3:
				ModelKit.cylinder(root, base + Vector3(0, h * (0.3 + 0.25 * k), 0), r + 0.008, 0.025,
					ModelKit.paint(Color("#9aa2a8"), 0.5), -1.0, 20)
			ModelKit.ball(root, base + Vector3(0, h, 0), r, ModelKit.paint(Color("#b9c0c4"), 0.6), Vector3(1, 0.6, 1))
		"loft_door":
			var y := float(ctx.get("hi", c).y) + 0.12
			var x := (lo.x + hi.x) / 2.0
			ModelKit.box(root, Vector3(x - 0.12, y - 0.02, hi.z - 0.05), Vector3(x + 0.12, y + 0.22, hi.z + 0.03),
				ModelKit.paint(Color("#f3eee2")))
			ModelKit.box(
				root,
				Vector3(x - 0.09, y, hi.z + 0.03),
				Vector3(x + 0.09, y + 0.19, hi.z + 0.04),
				ModelKit.paint(DARK)
			)
			ModelKit.box(
				root,
				Vector3(x - 0.02, y + 0.08, hi.z + 0.04),
				Vector3(x + 0.02, y + 0.18, hi.z + 0.08),
				ModelKit.paint(HAY)
			)
		"cupola":
			var top: float = ctx.get("top", hi.y)
			var x := (lo.x + hi.x) / 2.0
			var z := (lo.z + hi.z) / 2.0
			ModelKit.box(root, Vector3(x - 0.1, top - 0.08, z - 0.1), Vector3(x + 0.1, top + 0.14, z + 0.1),
				ModelKit.paint(Color("#f3eee2")))
			ModelKit.cylinder(root, Vector3(x, top + 0.14, z), 0.15, 0.14, ModelKit.paint(Color("#4a5d6e")), 0.0, 4)
			ModelKit.box(root, Vector3(x - 0.005, top + 0.28, z - 0.005), Vector3(x + 0.005, top + 0.42, z + 0.005),
				ModelKit.paint(Color("#3a3a3a")))
			ModelKit.box(root, Vector3(x - 0.05, top + 0.38, z - 0.004), Vector3(x + 0.06, top + 0.4, z + 0.004),
				ModelKit.paint(Color("#3a3a3a")))
		"stall_doors":
			var n := int(f.get("count", 4))
			for k in n:
				var x := lerpf(lo.x, hi.x, (k + 0.5) / n)
				var w := (hi.x - lo.x) / n * 0.62
				var y0 := PLINTH
				ModelKit.box(root, Vector3(x - w / 2 - 0.02, y0, hi.z), Vector3(
					x + w / 2 + 0.02,
					y0 + 0.56,
					hi.z + 0.02
				),
					ModelKit.paint(Color("#f3eee2")))
				ModelKit.box(root, Vector3(x - w / 2, y0, hi.z + 0.02), Vector3(x + w / 2, y0 + 0.3, hi.z + 0.035),
					ModelKit.surface(Color("#7a4a2a"), "boards"))
				# The open top half: dark inside the stall.
				ModelKit.box(root, Vector3(x - w / 2, y0 + 0.3, hi.z + 0.005), Vector3(x + w / 2, y0 + 0.52, hi.z + 0.02),
					ModelKit.paint(Color("#1f1612")))
		"porch":
			var x0 := lo.x + 0.05
			var x1 := hi.x - 0.05
			var depth := 0.28
			ModelKit.box(
				root,
				Vector3(x0, 0, hi.z),
				Vector3(x1, PLINTH, hi.z + depth),
				ModelKit.surface(WOOD, "boards", 0.2)
			)
			for x: float in [x0 + 0.03, x1 - 0.03]:
				ModelKit.box(root, Vector3(x - 0.025, PLINTH, hi.z + depth - 0.06), Vector3(x + 0.025, PLINTH + 0.52,
					hi.z + depth - 0.01), ModelKit.paint(Color("#f3eee2")))
			var porch_roof := ModelKit.box(root, Vector3(x0 - 0.03, -0.02, 0), Vector3(x1 + 0.03, 0.02, depth + 0.06),
				ModelKit.paint(
					Color.html(str(((ctx["spec"] as Dictionary)["roof"] as Dictionary).get("color", "#8e3b2c")))
				))
			if porch_roof != null:
				porch_roof.position = Vector3((x0 + x1) / 2.0, PLINTH + 0.56, hi.z + depth / 2.0)
				porch_roof.rotation.x = 0.25
		"terrace":
			# A raised deck along the side with a railing.
			var z0 := lo.z + 0.05
			var z1 := hi.z - 0.05
			var x1 := minf(hi.x + 0.32, fw - 0.05)
			ModelKit.box(
				root,
				Vector3(hi.x, 0, z0),
				Vector3(x1, 0.16, z1),
				ModelKit.surface(Color("#b07a4c"), "boards", 0.2)
			)
			_rail(
				root,
				Vector3(x1 - 0.02, 0.16, z0),
				Vector3(x1 - 0.02, 0.16, z1),
				0.22,
				ModelKit.paint(Color("#f3eee2"))
			)
		"chimney":
			var top: float = ctx.get("top", hi.y)
			ModelKit.box(root, Vector3(hi.x - 0.22, hi.y, lo.z + 0.12), Vector3(hi.x - 0.08, top + 0.15, lo.z + 0.26),
				ModelKit.surface(Color("#a6533c"), "stone", 0.0))
		"water_trough":
			var x := minf(hi.x + 0.45, fw - 0.3)
			var z := minf(hi.z + 0.35, fd - 0.2)
			ModelKit.box(
				root,
				Vector3(x - 0.2, 0, z - 0.07),
				Vector3(x + 0.2, 0.12, z + 0.07),
				ModelKit.surface(WOOD, "boards", 0.2)
			)
			ModelKit.box(
				root,
				Vector3(x - 0.18, 0.09, z - 0.05),
				Vector3(x + 0.18, 0.105, z + 0.05),
				ModelKit.water(),
				false
			)
		"hay_bales":
			var x := minf(hi.x + 0.3, fw - 0.25)
			var z := clampf(lo.z + 0.2, 0.2, fd - 0.2)
			for k in 3:
				var at := Vector3(x + (k % 2) * 0.22, 0.0 if k < 2 else 0.14, z + (0.11 if k == 2 else 0.0))
				ModelKit.box(root, at + Vector3(-0.1, 0, -0.08), at + Vector3(0.1, 0.14, 0.08), ModelKit.paint(HAY))
		"barrels":
			var x := minf(hi.x + 0.25, fw - 0.15)
			for k in 3:
				var z := lerpf(lo.z + 0.15, hi.z - 0.15, k / 2.0)
				ModelKit.cylinder(root, Vector3(x, 0, z), 0.1, 0.24, ModelKit.surface(Color("#7c4a2a"), "boards", 0.25))
				ModelKit.cylinder(root, Vector3(x, 0.05, z), 0.105, 0.025, ModelKit.paint(Color("#3a3a3a"), 0.5))
				ModelKit.cylinder(root, Vector3(x, 0.18, z), 0.105, 0.025, ModelKit.paint(Color("#3a3a3a"), 0.5))
		"flowers":
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(str((ctx["it"] as Dictionary).get("id", "")))
			for k in 14:
				var p := Vector3(rng.randf_range(0.1, fw - 0.1), 0, fd - rng.randf_range(0.05, 0.3))
				if p.x > lo.x - 0.05 and p.x < hi.x + 0.05 and p.z < hi.z + 0.05:
					continue
				ModelKit.cylinder(root, p, 0.008, 0.08, ModelKit.paint(Color("#4f8a2f")))
				var petal: Color = [Color("#ff7aa8"), Color("#ffd23f"), Color("#ffffff"), Color("#b388ff")][k % 4]
				ModelKit.ball(root, p + Vector3(0, 0.09, 0), 0.03, ModelKit.paint(petal))
		"beehives":
			var n := int(f.get("count", 3))
			for k in n:
				var p := Vector3(lerpf(0.4, fw - 0.4, k / maxf(n - 1.0, 1.0)), 0, fd * (0.4 + 0.2 * (k % 2)))
				ModelKit.box(root, p + Vector3(-0.16, 0, -0.14), p + Vector3(0.16, 0.08, 0.14), ModelKit.paint(WOOD))
				for level in 3:
					var y := 0.08 + level * 0.13
					ModelKit.box(root, p + Vector3(-0.14, y, -0.12), p + Vector3(0.14, y + 0.12, 0.12),
						ModelKit.surface(Color("#f2e3b3"), "boards", 0.2))
				ModelKit.box(
					root,
					p + Vector3(-0.17, 0.47, -0.15),
					p + Vector3(0.17, 0.52, 0.15),
					ModelKit.paint(Color("#c9a24a"))
				)
				ModelKit.box(root, p + Vector3(-0.05, 0.09, 0.12), p + Vector3(0.05, 0.11, 0.13), ModelKit.paint(DARK))
		"pond":
			var rx := fw * 0.4
			var rz := fd * 0.36
			var centre := Vector3(fw / 2.0, 0, fd / 2.0)
			ModelKit.ball(
				root,
				centre + Vector3(0, -0.02, 0),
				1.0,
				ModelKit.paint(Color("#8a7a5a")),
				Vector3(rx + 0.08, 0.05, rz + 0.08)
			)
			ModelKit.ball(root, centre + Vector3(0, 0.005, 0), 1.0, ModelKit.water(), Vector3(rx, 0.03, rz))
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for k in 10:
				var a := TAU * k / 10.0 + rng.randf() * 0.3
				var p := centre + Vector3(cos(a) * (rx + 0.05), 0, sin(a) * (rz + 0.05))
				ModelKit.ball(root, p, rng.randf_range(0.04, 0.07), ModelKit.paint(STONE), Vector3(1, 0.6, 1))
			for k in 4:
				var a := TAU * (k + 0.5) / 4.0
				ModelKit.cylinder(root, centre + Vector3(cos(a) * rx * 0.8, 0, sin(a) * rz * 0.8), 0.006, 0.22,
					ModelKit.paint(Color("#5d7a2c")))
		"duck_house":
			var spot: Array = f.get("at", [0.82, 0.2])
			var p := Vector3(fw * float(spot[0]), 0, fd * float(spot[1]))
			for k in 4:
				ModelKit.box(root, p + Vector3(
					-0.15 + (k % 2) * 0.27,
					0,
					-0.12 + (k / 2) * 0.21
				), p + Vector3(-0.12 + (k % 2) * 0.27,
					0.15, -0.09 + (k / 2) * 0.21), ModelKit.paint(WOOD))
			ModelKit.box(
				root,
				p + Vector3(-0.17, 0.15, -0.14),
				p + Vector3(0.17, 0.35, 0.14),
				ModelKit.surface(Color("#e9d7a8"), "boards")
			)
			ModelKit.roof(root, "gable", p + Vector3(-0.17, 0.15, -0.14), p + Vector3(0.17, 0.35, 0.14), 0.12, 0.04,
				ModelKit.surface(Color("#b5492f"), "shingles", 0.0), ModelKit.surface(Color("#e9d7a8"), "boards"))
		"trees":
			# Rows of three, spread over the yard; more trees, more rows, a little smaller.
			var n := int(f.get("count", 6))
			var rows := ceili(n / 3.0)
			var size := 0.55 if rows <= 2 else 0.55 * 2.0 / rows + 0.1
			for k in n:
				var row := k / 3
				var z := fd * (0.3 + 0.4 * row / maxf(rows - 1.0, 1.0)) if rows > 1 else fd * 0.5
				var p := Vector3(fw * (0.25 + 0.25 * (k % 3)), 0, z)
				TreeModel.build_at(root, p, {"color": "#d63c2f", "id": "orchard", "family": "apple"}, size, true, k)
		"wing":
			_wing(ctx, f)
		"lean_to":
			_lean_to(ctx, f)
		"weathervane":
			var top: float = ctx.get("top", hi.y)
			var x := (lo.x + hi.x) / 2.0 + float(f.get("shift", 0.0))
			var z := (lo.z + hi.z) / 2.0
			var iron := ModelKit.paint(Color("#2e2e2e"), 0.3)
			ModelKit.box(root, Vector3(x - 0.008, top, z - 0.008), Vector3(x + 0.008, top + 0.34, z + 0.008), iron)
			ModelKit.box(root, Vector3(x - 0.12, top + 0.22, z - 0.004), Vector3(x + 0.12, top + 0.235, z + 0.004), iron)
			ModelKit.box(root, Vector3(x - 0.004, top + 0.22, z - 0.09), Vector3(x + 0.004, top + 0.235, z + 0.09), iron)
			# The cockerel on top.
			ModelKit.ball(root, Vector3(x, top + 0.33, z), 0.045, ModelKit.paint(Color("#c9a24a"), 0.6),
				Vector3(1.6, 1.0, 0.35))
			ModelKit.ball(root, Vector3(x + 0.06, top + 0.37, z), 0.025, ModelKit.paint(Color("#c9a24a"), 0.6),
				Vector3(1, 1, 0.4))
		"sign":
			var p := Vector3(
				minf(hi.x + 0.15, fw - 0.1),
				0,
				minf(hi.z + 0.2, fd - 0.05)
			) if hi != c else Vector3(fw - 0.2, 0, fd - 0.1)
			ModelKit.box(root, p + Vector3(-0.015, 0, -0.015), p + Vector3(0.015, 0.4, 0.015), ModelKit.paint(WOOD))
			ModelKit.box(
				root,
				p + Vector3(-0.14, 0.26, 0.0),
				p + Vector3(0.14, 0.42, 0.025),
				ModelKit.surface(Color("#c8a26a"), "boards", 0.0)
			)


## An annex built onto the main block (a milking parlour, a tack room, a bigger kitchen): lower walls of
## the same kind against the side the camera sees (+x, or the front +z with "side": "front"), its own
## gabled roof, footing and window. "depth" is how far it stands out, "span" how much of the wall it
## covers, "h" its wall height.
static func _wing(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var s: Dictionary = ctx["spec"]
	var front := str(f.get("side", "right")) == "front"
	var depth := float(f.get("depth", 0.32))
	var span := float(f.get("span", 0.7))
	var h := float(f.get("h", (hi.y - lo.y) * 0.62))
	var wlo: Vector3
	var whi: Vector3
	if front:
		var xc := (lo.x + hi.x) / 2.0 + float(f.get("shift", 0.0))
		var half := (hi.x - lo.x) * span / 2.0
		wlo = Vector3(xc - half, lo.y, hi.z - 0.02)
		whi = Vector3(xc + half, lo.y + h, minf(hi.z + depth, float(ctx["fd"]) - 0.08))
	else:
		var zc := (lo.z + hi.z) / 2.0 + float(f.get("shift", 0.0))
		var half := (hi.z - lo.z) * span / 2.0
		wlo = Vector3(hi.x - 0.02, lo.y, zc - half)
		whi = Vector3(minf(hi.x + depth, float(ctx["fw"]) - 0.08), lo.y + h, zc + half)
	if whi.x - wlo.x < 0.1 or whi.z - wlo.z < 0.1:
		return  # no room on this footprint
	var wall_mat := ModelKit.surface(ctx["wall"], str((s["body"] as Dictionary).get("walls", "boards")))
	if lo.y <= 0.0:
		ModelKit.box(root, wlo - Vector3(0.03, 0, 0.03), Vector3(whi.x + 0.03, PLINTH, whi.z + 0.03),
			ModelKit.surface(STONE, "stone", 0.3))
	ModelKit.box(root, Vector3(wlo.x, maxf(wlo.y, PLINTH * 0.5), wlo.z), whi, wall_mat)
	var r: Dictionary = s["roof"]
	var roof_mat := ModelKit.surface(Color.html(str(f.get("roof", r.get("color", "#8e3b2c")))),
		str(r.get("style", "shingles")), 0.0)
	var rise := minf(whi.x - wlo.x, whi.z - wlo.z) * 0.35
	ModelKit.roof(root, "gable", wlo, whi, rise, 0.05, roof_mat, wall_mat)
	# A window in its outer wall.
	var trim := Color.html(str(s.get("trim", "#f3eee2")))
	var y := wlo.y + h * 0.55
	var w := minf(0.16, h * 0.35)
	if front:
		var x := (wlo.x + whi.x) / 2.0
		ModelKit.box(root, Vector3(x - w / 2 - 0.02, y - w / 2 - 0.02, whi.z), Vector3(x + w / 2 + 0.02, y + w / 2 + 0.02,
			whi.z + 0.02), ModelKit.paint(trim))
		ModelKit.box(root, Vector3(x - w / 2, y - w / 2, whi.z + 0.02), Vector3(x + w / 2, y + w / 2, whi.z + 0.03),
			ModelKit.glass())
	else:
		var z := (wlo.z + whi.z) / 2.0
		ModelKit.box(root, Vector3(whi.x, y - w / 2 - 0.02, z - w / 2 - 0.02), Vector3(whi.x + 0.02, y + w / 2 + 0.02,
			z + w / 2 + 0.02), ModelKit.paint(trim))
		ModelKit.box(root, Vector3(whi.x + 0.02, y - w / 2, z - w / 2), Vector3(whi.x + 0.03, y + w / 2, z + w / 2),
			ModelKit.glass())


## An open-sided shelter against the side wall: two posts and a sloping plank roof, hay stacked under it.
static func _lean_to(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var depth := minf(float(f.get("depth", 0.34)), float(ctx["fw"]) - 0.08 - hi.x)
	if depth < 0.12:
		return
	var z0 := lo.z + 0.04
	var z1 := hi.z - 0.04
	var high := lo.y + (hi.y - lo.y) * 0.8
	var low := high - depth * 0.55
	var x1 := hi.x + depth
	var wood := ModelKit.paint(WOOD)
	for z: float in [z0 + 0.02, z1 - 0.02]:
		ModelKit.box(root, Vector3(x1 - 0.05, 0, z - 0.02), Vector3(x1 - 0.01, low, z + 0.02), wood)
	var plank := ModelKit.box(root, Vector3(-depth / 2.0 - 0.04, -0.015, -(z1 - z0) / 2.0 - 0.03),
		Vector3(depth / 2.0 + 0.04, 0.015, (z1 - z0) / 2.0 + 0.03), ModelKit.surface(Color("#9a6b45"), "boards", 0.0))
	if plank != null:
		plank.position = Vector3(hi.x + depth / 2.0, (high + low) / 2.0, (z0 + z1) / 2.0)
		plank.rotation.z = -atan2(high - low, depth)
	for k in 2:
		var at := Vector3(hi.x + depth * 0.45, 0.0, lerpf(z0 + 0.12, z1 - 0.12, k))
		ModelKit.box(root, at + Vector3(-0.1, 0, -0.08), at + Vector3(0.1, 0.13, 0.08), ModelKit.paint(HAY))


## A yard on the footprint around the building: a patch of dirt, straw, grass or mud, and a fence.
static func _yard(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var fw: float = ctx["fw"]
	var fd: float = ctx["fd"]
	var inset := 0.06
	var ground := str(f.get("ground", "dirt"))
	var col: Color = GROUNDS.get(ground, GROUNDS["dirt"])
	ModelKit.box(root, Vector3(inset, 0, inset), Vector3(fw - inset, 0.012, fd - inset),
		ModelKit.surface(col, "plaster", 0.0), false)
	var fence := str(f.get("fence", "rail"))
	var mat := ModelKit.paint(FENCE if fence == "picket" else RAIL)
	var corners := [Vector3(inset, 0, inset), Vector3(fw - inset, 0, inset), Vector3(fw - inset, 0, fd - inset),
		Vector3(inset, 0, fd - inset)]
	for k in 4:
		var a: Vector3 = corners[k]
		var b: Vector3 = corners[(k + 1) % 4]
		if k == 2:
			# A gate in the front fence.
			var mid := (a + b) / 2.0
			var gap := (b - a).normalized() * 0.22
			_fence(root, a, mid - gap, fence, mat)
			_fence(root, mid + gap, b, fence, mat)
		else:
			_fence(root, a, b, fence, mat)


## A run of fence: posts, with two rails (rail) or pointed pickets (picket).
static func _fence(root: Node3D, a: Vector3, b: Vector3, kind: String, mat: Material) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(length, 0.001)
	var posts := maxi(1, int(ceil(length / 0.33)))
	for k in posts + 1:
		var p := a + dir * (length * k / posts)
		ModelKit.box(root, p - Vector3(0.022, 0, 0.022), p + Vector3(0.022, 0.24, 0.022), mat)
	if kind == "picket":
		var n := int(length / 0.08)
		for k in n:
			var p := a + dir * (length * (k + 0.5) / n)
			ModelKit.box(root, p - Vector3(0.012, 0, 0.012), p + Vector3(0.012, 0.2, 0.012), mat)
		_rail(root, a, b, 0.14, mat)
	else:
		_rail(root, a, b, 0.09, mat)
		_rail(root, a, b, 0.19, mat)


static func _rail(root: Node3D, a: Vector3, b: Vector3, y: float, mat: Material) -> void:
	var lo := Vector3(minf(a.x, b.x) - 0.012, a.y + y, minf(a.z, b.z) - 0.012)
	var hi := Vector3(maxf(a.x, b.x) + 0.012, a.y + y + 0.03, maxf(a.z, b.z) + 0.012)
	ModelKit.box(root, lo, hi, mat)
