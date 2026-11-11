class_name MasterySystem
extends GameSystem
## Mastery, the FarmVille way, for everything that's harvested: crops, trees and animals.
## Part of the game state: reached as `Game.mastery`; shared state is on `game`.
##
## Every harvest of an item earns it points: a crop per plot (double when fertilized), a tree or an animal
## each time it's collected, standing on the farm or living in a home (a home's harvest counts each one in
## it, so the more of a kind you keep, the sooner it's mastered). Three stars, each paying coins and XP; the
## third puts that item's mastery sign on the farm. A crop's stars also raise its price (game.field.harvest).
## How many points a star needs follows how often it can be harvested: a crop by its growing time, a tree or
## animal by its cycle (FarmVille: an animal's first star took about 3 to 9 harvests).

const CROP_FAST := [150, 450, 900]     # grows in 6 h or less
const CROP_MEDIUM := [80, 240, 480]    # 8 to 16 h
const CROP_SLOW := [40, 120, 240]      # 1 day or more
const PRODUCER_DAILY := [9, 27, 54]    # trees and animals ready every day or sooner
const PRODUCER_TWO_DAYS := [6, 18, 36]
const PRODUCER_SLOW := [3, 9, 18]      # longer
const STAR_COINS := [100, 300, 1000]
const STAR_XP := [10, 30, 100]
const FAST_CROP_SECONDS := 6 * 3600
const DAY := 86400

var points := {}                       # item or crop id -> mastery points


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	points = {}


func save_to(data: Dictionary) -> void:
	data["mastery"] = points


func load_from(data: Dictionary) -> void:
	points = GameSystem.int_map(data.get("mastery", {}))


func points_of(id: String) -> int:
	return int(points.get(id, 0))


## The points each star needs, by how often the item can be harvested.
func thresholds(id: String) -> Array:
	if game.crops.has(id):
		var grow := int(game.crops[id]["grow_seconds"])
		if grow <= FAST_CROP_SECONDS:
			return CROP_FAST
		return CROP_MEDIUM if grow < DAY else CROP_SLOW
	var cycle := int(game.item_data(id).get("cycle_seconds", DAY))
	if cycle <= DAY:
		return PRODUCER_DAILY
	return PRODUCER_TWO_DAYS if cycle <= 2 * DAY else PRODUCER_SLOW


func stars(id: String) -> int:
	var n := points_of(id)
	var out := 0
	for need in thresholds(id):
		if n >= int(need):
			out += 1
	return out


## Can this item be mastered (a crop, or a tree or animal that's harvested)?
func masterable(id: String) -> bool:
	return game.crops.has(id) or ["tree", "animal", "bloom"].has(str(game.item_data(id).get("kind", "")))


## `count` harvests of `id`: points for what it's mastered as (a Full Bloom counts double, for its flower's
## shared mastery under the Single Bloom's id). Returns the stars gained.
func add_harvest(id: String, count: int) -> int:
	var d := game.catalog.get_def(id)
	if d is BloomDef:
		return add((d as BloomDef).single_id(), count * (d as BloomDef).mastery_points())
	return add(id, count)


## Adds points for `count` harvests of `id`, awarding any stars reached. Returns the stars gained.
func add(id: String, count: int) -> int:
	if count <= 0 or not masterable(id):
		return 0
	var before := stars(id)
	points[id] = points_of(id) + count
	var after := stars(id)
	for star in range(before + 1, after + 1):
		award_star(id, star)
	return after - before


func award_star(id: String, star: int) -> void:
	game.add_coins(STAR_COINS[star - 1])
	game.add_xp(STAR_XP[star - 1])
	game.message.emit(tr("MASTERY_STAR") % [name_of(id), star])
	game.ribbons.bump("mastery_stars", 1)
	if star == 3 and game.place_somewhere("mastery_sign"):
		game.objects[-1]["crop"] = id  # FarmVille's mastery sign, to show off on the farm (any mastered item)
		game.message.emit(tr("MASTERED_A_MASTERY_SIGN_WAS_PUT") % name_of(id))
		game.objects_updated()


## What a mastery sign or message calls the item.
func name_of(id: String) -> String:
	if game.crops.has(id):
		return str(game.crops[id]["name"])
	return str(game.item_data(id).get("name", id))


## The colour a mastery sign for `id` is painted (the crop's or the item's own).
func colour_of(id: String) -> String:
	if game.crops.has(id):
		return str(game.crops[id].get("color", ""))
	return str(game.item_data(id).get("color", ""))
