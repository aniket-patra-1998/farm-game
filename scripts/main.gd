class_name FarmMain
extends Node2D
## Wires the farm, camera and HUD together, frames the farm on any screen,
## and handles zooming and moving around the farm.
##
## Touch: pinch to zoom, two-finger drag to move, or one-finger drag with the Hand tool.
## Mouse: wheel to zoom, right- or middle-drag to move. Trackpad gestures also work.

const FAR_FLASH := 0.35       # the 2D world's screen flash for the farthest strike (a near one is full)
const WARM_WEATHERS: Array[String] = ["rain", "storm", "snow", "fog"]   # under the first cover: _warm_weather
const WARM_WEATHER_FRAMES := 4
const SCREEN_FLASH_3D := 0.35 # in 3D the frame lights itself (Lightning3D.flash): the screen adds a little
const INK := 0.0   # the dark outline drawn round things (grade.gdshader), 0 off: FarmVille's inked look
const INK_FROM := 0.22    # how small a jump in light or colour is an edge (lower: more lines)
const INK_REACH := 1.0    # how many pixels out it looks, so how thick the line is
const TAP_WORDS_MS := 300   # the game's words this soon after a tap belong to it (shown in its bubble)
const CLOSEST_TILES := 3.5   # the closest zoom shows about this many tiles across, whatever the farm's size
const MIN_CLOSE_FACTOR := 1.5 # (and is always at least this much closer than the whole-farm view)
const FURTHEST_OUT := 1.25    # how far past the whole-farm view you can pull back
const WHEEL_STEP := 1.1
const ROOSTER_HOME := "chicken"   # not-ui: a farm with one of these (a hen, a coop) hears the dawn
const MORNING := [5.0, 11.0]      # the hours the day's first open of the farm hears the rooster (owner, 19 Nov)
const CROWED := "rooster"         # not-ui (the player's settings section: the day it last crowed)
const NIGHT_FROM := 0.6       # how dark it is (DayCycle's 0..1) when the animals go to sleep
const READY_ZOOM := 2.2       # going to a ready thing zooms in to at least this many times the whole-farm view
const DAYLIGHT_EVERY := 0.1   # seconds between updates of the 3D sun, sky light and window glow

var grid: FarmGrid
var camera: FarmCamera
var hud: FarmHud
var sky: SkyLayer
var light: CanvasModulate  # tints the whole farm for the time of day
var night: NightGlow
var shadows: CloudShadows
var grade: ColorRect       # colour grade over the farm and sky
var weather_fx: WeatherLayer
var weather_events: WeatherEvents
var world_3d: Farm3D        # the farm in real 3D (project setting farm/world/use_3d), behind the 2D layers

var _base_zoom := 1.0       # zoom that shows the whole farm (you can pull back a little past it)
var _warm_at := 0         # frames into the weather warm-up under the first cover (-1: done)
var _warm_was := ""       # the weather override before it
var _last_input_msec := 0   # when the player last touched anything (0: not yet), for the idle view
var _idle_after_msec := 0   # how long with no touch before the interface fades away (0 never)
var _was_night := false     # it was night at the last look (first light after it: the rooster)
var _crowed_day := -2       # the day the rooster last crowed (-2: not read from the settings yet)
var _waking := false        # the press that brought the interface back is being swallowed, to its release
var _touches := {}          # finger index -> screen position
var _pinch_dist := 0.0
var _mouse_panning := false
var _since_daylight := 1.0   # (starts due, so the first frame is lit)


