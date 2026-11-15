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



const HOUSE_AT := 0.5       # how high a birdhouse's landing board stands on its post, in tiles
const BATH_STONE := Color("#bdb6a6")   # the warm stone a birdbath is turned from (mixed with its own colour)
const BATH_SIDES := 20      # sides of a birdbath's turned stone
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
			# A round bale lying on its side: its rolled-up layers showing as rings on the ends, two twine
			# bands, and loose straw sticking out and lying round its foot.
			var bale := ModelKit.cylinder(root, Vector3.ZERO, 0.2, 0.36, ModelKit.paint(HAY), -1.0, 16)
			bale.rotation.x = PI / 2.0
			bale.position = c + Vector3(0, 0.2, 0)
			for z: float in [-0.181, 0.181]:
				for k in 3:
					var ring := ModelKit.cylinder(root, Vector3.ZERO, 0.17 - 0.05 * k, 0.004,
						ModelKit.paint(HAY.darkened(0.08 + 0.05 * k)), -1.0, 14)
					ring.rotation.x = PI / 2.0
					ring.position = c + Vector3(0, 0.2, z + signf(z) * 0.002 * (k + 1))
			for z: float in [-0.08, 0.08]:
				var band := ModelKit.cylinder(root, Vector3.ZERO, 0.205, 0.02, ModelKit.paint(Color("#a8743f")), -1.0, 16)
				band.rotation.x = PI / 2.0
				band.position = c + Vector3(0, 0.2, z)
			_straw(root, c, 0.24, 0.32, 18, id)
		"haystack":
			# A stack built up round a pole in rounded layers, each a little narrower, thatched with strands that
			# hang down its sides, straw scattered at its foot and a pitchfork leaning on it.
			for k in 4:
				var r := 0.38 - 0.06 * k
				ModelKit.ball(root, c + Vector3(0, 0.1 + 0.13 * k, 0), r, ModelKit.paint(HAY.darkened(0.08 - 0.025 * k)),
					Vector3(1, 0.55, 1))
			ModelKit.ball(root, c + Vector3(0, 0.5, 0), 0.17, ModelKit.paint(HAY.lightened(0.05)), Vector3(1, 0.9, 1))
			var rng := _rng(id)
			for k in 40:   # strands hanging down the sides
				var ang := TAU * k / 40.0 + rng.randf_range(-0.05, 0.05)
				var lay := rng.randi_range(0, 3)
				var r := (0.38 - 0.06 * lay) * 0.97
				var strand := ModelKit.box(root, Vector3(-0.006, -0.09, -0.002), Vector3(0.006, 0.0, 0.002),
					ModelKit.paint(HAY.darkened(rng.randf_range(0.0, 0.2))), false)
				strand.position = c + Vector3(cos(ang) * r, 0.1 + 0.13 * lay, sin(ang) * r)
				strand.rotation = Vector3(sin(ang) * 0.5, -ang, -cos(ang) * 0.5)
			ModelKit.cylinder(root, c + Vector3(0, 0.56, 0), 0.015, 0.14, ModelKit.paint(DARK_WOOD))
			_straw(root, c, 0.42, 0.5, 22, id)
			# The pitchfork: a handle leaning on the stack, three tines at its top.
			var fork := Node3D.new()
			fork.position = c + Vector3(0.36, 0, 0.2)
			fork.rotation = Vector3(0, 0.6, 0.38)
			root.add_child(fork)
			ModelKit.cylinder(fork, Vector3.ZERO, 0.012, 0.62, ModelKit.paint(WOOD), -1.0, 6)
			for t in 3:
				ModelKit.cylinder(fork, Vector3(-0.035 + 0.035 * t, 0.62, 0), 0.005, 0.12, ModelKit.paint(Color("#9aa3aa"), 0.5),
					-1.0, 4)
			ModelKit.box(fork, Vector3(-0.045, 0.6, -0.006), Vector3(0.045, 0.63, 0.006), ModelKit.paint(Color("#9aa3aa"), 0.5))
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
			# A plank trough on two short trestles, bound with iron straps, brimming.
			for x: float in [-0.24, 0.24]:
				ModelKit.box(root, c + Vector3(x - 0.03, 0, -0.17), c + Vector3(x + 0.03, 0.06, 0.17),
					ModelKit.paint(DARK_WOOD))
			ModelKit.tub(root, c + Vector3(-0.32, 0.06, -0.14), c + Vector3(0.32, 0.24, 0.14), 0.03,
				ModelKit.surface(col, "boards", 0.2), ModelKit.water())
			for x: float in [-0.29, 0.29]:
				ModelKit.box(root, c + Vector3(x - 0.012, 0.06, -0.145), c + Vector3(x + 0.012, 0.245, 0.145),
					ModelKit.paint(Color("#5a6066"), 0.4))
			_straw(root, c, 0.3, 0.36, 8, id)
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
			# A raised bed edged with boards, its soil mounded, leafy plants with flowers of several heights and
			# kinds standing in rows (taller at the back), and a few fallen petals.
			ModelKit.box(root, c + Vector3(-0.4, 0, -0.4), c + Vector3(0.4, 0.07, 0.4),
				ModelKit.surface(DARK_WOOD, "boards", 0.2))
			ModelKit.ball(root, c + Vector3(0, 0.065, 0), 1.0, ModelKit.paint(Color("#5e4128")), Vector3(0.37, 0.035, 0.37))
			var rng := _rng(id)
			var petals := [col, Color("#ffd23f"), Color("#ffffff"), Color("#b388ff"), Color("#ff7a59")]
			for k in 16:
				var row := k / 4
				var p := c + Vector3(-0.27 + 0.18 * (k % 4) + rng.randf_range(-0.04, 0.04), 0.08,
					-0.27 + 0.18 * row + rng.randf_range(-0.04, 0.04))
				var h := 0.2 - 0.03 * row + rng.randf_range(-0.02, 0.02)   # the back rows (low z) taller
				for leaf in 3:
					var ang := TAU * leaf / 3.0 + rng.randf()
					ModelKit.ball(root, p + Vector3(cos(ang) * 0.03, 0.02, sin(ang) * 0.03), 0.03,
						ModelKit.paint(Color("#4f8a2f").lightened(rng.randf() * 0.15)), Vector3(1.2, 0.45, 0.7))
				ModelKit.cylinder(root, p, 0.006, h, ModelKit.paint(Color("#4f8a2f")), -1.0, 4)
				var bloom: Color = petals[(k * 3 + row) % petals.size()]
				for j in 5:
					var b := TAU * j / 5.0
					ModelKit.ball(root, p + Vector3(cos(b) * 0.03, h, sin(b) * 0.03), 0.033, ModelKit.paint(bloom),
						Vector3(1.0, 0.5, 1.0))
				ModelKit.ball(root, p + Vector3(0, h + 0.008, 0), 0.016, ModelKit.paint(Color("#f2c230")))
			for k in 5:
				ModelKit.ball(root, c + Vector3(rng.randf_range(-0.3, 0.3), 0.09, rng.randf_range(-0.3, 0.3)), 0.012,
					ModelKit.paint(petals[k % petals.size()]), Vector3(1.2, 0.3, 1.0))
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
			_birdhouse(root, c, col, Color.html(str(it.get("accent", "#f4e3c3"))), id)
		"birdbath":
			_birdbath(root, c, col, id)
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


