class_name DecorModel
extends RefCounted
## Every decoration in 3D, by id: paths, fences, hedges and walls that join up with their neighbours'
## lines, hay, a scarecrow, a well, a fountain, a gazebo, gnomes, flamingos... The farmhouse and log cabin
## are buildings (BuildingModel); the countryside trees share TreeModel and the pine. The node's origin is
## the footprint's back corner; `o` is the placed object (a mastery sign's crop, a bunch's flower).

const WOOD := Color("#a8743f")
const DARK_WOOD := Color("#6e4a2a")
const STONE := Color("#9aa4ad")
const WHITE := Color("#f4efe4")
const HAY := Color("#e3c46a")
const LEAF := Color("#3c8a2e")
## Every decoration with a model here (tests check the catalog's decorations against it).
const IDS := ["farmhouse", "log_cabin", "dirt_path", "brick_path", "stone_path", "wooden_fence", "white_picket_fence",
	"tall_wooden_fence", "wooden_gate", "hedge", "stone_wall", "hay_bale", "haystack", "scarecrow", "water_trough",
	"bonfire", "wheelbarrow",
	"water_well", "flower_bed", "pink_flamingo", "bench", "birdhouse", "birdbath", "picnic_table", "garden_gnome",
	"lamp_post", "sundial", "small_pond", "fountain", "arbor", "wooden_bridge", "gazebo", "pine_tree", "oak_tree",
	"maple_tree", "willow_tree", "mastery_sign", "mailbox", "farm_stand", "perfect_bunch"]



const WATER_LIFT := 0.012   # water stands this far above the rim it fills, never level with it (flicker)
## Decorations that bend in the wind, and how much (paint3d sway, by height above their foot).
const SWAY_BY_ID := {"scarecrow": 0.08, "flower_bed": 0.6, "arbor": 0.02,
	"perfect_bunch": 0.5, "haystack": 0.015}
static var _glows := {}   # colour -> glowing material




