class_name NightGlow
extends CanvasLayer
## Lights that should shine through the darkness: a warm glow from the farmhouse
## and fireflies drifting over the farm. Drawn above the world (so the night tint
## doesn't dim them) but moves with the camera like the farm does.

const FIREFLIES := 26
## Light spots per object id: [along the front 0..1, height px, size].
const LIGHTS := {
	"farmhouse": [[0.25, 16, 1.0], [0.75, 30, 1.0]],
	"log_cabin": [[0.7, 22, 0.9]],
	"lamp_post": [[0.5, 46, 0.9]],
	"bonfire": [[0.5, 8, 1.3]],
	"bakery": [[0.3, 24, 1.0], [0.72, 34, 0.9]],
	"winery": [[0.3, 22, 1.0]],
	"spa": [[0.3, 24, 1.0], [0.75, 30, 0.8]],
	"garage": [[0.7, 30, 0.8]],
	"gazebo": [[0.5, 40, 0.7]],
}

var grid: FarmGrid
var dark := 0.0
var _canvas: Node2D
var _flies: Array = [] # {pos, phase, speed}


func _ready() -> void:
	layer = 2
	follow_viewport_enabled = true
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_glow)
	add_child(_canvas)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in FIREFLIES:
		_flies.append({"tile": Vector2(rng.randf(), rng.randf()), "phase": rng.randf() * TAU, "speed": rng.randf_range(0.6, 1.4)})


func _process(_delta: float) -> void:
	if dark > 0.01:
		_canvas.queue_redraw()
	elif _canvas.visible:
		_canvas.queue_redraw()


func _draw_glow() -> void:
	if dark <= 0.01 or grid == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	# Warm light from windows, lamps and fires. Each spot: [where along the front (0 = left corner,
	# 1 = right corner), height above the ground in px, size].
	for o in Game.objects:
		var spots: Array = LIGHTS.get(o["id"], [])
		if spots.is_empty():
			continue
		var fp := Game.footprint(o["id"])
		var g := grid.corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
		var c := (g[0] + g[2]) / 2.0
		var left := c.lerp(g[3], 0.78)
		var right := c.lerp(g[1], 0.78)
		var bottom := c.lerp(g[2], 0.78)
		var flicker := 0.9 + 0.1 * sin(t * 3.1 + float(o["uid"]))
		for spot in spots:
			var along: float = spot[0]
			var at := (left.lerp(bottom, along * 2.0) if along <= 0.5 else bottom.lerp(right, along * 2.0 - 1.0)) + Vector2(0, -float(spot[1]))
			var sz: float = spot[2]
			var col: Color = Color(1.0, 0.55, 0.2) if o["id"] == "bonfire" else Color(1.0, 0.78, 0.4)
			var fl := flicker if o["id"] != "bonfire" else 0.75 + 0.25 * sin(t * 9.0 + float(o["uid"]))
			for r in 4:
				_canvas.draw_circle(at, (18.0 + r * 16.0) * sz, Color(col.r, col.g, col.b, dark * fl * (0.16 - r * 0.035)))
			_canvas.draw_circle(at, 7.0 * sz, Color(1.0, 0.86, 0.55, dark * fl * 0.9))

	# Fireflies wander slowly over the farm and blink.
	var size := Game.farm_size
	for f in _flies:
		var base: Vector2 = f["tile"]
		var ph: float = f["phase"]
		var sp: float = f["speed"]
		var row := base.x * size + sin(t * 0.3 * sp + ph) * 0.6
		var col := base.y * size + cos(t * 0.27 * sp + ph * 1.3) * 0.6
		var p := grid.top_of_f(row, col) + Vector2(0, -18 - 10 * sin(t * sp + ph))
		var blink := clampf(sin(t * 1.6 * sp + ph) * 1.5, 0.0, 1.0)
		var a := dark * blink
		if a <= 0.02:
			continue
		_canvas.draw_circle(p, 9.0, Color(0.85, 1.0, 0.45, a * 0.22))
		_canvas.draw_circle(p, 3.0, Color(0.95, 1.0, 0.7, a))