## A birdhouse on its post: a stone footing, a braced landing board, a boarded house under an overhanging roof
## with a ridge cap, a round door with its ring and a perch below it, a bird on the perch, a vine up the post
## and another bird circling above.
static func _birdhouse(root: Node3D, c: Vector3, col: Color, wall: Color, id: String) -> void:
	var wood := ModelKit.paint(WOOD)
	var dark := ModelKit.paint(DARK_WOOD)
	var rng := _rng(id)
	ModelKit.cylinder(root, c, 0.07, 0.03, ModelKit.surface(STONE, "stone", 0.3), 0.05, 8)
	ModelKit.box(root, c + Vector3(-0.02, 0.02, -0.02), c + Vector3(0.02, HOUSE_AT, 0.02), wood)
	ModelKit.box(root, c + Vector3(-0.028, HOUSE_AT - 0.05, -0.028), c + Vector3(0.028, HOUSE_AT - 0.03, 0.028), dark)
	for side: float in [-1.0, 1.0]:   # a brace each way under the landing board
		var brace := ModelKit.box(root, c + Vector3(side * 0.05 - 0.01, HOUSE_AT - 0.12, -0.01),
			c + Vector3(side * 0.05 + 0.01, HOUSE_AT, 0.01), dark)
		brace.rotation.z = side * 0.75
	ModelKit.box(root, c + Vector3(-0.17, HOUSE_AT, -0.13), c + Vector3(0.17, HOUSE_AT + 0.02, 0.13), wood)
	var lo := c + Vector3(-0.115, HOUSE_AT + 0.02, -0.095)
	var hi := c + Vector3(0.115, HOUSE_AT + 0.2, 0.095)
	ModelKit.box(root, lo, hi, ModelKit.surface(wall, "boards", 0.0))
	for sx: float in [-1.0, 1.0]:   # corner boards
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(sx * 0.115, 0, sz * 0.095)
			ModelKit.box(root, c + at + Vector3(-0.012, HOUSE_AT + 0.02, -0.012),
				c + at + Vector3(0.012, HOUSE_AT + 0.2, 0.012), ModelKit.paint(wall.darkened(0.18)))
	var top := ModelKit.roof(root, "gable", lo, hi, 0.1, 0.04, ModelKit.paint(col),
		ModelKit.surface(wall, "boards", 0.0))
	ModelKit.box(root, Vector3(lo.x - 0.05, top - 0.012, c.z - 0.014), Vector3(hi.x + 0.05, top + 0.012, c.z + 0.014),
		ModelKit.paint(col.darkened(0.25)))
	# The door: a dark round hole in a ring, on the gable end, and the perch below it.
	var door := c + Vector3(0.116, HOUSE_AT + 0.13, 0)
	_disc(root, door, 0.05, 0.008, ModelKit.paint(col))
	_disc(root, door + Vector3(0.004, 0, 0), 0.034, 0.008, ModelKit.paint(Color("#1d1712")))
	_disc(root, door + Vector3(0.03, -0.075, 0), 0.008, 0.07, dark)
	var sitter := songbird(Color("#d8553a"), Color("#f1dfc4"))
	sitter.position = door + Vector3(0.05, -0.066, 0)
	sitter.rotation.y = -PI / 2.0 + 0.5
	root.add_child(sitter)
	for k in 7:   # a vine winding up the post
		var ang := k * 1.9 + rng.randf() * 0.4
		var leaf_at := c + Vector3(cos(ang) * 0.03, 0.06 + k * 0.055, sin(ang) * 0.03)
		ModelKit.ball(root, leaf_at, 0.022, ModelKit.paint(LEAF.lightened(rng.randf() * 0.25), 0.0, 0.15),
			Vector3(1.3, 0.6, 1.0))
	ModelKit.ball(root, c + Vector3(0.035, 0.2, 0.01), 0.014, ModelKit.paint(Color("#f2d24a")))
	DecorMotion.orbit(root, c + Vector3(0, HOUSE_AT + 0.42, 0), DecorMotion.bird(Color("#6f8fc9")),
		DecorMotion.CIRCLING)


