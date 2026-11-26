class_name Animal3D
extends Node3D
## An animal in 3D, built from its rig (data/animal_rigs.json, through AnimalRig) and moved every frame by
## the same AnimalBehaviour that drives the 2D animal: one mind, two bodies. A four-legged animal has a
## body, a neck and head that lower to graze, four legs with knees that walk a planted-foot gait, ears,
## eyes, a tail that swishes; a bird has two legs, a bobbing head, wings that open; rabbits hop, turtles
## paddle, bees hover. Proportions (and so babies' big heads and long legs) all come from the rig.
##
## Local space: the animal faces +x, up is +y, its left side is -z. Sizes are the rig's pixels (made for a
## 128-pixel tile) times PX, so a cow is a little over half a tile long.

const PX := 1.9 / IsoProjection.PX_PER_UNIT    # rig pixels to world units (a cow is about a tile long, as in FarmVille)
const TURN_RATE := 3.5                          # how fast it turns to face where it's going (radians/s)
const SHUFFLE_REACH := 0.1                      # its feet's travel for each radian it turns, as a share of its length
const FEET_SHARE := 0.06                        # of a file-made animal's height, from the ground up, that is its feet
## The two ways an animal stands when still: side-on to the camera, turned a little toward it (FarmVille's
## three-quarter view), facing screen right or screen left. 0 faces +x; screen right is +x -z (pi/4).
const REST_RIGHT := PI / 12.0
const REST_LEFT := PI * 17.0 / 12.0
const SETTLE_RATE := 1.2                        # how fast it eases round to stand side-on (radians/s)
const FLOAT_SINK := 0.22                        # how much of its height is under the water when it swims
const FLOAT_EASE := 3.0                         # how fast it settles into the water or steps out (per second)
const DABBLE_EASE := 1.4                        # how fast a swimmer tips under to feed and comes up (per second):
                                                # it stays under for the whole of its feeding, as a duck does
const DABBLE_TIP := 1.15                        # radians a swimmer tips forward when it dabbles: head under, tail up
const EYE := Color("#1b140f")
const HOOF := Color("#3a2c22")
const PINK := Color("#eba9a3")
const BEAK := Color("#f2a33a")
const COMB := Color("#d8382f")
const LEG_NAMES := ["hind_far", "fore_far", "hind_near", "fore_near"]

const LEG_PHASES := [0.5, 0.75, 0.0, 0.25]      # the four-beat walk, as in QuadrupedArt
const CONTACT_SPREAD := 1.25                    # the contact shade reaches this far past the body

const CONTACT_LIFT := 0.012                     # just above the grass, so it never flickers into it


## The animation budget: this many animals on screen are posed every frame; past it, each is posed every
## 2nd, 3rd or 4th frame in turn (round-robin, so the work is spread evenly), holding its pose between.
## The usual mobile budget is 10-20 fully animated characters; the minds still think every frame.
const FULL_RATE := 16
const MAX_STRIDE := 4
## Animals posed in one frame at most: a pan that brings a crowd into view at once (the stride is set by the frame
## before, when few were in view) posed 200 in one frame, a 242 ms stall on a PC; the rest wait a frame or two.
const POSES_MOST := FULL_RATE * 2
const SLOTS := 64                 # turns an animal's slot is taken from (strides up to this space them evenly)
const PENDING_MOST := 0.5         # seconds a late pose catches up at most (never a jump of seconds at once)
const STRIDES := "res://data/animal_strides.json"   # every kind's file_stride, kept (tools/animal_strides)
const NOSES := "res://data/animal_sleep.json"       # where each kind's nose is asleep (tools/animal_art's export)
const MESH_MOVE := 1000           # in _file_shapes: from here up, a blend shape of the mesh (a long coat's shake)
const SLEEP_MOVE := "sleep"       # a file's sleeping pose (tools/animal_art: motion.asleep)   # not-ui
const ASLEEP := 0.85              # how far into its sleeping pose an animal counts as asleep (its "z z z" shows)
const BEE_BEAT_RATE := 60.0      # a file-made bee's wing beats (radians of the beat a second)..
const BEE_HOVER_RATE := 3.3      # ..and its slow bob in the air (as tools/animal_art's motion)
const BEE_HOVER := 0.4           # how high the bob goes, as a share of its body's height
const PICK_PAD := 0.04           # tiles added round an animal's body for a tap
const PICK_MIN := 0.14           # the least half-width of a tap box (a chick is still easy to tap)


## Animals are posed at least this many frames apart (the graphics quality's `pose_every`, Quality).
static var min_stride := 1
## Whether animals are posed at all: off, each stands as it is, still drawn (the phone benchmark turns it off for a
## moment to say what posing them costs the GPU: LoadBenchmark's `animals_posing`).
static var posing := true
static var _frame := -1          # the frame _seen counts
static var _seen := 0            # animals on screen so far this frame
static var _lengths := {}         # animal id -> its file's length (file_length)
static var _strides := {}         # animal id -> the ground one cycle of its file's walk covers (file_stride)
## The animals asleep in their sleeping pose just now (SleepMarks draws a "z z z" at each one's nose).
static var sleepers: Array[Animal3D] = []
static var _noses := {}           # animal id -> its nose asleep, in its model's own space (NOSES), read once
static var _walk_moves: Array[String] = []   # walk frame -> its move's name (walk_move)
static var _kept := {}            # animal id -> {"file": fingerprint, "stride": ..} (STRIDES, read once)

static var _seen_last := 0       # and last frame, which sets this frame's stride
static var _posed := 0           # animals posed so far this frame (at most POSES_MOST)



static var _templates := {}       # "id|size" -> the first animal built of it, never on screen (copied)
var rig: AnimalRig
## Its mind, owned and updated by FarmLife (told, when it is given, whether this model sleeps its own way).
var behaviour: AnimalBehaviour: set = _set_behaviour
var motion: AnimalMotion         # its body's weight: leaning, swaying, lagging, settling (3D only)
var heading := 0.0               # radians around +y; 0 faces +x

var home := Vector3.ZERO         # the tile centre it wanders around

var drop := 0.0                  # height above the ground while dropping in (tweened by land())
var afloat := false              # it is on water (BuildingFill says so): it swims low and dabbles, not pecks
var float_share := 0.0           # how far it has settled into the water, 0..1
var dabble := 0.0                # how far a swimmer has tipped forward to feed, 0..1

var _body: Node3D
var _head: Node3D
var _neck: MeshInstance3D
var _tail: Node3D
var _legs: Array[Dictionary] = []   # {"hip": Vector3, "upper": MeshInstance3D, "lower": MeshInstance3D, ...}
var _wings: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _last := Vector3.ZERO
var _r := Vector3.ONE            # body half-sizes (length, height, width)

var _leg := 0.2
var _contact: Node3D             # where the soft shade on the grass right under it lies (drawn by ContactShades)
var _contact_size := Vector2.ONE  # its size on the ground
var _contact_strength := 1.0
var _shades: ContactShades        # the farm's batch of shades, and this animal's slot in it
var _shade_slot := -1
var _eyes: Array[Node3D] = []    # (they blink)
var _walk_speed := 1.0           # its walking speed, in units a second
var _skeleton: Skeleton3D        # the whole animal is one skinned mesh on this (see _skin)
var _casting: MeshInstance3D     # its part that may cast a real shadow (the graphics level's `animal_shadows`)
var _bones: Array[Node3D] = []   # the part nodes the pose code moves, by bone index; copied to the bones
var _slot := 0                   # its turn in the round-robin when posed less than every frame