func _ready() -> void:
	StartMarks.mark("main_made")   # not-ui (the main scene loaded)
	PerfReadout.show_in(get_tree(), PerfReadout.wanted())   # debug builds, when switched on in Settings
	Display.apply()   # full screen if chosen (a computer opens maximised: project.godot's window mode)
	sky = SkyLayer.new()
	add_child(sky)

	light = CanvasModulate.new()
	add_child(light)

	grid = FarmGrid.new()
	add_child(grid)

	shadows = CloudShadows.new()
	shadows.grid = grid
	add_child(shadows)

	var grade_layer := CanvasLayer.new()
	grade_layer.layer = 1
	add_child(grade_layer)
	grade = ColorRect.new()
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grade.gdshader")
	grade.material = mat
	grade_layer.add_child(grade)

	weather_fx = WeatherLayer.new()
	add_child(weather_fx)
	weather_events = WeatherEvents.new()   # (lightning, thunder and the rain's sound: docs/WEATHER.md)
	add_child(weather_events)
	weather_events.struck.connect(_on_struck)

	night = NightGlow.new()
	night.grid = grid
	add_child(night)

	camera = FarmCamera.new()
	camera.top_margin = FarmHud.top_h()
	camera.bottom_margin = FarmHud.bottom_h()
	# You can look out over the countryside a little, but not off into nothing.
	camera.area_provider = func() -> Rect2:
		var pad := FarmGrid.TILE_W * 4.0
		return grid.get_bounds().grow_individual(pad, pad / 2.0, pad, pad / 2.0)
	add_child(camera)
	camera.make_current()
	if Farm3D.enabled():
		_use_3d()
	StartMarks.mark("world")   # not-ui (the farm's layers and its 3D world made)

	hud = FarmHud.new()
	add_child(hud)
	StartMarks.mark("hud")   # not-ui (the HUD made)

	var fx := FxLayer.new()
	fx.hud = hud
	add_child(fx)
	grid.fx = fx

	hud.camera = camera
	hud.grid = grid
	hud.fit_view = _fit_camera
	hud.next_ready = go_to_next_ready
	hud.go_to = go_to_kind
	ItemSearch.show_on_farm = show_item_on_farm   # (search's Show on farm; a method, cleared in _exit_tree)
	_idle_after_msec = int(Balance.f("feel.idle_view_seconds") * 1000.0)
	hud.tool_selected.connect(grid.set_tool)
	hud.place_requested.connect(grid.start_placing)
	hud.cancel_place_requested.connect(grid.cancel_placing)
	hud.place_stored_requested.connect(grid.start_placing_stored)
	grid.placing_changed.connect(hud.show_placing)
	grid.tool_changed.connect(func(t: String) -> void: hud.tools.show_tool(t))
	grid.object_tapped.connect(hud.show_building)
	grid.panel_requested.connect(hud.show_panel)
	grid.tapped_info.connect(hud.bubble.show_at)
	grid.tapped_rust.connect(hud.bubble.show_repair)
	grid.vehicle_seed_wanted.connect(hud.use_vehicle)
	hud.bubble.to_screen = func(p: Vector2) -> Vector2: return grid.get_global_transform_with_canvas() * p
	# Every word about a tap shows where the finger was, in the tapped thing's bubble (FarmVille's way), not a
	# message at the top; the game's own news (a level, a find) stays a message.
	grid.info.connect(func(text: String) -> void:
		hud.bubble.show_at(grid.last_tap_at + Vector2(0, -FarmGrid.BUBBLE_LIFT * 0.6), text, "", -1))
	# The game's words just after a tap on the farm (a refusal, a result) show at the tap, in its bubble; later
	# news (the farmer's work done, a find while away) and anything said with a panel open stays at the top.
	Game.message.connect(func(text: String) -> void:
		if not Game.modal_open and Time.get_ticks_msec() - grid.last_tap_msec <= TAP_WORDS_MS:
			hud.bubble.show_at(grid.last_tap_at + Vector2(0, -FarmGrid.BUBBLE_LIFT * 0.6), text, "", -1)
		else:
			hud.show_message(text))

	get_viewport().size_changed.connect(_on_resized)
	Game.farm_expanded.connect(func(_size: int) -> void: _fit_camera())
	_fit_camera()
	Quality.apply_frame_cap()    # (and again whenever the level is chosen: Quality.choose)
	FrameClock.start_in(self)    # (this frame's script time, for AutoQuality and the benchmark)
	AutoQuality.start_in(self)   # keeps the device smooth: steps down when frames stay slow (until the player chooses)
	# The farm is built; its first frames, while the renderer prepares every material, stay under a cover (only
	# when the game itself is running: the screenshot and probe tools load this scene inside their own).
	StartMarks.mark("main_built")   # not-ui (the farm laid out, before its first frame)
	if get_tree().current_scene == self:
		LoadingCover.cover(self, Game.player.farm_name if Game.player.farm_name != "" else tr("MY_FARM"), world_3d)
		OnlineGate.check(self)   # (the game plays only online: asked while the farm opens, docs/PACKS.md)
		hud.intro.open_when_ready(self)   # (a brand-new farm: its name, farmer and region, once the cover lifts)
		Game.farm_opened.connect(_on_farm_opened)
		if StartMarks.benchmark_wanted():
			load(StartMarks.BENCHMARK).start(self)   # (the benchmark build measures loading on the phone by itself, then quits)


