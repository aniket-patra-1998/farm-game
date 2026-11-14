extends Control
## Every interface icon (UiIcon) on one sheet at three sizes, on the cards' cream and the panels' brown, to look the
## set over after a change. Writes ci_shots/icons.png (or --out=<file>). Needs a renderer:
##   xvfb-run godot --rendering-method gl_compatibility --path . res://tools/icon_sheet.tscn -- --out=/tmp/icons.png

const SIZES := [96.0, 48.0, 28.0]


func _ready() -> void:
	var out := "res://ci_shots/icons.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var back := ColorRect.new()
	back.color = UiTheme.color("card_face")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var rows := VBoxContainer.new()
	rows.position = Vector2(16, 16)
	add_child(rows)
	for px: float in SIZES:
		var row := HFlowContainer.new()
		row.custom_minimum_size.x = get_viewport_rect().size.x - 32.0
		for kind: String in UiIcon.KINDS:
			row.add_child(UiIcon.make(kind, px))
		for k in 4:
			row.add_child(UiIcon.make("ribbon", px, UiTheme.color("ribbon_tier_%d" % k)))
		rows.add_child(row)
	var things := HFlowContainer.new()   # every collection item's shape, in a sample colour
	things.custom_minimum_size.x = get_viewport_rect().size.x - 32.0
	for shape: String in ThingIcon.SHAPES:
		things.add_child(ThingIcon.of([shape, "#c89a5a", "#c0392b"], 60.0))
	rows.add_child(things)
	for k in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := out if out.begins_with("/") else ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
