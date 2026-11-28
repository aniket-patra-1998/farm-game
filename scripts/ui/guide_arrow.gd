class_name GuideArrow
extends Control
## Show me's pointer (owner's pick, 27 Nov: "just an arrow pointing, no words"): one chunky arrow, the kit's gold
## with a dark wood edge and a soft shadow, bobbing toward what to tap (a tool, a plot, a thing on the farm, a card
## in the Market), as Hay Day and Township point. It follows its target every frame (the view may travel); a target
## off screen gets the arrow at the screen's edge, turned toward it. It goes at the player's next tap, when its
## target is gone, or after LIFE seconds. Draws itself; takes no taps.
## In the guided start it is a spotlight (owner's pick A, 28 Nov: Hay Day's and Township's way): the screen dims
## but for a soft circle round what to tap, a ring pulses round it and a hand taps it. A tap outside the circle does
## nothing but send the spotlight away for a while (`rest_until`), so a player who wants something else gets it.

const LIFE := 10.0          # seconds it stays when nothing is tapped
const GRACE := 0.3          # seconds before a tap sends it away (the Show me tap itself)
const LOST := 0.6           # seconds its target may be missing (a list still filling) before it goes
const BOB := 0.22           # how far it bobs, of its length
const BOB_SPEED := 5.0      # radians a second
const HEAD := 0.55          # the head's length, of the arrow's
const STEM := 0.36          # the stem's width, of the arrow's width
const WIDTH := 0.8          # the arrow's width, of its length
const EDGE := 0.12          # its outline, of its width
const GAP := 0.08           # the gap between its tip and the target (an object's top), of its length
const SHADOW := Color(0, 0, 0, 0.3)
const SHADOW_DROP := 3.0
const DIM := Color(0, 0, 0, 0.55)  # the spotlight's dark round the circle
const FADE_IN := 0.25       # seconds the dark takes to come
const HOLE_DROP := 0.75     # the circle's middle below the target's top, of its radius (a button's, a card's top)
const REST_MS := 8000       # a tap outside the circle: no spotlight again for this long
const RING_PULSE := 4.0     # px the ring breathes
const TAP_SPEED := 4.0      # the hand's taps, radians a second
const TAP_DEPTH := 0.18     # how far the hand moves in to tap, of the circle's radius
const HAND_TILT := -0.42    # radians the hand leans (its finger up and to the left)
const HAND_SIZE := 1.5      # the hand's height, of the circle's radius
const ARC_POINTS := 12      # points on each quarter of the circle's edge
## The hand as one outline in a 64 x 74 box, its fingertip at (25.5, 3): a glove pointing up.
const HAND: Array[Vector2] = [Vector2(22, 8), Vector2(25.5, 3), Vector2(29, 8), Vector2(29, 32), Vector2(31, 21),
	Vector2(34.5, 17), Vector2(38, 21), Vector2(38, 33), Vector2(40, 25), Vector2(43.5, 21), Vector2(47, 25),
	Vector2(47, 37), Vector2(49, 32), Vector2(52.5, 28), Vector2(55, 33), Vector2(52, 55), Vector2(45, 68),
	Vector2(33, 72), Vector2(27, 72), Vector2(18, 69), Vector2(12, 62), Vector2(4, 44), Vector2(5, 38),
	Vector2(10, 38), Vector2(22, 50)]
const HAND_TIP := Vector2(25.5, 3)
const HAND_BOX := 74.0

## Whether the arrow is a spotlight now (HudGuide sets it: the guided start, nothing in hand, no other card up).
static var spot_allowed := Callable()
## No spotlight before this (Time.get_ticks_msec): a tap outside one sent it away.
static var rest_until := 0

var target: Callable        # () -> Vector2 on screen, or Vector2.INF when the target is gone
var _age := 0.0
var _lost := 0.0
var _spot := false          # a spotlight this frame
var _hole := Vector2.INF    # its middle on screen


## Points at what `where` says (see `target`) until a tap; one at a time on `parent`.
static func point(parent: Node, where: Callable) -> GuideArrow:
	for c in parent.get_children():
		if c is GuideArrow:
			c.queue_free()
	var a := GuideArrow.new()
	a.name = "GuideArrow"   # not-ui (a node's name)
	a.target = where
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.set_anchors_preset(Control.PRESET_FULL_RECT)
	a.z_index = 100
	parent.add_child(a)
	return a


