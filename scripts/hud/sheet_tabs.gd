class_name SheetTabs
extends HBoxContainer
## A sheet's tabs (BuildingSheet): the kit's pill tabs (`UiKit.tab_button`) in a centred row, the one in
## use lit, switching what the sheet shows below. Set with words keys (`set_tabs`); a tap says which (`picked`).
## One tab, or none: no row at all.

signal picked(index: int)

var current := 0
var _keys: Array = []


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", int(UiTheme.size("hud_gap") * 0.5))


## The tabs, by their words' keys; the first in use. The row is made again only when the keys change.
func set_tabs(keys: Array) -> void:
	visible = keys.size() > 1
	if keys == _keys:
		return
	_keys = keys.duplicate()
	current = 0
	_build()


## Puts tab `i` in use (`quiet`: without saying so, as the sheet itself chose it).
func pick(i: int, quiet := false) -> void:
	if i == current or i < 0 or i >= _keys.size():
		return
	current = i
	_build()
	if not quiet:
		picked.emit(i)


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for k in _keys.size():
		var b := UiKit.tab_button(tr(str(_keys[k])), k == current)
		var which := k
		b.pressed.connect(func() -> void: pick(which))
		add_child(b)
