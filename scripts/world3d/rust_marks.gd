class_name RustMarks
extends MultiMeshInstance3D
## The rust sign over every rusty vehicle (docs/RUST.md; our own touch): a bubble with a broken gear, coloured
## by how bad the rust is, and a pip for each level (shaders/rust3d.gdshader). One draw for all of them, as the
## ready signs (ReadyMarks), and kept a steady size on screen the same way (`follow`). Objects3D says where:
## over a vehicle standing outside, or over the Garage it stands in. A tap on a sign offers that vehicle's
## repair (`pick`).

const SIZE := 0.6             # the sign's width in tiles, at the nearest zoom
const ABOVE := 0.3            # how far above a thing's top its middle hovers, in tiles

var _material: ShaderMaterial
var _where: Array[Vector3] = []     # where each sign is (a CPU copy: the GPU's can't be read back everywhere)
var _ids: Array[String] = []        # the vehicle each is for
var _shares: Array[float] = []      # its rust, as a share of the most there is
var _mends: Array[float] = []       # how far its repair is (0: not being repaired)
var _zoom := 1.0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/rust3d.gdshader")
	_material.render_priority = 2   # (after the farm: it draws over what stands in front)
	material_override = _material
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SIZE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.use_colors = true   # (the compatibility renderer reads an unset instance colour as black)
	multimesh.mesh = quad
	visible = false


## Shows a sign over each of `tops` (the top centre of a rusty vehicle, or of the Garage it stands in) and none
## elsewhere: `ids` the vehicles, `shares` each one's rust as a share of the most there is (0..1).
## `mends`: for each sign, how far its thing's repair is (0: not in for one; a building being repaired keeps its
## sign, mended gear turning and its pips filling: docs/WEAR.md).
func show_at(tops: Array[Vector3], ids: Array[String], shares: Array[float], mends: Array[float] = []) -> void:
	var where: Array[Vector3] = []
	for top in tops:
		where.append(top + Vector3(0, ABOVE, 0))
	if where == _where and ids == _ids and shares == _shares and mends == _mends:
		return
	_where = where
	_ids = ids.duplicate()
	_shares = shares.duplicate()
	_mends = mends.duplicate()
	multimesh.instance_count = where.size()
	for k in where.size():
		multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, where[k]))
		multimesh.set_instance_custom_data(k, Color(shares[k], mends[k] if k < mends.size() else 0.0, 0, 0))
		multimesh.set_instance_color(k, Color.WHITE)
	visible = not where.is_empty()


## The vehicles that wear a sign, and each one's rust as a share of the most.
func ids() -> Array[String]:
	return _ids


func shares() -> Array[float]:
	return _shares


## ..and how far each one's repair is (0: not being repaired).
func mends() -> Array[float]:
	return _mends


## Where sign `k` hovers.
func where(k: int) -> Vector3:
	return _where[k]


## Keeps the signs a steady size on screen as an orthographic camera of `camera_size` zooms (as the ready signs).
func follow(camera_size: float) -> void:
	var zoom := clampf(camera_size / ReadyMarks.ZOOM_REF, 1.0, ReadyMarks.ZOOM_MOST)
	if not is_equal_approx(zoom, _zoom):
		_zoom = zoom
		_material.set_shader_parameter("zoom", zoom)


## The vehicle whose sign is under a screen point ("" if none): anywhere on the sign counts, a finger's worth.
func pick(camera: Camera3D, screen_pos: Vector2) -> String:
	var side := camera.global_transform.basis.x * (SIZE / 2.0 * _zoom)
	for k in _where.size():
		var middle := camera.unproject_position(_where[k])
		if screen_pos.distance_to(middle) <= middle.distance_to(camera.unproject_position(_where[k] + side)):
			return _ids[k]
	return ""
