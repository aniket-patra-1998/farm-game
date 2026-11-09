class_name BuildingModel
extends RefCounted
## Builds a building in 3D from its description in data/building_models.json: a stone footing, walls with
## their pattern, a roof, a door and windows, white trim at the corners, and the features that make each
## kind of building its own (a coop on stilts with a ramp, a dairy's silo and loft door, a stable's row of
## half-doors, yards, troughs, hay, hives, a pond...). The node's origin is the footprint's back corner;
## x runs along its columns and z along its rows, one unit a tile.

const PATH := "res://data/building_models.json"
const PLINTH := 0.09
const STONE := Color("#9b958a")
const WOOD := Color("#8a5a36")
const DARK := Color("#3b2a20")
const HAY := Color("#e2c25a")
const FENCE := Color("#f1ece0")
const RAIL := Color("#a07446")
const GROUNDS := {"dirt": Color("#9a7a52"), "straw": Color("#d9bf6a"), "grass": Color("#79a845"),
	"mud": Color("#6e5236")}

static var _data := {}


static func spec(id: String) -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"default": {}, "buildings": {}}
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error(PATH + " is missing or not valid JSON")
	var out: Dictionary = (_data["default"] as Dictionary).duplicate(true)
	var own: Dictionary = (_data.get("buildings", {}) as Dictionary).get(id, {})
	for k in own:
		if typeof(own[k]) == TYPE_DICTIONARY and typeof(out.get(k)) == TYPE_DICTIONARY:
			(out[k] as Dictionary).merge(own[k], true)
		else:
			out[k] = own[k]
	return out


## The whole building, under a new node. `fp` is the footprint in tiles (columns, rows).
static func build(it: Dictionary, fp: Vector2i) -> Node3D:
	var root := Node3D.new()
	var s := spec(str(it.get("id", "")))
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


