class_name NurtureSystem
extends GameSystem
## FarmVille's mystery young (Mystery Seedlings, Babies and Bulbs) and the care of withered Blooms.
## Part of the game state: reached as `Game.nurture`; shared state is on `game`.
##
## A young one is found while harvesting (an Orchard gives a seedling or a Watering Can every time; an animal
## home now and then gives a baby, and Animal Feed). It goes on the farm (or, with no room, into the Barn),
## and the farmer gives it its supply one at a time (a queued job, like any farm work). On the last one it
## grows into what it was all along: a tree of the Orchard's kinds (a rare variety now and then), or an animal
## of the home's kinds. What it becomes is decided when it's found and kept secret until then.
##
## Supplies came from friends in FarmVille; until friends, they're found while harvesting or bought with gems.
## Placed young are objects with two fields of their own: "fed" (supplies given) and "becomes" (an item id).

const SUPPLIES := {
	"watering_can": {"name": "WATERING_CAN", "gem_cost": 2},
	"animal_feed": {"name": "ANIMAL_FEED", "gem_cost": 2},
	"flower_food": {"name": "FLOWER_FOOD", "gem_cost": 2},
}
## FarmVille: every Orchard harvest gave a seedling or a can. The split is our guess (sources don't say).
const SEEDLING_SHARE := 0.5
const RARE_CHANCE := 0.10          # a seedling from a tree with a rare variety grows into the rare one
const MYSTERY_BABY_CHANCE := 0.08  # per animal home harvest (our guess: FarmVille's pens varied)
const HOME_FEED_CHANCE := 0.25     # an animal home's harvest leaves a sack of Animal Feed
const NURSERY_FEED := 2            # the Nursery Barn's harvest: FarmVille's nursery gave feed daily
## Blooms (FarmVille 2012): harvests give Mystery Bulbs, a Full Bloom more often; Flower Food regrows a
## withered Single Bloom. The chances and amounts are ours (sources give none).
const BULB_CHANCE := 0.05          # per Single Bloom harvest (doubled for a Full Bloom)
const GARDEN_BULB_CHANCE := 0.15   # per Bloom Garden harvest
const BLOOM_FOOD_CHANCE := 0.2     # a bloom's harvest leaves Flower Food
const GARDEN_FOOD := 1             # every Bloom Garden harvest
const REGROW_FOOD := 1             # Flower Food to regrow a withered Single Bloom
const SEEDLING := "mystery_seedling"
const BABY := "mystery_baby"
const BULB := "mystery_bulb"

var supplies := {}                 # supply id -> how many


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	supplies = {}


func save_to(data: Dictionary) -> void:
	data["supplies"] = supplies


func load_from(data: Dictionary) -> void:
	supplies = GameSystem.int_map(data.get("supplies", {}))


func has_supply(supply: String) -> int:
	return int(supplies.get(supply, 0))


func add_supply(supply: String, n: int) -> void:
	if not SUPPLIES.has(supply) or n <= 0:
		return
	supplies[supply] = has_supply(supply) + n
	game.inventory_changed.emit()


## Supplies not already promised to queued feeding jobs.
func free_supply(supply: String) -> int:
	var promised := 0
	for job in game.player.queue:
		if job["kind"] == "nurture":
			var o := game.object_by_uid(int(job["uid"]))
			if supply_for(o) == supply:
				promised += 1
	return has_supply(supply) - promised


func supply_name(supply: String) -> String:
	return tr(SUPPLIES[supply]["name"])


## Buys `n` of a supply with gems. Returns whether it was bought.
func buy_supply(supply: String, n: int) -> bool:
	if not SUPPLIES.has(supply) or n <= 0 or not game.spend_gems(int(SUPPLIES[supply]["gem_cost"]) * n):
		return false
	add_supply(supply, n)
	return true


# ---------------------------------------------------------------- the young on the farm

func is_young(o: Dictionary) -> bool:
	return not o.is_empty() and game.kind_of(o) == "young"


func def_of(o: Dictionary) -> YoungDef:
	return game.catalog.defs.get(o["id"]) as YoungDef


func supply_of(o: Dictionary) -> String:
	return def_of(o).supply()


func fed(o: Dictionary) -> int:
	return int(o.get("fed", 0))


func needs(o: Dictionary) -> int:
	return def_of(o).needs()


## How far it has grown, 0 to 1 (for drawing it).
func growth(o: Dictionary) -> float:
	return clampf(float(fed(o)) / needs(o), 0.0, 1.0)


