class_name Plots3D
extends Node3D
## Every plowed or planted plot as a raised bed of soil, drawn as one MultiMesh (one draw for the whole
## field): bevelled edges so beds read as mounds of earth, furrows along them, darker and damp where
## fertilized. Crops on top come from CropModels. Rebuilt when plots change.

const BED := 0.9           # a bed's width, in tiles (the gaps between beds are grass)
const HEIGHT := 0.09
const BEVEL := 0.07

var _beds: MultiMeshInstance3D


func _ready() -> void:
	_beds = MultiMeshInstance3D.new()
	var soil := ShaderMaterial.new()
	soil.shader = load("res://shaders/soil3d.gdshader")
	_beds.material_override = soil
	_beds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # flat: it only takes shadows
	add_child(_beds)
	rebuild()


func rebuild() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = bed_mesh()
	var cells: Array[Vector3i] = []
	var n := Game.farm_size
	for r in n:
		for c in n:
			var i := Game.index_of(r, c)
			if Game.plots[i].get("state", "grass") != "grass":
				cells.append(Vector3i(r, c, i))
	mm.instance_count = cells.size()
	for k in cells.size():
		var cell := cells[k]
		mm.set_instance_transform(k, Transform3D(Basis(), IsoProjection.tile_centre(cell.x, cell.y)))
		mm.set_instance_custom_data(k, Color(0, 0, 0, 1.0 if Game.field.is_fertilized(cell.z) else 0.0))
	_beds.multimesh = mm


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