var _pending := 0.0              # time not yet posed (while waiting its turn)
var _owed := false               # its turn came in a frame already full of poses (POSES_MOST): next frame, first
var _id := ""                    # its catalog id (for its file, AssetRegistry)
var _size := 1.0                 # how big it is drawn (smaller in a small yard)
var _file_mesh: MeshInstance3D   # made as a file: the mesh its moves pose (null when built)
var _file_bones: AnimalBones     # ..its bones, which most of its moves move (null: the file has none)
var _file_shapes := {}           # a move's name -> its number in _file_bones, or MESH_MOVE + its blend shape's
var _walk_frames := 0            # how many walk_NN moves the file has (the cycle is cut into that many)
var _shaking := 0.0               # how far through a shake of its coat it last was (AnimalPose.shake)
var _fluff: DustPuffs             # the tufts its shakes let go (made at its first shake)






## Real shadows from animals only where the graphics level allows (`animal_shadows`, high and up): below that
## the contact shade under each (ContactShades) grounds it, and the shadow pass skips a farm's worth of animals.
func _apply_shadow() -> void:
	if _casting != null:
		_casting.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(Quality.value("animal_shadows"))
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func _enter_tree() -> void:
	if not Quality.notifier.emitted.is_connected(_apply_shadow):
		Quality.notifier.emitted.connect(_apply_shadow)


func _exit_tree() -> void:
	if Quality.notifier.emitted.is_connected(_apply_shadow):
		Quality.notifier.emitted.disconnect(_apply_shadow)
	sleepers.erase(self)


static func create(it: Dictionary, mind: AnimalBehaviour, at: Vector3, size := 1.0) -> Animal3D:
	var a := _from_template(it, size)
	a.behaviour = mind
	a.home = at
	a.position = at
	a._last = at
	a.heading = REST_LEFT if mind != null and mind.facing < 0.0 else REST_RIGHT
	a.motion = AnimalMotion.new(hash(str(it.get("id", ""))) + int(at.x * 97.0 + at.z * 31.0))
	# Its pace is its legs': a stride of ground for each cycle of them (and its mind walks it at that).
	var stride := a.stride()
	a._walk_speed = maxf(stride * a.rig.num("speed", 10.0) * a.rig.scale / maxf(a.rig.cycle_length(), 0.001), 0.001)
	if mind != null:
		mind.stride_tiles = stride
		mind.showy = bool(it.get("limited", false))
		mind.shakes = a._file_shapes.has(CoatTouch.SHAKE_A)
	a._slot = a.get_instance_id() % SLOTS
	a.rotation.y = a.heading
	return a


## A new animal of this kind and size: a copy of the one built first (TEMPLATES), sharing its skinned mesh, so a
## farm of 140 animals builds a few dozen, not 140 (each build merges and skins its parts: ~3 ms on a desktop,
## many times that on a phone). The build depends only on the rig, so every copy is the same as a fresh one.
static func _from_template(it: Dictionary, size: float) -> Animal3D:
	var key := "%s|%.3f" % [str(it.get("id", "")), size]
	if not _templates.has(key):
		var t := Animal3D.new()
		t.rig = AnimalRig.of(it) if is_equal_approx(size, 1.0) else AnimalRig.scaled(it, size)  # smaller in a small yard
		t._id = str(it.get("id", ""))
		t._size = size
		t._build()
		_templates[key] = t
	var template: Animal3D = _templates[key]
	var a := template.duplicate() as Animal3D
	a._take_parts_of(template)
	return a


## Lets the animals built to copy from go (at exit, with the other shared looks: Instancer.clear).
static func clear_templates() -> void:
	for t: Node in _templates.values():
		t.free()
	_templates.clear()


## Points this copy's part references at its own nodes (the same paths as in `t`) and copies `t`'s sizes.
func _take_parts_of(t: Animal3D) -> void:
	rig = t.rig
	_r = t._r
	_leg = t._leg
	_contact_size = t._contact_size
	_contact_strength = t._contact_strength
	_body = _mine(t, t._body)
	_head = _mine(t, t._head)
	_neck = _mine(t, t._neck)
	_tail = _mine(t, t._tail)
	_contact = _mine(t, t._contact)
	_skeleton = _mine(t, t._skeleton)
	_casting = _mine(t, t._casting)
	_file_mesh = _mine(t, t._file_mesh)
	_file_bones = t._file_bones.another() if t._file_bones != null else null
	_file_shapes = t._file_shapes
	_walk_frames = t._walk_frames
	_id = t._id
	_size = t._size
	for list: Array in [[t._wings, _wings], [t._ears, _ears], [t._eyes, _eyes], [t._bones, _bones]]:
		(list[1] as Array).clear()
		for n: Node in list[0]:
			(list[1] as Array).append(_mine(t, n))
	_legs.clear()
	for leg: Dictionary in t._legs:
		var own := {}
		for k: String in leg:
			own[k] = _mine(t, leg[k]) if leg[k] is Node else leg[k]
		_legs.append(own)
	_apply_shadow()


## This copy's node at the place `n` has in `t` (by child order: a copy's nodes get new names).
func _mine(t: Animal3D, n: Node) -> Node:
	if n == null:
		return null
	var steps: Array[int] = []
	var at := n
	while at != t:
		steps.push_front(at.get_index())
		at = at.get_parent()
	var out: Node = self
	for k in steps:
		out = out.get_child(k)
	return out




# ---------------------------------------------------------------- building


func _build() -> void:
	if AssetRegistry.has_model(_id) and _build_file():
		return   # (made as a file: docs/ASSETS.md; else the code-built animal below)
	ModelKit.round_balls = true
	_build_parts()
	ModelKit.round_balls = false


## An animal made as a file (tools/animal_art's export): its mesh, its bones and its moves as where each bone
## goes (AnimalBones; a long coat's shake alone is a blend shape), posed each frame from the same pose values as
## a built one (`_pose_file`). False when the file has no mesh to pose (the built animal is drawn instead).
func _build_file() -> bool:
	var model := AssetRegistry.instance(_id)
	var mi := _first_mesh(model) if model != null else null
	if mi == null or mi.mesh == null:
		if model != null:
			model.free()
		return false
	_body = Node3D.new()
	add_child(_body)
	model.scale = Vector3.ONE * _size
	_body.add_child(model)
	_file_mesh = mi
	CoatTouch.dress(mi, Game.item_data(_id))
	_file_bones = AnimalBones.of(mi)
	if _file_bones != null:
		for k in _file_bones.moves.names.size():
			_file_shapes[_file_bones.moves.names[k]] = k
	for k in mi.mesh.get_blend_shape_count():
		_file_shapes[String(mi.mesh.get_blend_shape_name(k))] = MESH_MOVE + k
	while _file_shapes.has(walk_move(_walk_frames)):
		_walk_frames += 1
	var box := AnimalBones.box_of(mi)
	_r = box.size * 0.5 * _size
	_leg = box.size.y * _size * 0.3
	_r.y = box.size.y * _size * 0.35
	_casting = mi
	_apply_shadow()
	_build_contact()
	return true


## The ground one cycle of its legs covers, in tiles: its file's own walk, or the walk it is posed with.
func stride() -> float:
	var made := file_stride(_id) * _size if _file_mesh != null else 0.0
	return made if made > 0.0 else maxf(AnimalGait.STRIDE * _leg / AnimalGait.STANCE, 0.001)


func _set_behaviour(mind: AnimalBehaviour) -> void:
	behaviour = mind
	if mind != null:
		mind.lies = sleeps_its_own_way()


## Whether its model has a sleeping pose of its own (a file made with the `sleep` move).
func sleeps_its_own_way() -> bool:
	return _file_shapes.has(SLEEP_MOVE)


## Where its nose is in the world when it is asleep (its "z z z" rises from there), or Vector3.INF when its kind's
## is not known (NOSES: written with each animal's file).
func nose_asleep() -> Vector3:
	if _noses.is_empty():
		_noses = DataFile.read_optional(NOSES).get("noses", {})
	var at: Variant = _noses.get(_id)
	if not at is Array or (at as Array).size() != 3 or _file_mesh == null:
		return Vector3.INF
	return _file_mesh.global_transform * Vector3(float(at[0]), float(at[1]), float(at[2]))


