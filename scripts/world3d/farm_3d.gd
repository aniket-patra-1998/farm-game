class_name Farm3D
extends Node3D
## The farm as a real 3D scene: real sunlight and shadows, so buildings, animals and crops stand on the
## ground with weight instead of being pictures laid on pictures. Everything else (the rules, taps, the
## HUD, floating coins, highlights) is unchanged: the 3D camera follows the 2D camera exactly through
## IsoProjection, so the two line up pixel for pixel.
##
## Owns the camera, the sun and moon, the sky light and fog (from the time of day and the weather), the
## ground, the plots, and the things standing on the farm. Turned on by the project setting
## farm/world/use_3d.

const SETTING := "farm/world/use_3d"
const SHADOW_DISTANCE := 90.0
const SUN_MAX_ELEVATION := deg_to_rad(58.0)
const SUN_MIN_ELEVATION := deg_to_rad(9.0)
const MOON_ELEVATION := deg_to_rad(40.0)

var grid: FarmGrid
var camera_2d: Camera2D

var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var ground: Ground3D
var plots: Plots3D
var crops: Crops3D
var objects: Objects3D


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, false))


func _ready() -> void:
	camera = Camera3D.new()
	camera.near = 1.0
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	sun.shadow_blur = 1.5
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# No sky reflections: a painted farm, not chrome. (They tinted every white wall blue.)
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	environment.glow_bloom = 0.04
	environment.adjustment_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	ground = Ground3D.new()
	add_child(ground)
	plots = Plots3D.new()
	add_child(plots)
	crops = Crops3D.new()
	add_child(crops)
	objects = Objects3D.new()
	objects.life = grid.life if grid != null else null
	objects.grid = grid
	add_child(objects)
	Game.plot_changed.connect(func(_i: int) -> void: _plots_changed())
	Game.farm_expanded.connect(func(_n: int) -> void:
		ground.rebuild()
		plots.rebuild())
	Game.objects_changed.connect(objects.queue_sync)
	if grid != null:
		# Taps go to what's drawn under the finger; tapped things react; harvests pop; landings puff.
		grid.picker = func(screen_pos: Vector2) -> int: return objects.pick(camera, screen_pos)
		grid.object_poked.connect(_poked)
		grid.plants_popped.connect(crops.pop)
		objects.landed.connect(func(at: Vector3) -> void:
			grid.world_fx.burst("dust", IsoProjection.grid_of(at)))


## Something was tapped: it bounces, and an animal looks round at you.
func _poked(uid: int) -> void:
	objects.bounce(uid)
	var mind := grid.life.mind(uid)
	if mind != null:
		mind.poke()


func _plots_changed() -> void:
	# Plowing or clearing a plot changes both the beds and where grass tufts grow; coalesced per frame.
	if not is_queued_for_deletion() and not has_meta("rebuild_queued"):
		set_meta("rebuild_queued", true)
		(func() -> void:
			remove_meta("rebuild_queued")
			plots.rebuild()
			crops.rebuild()
			ground.rebuild()).call_deferred()


func _process(_delta: float) -> void:
	if grid == null or camera_2d == null:
		return
	var centre := grid.to_local(camera_2d.get_screen_center_position())
	IsoProjection.aim(camera, centre, camera_2d.zoom.x, get_viewport().get_visible_rect().size.y)


## The light for this moment: called by main every frame with the hour and the weather.
func set_daylight(hour: float, weather: Dictionary) -> void:
	var look := DayCycle.sample(hour)
	var dark: float = look["dark"]
	var dim := float(weather.get("dim", 0.0))
	var cover := float(weather.get("cover", 0.0))
	var s := DayCycle.sun_progress(hour)
	var light_col: Color = look["light"]
	if s >= 0.0:
		var elevation := lerpf(SUN_MIN_ELEVATION, SUN_MAX_ELEVATION, sin(s * PI))
		_aim_light(s * PI, elevation)
		sun.light_color = light_col.lerp(Color(1.0, 0.82, 0.62), pow(1.0 - sin(s * PI), 3.0) * 0.6)
		sun.light_energy = (1.15 - 0.85 * cover) * (1.0 - dim) * (1.0 - dark)
		sun.shadow_opacity = clampf(1.0 - cover * 0.9, 0.15, 1.0)
	else:
		# Moonlight: faint and blue, from high behind the farm.
		var m := maxf(DayCycle.moon_progress(hour), 0.0)
		_aim_light(m * PI, MOON_ELEVATION)
		sun.light_color = Color(0.62, 0.72, 1.0)
		sun.light_energy = 0.28 * (1.0 - cover * 0.7)
		sun.shadow_opacity = 0.5
	var top: Color = look["top"]
	var horizon: Color = look["horizon"]
	environment.background_color = horizon
	# Shade is lit by the sky, but mostly warm-neutral bounce light off the grass and earth.
	environment.ambient_light_color = Color(0.86, 0.88, 0.84).lerp(top, 0.25).lerp(Color(0.75, 0.78, 0.82), cover * 0.5)
	environment.ambient_light_energy = lerpf(0.42, 0.3, dark) * (1.0 - dim * 0.4)
	environment.adjustment_saturation = lerpf(1.08, 0.75, dark) * (1.0 - float(weather.get("desat", 0.0)))
	var fog := float(weather.get("fog", 0.0))
	environment.fog_enabled = fog > 0.01
	environment.fog_light_color = horizon.lerp(Color(0.85, 0.88, 0.9), 0.6)
	environment.fog_density = 0.012 * fog
	ground.wind = float(weather.get("wind", 0.6))
	crops.wind = ground.wind


## Points the light from a spot on the sky: `arc` 0 is to the right of the screen, PI/2 behind the farm,
## PI to the left; so the morning sun throws shadows left, noon toward you, evening right.
func _aim_light(arc: float, elevation: float) -> void:
	var right := Vector3(1, 0, -1).normalized()
	var back := Vector3(-1, 0, -1).normalized()
	var flat := right * cos(arc) + back * sin(arc)
	var from := flat * cos(elevation) + Vector3.UP * sin(elevation)
	var centre := Vector3(Game.farm_size / 2.0, 0.0, Game.farm_size / 2.0)
	sun.look_at_from_position(centre + from * 50.0, centre, Vector3.UP if absf(from.y) < 0.99 else Vector3.BACK)
