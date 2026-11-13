extends Node
## A look at the interface kit: every part on a meadow, written to ci_shots/ui_sheet.png. Needs a renderer:
##   xvfb-run godot --rendering-method gl_compatibility --path . res://tools/ui_sheet.tscn


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color("#5fa83a")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var top := HBoxContainer.new()
	top.position = Vector2(20, 20)
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	var coins := UiKit.meter("coin", true)
	coins.custom_minimum_size.x = 230
	(coins.get_meta("value_label") as Label).text = "56,052"
	top.add_child(coins)
	var cash := UiKit.meter("gem", true)
	cash.custom_minimum_size.x = 150
	(cash.get_meta("value_label") as Label).text = "63"
	top.add_child(cash)
	var xp := UiKit.xp_bar()
	xp.ratio = 0.62
	xp.level = 24
	xp.text = "18267 / 29000"
	top.add_child(xp)
	top.add_child(UiKit.plaque("Wells's Farm"))
	var row := HBoxContainer.new()
	row.position = Vector2(20, 120)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for kind in UiIcon.KINDS:
		row.add_child(UiKit.icon_button(kind))
	var mute := UiKit.icon_button("speaker")
	(mute.get_meta("icon") as UiIcon).struck = true
	row.add_child(mute)
	for k in 4:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ci_shots"))
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://ci_shots/ui_sheet.png"))
	get_tree().quit()
