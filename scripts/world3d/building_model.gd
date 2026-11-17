class_name BuildingModel
extends RefCounted
## Builds a building in 3D from its description in data/building_models.json: a stone footing, walls with
## their pattern, a roof, a door and windows, white trim at the corners, and the features that make each
## kind of building its own (a coop on stilts with a ramp, a dairy's silo and loft door, a stable's row of
## half-doors, yards, troughs, hay, hives, a pond...). The node's origin is the footprint's back corner;
## x runs along its columns and z along its rows, one unit a tile.

const PATH := "res://data/building_models.json"
const SKIRT_PITCH := 0.3      # the pent roof round a ground floor under an upper storey: rise over half-span
const SKIRT_OVER := 0.1        # and how far it overhangs
const SPILL_REACH := 0.8      # how far a lit building's light reaches over the ground, in tiles
const SILO_CHECKS := 14   # dark panels in the chequered band of a silo
const PLINTH := 0.13         # a building's stone footing stands this high..
const FOOT_OUT := 0.085      # ..on a broad low course this much wider than the walls (it is battered)
const FRIEZE := 0.075        # the board that runs round the top of the walls, under the eaves
const FRAME_OUT := 0.04      # a window's frame stands this proud of its wall
const PICKET_GAP := 0.12      # between a picket fence's pickets, in tiles
const WINDOWS := &"window_spots"   # meta on a marker child: the windows animals can look out of ([{at, size}])
const DOOR := &"door_swing"   # meta on a door's hinge: which way it swings open
const DOOR_WALL := 0.85       # the wall height a door's own height is given for
## The features that are one building's own (`_signature`).
const SLIDE := "slide"   # not-ui (a meta on a door that rolls up: how far)
const STORING := "storing"   # not-ui (a building type: Game.building_type)
const PLAN := "plan"         # not-ui (the state of the part that shows what is still to be built: `_plan`)
const PLAN_SNAP := 0.005     # two shapes within this of each other, in tiles, are the same shape
const HARVESTING := "harvesting"   # not-ui (a building type: Game.building_type)
const BALE := Vector3(0.13, 0.15, 0.09)   # a hay bale's half length, its height and half width, in tiles
const ROUGH_MOUNDS := 7           # low humps in a rough yard's ground..
const ROUGH_TUFTS := 8            # ..and tufts of straw lying on it
const DUCK_HOUSE := Vector3(0.2, 0.24, 0.16)   # a duck house: half its width, its walls' height, half its depth
const HIVE_BOX := Vector3(0.29, 0.18, 0.25)   # a beehive's box: half width, height and half depth, in tiles
const SIGNATURES: Array[String] = ["rock", "pool", "wallow", "carrots", "fuel_pump", "mobile", "burrow"]
## Yard features' size (their radius in tiles, unless the data gives `r`).
const FEATURE_R := {"rock": 0.3, "pool": 0.32, "wallow": 0.34, "carrots": 0.26, "fuel_pump": 0.18, "burrow": 0.34}
const HILL := Color("#6fae45")   # a burrow's grassy hill
const STILL_WATER := Color("#2999d6")   # painted water that does not move, in the water's own blue
## A goat's climbing rock: (x, z offset as shares of its radius, radius share, height share).
const ROCK_BOULDERS: Array[Vector4] = [Vector4(0, 0, 0.75, 1.3), Vector4(0.55, 0.3, 0.5, 0.9),
	Vector4(-0.5, 0.35, 0.45, 0.8), Vector4(0.1, -0.5, 0.5, 0.95), Vector4(0.15, 0.1, 0.45, 2.1)]
const PASTELS: Array[Color] = [Color("#f4b6c9"), Color("#a9d4ef"), Color("#f6e3a1")]
# A broken building (the starter Barn, before it is repaired): see _broken.
const TARP := Color("#3f78b5")
const TARP_LIFT := 0.02       # how far the tarp lies proud of the roof
const TARP_FROM := 0.3        # and the share of the roof's length it covers, from here
const TARP_TO := 0.72
const BOARD_GAP := 0.055      # a missing board's height
## Missing boards: (along the wall, up the wall, length), as shares; even ones on the front, odd on the side.
const BROKEN_GAPS: Array[Vector3] = [Vector3(0.2, 0.62, 0.16), Vector3(0.7, 0.55, 0.2), Vector3(0.8, 0.3, 0.12),
	Vector3(0.4, 0.78, 0.18), Vector3(0.66, 0.72, 0.1)]
const LOOSE_TILT := 0.5       # radians a loose board hangs askew
const DOOR_AJAR := 0.35       # radians a broken door hangs open
const DOOR_SAG := 0.06        # and leans
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
static var _fills := {}   # fill_of, by "id|level"


## How a building is built at a size (`level`, 1 the smallest): its own description over the defaults,
## then each size's changes up to `level` laid on in turn (data "levels": {"2": {...}, "3": {...}}).
## A size's "drop" first removes features of those types; its "features" are added; anything else
## (body, roof, door: merged; windows, window_rows: replaced) changes the building itself.
## A number of the look every building shares (data/building_models.json "look"); 1 when it is not set.
static func _look(key: String) -> float:
	_load()
	return float((_data.get("look", {}) as Dictionary).get(key, 1.0))


## The shared look laid over a building's own numbers: lower walls and a bigger door (chunky, as the farm art
## these follow is), and for a home with a yard a smaller shed drawn back into its corner, so the yard and the
## animals in it are most of what is seen.
static func _styled(s: Dictionary) -> Dictionary:
	var body: Dictionary = s["body"]
	body["h"] = float(body.get("h", 0.85)) * _look("walls")
	var yard := (s.get("features", []) as Array).any(func(f: Dictionary) -> bool: return f.get("type") == "yard")
	if yard:
		var k := _look("shed")
		var at: Array = body.get("at", [0.5, 0.42])
		var w := float(body.get("w", 0.7))
		var d := float(body.get("d", 0.66))
		body["at"] = [float(at[0]) - w * (1.0 - k) / 2.0, float(at[1]) - d * (1.0 - k) / 2.0]
		body["w"] = w * k
		body["d"] = d * k
	var door: Dictionary = s.get("door", {})
	door["w"] = float(door.get("w", 0.28)) * _look("door")
	door["h"] = minf(float(door.get("h", 0.55)) * _look("door"), float(body["h"]) * 0.8)
	s["door"] = door
	return s


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
	return _styled(out)


## What a building's model says about its fill (see BuildingFill): cached, since it is asked for every sync.
## Read-only: callers must not change it.
static func fill_of(id: String, level := 1) -> Dictionary:
	var key := "%s|%d" % [id, level]
	if not _fills.has(key):
		_fills[key] = spec(id, level).get("fill", {})
	return _fills[key]


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
			"hay_bales" when f.has("at"):
				var spot := yard_spot(f, fw, fd)
				var half := Vector2(BALE.x * 2.0 + 0.04, BALE.z * 2.0) * float(f.get("scale", 1.0))
				out.append(Rect2(spot - half, half * 2.0))
			"rack" when f.has("at"):
				var spot := yard_spot(f, fw, fd)
				out.append(Rect2(spot.x - 0.28, spot.y - 0.16, 0.56, 0.32))
			"hive":
				var spot := yard_spot(f, fw, fd)
				out.append(Rect2(spot.x - HIVE_BOX.x - 0.08, spot.y - HIVE_BOX.z - 0.06, HIVE_BOX.x * 2.0 + 0.16,
					HIVE_BOX.z * 2.0 + 0.3))
			"lean_to", "terrace", "barrels", "hay_bales":
				out.append(Rect2(hi.x, lo.y, minf(0.5, fw - hi.x), bd))
			"porch", "stall_doors":
				out.append(Rect2(lo.x, hi.y, bw, 0.32))
			"water_trough":
				var spot := _trough_at(hi, fw, fd)
				out.append(Rect2(spot.x - 0.22, spot.y - 0.09, 0.44, 0.18))
			"silo":
				var p: Array = f.get("at", [0.85, 0.2])
				var r := float(f.get("r", 0.22)) + 0.04
				out.append(Rect2(float(p[0]) * fw - r, float(p[1]) * fd - r, r * 2.0, r * 2.0))
			"duck_house":
				var p: Array = f.get("at", [0.82, 0.2])
				out.append(Rect2(float(p[0]) * fw - 0.24, float(p[1]) * fd - 0.2, 0.48, 0.8))
			"beehives":
				var n := int(f.get("count", 3))
				for k in n:
					var x := lerpf(0.4, fw - 0.4, k / maxf(n - 1.0, 1.0))
					out.append(Rect2(x - 0.18, fd * (0.4 + 0.2 * (k % 2)) - 0.16, 0.36, 0.32))
			"ramp":
				out.append(Rect2((lo.x + hi.x) / 2.0 - 0.1, hi.y, 0.2, 0.45))
			"nest_boxes":
				out.append(Rect2(hi.x, lo.y, 0.14, bd))
			"rock", "pool", "wallow", "carrots", "fuel_pump", "burrow":
				var spot := yard_spot(f, fw, fd)
				var r := float(f.get("r", FEATURE_R.get(str(f["type"]), 0.3)))
				out.append(Rect2(spot.x - r, spot.y - r, r * 2.0, r * 2.0))
	return out


## Where a yard's water trough stands, by its building's front right corner `hi` (x, z).
static func _trough_at(hi: Vector2, fw: float, fd: float) -> Vector2:
	return Vector2(minf(hi.x + 0.45, fw - 0.3), minf(hi.y + 0.35, fd - 0.2))


## Where the animals of a yard can drink: the middle of each water trough in it (BuildingFill sends them).
static func troughs(s: Dictionary, fp: Vector2i) -> Array[Vector2]:
	var body: Dictionary = s["body"]
	var at: Array = body.get("at", [0.5, 0.42])
	var hi := Vector2(float(at[0]) * fp.x + float(body.get("w", 0.7)) * fp.x / 2.0,
		float(at[1]) * fp.y + float(body.get("d", 0.66)) * fp.y / 2.0)
	var out: Array[Vector2] = []
	for f: Dictionary in s.get("features", []):
		if str(f.get("type", "")) == "water_trough":
			out.append(_trough_at(hi, fp.x, fp.y))
	return out


