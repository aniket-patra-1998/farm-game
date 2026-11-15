class_name HudTools
extends RefCounted
## The tool panel at the bottom right, FarmVille's way: eight icon tools on a wooden panel, the one in use lit.
## Select taps things to look at them, collect them and open their panels; Plow; Plant asks which seed (HudSeeds);
## Harvest gathers what is ready and never opens a panel; Fertilise; Move (a decoration being moved can be
## turned from the placing bar); Store puts things in the Barn; Sell sells them (or clears a plot). The boosts
## (Fertilize All, Unwither, helpers) are used from the Barn, and a vehicle by tapping it, as in FarmVille.

## [tool id sent to the farm, icon, label key]
const TOOLS := [["hand", "arrow", "TOOL_SELECT"], ["plow", "hoe", "TOOL_PLOW"], ["plant", "seeds", "TOOL_PLANT"],
	["harvest", "basket", "TOOL_HARVEST"], ["fertilize", "fertilizer", "TOOL_FERTILISE"], ["move", "move", "TOOL_MOVE"],
	["store", "barn", "TOOL_STORE"], ["sell", "tag", "TOOL_SELL"]]
const FIRST := "plow"            # in hand when the game opens (the tutorial starts by plowing)
const LEARN_USES := 5            # a tool's name shows under it until it has been picked this many times
const LEARNED := "learned"       # the player's settings section counting those picks (kept on the phone)

var hud: FarmHud
var panel: PanelContainer
var buttons := {}                # tool id -> Button
var _group := ButtonGroup.new()


func _init(owner: FarmHud) -> void:
	hud = owner


func build(root: Control) -> void:
	var margin := UiTheme.size("hud_margin")
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_box())
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -margin
	panel.offset_bottom = -margin
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiTheme.size("hud_gap") * 0.6))
	panel.add_child(row)
	for t: Array in TOOLS:
		var b := UiKit.tool_button(str(t[1]), tr(str(t[2])), 0.0, 0.0, 0.0, null, not learned(str(t[0])))
		b.toggle_mode = true
		b.button_group = _group
		var id := str(t[0])
		b.pressed.connect(func() -> void: _pick(id))
		buttons[id] = b
		row.add_child(b)
	(buttons[FIRST] as Button).button_pressed = true


## Whether the player knows tool `id` by now (picked LEARN_USES times): then it shows its picture only, and its
## name for a moment when picked (and on a long press). A new player sees every tool's name.
static func learned(id: String) -> bool:
	return int(PlayerSettings.value(LEARNED, id, 0)) >= LEARN_USES


func _pick(id: String) -> void:
	Feedback.moment("tap")
	var uses := int(PlayerSettings.value(LEARNED, id, 0))
	if uses < LEARN_USES:
		PlayerSettings.keep(LEARNED, {id: uses + 1})
	var b: Button = buttons[id]
	if learned(id):
		(b.get_meta("label") as Label).visible = false
		UiKit.name_bubble(b, (b.get_meta("label") as Label).text)
	if id == "plant":
		hud.show_seeds()     # which seed first; the tool goes in hand once one is chosen
		return
	hud.tool_selected.emit(id, "")


## Lights the tool in hand (when it changes without a tap here: a seed chosen, a vehicle tapped).
func show_tool(id: String) -> void:
	if buttons.has(id):
		(buttons[id] as Button).button_pressed = true
	else:
		for b: Button in buttons.values():
			b.button_pressed = false
