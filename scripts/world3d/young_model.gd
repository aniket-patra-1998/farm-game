class_name YoungModel
extends RefCounted
## A mystery young's look, built fresh as it grows (never kept by ModelStore), apart from DecorModel so the start
## does not compile every decoration's builder to draw one (docs/PERF_RUN.md, the start).

## A mystery young on the farm: a seedling in a mound of soil (taller and leafier with each can), or a
## covered wicker basket (a baby, stirring under its blanket) with a tag showing how far it has grown.
static func build(it: Dictionary, o: Dictionary, growth: float) -> Node3D:
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
		ModelKit.box(root, c + Vector3(-0.01, 0.16, -0.16), c + Vector3(0.01, 0.3, -0.14), ModelKit.paint(DecorPaint.WOOD))
		# A tag on a stick: a bar filling with the feed given.
		ModelKit.box(root, c + Vector3(-0.07, 0.26, -0.155), c + Vector3(0.07, 0.31, -0.145),
			ModelKit.paint(DecorPaint.WHITE))
		ModelKit.box(root, c + Vector3(-0.065, 0.27, -0.16), c + Vector3(-0.065 + 0.13 * maxf(growth, 0.04), 0.3, -0.158),
			ModelKit.paint(Color("#e2a43a")))
	return ModelKit.bake(root)
