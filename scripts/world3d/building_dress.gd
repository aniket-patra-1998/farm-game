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
const SHADE_LIFT := 0.014     # it lies this far above the ground (over a yard's floor)
const GOLDEN := 2.39996
## Every feature this dressing builds (`feature`); BuildingModel builds the rest.
const FEATURES: Array[String] = ["sacks", "crates", "cask", "oven", "emblem", "crown", "sails", "chute",
	"press", "pour", "boiler", "jet", "rack", "hay_rack",
	"milk_cans", "perch", "feeder", "bench", "woodpile"]
const GOLD := Color("#f2c14e")
const GRAIN := Color("#e8b93c")
## The features that can be a crafting building's animated part: each is a thing you can see when it stands still.
const MACHINES: Array[String] = ["sails", "chute", "oven", "chimney", "press", "pour", "boiler", "jet"]
const ANIMATED := "animated"  # a feature's `part`: it moves while the building is crafting, and only then
const STORAGE := "storage"    # a feature's `part`: it shows how full the building is, in FILLS looks
const FILLS := 4              # empty, a quarter, half and full
const FULL := 3
const CHUTE_LONG := 0.7       # a grain chute: how long its spout is..
const CHUTE_TILT := 0.55       # ..how steeply it runs down (radians)..
const CHUTE_HIGH := 0.42       # ..and how high its mouth is over the ground
const BADGE_R := 0.24             # the VIP badge: its medallion's radius, in tiles..
const BADGE_THICK := 0.022        # ..half its thickness..
const BADGE_POST := 0.16          # ..the finial it stands on..
const BADGE_BOB := 0.025          # ..how far it rides up and down while VIP is active..
const BADGE_TIER := 3             # ..and the VIP levels to a tier of it
## A tier's metal, the enamel its number stands on, and its gems: bronze, silver, gold, gold on green, and
## gold on royal purple with diamonds.
const BADGE_METALS: Array[Color] = [Color("#cf8a45"), Color("#d9dee4"), Color("#f6c443"), Color("#f6c443"),
	Color("#ffd65a")]
const BADGE_ENAMELS: Array[Color] = [Color("#5c2413"), Color("#1d3566"), Color("#96172a"), Color("#0e6a46"),
	Color("#4a1e96")]
const BADGE_GEMS: Array[Color] = [Color("#e2553d"), Color("#4fb3ff"), Color("#e2553d"), Color("#ff5c7a"),
	Color("#bff3ff")]
const DIGIT_GAP := 0.28           # the space between two digits, against a digit's width
const DIGIT_STROKE := 0.26        # a stroke's thickness, against a digit's width
## The digits 0 to 9 as lines, each a run of x, y points in a box 1 wide and 2 tall (corners cut, so they read
## as round).
const DIGIT_STROKES := [
	[[0.25, 0, 0.75, 0, 1, 0.3, 1, 1.7, 0.75, 2, 0.25, 2, 0, 1.7, 0, 0.3, 0.25, 0]],
	[[0.15, 1.5, 0.6, 2, 0.6, 0], [0.15, 0, 1, 0]],
	[[0, 1.65, 0.3, 2, 0.7, 2, 1, 1.65, 1, 1.25, 0, 0, 1, 0]],
	[[0, 1.7, 0.3, 2, 0.7, 2, 1, 1.7, 1, 1.3, 0.7, 1.05, 0.35, 1.05], [0.7, 1.05, 1, 0.75, 1, 0.3, 0.7, 0, 0.3, 0,
		0, 0.3]],
	[[0.75, 0, 0.75, 2, 0, 0.65, 1, 0.65]],
	[[1, 2, 0.1, 2, 0.1, 1.15, 0.7, 1.15, 1, 0.85, 1, 0.3, 0.7, 0, 0.3, 0, 0, 0.3]],
	[[0.9, 2, 0.45, 2, 0, 1.4, 0, 0.3, 0.3, 0, 0.7, 0, 1, 0.3, 1, 0.8, 0.7, 1.1, 0.3, 1.1, 0, 0.8]],
	[[0, 2, 1, 2, 0.4, 0]],
	[[0.3, 1.05, 0.05, 1.3, 0.05, 1.7, 0.3, 2, 0.7, 2, 0.95, 1.7, 0.95, 1.3, 0.7, 1.05, 0.3, 1.05, 0, 0.75, 0, 0.3,
		0.3, 0, 0.7, 0, 1, 0.3, 1, 0.75, 0.7, 1.05]],
	[[0.1, 0, 0.55, 0, 1, 0.6, 1, 1.7, 0.7, 2, 0.3, 2, 0, 1.7, 0, 1.2, 0.3, 0.9, 0.7, 0.9, 1, 1.2]]]
