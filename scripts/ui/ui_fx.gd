class_name UiFx
extends RefCounted
## The interface's life (our own touch, the plush feel of modern farm games): things press in and spring back,
## cards pop in one after another as a panel opens, and every surface (a panel, a sheet, a card, a bubble) opens
## and closes in one motion (`open`, `close`; docs/ART_POLISH.md "Panel motion"): it fades in, grows from a little
## smaller and rises a few px into place, eased out; it closes the same way back, quicker, eased in, and only
## then is hidden. Either way it can be turned back from where it is; a tab's page fades in (`crossfade`).
## Only modulate, scale and position move (cheap on a phone); nothing bounces. Every motion is here, so the whole
## interface moves alike.

const PRESS_SCALE := 0.92         # a pressed thing sinks to this size..
const SPRING_SCALE := 1.06        # ..and overshoots to this on letting go
const PRESS_TIME := 0.07
const SPRING_TIME := 0.28
const POP_FROM := 0.82            # a card pops in from this size
const POP_TIME := 0.32
const POP_STAGGER := 0.035        # each next card starts this much later..
const POP_MOST := 0.5             # ..but none later than this
const OPEN_FROM := 0.94           # a surface opens from this size..
const OPEN_RISE := 8.0            # ..this many px low (rising into place)..
const OPEN_TIME := 0.22           # ..fading in, in this, eased out (it arrives softly)
const CLOSE_TIME := 0.16          # it closes the same way back in this, eased in (quad: it leaves at once), then hides
const TAB_TIME := 0.12            # a tab's page fades in over the last one in this
const MOST_STEP := 1.0 / 30.0     # a motion moves at most this much time a frame (a long frame never skips it)
const PULSE_SCALE := 1.12         # a counter swells to this as a reward lands..
const PULSE_TIME := 0.08          # ..this quickly..
const PULSE_SETTLE := 0.22        # ..and settles back in this
const SHINE_LIGHT := 1.6          # a button that has just appeared glows this bright..
const SHINE_TIME := 0.9           # ..and fades back to its colour in this, swelling once
const SETTLE_TIME := 0.32         # a squashed or swelled thing on the farm settles back to its size in this

static var pop_next := false      # the panel being opened pops its cards in (not on every refresh)..
static var popped := 0            # ..each a little after the last (set back to 0 as a panel opens)
static var _moving: Array[Motion] = []   # the opens, closes and fades under way (each steps every frame)


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
	control.tree_entered.connect(func() -> void: pop_now(control, order), CONNECT_ONE_SHOT)


## `control` (in the tree) pops in now, `order` cards after the first (a CardList's cards as a panel opens).
static func pop_now(control: Control, order: int) -> void:
	control.pivot_offset = control.custom_minimum_size / 2.0
	control.scale = Vector2.ONE * POP_FROM
	control.modulate.a = 0.0
	var t := control.create_tween().set_parallel()
	var wait := minf(order * POP_STAGGER, POP_MOST)
	t.tween_property(control, "scale", Vector2.ONE, POP_TIME).set_delay(wait).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(control, "modulate:a", 1.0, POP_TIME * 0.6).set_delay(wait)


## Opens `host` (shows it) in the one motion: `moving` (the host itself when not given) fades in, grows and rises
## into place; `backdrop` (a dim behind it) fades in with it. Opening one that is closing turns it back from where
## it is; opening one already open does nothing (it never stacks), unless `afresh` (a bubble shown again for
## another thing comes in again).
static func open(host: Control, moving: Control = null, backdrop: CanvasItem = null, afresh := false) -> void:
	open_with(host, panel_look(moving if moving != null else host, backdrop), afresh)


## Opens `host` with its own `look` (look(share): `share` 0 hidden .. 1 at rest), on the same timing and ease:
## a sheet that slides up from the bottom, words that only fade.
static func open_with(host: Control, look: Callable, afresh := false) -> void:
	var m := _motion(host)
	if is_open(host) and not afresh:
		return
	if not host.visible or afresh:
		m.share = 0.0
	m.look = look
	if m.closing:   # (turned back on its way out: it takes taps again)
		_hold_input(host, false)
	m.closing = false
	m.then = Callable()
	_stop(m)
	host.visible = true
	look.call(m.share)   # (at once: no frame of it at rest before the motion starts)
	if not host.is_inside_tree():
		m.share = 1.0
		look.call(1.0)
		return
	_run(host, m, 1.0, OPEN_TIME * (1.0 - m.share), Tween.EASE_OUT)


