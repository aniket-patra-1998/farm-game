class_name UiModels
extends RefCounted
## The interface's icons as small 3D things (our own look, the way modern farm games light their icons): a gold
## coin, a gem, a hoe, a seed sack, a basket of produce, a fertilizer sack, a red barn, a price tag, a market stall,
## an album, a gear (the star and the ribbon read best as drawn shapes). Built from the farm's own parts and lit like
## it, rendered once by ItemIcons (id "ui:<kind>") and drawn by UiIcon with an outline and a soft shadow, so the
## buttons match the farm. Flat glyphs (an eye, a speaker, zoom, arrows, plus, cross) stay drawn: a symbol reads
## best as a symbol.
## Modelled about a tile across, centred on (0.5, 0, 0.5), facing the icon camera (it looks from the front left).

const KINDS: Array[String] = ["coin", "gem", "hoe", "seeds", "basket", "fertilizer", "barn", "tag", "market", "album",
	"gear", "helpers", "farmhand", "arborist", "gardener", "unwither", "fuel"]
const STRAW := Color("#e8c66a")
const CAN_GREEN := Color("#4f9a52")
const GOLD := Color("#f2b632")
const GOLD_DEEP := Color("#c98a1a")
const WOOD := Color("#b7834a")
const WOOD_DARK := Color("#7a5230")
const STEEL := Color("#b7c0c7")
const SACK := Color("#e2c99a")
const RED := Color("#d9442f")
const CREAM := Color("#fbefd2")
const LEAF := Color("#5c9a3e")


