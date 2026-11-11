class_name BuildingStock
extends RefCounted
## What a building keeps that isn't an animal or a plant, shown where it's kept: vehicles parked in the
## Garage's apron, Perfect Bunches in pots by the Garden Shed's door, goods stacked by the Barn. One builder
## per kind of stock, chosen by the model's `fill.stock` (data/building_models.json); a new holder is a line
## of data and, for a new kind of thing, one builder here. Every builder returns a signature (what's shown)
## so the owner rebuilds only when it changes.

const KINDS := ["vehicles", "bunches", "goods", "gophers"]
const MAX_VEHICLES := 2           # the most shown in the doorway (the garage can hold more)
const VEHICLE_SCALE := 0.85
const VEHICLE_SETBACK := 0.12     # how far behind the doorway a vehicle's middle stands: its nose sticks out
const DOOR_SHARE := 0.55          # the Garage door's width, in tiles of footprint (data/building_models.json)
const MAX_POTS := 8
const MAX_GOODS := 10
const MAX_MOUNDS := 10
const MOUND_EDGE := 0.42          # tiles between a burrow and the fence
const GOPHER_COATS := {"plain_gopher": "#a58660", "brown_gopher": "#7b5233", "spotted_gopher": "#b8946a",
	"striped_gopher": "#8a6540", "golden_gopher": "#e8b830"}
const FLOWER_COLOURS := [Color("#d6304a"), Color("#f5c518"), Color("#f7b5c8"), Color("#9b7be0"), Color("#ff8c42")]


## A short text that changes when what's shown would change.
static func signature(kind: String, o: Dictionary) -> String:
	match kind:
		"vehicles":
			return JSON.stringify(o.get("inside", {}))
		"bunches":
			return str(Game.shed.bunches.size())
		"goods":
			return "%d|%d" % [Game.storage.stored.size(), Game.storage.barn_capacity()]
		"gophers":
			return JSON.stringify(Game.finds.owned)
	return ""


## The stock as a baked model in the building's own space, standing at `at` (shares of the footprint).
static func build(kind: String, o: Dictionary, fp: Vector2i, at: Array) -> Node3D:
	var root := Node3D.new()
	var p := Vector3(float(at[0]) * fp.x, 0, float(at[1]) * fp.y)
	match kind:
		"vehicles":
			_vehicles(root, o, p, fp)
		"bunches":
			_pots(root, p)
		"goods":
			_goods(root, p)
		"gophers":
			_gophers(root, fp, int(o.get("uid", 0)))
	return ModelKit.bake(root)


## Parked inside, nose to the doorway: the shutter is up and the front half of up to two vehicles shows in the
## opening (the back halves are inside the walls). `p` is the middle of the door's threshold.
static func _vehicles(root: Node3D, o: Dictionary, p: Vector3, fp: Vector2i) -> void:
	var inside: Dictionary = o.get("inside", {})
	var shown: Array[String] = []
	for id: String in Game.item_order:
		if shown.size() < MAX_VEHICLES and int(inside.get(id, 0)) > 0:
			shown.append(id)
	var spread := DOOR_SHARE * fp.x * 0.25
	for n in shown.size():
		var car := VehicleModel.build(Game.item_data(shown[n]))
		var pivot := Node3D.new()
		pivot.rotation.y = -PI / 2.0                       # the model faces +x; the doorway faces +z
		pivot.scale = Vector3.ONE * VEHICLE_SCALE
		car.position = Vector3(-0.5, 0, -0.5)               # turn about the vehicle's middle
		pivot.add_child(car)
		var side := 0.0 if shown.size() == 1 else (-1.0 if n == 0 else 1.0)
		pivot.position = Vector3(p.x + side * spread, 0, p.z - VEHICLE_SETBACK)
		root.add_child(pivot)


## Terracotta pots of the bunches held, in a cluster by the door; the colours are the flowers kept.
static func _pots(root: Node3D, p: Vector3) -> void:
	var held: Array = Game.shed.bunches
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in mini(held.size(), MAX_POTS):
		var c := p + Vector3((k % 4) * 0.13 - 0.2, 0, int(k / 4.0) * 0.12 - 0.05)
		ModelKit.cylinder(root, c, 0.045, 0.07, ModelKit.paint(Color("#b5653a")), 0.06, 10)
		var col: Color = FLOWER_COLOURS[hash(str(held[k])) % FLOWER_COLOURS.size()]
		for f in 3:
			var a := TAU * f / 3.0 + k
			ModelKit.ball(root, c + Vector3(cos(a) * 0.025, 0.1 + rng.randf() * 0.03, sin(a) * 0.025), 0.026,
				ModelKit.paint(col, 0.2))


