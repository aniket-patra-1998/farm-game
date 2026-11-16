class_name BuildingDress
extends RefCounted
## What makes a building a place and says what it is for (the storybook look, data/building_models.json
## `features`): the ground it stands on (a soft shade round its foot, a worn path to its door, grass, stones
## and flowers along its walls), a lantern by its door, and the things of its trade: a mill's turning sails,
## hopper and sacks, a bakery's brick oven, bread baskets and hanging sign, a winery's stacked barrels and
## vine-covered pergola, a barn's hay rack and milk cans, a coop's perch and feeder, a house's bench and
## woodpile. BuildingModel builds the block, roof, door and windows and calls this for the rest.

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
const TUFTS := 12             # tufts of grass along a building's walls..
const TUFT_STONES := 5        # ..and stones among them
const GOLDEN := 2.39996
## Every feature this dressing builds (`feature`); BuildingModel builds the rest.
const FEATURES: Array[String] = ["sacks", "crates", "barrel_stack", "windmill", "hopper", "oven", "bread",
	"hanging_sign", "pergola", "half_timber", "hay_rack", "milk_cans", "perch", "feeder", "bench", "woodpile"]

static var _shade: ShaderMaterial
static var _tuft: ArrayMesh


## The ground a building stands on: a soft shade round its foot (it sits on the earth), a worn path from its
## door to the edge of its plot when it has no yard, and tufts of grass, stones and a few flowers along the
## walls the camera sees.
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
		# The path: trodden earth widening from the door, with a few flat stones set in it.
		var reach := fd - hi.z - 0.06
		var w := float(door.get("w", 0.28)) * float(ctx["bw"]) / 0.7 + 0.1
		ModelKit.ball(root, Vector3(x, 0.0, hi.z + reach * 0.5), reach * 0.52, ModelKit.surface(PATH, "plaster", 0.0),
			Vector3(w / reach * 1.25, 0.03, 1.0))
		for k in 4:
			ModelKit.cylinder(root, Vector3(x + (0.05 if k % 2 == 0 else -0.06), 0.012,
				hi.z + 0.16 + reach * 0.2 * k),
				0.07, 0.012, ModelKit.surface(STONE.lightened(0.08 * (k % 2)), "plaster", 0.0), 0.06, 7)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str((ctx["it"] as Dictionary).get("id", ""))) + int(ctx["bw"] * 100.0)
	if lo.y > 0.0:
		return   # (on stilts: nothing grows against it)
	var half_door := float(door.get("w", 0.28)) * float(ctx["bw"]) / 0.7 / 2.0 + 0.08
	for k in TUFTS:
		# Along the front wall (+z) and the side wall (+x), the two the camera sees; never across the doorway.
		var front := k % 2 == 0
		var t := rng.randf()
		var out := rng.randf_range(0.05, 0.13)
		var at := Vector3(lerpf(lo.x, hi.x, t), 0, hi.z + out) if front else Vector3(hi.x + out, 0, lerpf(lo.z, hi.z,
			t))
		if (front and absf(at.x - x) < half_door) or at.x > fw - 0.04 or at.z > fd - 0.04:
			continue
		if k < TUFT_STONES * 2 and k % 4 == 1:
			stone(root, at, rng.randf_range(0.04, 0.065), STONE.darkened(rng.randf() * 0.15))
			continue
		tuft(root, at, rng.randf_range(0.08, 0.14), Color("#5aa63a").darkened(rng.randf() * 0.2), rng.randf() * TAU)
		if k % 5 == 0:
			var petal: Color = [Color("#ff7aa8"), Color("#ffd23f"), Color("#ffffff"), Color("#b388ff")][k % 4]
			bead(root, at + Vector3(0.02, 0.1, 0.02), 0.026, ModelKit.paint(petal))


