class_name MaterialModel
extends RefCounted
## The building parts (data/catalog/materials.json) as small 3D things, for their pictures (ItemIcons): each one
## is what it is, a stack of boards, a pile of bricks, a box of nails, so a row of parts reads at a glance.
## Modelled about a tile across, centred on (0.5, 0, 0.5) like everything the pictures draw.

const WOOD := Color("#b7834a")
const DARK_WOOD := Color("#7a5230")
const IRON := Color("#8a8f96")
const BRICK := Color("#b5533a")
const LEATHER := Color("#8a5a32")
const GLASS := Color("#7fc4b8")
const WOOL := Color("#d9584a")
const WAX := Color("#f0c24a")
const GREEN := Color("#5c9a3e")
const STONE := Color("#a9a39a")


## Part `id` as a baked model, or null for an id that isn't a part.
static func build(id: String) -> Node3D:
	var root := Node3D.new()
	var c := Vector3(0.5, 0, 0.5)
	match id:
		"boards":
			for k in 4:
				var y := 0.06 * k
				var turn := 0.06 if k % 2 == 0 else -0.06
				var plank := ModelKit.box(root, Vector3(-0.38, 0, -0.07), Vector3(0.38, 0.05, 0.07),
					ModelKit.surface(WOOD.darkened(0.06 * k), "boards", 0.2))
				plank.position = c + Vector3(0, y, (k - 1.5) * 0.04)
				plank.rotation.y = turn
		"bricks":
			for k in 6:
				var row := k / 3
				var x := (k % 3 - 1) * 0.22 + (0.11 if row == 1 else 0.0)
				if row == 1 and k % 3 == 2:
					continue
				ModelKit.box(root, c + Vector3(x - 0.1, row * 0.1, -0.12), c + Vector3(x + 0.1, row * 0.1 + 0.09, 0.12),
					ModelKit.paint(BRICK.lightened(0.05 * (k % 2))))
		"nails":
			ModelKit.box(root, c + Vector3(-0.22, 0, -0.16), c + Vector3(0.22, 0.14, 0.16), ModelKit.paint(DARK_WOOD))
			for k in 7:
				var at := c + Vector3(-0.15 + 0.05 * k, 0.14, -0.04 + 0.03 * (k % 3))
				var nail := ModelKit.cylinder(root, at, 0.012, 0.16, ModelKit.paint(IRON, 0.6))
				nail.rotation.z = 0.3 * ((k % 3) - 1)
				ModelKit.cylinder(root, at + Vector3(0, 0.16, 0), 0.028, 0.012, ModelKit.paint(IRON, 0.6))
		"harnesses":
			for k in 3:
				var strap := ModelKit.box(root, Vector3(-0.3, 0, -0.03), Vector3(0.3, 0.025, 0.03), ModelKit.paint(LEATHER))
				strap.position = c + Vector3(0, 0.025 * k, 0)
				strap.rotation.y = k * PI / 3.0
			ModelKit.cylinder(root, c + Vector3(0.2, 0.08, 0), 0.07, 0.02, ModelKit.paint(Color("#d9b24a"), 0.7))
		"horseshoes":
			for k in 2:
				var at := c + Vector3(-0.12 + 0.24 * k, 0.02 * k, 0)
				for p in 7:
					var a := PI * (p / 6.0)
					ModelKit.ball(root, at + Vector3(cos(a) * 0.12, 0.02, -sin(a) * 0.12 + 0.06), 0.03,
						ModelKit.paint(IRON, 0.5), Vector3(1.2, 0.6, 1.2))
		"bottles":
			for k in 3:
				var at := c + Vector3(-0.16 + 0.16 * k, 0, 0.04 * (k % 2))
				ModelKit.cylinder(root, at, 0.06, 0.24, ModelKit.paint(GLASS, 0.8), 0.06, 10)
				ModelKit.cylinder(root, at + Vector3(0, 0.24, 0), 0.06, 0.06, ModelKit.paint(GLASS, 0.8), 0.022, 10)
				ModelKit.cylinder(root, at + Vector3(0, 0.3, 0), 0.024, 0.05, ModelKit.paint(DARK_WOOD))
		"blankets":
			for k in 3:
				ModelKit.box(root, c + Vector3(-0.28, 0.07 * k, -0.2), c + Vector3(0.28, 0.07 * k + 0.065, 0.2),
					ModelKit.paint([WOOL, Color("#e8d6a8"), Color("#4f7fb0")][k]))
		"smokers":
			ModelKit.cylinder(root, c, 0.11, 0.26, ModelKit.paint(IRON, 0.5), 0.11, 12)
			ModelKit.cylinder(root, c + Vector3(0, 0.26, 0), 0.11, 0.08, ModelKit.paint(IRON.darkened(0.2), 0.5), 0.04, 12)
			ModelKit.box(root, c + Vector3(0.11, 0.04, -0.07), c + Vector3(0.3, 0.16, 0.07), ModelKit.paint(LEATHER))
		"beeswax":
			for k in 3:
				ModelKit.box(root, c + Vector3(-0.16 + 0.12 * (k % 2), 0.08 * k, -0.12),
					c + Vector3(0.12 + 0.12 * (k % 2), 0.08 * k + 0.075, 0.12), ModelKit.paint(WAX.darkened(0.06 * k), 0.3))
		"vehicle_parts":
			var cog := ModelKit.cylinder(root, c + Vector3(-0.08, 0, 0), 0.17, 0.06, ModelKit.paint(IRON, 0.6), 0.17, 12)
			cog.rotation.x = 0.0
			for t in 10:
				var a := TAU * t / 10.0
				ModelKit.box(root, c + Vector3(-0.08 + cos(a) * 0.19 - 0.025, 0, sin(a) * 0.19 - 0.025),
					c + Vector3(-0.08 + cos(a) * 0.19 + 0.025, 0.06, sin(a) * 0.19 + 0.025), ModelKit.paint(IRON, 0.6))
			ModelKit.cylinder(root, c + Vector3(0.2, 0, 0.1), 0.04, 0.22, ModelKit.paint(IRON.darkened(0.2), 0.6))
		"flower_ties":
			for k in 3:
				var bow := ModelKit.ball(root, c + Vector3(-0.15 + 0.15 * k, 0.05, 0.03 * k), 0.07,
					ModelKit.paint([Color("#e86aa0"), Color("#f2c84a"), Color("#8a6ae0")][k]), Vector3(1.8, 0.5, 0.8))
				bow.rotation.y = 0.4 * k
		"garden_edging":
			for k in 5:
				var x := -0.35 + 0.15 * k
				ModelKit.box(root, c + Vector3(x, 0, -0.04), c + Vector3(x + 0.12, 0.12 + 0.03 * (k % 2), 0.04),
					ModelKit.paint(STONE.lightened(0.04 * (k % 3))))
		"trellises":
			for k in 4:
				var slat := ModelKit.box(root, Vector3(-0.025, 0, -0.01), Vector3(0.025, 0.5, 0.01),
					ModelKit.paint(WOOD.lightened(0.15)))
				slat.position = c + Vector3(-0.15 + 0.1 * k, 0, 0)
				slat.rotation.z = 0.5 if k % 2 == 0 else -0.5
			ModelKit.ball(root, c + Vector3(0.1, 0.35, 0.02), 0.06, ModelKit.paint(GREEN))
		_:
			root.free()
			return null
	return ModelKit.bake(root)