static func build(it: Dictionary, fp: Vector2i, o: Dictionary) -> Node3D:
	var id := str(it.get("id", ""))
	if id in ["farmhouse", "log_cabin"]:
		return ModelKit.bake(BuildingModel.build(it, fp))
	if Game.links.group_of(id) != "":
		# Fences, hedges, walls and paths are drawn joined up by the LinkLayer; alone (a sheet, a size guide)
		# one is a straight piece.
		var piece := Node3D.new()
		piece.position = Vector3(0.5, 0, 0.5)
		piece.add_child(LinkModels.node(it, LinkShape.Kind.STRAIGHT, 0))
		var alone := Node3D.new()
		alone.add_child(piece)
		return ModelKit.bake(alone)
	var root := Node3D.new()
	var c := Vector3(fp.x / 2.0, 0, fp.y / 2.0)
	var col := Color.html(str(it.get("color", "#a8743f")))
	match id:
		"hay_bale":
			var bale := ModelKit.cylinder(root, Vector3.ZERO, 0.2, 0.36, ModelKit.paint(HAY), -1.0, 14)
			bale.rotation.x = PI / 2.0
			bale.position = c + Vector3(0, 0.2, 0)
			for z: float in [-0.08, 0.08]:
				var band := ModelKit.cylinder(
					root,
					Vector3.ZERO,
					0.205,
					0.02,
					ModelKit.paint(Color("#a8743f")),
					-1.0,
					14
				)
				band.rotation.x = PI / 2.0
				band.position = c + Vector3(0, 0.2, z)
		"haystack":
			# A rounded stack on the ground: a wide skirt, a domed top, and the pole it's built round.
			ModelKit.cylinder(root, c, 0.38, 0.24, ModelKit.paint(HAY.darkened(0.06)), 0.33, 14)
			ModelKit.ball(root, c + Vector3(0, 0.24, 0), 0.33, ModelKit.paint(HAY), Vector3(1, 0.95, 1))
			ModelKit.cylinder(root, c + Vector3(0, 0.5, 0), 0.015, 0.16, ModelKit.paint(DARK_WOOD))
		"scarecrow":
			ModelKit.box(root, c + Vector3(-0.02, 0, -0.02), c + Vector3(0.02, 0.7, 0.02), ModelKit.paint(DARK_WOOD))
			ModelKit.box(
				root,
				c + Vector3(-0.02, 0.45, -0.25),
				c + Vector3(0.02, 0.49, 0.25),
				ModelKit.paint(DARK_WOOD)
			)
			ModelKit.box(
				root,
				c + Vector3(-0.07, 0.3, -0.12),
				c + Vector3(0.07, 0.52, 0.12),
				ModelKit.paint(Color("#4a6fa5"))
			)
			ModelKit.ball(root, c + Vector3(0, 0.6, 0), 0.08, ModelKit.paint(Color("#e8cf9a")))
			ModelKit.cylinder(root, c + Vector3(0, 0.66, 0), 0.14, 0.02, ModelKit.paint(col))
			ModelKit.cylinder(root, c + Vector3(0, 0.68, 0), 0.07, 0.08, ModelKit.paint(col), 0.05)
			for side: float in [-1.0, 1.0]:
				ModelKit.ball(root, c + Vector3(0, 0.47, side * 0.27), 0.04, ModelKit.paint(HAY), Vector3(1, 0.6, 1.6))
		"water_trough":
			ModelKit.tub(root, c + Vector3(-0.32, 0, -0.14), c + Vector3(0.32, 0.18, 0.14), 0.03,
				ModelKit.surface(col, "boards", 0.2), ModelKit.water())
		"bonfire":
			for k in 8:
				var a := TAU * k / 8.0
				ModelKit.ball(root, c + Vector3(cos(a) * 0.22, 0.04, sin(a) * 0.22), 0.06, ModelKit.paint(STONE))
			for k in 4:
				var log_piece := ModelKit.cylinder(root, Vector3.ZERO, 0.03, 0.34, ModelKit.paint(DARK_WOOD), -1.0, 6)
				log_piece.position = c + Vector3(0, 0.08, 0)
				log_piece.rotation = Vector3(0, TAU * k / 4.0, PI / 2.0 - 0.5)
			# Tongues of flame licking up from the logs, embers floating off them.
			ModelKit.ball(root, c + Vector3(0, 0.08, 0), 0.08, _glow(Color("#ff6a1f")), Vector3(1, 0.5, 1))
			DecorMotion.flame(root, c + Vector3(0, 0.06, 0), 0.08, 0.26, Color("#ff6a1f"), Color("#ffd35a"))
			for k in 3:
				var a := TAU * k / 3.0 + 0.4
				DecorMotion.flame(root, c + Vector3(cos(a) * 0.06, 0.05, sin(a) * 0.06), 0.045, 0.15,
					Color("#ff7a26"), Color("#ffe07a"))
			DecorMotion.spray(root, c + Vector3(0, 0.18, 0), DecorMotion.EMBERS)
		"wheelbarrow":
			ModelKit.box(root, c + Vector3(-0.15, 0.12, -0.12), c + Vector3(0.15, 0.26, 0.12), ModelKit.paint(col, 0.5))
			ModelKit.ball(root, c + Vector3(0, 0.27, 0), 0.11, ModelKit.paint(Color("#5e3d24")), Vector3(1.2, 0.3, 1))
			var wheel := ModelKit.cylinder(root, Vector3.ZERO, 0.07, 0.03, ModelKit.paint(Color("#2a2a2a")), -1.0, 12)
			wheel.rotation.x = PI / 2.0
			wheel.position = c + Vector3(0.2, 0.07, 0)
			for z: float in [-0.08, 0.08]:
				ModelKit.box(
					root,
					c + Vector3(-0.38, 0.17, z - 0.012),
					c + Vector3(0.2, 0.19, z + 0.012),
					ModelKit.paint(WOOD)
				)
		"water_well":
			ModelKit.cylinder(root, c, 0.28, 0.3, ModelKit.surface(STONE, "stone", 0.3), -1.0, 16)
			ModelKit.cylinder(root, c + Vector3(0, 0.3, 0), 0.22, WATER_LIFT, ModelKit.water(), -1.0, 16)
			# A bucket hanging over the water, bobbing on its rope.
			var bucket := Node3D.new()
			ModelKit.cylinder(bucket, Vector3.ZERO, 0.06, 0.08, ModelKit.paint(WOOD), 0.07, 10)
			ModelKit.box(bucket, Vector3(-0.003, 0.08, -0.003), Vector3(0.003, 0.3, 0.003), ModelKit.paint(Color("#c9b38a")))
			DecorMotion.orbit(root, c + Vector3(0, 0.36, 0), bucket, DecorMotion.BOBBING)
			for z: float in [-0.25, 0.25]:
				ModelKit.box(
					root,
					c + Vector3(-0.02, 0.3, z - 0.02),
					c + Vector3(0.02, 0.75, z + 0.02),
					ModelKit.paint(WOOD)
				)
			ModelKit.roof(root, "gable", c + Vector3(-0.2, 0.75, -0.32), c + Vector3(0.2, 0.75, 0.32), 0.16, 0.03,
				ModelKit.surface(Color("#8e3b2c"), "shingles", 0.0), ModelKit.paint(WOOD))
			var axle := ModelKit.cylinder(root, Vector3.ZERO, 0.02, 0.5, ModelKit.paint(DARK_WOOD), -1.0, 6)
			axle.rotation.x = PI / 2.0
			axle.position = c + Vector3(0, 0.6, 0)
			ModelKit.cylinder(root, c + Vector3(0, 0.38, 0), 0.05, 0.08, ModelKit.paint(Color("#7c4a2a")), -1.0, 8)
		"flower_bed":
			ModelKit.box(
				root,
				c + Vector3(-0.38, 0, -0.38),
				c + Vector3(0.38, 0.06, 0.38),
				ModelKit.paint(Color("#6b4a2e"))
			)
			var rng := _rng(id)
			var petals := [col, Color("#ffd23f"), Color("#ffffff"), Color("#b388ff")]
			for k in 18:
				var p := c + Vector3(rng.randf_range(-0.32, 0.32), 0.06, rng.randf_range(-0.32, 0.32))
				ModelKit.cylinder(root, p, 0.007, 0.1, ModelKit.paint(Color("#4f8a2f")), -1.0, 4)
				ModelKit.ball(root, p + Vector3(0, 0.11, 0), 0.035, ModelKit.paint(petals[k % 4]))
		"pink_flamingo":
			for z: float in [-0.02, 0.02]:
				ModelKit.box(
					root,
					c + Vector3(-0.005, 0, z - 0.005),
					c + Vector3(0.005, 0.28, z + 0.005),
					ModelKit.paint(Color("#333333"))
				)
			ModelKit.ball(root, c + Vector3(-0.03, 0.34, 0), 0.08, ModelKit.paint(col), Vector3(1.4, 0.9, 0.8))
			var neck := ModelKit.cylinder(root, Vector3.ZERO, 0.015, 0.2, ModelKit.paint(col), -1.0, 6)
			neck.position = c + Vector3(0.05, 0.46, 0)
			neck.rotation.z = -0.3
			ModelKit.ball(root, c + Vector3(0.08, 0.56, 0), 0.035, ModelKit.paint(col))
			var beak := ModelKit.cylinder(root, Vector3.ZERO, 0.012, 0.06, ModelKit.paint(Color("#222222")), 0.0, 6)
			beak.position = c + Vector3(0.12, 0.54, 0)
			beak.rotation.z = -2.2
		"bench":
			ModelKit.box(
				root,
				c + Vector3(-0.1, 0.16, -0.32),
				c + Vector3(0.1, 0.19, 0.32),
				ModelKit.surface(col, "boards", 0.0)
			)
			ModelKit.box(
				root,
				c + Vector3(-0.12, 0.19, -0.32),
				c + Vector3(-0.09, 0.38, 0.32),
				ModelKit.surface(col, "boards", 0.0)
			)
			for z: float in [-0.28, 0.28]:
				ModelKit.box(
					root,
					c + Vector3(-0.09, 0, z - 0.015),
					c + Vector3(0.09, 0.16, z + 0.015),
					ModelKit.paint(Color("#333333"), 0.4)
				)
		"birdhouse":
			ModelKit.box(root, c + Vector3(-0.015, 0, -0.015), c + Vector3(0.015, 0.55, 0.015), ModelKit.paint(WOOD))
			ModelKit.box(
				root,
				c + Vector3(-0.08, 0.55, -0.08),
				c + Vector3(0.08, 0.72, 0.08),
				ModelKit.surface(WHITE, "boards")
			)
			ModelKit.roof(root, "gable", c + Vector3(-0.08, 0.55, -0.08), c + Vector3(0.08, 0.72, 0.08), 0.07, 0.02,
				ModelKit.paint(col), ModelKit.surface(WHITE, "boards"))
			ModelKit.cylinder(root, c + Vector3(0.081, 0.63, 0), 0.025, 0.005, ModelKit.paint(Color("#222222")))
			# Its bird, circling the house.
			DecorMotion.orbit(root, c + Vector3(0, 0.82, 0), DecorMotion.bird(Color("#6f8fc9")), DecorMotion.CIRCLING)
		"birdbath":
			ModelKit.cylinder(root, c, 0.1, 0.05, ModelKit.paint(col), -1.0, 12)
			ModelKit.cylinder(root, c + Vector3(0, 0.05, 0), 0.04, 0.25, ModelKit.paint(col), 0.05, 10)
			ModelKit.cylinder(root, c + Vector3(0, 0.3, 0), 0.08, 0.06, ModelKit.paint(col), 0.2, 16)
			# Water filling the bowl to its brim (the bowl is solid: the water sits on it, never inside it).
			ModelKit.cylinder(root, c + Vector3(0, 0.36, 0), 0.185, WATER_LIFT, ModelKit.water(), -1.0, 16)
		"picnic_table":
			ModelKit.box(
				root,
				c + Vector3(-0.3, 0.3, -0.18),
				c + Vector3(0.3, 0.33, 0.18),
				ModelKit.surface(col, "boards", 0.0)
			)
			for z: float in [-0.3, 0.3]:
				ModelKit.box(
					root,
					c + Vector3(-0.3, 0.17, z - 0.06),
					c + Vector3(0.3, 0.2, z + 0.06),
					ModelKit.surface(col, "boards", 0.0)
				)
			for x: float in [-0.25, 0.25]:
				ModelKit.box(
					root,
					c + Vector3(x - 0.02, 0, -0.32),
					c + Vector3(x + 0.02, 0.3, 0.32),
					ModelKit.paint(col.darkened(0.2))
				)
		"garden_gnome":
			ModelKit.ball(root, c + Vector3(0, 0.1, 0), 0.08, ModelKit.paint(Color("#3f6fb5")), Vector3(1, 1.2, 1))
			ModelKit.ball(root, c + Vector3(0, 0.22, 0), 0.06, ModelKit.paint(Color("#f2c9a0")))
			ModelKit.ball(root, c + Vector3(0.04, 0.18, 0), 0.05, ModelKit.paint(WHITE), Vector3(0.8, 1.2, 1))
			ModelKit.cylinder(root, c + Vector3(0, 0.26, 0), 0.065, 0.16, ModelKit.paint(col), 0.0, 10)
		"lamp_post":
			ModelKit.cylinder(root, c, 0.05, 0.05, ModelKit.paint(col, 0.5), -1.0, 8)
			ModelKit.cylinder(root, c, 0.022, 0.75, ModelKit.paint(col, 0.5), 0.016, 8)
			ModelKit.box(root, c + Vector3(-0.06, 0.75, -0.06), c + Vector3(0.06, 0.88, 0.06), ModelKit.glass())
			ModelKit.cylinder(root, c + Vector3(0, 0.88, 0), 0.09, 0.06, ModelKit.paint(col, 0.5), 0.0, 4)
		"sundial":
			ModelKit.cylinder(root, c, 0.12, 0.3, ModelKit.surface(STONE, "stone", 0.2), 0.09, 10)
			ModelKit.cylinder(root, c + Vector3(0, 0.3, 0), 0.16, 0.03, ModelKit.paint(col, 0.4), -1.0, 16)
			var gnomon := ModelKit.box(
				root,
				Vector3(-0.08, 0, -0.005),
				Vector3(0.08, 0.08, 0.005),
				ModelKit.paint(Color("#b8862f"), 0.7)
			)
			gnomon.position = c + Vector3(0, 0.36, 0)
		"small_pond", "fountain":
			_pond(root, fp, id == "fountain", col)
		"arbor":
			for x: float in [0.2, 0.8]:
				for z: float in [0.3, 0.7]:
					ModelKit.box(
						root,
						Vector3(x - 0.025, 0, z - 0.025),
						Vector3(x + 0.025, 0.75, z + 0.025),
						ModelKit.paint(col)
					)
			for k in 5:
				var z := 0.25 + 0.125 * k
				ModelKit.box(root, Vector3(0.12, 0.75, z - 0.015), Vector3(0.88, 0.79, z + 0.015), ModelKit.paint(col))
			var rng := _rng(id)
			for k in 14:
				var p := Vector3(rng.randf_range(0.15, 0.85), rng.randf_range(0.45, 0.82), rng.randf_range(0.25, 0.75))
				ModelKit.ball(root, p, 0.06, ModelKit.paint(LEAF.lightened(rng.randf() * 0.15)))
				if k % 3 == 0:
					ModelKit.ball(root, p + Vector3(0.03, 0.03, 0.03), 0.03, ModelKit.paint(Color("#ff7aa8")))
		"wooden_bridge":
			_bridge(root, c, col, int(o.get("uid", 0)))
		"gazebo":
			ModelKit.cylinder(root, c, 0.82, 0.1, ModelKit.surface(Color("#c8a26a"), "boards", 0.2), -1.0, 8)
			for k in 8:
				var a := TAU * (k + 0.5) / 8.0
				ModelKit.box(root, c + Vector3(cos(a) * 0.72 - 0.025, 0.1, sin(a) * 0.72 - 0.025),
					c + Vector3(cos(a) * 0.72 + 0.025, 0.9, sin(a) * 0.72 + 0.025), ModelKit.paint(col))
			ModelKit.cylinder(
				root,
				c + Vector3(0, 0.9, 0),
				0.92,
				0.5,
				ModelKit.surface(Color("#4f7f8a"), "shingles", 0.0),
				0.05,
				8
			)
			ModelKit.ball(root, c + Vector3(0, 1.42, 0), 0.05, ModelKit.paint(Color("#d4b04a"), 0.7))
		"pine_tree":
			Objects3D.pine(root, c, 1.1)
		"oak_tree", "maple_tree", "willow_tree":
			TreeModel.build_at(root, c, {"id": id}, 1.25, false, int(o.get("uid", 0)), false)
		"mastery_sign", "mailbox", "farm_stand", "perfect_bunch":
			_small_sign(root, id, c, col, o)
		_:
			# A decoration added to the catalog without a model: make it visible (and the test fails).
			push_warning("no 3D model for decoration %s" % id)
			ModelKit.box(root, c + Vector3(-0.2, 0, -0.2), c + Vector3(0.2, 0.4, 0.2), ModelKit.surface(col, "boards"))
	if SWAY_BY_ID.has(id):
		ModelKit.sway_all(root, SWAY_BY_ID[id])
	# Chunkier than modelled, about the middle of its footprint (the ground stays where it is).
	var chunk := ScaleGuide.decor_scale(id)
	root.scale = Vector3.ONE * chunk
	root.position = c * (1.0 - chunk)
	return ModelKit.bake(root)


