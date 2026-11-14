class_name ReadyMarks
extends MultiMeshInstance3D
## The one "ready" sign over everything with something to collect, FarmVille's way: a soft, light pink
## triangle pointing down, hovering and bobbing gently (shaders/ready3d.gdshader). Buildings, trees, blooms and
## animals all wear the same one, so the farm reads at a glance and it costs one draw for all of them.
## Objects3D says where: `show_at` for what stands still (over its top) and `follow_animals` for animals, whose
## signs move with them each frame. The camera's zoom keeps them a steady size on screen (`follow`).

const SIZE := 0.42            # the sign's width in tiles, at the nearest zoom
const ABOVE := 0.3            # how far above a thing's top it hovers, in tiles
const ZOOM_REF := 9.0         # the camera size (tiles on screen) the sign is drawn at SIZE for
const ZOOM_MOST := 3.0        # and the most it grows by when the camera pulls back

var _material: ShaderMaterial
var _tops: Array[Vector3] = []          # signs over what stands still
var _animals: Array[Animal3D] = []      # and over these, wherever they walk
var _zoom := -1.0
var _animal_at: Array[Vector3] = []     # where each animal's sign was last put
var _where: Array[Vector3] = []         # where each sign is (a CPU copy: the GPU's can't be read back everywhere)


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


## Shows a sign over each of `tops` (the top centre of each ready thing that stands still) and over each of
## `animals`, and none elsewhere.
func show_at(tops: Array[Vector3], animals: Array[Animal3D] = []) -> void:
	if tops == _tops and animals == _animals:
		return
	_tops = tops.duplicate()
	_animals = animals.duplicate()
	multimesh.instance_count = tops.size() + animals.size()
	_where.resize(multimesh.instance_count)
	for k in tops.size():
		_put(k, tops[k], fposmod(tops[k].x * 0.37 + tops[k].z * 0.61, 1.0))
	_animal_at.resize(animals.size())
	for k in animals.size():
		_animal_at[k] = Vector3.INF
		multimesh.set_instance_custom_data(tops.size() + k, Color(fposmod(k * 0.618, 1.0), 0, 0, 0))
		multimesh.set_instance_color(tops.size() + k, Color.WHITE)
	follow_animals()
	visible = multimesh.instance_count > 0


## Moves the animals' signs to where the animals are now (each frame; only ready animals have one, and only one
## that has moved is touched).
func follow_animals() -> void:
	var first := _tops.size()
	for k in _animals.size():
		var a := _animals[k]
		if not is_instance_valid(a):
			if _animal_at[k] != Vector3.ZERO:   # gone (sold, lifted): its sign shrinks to nothing till the next sync
				_animal_at[k] = Vector3.ZERO
				multimesh.set_instance_transform(first + k, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		if not a.visible or not a.is_visible_in_tree():
			continue
		var target := a.position + Vector3(0, a.reach().y + ABOVE, 0)
		if target.is_equal_approx(_animal_at[k]):
			continue
		_animal_at[k] = target
		_where[first + k] = target
		multimesh.set_instance_transform(first + k, Transform3D(Basis.IDENTITY, target))


## Sign `k` over `top`, bobbing at `phase` (0..1: a thing keeps its own beat, so they don't bob in step).
func _put(k: int, top: Vector3, phase: float) -> void:
	_where[k] = top + Vector3(0, ABOVE, 0)
	multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, _where[k]))
	multimesh.set_instance_custom_data(k, Color(phase, 0, 0, 0))
	multimesh.set_instance_color(k, Color.WHITE)


## Where sign `k` hovers (the still ones first, then the animals').
func where(k: int) -> Vector3:
	return _where[k]


## How many signs are showing.
func count() -> int:
	return _tops.size() + _animals.size()


## Keeps the signs a steady size on screen as an orthographic camera of `camera_size` zooms.
func follow(camera_size: float) -> void:
	var zoom := clampf(camera_size / ZOOM_REF, 1.0, ZOOM_MOST)
	if not is_equal_approx(zoom, _zoom):
		_zoom = zoom
		_material.set_shader_parameter("zoom", zoom)
