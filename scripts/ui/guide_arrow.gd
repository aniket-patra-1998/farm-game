class_name GuideArrow
extends Control
## Show me's pointer (owner's pick, 27 Nov: "just an arrow pointing, no words"): one chunky arrow, the kit's gold
## with a dark wood edge and a soft shadow, bobbing toward what to tap (a tool, a plot, a thing on the farm, a card
## in the Market), as Hay Day and Township point. It follows its target every frame (the view may travel); a target
## off screen gets the arrow at the screen's edge, turned toward it. It goes at the player's next tap, when its
## target is gone, or after LIFE seconds. Draws itself; takes no taps.

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

var target: Callable        # () -> Vector2 on screen, or Vector2.INF when the target is gone
var _age := 0.0
var _lost := 0.0


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
static func at_control(c: Control) -> Callable:
	return func() -> Vector2:
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			return Vector2.INF
		var r := c.get_global_rect()
		return Vector2(r.get_center().x, r.position.y)   # (its top: the arrow comes down onto it, owner, 28 Nov)


func _process(delta: float) -> void:
	_age += delta
	_lost = _lost + delta if not target.is_valid() or target.call() == Vector2.INF else 0.0
	if _age > LIFE or _lost > LOST:
		queue_free()
		return
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _age < GRACE:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		queue_free()


func _draw() -> void:
	if not target.is_valid():
		return
	var to: Vector2 = target.call()
	if to == Vector2.INF:
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