## Where a feature that stands in the yard goes: its `at` (shares of the footprint), or the front right corner.
static func yard_spot(f: Dictionary, fw: float, fd: float) -> Vector2:
	var at: Array = f.get("at", [0.74, 0.74])
	return Vector2(float(at[0]) * fw, float(at[1]) * fd)


## The whole building at its size, under a new node. `fp` is the footprint in tiles (columns, rows).
## `active` is whether it is at work (a bakery with something in the oven): only then does its chimney smoke.
## `fill` is how full a crafting building is of finished things, 0 to BuildingDress.FULL: its storage parts
## (features marked `"part": "storage"`) show it. Its animated parts (`"part": "animated"`) move only while
## it is `active`. Every state is in the one model (parts named as AssetRegistry's states are); `active` and
## `fill` only say which it shows first, and `show_state` changes that without building anything.
static func build(it: Dictionary, fp: Vector2i, level := 1, active := true, broken := false,
		fill := 0) -> Node3D:
	var ctx := _assemble(it, fp, level, active, broken, fill)
	var root: Node3D = ctx["root"]
	if not broken:
		_plan(ctx, it, fp, level)
	# What shows in one state only (BuildingDress.when) is merged, part by part, and kept apart from the rest so
	# it can be switched; the building comes out showing the state asked for.
	for part: String in (ctx.get("states", {}) as Dictionary):
		var loose: Node3D = ctx["states"][part]
		root.remove_child(loose)
		if part.begins_with(AssetRegistry.STATE + "fill"):
			ModelKit.no_shadows(loose)   # (a storage look is small things: one draw, no shadow pass of its own)
		var merged := ModelKit.bake(loose)
		merged.name = part
		merged.set_meta(ModelKit.KEEP, true)
		root.add_child(merged)
	show_state(root, active, fill)
	return SpaceFit.fit_model(root, fp)


## The size after `level` that changes how building `id` looks, or -1 when `level` is its last look.
static func next_size(id: String, level: int) -> int:
	var next := -1
	for size: int in sizes_of(id):
		if size > level and (next < 0 or size < next):
			next = size
	return next


## What the building does not have yet (a rule for every building that grows; our own touch): each shape its
## next size has and this one lacks, gathered into one part that is drawn as a timber frame
## (`when_plan_true`, ModelKit.frame_material), so a building that can still grow shows what it will become.
## Shapes are told apart by where they are and how big: a wall repainted is the same shape, a taller one is
## not. What shows in one state only, and what moves by an effect, is left out. A building whose description
## says `"plan": false` shows none.
static func _plan(ctx: Dictionary, it: Dictionary, fp: Vector2i, level: int) -> void:
	var next := next_size(str(it.get("id", "")), level)
	if next < 0 or not bool((ctx["spec"] as Dictionary).get("plan", true)):
		return
	var have := {}
	for shape: Array in _shapes(ctx["root"], Transform3D.IDENTITY):
		have[_shape_key(shape)] = true
	var ahead: Node3D = _assemble(it, fp, next, false, false, 0)["root"]
	for shape: Array in _shapes(ahead, Transform3D.IDENTITY):
		if have.has(_shape_key(shape)):
			continue
		var from := shape[0] as MeshInstance3D
		var mesh := ArrayMesh.new()
		for s in from.mesh.get_surface_count():   # (one vertex layout for all of them: they merge into one draw)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
				ModelKit.tint_arrays(from.mesh.surface_get_arrays(s), Color.WHITE))
		var copy := MeshInstance3D.new()
		copy.mesh = mesh
		copy.transform = shape[1]
		copy.material_override = ModelKit.frame_material()
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		BuildingDress.when(ctx, PLAN, true).add_child(copy)
	ahead.free()


## Every solid shape under `node` as [its mesh instance, where it is in the model]: not what shows in one state
## only, nor an effect.
static func _shapes(node: Node, xf: Transform3D) -> Array:
	var out := []
	for child in node.get_children():
		var kind := String(child.name).split("_")[0]
		if not child is Node3D or String(child.name).begins_with(AssetRegistry.STATE) or DecorMotion.EFFECTS.has(kind):
			continue
		var c := child as Node3D
		var cxf := xf * c.transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append([c, cxf])
		out.append_array(_shapes(c, cxf))
	return out


## What tells one shape from another: the box it fills in the model, to PLAN_SNAP.
static func _shape_key(shape: Array) -> String:
	var box: AABB = (shape[1] as Transform3D) * (shape[0] as MeshInstance3D).mesh.get_aabb()
	var grain := Vector3.ONE * PLAN_SNAP
	return "%s|%s" % [box.position.snapped(grain), box.size.snapped(grain)]


## Everything a building is made of at a size, loose under a new node (`root` in what it returns, the build's
## own notes with it): `build` merges it and fits it to its plot.
static func _assemble(it: Dictionary, fp: Vector2i, level: int, active: bool, broken: bool, fill: int) -> Dictionary:
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
	# (a level's spec can repaint the walls: the Barn's first looks are bare planks, then red)
	var wall_col := Color.html(str(s.get("color", it.get("color", "#c0392b"))))
	var ctx := {"root": root, "fw": fw, "fd": fd, "centre": centre, "bw": bw, "bd": bd, "bh": bh, "lift": lift,
		"wall": wall_col, "spec": s, "it": it, "active": active, "fill": fill,
		"harvesting": str(it.get("type", "")) == HARVESTING, "level": level}
	# Yards go down first (they're on the ground, under everything).
	for f: Dictionary in s.get("features", []):
		if f.get("type") == "yard":
			_yard(ctx, f)
	# A maxed building (it wears a crown) has its roofs edged in gold.
	for f: Dictionary in s.get("features", []):
		if f.get("type") == "crown":
			ModelKit.roof_trim = BuildingDress.GOLD
	if bw > 0.0 and bh > 0.0:
		if str(body.get("shape", "block")) == "tower":
			_tower(ctx)
		else:
			_body(ctx)
	for f: Dictionary in s.get("features", []):
		if f.get("type") != "yard":
			_feature(ctx, f)
	ModelKit.roof_trim = ModelKit.RAKE_COLOUR
	if broken and ctx.has("lo"):
		_broken(ctx)
	if str(it.get("kind", "")) == "crafting" or str(it.get("type", "")) == STORING:
		# Nobody goes in and out of a crafting building or a store: its door is part of the walls, not a thing
		# on hinges (a Garage's shutter does roll up: it stays a part).
		for c in root.get_children():
			if c.has_meta(DOOR) and not c.has_meta(SLIDE):
				c.remove_meta(DOOR)
				c.remove_meta(ModelKit.KEEP)
	return ctx


## Shows a built building (or a copy of one) at work or not and as full as `fill` (0 to BuildingDress.FULL): its
## animated parts move or stand still, its storage parts show that look. Nothing is built again.
static func show_state(model: Node3D, working: bool, fill := 0) -> void:
	AssetRegistry.apply_state(model, {"working": working, "fill": fill})