const TABLE := Vector3(0.22, 0.2, 0.11)   # a table of goods: half its length, its height and half its width
const RACK_WIDE := 0.4
const RACK_TALL := 0.52
const GAUGE_WIDE := 0.11
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
const SAIL_SPEED := 0.55      # how fast a windmill's sails turn (radians a second)
const SAIL_WIDE := 0.27       # a windmill sail's width, as a share of its length



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
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ModelKit.shade_material()
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
				var row := p.z + r * 0.85 + 0.2
				for held in range(1, FILLS):
					for k in mini(held, FULL):
						_keg(when(ctx, "fill", held), Vector3(p.x + (k - 1) * 0.21, 0, row))
				_keg(when(ctx, "fill", FULL), Vector3(p.x - 0.105, 0.2, row))
				ModelKit.cylinder(when(ctx, "fill", FULL), Vector3(p.x + 0.16, 0, row + 0.16), 0.15, 0.012,
					ModelKit.paint(GRAPE), 0.13, 10)
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
			if not f.get("star", true):
				return true   # (the gold alone: something else stands on its roof, as the Barn's badge does)
			var star_r := float(f.get("r", STAR_R))   # (a small building wears a smaller star)
			ModelKit.cylinder(root, tip, 0.016, star_r * 0.67, gold, -1.0, 6)
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
			star.scale = Vector3.ONE * (star_r / STAR_R)
			star.position = tip + Vector3(0, star_r * 1.67, 0)
			star.rotation.y = PI / 4.0   # (turned to the camera)
			root.add_child(star)
		"vip_badge":
			_vip_badge(ctx, lo, hi)
		"boiler":
			# A copper boiler on a stone bed beside the bath, a pipe out of its top. While the building works, the
			# pool it heats steams (`pool`: where, as shares of the plot).
			var copper := ModelKit.paint(Color("#c9793a"), 0.6)
			ModelKit.cylinder(root, at, 0.22, 0.08, ModelKit.surface(STONE, "stone", 0.2), 0.2, 10)
			ModelKit.cylinder(root, at + Vector3(0, 0.08, 0), 0.16, 0.32, copper, -1.0, 10)
			ModelKit.ball(root, at + Vector3(0, 0.4, 0), 0.16, copper, Vector3(1, 0.6, 1), true)
			for band: float in [0.14, 0.32]:
				ModelKit.cylinder(root, at + Vector3(0, band, 0), 0.166, 0.028, ModelKit.paint(IRON, 0.4), -1.0, 10)
			ModelKit.cylinder(root, at + Vector3(0, 0.46, 0), 0.035, 0.22, copper, -1.0, 6)
			ModelKit.box(root, at + Vector3(-0.055, 0.1, 0.15), at + Vector3(0.055, 0.21, 0.168), ModelKit.paint(IRON))
			var pool: Array = f.get("pool", [])
			DecorMotion.effect(when(ctx, "working", true), "steam", Vector3(float(pool[0]) * fw, 0.12,
				float(pool[1]) * fd) if pool.size() == 2 else at + Vector3(0, 0.7, 0))
		"jet":
			# A fountain in the pool: a stone bowl on a stem, and its jet while the building works.
			var marble := ModelKit.surface(STONE.lightened(0.2), "plaster", 0.1)
			ModelKit.cylinder(root, at, 0.05, 0.2, marble, 0.04, 8)
			ModelKit.cylinder(root, at + Vector3(0, 0.2, 0), 0.06, 0.05, marble, 0.14, 10)
			DecorMotion.effect(when(ctx, "working", true), "jet", at + Vector3(0, 0.27, 0))
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
			var hub_at := c + face * hub.x + Vector3(0, hub.y, 0)
			var reach := float(f.get("reach", 0.7))
			var stripe := Color.html(str(f.get("stripe", "#" + CREAM.to_html(false))))
			# (the shaft they hang on stands whatever the state)
			var shaft := ModelKit.cylinder(root, Vector3.ZERO, 0.04, 0.3, ModelKit.paint(DARK_WOOD), -1.0, 8)
			shaft.position = hub_at - face * 0.13
			shaft.rotation = Vector3(PI / 2.0, atan2(face.x, face.z), 0)
			if bool(f.get("broken", false)) or str(f.get("part", "")) != ANIMATED:
				sails(root, hub_at, face, reach, false, bool(f.get("broken", false)), stripe)
			else:
				# (turning while the building works, standing still otherwise: a set for each state)
				sails(when(ctx, "working", true), hub_at, face, reach, true, false, stripe)
				sails(when(ctx, "working", false), hub_at, face, reach, false, false, stripe)
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
			DecorMotion.effect(when(ctx, "working", true), "grain", at + Vector3(0, CHUTE_HIGH, 0))
		"press":
			# A wine press: a slatted tub on a stone bed, a screw up its middle, and the bar that turns it while
			# the building works.
			ModelKit.cylinder(root, at, 0.27, 0.07, ModelKit.surface(STONE, "stone", 0.2), 0.25, 10)
			ModelKit.cylinder(root, at + Vector3(0, 0.07, 0), 0.2, 0.26, ModelKit.surface(WOOD, "boards", 0.2), 0.22, 10)
			for hoop: float in [0.12, 0.27]:
				ModelKit.cylinder(root, at + Vector3(0, hoop, 0), 0.225, 0.03, ModelKit.paint(IRON, 0.4), -1.0, 10)
			ModelKit.cylinder(root, at + Vector3(0, 0.33, 0), 0.19, 0.02, ModelKit.paint(GRAPE.darkened(0.2)), -1.0, 10)
			ModelKit.cylinder(root, at + Vector3(0, 0.33, 0), 0.03, 0.34, ModelKit.paint(DARK_WOOD), -1.0, 6)
			_turns(when(ctx, "working", true), at + Vector3(0, 0.6, 0), _press_bar(), true, 1.1)
			_turns(when(ctx, "working", false), at + Vector3(0, 0.6, 0), _press_bar(), false, 1.1)
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
			DecorMotion.effect(when(ctx, "working", true), "pour", at + Vector3(0, 0.29, 0.21))
		"rack":
			# A stall of goods by the building, facing you, under a little roof in the building's colour: a
			# storage part. Its three shelves fill from the bottom as the building fills, and a full one has a
			# crate more on the ground beside it.
			var goods := str(f.get("goods", "loaves"))
			var boards := ModelKit.surface(WOOD.lightened(0.25), "boards", 0.2)
			if str(f.get("style", "stall")) == "table":
				_table(ctx, at, goods, boards)
				return true
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var leg := at + Vector3(corner.x * RACK_WIDE / 2.0, 0, corner.y * 0.08)
				ModelKit.box(root, leg + Vector3(-0.015, 0, -0.015), leg + Vector3(0.015, RACK_TALL, 0.015), boards)
			var roof := ModelKit.box(root, Vector3(-RACK_WIDE / 2.0 - 0.05, -0.012, -0.15), Vector3(RACK_WIDE / 2.0 + 0.05,
				0.012, 0.15), ModelKit.paint(Color.html(str(f.get("color", "#c0392b")))))
			roof.position = at + Vector3(0, RACK_TALL + 0.03, 0.02)
			roof.rotation.x = 0.3
			for k in 3:
				var shelf := at + Vector3(0, 0.07 + k * RACK_TALL * 0.3, 0)
				ModelKit.box(root, shelf + Vector3(-RACK_WIDE / 2.0, 0, -0.08), shelf + Vector3(RACK_WIDE / 2.0, 0.02,
					0.08), boards)
				for held in range(k + 1, FILLS):
					for n in 3:
						_good(when(ctx, "fill", held), shelf + Vector3((n - 1) * RACK_WIDE * 0.3, 0.02, 0.01), goods, n + k)
			var crate := at + Vector3(RACK_WIDE / 2.0 + 0.16, 0, 0.1)
			ModelKit.box(when(ctx, "fill", FULL), crate + Vector3(-0.11, 0, -0.08), crate + Vector3(0.11, 0.08, 0.08),
				ModelKit.paint(WOOD.lightened(0.1)))
			for n in 4:
				_good(when(ctx, "fill", FULL), crate + Vector3(-0.05 + 0.1 * (n % 2), 0.08, -0.03 + 0.06 * (n / 2)),
					goods, n)
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
	# While the building works, its chimney smokes.
	DecorMotion.effect(when(ctx, "working", true), "smoke", Vector3(x + 0.11, stack_top + 0.17, z))


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
	var low_top := float(body.get("lower_taper", LOWER_TAPER))
	var up_foot := float(body.get("upper_foot", UPPER_FOOT))
	var up_top := float(body.get("upper_top", UPPER_TOP))
	if lower > 0.0:
		storeys = [[foot * 0.5, lower, r0, r0 * low_top], [lower + LOWER_ROOF, bh, r0 * up_foot, r0 * up_top]]
		ModelKit.cylinder(root, c + Vector3(0, lower, 0), r0 * low_top + over, LOWER_ROOF, roof_mat,
			r0 * up_foot, TOWER_SIDES)
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
		"lower": Vector2(r0 * low_top + over + 0.06, lower + 0.05)}
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


