class_name ReadyMarks
extends MultiMeshInstance3D
## FarmVille's "ready" sign over every building with something to collect: a golden sparkle above its roof,
## bobbing and twinkling (shaders/ready3d.gdshader), seen across the whole farm. One MultiMesh for all of them,
## so a farm of ready buildings is one draw; Objects3D says where (`show_at`) when it looks at the farm, and the
## camera's zoom keeps them a steady size on screen (`follow`).

const SIZE := 0.75            # the sparkle's width in tiles, at the nearest zoom
const ABOVE := 0.32           # how far above a building's top it floats, in tiles
const ZOOM_REF := 9.0         # the camera size (tiles on screen) the sparkle is drawn at SIZE for
const ZOOM_MOST := 3.0        # and the most it grows by when the camera pulls back

var _material: ShaderMaterial
var _tops: Array[Vector3] = []


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/ready3d.gdshader")
	_material.render_priority = 2   # (after the farm: it draws over what stands in front)
	material_override = _material
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SIZE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.use_colors = true   # (the compatibility renderer reads an unset instance colour as black)
	multimesh.mesh = quad


## Shows a sparkle over each of `tops` (the top centre of each ready building), and none elsewhere.
func show_at(tops: Array[Vector3]) -> void:
	if tops == _tops:
		return
	_tops = tops.duplicate()
	multimesh.instance_count = tops.size()
	for k in tops.size():
		multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, tops[k] + Vector3(0, ABOVE, 0)))
		multimesh.set_instance_custom_data(k, Color(fposmod(tops[k].x * 0.37 + tops[k].z * 0.61, 1.0), 0, 0, 0))
		multimesh.set_instance_color(k, Color.WHITE)
	visible = not tops.is_empty()


## How many sparkles are showing.
func count() -> int:
	return _tops.size()


## Keeps the sparkles a steady size on screen as an orthographic camera of `camera_size` zooms.
func follow(camera_size: float) -> void:
	_material.set_shader_parameter("zoom", clampf(camera_size / ZOOM_REF, 1.0, ZOOM_MOST))