## FarmVille's starter Barn before it is repaired: a blue tarp over part of the roof on the side you see, boards
## missing from the walls (dark gaps), a loose board hanging askew, its doors sagging ajar, and planks lying by
## the wall. It reads as broken at a glance and as the same barn once fixed.
static func _broken(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var r: Dictionary = (ctx["spec"] as Dictionary)["roof"]
	var kind := str(r.get("type", "gable"))
	var tarp := ModelKit.paint(TARP)
	var mid := (lo + hi) / 2.0
	if kind in ["gable", "gambrel"] and (ctx["spec"] as Dictionary).get("upper", {}).is_empty():
		var rise := float(r.get("pitch", 0.7)) * minf(hi.x - lo.x, hi.z - lo.z) / 2.0
		for q: Array in ModelKit.roof_slopes(kind, lo, hi, rise, float(r.get("overhang", 0.08))):
			var centre: Vector3 = (q[0] + q[1] + q[2] + q[3]) / 4.0
			if centre.x + centre.z <= mid.x + mid.z:
				continue   # (the far slopes: unseen)
			var out: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
			if out.dot(centre - Vector3(mid.x, hi.y, mid.z)) < 0.0:
				out = -out
			var lift := out * TARP_LIFT
			var a: Vector3 = q[0].lerp(q[1], TARP_FROM) + lift
			var b: Vector3 = q[0].lerp(q[1], TARP_TO) + lift
			var c: Vector3 = q[3].lerp(q[2], TARP_TO) + lift
			var d: Vector3 = q[3].lerp(q[2], TARP_FROM) + lift
			ModelKit.faces(root, [[a, b, c, d]], centre - out, tarp)
	else:
		var top := float(ctx.get("top", hi.y))
		ModelKit.box(root, Vector3(mid.x - 0.2, top, mid.z - 0.15), Vector3(mid.x + 0.15, top + 0.02, mid.z + 0.2),
			tarp)
	# Gaps where boards are missing, on the two walls the camera sees (+z front, +x side).
	var gap := ModelKit.paint(DARK)
	var h := hi.y - lo.y
	for k in BROKEN_GAPS.size():
		var g: Vector3 = BROKEN_GAPS[k]   # (along the wall, up the wall, length) as shares
		if k % 2 == 0:
			var x := lerpf(lo.x, hi.x, g.x)
			var y := lo.y + h * g.y
			ModelKit.box(root, Vector3(x - g.z * 0.5, y, hi.z), Vector3(x + g.z * 0.5, y + BOARD_GAP, hi.z + 0.006),
				gap)
		else:
			var z := lerpf(lo.z, hi.z, g.x)
			var y2 := lo.y + h * g.y
			ModelKit.box(root, Vector3(hi.x, y2, z - g.z * 0.5), Vector3(hi.x + 0.006, y2 + BOARD_GAP, z + g.z * 0.5),
				gap)
	# A loose board hanging askew on the side wall, and two lying by the front.
	var board := ModelKit.surface(WOOD, "boards")
	var loose := ModelKit.box(root, Vector3(-0.17, -0.02, -0.004), Vector3(0.17, 0.02, 0.004), board)
	if loose != null:
		loose.position = Vector3(hi.x + 0.012, lo.y + h * 0.42, lerpf(lo.z, hi.z, 0.3))
		loose.rotation = Vector3(0.0, PI / 2.0, 0.0)
		loose.rotate_object_local(Vector3(0, 0, 1), LOOSE_TILT)
	for k in 2:
		var plank := ModelKit.box(root, Vector3(-0.18, 0, -0.025), Vector3(0.18, 0.018, 0.025), board)
		if plank != null:
			plank.position = Vector3(lerpf(lo.x, hi.x, 0.18 + 0.12 * k), 0.0, hi.z + 0.16 + 0.05 * k)
			plank.rotation.y = 0.25 - 0.5 * k
	# The doors sag ajar on their hinges.
	for hinge in root.get_children():
		if hinge is Node3D and hinge.has_meta(DOOR):
			var swing := float(hinge.get_meta(DOOR))
			(hinge as Node3D).rotation = Vector3(0.0, swing * DOOR_AJAR, -swing * DOOR_SAG)


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
		var sides := [[Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z)], [Vector3(hi.x, 0, lo.z), Vector3(hi.x, 0,
			hi.z)],
			[Vector3(hi.x, 0, hi.z), Vector3(lo.x, 0, hi.z)], [Vector3(lo.x, 0, hi.z), Vector3(lo.x, 0, lo.z)]]
		for k in 4:
			var share := clampf(footing * 4.0 - k, 0.0, 1.0)
			if share <= 0.0:
				break
			var a: Vector3 = sides[k][0]
			var b: Vector3 = a.lerp(sides[k][1], share)
			ModelKit.box(root, Vector3(minf(a.x, b.x), 0, minf(a.z, b.z)) - Vector3(0.05, 0, 0.05),
				Vector3(maxf(a.x, b.x), PLINTH, maxf(a.z, b.z)) + Vector3(0.05, 0, 0.05), ModelKit.surface(STONE,
					"stone", 0.3))
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
		var t := 0.03 * _look("trim")
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
	return SpaceFit.fit_model(root, fp)   # (a site keeps the tile border too: neighbours never touch)



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
		ModelKit.box(root, Vector3(lx + side - 0.01, 0, z + 0.05), Vector3(lx + side + 0.01, top - 0.1, z + 0.07),
			timber)
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
	var mi := ModelKit.box(root, Vector3(-t / 2.0, -t / 2.0, -length / 2.0), Vector3(t / 2.0, t / 2.0, length / 2.0),
		mat)
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
		ModelKit.cylinder(root, at + Vector3(0.0, 0, -0.38), 0.06, 0.12, ModelKit.surface(Color("#7c4a2a"), "boards",
			0.2))


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
		# A stone footing, battered: a broad low course, and the footing proper on it, wider than the walls. The
		# building stands on something.
		ModelKit.box(root, lo - Vector3(FOOT_OUT, 0, FOOT_OUT), Vector3(hi.x + FOOT_OUT, PLINTH * 0.42,
			hi.z + FOOT_OUT),
			ModelKit.surface(STONE.darkened(0.12), "stone", 0.35))
		ModelKit.box(root, lo - Vector3(0.045, 0, 0.045), Vector3(hi.x + 0.045, PLINTH, hi.z + 0.045),
			ModelKit.surface(STONE, "stone", 0.3))
	var wall_mat := ModelKit.surface(ctx["wall"], walls)
	ModelKit.box(root, Vector3(lo.x, maxf(lo.y, PLINTH * 0.5), lo.z), hi, wall_mat)
	# White corner boards.
	var t := 0.035 * _look("trim")
	for corner: Vector2 in [Vector2(lo.x, lo.z), Vector2(hi.x, lo.z), Vector2(hi.x, hi.z), Vector2(lo.x, hi.z)]:
		ModelKit.box(root, Vector3(corner.x - t, lo.y, corner.y - t), Vector3(corner.x + t, hi.y, corner.y + t),
			ModelKit.paint(trim))
	# A frieze board round the top of the walls, and the shadow the eaves throw under it.
	ModelKit.box(root, Vector3(lo.x - 0.014, hi.y - FRIEZE, lo.z - 0.014), Vector3(hi.x + 0.014, hi.y, hi.z + 0.014),
		ModelKit.paint(trim))
	ModelKit.box(root, Vector3(lo.x - 0.006, hi.y - FRIEZE - 0.03, lo.z - 0.006), Vector3(hi.x + 0.006, hi.y - FRIEZE,
		hi.z + 0.006), ModelKit.paint((ctx["wall"] as Color).darkened(0.42)), false)
	# Roof.
	var r: Dictionary = s["roof"]
	var kind := str(r.get("type", "gable"))
	var top := hi.y
	var upper: Dictionary = s.get("upper", {})
	if not upper.is_empty():
		top = _upper_storey(ctx, lo, hi, wall_mat, trim, upper)
	elif kind != "none":
		var span := minf(bw, bd)
		var rise := float(r.get("pitch", 0.7)) * span / 2.0
		var roof_mat := ModelKit.surface(Color.html(str(r.get("color", "#8e3b2c"))), str(r.get("style", "shingles")),
			0.0)
		top = ModelKit.roof(root, kind, lo, hi, rise, float(r.get("overhang", 0.1)), roof_mat, wall_mat)
	ctx["top"] = top
	ctx["lo"] = lo
	ctx["hi"] = hi
	_door(ctx, trim)
	_windows(ctx, int(s.get("windows", 2)), trim, int(s.get("window_rows", 1)))
	_settle(ctx)


## A round tower instead of a block (a windmill): BuildingDress builds it, and its door hangs in the flat case
## at its foot.
static func _tower(ctx: Dictionary) -> void:
	var case := BuildingDress.tower(ctx)
	var at_door := ctx.duplicate()
	at_door["lo"] = case[0]
	at_door["hi"] = case[1]
	_door(at_door, Color.html(str((ctx["spec"] as Dictionary).get("trim", "#f3eee2"))))
	_settle(ctx)


