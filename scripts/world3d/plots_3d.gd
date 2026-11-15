class_name Plots3D
extends Node3D
## Every plowed or planted plot as a raised bed of soil, drawn as one MultiMesh (one draw for the whole
## field): bevelled edges so beds read as mounds of earth, furrows along them, darker and damp where
## fertilized. Crops on top come from CropModels. One slot per tile, updated plot by plot (`update`).

const SOIL_SHADER := preload("res://shaders/soil3d.gdshader")
const BED := 0.9           # a bed's width, in tiles (the gaps between beds are grass)
const HEIGHT := 0.025        # how far a bed stands above the grass: barely (FarmVille's plots lie almost flush)
const BEVEL := 0.05         # how far in from its foot a bed's flat top begins (soil3d `top_half`: BED / 2 less this)
const BED_FLOATS := 16     # a bed in the MultiMesh buffer: transform (12) and data (4)

var _beds: MultiMeshInstance3D
var _size := -1       # the farm size the slots were laid out for
# Every slot as written (BED_FLOATS each): the one source of what the beds show, pushed to the MultiMesh (whose
# buffer can't be read back on every renderer).
var _buffer := PackedFloat32Array()


func _ready() -> void:
	_beds = MultiMeshInstance3D.new()
	_beds.material_override = soil_material()
	_beds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # flat: it only takes shadows
	add_child(_beds)
	rebuild()


## The soil's material (a fresh one: each holder sets its own wetness and such).
static func soil_material() -> ShaderMaterial:
	var soil := ShaderMaterial.new()
	soil.shader = SOIL_SHADER
	return soil


## Lays out every bed again (a new farm or a bigger one): one instance slot per tile, so a single plot can be
## changed later on its own (`update`). A grass tile's slot is shrunk to nothing.
func rebuild() -> void:
	var n := Game.farm_size
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = bed_mesh()
	mm.instance_count = n * n
	_buffer = PackedFloat32Array()
	_buffer.resize(n * n * BED_FLOATS)
	for r in n:
		for c in n:
			_write(_buffer, (r * n + c) * BED_FLOATS, r, c)
	mm.buffer = _buffer
	_beds.multimesh = mm
	_size = n


## Brings the beds of plots `indices` up to date, one slot each (the whole field when the farm's size changed).
func update(indices: Array) -> void:
	if _size != Game.farm_size or indices.is_empty():
		rebuild()
		return
	for i: int in indices:
		var r := GameState.row_of(i)
		var c := GameState.col_of(i)
		if r >= _size or c >= _size:
			continue
		var at := (r * _size + c) * BED_FLOATS
		_write(_buffer, at, r, c)
		var b := _buffer
		_beds.multimesh.set_instance_transform(at / BED_FLOATS, Transform3D(Basis(Vector3(b[at], b[at + 4], b[at + 8]),
			Vector3(b[at + 1], b[at + 5], b[at + 9]), Vector3(b[at + 2], b[at + 6], b[at + 10])),
			Vector3(b[at + 3], b[at + 7], b[at + 11])))
		_beds.multimesh.set_instance_custom_data(at / BED_FLOATS, Color(b[at + 12], b[at + 13], b[at + 14], b[at + 15]))


## Every bed slot as written (transform and data, BED_FLOATS each), to hold an updated field to a fresh one.
func buffer() -> PackedFloat32Array:
	return _buffer


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


## A bed of earth: low and flat on top, with a short slope down to the ground all round (the soil shader rounds
## its corners and draws its furrows), centred on its tile.
static func bed_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := BED / 2.0
	var t := w - BEVEL
	var h := HEIGHT
	_face(st, [Vector3(-t, h, -t), Vector3(t, h, -t), Vector3(t, h, t), Vector3(-t, h, t)])
	for k in 4:
		var rot := Basis(Vector3.UP, k * PI / 2.0)
		_face(st, [rot * Vector3(t, h, -t), rot * Vector3(w, 0, -w), rot * Vector3(w, 0, w), rot * Vector3(t, h, t)])
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