## What can be given to it now: a young one its supply (until grown), a withered Single Bloom Flower Food;
## "" for anything else.
func supply_for(o: Dictionary) -> String:
	if is_young(o):
		return supply_of(o) if fed(o) < needs(o) else ""
	return "flower_food" if not o.is_empty() and game.is_withered(o) else ""


## Can it be given something now?
func can_feed(o: Dictionary) -> bool:
	var supply := supply_for(o)
	return supply != "" and has_supply(supply) > 0


## Gives a young one its supply, or regrows a withered bloom. Returns {"fed", "needs", "grown": the item it
## grew into or "", "regrown": bool}, or {}.
func feed(uid: int) -> Dictionary:
	var o := game.object_by_uid(uid)
	if not can_feed(o):
		return {}
	var supply := supply_for(o)
	supplies[supply] = has_supply(supply) - 1
	if not is_young(o):
		# It starts its cycle again, as if just harvested.
		o["t"] = game.now()
		game.inventory_changed.emit()
		game.objects_updated()
		return {"fed": REGROW_FOOD, "needs": REGROW_FOOD, "grown": "", "regrown": true}
	o["fed"] = fed(o) + 1
	var out := {"fed": fed(o), "needs": needs(o), "grown": "", "regrown": false}
	if fed(o) >= needs(o):
		out["grown"] = _grow(o)
	game.inventory_changed.emit()
	game.objects_updated()
	return out


## Upgrades a Single Bloom on the farm to its Full Bloom with gems (FarmVille's Farm Cash). Returns whether
## it was upgraded.
func upgrade_bloom(uid: int) -> bool:
	var o := game.object_by_uid(uid)
	var d := game.catalog.get_def(str(o.get("id", ""))) if not o.is_empty() else null
	if not d is BloomDef or (d as BloomDef).is_full() or not game.spend_gems((d as BloomDef).upgrade_gems()):
		return false
	o["id"] = (d as BloomDef).full_id()
	game.message.emit(tr("NOW_A_IT_WILL_NEVER_WITHER") % game.item_data(o["id"])["name"])
	game.objects_updated()
	return true


## It becomes what it was all along, where it stands (or the nearest free spot, if that's bigger).
func _grow(o: Dictionary) -> String:
	var into := str(o.get("becomes", ""))
	if not game.items.has(into) or str(game.item_data(into).get("kind", "")) != def_of(o).grows():
		into = first_of(def_of(o).grows())
	var row := int(o["row"])
	var col := int(o["col"])
	game.remove_object(o)
	var grown := {"uid": game.next_uid, "id": into, "row": row, "col": col, "t": game.now()}
	game.next_uid += 1
	if not game.can_place(into, row, col):
		var spot := game.nearest_free_spot(into, row, col)
		if spot.x < 0:
			# Nowhere at all: it waits in the Barn.
			grown.erase("row")
			grown.erase("col")
			game.storage.stored.append(grown)
			game.message.emit(tr("GREW_INTO_A_KEPT_IN_THE_BARN") % [game.item_data(o["id"])["name"],
				game.item_data(into)["name"]])
			game.ribbons.bump("young_raised", 1)
			return into
		grown["row"] = spot.x
		grown["col"] = spot.y
	game.add_object(grown)
	game.message.emit(tr("YOUR_GREW_INTO_A") % [game.item_data(o["id"])["name"], game.item_data(into)["name"]])
	game.ribbons.bump("young_raised", 1)
	return into


## If what it was to become left the catalog: the first of its kind.
func first_of(kind: String) -> String:
	for id in game.item_order:
		var it: Dictionary = game.items[id]
		if str(it.get("kind", "")) == kind and not it.has("rare_of") and not it.has("single_of"):
			return id
	return ""


# ---------------------------------------------------------------- finding them

