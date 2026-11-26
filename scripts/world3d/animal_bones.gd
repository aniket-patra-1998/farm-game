class_name AnimalBones
extends RefCounted
## The bones of an animal made as a file, and its moves (tools/animal_art's export.py `_rigged`). A file used to
## hold every move as a second copy of the whole mesh (17 of them: nine tenths of the file); now each point
## follows up to four bones, and a move says how far each bone goes from where it rests. The game adds the moves
## it wants bone by bone (`want`, `pose`): rest + each move's change x its strength, the very sum the stored
## copies gave point by point, so an animal moves as it did.
##
## A bone's place here is any 3x4 (a sum of moves stretches and leans a bone, which a Skeleton3D's turn-and-size
## poses can't hold), so the bones are the renderer's own (a RenderingServer skeleton this object keeps and
## frees), not a Skeleton3D node's: the one the file comes with is left idle.

const EXTRAS := "extras"        # where a file's node keeps what its exporter wrote beside the mesh
const KEPT := "animal_moves"    # where a mesh keeps its moves once read (every animal of the kind shares them)
const AXES := 4                 # a bone's place: its three axes and where it is
const WALK := "walk_"           # a walk frame's move: walk_00, walk_01..


var moves: Moves
var _skeleton := RID()
var _want := PackedFloat32Array()   # how much of each move is wanted now
var _stale := true                  # the bones are not yet where `_want` puts them


## A kind's moves, as read from its file once: shared by every animal of the kind.
class Moves:
	extends RefCounted
	var rest := PackedVector3Array()            # every bone as the animal stands (AXES vectors each)
	var names: Array[String] = []               # the moves, in the file's order
	var where: Array[PackedInt32Array] = []     # for each move: the bones it carries (each as its place in `rest`)
	var change: Array[PackedVector3Array] = []  # ..and how far it carries each (AXES vectors a bone)
	var box := AABB()                           # the animal as it stands (what its sizes are measured by)

	func bones() -> int:
		return rest.size() / AnimalBones.AXES

	## Where the point `at`, following `bones` by `weights` (four of each, from `first`), is with move `k` at
	## full strength and no other (k -1: as the animal stands).
	func moved(at: Vector3, bones: PackedInt32Array, weights: PackedFloat32Array, first: int, k: int) -> Vector3:
		var out := Vector3.ZERO
		for j in 4:
			var w := weights[first + j]
			if w <= 0.0:
				continue
			var o := bones[first + j] * AnimalBones.AXES
			var x := rest[o]
			var y := rest[o + 1]
			var z := rest[o + 2]
			var origin := rest[o + 3]
			var mine := where[k].find(o) if k >= 0 else -1
			if mine >= 0:
				var c := change[k]
				x += c[mine * AnimalBones.AXES]
				y += c[mine * AnimalBones.AXES + 1]
				z += c[mine * AnimalBones.AXES + 2]
				origin += c[mine * AnimalBones.AXES + 3]
			out += (x * at.x + y * at.y + z * at.z + origin) * w
		return out


## The bones of the animal file drawn by `mi`, or null when its file has none (a mesh that only stands). The
## Skeleton3D the file came with is left idle: `mi` no longer follows it.
static func of(mi: MeshInstance3D) -> AnimalBones:
	var kind := moves_of(mi)
	if kind == null:
		return null
	mi.skin = null
	mi.skeleton = NodePath()
	var out := AnimalBones.new()
	out.moves = kind
	out._want.resize(kind.names.size())
	return out


## Another animal's own bones for the same kind (a copy of an animal shares its mesh, never its pose).
func another() -> AnimalBones:
	var out := AnimalBones.new()
	out.moves = moves
	out._want.resize(moves.names.size())
	return out


## The moves of the file drawn by `mi` (read once a mesh), or null when it has none.
static func moves_of(mi: MeshInstance3D) -> Moves:
	if mi == null or mi.mesh == null:
		return null
	if mi.mesh.has_meta(KEPT):
		return mi.mesh.get_meta(KEPT)
	var wrote: Variant = mi.get_meta(EXTRAS) if mi.has_meta(EXTRAS) else null
	if not wrote is Dictionary or not (wrote as Dictionary).has("rest"):
		return null
	var kind := Moves.new()
	for bone: Array in wrote["rest"]:
		kind.rest.append_array(_axes(bone))
	var by_move: Dictionary = wrote["moves"]
	for move: String in by_move:
		var bones := PackedInt32Array()
		var far := PackedVector3Array()
		var carried: Dictionary = by_move[move]
		for bone: String in carried:
			bones.append(int(bone) * AXES)
			far.append_array(_axes(carried[bone]))
		kind.names.append(move)
		kind.where.append(bones)
		kind.change.append(far)
	var box: Array = wrote["box"]
	var low := Vector3(float(box[0][0]), float(box[0][1]), float(box[0][2]))
	kind.box = AABB(low, Vector3(float(box[1][0]), float(box[1][1]), float(box[1][2])) - low)
	mi.mesh.set_meta(KEPT, kind)
	return kind


## The box of the animal drawn by `mi` as it stands: its file's own word when it has bones (a mesh's box is of
## its points as built, before its bones stand it up), else the mesh's.
static func box_of(mi: MeshInstance3D) -> AABB:
	var kind := moves_of(mi)
	return kind.box if kind != null else mi.get_aabb()


## Which move is called `move` (-1: the file has none of that name).
func index(move: String) -> int:
	return moves.names.find(move)


## Asks for `weight` of move `k` (as a blend shape's weight was set).
func want(k: int, weight: float) -> void:
	if _want[k] != weight:
		_want[k] = weight
		_stale = true


## Puts `mi`'s bones where the wanted moves add up to. Nothing to work out when nothing was asked since the last.
func pose(mi: MeshInstance3D) -> void:
	if not _skeleton.is_valid():
		_skeleton = RenderingServer.skeleton_create()
		RenderingServer.skeleton_allocate_data(_skeleton, moves.bones())
	# (A MeshInstance3D lets go of what it draws on each time it enters the tree: asked again, at no cost.)
	RenderingServer.instance_attach_skeleton(mi.get_instance(), _skeleton)
	if not _stale:
		return
	_stale = false
	var at := places()
	for b in moves.bones():
		var o := b * AXES
		RenderingServer.skeleton_bone_set_transform(_skeleton, b, Transform3D(at[o], at[o + 1], at[o + 2], at[o + 3]))


## Every bone's place for the moves wanted now (AXES vectors a bone): where it rests, and each wanted move's
## change by its strength.
func places() -> PackedVector3Array:
	var at := moves.rest.duplicate()
	for k in _want.size():
		var w := _want[k]
		if w == 0.0:
			continue
		var bones := moves.where[k]
		var far := moves.change[k]
		for j in bones.size():
			var o := bones[j]
			var c := j * AXES
			at[o] += far[c] * w
			at[o + 1] += far[c + 1] * w
			at[o + 2] += far[c + 2] * w
			at[o + 3] += far[c + 3] * w
	return at


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _skeleton.is_valid():
		RenderingServer.free_rid(_skeleton)


static func _axes(numbers: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in AXES:
		out.append(Vector3(float(numbers[k * 3]), float(numbers[k * 3 + 1]), float(numbers[k * 3 + 2])))
	return out