## The ground one cycle of a file-made animal's walk covers, in tiles at full size (0 when it has no file or
## no walk): how far its feet reach back while they are down (the travel of its lowest points through the
## walk's moves), over the share of the cycle a foot is down. Once a kind: from data/animal_strides.json when it
## was measured from this very file (its fingerprint in data/art_versions.json), else measured now (reading
## every move of a file costs ~3 ms a kind, a fifth of opening the showcase).
static func file_stride(id: String) -> float:
	if not _strides.has(id):
		var kept := kept_stride(id)
		_strides[id] = kept if kept >= 0.0 else measure_stride(id)
	return _strides[id]


## The stride kept for kind `id` in STRIDES, or -1 when none is kept for its file as it is now.
static func kept_stride(id: String) -> float:
	if _kept.is_empty():
		_kept = DataFile.read_optional(STRIDES).get("strides", {})
		_kept[""] = {}   # (read once, even when empty)
	var e: Dictionary = _kept.get(id, {})
	var file := ArtVersion.file_of(id)
	return float(e["stride"]) if not file.is_empty() and str(e.get("file", "")) == file else -1.0


## Every kind drawn from an animal file (the kinds STRIDES keeps).
static func stride_kinds() -> Array[String]:
	var out: Array[String] = []
	for id: String in AssetRegistry.ids():
		if str(AssetRegistry.entry(id).get("budget", "")) == "animal" and AssetRegistry.has_model(id):
			out.append(id)
	out.sort()
	return out


## Kind `id`'s stride measured from its file (file_stride), as tools/animal_strides keeps it.
static func measure_stride(id: String) -> float:
	var stride := 0.0
	var model := AssetRegistry.instance(id) if AssetRegistry.has_model(id) else null
	var mi := _first_mesh(model) if model != null else null
	var moves := AnimalBones.moves_of(mi)
	if moves != null and mi.mesh is ArrayMesh and mi.mesh.get_surface_count() > 0:
		stride = _feet_reach(mi.mesh as ArrayMesh, moves) / AnimalGait.STANCE
	if model != null:
		model.free()
	return stride


static func _feet_reach(mesh: ArrayMesh, moves: AnimalBones.Moves) -> float:
	var arrays := mesh.surface_get_arrays(0)
	var built: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var steps: Array[int] = []
	for k in moves.names.size():
		if moves.names[k].begins_with(AnimalBones.WALK):
			steps.append(k)
	# (The feet: the lowest of the animal as it stands.)
	var stands := PackedVector3Array()
	var low := INF
	var high := -INF
	for k in built.size():
		stands.append(moves.moved(built[k], bones, weights, k * 4, -1))
		low = minf(low, stands[k].y)
		high = maxf(high, stands[k].y)
	var reaches: Array[float] = []
	for k in built.size():
		if stands[k].y > low + (high - low) * FEET_SHARE:
			continue
		var back := INF
		var fore := -INF
		for step in steps:
			var x := moves.moved(built[k], bones, weights, k * 4, step).x
			back = minf(back, x)
			fore = maxf(fore, x)
		reaches.append(fore - back)
	reaches.sort()
	return reaches[reaches.size() >> 1] if not reaches.is_empty() and not steps.is_empty() else 0.0


## How long an animal made as a file is, nose to tail, in tiles (0 when it has none); worked out once a kind.
static func file_length(id: String) -> float:
	if not _lengths.has(id):
		var length := 0.0
		if AssetRegistry.has_model(id):
			var model := AssetRegistry.instance(id)
			var mi := _first_mesh(model) if model != null else null
			if mi != null:
				length = AnimalBones.box_of(mi).size.x
			if model != null:
				model.free()
		_lengths[id] = length
	return _lengths[id]


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null


## Poses a file-made animal: its walk frames blended by gait and stride, head down, looking about, blinking, tail
## and breath, each a blend shape weighted by the pose value; the body's springs (lean, squash, hop) move the
## whole model, as they move a built one.
func _pose_file(p: AnimalPose) -> void:
	if _file_shapes.has(CoatTouch.SHAKE_A):
		_pose_shake(p.shake)
	var frames := maxi(_walk_frames, 1)
	var at := fposmod(p.gait, 1.0) * frames
	var k0 := int(at) % frames
	var k1 := (k0 + 1) % frames
	var f := at - floorf(at)
	for k in _walk_frames:
		var w := 0.0
		if k == k0:
			w += (1.0 - f) * p.stride
		if k == k1:
			w += f * p.stride
		_shape(walk_move(k), w)
	_shape("head", smoothstep(0.0, 1.0, p.head))
	var look := clampf(p.look + motion.head_yaw * 0.8, -1.0, 1.0)
	_shape("look_left", maxf(look, 0.0))
	_shape("look_right", maxf(-look, 0.0))
	_shape("blink", p.blink)
	_shape("jaw", maxf(p.jaw, 0.0) * smoothstep(0.0, 1.0, p.head))   # (chewing while grazing)
	_shape("tail", clampf(p.tail + motion.tail, -1.0, 1.0))
	_shape("breath", p.breath * 0.5)
	_shape("ear_flick", p.ear)
	_shape("display", p.display)
	_shape(SLEEP_MOVE, p.sleep)
	var deep := p.sleep >= ASLEEP
	if deep != sleepers.has(self):
		if deep:
			sleepers.append(self)
		else:
			sleepers.erase(self)
	var bug := rig.type == "bug"
	# A bee's wings beat all the time; a bird's open as it flaps.
	_shape("wing_flap", 0.5 + 0.5 * sin(p.time * BEE_BEAT_RATE) if bug else p.wing)
	var lift := 0.0
	if _file_shapes.has("hop"):
		_shape("hop", p.hop)   # (the hop's own shape lifts it and tucks its legs)
	else:
		lift = p.hop * _leg * 0.8
	if bug:
		lift += sin(p.time * BEE_HOVER_RATE) * _r.y * BEE_HOVER
	_body.position = Vector3(0, lift, 0)
	_body.rotation = Vector3(motion.roll, 0, motion.pitch)
	_body.scale = Vector3(1.0 + motion.squash * 0.6, 1.0 - motion.squash, 1.0 + motion.squash * 0.6)
	if _file_bones != null:
		_file_bones.pose(_file_mesh)


## What walk frame `k`'s move is called in a file (worked out once each: an animal asks for all of them a frame).
static func walk_move(k: int) -> String:
	while _walk_moves.size() <= k:
		_walk_moves.append("%s%02d" % [AnimalBones.WALK, _walk_moves.size()])
	return _walk_moves[k]


## A long coat's shake: the file's two shake moves in turn, and a little fluff let go as it starts.
func _pose_shake(through: float) -> void:
	var turn := CoatTouch.shake_weights(through)
	_shape(CoatTouch.SHAKE_A, turn.x)
	_shape(CoatTouch.SHAKE_B, turn.y)
	if through > 0.0 and _shaking <= 0.0 and is_inside_tree():
		if _fluff == null:
			_fluff = DustPuffs.new()
			_fluff.top_level = true   # (the tufts fall where they were let go, not carried along)
			add_child(_fluff)
			_fluff.global_transform = Transform3D.IDENTITY
		CoatTouch.shed(_fluff, global_position, _r, Color(str(Game.item_data(_id).get("color", "#ffffff"))))
	_shaking = through