## An Orchard was harvested: a Mystery Seedling of its trees, or a Watering Can. Returns popup texts.
func from_orchard(orchard: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not game.drops_enabled:
		return out
	var becomes := _pick_tree(orchard.get("inside", {}))
	if becomes != "" and game.rng.randf() < SEEDLING_SHARE and _found(SEEDLING, becomes):
		out.append(game.item_data(SEEDLING)["name"] + "!")
	else:
		add_supply("watering_can", 1)
		out.append(tr("WATERING_CAN_FOUND"))
	return out


## An animal home was harvested: now and then a Mystery Baby of its animals, and sometimes Animal Feed.
func from_home(home: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not game.drops_enabled:
		return out
	var inside: Dictionary = home.get("inside", {})
	if game.item_data(home["id"]).get("special", "") == "nursery":
		add_supply("animal_feed", NURSERY_FEED)
		out.append(tr("ANIMAL_FEED_N") % NURSERY_FEED)
		return out
	var becomes := _pick_animal(inside)
	if becomes == "":
		return out
	if game.rng.randf() < HOME_FEED_CHANCE:
		add_supply("animal_feed", 1)
		out.append(tr("ANIMAL_FEED_N") % 1)
	if game.rng.randf() < MYSTERY_BABY_CHANCE and _found(BABY, becomes):
		out.append(game.item_data(BABY)["name"] + "!")
	return out


## A bloom was harvested on the farm: now and then a Mystery Bulb (twice as often from a Full Bloom), and
## sometimes Flower Food.
func from_bloom(bloom: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not game.drops_enabled:
		return out
	if game.rng.randf() < BLOOM_FOOD_CHANCE:
		add_supply("flower_food", 1)
		out.append(tr("FLOWER_FOOD_N") % 1)
	var d := game.catalog.get_def(bloom["id"]) as BloomDef
	if game.rng.randf() < BULB_CHANCE * d.mastery_points() and _found(BULB, _pick_bloom({})):
		out.append(game.item_data(BULB)["name"] + "!")
	return out


## A Bloom Garden was harvested: Flower Food, and now and then a Mystery Bulb of its flowers.
func from_garden(garden: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not game.drops_enabled:
		return out
	add_supply("flower_food", GARDEN_FOOD)
	out.append(tr("FLOWER_FOOD_N") % GARDEN_FOOD)
	if game.rng.randf() < GARDEN_BULB_CHANCE and _found(BULB, _pick_bloom(garden.get("inside", {}))):
		out.append(game.item_data(BULB)["name"] + "!")
	return out


## Puts a found young on the farm (or in the Barn with no room), secretly set to become `becomes`.
func _found(young_id: String, becomes: String) -> bool:
	var o := {"uid": game.next_uid, "id": young_id, "t": game.now(), "fed": 0, "becomes": becomes}
	game.next_uid += 1
	var spot := game.free_spot_for(young_id)
	if spot.x < 0:
		game.storage.stored.append(o)
		game.message.emit(tr("YOU_FOUND_A_IT_S_IN_THE_BARN") % game.item_data(young_id)["name"])
	else:
		o["row"] = spot.x
		o["col"] = spot.y
		game.add_object(o)
		game.message.emit(tr("YOU_FOUND_A_GIVE_IT") % [game.item_data(young_id)["name"], needs_of(young_id),
			supply_name(str(game.item_data(young_id)["supply"]))])
	game.objects_updated()
	return true


func needs_of(young_id: String) -> int:
	return (game.catalog.defs[young_id] as YoungDef).needs()


## A tree from an Orchard's: likelier the more of it there are; a rare variety now and then.
func _pick_tree(inside: Dictionary) -> String:
	var id := _weighted(inside, func(k: String) -> bool: return str(game.item_data(k).get("kind", "")) == "tree")
	if id == "":
		return ""
	var rare := str(game.item_data(id).get("rare_sapling", ""))
	if rare != "" and game.items.has(rare) and game.rng.randf() < RARE_CHANCE:
		return rare
	return id


## A Single Bloom: one of the flowers in `inside` (likelier the more there are; a Full Bloom stands for its
## Single), or with nothing given, any flower at all: the bulb's a mystery.
func _pick_bloom(inside: Dictionary) -> String:
	var id := _weighted(inside, func(k: String) -> bool: return game.catalog.get_def(k) is BloomDef)
	if id != "":
		return (game.catalog.get_def(id) as BloomDef).single_id()
	var singles: Array[String] = []
	for k in game.item_order:
		var d := game.catalog.get_def(k)
		if d is BloomDef and not (d as BloomDef).is_full():
			singles.append(k)
	return singles[game.rng.randi_range(0, singles.size() - 1)] if not singles.is_empty() else ""


## An animal from a home's: likelier the more of it there are; a baby there stands for what it grows into.
func _pick_animal(inside: Dictionary) -> String:
	var id := _weighted(inside, func(k: String) -> bool: return str(game.item_data(k).get("kind", "")) == "animal")
	if id == "":
		return ""
	var adult := game.specials.adult_of(id)
	return adult if adult != "" and game.items.has(adult) else id


func _weighted(inside: Dictionary, keep: Callable) -> String:
	var total := 0
	for k in inside:
		if game.items.has(k) and keep.call(k):
			total += int(inside[k])
	if total <= 0:
		return ""
	var pick := game.rng.randi_range(1, total)
	for k in inside:
		if game.items.has(k) and keep.call(k):
			pick -= int(inside[k])
			if pick <= 0:
				return k
	return ""