## A stone birdbath: a square plinth, a turned baluster, a wide basin with a rolled rim standing above the
## water it holds, moss and pebbles at the foot, a bird drinking on the rim and another bathing.
static func _birdbath(root: Node3D, c: Vector3, col: Color, id: String) -> void:
	var tone := col.lerp(BATH_STONE, 0.55)   # (warm stone: a blue-grey bowl reads as more water)
	var stone := ModelKit.surface(tone, "stone", 0.3)
	var smooth := ModelKit.paint(tone.lightened(0.04))
	ModelKit.box(root, c + Vector3(-0.15, 0, -0.15), c + Vector3(0.15, 0.04, 0.15), stone)
	ModelKit.box(root, c + Vector3(-0.115, 0.04, -0.115), c + Vector3(0.115, 0.075, 0.115), stone)
	lathe(root, c, [Vector2(0.0, 0.075), Vector2(0.09, 0.075), Vector2(0.095, 0.095), Vector2(0.06, 0.12),
		Vector2(0.048, 0.16), Vector2(0.074, 0.215), Vector2(0.066, 0.26), Vector2(0.044, 0.3), Vector2(0.07, 0.325),
		Vector2(0.07, 0.345), Vector2(0.05, 0.36), Vector2(0.14, 0.385), Vector2(0.225, 0.43), Vector2(0.245, 0.452),
		Vector2(0.24, 0.47), Vector2(0.21, 0.47), Vector2(0.196, 0.44), Vector2(0.0, 0.425)], BATH_SIDES, smooth)
	for y: float in [0.1, 0.33]:   # the baluster's collars, a shade darker
		ModelKit.cylinder(root, c + Vector3(0, y, 0), 0.078, 0.014, ModelKit.paint(tone.darkened(0.1)), -1.0, 14)
	ModelKit.cylinder(root, c + Vector3(0, 0.432, 0), 0.2, 0.014 + WATER_LIFT, ModelKit.water(), -1.0, BATH_SIDES)
	var rng := _rng(id)
	for k in 7:   # moss creeping over the plinth
		var ang := rng.randf() * TAU
		ModelKit.ball(root, c + Vector3(cos(ang) * 0.14, 0.035, sin(ang) * 0.14), rng.randf_range(0.022, 0.04),
			ModelKit.paint(Color("#5f8a3a").darkened(rng.randf() * 0.2)), Vector3(1.4, 0.6, 1.0))
	for k in 4:   # pebbles round the foot
		var ang := rng.randf() * TAU
		ModelKit.ball(root, c + Vector3(cos(ang) * 0.21, 0.012, sin(ang) * 0.21), rng.randf_range(0.015, 0.026),
			ModelKit.paint(STONE.darkened(rng.randf() * 0.25)), Vector3(1.2, 0.6, 1.0))
	ModelKit.ball(root, c + Vector3(-0.07, 0.447 + WATER_LIFT, 0.06), 0.03, ModelKit.paint(Color("#4f9a3c")),
		Vector3(1.0, 0.12, 1.0))   # a leaf afloat
	var drinker := songbird(Color("#7a5a3a"), Color("#e9d9bd"))
	drinker.position = c + Vector3(0.2, 0.47, 0.06)
	drinker.rotation.y = 1.9
	drinker.rotation.x = 0.35   # (head down, drinking)
	root.add_child(drinker)
	var bather := songbird(Color("#3f7fc4"), Color("#f2ead8"))
	bather.position = c + Vector3(-0.02, 0.447, -0.07)
	bather.rotation.y = -0.6
	root.add_child(bather)