## Asks for `weight` of the file's move `move` (nothing when the file has none of that name).
func _shape(move: String, weight: float) -> void:
	var k: int = _file_shapes.get(move, -1)
	if k >= MESH_MOVE:
		_file_mesh.set_blend_shape_value(k - MESH_MOVE, weight)
	elif k >= 0:
		_file_bones.want(k, weight)




func _build_parts() -> void:
	_body = Node3D.new()
	add_child(_body)
	match rig.type:
		"bird":
			_build_bird()
		"bug":
			_build_bee()
		"shell":
			_build_turtle()
		_:
			_build_quad()
	_build_contact()
	_merge_parts()
	_skin()




## Draws: the parts that never move against each other (body and its coat, head and its face) become one
## mesh each, and only the body and head cast shadows; the thin moving parts (legs, ears, eyes, tail,
## wings) cast none, which at this size the sun's shadow wouldn't show anyway, and the contact shade under
## the animal grounds it. A cow goes from ~24 draws and ~24 shadow draws to ~12 and 2.
func _merge_parts() -> void:
	var moving: Array = [_neck, _head, _tail, _contact]
	moving.append_array(_wings)
	moving.append_array(_ears)
	moving.append_array(_eyes)
	for leg in _legs:
		for k in leg:
			if leg[k] is Node3D:
				moving.append(leg[k])
	ModelKit.merge_leaves(_body, moving)
	if _head != null:
		ModelKit.merge_leaves(_head, moving)
	for n: Node3D in moving:
		if n != null and n != _head:
			_no_shadow(n)




## One draw for the whole animal (two with its shadow-casting body and head): every part's mesh is baked,
## at rest, into one skinned mesh, each part bound wholly to its own bone. The part nodes stay, emptied, as
## the pose: the pose code moves them as before, and _pose_bones copies their transforms to the bones.
func _skin() -> void:
	var parts: Array[MeshInstance3D] = []
	_gather(self, parts)
	if parts.is_empty():
		return
	_skeleton = Skeleton3D.new()
	var bone_of := {}   # node -> bone index
	var groups := {}    # "shadow|material|format" -> {"st", "mat", "shadow"}
	for mi in parts:
		var chain: Array[Node3D] = []
		var n: Node = mi
		while n != self:
			chain.push_front(n as Node3D)
			n = n.get_parent()
		var rest := Transform3D.IDENTITY
		for link in chain:
			rest = rest * link.transform
			if not bone_of.has(link):
				var b := _skeleton.get_bone_count()
				_skeleton.add_bone(str(b))
				_skeleton.set_bone_parent(b, bone_of.get(link.get_parent(), -1))
				_skeleton.set_bone_rest(b, link.transform)
				bone_of[link] = b
				_bones.append(link)
		var bone: int = bone_of[mi]
		var shadow := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var mat := mi.material_override if mi.material_override != null else mi.get_active_material(s)
			var arrays := mi.mesh.surface_get_arrays(s)
			var tint := ModelKit.tinted(mat)
			var one_coat := false
			if mat == ModelKit.coat():
				one_coat = true   # merged already: its colours and shines are in its vertices
			elif ModelKit.is_coatable(mat) and (not tint.is_empty() or mat.has_meta(ModelKit.WHITE_TWIN)):
				# Every painted part shares one surface: its colour and its shine are in its vertices (a part
				# merged earlier already carries its colours: white tints it by nothing).
				var base: Color = tint[1] if not tint.is_empty() else Color.WHITE
				arrays = ModelKit.shine_arrays(ModelKit.tint_arrays(arrays, base), ModelKit.shine_of(mat))
				mat = ModelKit.coat()
				one_coat = true
			elif not tint.is_empty():
				mat = tint[0]
				arrays = ModelKit.tint_arrays(arrays, tint[1])
			var count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var bones := PackedInt32Array()
			bones.resize(count * 4)
			var weights := PackedFloat32Array()
			weights.resize(count * 4)
			for v in count:
				bones[v * 4] = bone
				weights[v * 4] = 1.0
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			var fmt := 0
			for k: int in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR, Mesh.ARRAY_TANGENT]:
				if arrays[k] != null:
					fmt |= 1 << k
			if one_coat:
				shadow = true  # thin parts cast a shadow too (a little more in the shadow pass) so all share one draw
			var key := "%s|%d|%d" % [shadow, mat.get_instance_id() if mat != null else 0, fmt]
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"st": st, "mat": mat, "shadow": shadow}
			var one := ArrayMesh.new()
			one.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			(groups[key]["st"] as SurfaceTool).append_from(one, 0, rest)
		mi.mesh = null  # it's drawn by the skinned mesh now; the node stays as its bone's pose
	add_child(_skeleton)
	var skin := _skeleton.create_skin_from_rest_transforms()
	for shadow: bool in [true, false]:
		var mesh := ArrayMesh.new()
		var mats: Array[Material] = []
		for key in groups:
			if groups[key]["shadow"] == shadow:
				(groups[key]["st"] as SurfaceTool).commit(mesh)
				mats.append(groups[key]["mat"])
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.skin = skin
		for k in mats.size():
			mi.set_surface_override_material(k, mats[k])
		if not shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			_casting = mi
			_apply_shadow()
		_skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
	_pose_bones()




func _gather(n: Node, out: Array[MeshInstance3D]) -> void:
	for c in n.get_children():
		if c == _contact or c == _skeleton:
			continue
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append(c)
		_gather(c, out)




func _pose_bones() -> void:
	if _skeleton == null:
		return
	for b in _bones.size():
		_skeleton.set_bone_pose(b, _bones[b].transform)




## Poses it this frame if it's on screen and its turn has come (the animation budget, FULL_RATE): owners
## call this every frame instead of update().
func animate(delta: float, cam: Camera3D) -> void:
	if not posing:
		return
	if cam != null and not cam.is_position_in_frustum(global_position):
		_pending = 0.0
		return
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_seen_last = _seen
		_seen = 0
		_posed = 0
	_seen += 1
	_pending += delta
	if (f + _slot) % stride_for(_seen_last) != 0 and not _owed:
		return
	if _posed >= POSES_MOST:
		_owed = true   # (its turn came in a crowded frame: posed in a coming one, before its next turn)
		return
	_posed += 1
	_owed = false
	update(minf(_pending, PENDING_MOST))
	_pending = 0.0


## How many frames apart each animal is posed when `seen` are on screen: every frame for up to FULL_RATE, then
## spaced to MAX_STRIDE; past that (a crowd of more than POSES_MOST * MAX_STRIDE) further still, so a frame is
## never asked to pose more than POSES_MOST (a cap alone left the end of the list unposed in a big herd).
static func stride_for(seen: int) -> int:
	var most := maxi(MAX_STRIDE, ceili(float(seen) / POSES_MOST))
	return clampi(maxi(ceili(float(seen) / FULL_RATE), min_stride), 1, mini(most, SLOTS))




static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)




## A soft dark patch on the grass under the body, a little longer than it, so the animal stands on the
## farm (ambient occlusion; the sun's shadow falls separately, and moves with the time of day).
## The contact shade: a marker that moves with the animal; the shade itself is a slot in the farm's batch
## (ContactShades), so all the animals' shades are one draw.
func _build_contact() -> void:
	_contact_size = Vector2(_r.x * 2.0 * CONTACT_SPREAD, maxf(_r.z, _r.x * 0.45) * 2.0 * CONTACT_SPREAD)
	_contact = Node3D.new()
	_contact.position.y = CONTACT_LIFT
	add_child(_contact)


