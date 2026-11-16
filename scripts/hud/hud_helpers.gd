class_name HudHelpers
extends Control
## The helpers' flower (our own touch): one button at the bottom left (a straw hat) that opens like a flower into
## the boosts that work the whole farm at once: Fertilize All, Unwither, the farmhands, arborists and gardeners,
## and the vehicles' fuel once there are vehicles. Each petal shows how many are left; a tap uses one (the rules
## and their messages are the systems' own). A tap anywhere else, or the hat again, folds it shut.

const OPEN_TIME := 0.32      # s for a petal to bloom out..
const SHUT_TIME := 0.16      # ..and to fold back in
const STAGGER := 0.035       # s between one petal and the next
const PETAL_SHARE := 1.0     # a petal's size, of the hat's
const SPACING := 1.15        # petals' centres apart along the arc, in petals
const LEAST_REACH := 2.0     # the arc's radius at least, in hats
const ARC := PI / 2.0        # the petals fan from straight up round to the right
const SPIN := -PI / 2.0      # a petal turns in from this far as it opens
const HAT_TURN := 0.35       # the hat tilts this much while open (rad)
const FADED := 0.4           # a petal with none left

var hud: FarmHud
var hat: Button
var is_open := false
var _catch: Control          # the screen behind the open flower: a tap there shuts it
var _petals: Array[Button] = []
var _counts: Array[Label] = []
var _uses: Array[Callable] = []
var _left: Array[Callable] = []   # () -> how many are left (-1: always usable, no count)
var _tween: Tween


func _init(owner: FarmHud) -> void:
	hud = owner


func build(root: Control) -> void:
	var margin := UiTheme.size("hud_margin")
	var side := UiTheme.size("side_width")
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = margin
	offset_bottom = -margin
	offset_top = -margin - side
	offset_right = margin + side
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catch = Control.new()
	_catch.visible = false
	_catch.mouse_filter = Control.MOUSE_FILTER_STOP
	_catch.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.is_pressed():
			shut())
	root.add_child(_catch)
	_catch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(self)
	_add_petal("fertilizer", "HELPER_FERTILIZE_ALL", func() -> int: return Game.fertilize_alls,
		func() -> void: Game.bees.use_fertilize_all())
	_add_petal("unwither", "HELPER_UNWITHER", func() -> int: return Game.unwithers if Game.unwithers > 0 else -1,
		func() -> void: Game.use_unwither())
	_add_petal("farmhand", "FARMHANDS", func() -> int: return Game.farmhands,
		func() -> void: Game.use_helper("animal"))
	_add_petal("arborist", "ARBORISTS", func() -> int: return Game.arborists,
		func() -> void: Game.use_helper("tree"))
	_add_petal("gardener", "GARDENERS", func() -> int: return Game.gardeners,
		func() -> void: Game.use_helper("bloom"))
	_add_petal("fuel", "SHEET_TAB_FUEL", func() -> int: return Game.vehicles.fuel_now(), _open_fuel)
	hat = UiKit.tool_button("helpers", tr("BOOSTS"), side, side, 0.0, null, false)
	hat.pivot_offset = Vector2(side, side) / 2.0
	hat.pressed.connect(func() -> void: shut() if is_open else open())
	add_child(hat)


## Opens the flower: each petal blooms out from the hat along the arc, one after another.
func open() -> void:
	if is_open:
		return
	is_open = true
	_catch.visible = true
	var shown := _shown()
	var side := UiTheme.size("side_width")
	var petal := side * PETAL_SHARE
	var reach := maxf(LEAST_REACH * side, SPACING * petal * maxf(1.0, shown.size() - 1.0) / ARC)
	var centre := Vector2(side, side) / 2.0
	_restart()
	for k in shown.size():
		var b := _petals[shown[k]]
		_show_count(shown[k])
		var a := -PI / 2.0 + (ARC * k / maxf(1.0, shown.size() - 1.0) if shown.size() > 1 else ARC / 2.0)
		var to := centre + Vector2(cos(a), sin(a)) * reach - b.size / 2.0
		b.visible = true
		b.position = centre - b.size / 2.0
		b.scale = Vector2.ZERO
		b.rotation = SPIN
		var at := STAGGER * k
		_tween.tween_property(b, "position", to, OPEN_TIME).set_delay(at).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
		_tween.tween_property(b, "scale", Vector2.ONE, OPEN_TIME).set_delay(at).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
		_tween.tween_property(b, "rotation", 0.0, OPEN_TIME).set_delay(at).set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	_tween.tween_property(hat, "rotation", HAT_TURN, OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Feedback.moment("tap")


## Folds the flower shut: the petals draw back into the hat.
func shut() -> void:
	if not is_open:
		return
	is_open = false
	_catch.visible = false
	var centre := Vector2(UiTheme.size("side_width"), UiTheme.size("side_width")) / 2.0
	_restart()
	for b in _petals:
		if b.visible:
			_tween.tween_property(b, "position", centre - b.size / 2.0, SHUT_TIME).set_trans(Tween.TRANS_CUBIC) \
				.set_ease(Tween.EASE_IN)
			_tween.tween_property(b, "scale", Vector2.ZERO, SHUT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(hat, "rotation", 0.0, SHUT_TIME)
	_tween.chain().tween_callback(func() -> void:
		for b in _petals:
			b.visible = is_open and b.visible)


## Which petals show now (fuel only once there are vehicles to fill).
func _shown() -> Array[int]:
	var out: Array[int] = []
	for k in _petals.size():
		if str(_petals[k].get_meta(&"kind")) != "fuel" or Game.vehicles.fuel_unlocked:
			out.append(k)
	return out


func _add_petal(kind: String, name_key: String, left: Callable, use: Callable) -> void:
	var px := UiTheme.size("side_width") * PETAL_SHARE
	var b := UiKit.icon_button(kind, px)
	b.set_meta(&"kind", kind)
	b.size = Vector2(px, px)
	b.pivot_offset = b.size / 2.0
	b.visible = false
	UiKit.long_press_name(b, tr(name_key))
	var k := _petals.size()
	b.pressed.connect(func() -> void:
		_uses[k].call()
		_show_count(k))
	add_child(b)
	_petals.append(b)
	_counts.append(UiKit.count_badge(b))
	_uses.append(use)
	_left.append(left)


func _show_count(k: int) -> void:
	var n: int = _left[k].call()
	var badge := _counts[k]
	badge.get_parent().visible = n >= 0
	badge.text = UiTheme.short_number(n) if n >= 0 else ""
	_petals[k].modulate.a = FADED if n == 0 else 1.0
	_petals[k].disabled = n == 0


func _open_fuel() -> void:
	shut()
	for o: Dictionary in Game.objects:
		if str(o.get("id", "")) == "barn":
			hud.show_building(int(o["uid"]))
			if hud.sheet != null:
				hud.sheet.show_page("SHEET_TAB_FUEL")
			return


func _restart() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
