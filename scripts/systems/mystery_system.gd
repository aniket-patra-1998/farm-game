class_name MysterySystem
extends GameSystem
## Mystery Eggs and the Mystery Box: weighted prize draws.
## Part of the game state: reached as `Game.mystery`; shared state is on `game`.

const MYSTERY_BOX_GEM_COST := 12

var mystery_eggs := {}             # egg colour -> count
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
	if game.rng.randf() >= chance:
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
	var text := give_prize(_weighted_prize(egg_data["colours"][colour]["prizes"]))
	game.ribbons.bump("eggs_opened", 1)
	game.message.emit("%s: %s" % [egg_data["colours"][colour]["name"], text])
	game.inventory_changed.emit()
	game.queue_save()
	return text


func give_prize(prize: Array) -> String:
	var kind: String = prize[0]
	match kind:
		"coins":
			game.add_coins(int(prize[1]))
			return "%d coins" % int(prize[1])
		"xp":
			game.add_xp(int(prize[1]))
			return "%d XP" % int(prize[1])
		"gems":
			game.add_gems(int(prize[1]))
			return "%d gems" % int(prize[1])
		"chicken", "item":
			if game.place_somewhere(prize[1]):
				return "a %s" % game.item_data(prize[1])["name"]
			game.add_coins(200)
			return "200 coins (no room for a %s)" % game.item_data(prize[1])["name"]
		"materials":
			var got: Array[String] = []
			for k in int(prize[1]):
				var m := game.daily.pick_part()
				game.daily.add_part(m, 1)
				got.append(GameState.part_names[m])
			return ", ".join(PackedStringArray(got))
		"unwither":
			game.add_unwithers(int(prize[1]))
			return "%d Unwither" % int(prize[1])
		"farmhand":
			game.farmhands += int(prize[1])
			return "%d Farmhand" % int(prize[1])
		"arborist":
			game.arborists += int(prize[1])
			return "%d Arborist" % int(prize[1])
		"fuel":
			game.vehicles.add_fuel(int(prize[1]))
			return "%d fuel" % int(prize[1])
		"fertilize_all":
			game.fertilize_alls += int(prize[1])
			return "%d Fertilize All" % int(prize[1])
	return ""


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
	if box_data.is_empty() or not game.spend_gems(int(box_data.get("gem_cost", MYSTERY_BOX_GEM_COST))):
		return ""
	return _open_box()


func _open_box() -> String:
	var text := give_prize(_weighted_prize(box_data["prizes"]))
	game.ribbons.bump("boxes_opened", 1)
	game.message.emit("Mystery Box: %s" % text)
	game.inventory_changed.emit()
	game.objects_updated()
	game.queue_save()
	return text