## Icon `kind` as a baked model, or null when it has none (it stays a drawn glyph).
static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	var c := Vector3(0.5, 0, 0.5)
	match kind:
		"coin":
			var coin := ModelKit.cylinder(root, Vector3.ZERO, 0.46, 0.1, ModelKit.paint(GOLD, 0.8), -1.0, 28)
			coin.rotation = Vector3(PI / 2.0, 0.35, 0)
			coin.position = c + Vector3(0, 0.46, 0)
			var face := ModelKit.cylinder(root, Vector3.ZERO, 0.35, 0.11, ModelKit.paint(GOLD_DEEP, 0.7), -1.0, 28)
			face.rotation = coin.rotation
			face.position = coin.position
			var emblem := ModelKit.cylinder(root, Vector3.ZERO, 0.16, 0.12, ModelKit.paint(GOLD.lightened(0.2), 0.8), -1.0, 5)
			emblem.rotation = coin.rotation
			emblem.position = coin.position
		"gem":
			ModelKit.cylinder(root, c + Vector3(0, 0.12, 0), 0.06, 0.32, ModelKit.paint(Color("#4fc3e8"), 0.9), 0.34, 8)
			ModelKit.cylinder(root, c + Vector3(0, 0.44, 0), 0.34, 0.12, ModelKit.paint(Color("#8ae0f5"), 0.9), 0.22, 8)
		"hoe":
			var handle := ModelKit.cylinder(root, Vector3.ZERO, 0.07, 1.1, ModelKit.surface(WOOD, "boards", 0.2), -1.0, 8)
			handle.rotation = Vector3(0, 0, -0.75)
			handle.position = c + Vector3(-0.42, 0.02, 0)
			var blade := ModelKit.box(root, Vector3(-0.3, -0.05, -0.04), Vector3(0.2, 0.34, 0.04), ModelKit.paint(STEEL, 0.8))
			blade.position = c + Vector3(0.36, 0.78, 0)
			blade.rotation = Vector3(0, 0.5, 0.25)
		"seeds", "fertilizer":
			var body := SACK if kind == "seeds" else Color("#c9d9a8")
			# A sack: a wide bottom, sides drawn in to a tied neck, a frilled top, a leaf printed on its front.
			ModelKit.ball(root, c + Vector3(0, 0.14, 0), 0.3, ModelKit.paint(body), Vector3(1.05, 0.5, 0.9))
			ModelKit.cylinder(root, c + Vector3(0, 0.12, 0), 0.31, 0.4, ModelKit.paint(body), 0.17, 14)
			ModelKit.cylinder(root, c + Vector3(0, 0.52, 0), 0.17, 0.06, ModelKit.paint(RED), 0.15, 12)
			ModelKit.cylinder(root, c + Vector3(0, 0.58, 0), 0.15, 0.14, ModelKit.paint(body.darkened(0.06)), 0.24, 12)
			var patch := ModelKit.ball(root, c + Vector3(0, 0.3, 0.25), 0.12, ModelKit.paint(LEAF if kind == "seeds" else
				Color("#3f7f1f")), Vector3(1.0, 1.0, 0.3))
			patch.rotation.y = 0.2
			if kind == "seeds":
				for k in 3:
					ModelKit.ball(root, c + Vector3(-0.3 + 0.08 * k, 0.03, 0.25 + 0.04 * k), 0.035, ModelKit.paint(Color("#e2c35a")))
		"basket":
			ModelKit.tub(root, c + Vector3(-0.36, 0, -0.28), c + Vector3(0.36, 0.34, 0.28), 0.04,
				ModelKit.surface(WOOD, "boards", 0.3))
			ModelKit.ball(root, c + Vector3(-0.15, 0.38, 0.0), 0.15, ModelKit.paint(RED, 0.4))
			ModelKit.ball(root, c + Vector3(0.14, 0.38, 0.05), 0.14, ModelKit.paint(Color("#f2a13a"), 0.3))
			ModelKit.ball(root, c + Vector3(0.0, 0.42, -0.12), 0.13, ModelKit.paint(Color("#8fbf5a"), 0.3))
			var arch := ModelKit.cylinder(root, Vector3.ZERO, 0.03, 0.7, ModelKit.paint(WOOD_DARK), -1.0, 6)
			arch.rotation = Vector3(0, 0, PI / 2.0)
			arch.position = c + Vector3(0.35, 0.62, 0)
		"barn":
			ModelKit.box(root, c + Vector3(-0.34, 0, -0.26), c + Vector3(0.34, 0.42, 0.26), ModelKit.surface(RED, "boards", 0.3))
			for side: float in [-1.0, 1.0]:
				var roof := ModelKit.box(root, Vector3(-0.22, -0.02, -0.29), Vector3(0.22, 0.02, 0.29),
					ModelKit.paint(Color("#6b4a3a")))
				roof.rotation.z = -side * 0.55
				roof.position = c + Vector3(side * 0.18, 0.52, 0)
			ModelKit.box(root, c + Vector3(-0.14, 0, 0.26), c + Vector3(0.14, 0.3, 0.28), ModelKit.paint(CREAM))
			ModelKit.box(root, c + Vector3(-0.11, 0.02, 0.27), c + Vector3(0.11, 0.27, 0.29), ModelKit.paint(RED.darkened(0.15)))
		"tag":
			var tag := Node3D.new()
			tag.position = c + Vector3(0, 0.4, 0)
			tag.rotation = Vector3(0, 0.3, 0.5)
			root.add_child(tag)
			ModelKit.box(tag, Vector3(-0.28, -0.18, -0.025), Vector3(0.18, 0.18, 0.025), ModelKit.paint(GOLD, 0.3))
			var tip := ModelKit.cylinder(tag, Vector3.ZERO, 0.18, 0.05, ModelKit.paint(GOLD, 0.3), -1.0, 4)
			tip.rotation = Vector3(PI / 2.0, 0, 0)
			tip.position = Vector3(0.18, 0, -0.025)
			ModelKit.cylinder(tag, Vector3(-0.17, 0, 0.0), 0.04, 0.06, ModelKit.paint(CREAM), -1.0, 10).rotation.x = PI / 2.0
		"market":
			ModelKit.box(root, c + Vector3(-0.38, 0, -0.22), c + Vector3(0.38, 0.32, 0.22),
				ModelKit.surface(WOOD, "boards", 0.3))
			for k in 3:
				ModelKit.ball(root, c + Vector3(-0.22 + 0.22 * k, 0.37, 0.08), 0.09,
					ModelKit.paint([RED, Color("#f2c23a"), Color("#8fbf5a")][k], 0.3))
			for x: float in [-0.36, 0.36]:
				ModelKit.cylinder(root, c + Vector3(x, 0.32, -0.18), 0.025, 0.4, ModelKit.paint(WOOD_DARK))
			for k in 6:   # the awning's stripes
				ModelKit.box(root, c + Vector3(-0.44 + 0.147 * k, 0.7, -0.26), c + Vector3(-0.44 + 0.147 * (k + 1), 0.76, 0.3),
					ModelKit.paint(RED if k % 2 == 0 else CREAM))
		"album":
			var book := Node3D.new()
			book.position = c + Vector3(0, 0.35, 0)
			book.rotation = Vector3(-0.2, 0.25, 0.1)
			root.add_child(book)
			ModelKit.box(book, Vector3(-0.32, -0.36, -0.06), Vector3(0.32, 0.36, 0.06), ModelKit.paint(Color("#3d78c9")))
			ModelKit.box(book, Vector3(-0.29, -0.33, -0.05), Vector3(0.31, 0.33, 0.065), ModelKit.paint(CREAM))
			ModelKit.box(book, Vector3(-0.32, -0.36, 0.05), Vector3(0.32, 0.36, 0.07), ModelKit.paint(Color("#3d78c9")))
			var star := ModelKit.cylinder(book, Vector3(0, 0.02, 0.07), 0.13, 0.02, ModelKit.paint(GOLD, 0.6), -1.0, 5)
			star.rotation.x = PI / 2.0
		"gear":
			var gear := Node3D.new()
			gear.position = c + Vector3(0, 0.4, 0)
			gear.rotation = Vector3(PI / 2.0, 0.4, 0)
			root.add_child(gear)
			ModelKit.cylinder(gear, Vector3(0, -0.05, 0), 0.28, 0.1, ModelKit.paint(STEEL.darkened(0.15), 0.7), -1.0, 24)
			for k in 8:
				var a := TAU * k / 8.0
				ModelKit.box(gear, Vector3(cos(a) * 0.3 - 0.06, -0.05, sin(a) * 0.3 - 0.06),
					Vector3(cos(a) * 0.3 + 0.06, 0.05, sin(a) * 0.3 + 0.06), ModelKit.paint(STEEL.darkened(0.15), 0.7))
			ModelKit.cylinder(gear, Vector3(0, -0.06, 0), 0.1, 0.12, ModelKit.paint(Color("#3b2412")), -1.0, 16)
		"helpers":   # a straw hat with a red band: the helpers' flower (HudHelpers)
			ModelKit.cylinder(root, c + Vector3(0, 0.2, 0), 0.48, 0.05, ModelKit.surface(STRAW, "boards", 0.2), -1.0, 24)
			ModelKit.cylinder(root, c + Vector3(0, 0.24, 0), 0.25, 0.24, ModelKit.paint(STRAW), 0.2, 20)
			ModelKit.cylinder(root, c + Vector3(0, 0.25, 0), 0.255, 0.07, ModelKit.paint(RED), -1.0, 20)
			ModelKit.ball(root, c + Vector3(0, 0.48, 0), 0.2, ModelKit.paint(STRAW), Vector3(1.0, 0.35, 1.0))
		"farmhand":   # a milk pail
			ModelKit.cylinder(root, c + Vector3(0, 0.05, 0), 0.26, 0.5, ModelKit.paint(STEEL, 0.8), 0.32, 20)
			ModelKit.cylinder(root, c + Vector3(0, 0.53, 0), 0.3, 0.03, ModelKit.paint(CREAM), -1.0, 20)
			var bail := ModelKit.cylinder(root, Vector3.ZERO, 0.02, 0.66, ModelKit.paint(STEEL.darkened(0.3)), -1.0, 6)
			bail.rotation = Vector3(0, 0, PI / 2.0)
			bail.position = c + Vector3(0.33, 0.78, 0)
		"arborist":   # an axe
			var haft := ModelKit.cylinder(root, Vector3.ZERO, 0.06, 1.0, ModelKit.surface(WOOD, "boards", 0.2), -1.0, 8)
			haft.rotation = Vector3(0, 0, 0.6)
			haft.position = c + Vector3(0.3, 0.02, 0)
			var head := ModelKit.box(root, Vector3(-0.24, -0.12, -0.05), Vector3(0.1, 0.14, 0.05), ModelKit.paint(STEEL, 0.8))
			head.rotation = Vector3(0, 0.3, 0.6)
			head.position = c + Vector3(-0.2, 0.78, 0)
		"gardener":   # a watering can
			ModelKit.cylinder(root, c + Vector3(0.05, 0.05, 0), 0.24, 0.42, ModelKit.paint(CAN_GREEN, 0.5), 0.2, 18)
			var spout := ModelKit.cylinder(root, Vector3.ZERO, 0.04, 0.5, ModelKit.paint(CAN_GREEN, 0.5), 0.07, 8)
			spout.rotation = Vector3(0, 0, 0.9)
			spout.position = c + Vector3(-0.15, 0.2, 0)
			var arc := ModelKit.cylinder(root, Vector3.ZERO, 0.035, 0.4, ModelKit.paint(CAN_GREEN.darkened(0.2)), -1.0, 6)
			arc.rotation = Vector3(0, 0, -PI / 2.0)
			arc.position = c + Vector3(-0.12, 0.6, 0)
		"unwither":   # a green tonic with a leaf
			ModelKit.ball(root, c + Vector3(0, 0.3, 0), 0.28, ModelKit.paint(Color("#6cc96a"), 0.8))
			ModelKit.cylinder(root, c + Vector3(0, 0.52, 0), 0.09, 0.18, ModelKit.paint(Color("#bfe8f0"), 0.8))
			ModelKit.cylinder(root, c + Vector3(0, 0.68, 0), 0.1, 0.09, ModelKit.paint(WOOD), -1.0, 10)
			var leaf := ModelKit.ball(root, c + Vector3(0.14, 0.82, 0), 0.12, ModelKit.paint(LEAF), Vector3(1.0, 0.35, 0.6))
			leaf.rotation.z = 0.6
		"fuel":   # a red jerry can
			ModelKit.box(root, c + Vector3(-0.26, 0, -0.14), c + Vector3(0.26, 0.62, 0.14), ModelKit.paint(RED, 0.6))
			ModelKit.box(root, c + Vector3(-0.18, 0.62, -0.06), c + Vector3(0.06, 0.72, 0.06), ModelKit.paint(RED.darkened(0.2)))
			var neck := ModelKit.cylinder(root, Vector3.ZERO, 0.06, 0.14, ModelKit.paint(GOLD_DEEP), -1.0, 10)
			neck.rotation.z = -0.5
			neck.position = c + Vector3(0.16, 0.62, 0)
			ModelKit.box(root, c + Vector3(-0.2, 0.2, 0.14), c + Vector3(0.2, 0.42, 0.15), ModelKit.paint(CREAM))
		_:
			root.free()
			return null
	return ModelKit.bake(root)
