class_name GateSign
extends RefCounted
## The signboard at an animal home's gate (owner, 26 Nov: "a signboard with the animal icon for each building...
## the same icons [as] in the Market"): a board hanging from the arm of a post, with the animal's own Market
## picture on it (ItemIcons), swaying a little in the wind (shaders/sign3d.gdshader reads the shared `wind`).
## A building's model has the post, its lantern and a mark where the board hangs (a part named `sign_cow`:
## BuildingModel "gate_sign"); a picture is made on the phone, so no file can carry it: the game hangs the
## board there (`hang`, `hang_on`). One draw a home; every home of an animal shares one material.

const MARK := "sign"              # a model's part that marks where its board hangs (its name carries the animal)
const SHADER := "res://shaders/sign3d.gdshader"
const SIZE := Vector3(0.5, 0.42, 0.03)   # the board: across, down from the arm, thick (tiles)
const DROP := 0.03                # how far under the arm the board's top edge hangs (its two short chains)

static var _mesh: ArrayMesh
static var _materials := {}       # animal -> the material of its boards


## The name of the part that marks where `animal`'s board hangs.
static func mark_name(animal: String) -> String:
	return "%s_%s" % [MARK, animal]


## Which animal the mark `n` is for ("" when it is not a sign's mark).
static func animal_of(n: Node) -> String:
	var words := String(n.name).split("_", true, 1)
	return words[1] if words.size() == 2 and words[0] == MARK else ""


## Hangs the board on `model`'s mark: the farm does, for every home it shows (Objects3D), so a home's file and
## its picture in the Market are the model alone. Null when it has no mark.
static func hang(model: Node) -> MeshInstance3D:
	for c in model.find_children(MARK + "_*", "Node3D", true, false):   # not-ui (a part's name, a class)
		return hang_on(c as Node3D)
	return null


## Hangs the board on `mark` (once: a mark asked again keeps its board).
static func hang_on(mark: Node3D) -> MeshInstance3D:
	if mark.get_child_count() > 0:
		return mark.get_child(0) as MeshInstance3D
	var board := MeshInstance3D.new()
	board.mesh = mesh()
	board.material_override = material(animal_of(mark))
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_child(board)
	return board


## The board every sign shares: a thin box hanging down from its top edge (where it swings from). Its front
## face's UV runs over the picture; every other face's vertex colour says it has none.
static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := SIZE.x / 2.0
	var deep := SIZE.z / 2.0
	var lo := Vector3(-half, -DROP - SIZE.y, -deep)
	var hi := Vector3(half, -DROP, deep)
	# (each face: its normal, then its four corners, the first its top left as seen from outside)
	var faces := [
		[Vector3(0, 0, 1), Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z),
			Vector3(lo.x, lo.y, hi.z)],
		[Vector3(0, 0, -1), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, lo.y, lo.z),
			Vector3(hi.x, lo.y, lo.z)],
		[Vector3(1, 0, 0), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, lo.y, lo.z),
			Vector3(hi.x, lo.y, hi.z)],
		[Vector3(-1, 0, 0), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z),
			Vector3(lo.x, lo.y, lo.z)],
		[Vector3(0, 1, 0), Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z),
			Vector3(lo.x, hi.y, hi.z)],
		[Vector3(0, -1, 0), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z),
			Vector3(lo.x, lo.y, lo.z)],
	]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in faces.size():
		var face: Array = faces[k]
		var shows := Color(1, 1, 1) if k == 0 else Color(0, 0, 0)
		for corner: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(face[0])
			st.set_uv(uvs[corner])
			st.set_color(shows)
			st.add_vertex(face[1 + corner])
	_mesh = st.commit()
	return _mesh


## The material of every board that shows `animal`: its Market picture (blank until it is made, then there).
static func material(animal: String) -> ShaderMaterial:
	if not _materials.has(animal):
		var m := ShaderMaterial.new()
		m.shader = load(SHADER)
		m.set_shader_parameter("picture", ItemIcons.of(animal))
		_materials[animal] = m
	return _materials[animal]