## A windmill's four sails at `hub`, facing `out` (level): each a spar, a cloth and a rail along its
## edge; every other cloth is `stripe`. They turn while the mill is `turning` (a `spin` part: DecorMotion.spin) and
## stand still otherwise. A `broken` wheel has one sail snapped off short, its cloth gone.
static func sails(root: Node3D, hub: Vector3, out: Vector3, reach: float, turning: bool, broken := false,
		stripe := CREAM) -> void:
	# Built to turn about its own y (the orbit shader's axis), then laid over so that axis points along `out`.
	var lay := Vector3(PI / 2.0, atan2(out.x, out.z), 0)
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
	if turning:
		DecorMotion.spin(root, hub, lay, wheel, SAIL_SPEED)
		return
	var holder := Node3D.new()
	holder.position = hub
	holder.rotation = lay
	holder.add_child(wheel)
	wheel.rotation.y = 0.5
	root.add_child(holder)


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
	ModelKit.cylinder(root, at, 0.09, 0.2, ModelKit.paint(Color("#8a5530")), 0.08, 8)
	ModelKit.cylinder(root, at + Vector3(0, 0.085, 0), 0.094, 0.03, ModelKit.paint(IRON), 0.092, 8)


## The Barn's VIP badge (docs/VIP.md): a crest over the roof with the VIP level's number on it, which is the
## building's level (BarnDef.look_level). It grows richer by tier (three levels each): bronze, then silver with
## a laurel, gold with wings, a crown, and at the last rays and gems. Two looks of one part, switched in place:
## while VIP is active its metal glimmers (ModelKit.to_shine), glints twinkle round it and it rides gently up
## and down (`when_vip_true`); lapsed, the same crest stands still in dull grey (`when_vip_false`), so what
## was lost is plain to see. Neither shows before the first VIP level.
static func _vip_badge(ctx: Dictionary, lo: Vector3, hi: Vector3) -> void:
	var root: Node3D = ctx["root"]
	var w_lo: Vector3 = ctx.get("upper_lo", lo)
	var w_hi: Vector3 = ctx.get("upper_hi", hi)
	var foot := Vector3((w_lo.x + w_hi.x) / 2.0, float(ctx.get("top", w_hi.y)) - 0.03, (w_lo.z + w_hi.z) / 2.0)
	var at := foot + Vector3(0, BADGE_POST + BADGE_R, 0)
	var turn := Vector3(0, PI / 4.0, 0)   # (its face to the camera)
	var level := int(ctx.get("level", 1))
	var tier := clampi((level - 1) / BADGE_TIER, 0, BADGE_METALS.size() - 1)
	# What it stands on: a turned finial of dark iron (it never changes).
	var iron := ModelKit.paint(Color("#3f454c"), 0.5)
	ModelKit.cylinder(root, foot, 0.07, 0.03, iron, 0.05, 8)
	ModelKit.cylinder(root, foot + Vector3(0, 0.03, 0), 0.028, BADGE_POST - 0.03, iron, 0.02, 8)
	bead(root, foot + Vector3(0, BADGE_POST * 0.55, 0), 0.04, iron)
	for on: bool in [true, false]:
		var face := Node3D.new()
		_crest(face, level, tier, on)
		var part := when(ctx, "vip", on)
		if on:
			var glints := DecorMotion.effect(face, "sparkle", Vector3(0, 0, BADGE_THICK * 3.0))
			glints.rotation.x = PI / 2.0   # (its ring stands in the crest's own flat, facing out)
			ModelKit.to_shine(DecorMotion.bob(part, at, turn, face, BADGE_BOB))
		else:
			face.position = at
			face.rotation = turn
			part.add_child(face)


