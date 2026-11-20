class_name YoungModel
extends RefCounted
## A mystery young's look, built fresh as it grows (never kept by ModelStore), apart from DecorModel so the start
## does not compile every decoration's builder to draw one (docs/PERF_RUN.md, the start).

const SPROUT_UNTIL := 0.2             # a seedling watered less than this (of its cans) is still a sprout..
const SAPLING := Vector2(0.2, 0.6)     # ..then a little tree: this size of a grown one at first, this on its last can
const SAPLING_LOOK := 3               # the little tree's shape: one for every seedling (what it becomes is a secret)
const STAKE := Vector2(0.28, 0.55)     # the stake it is tied to: this tall at first, this at last
const SOIL := Color("#6b4a2b")
const SPROUT := Color("#5d7a2c")


## A mystery young on the farm: a seedling in a mound of soil (a sprout, then a little tree that grows with each
## can until it turns into what it was all along), or a covered wicker basket (a baby, stirring under its
## blanket) with a tag showing how far it has grown.
static func build(it: Dictionary, o: Dictionary, growth: float) -> Node3D:
	var root := Node3D.new()
	var c := Vector3(0.5, 0, 0.5)
	if str(it.get("grows", "")) == "tree":
		var green := Color.html(str(it.get("color", "#6aa84f")))
		ModelKit.ball(root, c, 0.2, ModelKit.paint(SOIL), Vector3(1, 0.35, 1))
		if growth < SPROUT_UNTIL:
			ModelKit.cylinder(root, c + Vector3(0, 0.05, 0), 0.012, 0.13, ModelKit.paint(SPROUT), 0.008, 6)
			for side: float in [-1.0, 1.0]:
				ModelKit.ball(root, c + Vector3(side * 0.05, 0.17, 0), 0.05, ModelKit.paint(green), Vector3(1.4, 0.35, 0.8))
		else:
			var grown := inverse_lerp(SPROUT_UNTIL, 1.0, growth)
			TreeSpec.builder().build_at(root, c + Vector3(0, 0.03, 0), {"id": str(it.get("id", ""))},
				lerpf(SAPLING.x, SAPLING.y, grown), false, SAPLING_LOOK, false, green)
			ModelKit.cylinder(root, c + Vector3(0.08, 0.03, 0.03), 0.013, lerpf(STAKE.x, STAKE.y, grown),
				ModelKit.paint(DecorPaint.WOOD), 0.013, 6)
	else:
		var wicker := ModelKit.surface(Color("#b8894f"), "boards", 0.2)
		ModelKit.tub(root, c + Vector3(-0.2, 0, -0.14), c + Vector3(0.2, 0.16, 0.14), 0.025, wicker)
		ModelKit.ball(root, c + Vector3(0, 0.15, 0), 1.0, ModelKit.paint(Color("#9fc5e8")), Vector3(0.18, 0.06, 0.12))
		ModelKit.box(root, c + Vector3(-0.01, 0.16, -0.16), c + Vector3(0.01, 0.3, -0.14), ModelKit.paint(DecorPaint.WOOD))
		# A tag on a stick: a bar filling with the feed given.
		ModelKit.box(root, c + Vector3(-0.07, 0.26, -0.155), c + Vector3(0.07, 0.31, -0.145),
			ModelKit.paint(DecorPaint.WHITE))
		ModelKit.box(root, c + Vector3(-0.065, 0.27, -0.16), c + Vector3(-0.065 + 0.13 * maxf(growth, 0.04), 0.3, -0.158),
			ModelKit.paint(Color("#e2a43a")))
	return ModelKit.bake(root)