## Puts this animal's shade where its marker is (hidden while the animal is), taking a slot on first use.
func _push_shade() -> void:
	if _contact == null or not _contact.is_inside_tree():
		return
	if _shades == null:
		_shades = ContactShades.of(self)
		_shade_slot = _shades.take()
	var size := _contact.global_transform.basis.scaled(Vector3(_contact_size.x, 1.0, _contact_size.y))
	_shades.put(_shade_slot, Transform3D(size, _contact.global_position),
		_contact_strength if is_visible_in_tree() else 0.0)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY, NOTIFICATION_VISIBILITY_CHANGED:
			_push_shade()   # on the farm (or shown, or hidden) before its first pose
		NOTIFICATION_EXIT_TREE:
			if _shades != null and is_instance_valid(_shades):
				_shades.give_back(_shade_slot)
			_shades = null
			_shade_slot = -1




func _px(v: float) -> float:
	return v * PX




func _build_quad() -> void:
	var b := rig.pair("body", Vector2(26, 14))
	_r = Vector3(_px(b.x), _px(b.y), _px(b.y) * 0.85)
	_leg = _px(rig.size("leg", 15.0))
	var coat := rig.body_color
	var accent := rig.accent_color
	var mat := ModelKit.paint(coat)
	# The body: a rounded barrel, with wool, spots or patches on it.
	if rig.flag("wool"):
		for k in 9:
			var a := TAU * k / 9.0
			ModelKit.ball(_body, Vector3(cos(a) * _r.x * 0.62, sin(a) * _r.y * 0.4, 0), _r.y * 0.62,
				ModelKit.paint(coat.lightened(0.06)))
		ModelKit.ball(_body, Vector3.ZERO, 1.0, ModelKit.paint(coat.lightened(0.06)), _r * Vector3(0.95, 0.95, 1.05))
	else:
		ModelKit.ball(_body, Vector3.ZERO, 1.0, mat, _r)
	_markings(rig.text("markings", "none"), accent)
	if rig.flag("udder"):
		ModelKit.ball(_body, Vector3(-_r.x * 0.3, -_r.y * 0.85, 0), _r.y * 0.3, ModelKit.paint(PINK))
	# Legs: upper and lower segments, re-posed every frame.
	var thick := _px(rig.num("leg_width", 1.0) * (1.35 if rig.family == "pig" else 1.0) * 3.4)
	var leg_col := coat.darkened(0.08)
	var lower_col := leg_col
	if rig.family == "horse":
		lower_col = accent.lerp(coat, 0.35)
	if rig.flag("socks"):
		lower_col = Color("#f4f1ea")
	for k in 4:
		var near: bool = k >= 2
		var fore: bool = k % 2 == 1
		var hip := Vector3((0.58 if fore else -0.58) * _r.x, -_r.y * 0.35, (0.55 if near else -0.55) * _r.z)
		var upper := _segment(ModelKit.paint(leg_col), thick)
		var lower := _segment(ModelKit.paint(lower_col), thick * 0.75)
		var hoof_col := HOOF if rig.family != "pig" else coat.darkened(0.45)
		var hoof := ModelKit.box(_body, Vector3(-thick * 0.6, 0, -thick * 0.5),
			Vector3(thick * 0.6, thick * 0.6, thick * 0.5), ModelKit.paint(hoof_col))
		_legs.append({"hip": hip, "upper": upper, "lower": lower, "hoof": hoof, "phase": LEG_PHASES[k], "fore": fore,
			"k": k})
	# Neck and head.
	_neck = _segment(mat, _px(rig.pair("neck", Vector2(14, 9)).y) * 1.6)
	_head = Node3D.new()
	_body.add_child(_head)
	var h := rig.pair("head", Vector2(14, 10)) * rig.head_scale
	var hl := _px(h.x)
	var hh := _px(h.y)
	var head_col := coat
	if rig.text("markings") == "white_face":
		head_col = Color("#f4f1ea")
	elif rig.text("head_color") == "accent":
		head_col = accent
	ModelKit.ball(
		_head,
		Vector3(-hl * 0.1, 0, 0),
		1.0,
		ModelKit.paint(head_col),
		Vector3(hl * 0.48, hh * 0.5, hh * 0.45)
	)
	var muzzle := _muzzle_colour(rig.text("muzzle", "light"), head_col)
	if rig.text("muzzle") == "snout":
		var snout := ModelKit.cylinder(
			_head,
			Vector3(hl * 0.3, 0, 0),
			hh * 0.3,
			hl * 0.25,
			ModelKit.paint(muzzle),
			-1.0,
			12
		)
		snout.rotation.z = -PI / 2.0
		snout.position = Vector3(hl * 0.42, 0, 0)
	else:
		ModelKit.ball(
			_head,
			Vector3(hl * 0.32, -hh * 0.08, 0),
			1.0,
			ModelKit.paint(muzzle),
			Vector3(hl * 0.28, hh * 0.36, hh * 0.38)
		)
	var eye_r := hh * 0.09 * rig.num("eye_scale", 1.0)
	for side: float in [-1.0, 1.0]:
		_eyes.append(ModelKit.ball(_head, Vector3(hl * 0.05, hh * 0.15, side * hh * 0.4), eye_r, ModelKit.paint(EYE, 0.8)))
		var ear := Node3D.new()
		ear.position = Vector3(-hl * 0.3, hh * 0.3, side * hh * 0.35)
		_head.add_child(ear)
		var long_ears := rig.text("ears") == "long"
		var up := rig.text("ears") in ["up", "long"]
		var ear_at := Vector3(0, hh * (0.35 if up else 0.05), side * hh * (0.05 if up else 0.3))
		var ear_size := Vector3(
			hh * 0.12,
			hh * (0.45 if long_ears else (0.3 if up else 0.12)),
			hh * (0.12 if up else 0.28)
		)
		ModelKit.ball(ear, ear_at, 1.0, ModelKit.paint(head_col), ear_size)
		_ears.append(ear)
		match rig.text("horns", "none"):
			"nubs", "short":
				var horn_h := hh * (0.25 if rig.text("horns") == "nubs" else 0.45)
				ModelKit.cylinder(_head, Vector3(-hl * 0.15, hh * 0.4, side * hh * 0.22), hh * 0.08, horn_h,
					ModelKit.paint(Color("#ece3cf")), 0.0, 8)
			"long", "curl", "back", "long_back":
				var horn := ModelKit.cylinder(
					_head,
					Vector3.ZERO,
					hh * 0.09,
					hh * 0.9,
					ModelKit.paint(Color("#ece3cf")),
					0.0,
					8
				)
				horn.position = Vector3(-hl * 0.2, hh * 0.45, side * hh * 0.35)
				horn.rotation = Vector3(side * 1.1, 0, -0.6)
	if rig.text("mane", "") != "":
		ModelKit.box(
			_head,
			Vector3(-hl * 0.55, hh * 0.25, -hh * 0.08),
			Vector3(-hl * 0.2, hh * 0.55, hh * 0.08),
			ModelKit.paint(accent)
		)
	# Tail.
	_tail = Node3D.new()
	_tail.position = Vector3(-_r.x * 0.95, _r.y * 0.35, 0)
	_body.add_child(_tail)
	var tail_len := _px(rig.size("tail_len", 14.0))
	var tail_kind := rig.text("tail", "tuft")
	if tail_kind == "curl":
		ModelKit.ball(_tail, Vector3(-_px(2.0), 0, 0), _px(2.2), ModelKit.paint(coat.darkened(0.12)))
	else:
		var t := ModelKit.cylinder(
			_tail,
			Vector3(0, -tail_len, 0),
			_px(1.2),
			tail_len,
			ModelKit.paint(coat.darkened(0.1)),
			_px(1.0),
			6
		)
		t.position = Vector3(0, -tail_len / 2.0, 0)
		if tail_kind in ["tuft", "hair"]:
			ModelKit.ball(_tail, Vector3(0, -tail_len, 0), _px(2.6 if tail_kind == "tuft" else 3.4), ModelKit.paint(accent),
				Vector3(1, 1.6, 1))