## The crest itself, built facing +z about its own middle: `on` in its tier's metal and enamel, or in greys.
static func _crest(face: Node3D, level: int, tier: int, on: bool) -> void:
	var metal_col: Color = BADGE_METALS[tier] if on else Color("#8f969d")
	var metal := ModelKit.paint(metal_col, 0.9 if on else 0.3)
	var pale := ModelKit.paint(metal_col.lightened(0.35), 0.9 if on else 0.3)
	var enamel := ModelKit.paint(BADGE_ENAMELS[tier] if on else Color("#4f555c"), 0.6 if on else 0.1)
	var ink := ModelKit.paint(Color("#fff8e6") if on else Color("#b9bfc5"), 0.8 if on else 0.2)
	var gem := ModelKit.paint(BADGE_GEMS[tier] if on else Color("#737a82"), 1.0 if on else 0.2)
	if tier >= 4:
		# Rays behind it, long and short by turns.
		for k in 12:
			var ray := _turned(face, Vector3(0, 0, -BADGE_THICK * 1.5), TAU * k / 12.0)
			var long := BADGE_R * (0.75 if k % 2 == 0 else 0.5)
			ModelKit.faces(ray, [[Vector3(-0.028, BADGE_R * 0.95, 0), Vector3(0.028, BADGE_R * 0.95, 0),
				Vector3(0, BADGE_R * 0.95 + long, 0)]], Vector3(0, 0, -1), pale)
	if tier >= 2:
		# Wings: three feathers a side, fanned up and out.
		for side: float in [-1.0, 1.0]:
			for k in 3:
				var feather := _turned(face, Vector3(side * BADGE_R * 0.8, -0.02 + 0.05 * k, -BADGE_THICK * 0.5),
					-side * (PI / 2.0 - 0.3 - 0.36 * k))
				var long := BADGE_R * (1.25 - 0.22 * k)
				ModelKit.faces(feather, [[Vector3(-0.035, 0, 0), Vector3(0.035, 0, 0), Vector3(0.02, long * 0.8, 0),
					Vector3(-0.02, long * 0.8, 0)], [Vector3(-0.02, long * 0.8, 0), Vector3(0.02, long * 0.8, 0),
					Vector3(0, long, 0)]], Vector3(0, long * 0.4, -1), pale if k == 1 else metal)
	elif tier >= 1:
		# A laurel: leaves up each side of the ring.
		for side: float in [-1.0, 1.0]:
			for k in 5:
				var a := -PI / 2.0 + side * (0.5 + 0.44 * k)
				var leaf := _turned(face, Vector3(cos(a), sin(a), 0) * BADGE_R * 1.14, a + side * 0.9)
				bead(leaf, Vector3.ZERO, 0.05, pale, Vector3(1.25, 0.5, 0.4))
	# The medallion: a ring of metal, studs round it, and enamel within.
	_disc(face, Vector3.ZERO, BADGE_R, BADGE_THICK * 2.0, metal, 16)
	_disc(face, Vector3(0, 0, BADGE_THICK * 0.4), BADGE_R * 0.8, BADGE_THICK * 2.0, enamel, 16)
	for k in 12:
		bead(face, Vector3(cos(TAU * k / 12.0), sin(TAU * k / 12.0), 0) * BADGE_R * 0.9 + Vector3(0, 0, BADGE_THICK),
			0.017, pale)
	_stroke_number(face, level, ink, BADGE_R * 0.78, BADGE_THICK * 1.4)
	if tier >= 3:
		# A crown on top: a band, three points, a gem on each.
		var base := Vector3(0, BADGE_R * 0.98, 0)
		ModelKit.box(face, base + Vector3(-0.1, 0, -0.03), base + Vector3(0.1, 0.045, 0.03), metal, false)
		for k in 3:
			var x := (k - 1) * 0.075
			var tall := 0.1 if k == 1 else 0.075
			ModelKit.cylinder(face, base + Vector3(x, 0.045, 0), 0.034, tall, pale, 0.0, 4)
			bead(face, base + Vector3(x, 0.045 + tall, 0), 0.022, gem)
		bead(face, base + Vector3(0, 0.022, 0.03), 0.02, gem)
	if tier >= 4:
		for side: float in [-1.0, 1.0]:
			bead(face, Vector3(side * BADGE_R * 0.9, 0, BADGE_THICK), 0.03, gem)
		bead(face, Vector3(0, -BADGE_R * 0.9, BADGE_THICK), 0.03, gem)


