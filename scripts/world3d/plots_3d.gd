class_name Plots3D
extends Node3D
## Every plowed or planted plot as a raised bed of soil, drawn as one MultiMesh (one draw for the whole
## field): bevelled edges so beds read as mounds of earth, furrows along them, darker and damp where
## fertilized. Crops on top come from CropModels. One slot per tile, updated plot by plot (`update`).

const BED := 0.9           # a bed's width, in tiles (the gaps between beds are grass)
const HEIGHT := 0.09
const BEVEL := 0.07
const BED_FLOATS := 16     # a bed in the MultiMesh buffer: transform (12) and data (4)

var _beds: MultiMeshInstance3D
var _size := -1       # the farm size the slots were laid out for
var _shown := PackedFloat32Array()   # each slot's size and fertilized mark, as last written (the GPU buffer can't be read back)


func _ready() -> void:
	_beds = MultiMeshInstance3D.new()
	var soil := ShaderMaterial.new()
	soil.shader = load("res://shaders/soil3d.gdshader")
	_beds.material_override = soil
	_beds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # flat: it only takes shadows
	add_child(_beds)
	rebuild()


## Lays out every bed again (a new farm or a bigger one): one instance slot per tile, so a single plot can be
## changed later on its own (`update`). A grass tile's slot is shrunk to nothing.
func rebuild() -> void:
	var n := Game.farm_size
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = bed_mesh()
	mm.instance_count = n * n
	var buffer := PackedFloat32Array()
	buffer.resize(n * n * BED_FLOATS)
	for r in n:
		for c in n:
			_write(buffer, (r * n + c) * BED_FLOATS, r, c)
	mm.buffer = buffer
	_shown = PackedFloat32Array()
	_shown.resize(n * n * 2)
	for slot in n * n:
		_shown[slot * 2] = buffer[slot * BED_FLOATS]
		_shown[slot * 2 + 1] = buffer[slot * BED_FLOATS + 15]
	_beds.multimesh = mm
	_size = n


## Brings the beds of plots `indices` up to date, one slot each (the whole field when the farm's size changed).
func update(indices: Array) -> void:
	if _size != Game.farm_size or indices.is_empty():
		rebuild()
		return
	var one := PackedFloat32Array()
	one.resize(BED_FLOATS)
	for i: int in indices:
		var r := int(i / float(GameState.MAX_SIZE))
		var c := i % GameState.MAX_SIZE
		if r >= _size or c >= _size:
			continue
		_write(one, 0, r, c)
		var slot := r * _size + c
		_beds.multimesh.set_instance_transform(slot, Transform3D(Basis(Vector3(one[0], one[4], one[8]),
			Vector3(one[1], one[5], one[9]), Vector3(one[2], one[6], one[10])), Vector3(one[3], one[7], one[11])))
		_beds.multimesh.set_instance_custom_data(slot, Color(one[12], one[13], one[14], one[15]))
		_shown[slot * 2] = one[0]
		_shown[slot * 2 + 1] = one[15]


## What the beds show, slot by slot: [size, fertilized] pairs (to compare an updated field with a fresh one).
func shown() -> PackedFloat32Array:
	return _shown


## Tile (r, c)'s bed into `buffer` at `at`: its transform (shrunk to nothing on grass) and whether it's fertilized.
static func _write(buffer: PackedFloat32Array, at: int, r: int, c: int) -> void:
	var i := Game.index_of(r, c)
	var bed: bool = Game.plots[i].get("state", "grass") != "grass"
	var s := 1.0 if bed else 0.0
	var p := IsoProjection.tile_centre(r, c)
	var row := [s, 0.0, 0.0, p.x, 0.0, s, 0.0, p.y, 0.0, 0.0, s, p.z,
		0.0, 0.0, 0.0, 1.0 if bed and Game.field.is_fertilized(i) else 0.0]
	for k in BED_FLOATS:
		buffer[at + k] = row[k]


## A bed of earth: a low box with bevelled top edges, centred on its tile, sitting on the ground.
static func bed_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := BED / 2.0
	var t := w - BEVEL
	var h := HEIGHT
	var lo := h - BEVEL * 0.6
	# Top face.
	_face(st, [Vector3(-t, h, -t), Vector3(t, h, -t), Vector3(t, h, t), Vector3(-t, h, t)])
	# Bevels and sides, all four ways round.
	for k in 4:
		var rot := Basis(Vector3.UP, k * PI / 2.0)
		_face(st, [rot * Vector3(t, h, -t), rot * Vector3(w, lo, -w), rot * Vector3(w, lo, w), rot * Vector3(t, h, t)])
		_face(st, [rot * Vector3(w, lo, -w), rot * Vector3(w, 0, -w), rot * Vector3(w, 0, w), rot * Vector3(w, lo, w)])
	return st.commit()


## A flat four-sided face, with its normal pointing out of the bed (whichever way round it was given).
static func _face(st: SurfaceTool, v: Array) -> void:
	var a: Vector3 = v[0]
	var b: Vector3 = v[1]
	var c: Vector3 = v[2]
	var d: Vector3 = v[3]
	var n := (b - a).cross(c - a).normalized()
	var centre := (a + b + c + d) / 4.0
	if n.dot(centre - Vector3(0, HEIGHT * 0.5, 0)) < 0.0:
		n = -n
	st.set_normal(n)
	for idx: int in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(v[idx])