## Crates and sacks stacked by the wall: more the fuller the storage.
static func _goods(root: Node3D, p: Vector3) -> void:
	var share := float(Game.storage.stored.size()) / maxf(Game.storage.barn_capacity(), 1.0)
	var n := mini(MAX_GOODS, int(ceil(share * MAX_GOODS)))
	for k in n:
		var c := p + Vector3((k % 3) * 0.17, int(k / 6.0) * 0.1, (int(k / 3.0) % 2) * 0.14)
		if k % 3 == 1:
			ModelKit.ball(root, c + Vector3(0.07, 0.05, 0), 0.075, ModelKit.paint(Color("#cdb88a")), Vector3(1, 0.75, 0.8))
		else:
			ModelKit.box(root, c, c + Vector3(0.14, 0.1, 0.12), ModelKit.surface(BuildingModel.WOOD, "boards", 0.2))


## Burrows over the yard, more as the home grows (one tier more, two mounds more), a gopher bobbing up out of
## each as many as are owned: each different kind among them (the commonest first), in its own coat.
static func _gophers(root: Node3D, fp: Vector2i, seed_value: int) -> void:
	var mounds := mini(MAX_MOUNDS, 2 + 2 * Game.finds.tier("gopher"))
	var owned := {}
	for k: Dictionary in Game.finds.families.get("gopher", {}).get("kinds", []):
		owned[str(k["id"])] = Game.finds.count(str(k["id"]))
	var who := BuildingFill.pick_kinds(owned, mini(Game.finds.total("gopher"), mounds), 99)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cols := maxi(2, int(ceil(sqrt(float(mounds) * fp.x / maxf(fp.y, 1.0)))))
	var rows := int(ceil(float(mounds) / cols))
	for m in mounds:
		var u := (m % cols) / maxf(cols - 1.0, 1.0)
		var v := int(m / float(cols)) / maxf(rows - 1.0, 1.0)
		var at := Vector3(lerpf(MOUND_EDGE, fp.x - MOUND_EDGE, u) + rng.randf_range(-0.05, 0.05), 0,
			lerpf(MOUND_EDGE, fp.y - MOUND_EDGE, v) + rng.randf_range(-0.05, 0.05))
		ModelKit.ball(root, at, 0.14, ModelKit.paint(Color("#6e4c33")), Vector3(1.0, 0.34, 1.0))
		ModelKit.ball(root, at + Vector3(0, 0.02, 0), 0.07, ModelKit.paint(Color("#2e1f14")), Vector3(1.0, 0.25, 1.0))
		if m < who.size():
			DecorMotion.orbit(root, at + Vector3(0, 0.02, 0), _gopher(who[m]),
				{"speed": 0.0, "bob": 0.03, "bob_rate": 0.9 + 0.17 * (m % 4), "phase": m * 1.3})


## One gopher, head and shoulders up out of its burrow: coat by kind, ears, nose, eyes, buck teeth.
static func _gopher(kind_id: String) -> Node3D:
	var part := Node3D.new()
	var coat := Color(GOPHER_COATS.get(kind_id, "#a58660"))
	var mat := ModelKit.paint(coat, 0.15)
	ModelKit.ball(part, Vector3(0, 0.07, 0), 0.07, mat, Vector3(1.0, 1.15, 0.95))
	ModelKit.ball(part, Vector3(0, 0.14, 0.03), 0.052, mat)
	for side in [-1.0, 1.0]:
		ModelKit.ball(part, Vector3(side * 0.04, 0.185, 0.0), 0.018, mat)
		ModelKit.ball(part, Vector3(side * 0.022, 0.15, 0.075), 0.01, ModelKit.paint(Color("#16100a")))
	ModelKit.ball(part, Vector3(0, 0.133, 0.08), 0.012, ModelKit.paint(Color("#3a2418")))
	ModelKit.box(part, Vector3(-0.008, 0.108, 0.075), Vector3(0.008, 0.125, 0.085), ModelKit.paint(Color("#f6f0e0")))
	match kind_id:
		"spotted_gopher":
			ModelKit.ball(part, Vector3(0.03, 0.1, 0.04), 0.02, ModelKit.paint(Color("#f1e4c8")))
			ModelKit.ball(part, Vector3(-0.035, 0.06, 0.04), 0.018, ModelKit.paint(Color("#f1e4c8")))
		"striped_gopher":
			for k in 3:
				ModelKit.box(part, Vector3(-0.06 + k * 0.045, 0.02, 0.03), Vector3(-0.05 + k * 0.045, 0.125, 0.075),
					ModelKit.paint(Color("#4d3320")))
		"golden_gopher":
			ModelKit.ball(part, Vector3(0, 0.205, 0.03), 0.02, ModelKit.paint(Color("#ffe27a"), 0.6), Vector3(1, 0.5, 1))
	return part