## A node at `at` turned by `turn` about the axis out of the crest's face: what is built under it points along
## its own upright.
static func _turned(face: Node3D, at: Vector3, turn: float) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.rotation.z = turn
	face.add_child(n)
	return n


## A disc facing +z, its middle at `at`.
static func _disc(face: Node3D, at: Vector3, r: float, thick: float, mat: Material, sides: int) -> void:
	var flat := Node3D.new()
	flat.position = at
	flat.rotation.x = PI / 2.0
	face.add_child(flat)
	ModelKit.cylinder(flat, Vector3(0, -thick / 2.0, 0), r, thick, mat, r, sides)


## A number drawn in strokes on a crest's face, centred, `tall` high: each digit a few lines with their
## corners cut (DIGIT_STROKES), each line a raised bar.
static func _stroke_number(face: Node3D, number: int, mat: Material, tall: float, z: float) -> void:
	var digits := str(clampi(number, 0, 99))
	var unit := tall / 2.0                       # (a digit is 1 wide and 2 tall in its own units)
	if digits.length() > 1:
		unit *= 0.78                             # (two digits share the face)
	var wide := digits.length() + (digits.length() - 1) * DIGIT_GAP
	var thick := unit * DIGIT_STROKE
	for k in digits.length():
		var left := (k * (1.0 + DIGIT_GAP) - wide / 2.0) * unit
		for line: Array in DIGIT_STROKES[digits.unicode_at(k) - 48]:
			for n in range(0, line.size() - 2, 2):
				var a := Vector3(left + float(line[n]) * unit, (float(line[n + 1]) - 1.0) * unit, z)
				var b := Vector3(left + float(line[n + 2]) * unit, (float(line[n + 3]) - 1.0) * unit, z)
				var bar := _turned(face, (a + b) / 2.0, atan2(b.y - a.y, b.x - a.x))
				var half := a.distance_to(b) / 2.0 + thick / 2.0
				ModelKit.box(bar, Vector3(-half, -thick / 2.0, 0), Vector3(half, thick / 2.0, 0.014), mat, false)


