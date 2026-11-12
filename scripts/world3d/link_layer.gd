class_name LinkLayer
extends Node3D
## Draws every fence, hedge, wall and path piece on the farm, joined up. Pieces aren't nodes: each (item, shape,
## variant) is one MultiMesh of every piece that looks like it (LinkModels builds the meshes once), so a farm of
## hundreds of fences costs a handful of draws, and building another costs a few floats. A piece's shape comes
## from its neighbours every sync (LinksSystem.mask → LinkShape), so placing, selling or moving one re-shapes
## exactly the pieces beside it: an end becomes a straight, a straight a tee. Pieces that were joined by a change
## snap: a quick squash, and `snapped` for a sound. Only pieces that changed touch their buckets.

signal snapped(at: Vector3, fresh: bool)   # a piece joined its neighbours (fresh: it was just placed)

const DROP_HEIGHT := 1.1
const DROP_TIME := 0.22
const SNAP_TIME := 0.34
const SNAP_SQUASH := 0.22      # how far a snapping piece squashes
const HEIGHT_VARY := 0.05      # no two fence posts quite the same height

var _buckets := {}   # "item|kind|variant" -> {"uids": Array[int], "views": Array[MultiMeshInstance3D], "dirty": bool}
var _slot := {}      # uid -> {"key": String, "xf": Transform3D, "mask": int, "hidden": bool}
var _pulses := {}    # uid -> {"age": float, "drop": bool}
var _synced_once := false


func has_piece(uid: int) -> bool:
	return _slot.has(uid)


## Brings the pieces up to date with the farm's objects.
func sync(objects: Array) -> void:
	var seen := {}
	var touched := {}   # buckets to rebuild
	var joined: Array[int] = []
	var fresh := {}
	for o: Dictionary in objects:
		var group := Game.links.group_of(str(o.get("id", "")))
		if group.is_empty() or not o.has("row"):
			continue
		var uid := int(o["uid"])
		seen[uid] = true
		var row := int(o["row"])
		var col := int(o["col"])
		var mask := Game.links.mask_at(group, row, col, uid)
		var shape := LinkShape.of(mask)
		var variant := (row * 7 + col * 13 + row * col) % LinkModels.VARIANTS
		var key := "%s|%d|%d" % [o["id"], shape.x, variant]
		var xf := _transform(group, uid, row, col, shape.y)
		var old: Dictionary = _slot.get(uid, {})
		if old.get("key", "") == key and old.get("xf", Transform3D()) == xf:
			continue
		if old.has("key"):
			_touch(touched, str(old["key"]), o)
			if int(old["mask"]) | mask != int(old["mask"]):
				joined.append(uid)   # it gained a side: something joined it
		else:
			fresh[uid] = true
			if mask != 0:
				joined.append(uid)
		_slot[uid] = {"key": key, "xf": xf, "mask": mask, "hidden": bool(old.get("hidden", false))}
		_touch(touched, key, o)
	for uid: int in _slot.keys():
		if not seen.has(uid):
			_touch(touched, str(_slot[uid]["key"]), {})
			_slot.erase(uid)
			_pulses.erase(uid)
	for key: String in touched:
		_rebuild(key)
	if _synced_once:
		for uid in joined:
			pulse(uid, fresh.has(uid))
		for uid in fresh:
			if not joined.has(uid):
				pulse(uid, true)   # a lone piece drops in as well
		if not joined.is_empty():   # one click for the whole change, however many pieces it joined
			snapped.emit((_slot[joined[0]]["xf"] as Transform3D).origin, not fresh.is_empty())
	_synced_once = true


## A piece squashes and springs back (tapped, or joined); a new one drops in first.
func pulse(uid: int, drop := false) -> void:
	if _slot.has(uid):
		_pulses[uid] = {"age": 0.0, "drop": drop}
		_write(uid, _shown(uid, 0.0, drop))   # from this frame on, not a frame late


## A piece in hand isn't standing on the farm (it's drawn as the ghost): its slot collapses to nothing.
func set_hidden(uid: int, hidden: bool) -> void:
	if not _slot.has(uid) or bool(_slot[uid]["hidden"]) == hidden:
		return
	_slot[uid]["hidden"] = hidden
	_write(uid, _shown(uid, 0.0))


