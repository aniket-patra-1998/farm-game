class_name HudBubble
extends PanelContainer
## The small bubble over a tapped thing (FarmVille's way: what it is and how it is doing, right above it, not a
## panel): its name, one line (ready in 14 h, withered, needs feed), and, for a thing with more to it (a home,
## a crafting building, an animal to feed, a young one), an Open button for its panel. It follows the thing as
## the view moves, pops in, and goes after a few seconds, when another thing is tapped, or when a panel opens.

const SHOW_FOR := 3.0         # seconds a bubble stays..
const SHOW_FOR_ACTION := 5.0  # ..and with a button to press
const GAP := 6.0              # px between the bubble's point and the thing
const WRAP_AFTER := 26        # characters past which a bubble's words wrap (at ui_theme's `bubble_width`)

var hud: FarmHud
var to_screen: Callable       # grid space -> screen, from the farm (FarmMain)
var _at := Vector2.ZERO
var _uid := -1
var _left := 0.0
var _title: Label
var _line: Label
var _open: Button
var _act: Button          # the one thing to do right here (Feed), done from the bubble itself


func _init(owner: FarmHud) -> void:
	hud = owner
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiKit.panel_box())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)
	_title = _label(UiTheme.font(19), UiTheme.color("ink"))
	col.add_child(_title)
	_line = _label(UiTheme.font(15), UiTheme.color("tool_label"))
	col.add_child(_line)
	_open = hud._panel_button(tr("BUBBLE_OPEN"))
	_open.custom_minimum_size = Vector2(UiTheme.size("panel_button_width") * 0.6,
		UiTheme.size("panel_button_height") * 0.7)
	_open.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_open.pressed.connect(func() -> void:
		var uid := _uid
		close()
		hud.show_building(uid))
	_act = hud._panel_button("")
	_act.custom_minimum_size = _open.custom_minimum_size
	_act.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_act.pressed.connect(func() -> void:
		var o := Game.object_by_uid(_uid)
		var deed := action_of(o)
		close()
		if not deed.is_empty():
			(deed["do"] as Callable).call())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	buttons.add_child(_act)
	buttons.add_child(_open)
	col.add_child(buttons)
	visible = false


## Shows `title` and `line` over grid point `at`; `uid` the thing (-1: a plot), offering its panel when it has one.
func show_at(at: Vector2, title: String, line: String, uid: int) -> void:
	_at = at
	_uid = uid
	_title.text = title
	_line.text = line
	# A long word (a reason something can't be done) wraps at a set width; a name stays on one line.
	var long := title.length() > WRAP_AFTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long else TextServer.AUTOWRAP_OFF
	_title.custom_minimum_size.x = UiTheme.size("bubble_width") if long else 0.0
	_line.visible = line != ""
	var o := Game.object_by_uid(uid) if uid >= 0 else {}
	_open.visible = has_panel(o)
	var deed := action_of(o)
	_act.visible = not deed.is_empty()
	if _act.visible:
		_act.text = str(deed["words"])
	_left = SHOW_FOR_ACTION if _open.visible or _act.visible else SHOW_FOR
	visible = true
	reset_size()
	_follow()
	pivot_offset = Vector2(size.x / 2.0, size.y)
	scale = Vector2.ONE * UiFx.POP_FROM
	modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2.ONE, UiFx.POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, UiFx.POP_TIME * 0.5)


func close() -> void:
	visible = false
	_uid = -1


## Whether a placed thing has a panel worth opening from its bubble: a building (its yard, its recipes, its
## level), a young one or a bloom (what it needs, buying more), a vehicle (its fuel). An animal or a tree has
## nothing more than its bubble says; feeding is the bubble's own button (`action_of`).
static func has_panel(o: Dictionary) -> bool:
	if o.is_empty() or Game.kind_of(o) in ["decor", "animal", "tree"]:
		return false
	return (Game.is_building_item(str(o["id"])) or Game.nurture.is_young(o) or Game.kind_of(o) in ["bloom", "vehicle"]
		or Game.nurture.supply_for(o) != "")


## The one thing to do for `o` right from its bubble, as {"words", "do"}, or {}: feed a hungry animal or home
## with the best feed in the Barn, for more coins (the first effect), queued for the farmer as any farm work.
static func action_of(o: Dictionary) -> Dictionary:
	if o.is_empty() or not Game.feeds.is_feedable(o) or not Game.feeds.effect_of(o).is_empty():
		return {}
	var best := Game.feeds.best_feed_for(o)
	if best.is_empty():
		return {}
	var uid := int(o["uid"])
	var effect := str(Game.feeds.effects()[0])
	return {"words": TranslationServer.translate("BUBBLE_FEED"), "do": func() -> void:
		Game.player.enqueue({"kind": "feed", "uid": uid, "feed": best["feed"], "effect": effect,
			"rich": best["rich"]})}


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0 or Game.modal_open:
		close()
		return
	_follow()


func _follow() -> void:
	if not to_screen.is_valid():
		return
	var p: Vector2 = to_screen.call(_at)
	global_position = p - Vector2(size.x / 2.0, size.y + GAP)   # (screen space: the HUD root may sit inside safe insets)


func _label(px: int, colour: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", colour)
	return l