## Another farm laid out in place of this one (the showcase, or back to your own): it is covered while it is
## built and drawn, as the game's first farm is, and seen whole (so every material is drawn once under the cover).
func _on_farm_opened() -> void:
	_fit_camera()
	if not Game.in_showcase():
		PhoneNotices.ask_permission()   # (Android 13+: asked once, with the farm already on screen behind it)
	LoadingCover.cover(self, Game.player.farm_name if Game.player.farm_name != "" else tr("MY_FARM"), world_3d)
	hud.intro.open_when_ready(self)   # (a new farm started in Settings gets its first screen too)


## The farm drawn in 3D: its world goes behind every 2D layer; the 2D sky, ground and the pieces that
## now have 3D models step aside; taps, highlights, signs and effects stay in 2D on top.


## Leaving: nothing static may keep a callable into this scene. A lambda kept in a static outlives the scene's
## script and corrupts the heap when the engine shuts down (the crash on every quit, a freeze on a computer).
func _exit_tree() -> void:
	ItemSearch.show_on_farm = Callable()


## Search's Show on farm: the panels close and the view goes to the nearest `id`.
func show_item_on_farm(id: String) -> void:
	hud.close_panels()
	go_to_kind(FarmGrid.ITEM_SPOT + id)

func _use_3d() -> void:
	world_3d = Farm3D.new()
	world_3d.grid = grid
	world_3d.camera_2d = camera
	add_child(world_3d)
	sky.visible = false
	shadows.visible = false
	grid.ground.visible = false
	grid.shadows.visible = false
	light.color = Color.WHITE
	grid.pieces.three_d = true
	grid.pieces.sync()
	# The 2D pieces now only keep the list of ready things for the overlay: nothing to draw or animate.
	grid.pieces.visible = false
	grid.pieces.set_process(false)
	# The 2D night glow too: in 3D the windows, lamps and fireflies light themselves.
	night.visible = false
	night.set_process(false)


## Zoom so the whole farm fits between the top bar and the toolbar,
## in landscape or portrait, on phones and tablets.
func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var bounds := grid.get_bounds()
	var usable := view - Vector2(0, FarmHud.top_h() + FarmHud.bottom_h())
	_base_zoom = minf(usable.x / (bounds.size.x * 1.04), usable.y / (bounds.size.y * 1.04))
	_set_zoom_limits(view)
	# The free area is shifted down by half the difference between the bars.
	var shift := (FarmHud.top_h() - FarmHud.bottom_h()) / 2.0
	camera.snap(bounds.get_center() - Vector2(0, shift / _base_zoom), _base_zoom)


## A storm's lightning struck (WeatherEvents): the screen flashes and, in 3D, a bolt falls past the farm.
func _on_struck(far: float, toward: float) -> void:
	weather_fx.flash_now(lerpf(1.0, FAR_FLASH, far) if world_3d == null else lerpf(SCREEN_FLASH_3D, 0.0, far))
	if world_3d != null:
		world_3d.lightning.strike(far, toward, world_3d.camera, Game.farm_size, WeatherEvents.data("storm"))


