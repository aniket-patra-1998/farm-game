extends Node
## Makes every item's picture (and the interface's rendered icons) at their largest size and keeps them in the
## game (res://baked/icons, ItemIcons.SHIPPED), so a phone never renders one: CI runs it before the phone build.
## Needs a renderer:
##   xvfb-run godot --rendering-method gl_compatibility --path . res://tools/bake_icons.tscn

const MOST_FRAMES := 20000


func _ready() -> void:
	ItemIcons._side = ItemIcons.SIDE_MOST
	ItemIcons.shipping = true
	ItemIcons.start(self)
	var ids: Array[String] = []
	for id: String in Game.item_order:
		ids.append(id)
	for id: String in Game.crops:
		ids.append(id)
	for id: String in GameState.part_ids:
		ids.append(id)
	for kind in UiModels.KINDS:
		ids.append(ItemIcons.UI + kind)
	for id in ids:
		ItemIcons.of(id)
	var frames := 0
	while frames < MOST_FRAMES and not ids.all(func(i: String) -> bool: return ItemIcons.is_made(i)):
		frames += 1
		await get_tree().process_frame
	print("ICONS baked=%d frames=%d files=%d" % [ids.size(), frames, DirAccess.get_files_at(ItemIcons.SHIPPED).size()])
	get_tree().quit()