static func _rng(id: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	return rng




static func _glow(col: Color) -> StandardMaterial3D:
	# Shared per colour, so the bake merges every glowing part of that colour into one draw.
	var key := col.to_html()
	if not _glows.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.0
		_glows[key] = m
	return _glows[key]




## Path tiles: packed dirt, laid bricks, or flagstones, flush with the grass.
## A plank footbridge: separate planks with gaps, beams underneath, posts with caps and two rails.
static func _bridge(root: Node3D, c: Vector3, col: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 17
	ModelKit.box(root, c + Vector3(-0.3, 0, -0.32), c + Vector3(0.3, 0.012, 0.32), ModelKit.water(), false)
	var boards := ModelKit.surface(col, "boards", 0.0)
	var dark := ModelKit.paint(col.darkened(0.25))
	for x: float in [-0.3, 0.3]:  # the beams the planks rest on
		ModelKit.box(root, c + Vector3(x - 0.03, 0.08, -0.34), c + Vector3(x + 0.03, 0.13, 0.34), dark)
	var planks := 9
	for k in planks:
		var z := -0.3 + 0.6 * (k + 0.5) / planks
		var lift := rng.randf_range(-0.004, 0.006)
		ModelKit.box(root, c + Vector3(-0.42 + rng.randf_range(0, 0.02), 0.13 + lift, z - 0.026),
			c + Vector3(0.42 - rng.randf_range(0, 0.02), 0.16 + lift, z + 0.026), boards)
	for side: float in [-1.0, 1.0]:
		var x := 0.4 * side
		for z: float in [-0.3, 0.0, 0.3]:
			ModelKit.box(root, c + Vector3(x - 0.02, 0.1, z - 0.02), c + Vector3(x + 0.02, 0.4, z + 0.02), dark)
			ModelKit.cylinder(root, c + Vector3(x, 0.4, z), 0.032, 0.03, dark, 0.014, 4)
		for y: float in [0.22, 0.34]:
			ModelKit.box(root, c + Vector3(x - 0.012, y, -0.31), c + Vector3(x + 0.012, y + 0.028, 0.31), ModelKit.paint(col))


static func _pond(root: Node3D, fp: Vector2i, fountain: bool, col: Color) -> void:
	var c := Vector3(fp.x / 2.0, 0, fp.y / 2.0)
	var r := minf(fp.x, fp.y) * 0.42
	if fountain:
		ModelKit.cylinder(root, c, r, 0.18, ModelKit.surface(col, "stone", 0.2), -1.0, 24)
		ModelKit.cylinder(root, c + Vector3(0, 0.17, 0), r * 0.9, WATER_LIFT + 0.01, ModelKit.water(), -1.0, 24)
		ModelKit.cylinder(root, c, 0.08, 0.6, ModelKit.paint(col), 0.06, 10)
		ModelKit.cylinder(root, c + Vector3(0, 0.6, 0), 0.3, 0.06, ModelKit.paint(col), 0.25, 16)
		ModelKit.cylinder(root, c + Vector3(0, 0.65, 0), 0.26, WATER_LIFT + 0.01, ModelKit.water(), -1.0, 16)
		# The spout, its jet falling back into the upper bowl, and the bowl spilling over into the basin.
		ModelKit.cylinder(root, c + Vector3(0, 0.64, 0), 0.025, 0.07, ModelKit.paint(col), 0.018, 8)
		DecorMotion.spray(root, c + Vector3(0, 0.71, 0), DecorMotion.JET)
		var cascade: Dictionary = DecorMotion.CASCADE.duplicate()
		cascade["start_radius"] = 0.31  # just outside the upper bowl (0.3 at its widest), not inside its stone
		DecorMotion.spray(root, c + Vector3(0, 0.66, 0), cascade)
		_pond_bank(root, c, r + 0.12, r + 0.12, 3)
	else:
		ModelKit.ball(
			root,
			c + Vector3(0, -0.02, 0),
			1.0,
			ModelKit.paint(Color("#8a7a5a")),
			Vector3(r + 0.08, 0.05, r * 0.85 + 0.08)
		)
		ModelKit.ball(root, c + Vector3(0, 0.005, 0), 1.0, ModelKit.water(), Vector3(r, 0.03, r * 0.85))
		for k in 3:
			var a := TAU * k / 3.0 + 0.5
			ModelKit.ball(root, c + Vector3(
				cos(a) * r * 0.5,
				0.03,
				sin(a) * r * 0.4
			), 0.09, ModelKit.paint(Color("#4f9a3a")),
				Vector3(1, 0.12, 1))
			if k != 1:  # a pink lotus bloom on two of the pads: a cup of petals round a yellow heart
				var bloom := c + Vector3(cos(a) * r * 0.5, 0.045, sin(a) * r * 0.4)
				for j in 5:
					var b := TAU * j / 5.0
					ModelKit.ball(root, bloom + Vector3(cos(b) * 0.022, 0.012, sin(b) * 0.022), 0.03,
						ModelKit.paint(Color("#f4a6c8")), Vector3(0.7, 1.3, 0.7))
				ModelKit.ball(root, bloom + Vector3(0, 0.012, 0), 0.014, ModelKit.paint(Color("#f2c230")))
		_ducks(root, c + Vector3(0, 0.02, 0), r * 0.55)
		_pond_bank(root, c, r + 0.1, r * 0.85 + 0.1, 5)


## What grows and lies at a water's edge: a ring of stones (with a gap or two), and reeds in clumps, so the
## water sits in the ground. `rx` and `rz` are the bank's half sizes; `seed_value` makes each water its own.
static func _pond_bank(root: Node3D, c: Vector3, rx: float, rz: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 131
	var stones := 16
	for i in stones:
		if i % 7 == 3:
			continue  # a gap in the stones: a place to drink
		var a := TAU * i / stones + rng.randf_range(-0.1, 0.1)
		var size := rng.randf_range(0.04, 0.085)
		var stone := ModelKit.facet_ball(root, c + Vector3(cos(a) * rx, 0.015, sin(a) * rz), size,
			ModelKit.paint(Color("#9a9588").darkened(rng.randf() * 0.25)), Vector3(1.2, 0.7, 1.0))
		stone.rotation.y = rng.randf() * TAU
	for k in 3:
		var a := rng.randf() * TAU
		var at := c + Vector3(cos(a) * (rx + 0.05), 0.0, sin(a) * (rz + 0.05))
		for j in 4:
			var reed_h := rng.randf_range(0.14, 0.26)
			var reed := ModelKit.cylinder(root,
				at + Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04)),
				0.006, reed_h, ModelKit.paint(Color("#6f9a3c")), 0.002, 4)
			reed.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
			ModelKit.cylinder(root, at + Vector3(0.0, reed_h * 0.85, 0.0), 0.012, 0.04,
				ModelKit.paint(Color("#7a5a30")), 0.01, 5)


## Two ducks paddling round a pond, apart from each other.
static func _ducks(root: Node3D, centre: Vector3, reach: float) -> void:
	for k in 2:
		var paddle: Dictionary = DecorMotion.PADDLING.duplicate()
		paddle["radius"] = reach * (1.0 - 0.3 * k)
		paddle["phase"] = PI * k * 3.1
		DecorMotion.orbit(root, centre, DecorMotion.duck(Color("#f2efe6") if k == 0 else Color("#8a6a45")), paddle)


static func _small_sign(root: Node3D, id: String, c: Vector3, col: Color, o: Dictionary) -> void:
	match id:
		"mailbox":
			ModelKit.box(root, c + Vector3(-0.015, 0, -0.015), c + Vector3(0.015, 0.42, 0.015), ModelKit.paint(WOOD))
			var box := ModelKit.cylinder(root, Vector3.ZERO, 0.07, 0.24, ModelKit.paint(col, 0.5), -1.0, 12)
			box.rotation.z = PI / 2.0
			box.position = c + Vector3(0, 0.48, 0)
			ModelKit.box(
				root,
				c + Vector3(-0.06, 0.5, 0.07),
				c + Vector3(-0.05, 0.62, 0.075),
				ModelKit.paint(Color("#d8382f"))
			)
		"farm_stand":
			ModelKit.box(
				root,
				c + Vector3(-0.35, 0, -0.25),
				c + Vector3(0.35, 0.3, 0.25),
				ModelKit.surface(WOOD, "boards", 0.2)
			)
			for x: float in [-0.33, 0.33]:
				ModelKit.box(
					root,
					c + Vector3(x - 0.02, 0.3, -0.23),
					c + Vector3(x + 0.02, 0.7, -0.19),
					ModelKit.paint(WOOD)
				)
			ModelKit.box(root, c + Vector3(-0.4, 0.7, -0.35), c + Vector3(0.4, 0.73, 0.1), ModelKit.paint(col))
			for k in 6:
				ModelKit.ball(root, c + Vector3(-0.25 + 0.1 * k, 0.33, 0.05), 0.045,
					ModelKit.paint([Color("#e2453c"), Color("#f2a33a"), Color("#8fbf3a")][k % 3]))
		"mastery_sign", "perfect_bunch":
			# The mastered item's colour (a crop, tree or animal), or a bunch's flower's.
			var shown := Game.mastery.colour_of(str(o.get("crop", o.get("flower", ""))))
			var accent := Color.html(shown) if shown != "" else col
			if id == "perfect_bunch":
				for k in 7:
					var a := TAU * k / 7.0
					var p := c + Vector3(cos(a) * 0.08, 0, sin(a) * 0.08)
					ModelKit.cylinder(root, p, 0.008, 0.25, ModelKit.paint(Color("#4f8a2f")), -1.0, 4)
					ModelKit.ball(root, p + Vector3(cos(a) * 0.05, 0.27, sin(a) * 0.05), 0.05, ModelKit.paint(accent))
				ModelKit.cylinder(root, c + Vector3(0, 0.06, 0), 0.07, 0.06, ModelKit.paint(Color("#f29ab8")), -1.0, 10)
			else:
				ModelKit.box(root, c + Vector3(-0.015, 0, -0.015), c + Vector3(0.015, 0.4, 0.015), ModelKit.paint(WOOD))
				ModelKit.box(
					root,
					c + Vector3(-0.02, 0.32, -0.22),
					c + Vector3(0.02, 0.6, 0.22),
					ModelKit.paint(Color("#ffd34d"), 0.5)
				)
				ModelKit.ball(root, c + Vector3(0.03, 0.46, 0), 0.07, ModelKit.paint(accent), Vector3(0.3, 1, 1))


## A mystery young on the farm: a seedling in a mound of soil (taller and leafier with each can), or a
## covered wicker basket (a baby, stirring under its blanket) with a tag showing how far it has grown.
static func build_young(it: Dictionary, o: Dictionary, growth: float) -> Node3D:
	var root := Node3D.new()
	var c := Vector3(0.5, 0, 0.5)
	if str(it.get("grows", "")) == "tree":
		ModelKit.ball(root, c, 0.2, ModelKit.paint(Color("#6b4a2b")), Vector3(1, 0.35, 1))
		var h := lerpf(0.12, 0.42, growth)
		ModelKit.cylinder(root, c + Vector3(0, 0.05, 0), 0.012, h, ModelKit.paint(Color("#5d7a2c")), 0.008, 6)
		var leaf := ModelKit.paint(Color.html(str(it.get("color", "#6aa84f"))))
		for k in 2 + int(growth * 4.0):
			var a := TAU * k / 5.0 + 0.4
			var y := 0.06 + h * (0.45 + 0.5 * float(k) / 6.0)
			ModelKit.ball(root, c + Vector3(cos(a) * 0.05, y, sin(a) * 0.05), 0.045, leaf, Vector3(1.4, 0.35, 0.8))
		ModelKit.ball(root, c + Vector3(0, 0.06 + h, 0), 0.04, leaf, Vector3(1, 1.2, 1))
	else:
		var wicker := ModelKit.surface(Color("#b8894f"), "boards", 0.2)
		ModelKit.tub(root, c + Vector3(-0.2, 0, -0.14), c + Vector3(0.2, 0.16, 0.14), 0.025, wicker)
		ModelKit.ball(root, c + Vector3(0, 0.15, 0), 1.0, ModelKit.paint(Color("#9fc5e8")), Vector3(0.18, 0.06, 0.12))
		ModelKit.box(root, c + Vector3(-0.01, 0.16, -0.16), c + Vector3(0.01, 0.3, -0.14), ModelKit.paint(WOOD))
		# A tag on a stick: a bar filling with the feed given.
		ModelKit.box(root, c + Vector3(-0.07, 0.26, -0.155), c + Vector3(0.07, 0.31, -0.145), ModelKit.paint(WHITE))
		ModelKit.box(root, c + Vector3(-0.065, 0.27, -0.16), c + Vector3(-0.065 + 0.13 * maxf(growth, 0.04), 0.3, -0.158),
			ModelKit.paint(Color("#e2a43a")))
	return ModelKit.bake(root)
