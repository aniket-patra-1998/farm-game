class_name BuildingDress
extends RefCounted
## What makes a building a place and says what it is for (the storybook look, data/building_models.json
## `features`): the ground it stands on (a soft shade round its foot and a worn path to its door) and the one
## thing of its trade: a mill's round tower and turning sails, a bakery's brick oven, a winery's great
## cask, a spa's steaming pool, a barn's hay rack and milk cans, a coop's perch and feeder, a house's bench
## and woodpile. One bold thing each, not many small ones. BuildingModel builds the block, roof, door and
## windows and calls this for the rest.

const STONE := Color("#9b958a")
const WOOD := Color("#8a5a36")
const DARK_WOOD := Color("#5a3a24")
const IRON := Color("#2e2e2e")
const HAY := Color("#e2c25a")
const BURLAP := Color("#c9ad78")
const BRICK := Color("#a6533c")
const LEAF := Color("#4a8f36")
const PATH := Color("#b08d5c")
const CREAM := Color("#f3eee2")
const BAKED := Color("#c98b4a")
const SHADE_OUT := 0.3        # the shade round a building's foot reaches this far past its walls..
const SHADE_STRENGTH := 0.5   # ..and is this dark at its middle
const SHADE_LIFT := 0.014     # it lies this far above the ground (over a yard's floor)
const GOLDEN := 2.39996
## Every feature this dressing builds (`feature`); BuildingModel builds the rest.
const FEATURES: Array[String] = ["sacks", "crates", "cask", "oven", "steam", "emblem", "crown", "sails", "chute",
	"press", "pour", "jet", "rack", "hay_rack",
	"milk_cans", "perch", "feeder", "bench", "woodpile"]
const GOLD := Color("#f2c14e")
const GRAIN := Color("#e8b93c")
const ANIMATED := "animated"  # a feature's `part`: it moves while the building is crafting, and only then
const STORAGE := "storage"    # a feature's `part`: it shows how full the building is, in FILLS looks
const FILLS := 4              # empty, a quarter, half and full
const FULL := 3
const CHUTE_LONG := 0.7       # a grain chute: how long its spout is..
const CHUTE_TILT := 0.55       # ..how steeply it runs down (radians)..
const CHUTE_HIGH := 0.42       # ..and how high its mouth is over the ground
## Grain running off the end of a chute into the bin under it.
const GRAIN_FALL := {"streams": 4, "per_stream": 6, "life": 0.42, "rise": 0.0, "gravity": 2.8, "reach": 0.03,
	"size": 1.0, "colour": GRAIN}
const RACK_WIDE := 0.4
const RACK_TALL := 0.52
const GAUGE_WIDE := 0.11
## Wine running from a keg's tap into the pail under it.
const POUR := {"streams": 3, "per_stream": 6, "life": 0.36, "rise": 0.0, "gravity": 2.8, "reach": 0.012,
	"size": 0.9, "colour": Color("#8e2f5a")}
const GRAPE := Color("#6a3a8f")
const STAR_R := 0.24          # a maxed building's star: its radius..
const STAR_WAIST := 0.45      # ..how far in its inner points are..
const STAR_THICK := 0.05      # ..and half its thickness at the middle
const LOWER_TAPER := 0.86     # a two-storey tower: how wide its lower storey's top is, as a share of its foot..
const UPPER_FOOT := 0.64      # ..and its upper storey's foot..
const UPPER_TOP := 0.5        # ..and top
const LOWER_ROOF := 0.22      # the height of the pent roof between the two
const TOWER_SIDES := 14       # a round tower's sides
const TOWER_TAPER := 0.7      # how wide its top is, as a share of its foot
const CAP_SIDES := 18         # a tower cap's dome: how round it is
const CAP_EAVE := 0.05        # and the dark eave under it
const SAIL_WIDE := 0.27       # a windmill sail's width, as a share of its length

static var _shade: ShaderMaterial