## The top middle of a Control on screen while it is shown (for `target`): the arrow points down at its top.
## Held weakly: a control freed (its panel closed) just ends the arrow. Every target below does the same.
static func at_control(c: Control) -> Callable:
	var ref: WeakRef = weakref(c)
	return func() -> Vector2:
		return top_of_control(ref.get_ref() as Control)


## `id`'s card in `list` while it shows it (a list reuses its cards as it scrolls).
static func at_card(list: CardList, id: String) -> Callable:
	var ref: WeakRef = weakref(list)
	return func() -> Vector2:
		var l := ref.get_ref() as CardList
		return top_of_control(l.card_of(id)) if l != null else Vector2.INF


## A point `at` of the farm grid (FarmGrid local), where the view shows it now.
static func at_farm(grid: FarmGrid, at: Vector2) -> Callable:
	var ref: WeakRef = weakref(grid)
	return func() -> Vector2:
		var g := ref.get_ref() as FarmGrid
		return g.to_screen(at) if g != null else Vector2.INF


static func top_of_control(c: Control) -> Vector2:
	if c == null or not c.is_visible_in_tree():
		return Vector2.INF
	var r := c.get_global_rect()
	return Vector2(r.get_center().x, r.position.y)   # (its top: the arrow comes down onto it, owner, 28 Nov)


func _process(delta: float) -> void:
	_age += delta
	_lost = _lost + delta if not target.is_valid() or target.call() == Vector2.INF else 0.0
	if _age > LIFE or _lost > LOST:
		queue_free()
		return
	_spot = false
	if target.is_valid() and spot_allowed.is_valid() and bool(spot_allowed.call()) \
			and Time.get_ticks_msec() >= rest_until:
		var to: Vector2 = target.call()
		if to != Vector2.INF and get_viewport_rect().has_point(to):
			_spot = true
			_hole = to + Vector2(0, hole_radius() * HOLE_DROP)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _age < GRACE:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		var at: Vector2 = event.position
		if _spot and at.distance_to(_hole) > hole_radius():
			get_viewport().set_input_as_handled()   # (outside the circle: this tap does nothing..)
			rest_until = Time.get_ticks_msec() + REST_MS   # (..but the spotlight goes, and stays away a while)
		queue_free()


## The spotlight circle's radius, px.
static func hole_radius() -> float:
	return UiTheme.size("guide_hole")


## Whether the spotlight is up (tests: a tap outside it does nothing).
func spotlit() -> bool:
	return _spot


func _draw() -> void:
	if not target.is_valid():
		return
	var to: Vector2 = target.call()
	if to == Vector2.INF:
		return
	if _spot:
		_draw_spot()
		return
	var length := UiTheme.size("guide_arrow")
	var view := get_viewport_rect()
	var inset := view.grow(-length * 1.2)
	var dir := Vector2.DOWN   # (pointing down at it from above, or up from below near the top)
	if to.y < view.position.y + length * 2.0:
		dir = Vector2.UP
	if not inset.has_point(to):   # (off screen: at the edge, turned toward it)
		var held := Vector2(clampf(to.x, inset.position.x, inset.end.x), clampf(to.y, inset.position.y, inset.end.y))
		if held.distance_to(to) > 1.0:
			dir = (to - held).normalized()
			to = held + dir * length * (1.0 + GAP)
	var bob := (sin(_age * BOB_SPEED) * 0.5 + 0.5) * BOB * length
	var tip := to - dir * (length * GAP + bob)
	var shape := _shape(tip, dir, length)
	var drop := Vector2(0, SHADOW_DROP)
	draw_colored_polygon(_moved(shape, drop), SHADOW)
	var edge := UiTheme.color("button_edge")
	draw_colored_polygon(_grown(shape, tip, dir, length), edge)
	draw_colored_polygon(shape, UiTheme.color("button_face_down"))