## A building still under construction (FarmVille's frame): a stone footing, timber posts and beams, a
## ladder, and a stack of boards waiting to go up.
static func build_frame(it: Dictionary, fp: Vector2i) -> Node3D:
	var root := Node3D.new()
	var s := spec(str(it.get("id", "")))
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
	var timber := ModelKit.surface(Color("#c79a62"), "boards", 0.3)
	ModelKit.box(
		root,
		lo - Vector3(0.04, 0, 0.04),
		Vector3(hi.x + 0.04, PLINTH, hi.z + 0.04),
		ModelKit.surface(STONE, "stone", 0.3)
	)
	var posts := 3
	for i in posts:
		for j in posts:
			if i != 0 and i != posts - 1 and j != 0 and j != posts - 1:
				continue
			var p := Vector3(lerpf(lo.x, hi.x, i / (posts - 1.0)), PLINTH, lerpf(lo.z, hi.z, j / (posts - 1.0)))
			ModelKit.box(root, p - Vector3(0.03, 0, 0.03), p + Vector3(0.03, bh, 0.03), timber)
	for y: float in [bh * 0.5, bh]:
		_rail(root, Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z), y, timber)
		_rail(root, Vector3(lo.x, 0, hi.z), Vector3(hi.x, 0, hi.z), y, timber)
		_rail(root, Vector3(lo.x, 0, lo.z), Vector3(lo.x, 0, hi.z), y, timber)
		_rail(root, Vector3(hi.x, 0, lo.z), Vector3(hi.x, 0, hi.z), y, timber)
	# A stack of boards and a ladder against the front.
	for k in 4:
		var y := k * 0.035
		ModelKit.box(root, Vector3(hi.x + 0.08, y, c.z - 0.25), Vector3(hi.x + 0.32, y + 0.03, c.z + 0.25), timber)
	var ladder := Node3D.new()
	ladder.position = Vector3(c.x, PLINTH, hi.z + 0.1)
	ladder.rotation.x = -0.25
	root.add_child(ladder)
	for side: float in [-0.08, 0.08]:
		ModelKit.box(ladder, Vector3(side - 0.012, 0, -0.012), Vector3(side + 0.012, bh * 0.9, 0.012), timber)
	for k in 5:
		var y := (k + 0.5) * bh * 0.9 / 5.0
		ModelKit.box(ladder, Vector3(-0.08, y - 0.01, -0.01), Vector3(0.08, y + 0.01, 0.01), timber)
	return root


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
	_windows(ctx, int(s.get("windows", 2)), trim)


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
	match style:
		"barn":
			ModelKit.box(root, Vector3(x - w / 2, y0, z), Vector3(x + w / 2, y0 + h, z + 0.025),
				ModelKit.surface((ctx["wall"] as Color).darkened(0.25), "boards"))
			# The white X-braces of a barn door.
			for side: float in [-1.0, 1.0]:
				var cx := x + side * w / 4.0
				var brace := ModelKit.paint(trim)
				ModelKit.box(
					root,
					Vector3(cx - w / 4.0, y0, z + 0.025),
					Vector3(cx + w / 4.0, y0 + 0.04, z + 0.04),
					brace
				)
				ModelKit.box(root, Vector3(cx - w / 4.0, y0 + h - 0.04, z + 0.025), Vector3(cx + w / 4.0, y0 + h, z + 0.04),
					brace)
				var diag := ModelKit.box(root, Vector3(cx - 0.02, y0, z + 0.025), Vector3(cx + 0.02, y0 + h * 1.05, z + 0.04),
					brace)
				if diag != null:
					diag.rotation.z = side * atan2(w / 2.0, h)
			ModelKit.box(root, Vector3(x - w / 2 - 0.03, y0 + h, z), Vector3(x + w / 2 + 0.03, y0 + h + 0.04, z + 0.05),
				ModelKit.paint(trim))
		"roller":
			ModelKit.box(root, Vector3(x - w / 2, y0, z), Vector3(x + w / 2, y0 + h, z + 0.02),
				ModelKit.surface(Color("#c9ced2"), "metal"))
		"mesh", "hatch":
			ModelKit.box(root, Vector3(x - w / 2, y0, z), Vector3(x + w / 2, y0 + h, z + 0.02), ModelKit.paint(DARK))
			ModelKit.box(root, Vector3(x - w / 2 - 0.02, y0 + h, z), Vector3(x + w / 2 + 0.02, y0 + h + 0.03, z + 0.04),
				ModelKit.paint(trim))
		_:
			# A painted door with a frame (and, for an arch, a rounded top).
			ModelKit.box(root, Vector3(x - w / 2 - 0.03, y0, z), Vector3(x + w / 2 + 0.03, y0 + h + 0.03, z + 0.02),
				ModelKit.paint(trim))
			ModelKit.box(root, Vector3(x - w / 2, y0, z + 0.02), Vector3(x + w / 2, y0 + h, z + 0.035),
				ModelKit.paint(Color("#6b3f26")))
			if style == "arch":
				var arch := ModelKit.cylinder(root, Vector3(x, y0 + h, z + 0.02), w / 2.0, 0.02, ModelKit.paint(trim))
				arch.rotation.x = PI / 2.0
				arch.position = Vector3(x, y0 + h, z + 0.02)
	# A step up to the door.
	if lo.y <= 0.0:
		ModelKit.box(root, Vector3(x - w / 2 - 0.05, 0, z), Vector3(x + w / 2 + 0.05, PLINTH * 0.7, z + 0.1),
			ModelKit.surface(STONE, "stone", 0.2))


## Windows on the side the camera sees (+x), and on the front beside the door if the wall is wide.
static func _windows(ctx: Dictionary, count: int, trim: Color) -> void:
	if count <= 0:
		return
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var y := lo.y + (hi.y - lo.y) * 0.58
	var size := minf(0.2, (hi.y - lo.y) * 0.3)
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
			var p := Vector3(fw * 0.82, 0, fd * 0.2)
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
			var n := int(f.get("count", 6))
			for k in n:
				var p := Vector3(fw * (0.25 + 0.5 * (k % 3) / 2.0), 0, fd * (0.3 + 0.4 * (k / 3)))
				TreeModel.build_at(root, p, {"color": "#d63c2f"}, 0.55, true)
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
