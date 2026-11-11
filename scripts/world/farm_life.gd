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


func _ready() -> void:
	Game.objects_changed.connect(queue_sync)
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
		_minds[uid] = {"mind": mind, "key": key}
	for uid in _minds.keys():
		if not seen.has(uid):
			_minds.erase(uid)


func mind(uid: int) -> AnimalBehaviour:
	var m: Dictionary = _minds.get(uid, {})
	return m.get("mind")


func _process(delta: float) -> void:
	var frame := Engine.get_process_frames()
	var n := 0
	for m in _minds.values():
		var due: float = float(m.get("owed", 0.0)) + delta
		if (frame + n) % THINK_EVERY == 0:
			(m["mind"] as AnimalBehaviour).update(due)
			due = 0.0
		m["owed"] = due
		n += 1