## The arrow as one outline: the head's point at `tip`, the stem behind it, along `dir`.
func _shape(tip: Vector2, dir: Vector2, length: float) -> PackedVector2Array:
	var side := dir.orthogonal()
	var w := length * WIDTH / 2.0
	var s := w * STEM / WIDTH * 2.0
	var neck := tip - dir * length * HEAD
	var tail := tip - dir * length
	return PackedVector2Array([tip, neck + side * w, neck + side * s, tail + side * s, tail - side * s,
		neck - side * s, neck - side * w])


## The same outline a little bigger, for the dark edge round it.
func _grown(shape: PackedVector2Array, tip: Vector2, dir: Vector2, length: float) -> PackedVector2Array:
	var mid := tip - dir * length * 0.5
	var edge := length * WIDTH * EDGE
	var out := PackedVector2Array()
	for p in shape:
		out.append(p + (p - mid).normalized() * edge)
	return out


static func _moved(shape: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in shape:
		out.append(p + by)
	return out


## The dark with its soft circle, the ring round the circle and the hand tapping in it.
func _draw_spot() -> void:
	var fade := clampf(_age / FADE_IN, 0.0, 1.0)
	var dim := Color(DIM, DIM.a * fade)
	var r := hole_radius()
	var c := _hole
	var view := get_viewport_rect()
	var box := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	# Round the circle's square: four bands; inside the square: four corners, each a corner less its quarter-circle.
	draw_rect(Rect2(view.position, Vector2(view.size.x, maxf(box.position.y - view.position.y, 0.0))), dim)
	draw_rect(Rect2(Vector2(view.position.x, box.end.y), Vector2(view.size.x, maxf(view.end.y - box.end.y, 0.0))), dim)
	draw_rect(Rect2(Vector2(view.position.x, box.position.y), Vector2(maxf(box.position.x - view.position.x, 0.0),
		box.size.y)), dim)
	draw_rect(Rect2(Vector2(box.end.x, box.position.y), Vector2(maxf(view.end.x - box.end.x, 0.0), box.size.y)), dim)
	for q in 4:
		var from := PI + q * PI / 2.0
		var corner := c + Vector2(cos(from + PI / 4.0), sin(from + PI / 4.0)) * r * sqrt(2.0)
		var pts := PackedVector2Array([corner])
		for k in ARC_POINTS + 1:
			var a := from + PI / 2.0 * k / ARC_POINTS
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, dim)
	for k in 3:   # (a soft inner edge)
		draw_arc(c, r - 2.0 - k * 3.0, 0.0, TAU, ARC_POINTS * 4, Color(dim, dim.a * (0.45 - k * 0.15)), 3.0, true)
	var gold := UiTheme.color("glow_gold")
	var pulse := (sin(_age * BOB_SPEED) * 0.5 + 0.5) * RING_PULSE
	draw_arc(c, r + pulse + 6.0, 0.0, TAU, ARC_POINTS * 4, Color(gold, 0.35 * fade), 8.0, true)
	draw_arc(c, r + pulse, 0.0, TAU, ARC_POINTS * 4, Color(gold, fade), 4.0, true)
	_draw_hand(c, r, fade)


## The hand, its fingertip at the circle's middle, tapping in and out.
func _draw_hand(c: Vector2, r: float, fade: float) -> void:
	var scale_by := r * HAND_SIZE / HAND_BOX
	var tap := (sin(_age * TAP_SPEED) * 0.5 + 0.5) * TAP_DEPTH * r
	var lean := Vector2(cos(HAND_TILT + PI / 2.0), sin(HAND_TILT + PI / 2.0))   # (from the tip back along the hand)
	var tip := c + lean * (r * 0.1 + tap)
	var shape := PackedVector2Array()
	for p: Vector2 in HAND:
		shape.append(tip + ((p - HAND_TIP) * scale_by).rotated(HAND_TILT))
	var mid := tip + lean * r * HAND_SIZE * 0.5
	var edge := PackedVector2Array()
	for p in shape:
		edge.append(p + (p - mid).normalized() * maxf(2.0, r * 0.05))
	draw_colored_polygon(_moved(edge, Vector2(0, SHADOW_DROP)), Color(SHADOW, SHADOW.a * fade))
	draw_colored_polygon(edge, Color(UiTheme.color("ink"), fade))
	draw_colored_polygon(shape, Color(UiTheme.color("cream"), fade))
