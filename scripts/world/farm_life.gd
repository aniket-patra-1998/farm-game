class_name FarmLife
extends Node
## The minds of the farm's animals: one AnimalBehaviour per animal (and stray) on the farm, kept in step
## with Game.objects and updated every frame, whether or not anything draws them. The 3D animals (and the
## 2D ones, where the 2D world is used) only read from here, so there's one place where an animal decides
## what to do, and drawing it never changes that.

const THINK_EVERY := 2   # each mind thinks every this many frames (staggered), with the time that passed
const WANDER := 0.22   # how far an animal strays from its tile centre, in tiles

var _minds := {}       # uid -> {"mind": AnimalBehaviour, "key": String}
var _queued := false
var _farmer_in := 0.0   # seconds until it next looks whether the farmer is walking by


func _ready() -> void:
	Game.objects_changed.connect(queue_sync)
	Game.object_changed.connect(sync_one)
	sync()


static func lives(o: Dictionary) -> bool:
	return o.get("stray", false) or Game.kind_of(o) == "animal"


func queue_sync() -> void:
	if not _queued:
		_queued = true
		sync.call_deferred()


## A new animal, or one moved to a new spot or turned into another (a calf grown up), starts afresh there,
## on its own beat (seeded by its uid, so the farm moves the same way each time it loads).
func sync() -> void:
	var pt := PerfReadout.start()
	sync_timed()
	PerfReadout.stop("animals_sync", pt)


func sync_timed() -> void:
	_queued = false
	var seen := {}
	for o in Game.objects:
		if not lives(o):
			continue
		var uid := int(o["uid"])
		seen[uid] = true
		var key := "%s|%d|%d" % [o["id"], int(o["row"]), int(o["col"])]
		var m: Dictionary = _minds.get(uid, {})
		if m.get("key", "") == key:
			continue
		var mind := AnimalBehaviour.new(AnimalRig.of(Game.item_data(o["id"])), uid * 7919,
			Vector2(WANDER * FarmGrid.TILE_W / 2.0, WANDER * FarmGrid.TILE_H / 2.0))
		_minds[uid] = {"mind": mind, "key": key, "home": _home(o)}
	for uid in _minds.keys():
		if not seen.has(uid):
			_minds.erase(uid)


## One thing changed where it stands (a calf grown up into a cow): its mind only.
func sync_one(uid: int) -> void:
	var o := Game.object_by_uid(uid)
	if o.is_empty() or not lives(o):
		return
	var key := "%s|%d|%d" % [o["id"], int(o["row"]), int(o["col"])]
	if str(_minds.get(uid, {}).get("key", "")) != key:
		_minds[uid] = {"key": key, "home": _home(o), "mind": AnimalBehaviour.new(AnimalRig.of(Game.item_data(o["id"])),
			uid * 7919, Vector2(WANDER * FarmGrid.TILE_W / 2.0, WANDER * FarmGrid.TILE_H / 2.0))}


func mind(uid: int) -> AnimalBehaviour:
	var m: Dictionary = _minds.get(uid, {})
	return m.get("mind")


## Where an animal's home spot is, in tiles (x: col, y: row), as the farmer's position is.
static func _home(o: Dictionary) -> Vector2:
	return Vector2(float(o["col"]) + 0.5, float(o["row"]) + 0.5)


## The farmer walking by: animals near their way turn to watch them a moment (AnimalRig.farmer; looks only).
## Returns how many turned (tests).
func see_farmer(at: Vector2) -> int:
	var reach := AnimalRig.farmer("reach", 2.2)
	var turned := 0
	for m in _minds.values():
		var d: Vector2 = at - (m["home"] as Vector2)
		if d.length() <= reach and (m["mind"] as AnimalBehaviour).see_farmer(signf(d.x - d.y)):
			turned += 1   # (screen right is +col, -row)
	return turned


func _process(delta: float) -> void:
	var pt := PerfReadout.start()
	_process_timed(delta)
	PerfReadout.stop("animals_think", pt)


func _process_timed(delta: float) -> void:
	_farmer_in -= delta
	if _farmer_in <= 0.0:
		_farmer_in = AnimalRig.farmer("every", 1.5)
		if Game.player.is_walking():
			see_farmer(Game.player.pos)
	var frame := Engine.get_process_frames()
	var n := 0
	for m in _minds.values():
		var due: float = float(m.get("owed", 0.0)) + delta
		if (frame + n) % THINK_EVERY == 0:
			(m["mind"] as AnimalBehaviour).update(due)
			due = 0.0
		m["owed"] = due
		n += 1
