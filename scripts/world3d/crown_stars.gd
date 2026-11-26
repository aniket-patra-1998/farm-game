class_name CrownStars
extends MultiMeshInstance3D
## The gold star floating over every building at its biggest size (owner, 25 Nov: "a floating rotating star with
## a light glow... the same for all buildings, just the size will vary"): one star, turned and bobbed by its
## shader (shaders/crown_star3d.gdshader), with a soft halo behind it (crown_halo3d). Two draws for every star
## on the farm, as the ready and rust signs are one each; no building's own model carries a star, only a mark
## where its star floats (a part named `star_17`: a star 0.17 tiles in radius, at the top of its lead's roof:
## BuildingDress "crown"). Objects3D says where (`show_at`), from each finished building's mark (`mark_of`).
## For show: nothing here changes the game.

const MARK := "star"          # a model's part that marks its star (its name carries the radius, in hundredths)
const STAR_SHADER := "res://shaders/crown_star3d.gdshader"
const HALO_SHADER := "res://shaders/crown_halo3d.gdshader"
const WAIST := 0.45           # how far in the star's inner points are, of its radius..
const THICK := 0.21           # ..and half its thickness at the middle
const FLOAT := 1.7            # how high over the building's top the star's middle floats, in its own radii
const HALO := 5.0             # the halo's width, in the star's radii
const MOST := 64              # stars shown at once (a farm has fewer buildings at their biggest)
const SPREAD := 0.618         # each star's beat, from its number in the list, so no two turn in step

var _halo: MultiMeshInstance3D
var _tops: Array[Vector3] = []     # the roof tops last asked for, to tell when nothing has moved
var _where: Array[Vector3] = []    # where each star is and how big (a CPU copy: the GPU's can't be read back
var _radii: Array[float] = []      # on every renderer)


func _ready() -> void:
	multimesh = _batch(star_mesh(), STAR_SHADER)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE * HALO
	_halo = MultiMeshInstance3D.new()
	_halo.multimesh = _batch(disc, HALO_SHADER)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	# (The stars float above the buildings they are placed at: never culled by the batch's first box.)
	custom_aabb = AABB(Vector3(-1000, -10, -1000), Vector3(2000, 100, 2000))
	_halo.custom_aabb = custom_aabb
	visible = false


## A star over each of `tops` (the top of a building's lead, in this node's space), `radii` big; returns how many.
func show_at(tops: Array[Vector3], radii: Array[float]) -> int:
	var n := mini(tops.size(), MOST)
	if tops == _tops and radii == _radii:
		return n   # (asked again with nothing moved, as on every round of the farm's signs: nothing to send)
	_tops = tops.duplicate()
	_where.clear()
	_radii.clear()
	for k in n:
		var r := radii[k]
		_where.append(tops[k] + Vector3(0, r * FLOAT, 0))
		_radii.append(r)
		var place := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r), _where[k])
		var beat := Color(beat_of(k), 0, 0, 0)
		for batch: MultiMesh in [multimesh, _halo.multimesh]:
			batch.set_instance_transform(k, place)
			batch.set_instance_custom_data(k, beat)
	multimesh.visible_instance_count = n
	_halo.multimesh.visible_instance_count = n
	visible = n > 0
	return n


## Where star number `k` floats (in this node's own space), and its radius.
func where(k: int) -> Vector3:
	return _where[k]


func radius(k: int) -> float:
	return _radii[k]


## Where in its turn and bob star number `k` starts, 0 to 1: no two near each other move in step.
static func beat_of(k: int) -> float:
	return fposmod(k * SPREAD, 1.0)


## The star `model` is marked for: [the mark's node, the star's radius]; [] when it has none.
static func mark_of(model: Node) -> Array:
	for n in model.find_children(MARK + "_*", "Node3D", true, false):   # not-ui (a class)
		var words := String(n.name).split("_")
		if words.size() == 2 and words[1].is_valid_int():
			return [n, words[1].to_float() / 100.0]
	return []


## The star itself, a tile in radius: five points, thick at its middle, thin at its edge.
static func star_mesh() -> Mesh:
	var points: Array[Vector3] = []
	for k in 10:
		var reach := 1.0 if k % 2 == 0 else WAIST
		points.append(Vector3(sin(TAU * k / 10.0) * reach, cos(TAU * k / 10.0) * reach, 0))
	var sides: Array = []
	for k in 10:
		sides.append([points[k], points[(k + 1) % 10], Vector3(0, 0, THICK)])
		sides.append([points[(k + 1) % 10], points[k], Vector3(0, 0, -THICK)])
	var holder := Node3D.new()
	var made: Mesh = ModelKit.faces(holder, sides, Vector3.ZERO, null).mesh
	holder.free()
	return made


static func _batch(mesh: Mesh, shader_path: String) -> MultiMesh:
	var material := ShaderMaterial.new()
	material.shader = load(shader_path)
	mesh.surface_set_material(0, material)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	batch.mesh = mesh
	batch.instance_count = MOST
	batch.visible_instance_count = 0
	return batch