## The Next ready button: the view travels to the nearest thing with something to take that it has not shown yet
## (FarmGrid.next_ready).
func go_to_next_ready() -> void:
	_travel_to(grid.next_ready(grid.to_local(camera.global_position)))


## The away card's rows: the view travels to the nearest thing of `kind` ("ripe", "withered", "ready", "hungry",
## "stray": FarmGrid.spots_of) and it is pointed out.
func go_to_kind(kind: String) -> Dictionary:
	var spot := FarmGrid.nearest_spot(grid.spots_of(kind), grid.to_local(camera.global_position))
	if not spot.is_empty():
		grid.point_out(spot)
	_travel_to(spot)
	return spot


## The view travels to a spot on the farm ({at}: FarmGrid.spots_of), close enough to see it, and sits it in the
## middle of the free area between the bars. Nothing for {}.
func _travel_to(spot: Dictionary) -> void:
	if spot.is_empty():
		return
	var z := clampf(maxf(camera.target_zoom, _base_zoom * READY_ZOOM), camera.min_zoom, camera.max_zoom)
	var shift := (FarmHud.top_h() - FarmHud.bottom_h()) / 2.0
	camera.go_to(grid.to_global(spot["at"]) - Vector2(0, shift / z), z)


# ---------------------------------------------------------------- the idle farm


## Any touch, click or key is the player being here: it puts off the idle view, and when the interface had faded
## away it brings it back and does nothing else (that press, to its release, is swallowed: it was aimed at a
## farm with no buttons on it).
func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton
			or event is InputEventKey or event is InputEventGesture):
		return
	_last_input_msec = Time.get_ticks_msec()
	if hud.resting:
		hud.set_resting(false)
		_waking = true
	if _waking:
		get_viewport().set_input_as_handled()
		if not event.is_pressed() and not event is InputEventScreenDrag and not event is InputEventGesture:
			_waking = false


## The idle view (our own touch): after a while with no touch (Balance `feel.idle_view_seconds`) the interface
## fades away and the farm plays on. Never before the first touch (a tool or a test left running is not a player),
## nor from under a panel, a sheet, a thing being placed or the tutorial's hint.
func _rest_when_idle() -> void:
	if hud.resting:
		if Game.modal_open:
			hud.set_resting(false)   # something came up by itself (a level, a gift): it is shown
		return
	if _idle_after_msec <= 0 or _last_input_msec == 0 or Time.get_ticks_msec() - _last_input_msec < _idle_after_msec:
		return
	if Game.modal_open or hud.interface_hidden or hud.reading() or not grid.placing.is_empty() \
			or Game.tutorial_step != GameState.Tutorial.DONE:
		return
	hud.set_resting(true)


func _set_zoom_limits(view: Vector2) -> void:
	var limits := zoom_limits(minf(view.x, view.y), _base_zoom)
	camera.min_zoom = limits.x
	camera.max_zoom = limits.y


## The window or screen changed size (full screen switched, the window maximised, a tablet turned): the zoom
## limits follow the new shape, and the view stays where the player had it, only kept within the new limits.
func _on_resized() -> void:
	var view := get_viewport_rect().size
	var bounds := grid.get_bounds()
	var usable := view - Vector2(0, FarmHud.top_h() + FarmHud.bottom_h())
	_base_zoom = minf(usable.x / (bounds.size.x * 1.04), usable.y / (bounds.size.y * 1.04))
	_set_zoom_limits(view)
	camera.snap(camera.position, clampf(camera.target_zoom, camera.min_zoom, camera.max_zoom))