## A tuft of grass `h` high at `at`: three blades from one small shared mesh (nine triangles).
static func tuft(root: Node3D, at: Vector3, h: float, col: Color, turn: float) -> void:
	if _tuft == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for blade in 3:
			var a := TAU * blade / 3.0
			var foot := Vector3(cos(a), 0, sin(a)) * 0.12
			var tip := Vector3(cos(a) * 0.3, 1.0, sin(a) * 0.3)
			var side := Vector3(-sin(a), 0, cos(a)) * 0.13
			for tri: Array in [[foot - side, foot + side, tip], [foot + side, foot * 0.2, tip], [foot * 0.2,
				foot - side, tip]]:
				var n := ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3)).normalized()
				for v: Vector3 in [tri[0], tri[2], tri[1]]:
					st.set_normal(-n)
					st.add_vertex(v)
		_tuft = st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _tuft
	mi.material_override = ModelKit.paint(col)
	mi.transform = Transform3D(Basis(Vector3.UP, turn).scaled(Vector3(h, h, h)), at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## A stone on the ground: a low five-sided lump.
static func stone(root: Node3D, at: Vector3, r: float, col: Color) -> void:
	ModelKit.cylinder(root, at, r, r * 0.7, ModelKit.surface(col, "plaster", 0.2), r * 0.6, 5).cast_shadow \
		= GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # (too small for its shadow to show: half the cost)


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


## A lantern on the wall at `at` (the point it hangs from), facing out along `out`: an iron bracket and cage
## round glass that glows warm at night (the windows' own glass).
static func lantern(root: Node3D, at: Vector3, out: Vector3) -> void:
	var iron := ModelKit.paint(IRON, 0.3)
	var hang := at + out * 0.07
	ModelKit.box(root, Vector3(minf(at.x, hang.x) - 0.008, at.y, minf(at.z, hang.z) - 0.008),
		Vector3(maxf(at.x, hang.x) + 0.008, at.y + 0.014, maxf(at.z, hang.z) + 0.008), iron)
	ModelKit.box(root, hang + Vector3(-0.034, -0.03, -0.034), hang + Vector3(0.034, -0.015, 0.034), iron)
	ModelKit.box(root, hang + Vector3(-0.026, -0.1, -0.026), hang + Vector3(0.026, -0.03, 0.026), ModelKit.glass())
	ModelKit.box(root, hang + Vector3(-0.034, -0.115, -0.034), hang + Vector3(0.034, -0.1, 0.034), iron)
	ModelKit.cylinder(root, hang + Vector3(0, -0.015, 0), 0.03, 0.03, iron, 0.004, 4)


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
		"barrel_stack":
			# Barrels on their sides against the side wall: two below and one on top, a tap on the nearest.
			var x := minf(hi.x + 0.17, fw - 0.17)
			var z0 := float(f.get("z", 0.5)) * (hi.z - lo.z) + lo.z
			for k in 3:
				var p := Vector3(x, 0.13 + (0.2 if k == 2 else 0.0), z0 + (0.13 if k == 2 else 0.26 * k))
				var barrel := ModelKit.cylinder(root, Vector3.ZERO, 0.12, 0.28, ModelKit.surface(Color("#7c4a2a"),
					"boards", 0.2),
					-1.0, 10)
				barrel.rotation.z = PI / 2.0
				barrel.position = p
				for hoop: float in [-0.09, 0.09]:
					var band := ModelKit.cylinder(root, Vector3.ZERO, 0.125, 0.022, ModelKit.paint(IRON, 0.4), -1.0,
						10)
					band.rotation.z = PI / 2.0
					band.position = p + Vector3(hoop, 0, 0)
				ModelKit.cylinder(root, p + Vector3(0.14, -0.012, 0), 0.03, 0.024, ModelKit.paint(Color("#4a2a1a")),
					-1.0, 8) \
					.rotation.z = PI / 2.0
			for chock: float in [-0.1, 0.36]:
				ModelKit.box(root, Vector3(x - 0.1, 0, z0 + chock - 0.02), Vector3(x + 0.1, 0.04, z0 + chock + 0.02),
					ModelKit.paint(DARK_WOOD))
		"windmill":
			_windmill(ctx, f)
		"hopper":
			# A grain hopper on legs with a sack under its spout, fed by a chute from high on the mill's wall.
			var legs := ModelKit.paint(DARK_WOOD)
			for corner: Vector2 in [Vector2(-0.14, -0.14), Vector2(0.14, -0.14), Vector2(0.14, 0.14), Vector2(-0.14,
				0.14)]:
				ModelKit.box(root, at + Vector3(corner.x - 0.018, 0, corner.y - 0.018),
					at + Vector3(corner.x + 0.018, 0.46, corner.y + 0.018), legs)
			ModelKit.cylinder(root, at + Vector3(0, 0.26, 0), 0.045, 0.2, ModelKit.surface(Color("#c9a56a"), "boards",
				0.1), 0.2, 4) \
				.rotation.y = PI / 4.0
			ModelKit.box(root, at + Vector3(-0.16, 0.44, -0.16), at + Vector3(0.16, 0.5, 0.16),
				ModelKit.surface(Color("#c9a56a"), "boards", 0.1))
			ModelKit.ball(root, at + Vector3(0, 0.5, 0), 0.13, ModelKit.paint(Color("#e8c96a")), Vector3(1, 0.45, 1))
			ModelKit.ball(root, at + Vector3(0, 0.07, 0), 0.09, ModelKit.paint(BURLAP), Vector3(1, 0.75, 1), true)
			var from := Vector3(hi.x, hi.y * 0.9, clampf(at.z, lo.z + 0.1, hi.z - 0.1))
			var to := at + Vector3(0, 0.52, 0)
			var chute := ModelKit.box(root, Vector3(-0.035, -0.03, -from.distance_to(to) / 2.0),
				Vector3(0.035, 0.03, from.distance_to(to) / 2.0), ModelKit.surface(WOOD, "boards", 0.0))
			chute.transform = Transform3D(Basis.looking_at((to - from).normalized(), Vector3.UP), (from + to) / 2.0)
		"oven":
			_oven(ctx, f)
		"bread":
			# Baskets of bread by the door: round loaves and a sheaf of long ones standing in a crock.
			var side := float(f.get("side", 1.0))
			var x := (lo.x + hi.x) / 2.0 + side * (hi.x - lo.x) * 0.36
			var p := Vector3(x, 0, hi.z + 0.16)
			ModelKit.cylinder(root, p, 0.1, 0.09, ModelKit.surface(Color("#b98b4a"), "logs", 0.2), 0.13, 10)
			for k in 5:
				ModelKit.ball(root, p + Vector3(cos(k * GOLDEN) * 0.05, 0.1 + 0.02 * (k % 2), sin(k * GOLDEN) * 0.05),
					0.045,
					ModelKit.paint(BAKED.lightened(0.06 * (k % 3))), Vector3(1.2, 0.8, 1.0))
			var crock := p + Vector3(-side * 0.2, 0, 0.04)
			ModelKit.cylinder(root, crock, 0.055, 0.12, ModelKit.paint(Color("#8f6a4a"), 0.3), 0.065, 8)
			for k in 4:
				var loaf := bead(root, crock + Vector3(0.02 * (k - 1.5), 0.2, 0.012 * (k % 2)), 0.028,
					ModelKit.paint(BAKED.lightened(0.1)), Vector3(1.0, 4.4, 1.0))
				loaf.rotation.z = 0.12 * (k - 1.5)
		"hanging_sign":
			_hanging_sign(ctx, f)
		"pergola":
			_pergola(ctx, f)
		"half_timber":
			# Dark timbers on the plaster: posts, a rail, and braces leaning from the corners, on the two walls the
			# camera sees.
			var beam := ModelKit.paint(Color.html(str(f.get("color", "#5a3a24"))))
			var y0 := lo.y + BuildingModel.PLINTH
			var mid := lerpf(y0, hi.y, 0.52)
			for wall in 2:
				var a := Vector3(lo.x, 0, hi.z) if wall == 0 else Vector3(hi.x, 0, lo.z)
				var b := Vector3(hi.x, 0, hi.z) if wall == 0 else Vector3(hi.x, 0, hi.z)
				var out := Vector3(0, 0, 1) if wall == 0 else Vector3(1, 0, 0)
				var run := (b - a).normalized()
				var length := a.distance_to(b)
				_timber(root, a + Vector3(0, mid, 0), b + Vector3(0, mid, 0), out, beam)
				for share: float in [0.24, 0.76]:
					var foot := a + run * length * share
					_timber(root, foot + Vector3(0, y0, 0), foot + Vector3(0, hi.y, 0), out, beam)
				for end: float in [0.0, 1.0]:
					var corner := a + run * length * end
					var inward := run * (1.0 if end == 0.0 else -1.0)
					_timber(root, corner + inward * 0.05 + Vector3(0, mid, 0), corner + inward * length * 0.22
						+ Vector3(0, hi.y - 0.06, 0), out, beam)
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


## A mill's sails, turning: four lattice arms with their cloths on a hub high on the gable the camera sees
## (the front, or the side when the ridge runs across), on a shaft through the wall. Turned by the GPU
## (DecorMotion.orbit): no script, one draw.
static func _windmill(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var top: float = ctx.get("top", hi.y)
	var front := (hi.x - lo.x) <= (hi.z - lo.z)   # (the gable faces the front when the ridge runs front to back)
	var reach := float(f.get("reach", 0.62))
	var y := hi.y + (top - hi.y) * float(f.get("up", 0.3))
	var hub := Vector3((lo.x + hi.x) / 2.0, y, hi.z + 0.1) if front else Vector3(hi.x + 0.1, y, (lo.z + hi.z) / 2.0)
	var shaft := ModelKit.cylinder(root, Vector3.ZERO, 0.035, 0.16, ModelKit.paint(DARK_WOOD), -1.0, 8)
	shaft.position = hub - (Vector3(0, 0, 0.06) if front else Vector3(0.06, 0, 0))
	shaft.rotation = Vector3(PI / 2.0, 0, 0) if front else Vector3(0, 0, PI / 2.0)
	# Built to turn about its own y (the orbit shader's axis), then laid over so that axis points out of the wall.
	var sails := Node3D.new()
	ModelKit.cylinder(sails, Vector3(0, -0.03, 0), 0.06, 0.07, ModelKit.paint(DARK_WOOD.darkened(0.2)), 0.045, 8)
	for k in 4:
		var arm := Node3D.new()
		arm.rotation.y = TAU * k / 4.0
		sails.add_child(arm)
		ModelKit.box(arm, Vector3(0.03, -0.012, -0.014), Vector3(reach, 0.012, 0.014), ModelKit.paint(DARK_WOOD))
		ModelKit.box(arm, Vector3(reach * 0.24, -0.006, 0.014), Vector3(reach * 0.98, 0.006, 0.014 + reach * 0.24),
			ModelKit.paint(Color.html(str(f.get("cloth", "#f3ead2")))))
		for slat in 4:
			var at_x := lerpf(reach * 0.24, reach * 0.98, slat / 3.0)
			ModelKit.box(arm, Vector3(at_x - 0.008, -0.01, 0.014), Vector3(at_x + 0.008, 0.01, 0.014 + reach * 0.24),
				ModelKit.paint(DARK_WOOD.lightened(0.1)))
		ModelKit.box(arm, Vector3(reach * 0.24, -0.01, 0.014 + reach * 0.24 - 0.008),
			Vector3(reach * 0.98, 0.01, 0.014 + reach * 0.24 + 0.008), ModelKit.paint(DARK_WOOD.lightened(0.1)))
	var turning := DecorMotion.orbit(root, hub, sails, {"speed": float(f.get("speed", 0.55)), "radius": 0.0})
	turning.rotation = Vector3(PI / 2.0, 0, 0) if front else Vector3(0, 0, -PI / 2.0)
	for part in turning.get_children():
		if part is MeshInstance3D:
			(part as MeshInstance3D).custom_aabb = AABB(Vector3(-reach, -0.2, -reach), Vector3(reach * 2.0, 0.4,
				reach * 2.0))


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


## A sign hanging from an iron bracket over the door: a board with the emblem of the trade (`icon`: loaf,
## grapes, wheat, drop).
static func _hanging_sign(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var x := (lo.x + hi.x) / 2.0 + float(f.get("shift", -0.32)) * (hi.x - lo.x)
	var y := lo.y + (hi.y - lo.y) * float(f.get("up", 0.78))
	var iron := ModelKit.paint(IRON, 0.3)
	ModelKit.box(root, Vector3(x - 0.01, y, hi.z), Vector3(x + 0.01, y + 0.015, hi.z + 0.26), iron)
	ModelKit.box(root, Vector3(x - 0.008, y - 0.1, hi.z), Vector3(x + 0.008, y, hi.z + 0.012), iron)
	var board := Vector3(x, y - 0.14, hi.z + 0.16)
	ModelKit.box(root, board + Vector3(-0.014, -0.1, -0.11), board + Vector3(0.014, 0.1, 0.11),
		ModelKit.paint(Color.html(str(f.get("color", "#f3e6c4")))))
	ModelKit.box(root, board + Vector3(-0.018, 0.1, -0.12), board + Vector3(0.018, 0.115, 0.12),
		ModelKit.paint(DARK_WOOD))
	ModelKit.box(root, board + Vector3(-0.018, -0.115, -0.12), board + Vector3(0.018, -0.1, 0.12),
		ModelKit.paint(DARK_WOOD))
	for chain: float in [-0.08, 0.08]:
		ModelKit.box(root, board + Vector3(-0.004, 0.115, chain - 0.004), Vector3(x + 0.004, y,
			board.z + chain + 0.004), iron)
	for face: float in [-1.0, 1.0]:   # (the emblem, on both faces)
		var e := board + Vector3(face * 0.018, 0, 0)
		match str(f.get("icon", "loaf")):
			"grapes":
				for k in 6:
					bead(root, e + Vector3(0, 0.03 - 0.03 * (k / 3) - (0.03 if k == 5 else 0.0),
						-0.03 + 0.03 * (k % 3)
						+ (0.015 if k >= 3 else 0.0)), 0.022, ModelKit.paint(Color("#6a3a8f"), 0.4), Vector3(0.5, 1, 1))
				ModelKit.ball(root, e + Vector3(0, 0.07, 0.01), 0.03, ModelKit.paint(LEAF), Vector3(0.4, 0.6, 1.2))
			"wheat":
				for k in 5:
					bead(root, e + Vector3(0, -0.05 + 0.028 * k, 0.012 * (k % 2 * 2 - 1)), 0.02,
						ModelKit.paint(Color("#e2b23a")), Vector3(0.5, 1.3, 0.8))
			"drop":
				ModelKit.ball(root, e, 0.045, ModelKit.paint(Color("#6fc3d9"), 0.5), Vector3(0.4, 1.25, 1.0))
			_:
				ModelKit.ball(root, e, 0.06, ModelKit.paint(BAKED), Vector3(0.4, 0.75, 1.3), true)


## A pergola over the yard beside the building, grown over with vines: posts and beams, a roof of leaves, and
## bunches of grapes hanging under it.
static func _pergola(ctx: Dictionary, f: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var lo: Vector3 = ctx["lo"]
	var hi: Vector3 = ctx["hi"]
	var fw: float = ctx["fw"]
	var x0 := hi.x + 0.04
	var x1 := minf(hi.x + float(f.get("depth", 0.46)), fw - 0.1)
	var z0 := lerpf(lo.z, hi.z, float(f.get("from", 0.3)))
	var z1 := hi.z - 0.04
	var h := float(f.get("h", 0.62))
	var post := ModelKit.paint(DARK_WOOD)
	for z: float in [z0, z1]:
		ModelKit.box(root, Vector3(x1 - 0.025, 0, z - 0.025), Vector3(x1 + 0.025, h, z + 0.025), post)
		ModelKit.box(root, Vector3(x0, h - 0.03, z - 0.02), Vector3(x1 + 0.06, h, z + 0.02), post)
	for k in 4:
		var x := lerpf(x0 + 0.04, x1, k / 3.0)
		ModelKit.box(root, Vector3(x - 0.014, h, z0 - 0.06), Vector3(x + 0.014, h + 0.025, z1 + 0.06), post)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var grape := Color.html(str(f.get("color", "#6a3a8f")))
	for k in 16:
		var p := Vector3(rng.randf_range(x0 + 0.03, x1 + 0.03), h + 0.03, rng.randf_range(z0 - 0.04, z1 + 0.04))
		bead(root, p, rng.randf_range(0.07, 0.11), ModelKit.paint(LEAF.darkened(rng.randf() * 0.25)),
			Vector3(1.2, 0.45, 1.1))
		if k % 3 == 0:
			for b in 5:
				bead(root, p + Vector3(0.02 * (b % 2), -0.06 - 0.03 * (b / 2), 0.02 * ((b + 1) % 2)), 0.026,
					ModelKit.paint(grape.darkened(0.1 * (b % 2)), 0.4))
	# The vine itself, climbing the outer post.
	var stem := ModelKit.cylinder(root, Vector3(x1 + 0.03, 0, z1), 0.016, h, ModelKit.paint(Color("#6a4a2a")), 0.01,
		5)
	stem.rotation.x = 0.06


## A timber on a wall from `a` to `b` (points on the wall's foot line, with heights), standing proud of it
## along `out`.
static func _timber(root: Node3D, a: Vector3, b: Vector3, out: Vector3, mat: Material) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var beam := ModelKit.box(root, Vector3(-0.022, -0.008, -length / 2.0), Vector3(0.022, 0.008, length / 2.0), mat)
	beam.transform = Transform3D(Basis.looking_at((b - a) / length, out), (a + b) / 2.0 + out * 0.008)
