class_name SleepMarks
extends MultiMeshInstance3D
## The little "z z z" over every sleeping animal's nose (owner, 20 Nov): three small z's rising one after another,
## growing and fading (shaders/sleep3d.gdshader). One draw for all of them, as the ready and rust signs are.
## Animal3D says who is asleep in its sleeping pose (`sleepers`) and where its nose is then (`nose_asleep`); an
## animal with no sleeping pose of its own (one built by code, a bee) has none. For show: nothing here changes
## the game. Farm3D adds one.

const SHADER := "res://shaders/sleep3d.gdshader"
const SIZE := 0.36            # the quad's side in tiles: the z's rise this far up and across from the nose
const MOST := 96              # sleepers shown at once (a farm's every animal is fewer on screen)
const SPREAD := 0.618         # each sleeper's phase, from its own number, so they are not in step

var _where: Array[Vector3] = []   # where each z z z is (a CPU copy: the GPU's can't be read back everywhere)


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SIZE
	quad.center_offset = Vector3(SIZE * 0.5, SIZE * 0.5, 0.0)   # (its bottom left corner is the nose)
	var material := ShaderMaterial.new()
	material.shader = load(SHADER)
	quad.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = MOST
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (The z's rise above the animals they are placed at: never culled by the batch's first box.)
	custom_aabb = AABB(Vector3(-1000, -10, -1000), Vector3(2000, 100, 2000))
	visible = false


func _process(_delta: float) -> void:
	show_over(Animal3D.sleepers)


## Puts a "z z z" at the nose of each of `sleepers` that is on the farm and whose nose is known; returns how many.
func show_over(sleepers: Array[Animal3D]) -> int:
	var n := 0
	_where.clear()
	for a in sleepers:
		if n >= MOST:
			break
		if not is_instance_valid(a) or not a.is_inside_tree() or not a.is_visible_in_tree():
			continue
		var nose := a.nose_asleep()
		if not nose.is_finite():
			continue
		_where.append(to_local(nose))
		multimesh.set_instance_transform(n, Transform3D(Basis.IDENTITY, _where[n]))
		multimesh.set_instance_custom_data(n, Color(fposmod(a.get_instance_id() * SPREAD, 1.0), 0, 0, 0))
		n += 1
	multimesh.visible_instance_count = n
	visible = n > 0
	return n


## Where z z z number `k` is (in this node's own space).
func where(k: int) -> Vector3:
	return _where[k]