func _markings(kind: String, accent: Color) -> void:
	var white := Color("#f4f1ea")
	match kind:
		"spots", "patches":
			var spots := [Vector3(-0.4, 0.3, 1), Vector3(0.1, 0.5, 1), Vector3(0.45, 0.1, 1), Vector3(-0.15, -0.1, 1),
				Vector3(-0.3, 0.4, -1), Vector3(0.3, 0.3, -1)]
			var big := 0.24 if kind == "patches" else 0.17
			var col := accent if kind == "spots" else (white if rig.body_color.get_luminance() < 0.5 else accent)
			for s: Vector3 in spots:
				# A flattened blob pressed onto the body's surface.
				var p := Vector3(s.x * _r.x, s.y * _r.y, s.z * _r.z * sqrt(maxf(0.0, 1.0 - s.x * s.x - s.y * s.y)))
				ModelKit.ball(_body, p, 1.0, ModelKit.paint(col), Vector3(_r.x * big, _r.y * big * 1.1, _r.z * 0.12))
		"belt", "saddle":
			var x0 := -0.22 if kind == "belt" else 0.22
			# A broad band round the barrel (Belted Galloway), or a saddle over the back: wide enough to read.
			ModelKit.ball(_body, Vector3((x0 + 0.18) * _r.x, 0, 0), 1.0, ModelKit.paint(white),
				Vector3(_r.x * 0.42, _r.y * 1.03, _r.z * 1.03))
		"pale_belly", "white_face":
			ModelKit.ball(_body, Vector3(0, -_r.y * 0.35, 0), 1.0, ModelKit.paint(rig.body_color.lightened(0.45)),
				Vector3(_r.x * 0.85, _r.y * 0.7, _r.z * 1.01))




static func _muzzle_colour(kind: String, head_col: Color) -> Color:
	match kind:
		"pink":
			return head_col.lerp(PINK, 0.65)
		"dark":
			return head_col.darkened(0.35)
		"snout":
			return head_col.lerp(PINK, 0.35).darkened(0.08)
	return head_col.lightened(0.25)




func _build_bird() -> void:
	var b := rig.pair("body", Vector2(13, 11))
	_r = Vector3(_px(b.x), _px(b.y), _px(b.y) * 0.85)
	_leg = _px(rig.size("leg", 9.0))
	var coat := rig.body_color
	var accent := rig.accent_color
	ModelKit.ball(_body, Vector3.ZERO, 1.0, ModelKit.paint(coat), _r)
	# Wings: flattened ovals on each side, hinged at the shoulder.
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(_r.x * 0.2, _r.y * 0.25, side * _r.z * 0.85)
		_body.add_child(wing)
		ModelKit.ball(wing, Vector3(-_r.x * 0.45, 0, 0), 1.0, ModelKit.paint(coat.darkened(0.1)),
			Vector3(_r.x * 0.6, _r.y * 0.55, _r.z * 0.18))
		_wings.append(wing)
	# Tail.
	_tail = Node3D.new()
	_tail.position = Vector3(-_r.x * 0.85, _r.y * 0.3, 0)
	_body.add_child(_tail)
	match rig.text("tail", "fan"):
		"fan", "turkey":
			var n := 7 if rig.text("tail") == "turkey" else 4
			for k in n:
				var feather := Node3D.new()
				feather.rotation.x = (k / maxf(n - 1.0, 1.0) - 0.5) * 1.6
				_tail.add_child(feather)
				ModelKit.ball(feather, Vector3(0, _r.y * 0.6, 0), 1.0, ModelKit.paint(accent.lerp(coat, 0.2 * (k % 2))),
					Vector3(_r.x * 0.12, _r.y * 0.65, _r.z * 0.15))
		_:
			ModelKit.ball(_tail, Vector3(-_r.x * 0.1, _r.y * 0.1, 0), 1.0, ModelKit.paint(coat.darkened(0.06)),
				Vector3(_r.x * 0.3, _r.y * 0.2, _r.z * 0.4))
	# Two legs.
	for k in 2:
		var hip := Vector3(0, -_r.y * 0.5, (0.35 if k == 1 else -0.35) * _r.z)
		var col := BEAK if rig.flag("webbed") else Color("#e8a634")
		var upper := _segment(ModelKit.paint(col), _px(1.6))
		var lower := _segment(ModelKit.paint(col), _px(1.4))
		var foot := ModelKit.box(
			_body,
			Vector3(-_px(1.5), 0, -_px(2.0)),
			Vector3(_px(4.5), _px(0.8), _px(2.0)),
			ModelKit.paint(col)
		)
		_legs.append({"hip": hip, "upper": upper, "lower": lower, "hoof": foot, "phase": 0.5 * k, "fore": false})
	# Neck and head.
	_neck = _segment(ModelKit.paint(coat), _px(rig.pair("neck", Vector2(7, 7)).y) * 1.4)
	_head = Node3D.new()
	_body.add_child(_head)
	var h := rig.pair("head", Vector2(6.5, 6.5)) * rig.head_scale
	var hr := _px(h.x)
	var head_col := Color("#c9a7a0") if rig.family == "turkey" else coat
	ModelKit.ball(_head, Vector3.ZERO, hr, ModelKit.paint(head_col))
	if rig.text("beak") == "bill":
		ModelKit.ball(
			_head,
			Vector3(hr * 1.1, -hr * 0.15, 0),
			1.0,
			ModelKit.paint(BEAK),
			Vector3(hr * 0.7, hr * 0.22, hr * 0.45)
		)
	else:
		var beak := ModelKit.cylinder(_head, Vector3.ZERO, hr * 0.3, hr * 0.7, ModelKit.paint(BEAK), 0.0, 8)
		beak.rotation.z = -PI / 2.0
		beak.position = Vector3(hr * 1.2, -hr * 0.05, 0)
	if rig.flag("comb"):
		for k in 3:
			ModelKit.ball(_head, Vector3((-0.3 + 0.3 * k) * hr, hr * 0.95, 0), hr * 0.28, ModelKit.paint(COMB))
	if rig.flag("wattle"):
		ModelKit.ball(_head, Vector3(hr * 0.7, -hr * 0.8, 0), hr * 0.22, ModelKit.paint(COMB), Vector3(1, 1.5, 1))
	for side: float in [-1.0, 1.0]:
		_eyes.append(ModelKit.ball(_head, Vector3(hr * 0.4, hr * 0.25, side * hr * 0.75),
			hr * 0.16 * rig.num("eye_scale", 1.0), ModelKit.paint(EYE, 0.8)))




func _build_turtle() -> void:
	var b := rig.pair("body", Vector2(16, 10))
	_r = Vector3(_px(b.x), _px(b.y) * 0.8, _px(b.x) * 0.8)
	_leg = _px(4.0)
	var skin := rig.accent_color.lerp(Color("#8a9a5b"), 0.6)
	ModelKit.ball(_body, Vector3.ZERO, 1.0, ModelKit.paint(rig.body_color), Vector3(_r.x, _r.y, _r.z))
	for k in 4:
		var hip := Vector3((0.6 if k % 2 else -0.6) * _r.x, -_r.y * 0.2, (0.7 if k >= 2 else -0.7) * _r.z)
		var leg := ModelKit.ball(_body, hip, _px(3.0), ModelKit.paint(skin), Vector3(1.3, 0.7, 1))
		_legs.append({"stub": leg, "hip": hip, "phase": k * 0.25})
	_head = Node3D.new()
	_body.add_child(_head)
	ModelKit.ball(_head, Vector3.ZERO, _px(4.0), ModelKit.paint(skin), Vector3(1.3, 1, 1))
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(_head, Vector3(_px(2.5), _px(1.5), side * _px(2.6)), _px(0.8), ModelKit.paint(EYE))