## A low table of goods by the building (a rack's other style): two a row, a row more as the building fills,
## and one on the ground beside it when it is full.
static func _table(ctx: Dictionary, at: Vector3, goods: String, boards: Material) -> void:
	var root: Node3D = ctx["root"]
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var leg := at + Vector3(corner.x * (TABLE.x - 0.025), 0, corner.y * (TABLE.z - 0.025))
		ModelKit.box(root, leg + Vector3(-0.016, 0, -0.016), leg + Vector3(0.016, TABLE.y, 0.016), boards)
	ModelKit.box(root, at + Vector3(-TABLE.x, TABLE.y, -TABLE.z), at + Vector3(TABLE.x, TABLE.y + 0.022, TABLE.z),
		boards)
	for row in 3:
		for held in range(row + 1, FILLS):
			for n in 2:
				_good(when(ctx, "fill", held), at + Vector3((row - 1) * TABLE.x * 0.62, TABLE.y + 0.022,
					(n - 0.5) * TABLE.z * 0.9), goods, n + row)
	_good(when(ctx, "fill", FULL), at + Vector3(TABLE.x + 0.09, 0, TABLE.z * 0.4), goods, 1)


## One of the goods on a rack: a loaf, a bottle, a tray of eggs, a milk can, a pot of honey, a bundle of wool, a
## basket of truffles, a sack of oats, a crate of fruit or a basket of flowers.
static func _good(root: Node3D, at: Vector3, kind: String, n: int) -> void:
	if kind == "wool":
		# A bundle of fleece tied round the middle.
		for puff in 3:
			bead(root, at + Vector3((puff - 1) * 0.03, 0.04 + 0.012 * (puff % 2), 0), 0.04, ModelKit.paint(CREAM))
		ModelKit.box(root, at + Vector3(-0.006, 0, -0.045), at + Vector3(0.006, 0.085, 0.045), ModelKit.paint(BURLAP))
	elif kind in ["truffles", "crates", "baskets"]:
		# A little crate or basket, heaped with what was gathered.
		var basket := kind != "crates"
		ModelKit.box(root, at + Vector3(-0.055, 0, -0.045), at + Vector3(0.055, 0.05, 0.045),
			ModelKit.paint(BURLAP.darkened(0.15) if basket else WOOD.lightened(0.15)))
		var heap: Array[Color] = [Color("#4a3426"), Color("#5c4332"), Color("#3a281d")]
		if kind == "crates":
			heap = [Color("#d8402f"), Color("#e8b93c"), Color("#7fb23a")]
		elif kind == "baskets":
			heap = [Color("#ff7aa8"), Color("#ffd23f"), Color("#b388ff")]
		for k in 4:
			bead(root, at + Vector3(-0.026 + 0.052 * (k % 2), 0.066, -0.02 + 0.04 * (k / 2)), 0.026,
				ModelKit.paint(heap[(k + n) % heap.size()]))
	elif kind == "sacks":
		bead(root, at + Vector3(0, 0.055, 0), 0.055, ModelKit.paint(BURLAP.darkened(0.05 * (n % 2))), Vector3(0.9, 1.0,
			0.8))
		bead(root, at + Vector3(0, 0.115, 0), 0.018, ModelKit.paint(BURLAP.darkened(0.2)))
	elif kind == "eggs":
		# A straw tray with three eggs in it.
		ModelKit.box(root, at + Vector3(-0.055, 0, -0.04), at + Vector3(0.055, 0.02, 0.04), ModelKit.paint(HAY))
		for egg in 3:
			bead(root, at + Vector3((egg - 1) * 0.036, 0.04, 0.0), 0.022, ModelKit.paint(
				Color("#fbf3e0") if (egg + n) % 3 != 0 else Color("#d9a877")), Vector3(1.0, 1.3, 1.0))
	elif kind == "cans":
		var tin := ModelKit.paint(Color("#c5ccd1").darkened(0.06 * (n % 2)), 0.6)
		ModelKit.cylinder(root, at, 0.05, 0.13, tin, 0.05, 8)
		ModelKit.cylinder(root, at + Vector3(0, 0.13, 0), 0.05, 0.035, tin, 0.03, 8)
		ModelKit.cylinder(root, at + Vector3(0, 0.165, 0), 0.036, 0.018, tin, 0.04, 8)
	elif kind == "pots":
		ModelKit.cylinder(root, at, 0.042, 0.085, ModelKit.paint(Color("#e9a11b"), 0.7), 0.05, 8)
		ModelKit.cylinder(root, at + Vector3(0, 0.085, 0), 0.054, 0.022, ModelKit.paint(CREAM), 0.054, 8)
	elif kind == "bottles":
		var glass: Color = [Color("#3b9bb8"), Color("#e58fb0"), Color("#f3eee2")][n % 3]
		ModelKit.cylinder(root, at, 0.035, 0.09, ModelKit.paint(glass), 0.03, 6)
		bead(root, at + Vector3(0, 0.105, 0), 0.02, ModelKit.paint(DARK_WOOD))
	else:
		bead(root, at + Vector3(0, 0.04, 0), 0.06, ModelKit.paint(BAKED.darkened(0.08 * (n % 2))), Vector3(1.0, 0.7,
			0.8))