## Where a piece is drawn right now (nothing when it's in hand).
func transform_of(uid: int) -> Transform3D:
	var p: Dictionary = _pulses.get(uid, {})
	return _shown(uid, float(p.get("age", 0.0)), bool(p.get("drop", false)))


func _process(delta: float) -> void:
	for uid: int in _pulses.keys():
		var p: Dictionary = _pulses[uid]
		p["age"] = float(p["age"]) + delta
		var end := (DROP_TIME if p["drop"] else 0.0) + SNAP_TIME
		if float(p["age"]) >= end or not _slot.has(uid):
			_pulses.erase(uid)
			if _slot.has(uid):
				_write(uid, _shown(uid, 0.0))
			continue
		_write(uid, _shown(uid, float(p["age"]), bool(p["drop"])))


## Where a piece stands, `age` seconds into its reaction.
func _shown(uid: int, age: float, drop := false) -> Transform3D:
	var slot: Dictionary = _slot[uid]
	var xf: Transform3D = slot["xf"]
	if slot["hidden"]:
		return Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin)
	if not _pulses.has(uid):
		return xf
	var lift := 0.0
	var t := age
	if drop:
		if t < DROP_TIME:
			var u := t / DROP_TIME
			lift = DROP_HEIGHT * (1.0 - u * u)
		t -= DROP_TIME
	var wave := 0.0
	if t > 0.0:
		wave = exp(-t * 9.0) * sin(t * 28.0) * SNAP_SQUASH
	return Transform3D(xf.basis * Basis.from_scale(Vector3(1.0 - wave * 0.5, 1.0 + wave, 1.0 - wave * 0.5)),
		xf.origin + Vector3(0, lift, 0))


## The piece's rest transform: at its tile's centre, turned, a touch taller or shorter for fences and hedges.
func _transform(group: String, uid: int, row: int, col: int, turns: int) -> Transform3D:
	var tall := 1.0
	if group != "path":
		tall += (fposmod(float(uid) * 0.6180339, 1.0) - 0.5) * 2.0 * HEIGHT_VARY
	var basis := Basis(Vector3.UP, LinkShape.yaw(turns)) * Basis.from_scale(Vector3(1, tall, 1))
	return Transform3D(basis, Vector3(col + 0.5, 0, row + 0.5))


func _touch(touched: Dictionary, key: String, o: Dictionary) -> void:
	touched[key] = o if not o.is_empty() else touched.get(key, {})


## The pieces of a bucket, written afresh (only buckets that gained or lost a piece come here).
func _rebuild(key: String) -> void:
	var uids: Array[int] = []
	for uid: int in _slot:
		if _slot[uid]["key"] == key:
			uids.append(uid)
	var b: Dictionary = _buckets.get(key, {})
	if uids.is_empty():
		if b.has("views"):
			for v: MultiMeshInstance3D in b["views"]:
				v.queue_free()
		_buckets.erase(key)
		return
	if not b.has("views"):
		b = {"uids": uids, "views": _make_views(key)}
		_buckets[key] = b
	b["uids"] = uids
	var box := AABB(Vector3(-1, -1, -1), Vector3(Game.farm_size + 2, 4, Game.farm_size + 2))
	for v: MultiMeshInstance3D in b["views"]:
		var mm := v.multimesh
		mm.instance_count = uids.size()
		mm.custom_aabb = box
		for i in uids.size():
			mm.set_instance_transform(i, _shown(uids[i], 0.0))


func _make_views(key: String) -> Array[MultiMeshInstance3D]:
	var bits := key.split("|")
	var it := Game.item_data(bits[0])
	var out: Array[MultiMeshInstance3D] = []
	for p: Dictionary in LinkModels.parts(it, int(bits[1]), int(bits[2])):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = p["mesh"]
		var v := MultiMeshInstance3D.new()
		v.multimesh = mm
		if not p["shadow"]:
			v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(v)
		out.append(v)
	return out


func _write(uid: int, xf: Transform3D) -> void:
	var b: Dictionary = _buckets.get(str(_slot[uid]["key"]), {})
	if not b.has("uids"):
		return
	var i := (b["uids"] as Array).find(uid)
	if i < 0:
		return
	for v: MultiMeshInstance3D in b["views"]:
		v.multimesh.set_instance_transform(i, xf)
