class_name HudSeeds
extends RefCounted
## The seed list the Plant tool opens (FarmVille's Market seeds tab): every crop with its price, time and
## pollinated seeds; picking one puts it in hand to plant on plowed plots. Locked crops say their level.

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


func build_seeds(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(tr("PICK_A_SEED_THEN_TAP_PLOWED_PLOTS"), 20, BookPanel.CREAM))
	var grid := UiKit.card_grid(hud.get_viewport().get_visible_rect().size.x)
	for id: String in Game.crop_order:
		if not Release.has(id):
			continue
		grid.add_child(seed_card(id))
	content.add_child(grid)


## One crop's card, as FarmVille's seed shelf showed it: its picture, its mastery stars, its name, how long it
## grows and what it sells for, and its seed price (free while pollinated seeds last); tapping picks it.
func seed_card(id: String) -> Button:
	var crop: Dictionary = Game.crops[id]
	var locked := not Game.is_unlocked(id)
	var pol := Game.bees.pollinated_seeds(id)
	var badge: Control
	if locked:
		badge = UiKit.price_badge("lock", tr("UNLOCKS_LEVEL") % int(crop["unlock_level"]))
	elif pol > 0:
		badge = UiKit.price_badge("", tr("FREE_SEEDS_LEFT") % pol)
	else:
		badge = UiKit.price_badge("coin", str(int(crop["seed_cost"])), Game.coins < int(crop["seed_cost"]))
	var about := tr("SEED_CARD") % [FarmGrid.format_duration(int(crop["grow_seconds"])), int(crop["sell_price"])]
	var card := UiKit.item_card(ItemIcons.of(id), str(crop["name"]), about, badge, locked, MasteryStars.of(id))
	if not locked:
		card.pressed.connect(func() -> void: hud.choose_seed(id))
	return card