## What every body ends with: where its windows are, the light it spills at night, and the ground it stands on.
static func _settle(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var marker := Node3D.new()   # (read by BuildingFill, which puts animals' heads in them when the home is full)
	marker.set_meta(ModelKit.KEEP, true)
	marker.set_meta(WINDOWS, ctx.get("window_at", []))
	root.add_child(marker)
	_light_spill(ctx)
	BuildingDress.ground(ctx)


## A second storey (the top size of a big building): the ground floor under a low pent roof that runs all
## round it, and a smaller upper floor set back on top of it, with its own walls, windows and roof. The
## `upper` description (data/building_models.json) gives w and d as shares of the ground floor, h, windows,
## and optionally its own roof, walls and colour. Returns the top of the whole building; the upper floor's
## corners go in ctx as upper_lo and upper_hi (balconies and hoists hang on them).
static func _upper_storey(ctx: Dictionary, lo: Vector3, hi: Vector3, wall_mat: Material, trim: Color,
		upper: Dictionary) -> float:
	var root: Node3D = ctx["root"]
	var s: Dictionary = ctx["spec"]
	var r: Dictionary = s["roof"]
	var roof_col := Color.html(str(r.get("color", "#8e3b2c")))
	var roof_mat := ModelKit.surface(roof_col, str(r.get("style", "shingles")), 0.0)
	var bw: float = ctx["bw"]
	var bd: float = ctx["bd"]
	# The ground floor's own roof: low, all round, as a skirt under the upper floor.
	ModelKit.roof(root, "hip", lo, hi, SKIRT_PITCH * minf(bw, bd) / 2.0, SKIRT_OVER, roof_mat, wall_mat)
	var c: Vector3 = ctx["centre"]
	var uw := bw * float(upper.get("w", 0.8))
	var ud := bd * float(upper.get("d", 0.86))
	var uh := float(upper.get("h", 0.7))
	var shift := float(upper.get("back", 0.0))
	var ulo := Vector3(c.x - uw / 2.0, hi.y, c.z - ud / 2.0 - shift)
	var uhi := Vector3(c.x + uw / 2.0, hi.y + uh, c.z + ud / 2.0 - shift)
	var own_wall := wall_mat
	if upper.has("walls") or upper.has("color"):
		own_wall = ModelKit.surface(Color.html(str(upper.get("color", "#" + (ctx["wall"] as Color).to_html(false)))),
			str(upper.get("walls", (s["body"] as Dictionary).get("walls", "boards"))))
	ModelKit.box(root, ulo, uhi, own_wall)
	# A trim band where the storeys meet, and white corner boards up the upper floor.
	ModelKit.box(root, ulo - Vector3(0.02, 0, 0.02), Vector3(uhi.x + 0.02, ulo.y + 0.04, uhi.z + 0.02),
		ModelKit.paint(trim))
	var t := 0.03
	for corner: Vector2 in [Vector2(ulo.x, ulo.z), Vector2(uhi.x, ulo.z), Vector2(uhi.x, uhi.z), Vector2(ulo.x,
		uhi.z)]:
		ModelKit.box(root, Vector3(corner.x - t, ulo.y, corner.y - t), Vector3(corner.x + t, uhi.y, corner.y + t),
			ModelKit.paint(trim))
	var up_roof: Dictionary = upper.get("roof", {})
	var kind := str(up_roof.get("type", r.get("type", "gable")))
	var top := uhi.y
	if kind != "none":
		var pitch := float(up_roof.get("pitch", r.get("pitch", 0.7)))
		var mat := roof_mat
		if up_roof.has("color"):
			mat = ModelKit.surface(Color.html(str(up_roof["color"])), str(r.get("style", "shingles")), 0.0)
		top = ModelKit.roof(root, kind, ulo, uhi, pitch * minf(uw, ud) / 2.0, float(r.get("overhang", 0.08)), mat,
			own_wall)
	ctx["upper_lo"] = ulo
	ctx["upper_hi"] = uhi
	var sub := ctx.duplicate()
	sub["lo"] = ulo
	sub["hi"] = uhi
	_windows(sub, int(upper.get("windows", 2)), trim, 1)
	return top


## At night a building's windows and door throw warm light on the ground in front of them and beside them.
static func _light_spill(ctx: Dictionary) -> void:
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var root: Node3D = ctx["root"]
	var door: Dictionary = (ctx["spec"] as Dictionary).get("door", {})
	var reach_z := minf(SPILL_REACH, float(ctx["fd"]) - hi.z + 0.05)   # never off the footprint
	var reach_x := minf(SPILL_REACH, float(ctx["fw"]) - hi.x + 0.05)
	var pools: Array = []   # (one at the door, one under the windows: drawn together)
	if str(door.get("style", "barn")) != "none" and reach_z > 0.1:
		pools.append([Vector3((lo.x + hi.x) / 2.0, 0, hi.z - 0.05 + reach_z / 2.0), Vector2((hi.x - lo.x) * 0.9, reach_z)])
	if int((ctx["spec"] as Dictionary).get("windows", 2)) > 0 and reach_x > 0.1:
		pools.append([Vector3(hi.x - 0.05 + reach_x / 2.0, 0, (lo.z + hi.z) / 2.0), Vector2(reach_x,
			(hi.z - lo.z) * 0.9)])
	if not pools.is_empty():
		ModelKit.glow_pools(root, pools)


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
	# A barn's big doors grow with its walls (up to half again); a house door stays a house door.
	var h := float(d.get("h", 0.55)) * (clampf((hi.y - lo.y) / DOOR_WALL, 1.0, 1.5) if style == "barn" else 1.0)
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
					# (painted like its braces: a leaf is one draw)
					ModelKit.paint((ctx["wall"] as Color).darkened(0.25)))
				# The white X-braces of a barn door.
				var brace := ModelKit.paint(trim)
				ModelKit.box(leaf, Vector3(cx - w / 4.0, y0, z + 0.029), Vector3(cx + w / 4.0, y0 + 0.04, z + 0.044),
					brace)
				ModelKit.box(leaf, Vector3(cx - w / 4.0, y0 + h - 0.04, z + 0.029),
					Vector3(cx + w / 4.0, y0 + h, z + 0.044), brace)
				var diag := ModelKit.box(leaf, Vector3(cx - 0.02, y0, z + 0.029), Vector3(cx + 0.02, y0 + h * 1.05,
					z + 0.044),
					brace)
				if diag != null:
					diag.rotation.z = side * atan2(w / 2.0, h)
			# Its frame: a post each side and a heavy lintel.
			ModelKit.box(root, Vector3(x - w / 2 - 0.06, y0 + h, z), Vector3(x + w / 2 + 0.06, y0 + h + 0.06,
				z + 0.06),
				ModelKit.paint(trim))
			for side: float in [-1.0, 1.0]:
				ModelKit.box(root, Vector3(x + side * (w / 2 + 0.03) - 0.03, y0, z),
					Vector3(x + side * (w / 2 + 0.03) + 0.03,
					y0 + h, z + 0.05), ModelKit.paint(trim))
		"roller":
			var shutter := _hinge(root, Vector3(x, y0, z), 0.0)
			shutter.get_parent().set_meta(SLIDE, h * 0.85)
			ModelKit.box(shutter, Vector3(x - w / 2, y0, z + 0.004), Vector3(x + w / 2, y0 + h, z + 0.024),
				ModelKit.surface(Color("#c9ced2"), "metal"))
		"mesh", "hatch":
			var flap := _hinge(root, Vector3(x - w / 2, y0, z), -1.0)
			ModelKit.box(flap, Vector3(x - w / 2, y0, z + 0.004), Vector3(x + w / 2, y0 + h, z + 0.024),
				ModelKit.paint(DARK)
				if style == "mesh" else ModelKit.surface(WOOD, "boards"))
			ModelKit.box(root, Vector3(x - w / 2 - 0.02, y0 + h, z), Vector3(x + w / 2 + 0.02, y0 + h + 0.03,
				z + 0.04),
				ModelKit.paint(trim))
		_:
			# A painted door in a frame (and, for an arch, a rounded top instead of a lintel).
			if style != "arch":
				ModelKit.box(root, Vector3(x - w / 2 - 0.03, y0 + h, z), Vector3(x + w / 2 + 0.03, y0 + h + 0.03,
					z + 0.02),
					ModelKit.paint(trim))
			for side: float in [-1.0, 1.0]:
				ModelKit.box(root, Vector3(x + side * (w / 2 + 0.015) - 0.015, y0, z),
					Vector3(x + side * (w / 2 + 0.015) + 0.015, y0 + h, z + 0.02), ModelKit.paint(trim))
			var door_col := Color.html(str(d.get("color", "#6b3f26")))
			var door := _hinge(root, Vector3(x - w / 2, y0, z), -1.0)
			ModelKit.box(door, Vector3(x - w / 2, y0, z + 0.006), Vector3(x + w / 2, y0 + h, z + 0.026),
				ModelKit.paint(door_col))
			ModelKit.ball(door, Vector3(x + w / 2 - 0.04, y0 + h * 0.5, z + 0.03), 0.012,
				ModelKit.paint(Color("#d4b04a"), 0.7))
			if style == "arch":
				# Discs centred on the door's top, set back so their lower halves hide behind the door and its
				# posts: what shows is a rounded top in the door's colour inside a ring of trim.
				for disc: Array in [[w / 2.0 + 0.03, z + 0.001, trim], [w / 2.0, z + 0.003, door_col]]:
					var arch := ModelKit.cylinder(root, Vector3.ZERO, disc[0], 0.008, ModelKit.paint(disc[2]))
					arch.rotation.x = PI / 2.0
					arch.position = Vector3(x, y0 + h, disc[1] + 0.004)
	# Two broad steps up to the door.
	if lo.y <= 0.0:
		ModelKit.box(root, Vector3(x - w / 2 - 0.1, 0, z), Vector3(x + w / 2 + 0.1, PLINTH * 0.45, z + 0.2),
			ModelKit.surface(STONE.lightened(0.06), "stone", 0.2))
		ModelKit.box(root, Vector3(x - w / 2 - 0.06, 0, z), Vector3(x + w / 2 + 0.06, PLINTH * 0.9, z + 0.11),
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
	var size := minf(0.2, wall_h * (0.3 if rows == 1 else 0.42 / rows)) * _look("window")
	size = minf(size, wall_h * 0.5 / rows)   # (big, but inside its wall)
	for row in rows:
		var share := 0.58 if rows == 1 else lerpf(0.32, 0.74, row / (rows - 1.0))
		_window_row(ctx, count, trim, share, size)


static func _window_row(ctx: Dictionary, count: int, trim: Color, share: float, size: float) -> void:
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var y := lo.y + (hi.y - lo.y) * share
	var spots: Array = ctx.get("window_at", [])
	ctx["window_at"] = spots
	for k in count:
		var z := lerpf(lo.z, hi.z, (k + 1.0) / (count + 1.0))
		spots.append({"at": Vector3(hi.x, y, z), "size": size})
		var frame := 0.03 * _look("trim")
		# A thick frame standing proud of the wall, the glass set back in it behind a cross of bars.
		ModelKit.box(root, Vector3(hi.x, y - size / 2 - frame, z - size / 2 - frame),
			Vector3(hi.x + FRAME_OUT, y + size / 2 + frame, z + size / 2 + frame), ModelKit.paint(trim))
		ModelKit.box(root, Vector3(hi.x + FRAME_OUT, y - size / 2, z - size / 2), Vector3(hi.x + FRAME_OUT + 0.004,
			y + size / 2, z + size / 2), ModelKit.glass())
		ModelKit.box(root, Vector3(hi.x + FRAME_OUT, y - 0.011, z - size / 2), Vector3(hi.x + FRAME_OUT + 0.014,
			y + 0.011,
			z + size / 2), ModelKit.paint(trim), false)
		ModelKit.box(root, Vector3(hi.x + FRAME_OUT, y - size / 2, z - 0.011), Vector3(hi.x + FRAME_OUT + 0.014,
			y + size / 2, z + 0.011), ModelKit.paint(trim), false)
		# A header over it and a deep sill under it.
		ModelKit.box(root, Vector3(hi.x, y + size / 2 + frame, z - size / 2 - frame - 0.025),
			Vector3(hi.x + FRAME_OUT + 0.025, y + size / 2 + frame + 0.035,
				z + size / 2 + frame + 0.025), ModelKit.paint(trim))
		ModelKit.box(root, Vector3(hi.x, y - size / 2 - frame - 0.035, z - size / 2 - frame - 0.035),
			Vector3(hi.x + 0.095, y - size / 2 - frame, z + size / 2 + frame + 0.035), ModelKit.paint(trim))
		_dress_window(ctx, Vector3(hi.x, y, z), size, k)


## What a window wears (the building's "dress" in data/building_models.json): shutters at its sides, a box of
## flowers under it, or both; nothing on a plain shed.
static func _dress_window(ctx: Dictionary, at: Vector3, size: float, index: int) -> void:
	var root: Node3D = ctx["root"]
	var spec: Dictionary = ctx["spec"]
	var dress := str(spec.get("dress", "shutters"))
	if dress == "none":
		return
	if dress in ["shutters", "both"]:
		var roof_col := Color.html(str((spec["roof"] as Dictionary).get("color", "#8e3b2c")))
		var shutter := ModelKit.surface(Color.html(str(spec.get("shutter",
			"#" + roof_col.darkened(0.05).to_html(false)))),
			"boards", 0.0)
		for side: float in [-1.0, 1.0]:
			var z0 := at.z + side * (size / 2.0 + 0.03)
			var z1 := z0 + side * size * 0.38
			ModelKit.box(root, Vector3(at.x, at.y - size / 2.0, minf(z0, z1)),
				Vector3(at.x + 0.03, at.y + size / 2.0, maxf(z0, z1)), shutter)
	if dress in ["flower_boxes", "both"]:
		var wood := ModelKit.surface(WOOD, "boards")
		var y := at.y - size / 2.0 - 0.1
		ModelKit.box(root, Vector3(at.x, y, at.z - size / 2.0 - 0.03),
			Vector3(at.x + 0.08, y + 0.05, at.z + size / 2.0 + 0.03), wood)
		var blooms: Array[Color] = [Color("#e8506e"), Color("#f5c518"), Color("#f7f2e8"), Color("#9b7be0")]
		for b in 4:
			var bz := lerpf(at.z - size / 2.0, at.z + size / 2.0, (b + 0.5) / 4.0)
			ModelKit.ball(root, Vector3(at.x + 0.04, y + 0.07, bz), 0.024,
				ModelKit.paint(blooms[(index + b) % blooms.size()]))
			ModelKit.ball(root, Vector3(at.x + 0.04, y + 0.05, bz), 0.02, ModelKit.paint(Color("#4a8f36")))


# ---------------------------------------------------------------- features


static func _feature(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var fw: float = ctx["fw"]
	var fd: float = ctx["fd"]
	var c: Vector3 = ctx["centre"]
	var lo: Vector3 = ctx.get("lo", c)
	var hi: Vector3 = ctx.get("hi", c)
	if BuildingDress.feature(ctx, f):
		return
	match str(f.get("type", "")):
		"stilts":
			var lift: float = ctx["lift"]
			for corner: Vector2 in [Vector2(lo.x + 0.05, lo.z + 0.05), Vector2(hi.x - 0.05, lo.z + 0.05),
					Vector2(hi.x - 0.05, hi.z - 0.05), Vector2(lo.x + 0.05, hi.z - 0.05)]:
				ModelKit.box(root, Vector3(corner.x - 0.03, 0, corner.y - 0.03), Vector3(corner.x + 0.03, lift,
					corner.y + 0.03),
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
		"egg_chutes":
			# Chutes down the side wall to a basket of eggs, one more with every size: the coop's own sign of how
			# big it is (FarmVille's Big Coop had two, its Huge Coop three).
			var chutes := int(f.get("count", 1))
			var from := lo.y + 0.08
			for k in chutes:
				var z := lerpf(lo.z + 0.08, hi.z - 0.08, (k + 0.5) / chutes)
				var chute := ModelKit.box(root, Vector3(-0.04, -0.012, 0.0), Vector3(0.04, 0.012, Vector2(0.26,
					from).length()),
					ModelKit.surface(WOOD, "boards"))
				if chute != null:
					chute.position = Vector3(hi.x, from, z)
					chute.rotation = Vector3(atan2(from, 0.26), PI / 2.0, 0.0)
				ModelKit.box(root, Vector3(hi.x + 0.22, 0.0, z - 0.06), Vector3(hi.x + 0.34, 0.06, z + 0.06),
					ModelKit.paint(HAY))
				for egg in 2:
					ModelKit.ball(root, Vector3(hi.x + 0.26 + 0.05 * egg, 0.08, z - 0.02 + 0.04 * egg), 0.03,
						ModelKit.paint(Color("#f6ecd2")), Vector3(1, 1.25, 1))
		"silo":
			var at: Array = f.get("at", [0.85, 0.2])
			var base := Vector3(float(at[0]) * fw, 0, float(at[1]) * fd)
			var r := float(f.get("r", 0.22))
			var h := float(f.get("h", 1.6))
			# a second or third silo: fewer sides and no chequered band (cheaper)
			var plain := bool(f.get("plain", false))
			var sides := 12 if plain else 20
			ModelKit.cylinder(root, base, r + 0.03, 0.08, ModelKit.surface(STONE, "stone", 0.2), -1.0, sides)
			ModelKit.cylinder(root, base, r, h, ModelKit.surface(Color("#d9dcde"), "metal", 0.35), -1.0, sides)
			for k in 3:
				ModelKit.cylinder(root, base + Vector3(0, h * (0.3 + 0.25 * k), 0), r + 0.008, 0.025,
					ModelKit.paint(Color("#9aa2a8"), 0.5), -1.0, sides)
			# The chequered band near the top: two rows of dark panels round the silo, offset like a chessboard.
			for row in (0 if plain else 2):
				for k in SILO_CHECKS:
					if (k + row) % 2 == 1:
						continue
					var a := TAU * (k + 0.5 * row) / SILO_CHECKS
					var check := ModelKit.box(root, Vector3(-0.05, -0.035, 0.0), Vector3(0.05, 0.035, 0.014),
						ModelKit.paint(Color("#4f565d")))
					check.position = base + Vector3(sin(a) * (r - 0.002), h * 0.78 + row * 0.07 + 0.035,
						cos(a) * (r - 0.002))
					check.rotation.y = a
			if str(f.get("part", "")) != BuildingDress.STORAGE:
				_silo_top(root, f, base, r, h, sides)
				return
			# A storage part: a glass up its side shows the grain in it, and a full one runs over. A look for each.
			var out := Vector3(1, 0, 1).normalized()
			for held in BuildingDress.FILLS:
				var part := BuildingDress.when(ctx, "fill", held)
				BuildingDress.gauge(part, base + out * (r - 0.004) + Vector3(0, h * 0.14, 0), out, h * 0.7, held,
					BuildingDress.GRAIN)
				if held >= BuildingDress.FULL:
					BuildingDress.overflow(part, base, r, h)
				else:
					_silo_top(part, f, base, r, h, sides)
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
			# Straw spilling over the sill.
			ModelKit.ball(root, Vector3(x - 0.04, y - 0.01, hi.z + 0.06), 0.045, ModelKit.paint(HAY), Vector3(1.6,
				0.7, 1))
			ModelKit.ball(root, Vector3(x + 0.05, y - 0.03, hi.z + 0.07), 0.035, ModelKit.paint(HAY.darkened(0.1)),
				Vector3(1.4, 0.8, 1))
		"balcony":
			# A railed deck out from the upper floor's front, on brackets.
			var ulo: Vector3 = ctx.get("upper_lo", lo)
			var uhi: Vector3 = ctx.get("upper_hi", hi)
			var span := (uhi.x - ulo.x) * float(f.get("span", 0.7))
			var x := (ulo.x + uhi.x) / 2.0 + float(f.get("shift", 0.0))
			var y := ulo.y + 0.1
			var out := float(f.get("depth", 0.16))
			var wood := ModelKit.surface(WOOD, "boards")
			var rail := ModelKit.paint(Color("#f3eee2"))
			ModelKit.box(root, Vector3(x - span / 2.0, y, uhi.z), Vector3(x + span / 2.0, y + 0.025, uhi.z + out),
				wood)
			for k in 2:
				var bx := x + (k - 0.5) * span * 0.8
				ModelKit.box(root, Vector3(bx - 0.012, y - 0.09, uhi.z), Vector3(bx + 0.012, y, uhi.z + out * 0.8),
					wood)
			ModelKit.box(root, Vector3(x - span / 2.0, y + 0.12, uhi.z + out - 0.015),
				Vector3(x + span / 2.0, y + 0.135, uhi.z + out), rail)
			ModelKit.box(root, Vector3(x - span / 2.0, y + 0.12, uhi.z), Vector3(x - span / 2.0 + 0.015, y + 0.135,
				uhi.z + out), rail)
			ModelKit.box(root, Vector3(x + span / 2.0 - 0.015, y + 0.12, uhi.z), Vector3(x + span / 2.0, y + 0.135,
				uhi.z + out), rail)
			var posts := 5
			for k in posts:
				var px := lerpf(x - span / 2.0, x + span / 2.0, k / (posts - 1.0))
				ModelKit.box(root, Vector3(px - 0.007, y + 0.025, uhi.z + out - 0.014),
					Vector3(px + 0.007, y + 0.12, uhi.z + out), rail)
		"hoist":
			# A barn's hay hoist: a beam out from under the gable peak, a pulley wheel and a hanging rope.
			var ulo: Vector3 = ctx.get("upper_lo", lo)
			var uhi: Vector3 = ctx.get("upper_hi", hi)
			var x := (ulo.x + uhi.x) / 2.0
			var y := uhi.y + float(f.get("up", 0.12))
			var out := float(f.get("depth", 0.24))
			var wood := ModelKit.paint(WOOD)
			ModelKit.box(root, Vector3(x - 0.015, y, uhi.z - 0.02), Vector3(x + 0.015, y + 0.03, uhi.z + out), wood)
			ModelKit.box(root, Vector3(x - 0.012, y - 0.1, uhi.z + out * 0.15), Vector3(x + 0.012, y,
				uhi.z + out * 0.15 + 0.02),
				wood)
			ModelKit.cylinder(root, Vector3(x - 0.02, y - 0.03, uhi.z + out), 0.03, 0.04,
				ModelKit.paint(Color("#3a3a3a")),
				-1.0, 10).rotation.z = PI / 2.0
			ModelKit.box(root, Vector3(x - 0.004, y - 0.2, uhi.z + out - 0.004), Vector3(x + 0.004, y,
				uhi.z + out + 0.004),
				ModelKit.paint(Color("#c8a96a")))
		"dormers":
			# Small gabled windows poking out of the roof's front slope.
			var ulo: Vector3 = ctx.get("upper_lo", lo)
			var uhi: Vector3 = ctx.get("upper_hi", hi)
			var n := int(f.get("count", 2))
			var trim := Color.html(str((ctx["spec"] as Dictionary).get("trim", "#f3eee2")))
			var rmat := ModelKit.surface(Color.html(str(((ctx["spec"] as Dictionary)["roof"] as Dictionary).get("color",
				"#8e3b2c"))), "shingles", 0.0)
			for k in n:
				var x := lerpf(ulo.x, uhi.x, (k + 1.0) / (n + 1.0))
				var y := uhi.y + float(f.get("up", 0.05))
				var dlo := Vector3(x - 0.075, y, uhi.z - 0.1)
				var dhi := Vector3(x + 0.075, y + 0.15, uhi.z + 0.05)
				ModelKit.box(root, dlo, dhi, ModelKit.paint(trim))
				ModelKit.box(root, Vector3(x - 0.05, y + 0.03, dhi.z), Vector3(x + 0.05, y + 0.12, dhi.z + 0.01),
					ModelKit.glass())
				ModelKit.roof(root, "gable", Vector3(dlo.x, dlo.y, dlo.z), Vector3(dhi.x, dhi.y, dhi.z), 0.07, 0.025,
					rmat,
					ModelKit.paint(trim))
		"awning":
			# A striped canopy over the front door, sloping down and out.
			var w := float(f.get("w", 0.36))
			var x := (lo.x + hi.x) / 2.0 + float(f.get("shift", 0.0))
			var y := float(f.get("h", 0.62))
			var a := Color.html(str(f.get("a", "#c0392b")))
			var b := Color.html(str(f.get("b", "#f3eee2")))
			var stripes := 6
			for k in stripes:
				var sx := x - w / 2.0 + w * k / stripes
				var half := Vector3(w / stripes / 2.0, 0.01, 0.1)
				var strip := ModelKit.box(root, -half, half, ModelKit.paint(a if k % 2 == 0 else b))
				if strip != null:
					strip.position = Vector3(sx + half.x, y, hi.z + 0.1)
					strip.rotation.x = 0.35
		"flag":
			# A pennant on a pole at the roof's peak.
			var x := (lo.x + hi.x) / 2.0 + float(f.get("shift", 0.0))
			var z := (lo.z + hi.z) / 2.0
			var top: float = ctx.get("top", hi.y)
			var h := float(f.get("h", 0.34))
			ModelKit.box(root, Vector3(x - 0.006, top, z - 0.006), Vector3(x + 0.006, top + h, z + 0.006),
				ModelKit.paint(Color("#3a3a3a")))
			var pennant := Node3D.new()
			ModelKit.box(pennant, Vector3(-0.005, -0.1, -0.2), Vector3(0.005, 0.0, 0.0),
				ModelKit.paint(Color.html(str(f.get("color", "#c0392b")))))
			DecorMotion.orbit(root, Vector3(x, top + h, z), pennant, DecorMotion.FLUTTER)
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
				ModelKit.box(root, Vector3(x - w / 2, y0 + 0.3, hi.z + 0.005), Vector3(x + w / 2, y0 + 0.52,
					hi.z + 0.02),
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
			# Through the roof near the back corner, or at `x`, `z` (shares of the walls) and `w` wide, with a cap.
			var top: float = ctx.get("top", hi.y)
			var half := float(f.get("w", 0.14)) / 2.0
			var mid := Vector3(lerpf(lo.x, hi.x, float(f["x"])) if f.has("x") else hi.x - 0.15, 0,
				lerpf(lo.z, hi.z, float(f["z"])) if f.has("z") else lo.z + 0.19)
			ModelKit.box(root, Vector3(mid.x - half, hi.y, mid.z - half), Vector3(mid.x + half, top + 0.15, mid.z + half),
				ModelKit.surface(Color("#a6533c"), "stone", 0.0))
			if f.has("w"):
				ModelKit.box(root, Vector3(mid.x - half - 0.03, top + 0.15, mid.z - half - 0.03), Vector3(
					mid.x + half + 0.03, top + 0.2, mid.z + half + 0.03), ModelKit.paint(STONE.lightened(0.1)))
			# Smoke curling up from it (GPU-animated, one draw), while the building works.
			DecorMotion.effect(BuildingDress.when(ctx, "working", true), "smoke", Vector3(mid.x, top + 0.22, mid.z))
		"water_trough":
			var spot := _trough_at(Vector2(hi.x, hi.z), fw, fd)
			var x := spot.x
			var z := spot.y
			# (a harvesting building's trough holds painted water in the water's own blue, which does not move: the
			# real water would be a draw more than a building's budget has)
			ModelKit.tub(root, Vector3(x - 0.2, 0, z - 0.07), Vector3(x + 0.2, 0.12, z + 0.07), 0.02,
				ModelKit.surface(WOOD, "boards", 0.2), ModelKit.paint(STILL_WATER, 0.9)
				if ctx.get("harvesting", false) else ModelKit.water())
		"hay_bales" when f.has("at"):
			# A couple of bales in the yard: one lying square, one turned and leaning on it, each tied with two
			# bands of twine.
			var spot := yard_spot(f, fw, fd)
			for k in int(f.get("count", 2)):
				var bale := Node3D.new()
				var size := float(f.get("scale", 1.0))
				bale.position = Vector3(spot.x + (k * 2 - 1) * (BALE.x + 0.015) * size, 0, spot.y + k * 0.03 * size)
				bale.rotation.y = 0.0 if k == 0 else 0.5
				bale.scale = Vector3.ONE * size
				root.add_child(bale)
				ModelKit.box(bale, Vector3(-BALE.x, 0, -BALE.z), Vector3(BALE.x, BALE.y, BALE.z),
					ModelKit.paint(HAY.darkened(0.06 * k)))
				for band: float in [-0.5, 0.5]:
					ModelKit.box(bale, Vector3(band * BALE.x - 0.008, 0, -BALE.z - 0.004), Vector3(band * BALE.x + 0.008,
						BALE.y + 0.004, BALE.z + 0.004), ModelKit.paint(HAY.darkened(0.35)), false)
		"hive":
			_hive(ctx, f)
		"hay_bales":
			var x := minf(hi.x + 0.3, fw - 0.25)
			var z := clampf(lo.z + 0.2, 0.2, fd - 0.2)
			for k in 3:
				var at := Vector3(x + (k % 2) * 0.22, 0.0 if k < 2 else 0.14, z + (0.11 if k == 2 else 0.0))
				ModelKit.box(root, at + Vector3(-0.1, 0, -0.08), at + Vector3(0.1, 0.14, 0.08), ModelKit.paint(HAY))
		"barrels":
			# Beside the building; a yard with no building (an Orchard) has them by its back fence, out of
			# the way of what grows there.
			var bare := hi.x - lo.x < 0.01
			var x := fw - 0.3 if bare else minf(hi.x + 0.25, fw - 0.15)
			for k in 3:
				var z := lerpf(0.3, 0.9, k / 2.0) if bare else lerpf(lo.z + 0.15, hi.z - 0.15, k / 2.0)
				ModelKit.cylinder(root, Vector3(x, 0, z), 0.1, 0.24, ModelKit.surface(Color("#7c4a2a"), "boards",
					0.25))
				ModelKit.cylinder(root, Vector3(x, 0.05, z), 0.105, 0.025, ModelKit.paint(Color("#3a3a3a"), 0.5))
				ModelKit.cylinder(root, Vector3(x, 0.18, z), 0.105, 0.025, ModelKit.paint(Color("#3a3a3a"), 0.5))
		"flowers":
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(str((ctx["it"] as Dictionary).get("id", "")))
			for k in 14:
				var p := Vector3(rng.randf_range(0.1, fw - 0.1), 0, fd - rng.randf_range(0.05, 0.3))
				if p.x > lo.x - 0.05 and p.x < hi.x + 0.05 and p.z < hi.z + 0.05:
					continue
				ModelKit.box(root, p + Vector3(-0.006, 0, -0.006), p + Vector3(0.006, 0.08, 0.006),
					ModelKit.paint(Color("#4f8a2f")), false)
				var petal: Color = [Color("#ff7aa8"), Color("#ffd23f"), Color("#ffffff"), Color("#b388ff")][k % 4]
				BuildingDress.bead(root, p + Vector3(0, 0.09, 0), 0.032, ModelKit.paint(petal))
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
				ModelKit.box(root, p + Vector3(-0.05, 0.09, 0.12), p + Vector3(0.05, 0.11, 0.13),
					ModelKit.paint(DARK))
		"pond":
			var rx := fw * 0.4
			var rz := fd * 0.36
			var centre := Vector3(fw / 2.0, 0, fd / 2.0)
			# No ducks of its own: a Duck Pond's ducks are the ones living in it (BuildingFill), so an empty
			# pond looks empty.
			# (`still`: its reeds do not sway; a building's file moves only by its named parts)
			PondModel.build(root, centre, rx, rz, 7, 5, true)
		"duck_house":
			_duck_house(ctx, f)
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
		"arch":
			# A white trellis arch over the front fence (the edge facing the camera), climbing roses on it.
			var x := fw - 0.05
			var z := fd / 2.0
			var white := ModelKit.paint(Color("#f4f1ea"))
			for side: float in [-1.0, 1.0]:
				ModelKit.box(root, Vector3(x - 0.025, 0, z + side * 0.4 - 0.025), Vector3(x + 0.025, 0.7,
					z + side * 0.4 + 0.025),
					white)
			for k in 13:
				var a := PI * k / 12.0
				var p := Vector3(x, 0.7 + sin(a) * 0.22, z - cos(a) * 0.4)
				ModelKit.ball(root, p, 0.04, white)
				if k % 2 == 1:
					ModelKit.ball(root, p + Vector3(0.035, 0.03, 0), 0.04,
						ModelKit.paint(Color("#d6304a") if k % 4 == 1 else Color("#4f8a34")))
		"rock", "pool", "wallow", "carrots", "fuel_pump", "mobile", "burrow":
			_signature(ctx, f)
		"weathervane":
			var top: float = ctx.get("top", hi.y)
			var x := (lo.x + hi.x) / 2.0 + float(f.get("shift", 0.0))
			var z := (lo.z + hi.z) / 2.0
			var iron := ModelKit.paint(Color("#2e2e2e"), 0.3)
			ModelKit.box(root, Vector3(x - 0.008, top, z - 0.008), Vector3(x + 0.008, top + 0.34, z + 0.008), iron)
			ModelKit.box(root, Vector3(x - 0.12, top + 0.22, z - 0.004), Vector3(x + 0.12, top + 0.235, z + 0.004),
				iron)
			ModelKit.box(root, Vector3(x - 0.004, top + 0.22, z - 0.09), Vector3(x + 0.004, top + 0.235, z + 0.09),
				iron)
			# The cockerel and its arrow, swinging round with the wind.
			var vane := Node3D.new()
			var gold := ModelKit.paint(Color("#c9a24a"), 0.6)
			ModelKit.box(vane, Vector3(-0.004, 0.025, -0.13), Vector3(0.004, 0.035, 0.13), iron)
			ModelKit.ball(vane, Vector3(0, 0.07, 0), 0.045, gold, Vector3(0.35, 1.0, 1.6))
			ModelKit.ball(vane, Vector3(0, 0.11, -0.06), 0.025, gold, Vector3(0.4, 1, 1))
			DecorMotion.orbit(root, Vector3(x, top + 0.26, z), vane, DecorMotion.VANE)
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


## A silo's top: a cone roof in its `cap` colour, or a metal dome.
static func _silo_top(root: Node3D, f: Dictionary, base: Vector3, r: float, h: float, sides: int) -> void:
	if f.has("cap"):
		ModelKit.cylinder(root, base + Vector3(0, h, 0), r + 0.05, r * 0.95, ModelKit.paint(Color.html(str(f["cap"]))),
			0.03, sides)
	else:
		ModelKit.ball(root, base + Vector3(0, h, 0), r, ModelKit.paint(Color("#b9c0c4"), 0.6), Vector3(1, 0.6, 1))


## The one thing a building has that no other does (data/building_models.json `features`): a Goat Pen's
## climbing rock, a Spa's steaming pool, a Pig Pen's mud wallow, a Rabbit Hutch's carrot patch, a Garage's fuel
## pump, a Nursery's mobile in the loft. Each stands at `yard_spot` (the loft mobile hangs in the loft door).
static func _signature(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var kind := str(f["type"])
	var spot := yard_spot(f, ctx["fw"], ctx["fd"])
	var at := Vector3(spot.x, 0, spot.y)
	var r := float(f.get("r", FEATURE_R.get(kind, 0.3)))
	match kind:
		"burrow":
			# The gophers' own home (the Gopher Garden): a round grassy hill with a round wooden door in its
			# front, a little lit window in its side, a tin pipe for a chimney and flowers growing on it.
			ModelKit.ball(root, at, r, ModelKit.paint(HILL), Vector3(1.0, 0.82, 1.0), true)
			var wood := ModelKit.surface(WOOD, "boards", 0.0)
			var frame := ModelKit.cylinder(root, Vector3.ZERO, r * 0.46, 0.04, ModelKit.paint(DARK), -1.0, 14)
			frame.rotation.x = PI / 2.0
			frame.position = at + Vector3(0, r * 0.36, r * 0.86)
			var door := ModelKit.cylinder(root, Vector3.ZERO, r * 0.38, 0.05, wood, -1.0, 14)
			door.rotation.x = PI / 2.0
			door.position = at + Vector3(0, r * 0.36, r * 0.88)
			BuildingDress.bead(root, at + Vector3(r * 0.2, r * 0.36, r * 0.97), r * 0.05, ModelKit.paint(BuildingDress.GOLD))
			var pane := ModelKit.cylinder(root, Vector3.ZERO, r * 0.2, 0.04, ModelKit.glass(), -1.0, 12)
			pane.rotation.z = PI / 2.0
			pane.position = at + Vector3(r * 0.88, r * 0.42, 0)
			var pipe := ModelKit.cylinder(root, at + Vector3(-r * 0.3, r * 0.6, -r * 0.2), r * 0.09, r * 0.5,
				ModelKit.paint(BuildingDress.IRON), -1.0, 8)
			pipe.rotation.z = 0.2
			for k in 5:
				var round := 0.4 + k * 1.1
				BuildingDress.bead(root, at + Vector3(cos(round) * r * 0.55, r * 0.72, sin(round) * r * 0.5), r * 0.07,
					ModelKit.paint(PASTELS[k % PASTELS.size()]))
		"rock":
			# Boulders piled into a little mountain, a ledge on top for the goats to stand on.
			var stone := ModelKit.surface(STONE, "stone", 0.15)
			for b: Vector4 in ROCK_BOULDERS:   # (x, z offset as shares of r, radius share, height share)
				ModelKit.ball(root, at + Vector3(b.x * r, 0, b.y * r), b.z * r, stone, Vector3(1, b.w, 1))
			ModelKit.box(root, at + Vector3(-r * 0.3, r * 0.95, -r * 0.25), at + Vector3(r * 0.3, r * 1.02, r * 0.25),
				ModelKit.surface(WOOD, "boards"))
		"pool":
			ModelKit.cylinder(root, at, r + 0.05, 0.1, ModelKit.surface(STONE, "stone", 0.2), -1.0, 24)
			# (`still`: painted water that does not ripple, for a crafting building, where only animated parts move;
			# it steams while the building works: the "boiler" feature)
			var water := ModelKit.cylinder(root, at + Vector3(0, 0.101, 0), r, 0.004, ModelKit.paint(STILL_WATER,
				0.9) if bool(f.get("still", false)) else ModelKit.water(), -1.0, 24)
			if water != null:
				water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"wallow":
			ModelKit.ball(root, at + Vector3(0, -0.01, 0), 1.0, ModelKit.paint(GROUNDS["mud"].darkened(0.25), 0.4),
				Vector3(r, 0.04, r * 0.8))
			for k in 3:
				var a := TAU * k / 3.0 + 0.4
				ModelKit.ball(root, at + Vector3(cos(a) * r * 0.55, 0.02, sin(a) * r * 0.45), 0.035,
					ModelKit.paint(GROUNDS["mud"].lightened(0.15)), Vector3(1, 0.5, 1))
		"carrots":
			var soil := ModelKit.paint(GROUNDS["dirt"].darkened(0.2))
			ModelKit.box(root, at - Vector3(r, 0, r * 0.7), at + Vector3(r, 0.03, r * 0.7), soil)
			for row in 3:
				for k in 4:
					var p := at + Vector3(lerpf(-r * 0.75, r * 0.75, k / 3.0), 0.03, lerpf(-r * 0.45, r * 0.45,
						row / 2.0))
					ModelKit.ball(root, p, 0.022, ModelKit.paint(Color("#e8822a")), Vector3(1, 0.8, 1))
					ModelKit.cylinder(root, p, 0.02, 0.09, ModelKit.paint(Color("#4f9a34")), 0.0, 5)
		"fuel_pump":
			var cream := ModelKit.paint(Color("#f1ece0"))
			ModelKit.box(root, at + Vector3(-0.09, 0, -0.07), at + Vector3(0.09, 0.42, 0.07),
				ModelKit.paint(Color("#c8352b"), 0.4))
			ModelKit.box(root, at + Vector3(-0.07, 0.28, 0.07), at + Vector3(0.07, 0.37, 0.075), cream)
			ModelKit.box(root, at + Vector3(-0.1, 0.42, -0.08), at + Vector3(0.1, 0.47, 0.08), cream)
			ModelKit.box(root, at + Vector3(0.09, 0.12, -0.012), at + Vector3(0.15, 0.3, 0.012), ModelKit.paint(DARK))
			ModelKit.box(root, at + Vector3(-0.16, 0, -0.12), at + Vector3(0.16, 0.03, 0.12),
				ModelKit.surface(STONE, "stone", 0.2))
		"mobile":
			# A baby's mobile hanging in the loft: pastel stars and moons on a little cross.
			var lo: Vector3 = ctx["lo"]
			var hi: Vector3 = ctx["hi"]
			var top := Vector3((lo.x + hi.x) / 2.0, hi.y + 0.3, hi.z + 0.06)
			var string := ModelKit.paint(Color("#f6f1e6"))
			ModelKit.box(root, top - Vector3(0.004, 0.12, 0.004), top + Vector3(0.004, 0.0, 0.004), string)
			ModelKit.box(root, top + Vector3(-0.1, -0.125, -0.004), top + Vector3(0.1, -0.115, 0.004), string)
			for k in 3:
				var p := top + Vector3(-0.09 + 0.09 * k, -0.17 - 0.02 * (k % 2), 0)
				ModelKit.ball(root, p, 0.03, ModelKit.paint(PASTELS[k % PASTELS.size()]))


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
		ModelKit.box(root, Vector3(x - w / 2 - 0.02, y - w / 2 - 0.02, whi.z), Vector3(x + w / 2 + 0.02,
			y + w / 2 + 0.02,
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
	# The ground is not one flat colour: trodden patches, darker where the animals stand, and loose straw or
	# stones lying about.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str((ctx["it"] as Dictionary).get("id", ""))) + 3
	for k in 3:
		var p := Vector3(rng.randf_range(inset + 0.35, fw - inset - 0.35), 0.012, rng.randf_range(inset + 0.35,
			fd - inset - 0.35))
		var r := rng.randf_range(0.18, 0.3)
		var patch := ModelKit.cylinder(root, p, r, 0.004,
			ModelKit.surface(col.darkened(0.1 + 0.08 * (k % 2)) if k % 3 != 0
			else col.lightened(0.1), "plaster", 0.0), r * 0.85, 7)
		patch.scale.x = 1.0 + rng.randf() * 0.4
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if f.get("rough", false):
		# Rough ground: low humps the hooves have left, and straw trodden into it.
		for k in ROUGH_MOUNDS:
			var p := Vector3(rng.randf_range(inset + 0.2, fw - inset - 0.2), 0.0, rng.randf_range(inset + 0.2,
				fd - inset - 0.2))
			var r := rng.randf_range(0.1, 0.2)
			var hump := ModelKit.ball(root, p, r, ModelKit.surface(col.darkened(0.04 + 0.05 * (k % 3)), "plaster",
				0.0), Vector3(1.0 + rng.randf() * 0.5, 0.22, 1.0))
			hump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in ROUGH_TUFTS:
			var p := Vector3(rng.randf_range(inset + 0.15, fw - inset - 0.15), 0.012, rng.randf_range(inset + 0.15,
				fd - inset - 0.15))
			var wisp := ModelKit.box(root, Vector3(-0.07, 0, -0.006), Vector3(0.07, 0.008, 0.006),
				ModelKit.paint(HAY.lightened(0.1)), false)
			wisp.position = p
			wisp.rotation.y = rng.randf() * PI
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
			# Its gate posts stand taller, with caps; the gate hangs ajar on the nearer one.
			for post: Vector3 in [mid - gap, mid + gap]:
				ModelKit.box(root, post - Vector3(0.032, 0, 0.032), post + Vector3(0.032, 0.34, 0.032), mat)
				ModelKit.box(root, post + Vector3(-0.042, 0.34, -0.042), post + Vector3(0.042, 0.36, 0.042), mat)
			var gate := Node3D.new()
			gate.position = mid + gap
			gate.rotation.y = -0.6
			root.add_child(gate)
			var wide := gap.length() * 1.85
			for bar: float in [0.08, 0.2]:
				ModelKit.box(gate, Vector3(-wide, bar, -0.012), Vector3(0, bar + 0.03, 0.012), mat)
			for end: float in [0.0, 1.0]:
				ModelKit.box(gate, Vector3(-wide * end - 0.014, 0.04, -0.014), Vector3(-wide * end + 0.014, 0.26,
					0.014), mat)
		else:
			_fence(root, a, b, fence, mat)


## A duck house on the bank of a Duck Pond (which has no walls of its own): a boarded house on legs under a red
## roof, a ramp down to the water; with `tiers` 2 it stands on tall stilts with a second, smaller house on top
## of the first, over a little pent roof.
static func _duck_house(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var spot := yard_spot(f, ctx["fw"], ctx["fd"]) if f.has("at") else Vector2(0.82 * float(ctx["fw"]),
		0.2 * float(ctx["fd"]))
	var p := Vector3(spot.x, 0, spot.y)
	var tiers := int(f.get("tiers", 1))
	var legs := 0.15 if tiers == 1 else 0.3
	var boards := ModelKit.surface(Color("#e9d7a8"), "boards")
	var roof_mat := ModelKit.surface(Color("#b5492f"), "shingles", 0.0)
	var half := Vector3(DUCK_HOUSE.x, 0, DUCK_HOUSE.z)
	for k in 4:
		var leg := p + Vector3((k % 2 * 2 - 1) * (half.x - 0.03), 0, (k / 2 * 2 - 1) * (half.z - 0.03))
		ModelKit.box(root, leg + Vector3(-0.018, 0, -0.018), leg + Vector3(0.018, legs, 0.018), ModelKit.paint(WOOD))
	ModelKit.box(root, p + Vector3(-half.x - 0.03, legs - 0.02, -half.z - 0.03), p + Vector3(half.x + 0.03, legs,
		half.z + 0.03), ModelKit.surface(WOOD, "boards"))
	var ramp := ModelKit.box(root, Vector3(-0.06, -0.008, 0), Vector3(0.06, 0.008, legs * 1.7),
		ModelKit.surface(WOOD, "boards"))
	ramp.position = p + Vector3(0, legs - 0.01, half.z + 0.02)
	ramp.rotation.x = atan2(legs, legs * 1.4)
	var y := legs
	for tier in tiers:
		var narrow := 1.0 if tier == 0 else 0.76
		var lo := p + Vector3(-half.x * narrow, y, -half.z * narrow)
		var hi := p + Vector3(half.x * narrow, y + DUCK_HOUSE.y, half.z * narrow)
		ModelKit.box(root, lo, hi, boards)
		# (the way in: a dark round-topped hole on the front)
		ModelKit.box(root, Vector3(p.x - 0.05, y + 0.02, hi.z), Vector3(p.x + 0.05, y + DUCK_HOUSE.y * 0.6, hi.z + 0.004),
			ModelKit.paint(DARK), false)
		if tier < tiers - 1:
			ModelKit.roof(root, "hip", lo, hi, SKIRT_PITCH * half.z, 0.05, roof_mat, boards)
			y = hi.y + 0.03
		else:
			ctx["top"] = ModelKit.roof(root, "gable", lo, hi, half.z * narrow * 0.85, 0.05, roof_mat, boards)
			ctx["upper_lo"] = lo
			ctx["upper_hi"] = hi


## A beehive on its stand (the Beehive building, which has no walls of its own): a box hive of `tiers` storeys,
## each a stack of two boxes in the building's colours with a landing board and its dark way in, the upper one
## narrower over a little pent roof, and a pitched roof on top.
static func _hive(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var spot := yard_spot(f, ctx["fw"], ctx["fd"])
	var it: Dictionary = ctx["it"]
	var roof_mat := ModelKit.paint(Color.html(str(it.get("roof", "#c98a1a"))))
	var wood := ModelKit.surface(WOOD, "boards", 0.2)
	var at := Vector3(spot.x, 0, spot.y)
	# The stand: four legs and a deck.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var leg := at + Vector3(corner.x * (HIVE_BOX.x - 0.02), 0, corner.y * (HIVE_BOX.z - 0.02))
		ModelKit.box(root, leg + Vector3(-0.025, 0, -0.025), leg + Vector3(0.025, 0.16, 0.025), wood)
	ModelKit.box(root, at + Vector3(-HIVE_BOX.x - 0.03, 0.16, -HIVE_BOX.z - 0.03), at + Vector3(HIVE_BOX.x + 0.03,
		0.2, HIVE_BOX.z + 0.1), wood)
	var y := 0.2
	var tiers := int(f.get("tiers", 1))
	for tier in tiers:
		var narrow := 1.0 if tier == 0 else 0.78
		var half := Vector3(HIVE_BOX.x * narrow, HIVE_BOX.y, HIVE_BOX.z * narrow)
		for box in 2:
			var tint: Color = (ctx["wall"] as Color).lightened(0.25 if box == 0 else 0.0)
			ModelKit.box(root, at + Vector3(-half.x, y, -half.z), at + Vector3(half.x, y + half.y - 0.012, half.z),
				ModelKit.surface(tint, "boards", 0.2))
			# (the lip where two boxes meet)
			ModelKit.box(root, at + Vector3(-half.x - 0.012, y + half.y - 0.012, -half.z - 0.012), at + Vector3(
				half.x + 0.012, y + half.y, half.z + 0.012), ModelKit.paint(Color("#f3eee2")))
			if box == 0:
				# The way in, on the front, over a landing board.
				ModelKit.box(root, at + Vector3(-half.x * 0.5, y + 0.012, half.z), at + Vector3(half.x * 0.5, y + 0.04,
					half.z + 0.004), ModelKit.paint(DARK), false)
				ModelKit.box(root, at + Vector3(-half.x * 0.7, y - 0.004, half.z), at + Vector3(half.x * 0.7, y + 0.008,
					half.z + 0.07), wood)
			y += half.y
		var lo := at + Vector3(-half.x, y, -half.z)
		var hi := at + Vector3(half.x, y, half.z)
		if tier < tiers - 1:
			ModelKit.roof(root, "hip", lo, hi, SKIRT_PITCH * half.z, 0.03, roof_mat, roof_mat)   # (a pent ledge)
			y += 0.035
		else:
			y = ModelKit.roof(root, "gable", lo, hi, half.z * 0.8, 0.07, roof_mat, roof_mat)
		ctx["upper_lo"] = lo - Vector3(0, half.y * 2.0, 0)
		ctx["upper_hi"] = hi
	ctx["top"] = y
	BuildingDress.shade_pool(root, at, Vector2(HIVE_BOX.x * 2.0 + 0.5, HIVE_BOX.z * 2.0 + 0.5))


## A run of fence: posts, with two rails (rail) or pointed pickets (picket).
static func _fence(root: Node3D, a: Vector3, b: Vector3, kind: String, mat: Material) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(length, 0.001)
	var posts := maxi(1, int(ceil(length / 0.33)))
	for k in posts + 1:
		var p := a + dir * (length * k / posts)
		ModelKit.box(root, p - Vector3(0.026, 0, 0.026), p + Vector3(0.026, 0.26, 0.026), mat)
	if kind == "picket":
		var n := int(length / PICKET_GAP)   # (fewer, broader pickets: a white fence at a third less to draw)
		for k in n:
			var p := a + dir * (length * (k + 0.5) / n)
			ModelKit.box(root, p - Vector3(0.018, 0, 0.018), p + Vector3(0.018, 0.2, 0.018), mat)
		_rail(root, a, b, 0.14, mat)
	else:
		_rail(root, a, b, 0.09, mat)
		_rail(root, a, b, 0.19, mat)


static func _rail(root: Node3D, a: Vector3, b: Vector3, y: float, mat: Material) -> void:
	var lo := Vector3(minf(a.x, b.x) - 0.012, a.y + y, minf(a.z, b.z) - 0.012)
	var hi := Vector3(maxf(a.x, b.x) + 0.012, a.y + y + 0.03, maxf(a.z, b.z) + 0.012)
	ModelKit.box(root, lo, hi, mat)
