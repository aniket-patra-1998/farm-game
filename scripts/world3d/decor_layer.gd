class_name DecorLayer
extends Node3D
## Draws the farm's standalone decorations in batches (MultiMesh), not as a node each: every decoration of one
## look standing in one region of the farm is one batch per part of its model, so what a farm of decorations
## costs to draw follows how many kinds it has, not how many things. (Fences, hedges, walls and paths are the
## LinkLayer's, drawn the same way; this is that idea for everything that stands alone.)
##
## Objects3D keeps an empty stand-in node for each (its place, its box for taps) and tells this layer where the
## thing stands (`put`), when it goes (`remove`), when it is in hand (`set_hidden`) and when it should react
## (`pulse`: dropping in, bouncing at a tap). A reaction is played by writing that one instance's transform.
##
## Regions: a batch is one thing to the renderer, drawn whole or not at all, so the farm is cut into squares of
## REGION tiles and each has its own batches: what is off screen is not drawn, and a change relays one region's.

const REGION := 12             # tiles along a region's side
const DROP_HEIGHT := 1.4       # tiles above the ground a new thing falls from (Objects3D's)
const DROP_TIME := 0.32
const SETTLE_TIME := 0.5
const SQUASH := 0.2            # how far a landing or tapped thing squashes

var _buckets := {}   # "look|region" -> {"ids": Array[int], "index": {id: place}, "views": Array, "pieces": Array}
var _slot := {}      # id -> {"key": String, "xf": Transform3D, "foot": Vector3, "hidden": bool, "serial": int}
var _pulses := {}    # id -> {"age": float, "drop": bool}
var _dirty := {}     # bucket keys to lay out again
var _serial := 0


func has_piece(id: int) -> bool:
	return _slot.has(id)


## Stands thing `id` (a decoration's uid; anything unique) at `xf`, drawn as `pieces` (Instancer.pieces_of), of
## look `look` (everything of one look shares its batches). `foot` is the middle of its footprint on the ground:
## what it squashes and lands about, and what decides its region. Returns a number to give back to `remove`, so a
## stand-in freed late never removes the thing that replaced it.
func put(id: int, look: String, pieces: Array, xf: Transform3D, foot: Vector3) -> int:
	var key := "%s|%d" % [look, region_of(foot)]
	var old: Dictionary = _slot.get(id, {})
	if old.has("key") and old["key"] != key:
		_leave(id, str(old["key"]))
	_serial += 1
	_slot[id] = {"key": key, "xf": xf, "foot": foot, "hidden": bool(old.get("hidden", false)), "serial": _serial}
	var b: Dictionary = _buckets.get(key, {})
	if b.is_empty():
		b = {"ids": [] as Array[int], "index": {}, "views": [], "pieces": pieces}
		_buckets[key] = b
	if not (b["index"] as Dictionary).has(id):
		(b["index"] as Dictionary)[id] = (b["ids"] as Array).size()
		(b["ids"] as Array).append(id)
	_dirty[key] = true
	return _serial


## Thing `id` has gone (only if `serial` is still its own: see `put`).
func remove(id: int, serial: int) -> void:
	var slot: Dictionary = _slot.get(id, {})
	if slot.is_empty() or int(slot["serial"]) != serial:
		return
	_leave(id, str(slot["key"]))
	_slot.erase(id)
	_pulses.erase(id)


## A thing in hand isn't standing on the farm (it's drawn as the ghost): its place collapses to nothing.
func set_hidden(id: int, hidden: bool) -> void:
	if not _slot.has(id) or bool(_slot[id]["hidden"]) == hidden:
		return
	_slot[id]["hidden"] = hidden
	_write(id)


## Thing `id` reacts: it squashes and springs back (tapped), or falls in from above first (`drop`: just placed).
func pulse(id: int, drop := false) -> void:
	if _slot.has(id):
		_pulses[id] = {"age": 0.0, "drop": drop}
		_write(id)


## Where thing `id` is drawn right now.
func transform_of(id: int) -> Transform3D:
	return _shown(id) if _slot.has(id) else Transform3D.IDENTITY


## The meshes thing `id` is drawn with (their ids): two things of one look share them.
func meshes_of(id: int) -> Array:
	var out: Array = []
	if _slot.has(id):
		for piece: Dictionary in _buckets[str(_slot[id]["key"])]["pieces"]:
			out.append((piece["mesh"] as Mesh).get_instance_id())
	return out


## How many batches the layer draws, and how many things stand in them.
func counts() -> Vector2i:
	var views := 0
	for b: Dictionary in _buckets.values():
		views += (b["views"] as Array).size()
	return Vector2i(views, _slot.size())