## [furthest out, closest in] for a screen whose shorter side is `side` long and whose whole-farm zoom is `base`:
## the closest shows about CLOSEST_TILES tiles across that side at any farm size (FarmVille's close-up didn't
## shrink as the farm grew), in landscape or portrait.
static func zoom_limits(side: float, base: float) -> Vector2:
	var closest := maxf(side / (CLOSEST_TILES * FarmGrid.TILE_W), base * MIN_CLOSE_FACTOR)
	return Vector2(base / FURTHEST_OUT, closest)


## Under the first loading cover, every kind of weather is shown for a few frames, unseen, then the real weather
## again: the first rain on the A05s cost two frames of 1.1 s of GPU (all it brings drawn the first time: wet
## ground, rain on water, haze, its sky), mid-game. Shown here they are ready before the farm is.
func _warm_weather() -> void:
	if _warm_at < 0:
		return
	if LoadingCover.covering == 0:
		if _warm_at > 0:
			Game.weather_override = _warm_was
		_warm_at = -1   # (once only: the first cover; no cover, nothing to do it under)
		return
	if _warm_at == 0:
		_warm_was = Game.weather_override
	var k := _warm_at / WARM_WEATHER_FRAMES
	Game.weather_override = WARM_WEATHERS[k] if k < WARM_WEATHERS.size() else _warm_was
	_warm_at += 1 if k < WARM_WEATHERS.size() else 0


# ---------------------------------------------------------------- time of day

func _process(_delta: float) -> void:
	_rest_when_idle()
	_warm_weather()
	var hour := sky.hour
	var look := DayCycle.sample(hour)
	var w := Game.weather()
	var dark: float = look["dark"]
	# Light on the farm: the time of day's colour, greyer and dimmer under cloud.
	var l: Color = look["light"]
	l = l.lerp(Color(l.v, l.v, l.v), float(w["desat"]) * 0.5).darkened(float(w["dim"]))
	if world_3d != null:
		_since_daylight += _delta
		if _since_daylight >= DAYLIGHT_EVERY:   # the sun moves slowly: ten times a second is smooth
			_since_daylight = 0.0
			world_3d.set_daylight(hour, w)
			ModelKit.set_window_glow(dark)
			world_3d.set_night(dark)
			# Night and day for the animals (they sleep in the dark), and the rooster at first light.
			var night := dark > NIGHT_FROM
			# First light, or the farm opened in the morning (owner, 19 Nov: only a game left open over the dawn
			# ever heard it): once a day, on a farm with chickens to have a rooster.
			var morning := hour >= float(MORNING[0]) and hour < float(MORNING[1])
			if _crowed_day == -2:   # (kept on the device: once a day, however often the farm is opened)
				_crowed_day = int(PlayerSettings.value(CROWED, "day", -1))
			var due := (_was_night or morning) and _crowed_day != Game.day_number() and LoadingCover.covering == 0
			if not night and due and Game.objects.any(
					func(o: Dictionary) -> bool: return str(o["id"]).contains(ROOSTER_HOME)):
				_crowed_day = Game.day_number()
				PlayerSettings.keep(CROWED, {"day": _crowed_day})
				Feedback.moment("dawn")   # (a farm with chickens has a rooster to say so)
			_was_night = night
			AnimalBehaviour.night = night
			AnimalBehaviour.hour = hour
			AnimalBehaviour.rain = float(w["rain"])
	else:
		light.color = l
	sky.weather = w
	weather_fx.look = w
	weather_events.look = w
	# Windows light up at night and in a dark storm.
	night.dark = maxf(dark, clampf(float(w["dim"]) * 1.6 - 0.2, 0.0, 0.7))
	# Cloud shadows need the sun out and some cloud about.
	var sun := DayCycle.sun_progress(hour)
	var cover: float = w["cover"]
	shadows.strength = 0.0 if sun < 0.0 else (1.0 - dark) * clampf(1.0 - absf(cover - 0.45) / 0.4, 0.0, 1.0)
	# Colour grade: richer by day, cool and soft at night, warm low sun, fog haze.
	var m := grade.material as ShaderMaterial
	var sat := lerpf(Grade.value("day_saturation"), Grade.value("night_saturation"), dark) * (1.0 - float(w["desat"]))
	var contrast := lerpf(Grade.value("day_contrast"), Grade.value("night_contrast"), dark)
	var lift := Vector3(0.02, 0.035, 0.08) * dark
	if world_3d != null:
		# In 3D the frame's own adjustments take the grade and the 3D fog the haze; the full-screen pass is left
		# with the low sun's warmth and the vignette, and runs only where the quality level asks for it.
		world_3d.set_screen_grade(sat, contrast, lift)
		grade.visible = bool(Quality.value("screen_grade"))
		if not grade.visible:
			return
		sat = 1.0
		contrast = 1.0
		lift = Vector3.ZERO
	m.set_shader_parameter("ink", INK)
	m.set_shader_parameter("ink_from", INK_FROM)
	m.set_shader_parameter("ink_reach", INK_REACH)
	m.set_shader_parameter("saturation", sat)
	m.set_shader_parameter("contrast", contrast)
	m.set_shader_parameter("lift", lift)
	var low := 0.0 if sun < 0.0 else pow(1.0 - sin(sun * PI), 3.0)  # 1 right at sunrise and sunset
	m.set_shader_parameter("warm", Color(1.0, 0.7, 0.45, 0.22 * low * (1.0 - cover)))
	m.set_shader_parameter("warm_from", Vector2(0.0 if sun < 0.5 else 1.0, 0.3))
	var haze := Color(0.84, 0.87, 0.9, float(w["fog"]) * 0.75).lerp(Color(0.25, 0.3, 0.42, float(w["fog"]) * 0.6), dark)
	if world_3d != null:
		haze.a = 0.0   # (the 3D fog is the haze)
	m.set_shader_parameter("haze", haze)
	m.set_shader_parameter("vignette", lerpf(0.18, 0.4, dark))