## Closes `host` the way it opened, back from where it is, and hides it at the end (then calls `then`). Taps go
## through a closing surface (it no longer holds them). Closing one hidden calls `then` at once; one already
## closing keeps its motion.
static func close(host: Control, then := Callable()) -> void:
	var m := _motion(host)
	if not host.visible:
		m.closing = false
		if then.is_valid():
			then.call()
		return
	if m.closing:
		if then.is_valid():
			m.then = then
		return
	if not m.look.is_valid():   # (shown before any open: it closes as a panel)
		m.look = panel_look(host, null)
		m.share = 1.0
	m.closing = true
	m.then = then
	_stop(m)
	_hold_input(host, true)
	if not host.is_inside_tree():
		_closed(host, m)
		return
	_run(host, m, 0.0, CLOSE_TIME * m.share, Tween.EASE_IN, Tween.TRANS_QUAD)


## Whether `host` is open (shown and not on its way out): what "is the panel up?" asks.
static func is_open(host: Control) -> bool:
	return host.visible and not is_closing(host)


static func is_closing(host: Control) -> bool:
	return host.has_meta(&"fx_motion") and (host.get_meta(&"fx_motion") as Motion).closing


## How far open `host` is: 0 hidden .. 1 at rest.
static func share_of(host: Control) -> float:
	if not host.visible:
		return 0.0
	return (host.get_meta(&"fx_motion") as Motion).share if host.has_meta(&"fx_motion") else 1.0


## The panel's look: `moving` fades, grows from OPEN_FROM and rises OPEN_RISE px into place (it grows about a
## point below its middle, so growing lifts it), `backdrop` fades with it.
static func panel_look(moving: Control, backdrop: CanvasItem) -> Callable:
	return func(share: float) -> void:
		moving.pivot_offset = moving.size / 2.0 + Vector2(0.0, OPEN_RISE / (1.0 - OPEN_FROM))
		moving.scale = Vector2.ONE * lerpf(OPEN_FROM, 1.0, share)
		moving.modulate.a = share
		if backdrop != null:
			backdrop.modulate.a = share


## A look that only fades `node` (words over the farm, a full-screen card whose dim must cover the screen).
static func fade_look(node: CanvasItem) -> Callable:
	return func(share: float) -> void: node.modulate.a = share


## `page` fades in over what was there (a tab picked, a card's next content): the paper stays, the page changes.
static func crossfade(page: CanvasItem) -> void:
	if page == null:
		return
	if not page.has_meta(&"fx_fade"):
		var made := Motion.new()
		made.look = fade_look(page)
		page.set_meta(&"fx_fade", made)
	var m: Motion = page.get_meta(&"fx_fade")
	_stop(m)
	m.share = 0.0
	m.look.call(0.0)
	if not page.is_inside_tree():
		m.share = 1.0
		m.look.call(1.0)
		return
	_run(page, m, 1.0, TAB_TIME, Tween.EASE_OUT)