## A small bird at rest, facing -z, its feet at the origin: a round body with a pale belly, a head with a beak
## and eyes, folded wings a shade darker and a tail cocked up.
static func songbird(col: Color, belly: Color) -> Node3D:
	var b := Node3D.new()
	var paint := ModelKit.paint(col)
	var wing := ModelKit.paint(col.darkened(0.22))
	ModelKit.ball(b, Vector3(0, 0.04, 0), 0.036, paint, Vector3(0.85, 0.9, 1.25), true)
	ModelKit.ball(b, Vector3(0, 0.03, -0.012), 0.03, ModelKit.paint(belly), Vector3(0.8, 0.8, 1.0), true)
	ModelKit.ball(b, Vector3(0, 0.074, -0.03), 0.025, paint, Vector3.ONE, true)
	ModelKit.cylinder(b, Vector3(0, 0.068, -0.062), 0.009, 0.026, ModelKit.paint(Color("#e8a23a")), 0.0, 6) \
		.rotation.x = -PI / 2.0
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(b, Vector3(side * 0.027, 0.045, 0.008), 0.026, wing, Vector3(0.35, 0.7, 1.3), true)
		ModelKit.ball(b, Vector3(side * 0.018, 0.08, -0.044), 0.0045, ModelKit.paint(Color("#16130f")))
		ModelKit.box(b, Vector3(side * 0.012 - 0.003, 0, -0.003), Vector3(side * 0.012 + 0.003, 0.014, 0.003),
			ModelKit.paint(Color("#c98a3a")))
	var tail := ModelKit.box(b, Vector3(-0.014, 0.036, 0.03), Vector3(0.014, 0.046, 0.085), wing)
	tail.rotation.x = 0.45
	return b