# ---------------------------------------------------------------- zoom and move

func _unhandled_input(event: InputEvent) -> void:
	if Game.modal_open:
		_touches.clear()
		_mouse_panning = false
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom_by(WHEEL_STEP, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom_by(1.0 / WHEEL_STEP, mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mouse_panning = mb.pressed
			if mb.pressed:
				camera.begin_drag()
			else:
				camera.end_drag()

	elif event is InputEventMouseMotion and _mouse_panning:
		_pan((event as InputEventMouseMotion).relative)

	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		camera.zoom_by(mg.factor, mg.position, true)

	elif event is InputEventPanGesture:
		_pan(-(event as InputEventPanGesture).delta * 24.0)

	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
			if _touches.is_empty():
				camera.end_drag()  # let go: the view glides on and settles
		if _touches.size() == 2:
			# A second finger means zoom or move, never farming.
			grid.cancel_paint()
			_pinch_dist = _two_finger_distance()
			camera.begin_drag()

	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if not _touches.has(d.index):
			return
		_touches[d.index] = d.position
		if _touches.size() >= 2:
			var dist := _two_finger_distance()
			if _pinch_dist > 0.0:
				_zoom_at(_two_finger_center(), dist / _pinch_dist)
			_pinch_dist = dist
			_pan(d.relative / 2.0)
		elif d.index == 0 and grid.placing.is_empty() and grid.is_dragging():
			if not camera.is_dragging():
				camera.begin_drag()
			_pan(d.relative)


func _two_finger_distance() -> float:
	var pts := _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _two_finger_center() -> Vector2:
	var pts := _touches.values()
	return ((pts[0] as Vector2) + (pts[1] as Vector2)) / 2.0


## Screen point -> world point for the current camera.
func _to_world(screen_pos: Vector2) -> Vector2:
	return camera.to_world(screen_pos)


## Zooms keeping the point under the finger or cursor in place (instantly: pinches follow the fingers).
func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	camera.zoom_by(factor, screen_pos, true)


func _pan(screen_delta: Vector2) -> void:
	camera.pan_by(screen_delta)
