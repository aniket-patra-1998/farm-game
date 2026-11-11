class_name Trails
extends MultiMeshInstance3D
## What passes over the farm leaves marks on it for a while: the farmer's footprints, left and right in turn
## as they walk, and the wheel tracks of a vehicle across the ground it just worked. One MultiMesh holds
## them all as a ring (the oldest is replaced by the newest), so it costs one draw call however much
## walking there is. Marks press in dark and fade out over LIFE seconds (shaders/trail3d).

const CAPACITY := 160
const LIFE := 40.0                 # seconds a mark lasts
const FOOT_STRIDE := 0.34          # tiles between footprints
const FOOT_SIZE := Vector2(0.075, 0.14)
const FOOT_APART := 0.055          # left and right sit this far either side of the line walked
const TREAD_WIDTH := 0.18
const TREAD_APART := 0.34          # the two wheels of a lane, this far either side of its middle
const LANE := 2.0                  # tiles between the lanes a vehicle drives
const LIFT := 0.012                # marks lie this far above the grass
const BED_LIFT := 0.095            # wheel tracks lie on the beds a vehicle works (Plots3D.HEIGHT is 0.09)
const AGE_EVERY := 0.25            # how often marks age (a few times a second is plenty)
const FOOT := 0.0
const TREAD := 1.0

var _ages := PackedFloat32Array()  # seconds each mark has lasted (LIFE or more: gone)
var _kinds := PackedFloat32Array() # FOOT or TREAD, of each mark
var _next := 0                     # the ring's next slot
var _last_foot := Vector2.ZERO
var _foot_dist := 0.0
var _left := true
var _since_age := 0.0


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Marks can be anywhere on the farm: never culled for the box round the (hidden) ones the ring starts with.
	custom_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(80.0, 2.0, 80.0))
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = CAPACITY
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/trail3d.gdshader")
	material_override = mat
	_ages.resize(CAPACITY)
	_ages.fill(LIFE)
	_kinds.resize(CAPACITY)
	for i in CAPACITY:
		_hide(i)


func _ready() -> void:
	_last_foot = Game.player.pos
	Game.player.action_done.connect(_on_action_done)


func _process(delta: float) -> void:
	var p := Game.player
	if p.is_walking():
		_foot_dist += p.pos.distance_to(_last_foot)
		if _foot_dist >= FOOT_STRIDE:
			_foot_dist = 0.0
			var dir := (p.pos - _last_foot).normalized()
			var side := Vector2(-dir.y, dir.x) * FOOT_APART * (1.0 if _left else -1.0)
			_left = not _left
			var at := p.pos + side
			stamp(Vector3(at.x, LIFT, at.y), atan2(-dir.x, -dir.y), FOOT_SIZE, FOOT)
	_last_foot = p.pos
	_since_age += delta
	if _since_age >= AGE_EVERY:
		age(_since_age)
		_since_age = 0.0


## A mark at a point on the ground, turned `yaw`, `size` tiles across and along, of a kind (FOOT or TREAD).
func stamp(at: Vector3, yaw: float, size: Vector2, kind: float) -> void:
	var i := _next
	_next = (_next + 1) % CAPACITY
	_ages[i] = 0.0
	_kinds[i] = kind
	multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size.x, 1.0, size.y)), at))
	multimesh.set_instance_custom_data(i, Color(kind, 0.0, 0.0, 0.0))


## Time passes: every mark fades a little, and one that has lasted LIFE is gone.
func age(seconds: float) -> void:
	for i in CAPACITY:
		if _ages[i] >= LIFE:
			continue
		_ages[i] += seconds
		if _ages[i] >= LIFE:
			_hide(i)
		else:
			multimesh.set_instance_custom_data(i, Color(_kinds[i], _ages[i] / LIFE, 0.0, 0.0))


## How faded mark `i` is: 0 fresh, 1 gone.
func fade_of(i: int) -> float:
	return clampf(_ages[i] / LIFE, 0.0, 1.0)


## How many marks are on the ground now.
func live() -> int:
	var n := 0
	for a in _ages:
		if a < LIFE:
			n += 1
	return n


func _hide(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))


## A vehicle worked an area (a job's result is empty if it failed): two wheel tracks along each lane of it.
func _on_action_done(job: Dictionary, result: Dictionary) -> void:
	if str(job.get("kind", "")) != "vehicle" or result.is_empty():
		return
	var area := Game.vehicles.vehicle_area(str(job["item"]))
	lay_tracks(int(job["row"]), int(job["col"]), area)


## Wheel tracks over an area (row, col: its corner; area: tiles across and down): lanes of two treads each,
## running down the area.
func lay_tracks(row: int, col: int, area: Vector2i) -> void:
	var lanes := maxi(ceili(area.x / LANE), 1)
	for k in lanes:
		var x := col + minf(LANE * (k + 0.5), area.x - 0.5)
		for side: float in [-1.0, 1.0]:
			stamp(Vector3(x + side * TREAD_APART, BED_LIFT, row + area.y / 2.0), 0.0, Vector2(TREAD_WIDTH, area.y), TREAD)