## `control` swells a little and settles back (a counter as a reward lands on it); a pulse already running is
## replaced, so coins landing one after another never fight over its size.
static func pulse(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var t := _fresh_tween(control)
	if t == null:
		return
	t.tween_property(control, "scale", Vector2.ONE * PULSE_SCALE, PULSE_TIME).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	settle(t, control, "scale", Vector2.ONE, PULSE_SETTLE)


## A short shine on a button that has just appeared (HudReveal): it glows, swells once and settles.
static func shine(control: Control) -> void:
	control.modulate = Color(SHINE_LIGHT, SHINE_LIGHT, SHINE_LIGHT)
	var t := control.create_tween()
	t.tween_property(control, "modulate", Color.WHITE, SHINE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse(control)


## The one way anything springs back to its size or place, in the interface and on the farm: a single soft
## overshoot and rest, never an elastic wobble (things have weight; nothing is rubber). Added to `tween` in turn.
static func settle(tween: Tween, target: Object, property: NodePath, to: Variant,
		time: float = SETTLE_TIME) -> PropertyTweener:
	return tween.tween_property(target, property, to, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _scale_to(control: Control, to: float, time: float, trans: Tween.TransitionType) -> void:
	var t := _fresh_tween(control)
	if t != null:
		t.tween_property(control, "scale", Vector2.ONE * to, time).set_trans(trans)


## A new tween on `control`, the one it had stopped (null when it isn't on screen).
static func _fresh_tween(control: Control) -> Tween:
	if not control.is_inside_tree():
		return null
	var old: Variant = control.get_meta(&"fx_tween") if control.has_meta(&"fx_tween") else null   # (a null default errors)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var t := control.create_tween()
	control.set_meta(&"fx_tween", t)
	return t


static func _motion(host: Control) -> Motion:
	if not host.has_meta(&"fx_motion"):
		var m := Motion.new()
		m.share = 1.0 if host.visible else 0.0
		host.set_meta(&"fx_motion", m)
	return host.get_meta(&"fx_motion")


static func _step(share: float, m: Motion) -> void:
	m.share = share
	m.look.call(share)


## Moves `m` from where it is to `to` in `time`, eased by `easing` on curve `trans`, a step each frame. Its own
## clock, not a Tween's: a frame's time counts at most MOST_STEP, so a panel built in the frame it opens (a long
## frame) still opens in the whole motion rather than at rest the next frame.
static func _run(node: CanvasItem, m: Motion, to: float, time: float, easing: Tween.EaseType,
		trans := Tween.TRANS_CUBIC) -> void:
	m.from = m.share
	m.to = to
	m.time = time
	m.easing = easing
	m.trans = trans
	m.elapsed = 0.0
	m.node = node
	if not _moving.has(m):
		_moving.append(m)
	if not node.get_tree().process_frame.is_connected(_tick_all):
		node.get_tree().process_frame.connect(_tick_all)


## Every motion under way takes its step (one listener for all of them, each frame).
static func _tick_all() -> void:
	for m: Motion in _moving.duplicate():
		if _moving.has(m):   # (a step can stop another: a panel closing as a sheet opens)
			_tick(m)


static func _tick(m: Motion) -> void:
	if not is_instance_valid(m.node) or not m.node.is_inside_tree():
		_stop(m)
		return
	m.elapsed += minf(m.node.get_process_delta_time(), MOST_STEP)
	var k := clampf(m.elapsed / m.time, 0.0, 1.0) if m.time > 0.0 else 1.0
	_step(lerpf(m.from, m.to, Tween.interpolate_value(0.0, 1.0, k, 1.0, m.trans, m.easing)), m)
	if k >= 1.0:
		_stop(m)
		if m.closing:
			_closed(m.node as Control, m)


static func _stop(m: Motion) -> void:
	_moving.erase(m)


static func _closed(host: Control, m: Motion) -> void:
	m.closing = false
	m.share = 0.0
	host.visible = false
	_hold_input(host, false)
	m.look.call(1.0)   # (hidden at rest: whatever shows it next starts from its true size)
	var then := m.then
	m.then = Callable()
	if then.is_valid():
		then.call()


## While `host` closes, nothing in it takes a tap (each control's filter is kept and given back after).
static func _hold_input(node: Node, hold: bool) -> void:
	var c := node as Control
	if c != null:
		if hold and not c.has_meta(&"fx_filter"):
			c.set_meta(&"fx_filter", c.mouse_filter)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif not hold and c.has_meta(&"fx_filter"):
			c.mouse_filter = c.get_meta(&"fx_filter") as Control.MouseFilter
			c.remove_meta(&"fx_filter")
	for k in node.get_children():
		_hold_input(k, hold)


## One surface's open or close: how far open it is (0 hidden .. 1 at rest), how it shows that, and the motion under way.
class Motion:
	extends RefCounted
	var share := 0.0
	var closing := false
	var look: Callable      # look(share): puts the surface `share` of the way open
	var then: Callable      # called once a close has hidden it
	var node: CanvasItem    # what moves (its frames are counted)
	var from := 0.0         # the motion under way: from this share..
	var to := 1.0           # ..to this..
	var time := 0.0         # ..in this many seconds..
	var elapsed := 0.0      # ..this far in..
	var easing := Tween.EASE_OUT
	var trans := Tween.TRANS_CUBIC
