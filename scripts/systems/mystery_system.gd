class_name MysterySystem
extends GameSystem
## Mystery Eggs and the Mystery Box: weighted prize draws.
## Part of the game state: reached as `Game.mystery`; shared state is on `game`.


# A prize is uncommon, rare, legendary when its share of the weights is under these.
const RARE_SHARES: Array[float] = [0.3, 0.12, 0.04]

var mystery_eggs := {}             # egg colour -> count
var last_rarity := "common"        # how rare the prize last opened was (the reveal reads it)
var egg_data := {}                 # data/mystery_eggs.json
var box_data := {}                 # data/mystery_box.json


func _init(owner: GameState) -> void:
	super(owner)


func load_data() -> void:
	egg_data = game.read_json("res://data/mystery_eggs.json")
	box_data = game.read_json("res://data/mystery_box.json")


func reset() -> void:
	mystery_eggs = {}


func save_to(data: Dictionary) -> void:
	data["mystery_eggs"] = mystery_eggs


func load_from(data: Dictionary) -> void:
	mystery_eggs = int_map(data.get("mystery_eggs", {}))


## Mystery Egg chance grows with the chickens inside; colour follows the breeds there.
func roll_mystery_egg(coop: Dictionary) -> String:
	if not game.drops_enabled or egg_data.is_empty():
		return ""
	var chickens := game.inside_total(coop)
	var chance := minf(
		float(egg_data.get("max_chance", 0.4)),
		chickens * float(egg_data.get("chance_per_chicken", 0.005))
	)
	if not game.rolls.roll("mystery_egg", chance):
		return ""
	var pick := game.rng.randi_range(1, chickens)
	var inside: Dictionary = coop["inside"]
	for id in inside:
		pick -= int(inside[id])
		if pick <= 0:
			return game.item_data(id).get("breed", "white")
	return "white"


## Opens one Mystery Egg of a colour. Returns the prize text, or "" if none held.
func open_mystery_egg(colour: String) -> String:
	if int(mystery_eggs.get(colour, 0)) <= 0:
		return ""
	mystery_eggs[colour] = int(mystery_eggs[colour]) - 1
	var won := _weighted_prize(egg_data["colours"][colour]["prizes"])
	last_rarity = rarity_of_prize(egg_data["colours"][colour]["prizes"], won)
	var text := give_prize(won)
	game.record("open_egg", colour)
	game.message.emit("%s: %s" % [egg_data["colours"][colour]["name"], text])
	game.inventory_changed.emit()
	game.queue_save()
	return text


func give_prize(prize: Array) -> String:
	var kind: String = prize[0]
	match kind:
		"coins":
			game.add_coins(int(prize[1]))
		"xp":
			game.add_xp(int(prize[1]))
		"gems":
			game.add_gems(int(prize[1]))
		"chicken", "item":
			# (a prize to place arrives as every new thing does: the Barn, or the inbox when it is full)
			var went := game.storage.welcome(str(prize[1]))
			return tr("PRIZE_IN_BARN" if went == BarnStorage.BARN else "PRIZE_IN_INBOX") % game.item_data(prize[1])["name"]
		"materials":
			var got: Array[String] = []
			for k in int(prize[1]):
				var m := game.daily.pick_part()
				game.daily.add_part(m, 1)
				got.append(GameState.part_names[m])
			return ", ".join(PackedStringArray(got))
		"unwither":
			game.add_unwithers(int(prize[1]))
		"farmhand":
			game.farmhands += int(prize[1])
		"arborist":
			game.arborists += int(prize[1])
		"fuel":
			game.vehicles.add_fuel(int(prize[1]))
		"fertilize_all":
			game.fertilize_alls += int(prize[1])
		_:
			return ""
	return prize_words(prize)


## A prize ([kind, amount or item]) in words ("3 gems", "a Cow"), for the prize itself and the reward lines.
static func prize_words(prize: Array) -> String:
	var n := int(prize[1]) if str(prize[0]) not in ["chicken", "item"] else 1
	match str(prize[0]):
		"chicken", "item":
			return TranslationServer.translate("A_THING") % str(Game.item_data(str(prize[1])).get("name", prize[1]))
		"coins":
			return TranslationServer.translate("SOCIAL_COINS") % n
		"xp":
			return TranslationServer.translate("XP_3") % n
		"gems":
			return TranslationServer.translate("GEMS_N") % n
		"unwither":
			return TranslationServer.translate("UNWITHER") % n
		"farmhand":
			return TranslationServer.translate("FARMHAND_2") % n
		"arborist":
			return TranslationServer.translate("ARBORIST_2") % n
		"fuel":
			return TranslationServer.translate("SOCIAL_FUEL") % n
		"fertilize_all":
			return TranslationServer.translate("FERTILIZE_ALL") % n
		"materials":
			return TranslationServer.translate("MATERIALS_N") % n
	return ""


## How rare a prize is among the prizes it was drawn from, by its share of their weights: the reveal's colours.
static func rarity_of_prize(prizes: Array, prize: Array) -> String:
	var total := 0
	for p: Array in prizes:
		total += int(p[2])
	var share := float(prize[2]) / maxi(total, 1)
	if share < RARE_SHARES[2]:
		return "legendary"
	if share < RARE_SHARES[1]:
		return "rare"
	return "uncommon" if share < RARE_SHARES[0] else "common"


## Picks one prize from a weighted list: [kind, amount or item, weight].
func _weighted_prize(prizes: Array) -> Array:
	var total := 0
	for p in prizes:
		total += int(p[2])
	var roll := game.rng.randi_range(1, total)
	for p in prizes:
		roll -= int(p[2])
		if roll <= 0:
			return p
	return prizes[-1]


## FarmVille's Mystery Box: bought with premium currency, opens into one random prize.
## Some things (the Donkey) come only from here.
func buy_mystery_box() -> String:
	if box_data.is_empty() or not game.spend_gems(
		int(box_data.get("gem_cost", Balance.i("mystery.mystery_box_gem_cost")))
	):
		return ""
	return _open_box()


func _open_box() -> String:
	var won := _weighted_prize(box_data["prizes"])
	last_rarity = rarity_of_prize(box_data["prizes"], won)
	var text := give_prize(won)
	game.record("open_box", "mystery_box")
	game.message.emit(tr("MYSTERY_BOX_2") % text)
	game.inventory_changed.emit()
	game.objects_updated()
	game.queue_save()
	return text
