class_name ContactShades
extends MultiMeshInstance3D
## The soft shades on the grass right under every animal, drawn as one batch (one draw for all of them, not one
## an animal). Each animal takes a slot (`take`), says where its shade lies and how strong it is (`put`) when
## it moves, and gives it back (`give_back`) when it leaves the farm. One batch per 3D farm, made on first use
## under the farm's top 3D node (`of`); a slot no animal holds is drawn invisible and reused.

const CHUNK := 128               # the batch grows this many slots at a time
const REACH := 500.0             # the batch is never culled: animals are anywhere on the farm

static var _batches := {}        # top node's instance id -> its ContactShades
static var _material: ShaderMaterial

var _free: Array[int] = []
var _used := 0                   # slots ever handed out (the rest of the batch is spare)
var _top: Node3D                 # the farm's top 3D node: the batch lies in its space
var _where: Array[Transform3D] = []   # each slot's place and strength as last put, kept here too (the engine's
var _strength := PackedFloat32Array()  # copy can't be read back on every renderer, and growing clears it)


## The batch for the farm `anchor` stands in (made on first use).
static func of(anchor: Node3D) -> ContactShades:
	var top: Node3D = anchor
	while top.get_parent() is Node3D:
		top = top.get_parent()
	var key := top.get_instance_id()
	var have: Variant = _batches.get(key)
	if have != null and is_instance_valid(have):
		return have
	var made := ContactShades.new()
	made._top = top
	top.add_child.call_deferred(made)   # (the farm may be busy adding the animal that asked)
	_batches[key] = made
	return made


func _init() -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/contact3d.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE           # each slot's transform stretches it to its animal
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = plane
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-REACH, -REACH, -REACH), Vector3.ONE * REACH * 2.0)


## A slot of its own for one animal's shade (invisible until `put`).
func take() -> int:
	if not _free.is_empty():
		return _free.pop_back()
	if _used >= multimesh.instance_count:
		_grow()
	_used += 1
	return _used - 1


## Where a slot's shade lies (in this batch's space, which is the farm's) and how strong it is (0..1).
func put(slot: int, where: Transform3D, strength: float) -> void:
	if slot < 0 or slot >= multimesh.instance_count:
		return
	var local := _top.global_transform.affine_inverse() * where
	multimesh.set_instance_transform(slot, local)
	multimesh.set_instance_color(slot, Color(1, 1, 1, strength))
	_where[slot] = local
	_strength[slot] = strength


## Where a slot's shade lies, in the farm's space, and how strong it is (0 when hidden or free).
func where_of(slot: int) -> Vector3:
	return _where[slot].origin if slot >= 0 and slot < _where.size() else Vector3.ZERO


func strength_of(slot: int) -> float:
	return _strength[slot] if slot >= 0 and slot < _strength.size() else 0.0


## The animal has gone: its slot is hidden and kept for the next one.
func give_back(slot: int) -> void:
	if slot < 0 or slot >= multimesh.instance_count:
		return
	_hide(slot)
	_free.append(slot)


func _hide(slot: int) -> void:
	var gone := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	multimesh.set_instance_transform(slot, gone)
	multimesh.set_instance_color(slot, Color(1, 1, 1, 0))
	_where[slot] = gone
	_strength[slot] = 0.0


## Room for CHUNK more slots, keeping every shade already there (setting the count clears the engine's copy, so
## the kept ones are put back from ours).
func _grow() -> void:
	var old := multimesh.instance_count
	multimesh.instance_count = old + CHUNK
	_where.resize(old + CHUNK)
	_strength.resize(old + CHUNK)
	for s in old:
		multimesh.set_instance_transform(s, _where[s])
		multimesh.set_instance_color(s, Color(1, 1, 1, _strength[s]))
	for s in range(old, old + CHUNK):
		_hide(s)


func _exit_tree() -> void:
	for key: int in _batches.keys():
		if _batches[key] == self:
			_batches.erase(key)
