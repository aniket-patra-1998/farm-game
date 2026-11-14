class_name HudSeeds
extends RefCounted
## The seed list the Plant tool opens (FarmVille's Market seeds tab): every crop with its price, time and
## pollinated seeds; picking one puts it in hand to plant on plowed plots. Locked crops say their level.

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


func build_seeds(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(tr("PICK_A_SEED_THEN_TAP_PLOWED_PLOTS"), 20, BookPanel.CREAM))
	for id: String in Game.crop_order:
		content.add_child(seed_row(id))


## One crop's card: name, what it costs and pays, how long it grows; its button picks it.
func seed_row(id: String) -> Control:
	var crop: Dictionary = Game.crops[id]
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(BookPanel.text(str(crop["name"]), 22))
	info.add_child(BookPanel.text(tr("SEED_DETAIL") % [FarmGrid.format_duration(int(crop["grow_seconds"])),
		int(crop["sell_price"]), int(crop["xp"])], 17))
	var pol := Game.bees.pollinated_seeds(id)
	if pol > 0:
		info.add_child(BookPanel.text(tr("POLLINATED_SEEDS_FREE") % pol, 16, BookPanel.CREAM))
	inner.add_child(info)
	var pick := Button.new()
	pick.custom_minimum_size = Vector2(150, 52)
	pick.focus_mode = Control.FOCUS_NONE
	if not Game.is_unlocked(id):
		pick.text = tr("UNLOCKS_LEVEL") % int(crop["unlock_level"])
		pick.disabled = true
	else:
		pick.text = tr("FREE_SEED") if pol > 0 else tr("SEED_COINS") % int(crop["seed_cost"])
		pick.pressed.connect(func() -> void: hud.choose_seed(id))
	inner.add_child(pick)
	return BookPanel.card_frame(inner)
