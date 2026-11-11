class_name BuildingStock
extends RefCounted
## What a building keeps that isn't an animal or a plant, shown where it's kept: vehicles parked in the
## Garage's apron, Perfect Bunches in pots by the Garden Shed's door, goods stacked by the Barn. One builder
## per kind of stock, chosen by the model's `fill.stock` (data/building_models.json); a new holder is a line
## of data and, for a new kind of thing, one builder here. Every builder returns a signature (what's shown)
## so the owner rebuilds only when it changes.

const KINDS := ["vehicles", "bunches", "goods"]
const MAX_VEHICLES := 3
const VEHICLE_SCALE := 0.55
const MAX_POTS := 8
const MAX_GOODS := 10
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
	return ModelKit.bake(root)


## Parked in a row on the apron, nose to the road.
static func _vehicles(root: Node3D, o: Dictionary, p: Vector3, fp: Vector2i) -> void:
	var inside: Dictionary = o.get("inside", {})
	var n := 0
	for id: String in Game.item_order:
		if n >= MAX_VEHICLES:
			break
		if int(inside.get(id, 0)) <= 0:
			continue
		var car := VehicleModel.build(Game.item_data(id))
		car.scale = Vector3.ONE * VEHICLE_SCALE
		car.position = Vector3(p.x - 0.5 * VEHICLE_SCALE - n * 0.62, 0, p.z - 0.5 * VEHICLE_SCALE)
		root.add_child(car)
		n += 1


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
