class_name UiFx
extends RefCounted
## The interface's life (our own touch, the plush feel of modern farm games): things press in and spring back,
## cards pop in one after another as a panel opens, pictures catch a passing shine, and a panel swells open.
## Every motion is here, so the whole interface moves alike.

const PRESS_SCALE := 0.92         # a pressed thing sinks to this size..
const SPRING_SCALE := 1.06        # ..and overshoots to this on letting go
const PRESS_TIME := 0.07
const SPRING_TIME := 0.28
const POP_FROM := 0.82            # a card pops in from this size
const POP_TIME := 0.32
const POP_STAGGER := 0.035        # each next card starts this much later..
const POP_MOST := 0.5             # ..but none later than this
const OPEN_FROM := 0.9            # a panel swells open from this size
const OPEN_TIME := 0.26
const GLINT := preload("res://shaders/glint.gdshader")

static var pop_next := false      # the panel being opened pops its cards in (not on every refresh)..
static var popped := 0            # ..each a little after the last (set back to 0 as a panel opens)
static var _glint: ShaderMaterial


## `control` sinks a little while pressed and springs back past its size when let go.
static func press_bounce(control: BaseButton) -> void:
	control.resized.connect(func() -> void: control.pivot_offset = control.size / 2.0)
	control.button_down.connect(func() -> void: _scale_to(control, PRESS_SCALE, PRESS_TIME, Tween.TRANS_QUAD))
	control.button_up.connect(func() -> void:
		var t := _fresh_tween(control)
		if t == null:
			return
		t.tween_property(control, "scale", Vector2.ONE * SPRING_SCALE, SPRING_TIME * 0.35).set_trans(Tween.TRANS_QUAD)
		t.tween_property(control, "scale", Vector2.ONE, SPRING_TIME * 0.65).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT))


## `control` pops in when it joins the screen, if a panel is opening (`pop_next`), a little after the one before.
static func pop_in(control: Control) -> void:
	if not pop_next:
		return
	var order := popped
	popped += 1
	control.tree_entered.connect(func() -> void:
		control.pivot_offset = control.custom_minimum_size / 2.0
		control.scale = Vector2.ONE * POP_FROM
		control.modulate.a = 0.0
		var t := control.create_tween().set_parallel()
		var wait := minf(order * POP_STAGGER, POP_MOST)
		t.tween_property(control, "scale", Vector2.ONE, POP_TIME).set_delay(wait).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
		t.tween_property(control, "modulate:a", 1.0, POP_TIME * 0.6).set_delay(wait), CONNECT_ONE_SHOT)


## A panel swelling open from a little smaller, fading in.
static func open(panel: Control) -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ONE * OPEN_FROM
	panel.modulate.a = 0.0
	var t := panel.create_tween().set_parallel()
	t.tween_property(panel, "scale", Vector2.ONE, OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, OPEN_TIME * 0.6)


## The shared shine for item pictures (each sweeps at its own time).
static func glint() -> ShaderMaterial:
	if _glint == null:
		_glint = ShaderMaterial.new()
		_glint.shader = GLINT
	return _glint


static func _scale_to(control: Control, to: float, time: float, trans: Tween.TransitionType) -> void:
	var t := _fresh_tween(control)
	if t != null:
		t.tween_property(control, "scale", Vector2.ONE * to, time).set_trans(trans)


## A new tween on `control`, the one it had stopped (null when it isn't on screen).
static func _fresh_tween(control: Control) -> Tween:
	if not control.is_inside_tree():
		return null
	var old: Variant = control.get_meta(&"fx_tween", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var t := control.create_tween()
	control.set_meta(&"fx_tween", t)
	return t