func _build_bee() -> void:
	var b := rig.pair("body", Vector2(6, 4))
	_r = Vector3(_px(b.x), _px(b.y), _px(b.y))
	ModelKit.ball(_body, Vector3.ZERO, 1.0, ModelKit.paint(rig.body_color), _r)
	for k in 2:
		ModelKit.ball(_body, Vector3((-0.3 + 0.4 * k) * _r.x, 0, 0), 1.0, ModelKit.paint(Color("#2a2118")),
			Vector3(_r.x * 0.12, _r.y * 1.02, _r.z * 1.02))
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(0, _r.y * 0.8, side * _r.z * 0.5)
		_body.add_child(wing)
		var glass := ModelKit.paint(Color(0.92, 0.97, 1.0))
		ModelKit.ball(wing, Vector3(0, 0, side * _r.z * 0.8), 1.0, glass, Vector3(_r.x * 0.5, _r.y * 0.1, _r.z * 0.9))
		_wings.append(wing)




## A limb segment: a unit cylinder, stretched between two points each frame by _place().
func _segment(mat: Material, width: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = width / 2.0
	mesh.bottom_radius = width / 2.0
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	_body.add_child(mi)
	return mi




## Stretches a segment from a to b (in the body's space).
static func _place(seg: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := maxf(d.length(), 0.0001)
	var up := d / length
	var side := up.cross(Vector3.BACK)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var fwd := side.cross(up).normalized()
	seg.transform = Transform3D(Basis(side, up * length, fwd), (a + b) / 2.0)




## How far it reaches from its feet (radius) and how tall it stands: its box for taps.
## How far along the ray `from`+`dir` this animal is met, or INF: its own box, turned the way it faces, so a tap
## lands on the animal under the finger, not on a big neighbour's square.
func hit(from: Vector3, dir: Vector3) -> float:
	var t := global_transform if is_inside_tree() else transform
	var inv := t.affine_inverse()
	var met: Variant = pick_box().intersects_ray(inv * from, inv.basis * dir)
	return from.distance_to(t * (met as Vector3)) if met != null else INF


## The box a tap is tested against, in the animal's own space (facing +X): its body, a little more, and never
## smaller than a fingertip.
func pick_box() -> AABB:
	var half: Vector3
	var mid := 0.0
	if _file_mesh != null:
		var b := AnimalBones.box_of(_file_mesh)
		half = b.size * 0.5 * _size
		mid = b.get_center().x * _size
	else:
		var r := reach()
		half = Vector3(r.x, r.y * 0.5, _r.z * 1.3)
	half = Vector3(maxf(half.x + PICK_PAD, PICK_MIN), half.y + PICK_PAD, maxf(half.z + PICK_PAD, PICK_MIN))
	return AABB(Vector3(mid - half.x, 0.0, -half.z), Vector3(half.x * 2.0, half.y * 2.0, half.z * 2.0))


func reach() -> Vector2:
	var r := maxf(_r.x, _r.z) * 1.6
	return Vector2(maxf(r, 0.12), _leg + _r.y * 2.6 + 0.05)




## Dropped onto the farm (just bought): falls in and lands with a little hop.
func land() -> void:
	drop = Objects3D.DROP_HEIGHT
	var tw := create_tween()
	tw.tween_property(self, "drop", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if behaviour != null:
		tw.tween_callback(behaviour.poke)




# ---------------------------------------------------------------- moving


## Poses the animal for this frame from its behaviour (call every frame it's on screen).
func update(delta: float) -> void:
	var p: AnimalPose = behaviour.pose if behaviour != null else AnimalPose.rest()
	# On water it sits low, its legs under the surface; its peck is a dabble, tipping forward with its head under.
	float_share = move_toward(float_share, 1.0 if afloat else 0.0, FLOAT_EASE * delta)
	if behaviour != null:
		var sunk := reach().y * FLOAT_SINK * float_share
		position = home + IsoProjection.ground_of(behaviour.offset) + Vector3(0, drop - sunk, 0)
	# (only while it feeds: a swimmer asleep keeps its head low without going under)
	var feeding := behaviour != null and behaviour.state == AnimalBehaviour.State.GRAZE
	dabble = move_toward(dabble, 1.0 if feeding else 0.0, DABBLE_EASE * delta)
	rotation.z = -DABBLE_TIP * dabble * float_share
	# Face where it's going: it comes round to its way, stepping round as it turns (its mind waits for it
	# to, before it sets off, and moves its legs for the turn: AnimalBehaviour.turned).
	var moved := position - _last
	_last = position
	var was := heading
	var off := 0.0
	var way := IsoProjection.ground_of(behaviour.going) if behaviour != null else Vector3.ZERO
	if way.length() > 0.0:
		var want := atan2(-way.z, way.x)
		heading = rotate_toward(heading, want, TURN_RATE * delta)
		off = absf(angle_difference(heading, want))
	elif behaviour == null or not behaviour.drinking:
		# Standing (grazing, idling): it settles side-on to the view, as FarmVille always showed its animals,
		# never tail-on or head-on (which, from above, reads as a pole).
		var rest := REST_RIGHT if absf(angle_difference(heading, REST_RIGHT)) < absf(angle_difference(heading, REST_LEFT)) \
			else REST_LEFT
		heading = rotate_toward(heading, rest, SETTLE_RATE * delta)
	if behaviour != null:
		behaviour.turned(off, absf(angle_difference(was, heading)) * _r.x * 2.0 * SHUFFLE_REACH)
	rotation.y = heading
	# The body's weight: how fast it's going (in walks), turning, hopping, and whether it's been tapped and
	# should look round at you.
	var speed := Vector2(moved.x, moved.z).length() / maxf(delta, 0.0001) / _walk_speed if delta > 0.0 else 0.0
	var keen := clampf(behaviour.noticed / 0.4, 0.0, 1.0) if behaviour != null else 0.0
	motion.step(delta, speed, heading, p.hop, p.stride, _yaw_to_camera() if keen > 0.0 else 0.0, keen)
	if _file_mesh != null:
		_pose_file(p)
		_settle_contact(p)
		return
	for e in _eyes:
		e.scale = Vector3(1.0, maxf(1.0 - p.blink, 0.1), 1.0)
	match rig.type:
		"bird":
			_pose_bird(p)
		"bug":
			_pose_bee(p)
		"shell":
			_pose_turtle(p)
		_:
			_pose_quad(p)
	_settle_contact(p)
	_pose_bones()




## Which way to turn the head to look at the camera, from straight ahead (radians, + to its left).
func _yaw_to_camera() -> float:
	if not is_inside_tree():
		return 0.0
	var local := global_transform.basis.inverse() * -IsoProjection.forward()
	return atan2(-local.z, local.x)


## The contact shade stays on the ground and fades as the animal leaves it (a hop, dropping in, a bee).
func _settle_contact(p: AnimalPose) -> void:
	var air := drop + p.hop * _leg * 0.55
	if rig.type == "bug":
		air += _body.position.y  # a bee hovers: only a faint patch under it
	_contact.position.y = CONTACT_LIFT - drop
	var fade := clampf(air / maxf(_r.y * 3.0, 0.05), 0.0, 0.85)
	_contact_strength = 1.0 - fade
	_contact.scale = Vector3.ONE * (1.0 - fade * 0.3)
	_push_shade()




func _pose_quad(p: AnimalPose) -> void:
	var m := motion
	var rise := pow(sin(p.gait * TAU * 2.0), 2.0) * _leg * 0.06 * p.stride
	var air := p.hop * _leg * 0.55
	_body.position = Vector3(0, _leg + _r.y * 0.62 + rise + air + p.breath * _r.y * 0.01, 0)
	# Weight: leaning into turns and speed, the hips rolling with each step and dropping on a rested leg; a
	# squash on landing; a slow breath.
	var sway := sin(p.gait * TAU) * AnimalMotion.SWAY * p.stride * (1.0 - m.trot * 0.6)
	_body.rotation = Vector3(m.roll + sway + m.rest * 0.05, 0, m.pitch - m.rest * 0.03)
	var breathe := 1.0 + p.breath * 0.012
	_body.scale = Vector3(1.0 + m.squash * 0.6, (1.0 - m.squash) * breathe, (1.0 + m.squash * 0.6) * breathe)
	# Legs: the feet stay planted on the ground whatever the body does above them (worked out on the
	# ground, then into the body's space for the leg's two bones).
	var reach := AnimalGait.STRIDE * _leg * (1.0 + m.trot * 0.25)
	var lift := AnimalGait.LIFT * _leg * (1.0 + m.trot * 0.5)
	var to_body := _body.transform.affine_inverse()
	for leg in _legs:
		var hip: Vector3 = leg["hip"]
		var k: int = leg["k"]
		var u := fposmod(p.gait + m.leg_phase(k), 1.0)
		var off := AnimalGait.foot_offset(u, reach, lift) * p.stride
		var hip_on_ground := _body.transform * hip
		var foot_on_ground := Vector3(hip_on_ground.x + off.x, p.hop * _leg * 0.4 - off.y, hip_on_ground.z)
		if k == 2:
			# The near hind leg is the one it rests: toe down, a little forward, the hock bent.
			foot_on_ground += Vector3(_leg * 0.12, _leg * 0.07, 0) * m.rest
		var foot := to_body * foot_on_ground
		var knee := _knee(hip, foot, bool(leg["fore"]))
		_place(leg["upper"], hip, knee)
		_place(leg["lower"], knee, foot)
		(leg["hoof"] as Node3D).position = foot
	# Neck and head: up and looking about, or down to graze, chewing. The head lags the body's turns,
	# rides out its bob, stays level when it leans, and turns to you when you tap.
	var down := smoothstep(0.0, 1.0, p.head)
	var neck_len := _px(rig.pair("neck", Vector2(14, 9)).x)
	var chest := Vector3(_r.x * 0.72, _r.y * 0.3, 0)
	var up_at := chest + Vector3(cos(-rig.num("neck_up", -0.6)), sin(-rig.num("neck_up", -0.6)), 0) * neck_len
	var graze_at := Vector3(chest.x + neck_len * 0.8, -_body.position.y + _r.y * 0.35, 0)
	var head_at := up_at.lerp(graze_at, down) + Vector3(0, p.look * _r.y * 0.1 * (1.0 - down), 0)
	head_at.y -= rise * m.head_steady
	var yaw := (p.look * 0.35 + m.head_yaw) * (1.0 - down * 0.7)
	head_at.z -= sin(yaw) * neck_len * 0.35
	_place(_neck, chest, head_at)
	_head.position = head_at + Vector3(0, p.jaw * _px(0.4), 0)
	_head.rotation = Vector3(-m.roll * 0.7, yaw, -lerpf(rig.num("head_tilt", 0.3), 1.2, down) - m.pitch * 0.7)
	for k in _ears.size():
		_ears[k].rotation = Vector3((1.0 if k % 2 else -1.0) * p.ear * 0.6, 0, m.ears)
	# The tail swings on after the body, and lifts when it trots.
	_tail.rotation = Vector3(p.tail * 0.8 + m.tail, 0, 0.35 - m.pitch * 0.8 + m.trot * 0.35)




## The knee (or hock) of a two-bone leg from hip to foot, bending forward for forelegs, back for hind.
func _knee(hip: Vector3, foot: Vector3, fore: bool) -> Vector3:
	var bone := absf(foot.y - hip.y) * 0.56
	var j := AnimalGait.joint(Vector2(hip.x, -hip.y), Vector2(foot.x, -foot.y), bone, bone, -1.0 if fore else 1.0)
	return Vector3(j.x, -j.y, hip.z)




func _pose_bird(p: AnimalPose) -> void:
	var waddle := sin(p.gait * TAU) * 0.13 * p.stride if rig.flag("waddle") else 0.0
	var air := p.hop * _leg * 0.8
	_body.position = Vector3(0, _leg + _r.y * 0.8 + absf(sin(p.gait * TAU)) * _leg * 0.08 * p.stride + air, 0)
	_body.rotation = Vector3(waddle + motion.roll, 0, 0.22 - 0.12 * p.head + motion.pitch)
	_body.scale = Vector3(1.0 + motion.squash * 0.6, 1.0 - motion.squash, 1.0 + motion.squash * 0.6)
	for leg in _legs:
		var hip: Vector3 = leg["hip"]
		var u := fposmod(p.gait + float(leg["phase"]), 1.0)
		var off := AnimalGait.foot_offset(u, 0.9 * _leg, 0.45 * _leg) * p.stride
		# Feet planted on the ground, whatever the body's lean (worked out on the ground, then into its space).
		var on_ground := _body.transform * hip
		var foot := _body.transform.affine_inverse() * Vector3(on_ground.x + off.x, -off.y, on_ground.z)
		var knee := _knee(hip, foot, false)
		_place(leg["upper"], hip, knee)
		_place(leg["lower"], knee, foot)
		(leg["hoof"] as Node3D).position = foot
	var down := smoothstep(0.0, 1.0, p.head)
	var neck_len := _px(rig.pair("neck", Vector2(7, 7)).x)
	var shoulder := Vector3(_r.x * 0.7, _r.y * 0.35, 0)
	var thrust := (fposmod(p.gait * 2.0, 1.0) - 0.5) * _px(3.0) * p.stride
	var up_at := shoulder + Vector3(0.25, 1.0, 0).normalized() * neck_len + Vector3(-thrust, 0, 0)
	var peck_at := Vector3(shoulder.x + neck_len, -_body.position.y + _r.y * 0.3, 0)
	var head_at := up_at.lerp(peck_at, down)
	_place(_neck, shoulder, head_at)
	_head.position = head_at
	_head.rotation = Vector3(0, p.look * 0.4 + motion.head_yaw * (1.0 - down * 0.7), -down * 0.9 - motion.pitch * 0.6)
	for k in _wings.size():
		var side := -1.0 if k == 0 else 1.0
		_wings[k].rotation = Vector3(side * (p.wing * 1.2 + sin(p.time * 26.0) * 0.5 * p.wing), 0, 0)
	_tail.rotation = Vector3(p.tail * 0.5 + motion.tail * 0.6, 0, 0.6 + p.display * 0.9 - motion.pitch)
	for f in _tail.get_children():
		var n := _tail.get_child_count()
		var i := f.get_index()
		(f as Node3D).rotation.x = (i / maxf(n - 1.0, 1.0) - 0.5) * lerpf(1.0, 2.6, p.display)




func _pose_turtle(p: AnimalPose) -> void:
	_body.position = Vector3(0, _r.y * 0.6, 0)
	for leg in _legs:
		var hip: Vector3 = leg["hip"]
		(leg["stub"] as Node3D).position = hip + Vector3(
			sin(p.gait * TAU + float(leg["phase"]) * TAU) * _px(2.0) * p.stride,
			0,
			0
		)
	var out := clampf(0.55 + 0.45 * maxf(p.stride, absf(p.look)), 0.0, 1.0)
	_head.position = Vector3(_r.x * (0.75 + 0.35 * out), _r.y * 0.1 - p.head * _px(2.0), 0)
	_head.rotation.y = p.look * 0.5




func _pose_bee(p: AnimalPose) -> void:
	_body.position = Vector3(0, _px(rig.size("hover", 18.0)) + sin(p.time * 3.3) * _px(2.0), 0)
	for k in _wings.size():
		_wings[k].rotation.x = (1.0 if k else -1.0) * (0.3 + sin(p.time * 60.0) * 0.5)
