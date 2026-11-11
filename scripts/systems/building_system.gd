class_name BuildingSystem
extends GameSystem
## The rules a building answers to, in one place, each answered with a Verdict: yes, or no and why.
##   can_buy      its level, its price, and how many one farm may have (FarmVille: 5 Dairy Farms, 3
##                crafting buildings in all, 1 of most others)
##   can_expand   the next size: not past the biggest, not while it's still a frame, materials in hand
##   can_sell     not the Barn or Farmhouse, not with anyone inside (they'd have nowhere to go)
## and the materials a frame or a size still needs can be bought with gems, as FarmVille sold them for
## Farm Cash. Who may move into a home is the housing system's (Game.homes.fit), which answers the same way.
## The UI asks here and shows the reason; it never repeats a rule. Reached as `Game.buildings`; it keeps
## no state of its own.

enum Why { OK, UNKNOWN, LEVEL, COINS, GEMS, LIMIT, GROUP_LIMIT, BIGGEST, FRAME, MATERIALS, SOMEONE_INSIDE, KEPT,
	REQUIRES }

const MATERIAL_GEMS := 1   # gems for one building material (FarmVille: 1 Farm Cash each)
## Buildings that stay where they are: the starter Barn and the Farmhouse.
const KEPT := ["barn", "farmhouse"]


## Whether something can be done, and if not, why (with the message to show).
class Verdict:
	var why: BuildingSystem.Why
	var text: String     ## what to tell the player (empty when it's a yes)
	var short: String    ## a word or two for a button ("Level 12", "1 per farm")

	func _init(reason: BuildingSystem.Why, words := "", label := "") -> void:
		why = reason
		text = words
		short = label

	func ok() -> bool:
		return why == BuildingSystem.Why.OK


static func yes() -> Verdict:
	return Verdict.new(Why.OK)


## How many of a building are on the farm (frames included: a frame is one of them, half-built).
func owned(id: String) -> int:
	var n := 0
	for o in game.objects:
		if o["id"] == id:
			n += 1
	return n


## How many of a limit group's buildings are on the farm.
func group_owned(group: String) -> int:
	var n := 0
	for o in game.objects:
		var def := game.building_def(str(o["id"]))
		if def != null and def.limit_group() == group:
			n += 1
	return n


## Can one be bought now? Its level, then how many the farm may have, then its price.
func can_buy(id: String) -> Verdict:
	var it := game.item_data(id)
	if it.is_empty():
		return Verdict.new(Why.UNKNOWN)
	var unlock := int(it.get("unlock_level", 1))
	if game.level() < unlock:
		return Verdict.new(Why.LEVEL, tr("UNLOCKS_AT_LEVEL") % [it["name"], unlock], tr("LEVEL") % unlock)
	var unmet := Requirements.first_unmet(game, id)
	if not unmet.is_empty():
		return Verdict.new(Why.REQUIRES, tr("NEEDS_X") % unmet["text"], tr("NEEDS_SHORT"))
	var def := game.building_def(id)
	if def != null:
		if owned(id) >= def.limit():
			return Verdict.new(Why.LIMIT, tr("LIMIT_REACHED") % [def.limit(), it["name"]],
				tr("LIMIT_SHORT") % def.limit())
		if def.limit_group() != "" and group_owned(def.limit_group()) >= def.group_limit():
			return Verdict.new(Why.GROUP_LIMIT, tr("GROUP_LIMIT_REACHED") % def.group_limit(),
				tr("LIMIT_SHORT") % def.group_limit())
	var price := price_of(id)
	if price.has("gems") and game.gems < int(price["gems"]):
		return Verdict.new(Why.GEMS, tr("NOT_ENOUGH_GEMS_FOR_A") % it["name"])
	if price.has("coins") and game.coins < int(price["coins"]):
		return Verdict.new(Why.COINS, tr("NOT_ENOUGH_COINS_FOR_A") % it["name"])
	return yes()


## What one costs now: {"coins": n} or {"gems": n} (a crafting building's price rises with each owned).
func price_of(id: String) -> Dictionary:
	var it := game.item_data(id)
	if it.get("kind", "") == "crafting":
		return game.crafting.crafting_price(id)
	if it.has("gem_cost"):
		return {"gems": int(it["gem_cost"])}
	return {"coins": int(it.get("cost", 0))}


## Can building `b` grow to its next size now?
func can_expand(b: Dictionary) -> Verdict:
	if b.is_empty() or not game.is_building(b):
		return Verdict.new(Why.UNKNOWN)
	if game.under_construction(b):
		return Verdict.new(Why.FRAME, tr("FINISH_IT_FIRST"))
	if game.building_def(str(b["id"])).grows_with_finds():
		return Verdict.new(Why.BIGGEST)  # it grows by itself, as more are found
	var need := game.land.expansion_needs(b)
	if need.is_empty():
		return Verdict.new(Why.BIGGEST, tr("FULLY_EXPANDED"))
	var short := missing(need)
	if not short.is_empty():
		return Verdict.new(Why.MATERIALS, tr("MATERIALS_SHORT") % describe(short))
	return yes()


## Can it be sold? Not the Barn or Farmhouse, nor a home with anyone inside.
func can_sell(o: Dictionary) -> Verdict:
	if o.is_empty() or o.get("stray", false):
		return Verdict.new(Why.UNKNOWN, tr("THAT_CAN_T_BE_SOLD"))
	if KEPT.has(str(o["id"])):
		return Verdict.new(Why.KEPT, tr("THAT_CAN_T_BE_SOLD"))
	return yes()


## What's still missing of `need` from the materials held: {material: count}, empty when all are there.
func missing(need: Dictionary) -> Dictionary:
	var out := {}
	for m in need:
		var short := int(need[m]) - int(game.parts.get(m, 0))
		if short > 0:
			out[m] = short
	return out


## Gems to buy what's missing of `need`.
func gems_for(need: Dictionary) -> int:
	var n := 0
	for m in missing(need):
		n += int(missing(need)[m])
	return n * MATERIAL_GEMS


## Buys what's missing of `need` with gems (FarmVille sold materials for Farm Cash). False, with a
## message, if there's nothing to buy or not enough gems.
func buy_missing(need: Dictionary) -> bool:
	var short := missing(need)
	if short.is_empty():
		return false
	if not game.spend_gems(gems_for(need)):
		game.message.emit(tr("NOT_ENOUGH_GEMS_FOR_MATERIALS"))
		return false
	for m in short:
		game.parts[m] = int(game.parts.get(m, 0)) + int(short[m])
	game.inventory_changed.emit()
	game.queue_save()
	return true


## Materials as words: "3 Bricks, 2 Nails".
static func describe(materials: Dictionary) -> String:
	var parts: Array[String] = []
	for m in materials:
		parts.append("%d %s" % [int(materials[m]), GameState.part_names.get(m, m)])
	return ", ".join(PackedStringArray(parts))