## A flat round piece standing on edge, facing +x (a door hole, a ring, a dowel when `depth` is long).
static func _disc(root: Node3D, at: Vector3, r: float, depth: float, mat: Material) -> MeshInstance3D:
	var mi := ModelKit.cylinder(root, at, r, depth, mat, -1.0, 12)
	mi.position = at
	mi.rotation.z = -PI / 2.0
	return mi


## A shape turned on a lathe round the upright axis through `c`: `profile` is its outline from the axis at
## the bottom, out and up, and back to the axis at the top, as (radius, height) points. A stretch that turns
## back toward the axis and down is a hollow (a basin's inside). Lit flat along the outline, smooth round it.
static func lathe(root: Node3D, c: Vector3, profile: Array, sides: int, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := ModelKit.scaled(sides, 8)
	for k in profile.size() - 1:
		var a: Vector2 = profile[k]
		var b: Vector2 = profile[k + 1]
		var out := Vector2(b.y - a.y, a.x - b.x).normalized()   # the outline's outward side, as (radial, up)
		for i in n:
			var corners: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for pair: Array in [[a, i], [b, i], [b, i + 1], [a, i + 1]]:
				var ang := TAU * float(pair[1]) / n
				var point: Vector2 = pair[0]
				corners.append(c + Vector3(cos(ang) * point.x, point.y, sin(ang) * point.x))
				normals.append(Vector3(cos(ang) * out.x, out.y, sin(ang) * out.x))
			var facing := (normals[0] + normals[2]).normalized()
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				var order: Array = tri
				var across := (corners[tri[1]] - corners[tri[0]]).cross(corners[tri[2]] - corners[tri[0]])
				if across.length_squared() < 1e-12:
					continue   # (at the axis a quad is a triangle: its empty half is left out)
				if across.dot(facing) > 0.0:   # (front faces run clockwise seen from outside: ModelKit.faces)
					order = [tri[0], tri[2], tri[1]]
				for v: int in order:
					st.set_normal(normals[v])
					st.add_vertex(corners[v])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	root.add_child(mi)
	return mi


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
		PondModel.build(root, c, r, r * 0.85, 5, 3)
		_ducks(root, c + Vector3(0, PondModel.WATER_LEVEL + 0.01, 0), r * 0.55)


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


## Loose straw round a thing's foot: `n` short strands lying on the ground in a ring between `inner` and `outer`
## from its centre.
static func _straw(root: Node3D, c: Vector3, inner: float, outer: float, n: int, id: String) -> void:
	var rng := _rng(id + ":straw")
	for k in n:
		var ang := rng.randf() * TAU
		var d := rng.randf_range(inner, outer)
		var strand := ModelKit.box(root, Vector3(-0.04, 0, -0.003), Vector3(0.04, 0.004, 0.003),
			ModelKit.paint(HAY.darkened(rng.randf_range(0.0, 0.25))), false)
		strand.position = c + Vector3(cos(ang) * d, 0.002, sin(ang) * d)
		strand.rotation.y = rng.randf() * TAU


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