## The ground a building stands on: a soft shade round its foot (it sits on the earth), a worn path from its
## door to the edge of its plot when it has no yard.
static func ground(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var fw: float = ctx["fw"]
	var fd: float = ctx["fd"]
	var spec: Dictionary = ctx["spec"]
	if lo.y <= 0.0:
		var a := Vector2(maxf(lo.x - SHADE_OUT, 0.02), maxf(lo.z - SHADE_OUT, 0.02))
		var b := Vector2(minf(hi.x + SHADE_OUT * 1.5, fw - 0.02), minf(hi.z + SHADE_OUT * 1.5, fd - 0.02))
		shade_pool(root, Vector3((a.x + b.x) / 2.0, 0, (a.y + b.y) / 2.0), b - a)
	var yard := false
	for f: Dictionary in spec.get("features", []):
		yard = yard or str(f.get("type", "")) in ["yard", "porch"]
	var door: Dictionary = spec.get("door", {})
	var x := (lo.x + hi.x) / 2.0
	if not yard and str(door.get("style", "barn")) != "none" and fd - hi.z > 0.25:
		# The path: trodden earth widening from the door.
		var reach := fd - hi.z - 0.06
		var w := float(door.get("w", 0.28)) * float(ctx["bw"]) / 0.7 + 0.1
		ModelKit.ball(root, Vector3(x, 0.0, hi.z + reach * 0.5), reach * 0.52, ModelKit.surface(PATH, "plaster", 0.0),
			Vector3(w / reach * 1.25, 0.03, 1.0))


## A small round thing (a berry, a grape, a flower's head): a ball of few faces, since there are many.
static func bead(root: Node3D, at: Vector3, r: float, mat: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 5
	mesh.rings = 2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.scale = scale
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # (too small for its shadow to show)
	root.add_child(mi)
	return mi


## A soft dark patch on the ground, `size` across, centred on `at` (x, z): where a building blocks the sky. Left
## out of the bake (it is drawn blended), casts no shadow.
static func shade_pool(parent: Node3D, at: Vector3, size: Vector2) -> MeshInstance3D:
	if _shade == null:
		_shade = ShaderMaterial.new()
		_shade.shader = load("res://shaders/contact3d.gdshader")
		_shade.set_shader_parameter("strength", SHADE_STRENGTH)
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _shade
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(at.x, SHADE_LIFT, at.z)
	mi.set_meta(ModelKit.KEEP, true)
	parent.add_child(mi)
	return mi


## Builds feature `f` if it is one of the dressing's own, and says whether it was.
static func feature(ctx: Dictionary, f: Dictionary) -> bool:
	var root: Node3D = ctx["root"]
	var fw: float = ctx["fw"]
	var fd: float = ctx["fd"]
	var c: Vector3 = ctx["centre"]
	var lo: Vector3 = ctx.get("lo", c)
	var hi: Vector3 = ctx.get("hi", c)
	# An animated part moves while the building is crafting, and only then.
	var moving := bool(ctx.get("active", true))
	var spot: Array = f.get("at", [])
	var at := Vector3(float(spot[0]) * fw, 0, float(spot[1]) * fd) if spot.size() == 2 \
		else Vector3(minf(hi.x + 0.3, fw - 0.22), 0, minf(hi.z + 0.25, fd - 0.2))
	match str(f.get("type", "")):
		"sacks":
			# Feed sacks stacked by the wall: two rows and one thrown on top, each a full bag with its tied ears, one
			# with its mark showing.
			var n := int(f.get("count", 5))
			for k in n:
				var layer := 0 if k < 3 else (1 if k < 5 else 2)
				var along: float = (float(k) if k < 3 else (k - 2.5 if k < 5 else 1.0)) - 1.0
				var bag := Node3D.new()
				bag.position = at + Vector3(along * 0.2, 0.115 * layer, 0.02 * (k % 2))
				bag.rotation.y = 0.16 * (k % 3 - 1)
				root.add_child(bag)
				var cloth := ModelKit.paint(Color("#d8bd84").darkened(0.07 * (k % 3)))
				ModelKit.box(bag, Vector3(-0.09, 0, -0.13), Vector3(0.09, 0.105, 0.13), cloth)
				ModelKit.box(bag, Vector3(-0.075, 0.105, -0.11), Vector3(0.075, 0.125, 0.11), cloth, false)
				for ear: float in [-0.07, 0.07]:
					ModelKit.box(bag, Vector3(ear - 0.02, 0.06, 0.13), Vector3(ear + 0.02, 0.1, 0.155), cloth, false)
				if k == n - 1 or k == 1:
					ModelKit.box(bag, Vector3(-0.06, 0.03, 0.131), Vector3(0.06, 0.075, 0.134),
						ModelKit.paint(Color.html(str(f.get("mark", "#c0392b")))), false)
		"crates":
			var fruit := Color.html(str(f.get("color", "#d93b30")))
			for k in int(f.get("count", 2)):
				var p := at + Vector3(0.2 * k, 0.0, 0.05 * (k % 2))
				ModelKit.tub(root, p + Vector3(-0.09, 0, -0.07), p + Vector3(0.09, 0.11, 0.07), 0.015,
					ModelKit.surface(WOOD.lightened(0.1), "boards", 0.2))
				for b in 6:
					bead(root, p + Vector3(-0.05 + 0.05 * (b % 3), 0.11, -0.03 + 0.06 * (b / 3)), 0.03,
						ModelKit.paint(fruit.darkened(0.06 * (b % 2)), 0.3))
		"cask":
			# One great cask on its side beside the building, on a cradle, its head and tap toward you.
			var r := float(f.get("r", 0.36))
			var p := Vector3(minf(hi.x + r + 0.1, fw - r - 0.04), r + 0.05, lerpf(lo.z, hi.z, float(f.get("z", 0.6))))
			var oak := ModelKit.surface(Color("#8a5530"), "boards", 0.2)
			for side: float in [-1.0, 1.0]:
				# (two halves, each widest at the middle: a cask bulges)
				var half := ModelKit.cylinder(root, Vector3.ZERO, r, r * 0.85, oak, r * 0.82, 12)
				half.rotation.x = side * PI / 2.0
				half.position = p + Vector3(0, 0, side * r * 0.425)
				var hoop := ModelKit.cylinder(root, Vector3.ZERO, r * 0.885 + 0.012, 0.04, ModelKit.paint(IRON, 0.4),
					-1.0, 12)
				hoop.rotation.x = PI / 2.0
				hoop.position = p + Vector3(0, 0, side * r * 0.55)
				ModelKit.box(root, Vector3(p.x - r * 0.8, 0, p.z + side * r * 0.5 - 0.04),
					Vector3(p.x + r * 0.8, r * 0.3, p.z + side * r * 0.5 + 0.04), ModelKit.paint(DARK_WOOD))
			var head := ModelKit.cylinder(root, Vector3.ZERO, r * 0.74, 0.02, ModelKit.paint(Color("#b98552")), -1.0,
				12)
			head.rotation.x = PI / 2.0
			head.position = p + Vector3(0, 0, r * 0.85)
			var tap := ModelKit.cylinder(root, Vector3.ZERO, 0.03, 0.1, ModelKit.paint(IRON, 0.4), -1.0, 6)
			tap.rotation.x = PI / 2.0
			tap.position = p + Vector3(0, -r * 0.45, r * 0.85 + 0.05)
			if str(f.get("part", "")) == STORAGE:
				# How full it is shows in the kegs drawn off it, standing before its head: one, then two, then three
				# with a fourth on top and wine pooled under the tap.
				var drawn := int(ctx.get("fill", 0))
				var row := p.z + r * 0.85 + 0.2
				for k in mini(drawn, FULL):
					_keg(root, Vector3(p.x + (k - 1) * 0.21, 0, row))
				if drawn >= FULL:
					_keg(root, Vector3(p.x - 0.105, 0.2, row))
					ModelKit.cylinder(root, Vector3(p.x + 0.16, 0, row + 0.16), 0.15, 0.012, ModelKit.paint(GRAPE), 0.13,
						10)
		"emblem":
			# The sign of its trade on a round plaque high on the front gable: a loaf, or a bunch of grapes.
			var up_lo: Vector3 = ctx.get("upper_lo", lo)
			var up_hi: Vector3 = ctx.get("upper_hi", hi)
			var roof_top: float = ctx.get("top", up_hi.y)
			var e := Vector3((up_lo.x + up_hi.x) / 2.0, up_hi.y + (roof_top - up_hi.y) * float(f.get("up", 0.3)),
				up_hi.z)
			var plaque := ModelKit.cylinder(root, Vector3.ZERO, 0.22, 0.03, ModelKit.paint(CREAM), -1.0, 12)
			plaque.rotation.x = PI / 2.0
			plaque.position = e + Vector3(0, 0, 0.015)
			if str(f.get("icon", "loaf")) == "grapes":
				for k in 6:
					var row := 0 if k < 3 else (1 if k < 5 else 2)
					var across := (k - 1.0) if row == 0 else ((k - 3.5) if row == 1 else 0.0)
					bead(root, e + Vector3(across * 0.085, 0.03 - row * 0.075, 0.05), 0.05, ModelKit.paint(GRAPE))
				bead(root, e + Vector3(0.03, 0.11, 0.045), 0.05, ModelKit.paint(LEAF), Vector3(1.3, 0.6, 0.5))
			else:
				bead(root, e + Vector3(0, 0, 0.04), 0.15, ModelKit.paint(BAKED), Vector3(1.0, 0.62, 0.42))
				for k in 3:
					var cut := ModelKit.box(root, Vector3(-0.011, -0.05, 0), Vector3(0.011, 0.05, 0.012),
						ModelKit.paint(CREAM), false)
					cut.position = e + Vector3(-0.07 + 0.07 * k, 0.012, 0.094)
					cut.rotation.z = -0.5
		"crown":
			# What a maxed building wears: a band of gold round the top of its walls, and a gold star over its
			# roof. (It stands still: only a building's animated parts move.)
			var gold := ModelKit.paint(GOLD, 0.8)
			var w_lo: Vector3 = ctx.get("upper_lo", lo)
			var w_hi: Vector3 = ctx.get("upper_hi", hi)
			var band := w_hi.y - BuildingModel.FRIEZE - 0.09
			if ctx.has("tower_top"):
				var tr: float = ctx["tower_top"]
				ModelKit.cylinder(root, Vector3(c.x, band - 0.03, c.z), tr + 0.055, 0.09, gold, tr + 0.05, TOWER_SIDES)
			else:
				ModelKit.box(root, Vector3(w_lo.x - 0.022, band, w_lo.z - 0.022), Vector3(w_hi.x + 0.022, band + 0.08,
					w_hi.z + 0.022), gold)
			var tip := Vector3((w_lo.x + w_hi.x) / 2.0 + float(f.get("shift", 0.0)), float(ctx.get("top", w_hi.y)),
				(w_lo.z + w_hi.z) / 2.0)
			ModelKit.cylinder(root, tip, 0.016, 0.16, gold, -1.0, 6)
			var star := Node3D.new()
			var points: Array[Vector3] = []
			for k in 10:
				var reach := STAR_R * (1.0 if k % 2 == 0 else STAR_WAIST)
				points.append(Vector3(sin(TAU * k / 10.0) * reach, cos(TAU * k / 10.0) * reach, 0))
			var sides: Array = []
			for k in 10:
				sides.append([points[k], points[(k + 1) % 10], Vector3(0, 0, STAR_THICK)])
				sides.append([points[(k + 1) % 10], points[k], Vector3(0, 0, -STAR_THICK)])
			ModelKit.faces(star, sides, Vector3.ZERO, gold)
			star.position = tip + Vector3(0, 0.16 + STAR_R, 0)
			star.rotation.y = PI / 4.0   # (turned to the camera)
			root.add_child(star)
		"steam":
			# Steam off warm water (a spa's pool), while the building works.
			if moving:
				DecorMotion.spray(root, at + Vector3(0, float(f.get("up", 0.12)), 0), DecorMotion.STEAM)
		"jet":
			# A fountain in the pool: a stone spout, and its jet while the building works.
			ModelKit.cylinder(root, at, 0.05, 0.14, ModelKit.surface(STONE.lightened(0.1), "stone", 0.2), 0.035, 8)
			if moving:
				DecorMotion.spray(root, at + Vector3(0, 0.15, 0), DecorMotion.JET)
		"sails":
			# A windmill's sails on its tower's top storey or (`"on": "lower"`) its lower one. One set faces the
			# camera. Two stand on opposite sides: the top one over the door, on the left as you see it, and the
			# lower one on the right. A broken set never turns.
			var hubs: Dictionary = ctx.get("hubs", {})
			if hubs.is_empty():
				return true
			var low := str(f.get("on", "top")) == "lower"
			var twin := false
			for other: Dictionary in (ctx["spec"] as Dictionary).get("features", []):
				twin = twin or (str(other.get("type", "")) == "sails" and str(other.get("on", "top")) == "lower")
			var face := Vector3(1, 0, 0) if low else (Vector3(0, 0, 1) if twin else Vector3(1, 0, 1).normalized())
			var hub: Vector2 = hubs["lower" if low else "top"]
			sails(root, c + face * hub.x + Vector3(0, hub.y, 0), face, float(f.get("reach", 0.7)),
				moving and not bool(f.get("broken", false)), bool(f.get("broken", false)),
				Color.html(str(f.get("stripe", "#" + CREAM.to_html(false)))))
		"chute":
			# A grain chute from the mill down to an open bin; grain runs from it while the building works.
			var boards := ModelKit.surface(WOOD, "boards", 0.2)
			ModelKit.tub(root, at + Vector3(-0.17, 0, -0.17), at + Vector3(0.17, 0.2, 0.17), 0.02, boards,
				ModelKit.paint(GRAIN))
			var toward := Vector3(c.x - at.x, 0, c.z - at.z).normalized()
			# (a trough: a floor and two sides, running down from the mill's wall to over the bin)
			var run := Vector3(0, sin(CHUTE_TILT), 0) + toward * cos(CHUTE_TILT)
			for part: Array in [[-0.08, 0.08, -0.02, 0.02], [-0.1, -0.07, -0.02, 0.07], [0.07, 0.1, -0.02, 0.07]]:
				var board := ModelKit.box(root, Vector3(part[0], part[2], -CHUTE_LONG / 2.0), Vector3(part[1], part[3],
					CHUTE_LONG / 2.0), boards)
				board.rotation = Vector3(-CHUTE_TILT, atan2(toward.x, toward.z), 0)
				board.position = at + Vector3(0, CHUTE_HIGH, 0) + run * CHUTE_LONG / 2.0 + board.basis * Vector3(
					(float(part[0]) + float(part[1])) / 2.0, (float(part[2]) + float(part[3])) / 2.0, 0)
			if moving:
				DecorMotion.spray(root, at + Vector3(0, CHUTE_HIGH, 0), GRAIN_FALL)
		"press":
			# A wine press: a slatted tub on a stone bed, a screw up its middle, and the bar that turns it while
			# the building works.
			ModelKit.cylinder(root, at, 0.27, 0.07, ModelKit.surface(STONE, "stone", 0.2), 0.25, 10)
			ModelKit.cylinder(root, at + Vector3(0, 0.07, 0), 0.2, 0.26, ModelKit.surface(WOOD, "boards", 0.2), 0.22, 10)
			for hoop: float in [0.12, 0.27]:
				ModelKit.cylinder(root, at + Vector3(0, hoop, 0), 0.225, 0.03, ModelKit.paint(IRON, 0.4), -1.0, 10)
			ModelKit.cylinder(root, at + Vector3(0, 0.33, 0), 0.19, 0.02, ModelKit.paint(GRAPE.darkened(0.2)), -1.0, 10)
			ModelKit.cylinder(root, at + Vector3(0, 0.33, 0), 0.03, 0.34, ModelKit.paint(DARK_WOOD), -1.0, 6)
			var bar := Node3D.new()
			ModelKit.box(bar, Vector3(-0.3, -0.02, -0.02), Vector3(0.3, 0.02, 0.02), ModelKit.paint(DARK_WOOD))
			for end: float in [-0.3, 0.3]:
				bead(bar, Vector3(end, 0, 0), 0.04, ModelKit.paint(WOOD.lightened(0.2)))
			_turns(root, at + Vector3(0, 0.6, 0), bar, moving, 1.1)
		"pour":
			# A keg on a stand with a pail under its tap; the wine runs while the building works.
			var keg := ModelKit.cylinder(root, Vector3.ZERO, 0.13, 0.3, ModelKit.surface(Color("#8a5530"), "boards", 0.2),
				-1.0, 10)
			keg.rotation.x = PI / 2.0
			keg.position = at + Vector3(0, 0.36, 0)
			for leg: float in [-0.1, 0.1]:
				ModelKit.box(root, at + Vector3(-0.13, 0, leg - 0.025), at + Vector3(0.13, 0.25, leg + 0.025),
					ModelKit.paint(DARK_WOOD))
			ModelKit.box(root, at + Vector3(-0.015, 0.29, 0.15), at + Vector3(0.015, 0.33, 0.22), ModelKit.paint(IRON, 0.4))
			ModelKit.tub(root, at + Vector3(-0.08, 0, 0.13), at + Vector3(0.08, 0.12, 0.29), 0.015,
				ModelKit.surface(WOOD.lightened(0.1), "boards", 0.2), ModelKit.paint(GRAPE.darkened(0.25)))
			if moving:
				DecorMotion.spray(root, at + Vector3(0, 0.29, 0.21), POUR)
		"rack":
			# Shelves of goods standing by the building, facing you: a storage part. Its three shelves fill from
			# the bottom as the building fills, and a full one has a crate more on the ground beside it.
			var held := int(ctx.get("fill", 0))
			var goods := str(f.get("goods", "loaves"))
			var boards := ModelKit.surface(WOOD, "boards", 0.2)
			for side: float in [-1.0, 1.0]:
				ModelKit.box(root, at + Vector3(side * RACK_WIDE / 2.0 - 0.02, 0, -0.08), at + Vector3(
					side * RACK_WIDE / 2.0 + 0.02, RACK_TALL, 0.08), boards)
			ModelKit.box(root, at + Vector3(-RACK_WIDE / 2.0 - 0.04, RACK_TALL, -0.1), at + Vector3(
				RACK_WIDE / 2.0 + 0.04, RACK_TALL + 0.03, 0.12), ModelKit.paint(DARK_WOOD))
			for k in 3:
				var shelf := at + Vector3(0, 0.07 + k * RACK_TALL * 0.31, 0)
				ModelKit.box(root, shelf + Vector3(-RACK_WIDE / 2.0, 0, -0.08), shelf + Vector3(RACK_WIDE / 2.0, 0.02,
					0.08), boards)
				for n in (3 if held > k else 0):
					_good(root, shelf + Vector3((n - 1) * RACK_WIDE * 0.3, 0.02, 0.01), goods, n + k)
			if held >= FULL:
				var crate := at + Vector3(RACK_WIDE / 2.0 + 0.16, 0, 0.1)
				ModelKit.tub(root, crate + Vector3(-0.11, 0, -0.08), crate + Vector3(0.11, 0.1, 0.08), 0.015, boards)
				for n in 4:
					_good(root, crate + Vector3(-0.05 + 0.1 * (n % 2), 0.08, -0.03 + 0.06 * (n / 2)), goods, n)
		"oven":
			_oven(ctx, f)
		"hay_rack":
			# A hay rack on crossed legs, full, with what the animals pulled out lying under it.
			for end: float in [-0.2, 0.2]:
				for lean: float in [-1.0, 1.0]:
					var leg := ModelKit.box(root, Vector3(-0.015, 0, -0.015), Vector3(0.015, 0.36, 0.015),
						ModelKit.paint(WOOD))
					leg.position = at + Vector3(end, 0, 0)
					leg.rotation.x = 0.5 * lean
			ModelKit.box(root, at + Vector3(-0.24, 0.2, -0.012), at + Vector3(0.24, 0.225, 0.012),
				ModelKit.paint(WOOD))
			ModelKit.ball(root, at + Vector3(0, 0.3, 0), 0.16, ModelKit.paint(HAY), Vector3(1.5, 0.6, 0.75))
			ModelKit.ball(root, at + Vector3(0.05, 0.34, 0.02), 0.1, ModelKit.paint(HAY.lightened(0.1)), Vector3(1.4,
				0.6, 0.8))
			ModelKit.ball(root, at + Vector3(-0.05, 0.02, 0.12), 0.1, ModelKit.paint(HAY.darkened(0.08)), Vector3(1.3,
				0.25, 0.9))
		"milk_cans":
			for k in int(f.get("count", 3)):
				var p := at + Vector3(0.13 * k, 0, 0.05 * (k % 2))
				var tin := ModelKit.paint(Color("#c5ccd1").darkened(0.06 * (k % 2)), 0.6)
				ModelKit.cylinder(root, p, 0.055, 0.16, tin, 0.055, 10)
				ModelKit.cylinder(root, p + Vector3(0, 0.16, 0), 0.055, 0.04, tin, 0.035, 10)
				ModelKit.cylinder(root, p + Vector3(0, 0.2, 0), 0.04, 0.02, tin, 0.045, 10)
		"perch":
			# A roost: two posts and three rungs, a ladder leaning to it.
			for side: float in [-0.16, 0.16]:
				ModelKit.box(root, at + Vector3(side - 0.015, 0, -0.015), at + Vector3(side + 0.015, 0.36, 0.015),
					ModelKit.paint(WOOD))
			for k in 3:
				ModelKit.box(root, at + Vector3(-0.2, 0.1 + 0.11 * k, -0.012 + 0.05 * k), at + Vector3(0.2,
					0.125 + 0.11 * k,
					0.012 + 0.05 * k), ModelKit.paint(WOOD.lightened(0.12)))
		"feeder":
			ModelKit.cylinder(root, at, 0.1, 0.03, ModelKit.paint(Color("#c0392b"), 0.3), 0.1, 10)
			ModelKit.cylinder(root, at + Vector3(0, 0.03, 0), 0.05, 0.13, ModelKit.paint(Color("#d9dcde"), 0.5), 0.06,
				10)
			ModelKit.cylinder(root, at + Vector3(0, 0.16, 0), 0.075, 0.05, ModelKit.paint(Color("#c0392b"), 0.3),
				0.01, 10)
			for k in 7:
				bead(root, at + Vector3(cos(k * GOLDEN) * 0.16, 0.008, sin(k * GOLDEN) * 0.16), 0.012,
					ModelKit.paint(Color("#e8c96a")))
		"bench":
			var x := (lo.x + hi.x) / 2.0 + float(f.get("shift", 0.3)) * (hi.x - lo.x)
			var z := hi.z + 0.1
			var y := BuildingModel.PLINTH if bool(f.get("on_porch", true)) else 0.0
			var plank := ModelKit.surface(WOOD.lightened(0.12), "boards", 0.0)
			ModelKit.box(root, Vector3(x - 0.16, y + 0.1, z - 0.05), Vector3(x + 0.16, y + 0.125, z + 0.06), plank)
			ModelKit.box(root, Vector3(x - 0.16, y + 0.125, z - 0.05), Vector3(x + 0.16, y + 0.26, z - 0.03), plank)
			for side: float in [-0.14, 0.14]:
				ModelKit.box(root, Vector3(x + side - 0.012, y, z - 0.04), Vector3(x + side + 0.012, y + 0.1,
					z + 0.05),
					ModelKit.paint(DARK_WOOD))
		"woodpile":
			# Split logs stacked against the side wall, an axe in the chopping block beside them.
			var x := minf(hi.x + 0.1, fw - 0.12)
			var z0 := float(f.get("z", 0.25)) * (hi.z - lo.z) + lo.z
			for k in 9:
				var row := 0 if k < 4 else (1 if k < 7 else 2)
				var i := k if k < 4 else (k - 4 if k < 7 else k - 7)
				var p := Vector3(x, 0.045 + 0.08 * row, z0 + 0.09 * i + 0.045 * row)
				var cut := ModelKit.cylinder(root, Vector3.ZERO, 0.042, 0.22, ModelKit.surface(Color("#7a5230"),
					"logs", 0.1), -1.0, 6)
				cut.rotation.z = PI / 2.0
				cut.position = p
				ModelKit.cylinder(root, p + Vector3(0.112, -0.004, 0), 0.036, 0.008, ModelKit.paint(Color("#d9b98a")),
					-1.0, 6) \
					.rotation.z = PI / 2.0
			var block := Vector3(minf(x + 0.26, fw - 0.1), 0, z0 + 0.1)
			ModelKit.cylinder(root, block, 0.08, 0.1, ModelKit.surface(Color("#8a6a45"), "logs", 0.2), 0.075, 8)
		_:
			return false
	return true


## A bakery's brick oven built against its side wall: a broad base with an arched mouth and its glow, a
## shoulder, and a tall chimney stepping in to a cap and a pot above the roof; it smokes when baking.
static func _oven(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var top: float = ctx.get("top", hi.y)
	var brick := ModelKit.surface(Color.html(str(f.get("color", "#a6533c"))), "stone", 0.25)
	var z := lerpf(lo.z, hi.z, float(f.get("z", 0.3)))
	var x := hi.x
	var deep := 0.3
	ModelKit.box(root, Vector3(x, 0, z - 0.24), Vector3(x + deep, 0.5, z + 0.24), brick)
	ModelKit.box(root, Vector3(x, 0.5, z - 0.19), Vector3(x + deep * 0.8, 0.66, z + 0.19), brick)
	# Its mouth: a dark arch on the face the camera sees, a fire glowing in it (the windows' own glass, warm at night).
	ModelKit.box(root, Vector3(x + deep, 0.12, z - 0.11), Vector3(x + deep + 0.008, 0.3, z + 0.11),
		ModelKit.paint(Color("#2a1a12")))
	var arch := ModelKit.cylinder(root, Vector3.ZERO, 0.11, 0.008, ModelKit.paint(Color("#2a1a12")), -1.0, 12)
	arch.rotation.z = PI / 2.0
	arch.position = Vector3(x + deep + 0.004, 0.3, z)
	ModelKit.ball(root, Vector3(x + deep, 0.17, z), 0.07, ModelKit.paint(Color("#ff9a2e"), 0.2), Vector3(0.3, 0.7,
		1.2))
	ModelKit.box(root, Vector3(x + deep - 0.01, 0.42, z - 0.26), Vector3(x + deep + 0.04, 0.46, z + 0.26),
		ModelKit.surface(STONE, "plaster", 0.0))
	var stack_top := maxf(top + 0.22, 1.2)
	ModelKit.box(root, Vector3(x, 0.66, z - 0.12), Vector3(x + 0.22, stack_top, z + 0.12), brick)
	ModelKit.box(root, Vector3(x - 0.025, stack_top, z - 0.145), Vector3(x + 0.245, stack_top + 0.05, z + 0.145),
		ModelKit.surface(STONE, "plaster", 0.0))
	ModelKit.cylinder(root, Vector3(x + 0.11, stack_top + 0.05, z), 0.055, 0.1, ModelKit.paint(Color("#8a4630")),
		0.045, 8)
	if ctx.get("active", true):
		DecorMotion.spray(root, Vector3(x + 0.11, stack_top + 0.17, z), DecorMotion.SMOKE)


## A round tower for a body (a windmill; `"shape": "tower"` in data/building_models.json): a stone foot, walls
## that taper under a band of trim, and a pointed dome for a cap. With `lower` (a height) it
## has two storeys: a broad lower one under a pent roof, and a slimmer upper one. Each storey has a window.
## Leaves the tower's bounds in ctx as lo, hi and top (tower_top is its radius there, hubs where its "sails"
## features hang), and returns the flat-fronted case its door stands in, as [lo, hi]: a door cannot hang on a
## round wall.
static func tower(ctx: Dictionary) -> Array:
	var root: Node3D = ctx["root"]
	var s: Dictionary = ctx["spec"]
	var body: Dictionary = s["body"]
	var c: Vector3 = ctx["centre"]
	var bh: float = ctx["bh"]
	var r0 := minf(ctx["bw"], ctx["bd"]) / 2.0
	var trim := ModelKit.paint(Color.html(str(s.get("trim", "#f3eee2"))))
	var r: Dictionary = s["roof"]
	var roof_col := Color.html(str(r.get("color", "#8e3b2c")))
	var roof_mat := ModelKit.paint(roof_col)
	var over := float(r.get("overhang", 0.14))
	var wall := ModelKit.surface(ctx["wall"], str(body.get("walls", "plaster")))
	var foot := BuildingModel.PLINTH * 1.5
	ModelKit.cylinder(root, c, r0 + 0.07, foot, ModelKit.surface(STONE, "stone", 0.3), r0 + 0.03, TOWER_SIDES)
	# Each storey: [from, to, its radius at the foot, and at the top].
	var storeys: Array = [[foot * 0.5, bh, r0, r0 * float(body.get("taper", TOWER_TAPER))]]
	var lower := float(body.get("lower", 0.0))
	if lower > 0.0:
		storeys = [[foot * 0.5, lower, r0, r0 * LOWER_TAPER], [lower + LOWER_ROOF, bh, r0 * UPPER_FOOT, r0 * UPPER_TOP]]
		ModelKit.cylinder(root, c + Vector3(0, lower, 0), r0 * LOWER_TAPER + over, LOWER_ROOF, roof_mat,
			r0 * UPPER_FOOT, TOWER_SIDES)
	var windows: Array = []
	var r1 := r0
	for storey: Array in storeys:
		var from: float = storey[0]
		var to: float = storey[1]
		var wide: float = storey[2]
		r1 = storey[3]
		ModelKit.cylinder(root, c + Vector3(0, from, 0), wide, to - from, wall, r1, TOWER_SIDES)
		ModelKit.cylinder(root, c + Vector3(0, to - 0.08, 0), r1 + 0.035, 0.08, trim, r1 + 0.03, TOWER_SIDES)
		# A window, in a frame deep enough to stand out of the round wall.
		var size := 0.24 if windows.is_empty() else 0.2
		var at := Vector3(c.x + lerpf(wide, r1, 0.55), lerpf(from, to, 0.55), c.z)
		ModelKit.box(root, at + Vector3(-0.07, -size / 2 - 0.035, -size / 2 - 0.035),
			at + Vector3(0.04, size / 2 + 0.035, size / 2 + 0.035), trim)
		ModelKit.box(root, at + Vector3(0.04, -size / 2, -size / 2), at + Vector3(0.044, size / 2, size / 2),
			ModelKit.glass())
		windows.append({"at": at + Vector3(0.04, 0, 0), "size": size})
	ctx["window_at"] = windows
	# The cap: a smooth dome a little taller than it is wide, over a dark eave, with a ball on its tip.
	var rise := float(r.get("pitch", 1.5)) * r1
	ModelKit.cylinder(root, c + Vector3(0, bh, 0), r1 + over + 0.02, CAP_EAVE, ModelKit.paint(roof_col.darkened(0.25)),
		-1.0, CAP_SIDES)
	var dome := MeshInstance3D.new()
	var round := SphereMesh.new()
	round.is_hemisphere = true
	round.radius = r1 + over
	round.height = rise
	round.radial_segments = CAP_SIDES
	round.rings = CAP_SIDES / 2
	dome.mesh = round
	dome.position = c + Vector3(0, bh + CAP_EAVE, 0)
	dome.material_override = ModelKit.paint(roof_col)
	root.add_child(dome)
	ModelKit.ball(root, c + Vector3(0, bh + CAP_EAVE + rise + 0.03, 0), 0.05, trim)
	ctx["lo"] = Vector3(c.x - r0, 0, c.z - r0)
	ctx["hi"] = Vector3(c.x + r0, bh, c.z + r0)
	ctx["top"] = bh + CAP_EAVE + rise + 0.08
	ctx["tower_top"] = r1
	# Where sails can hang (the "sails" feature): how far from the middle and how high, on the top storey and on
	# the lower one.
	ctx["hubs"] = {"top": Vector2(r1 + over + 0.03, bh + CAP_EAVE + rise * 0.16),
		"lower": Vector2(r0 * LOWER_TAPER + over + 0.06, lower + 0.05)}
	# The door's case: a stone porch standing out of the foot of the tower, under a slab the roof's colour.
	var door: Dictionary = s.get("door", {})
	var w := float(door.get("w", 0.28)) * float(ctx["bw"]) / 0.7
	var arch := w / 2.0 if str(door.get("style", "barn")) == "arch" else 0.0
	var back: float = (storeys[0] as Array)[3]
	var case_lo := Vector3(c.x - w / 2.0 - 0.08, 0, c.z + back * 0.8)
	var case_hi := Vector3(c.x + w / 2.0 + 0.08, BuildingModel.PLINTH + float(door.get("h", 0.5)) + arch + 0.08,
		c.z + r0 + 0.06)
	ModelKit.box(root, case_lo, case_hi, ModelKit.surface(STONE.lightened(0.14), "stone", 0.3))
	ModelKit.box(root, Vector3(case_lo.x - 0.05, case_hi.y, case_lo.z), Vector3(case_hi.x + 0.05, case_hi.y + 0.06,
		case_hi.z + 0.06), ModelKit.paint(roof_col.darkened(0.1)))
	return [case_lo, case_hi]


## A windmill's four sails on a shaft at `hub`, facing `out` (level): each a spar, a cloth and a rail along its
## edge; every other cloth is `stripe`. They turn while the mill is `turning` (one draw, spun on the GPU) and
## stand still otherwise. A `broken` wheel has one sail snapped off short, its cloth gone.
static func sails(root: Node3D, hub: Vector3, out: Vector3, reach: float, turning: bool, broken := false,
		stripe := CREAM) -> void:
	# Built to turn about its own y (the orbit shader's axis), then laid over so that axis points along `out`.
	var lay := Vector3(PI / 2.0, atan2(out.x, out.z), 0)
	var shaft := ModelKit.cylinder(root, Vector3.ZERO, 0.04, 0.3, ModelKit.paint(DARK_WOOD), -1.0, 8)
	shaft.position = hub - out * 0.13
	shaft.rotation = lay
	var wheel := Node3D.new()
	ModelKit.cylinder(wheel, Vector3(0, -0.03, 0), 0.07, 0.08, ModelKit.paint(DARK_WOOD.darkened(0.2)), 0.05, 8)
	var wide := reach * SAIL_WIDE
	for k in 4:
		var arm := Node3D.new()
		arm.rotation.y = TAU * k / 4.0
		wheel.add_child(arm)
		if broken and k == 1:
			# (the stump of a spar, splintered at an angle)
			ModelKit.box(arm, Vector3(0.03, -0.014, -0.016), Vector3(reach * 0.34, 0.014, 0.016),
				ModelKit.paint(DARK_WOOD))
			var splinter := ModelKit.box(arm, Vector3(0, -0.012, -0.012), Vector3(reach * 0.14, 0.012, 0.012),
				ModelKit.paint(DARK_WOOD.lightened(0.2)))
			splinter.position = Vector3(reach * 0.32, 0, 0)
			splinter.rotation.y = 0.7
			continue
		ModelKit.box(arm, Vector3(0.03, -0.014, -0.016), Vector3(reach, 0.014, 0.016), ModelKit.paint(DARK_WOOD))
		ModelKit.box(arm, Vector3(reach * 0.22, -0.006, 0.016), Vector3(reach * 0.98, 0.006, 0.016 + wide),
			ModelKit.paint(stripe if k % 2 == 0 else CREAM))
		ModelKit.box(arm, Vector3(reach * 0.22, -0.011, 0.016 + wide - 0.012), Vector3(reach * 0.98, 0.011,
			0.016 + wide + 0.012), ModelKit.paint(DARK_WOOD.lightened(0.12)))
	var holder: Node3D
	if turning:
		holder = DecorMotion.orbit(root, hub, wheel, {"speed": 0.55, "radius": 0.0})
		for part in holder.get_children():
			if part is MeshInstance3D:
				(part as MeshInstance3D).custom_aabb = AABB(Vector3(-reach, -0.2, -reach), Vector3(reach * 2.0, 0.4,
					reach * 2.0))
	else:
		holder = Node3D.new()
		holder.position = hub
		holder.add_child(wheel)
		wheel.rotation.y = 0.5
		root.add_child(holder)
	holder.rotation = lay


## A full silo running over: its lid is off, grain is heaped out of its top and lies in a mound at its foot,
## on the side the camera sees. `base` is the middle of its foot, `r` its radius and `h` its height.
static func overflow(root: Node3D, base: Vector3, r: float, h: float) -> void:
	var grain := ModelKit.paint(GRAIN)
	var out := Vector3(1, 0, 1).normalized()
	ModelKit.cylinder(root, base + Vector3(0, h, 0), r + 0.04, r * 1.2, grain, 0.03, 10)
	ModelKit.cylinder(root, base + out * (r + 0.1), 0.17, 0.1, grain, 0.03, 8)


## A glass up the side of a storage part, showing how full it is: a dark slot `tall` high standing at `foot` and
## facing `out`, filled a third, two thirds or to the top in `col` as `fill` goes from a quarter to full.
static func gauge(root: Node3D, foot: Vector3, out: Vector3, tall: float, fill: int, col: Color) -> void:
	var turn := atan2(out.x, out.z)
	var slot := ModelKit.box(root, Vector3(-GAUGE_WIDE / 2.0, -tall / 2.0, -0.006), Vector3(GAUGE_WIDE / 2.0, tall / 2.0,
		0.006), ModelKit.paint(IRON), false)
	slot.position = foot + Vector3(0, tall / 2.0, 0) + out * 0.006
	slot.rotation.y = turn
	if fill <= 0:
		return
	var high := tall * fill / float(FULL) - 0.02
	var level := ModelKit.box(root, Vector3(-GAUGE_WIDE / 2.0 + 0.014, -high / 2.0, -0.005), Vector3(
		GAUGE_WIDE / 2.0 - 0.014, high / 2.0, 0.005), ModelKit.paint(col), false)
	level.position = foot + Vector3(0, 0.01 + high / 2.0, 0) + out * 0.016
	level.rotation.y = turn


## A small keg standing on end at `at`.
static func _keg(root: Node3D, at: Vector3) -> void:
	ModelKit.cylinder(root, at, 0.09, 0.2, ModelKit.surface(Color("#8a5530"), "boards", 0.2), 0.08, 8)
	ModelKit.cylinder(root, at + Vector3(0, 0.085, 0), 0.094, 0.03, ModelKit.paint(IRON, 0.4), 0.092, 8)


## One of the goods on a rack: a loaf, or a bottle.
static func _good(root: Node3D, at: Vector3, kind: String, n: int) -> void:
	if kind == "bottles":
		var glass: Color = [Color("#3b9bb8"), Color("#e58fb0"), Color("#f3eee2")][n % 3]
		ModelKit.cylinder(root, at, 0.035, 0.09, ModelKit.paint(glass, 0.5), 0.03, 6)
		bead(root, at + Vector3(0, 0.105, 0), 0.02, ModelKit.paint(DARK_WOOD))
	else:
		bead(root, at + Vector3(0, 0.04, 0), 0.06, ModelKit.paint(BAKED.darkened(0.08 * (n % 2))), Vector3(1.0, 0.7,
			0.8))


## Puts `part` at `at`, turning about its own upright (one draw, spun on the GPU) while `moving`, still otherwise.
static func _turns(root: Node3D, at: Vector3, part: Node3D, moving: bool, speed: float) -> void:
	if moving:
		DecorMotion.orbit(root, at, part, {"speed": speed, "radius": 0.0})
		return
	part.position = at
	part.rotation.y = 0.6
	root.add_child(part)
