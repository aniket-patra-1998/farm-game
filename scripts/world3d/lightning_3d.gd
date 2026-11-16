class_name Lightning3D
extends Node3D
## A storm's lightning in the 3D world (docs/WEATHER.md; our own touch): a strike (WeatherEvents.struck) draws
## one bolt far out past the farm, on the side the camera looks toward, from the clouds to the ground with a
## branch or two, flickering out over `bolt_seconds`; and `flash`, read by Farm3D, lights the whole frame for a
## moment. One mesh, made per strike and dropped after it (a few a minute at most); it casts no shadow and is
## seen through the fog. Nothing on the farm is ever struck.

const LEVELS := 5            # midpoint splits of the bolt's line (2^5 segments)
const JAG := 0.34            # how far a split may wander, of its segment's length
const WIDTH := 0.1           # the bolt's bright core (world units); branches are thinner..
const HALO := 6.0            # ..and its glow round it, this many times as wide, faint
const HALO_COLOUR := Color(0.55, 0.65, 1.0, 0.16)
const BRANCHES := 2          # at most this many branches
const FLASH_FALL := 3.5      # the flash fades this fast (a second)
const FLICKERS := [[1.0, 0.72], [0.6, 0.45], [0.3, 0.18]]   # spans of its life (1 down to 0) it shows in
const ACROSS := 0.4   # strikes fall across this share of the view's width either side of its middle
const COLOUR := Color(0.86, 0.9, 1.0)

var flash := 0.0
var _bolt: MeshInstance3D
var _life := 0.0
var _span := 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_bolt = MeshInstance3D.new()
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true   # (the core and the glow are coloured per ribbon)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true   # (seen through the storm's haze)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt.material_override = mat
	_bolt.visible = false
	add_child(_bolt)


## A strike `far` out (0 near .. 1 far) toward `toward` (0..TAU: where across the view), seen by
## `camera`, on a farm `size` tiles across, by the rules `storm` (data/weather.json).
func strike(far: float, toward: float, camera: Camera3D, size: int, storm: Dictionary) -> void:
	# Past the farm's far corner as the camera sees it (so never on the farm), as far again as the strike is
	# far, and across the view's width by `toward` (so a near one is seen, not lost behind the camera).
	var ahead := -camera.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var right := ahead.cross(Vector3.UP)
	var look := -camera.global_transform.basis.z
	var target := camera.global_position + look * (-camera.global_position.y / minf(look.y, -0.01))
	var centre := Vector3(size / 2.0, 0.0, size / 2.0)
	var near: Array = storm.get("near_tiles", [3.0, 8.0])
	var far_t: Array = storm.get("far_tiles", [12.0, 32.0])
	var near_to := WeatherEvents.NEAR_UP_TO
	var tiles := lerpf(float(near[0]), float(near[1]), far / near_to) if far < near_to \
		else lerpf(float(far_t[0]), float(far_t[1]), (far - near_to) / (1.0 - near_to))
	var across := (toward / TAU * 2.0 - 1.0) * camera.size * ACROSS * get_viewport().get_visible_rect().size.aspect()
	# (the farm is a diamond on screen: beside its middle its far edge is nearer, so a strike out to the side lands
	# just past the side edge, in view, instead of past the top corner and off the screen)
	var aside := absf((target + right * across - centre).dot(right))
	var past := (centre - target).dot(ahead) + maxf(0.0, size * 0.7071 - aside) + tiles
	var ground := target + ahead * past + right * across
	var top := ground + Vector3(_rng.randf_range(-3.0, 3.0), float(storm.get("bolt_height", 26.0)),
		_rng.randf_range(-3.0, 3.0))
	_bolt.mesh = _mesh(top, ground, camera)
	_span = float(storm.get("bolt_seconds", 0.32))
	_life = _span
	_bolt.visible = true
	flash = float(storm.get("flash", 1.0)) * lerpf(1.0, 0.45, far)


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta * FLASH_FALL)
	if _life <= 0.0:
		return
	_life -= delta
	var t := _life / _span
	var on := false
	for span: Array in FLICKERS:
		on = on or (t <= float(span[0]) and t >= float(span[1]))
	_bolt.visible = on and _life > 0.0
	if _life <= 0.0:
		_bolt.mesh = null


## The bolt's mesh: a jagged line from `top` to `ground` and a branch or two, as flat ribbons turned to the
## camera (so a thin line reads at any zoom).
func _mesh(top: Vector3, ground: Vector3, camera: Camera3D) -> ArrayMesh:
	var view := -camera.global_transform.basis.z
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := _jagged(top, ground)
	_glowing(st, trunk, WIDTH, view)
	for b in _rng.randi_range(1, BRANCHES):
		var from: Vector3 = trunk[_rng.randi_range(trunk.size() / 5, trunk.size() / 2)]
		var to := from + Vector3(_rng.randf_range(-6.0, 6.0), -(from.y - ground.y) * _rng.randf_range(0.3, 0.6),
			_rng.randf_range(-6.0, 6.0))
		_glowing(st, _jagged(from, to), WIDTH * 0.6, view)
	return st.commit()


func _jagged(a: Vector3, b: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	for level in LEVELS:
		var next := PackedVector3Array()
		for k in pts.size() - 1:
			var p := pts[k]
			var q := pts[k + 1]
			var reach := p.distance_to(q) * JAG
			next.append(p)
			next.append((p + q) / 2.0 + Vector3(_rng.randf_range(-reach, reach), _rng.randf_range(-reach, reach) * 0.3,
				_rng.randf_range(-reach, reach)))
		next.append(pts[pts.size() - 1])
		pts = next
	return pts


## A line of the bolt: a faint wide glow, then the bright thin core over it.
func _glowing(st: SurfaceTool, pts: PackedVector3Array, width: float, view: Vector3) -> void:
	_ribbon(st, pts, width * HALO, view, HALO_COLOUR)
	_ribbon(st, pts, width, view, COLOUR)


func _ribbon(st: SurfaceTool, pts: PackedVector3Array, width: float, view: Vector3, colour: Color) -> void:
	# One joined strip (each point's side shared by the segments either side of it): no overlapping quads, so the
	# glow adds up evenly instead of in bright knots at the joints.
	st.set_color(colour)
	var sides := PackedVector3Array()
	for k in pts.size():
		var along := pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]
		sides.append(along.cross(view).normalized() * width * lerpf(1.0, 0.4, float(k) / pts.size()))
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		st.add_vertex(a - sides[k])
		st.add_vertex(a + sides[k])
		st.add_vertex(b + sides[k + 1])
		st.add_vertex(a - sides[k])
		st.add_vertex(b + sides[k + 1])
		st.add_vertex(b - sides[k + 1])