## The region of the farm a place lies in, as one number.
static func region_of(at: Vector3) -> int:
	return int(floor(at.z / REGION)) * 1000 + int(floor(at.x / REGION))


func _process(delta: float) -> void:
	if not _dirty.is_empty():
		for key: String in _dirty.keys():
			_lay_out(key)
		_dirty.clear()
	for id: int in _pulses.keys():
		var p: Dictionary = _pulses[id]
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= (DROP_TIME if p["drop"] else 0.0) + SETTLE_TIME or not _slot.has(id):
			_pulses.erase(id)
		if _slot.has(id):
			_write(id)


## Lays every batch of the layer out now (tests and tools; the farm does it once a frame).
func flush() -> void:
	for key: String in _dirty.keys():
		_lay_out(key)
	_dirty.clear()


func _leave(id: int, key: String) -> void:
	var b: Dictionary = _buckets.get(key, {})
	if b.is_empty():
		return
	# (The last thing takes the leaver's place, so nothing else moves.)
	var ids: Array = b["ids"]
	var index: Dictionary = b["index"]
	var at := int(index.get(id, -1))
	if at < 0:
		return
	var last: int = ids[ids.size() - 1]
	ids[at] = last
	index[last] = at
	ids.pop_back()
	index.erase(id)
	_dirty[key] = true


## A bucket's batches written afresh: one per part of the model, an instance per thing; none when it is empty.
func _lay_out(key: String) -> void:
	var b: Dictionary = _buckets.get(key, {})
	if b.is_empty():
		return
	var ids: Array = b["ids"]
	if ids.is_empty():
		for v: MultiMeshInstance3D in b["views"]:
			v.queue_free()
		_buckets.erase(key)
		return
	if (b["views"] as Array).is_empty():
		b["views"] = _make_views(b["pieces"], _slot[ids[0]]["foot"])
	var pieces: Array = b["pieces"]
	for k in pieces.size():
		var mm := (b["views"][k] as MultiMeshInstance3D).multimesh
		var part: Transform3D = pieces[k]["xf"]
		mm.instance_count = ids.size()
		for i in ids.size():
			mm.set_instance_transform(i, _shown(ids[i]) * part)


func _make_views(pieces: Array, at: Vector3) -> Array:
	var corner := Vector3(floor(at.x / REGION) * REGION, 0, floor(at.z / REGION) * REGION)
	var box := AABB(corner - Vector3(1.5, 1, 1.5), Vector3(REGION + 3, 5, REGION + 3))
	var out: Array = []
	for piece: Dictionary in pieces:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = piece["mesh"]
		mm.custom_aabb = box
		var v := MultiMeshInstance3D.new()
		v.multimesh = mm
		if piece.get("material") != null:
			v.material_override = piece["material"]
		if not piece["shadow"]:
			v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(v)
		out.append(v)
	return out


## Writes thing `id`'s place into its batches (when they are laid out; else the next layout does).
func _write(id: int) -> void:
	var b: Dictionary = _buckets.get(str(_slot[id]["key"]), {})
	if b.is_empty() or (b["views"] as Array).is_empty() or _dirty.has(str(_slot[id]["key"])):
		return
	var i := int((b["index"] as Dictionary).get(id, -1))
	if i < 0:
		return
	var xf := _shown(id)
	var pieces: Array = b["pieces"]
	for k in pieces.size():
		(b["views"][k] as MultiMeshInstance3D).multimesh.set_instance_transform(i, xf * (pieces[k]["xf"] as Transform3D))


## Where a thing stands this moment: at rest, collapsed to nothing in hand, or part way through a reaction (falling
## in, then a squash that springs back about its base).
func _shown(id: int) -> Transform3D:
	var slot: Dictionary = _slot[id]
	var xf: Transform3D = slot["xf"]
	if slot["hidden"]:
		return Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin)
	var p: Dictionary = _pulses.get(id, {})
	if p.is_empty():
		return xf
	var t := float(p["age"])
	var lift := 0.0
	if p["drop"]:
		if t < DROP_TIME:
			var u := t / DROP_TIME
			lift = DROP_HEIGHT * (1.0 - u * u)
		t -= DROP_TIME
	var wave := exp(-t * 9.0) * sin(t * 26.0 + 1.2) * SQUASH if t > 0.0 else 0.0
	var squash := Basis.from_scale(Vector3(1.0 + wave * 0.6, 1.0 - wave, 1.0 + wave * 0.6))
	# (squashed about the middle of its footprint on the ground, which stays put)
	var foot: Vector3 = slot["foot"]
	return Transform3D(squash, foot + Vector3(0, lift, 0)) * Transform3D(Basis.IDENTITY, -foot) * xf