## Puts `part` at `at`, turning about its own upright (a `spin` part) while `moving`, still otherwise.
static func _turns(root: Node3D, at: Vector3, part: Node3D, moving: bool, speed: float) -> void:
	if moving:
		DecorMotion.spin(root, at, Vector3.ZERO, part, speed)
		return
	part.position = at
	part.rotation.y = 0.6
	root.add_child(part)


## The part of the building shown only in one state, as AssetRegistry names states (`when_working_true`,
## `when_fill_2`...): one node for each, shared by every feature. An animated part puts what moves in
## `when("working", true)` and what stands still in its place in `when("working", false)`; a storage part puts
## each of its looks in `when("fill", n)`. `BuildingModel.build` merges each into a mesh or two.
static func when(ctx: Dictionary, key: String, value: Variant) -> Node3D:
	var states: Dictionary = ctx.get("states", {})
	ctx["states"] = states
	var part := "%s%s_%s" % [AssetRegistry.STATE, key, str(value).to_lower()]
	if not states.has(part):
		var node := Node3D.new()
		node.name = part
		(ctx["root"] as Node3D).add_child(node)
		states[part] = node
	return states[part]


## The bar that turns a wine press's screw: a beam with a knob at each end.
static func _press_bar() -> Node3D:
	var bar := Node3D.new()
	ModelKit.box(bar, Vector3(-0.3, -0.02, -0.02), Vector3(0.3, 0.02, 0.02), ModelKit.paint(DARK_WOOD))
	for end: float in [-0.3, 0.3]:
		bead(bar, Vector3(end, 0, 0), 0.04, ModelKit.paint(WOOD.lightened(0.2)))
	return bar
