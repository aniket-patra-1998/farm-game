class_name WearSystem
extends GameSystem
## Building wear (our own addition, docs/WEAR.md; owner, 19 Nov: "more utilities/upgrades should come at the cost
## of more maintenance"). A utility building wears with time, as a vehicle rusts: a level every Balance
## `wear.level_days`, faster for each size it has grown (`wear.size_faster`), none in a farm's first
## `wear.grace_days`. Each level costs it something of its work (BuildingDef.wear_kind says what):
## - a home (animals, trees, bees, helpers) gives fewer coins a collect, and at the last level none at all;
## - a crafting building crafts slower, and at the last level starts nothing;
## - a Garage keeps less rust off: fully worn, its vehicles rust as fast as those standing outside;
## - storage (the Barn, the Garden Shed) holds less (nothing kept is thrown out: a full one takes nothing new),
##   and from `wear.spoil_from` some of what spoils (the Barn's feed, the Shed's bunches) spoils a day.
## A repair (coins and the building's own materials, a share of what it cost, and time) takes it all off.
## Worked out from the clock, as rust: what is kept is the wear gathered when it last changed pace, and when.
## Part of the game state: reached as `Game.wear`. Switch: Release "wear". Numbers: Balance `wear.*`.

const DAY := 86400.0
const KEY := "#"   # not-ui (a building's key among the rust signs' ids: "#" + its uid)

## building uid (as a string) -> {"w": wear gathered by `t`, in seconds at the size-1 pace, "t": when,
## "p": the pace it has worn at since `t` (_pace), "fix": when its repair is done (0: not being repaired)}
var buildings := {}
var spoil_t := 0          # when spoiling was last worked out
var _spoil_carry := {}    # building uid -> the part of a spoiled thing not yet whole (spoiling is slow)


func _init(owner: GameState) -> void:
	super(owner)
	game.objects_changed.connect(settle)
	game.building_upgraded.connect(func(uid: int, _level: int) -> void: _grew(uid))


func reset() -> void:
	buildings = {}
	spoil_t = game.now()
	_spoil_carry = {}


func save_to(data: Dictionary) -> void:
	data["wear"] = buildings
	data["wear_spoil_t"] = spoil_t


func load_from(data: Dictionary) -> void:
	buildings = {}
	_spoil_carry = {}
	spoil_t = int(data.get("wear_spoil_t", game.now()))
	var saved: Variant = data.get("wear", {})
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for key: String in saved:
		var b: Variant = saved[key]
		if typeof(b) == TYPE_DICTIONARY:
			buildings[key] = {"w": maxf(0.0, float(b.get("w", 0.0))), "t": int(b.get("t", game.now())),
				"p": maxf(1.0, float(b.get("p", 1.0))), "fix": int(b.get("fix", 0))}


func shift_clock(seconds: int) -> void:
	spoil_t -= seconds
	for key: String in buildings:
		var b: Dictionary = buildings[key]
		b["t"] = int(b["t"]) - seconds
		if int(b["fix"]) > 0:
			b["fix"] = int(b["fix"]) - seconds


## The showcase's utility buildings show every stage of wear between them: like new, the stages between, stopped.
func showcase() -> void:
	var worn: Array[Dictionary] = []
	for o in game.objects:
		if wears(o):
			worn.append(o)
	for k in worn.size():
		var at := roundi(float(k) * max_level() / maxi(worn.size() - 1, 1))
		buildings[str(worn[k]["uid"])] = {"w": (at + 0.3) * Balance.f("wear.level_days") * DAY, "t": game.now(),
			"p": _pace(worn[k]), "fix": 0}


func is_on() -> bool:
	return Release.on("wear")


## The most wear there is: at this level a building stops working.
func max_level() -> int:
	return Balance.a("wear.repair_share").size()


## Whether `o` is a building that wears (a utility building, built, on the farm).
func wears(o: Dictionary) -> bool:
	return is_on() and not o.is_empty() and game.is_building_item(str(o["id"])) and not game.under_construction(o) \
		and game.building_def(str(o["id"])).wear_kind() != ""


## What wear does to `o`: BuildingDef.wear_kind ("home", "crafting", "garage", "storage" or "").
func kind_of(o: Dictionary) -> String:
	return game.building_def(str(o["id"])).wear_kind() if wears(o) else ""


## Buildings came, went or were built: each new one starts like new; one gone is forgotten.
func settle() -> void:
	if not is_on():
		return
	var here := {}
	for o in game.objects:
		if wears(o):
			var key := str(o["uid"])
			here[key] = true
			if not buildings.has(key):
				buildings[key] = {"w": 0.0, "t": game.now(), "p": _pace(o), "fix": 0}
	for key: String in buildings.keys():
		if not here.has(key):
			buildings.erase(key)


## A building grew a size: its wear so far is kept, and it wears faster from here.
func _grew(uid: int) -> void:
	var key := str(uid)
	if buildings.has(key):
		_bank(key)
		buildings[key]["p"] = _pace(game.object_by_uid(uid))


## How many times as fast `o` wears as a size-1 building (each size it has grown wears it faster).
func _pace(o: Dictionary) -> float:
	return 1.0 + Balance.f("wear.size_faster") * maxi(0, game.level_of(o) - 1)


## When wear may start on this farm (none in its first weeks).
func _grace_end() -> int:
	if game.born_day < 0:
		return 0
	return int((game.born_day + Balance.i("wear.grace_days")) * DAY)


## The wear `uid` has gathered by now, in seconds at the size-1 pace.
func gathered(uid: int) -> float:
	var key := str(uid)
	if not is_on() or not buildings.has(key):
		return 0.0
	var o := game.object_by_uid(uid)
	if o.is_empty():
		return 0.0
	var b: Dictionary = buildings[key]
	var pace := float(b.get("p", _pace(o)))
	if _repaired(key):
		return maxf(0.0, float(game.now() - maxi(int(b["fix"]), _grace_end()))) * _pace(o)
	if int(b["fix"]) > 0:
		return float(b["w"])   # (being repaired: it gathers none)
	return float(b["w"]) + maxf(0.0, float(game.now() - maxi(int(b["t"]), _grace_end()))) * pace


## A building's level of wear: 0 like new, up to max_level().
func level(uid: int) -> int:
	return clampi(floori(gathered(uid) / (Balance.f("wear.level_days") * DAY)), 0, max_level())


func level_of(o: Dictionary) -> int:
	return level(int(o["uid"])) if wears(o) else 0


## Seconds until `o` reaches wear level `n` (0 if it has, -1 if it never will now: being repaired, or no wear).
func seconds_until_level(o: Dictionary, n: int) -> int:
	if not wears(o) or repairing(int(o["uid"])) or not buildings.has(str(o["uid"])):
		return -1
	var left := n * Balance.f("wear.level_days") * DAY - gathered(int(o["uid"]))
	if left <= 0.0:
		return 0
	var b: Dictionary = buildings[str(o["uid"])]
	return ceili(left / float(b.get("p", _pace(o)))) + maxi(0, _grace_end() - game.now())


## Whether it is too worn to work at all (a home gives nothing, a crafting building starts nothing).
func stopped(o: Dictionary) -> bool:
	return wears(o) and level_of(o) >= max_level() and not repairing(int(o["uid"]))


## A home's coins a collect, as a share of a like-new one's.
func goods_factor(o: Dictionary) -> float:
	if kind_of(o) != "home":
		return 1.0
	return 0.0 if stopped(o) else maxf(0.0, 1.0 - Balance.f("wear.goods_less") * level_of(o))


## How many times as long a craft takes in this building.
func craft_factor(o: Dictionary) -> float:
	return 1.0 + Balance.f("wear.craft_slower") * level_of(o) if kind_of(o) == "crafting" else 1.0


## A storage building's room, as a share of a like-new one's.
func room_factor(o: Dictionary) -> float:
	return maxf(0.0, 1.0 - Balance.f("wear.room_less") * level_of(o)) if kind_of(o) == "storage" else 1.0


## How much of its rust a Garage no longer keeps off: 0 like new, 1 fully worn (its vehicles rust as outside).
func garage_share(o: Dictionary) -> float:
	return float(level_of(o)) / max_level() if kind_of(o) == "garage" else 0.0


## Whether it wants a repair: worn, and not in for one now.
func needs_repair(o: Dictionary) -> bool:
	return wears(o) and level_of(o) > 0 and not repairing(int(o["uid"]))


func repairing(uid: int) -> bool:
	return repair_left(uid) > 0


func repair_left(uid: int) -> int:
	if not is_on():
		return 0
	return maxi(0, int((buildings.get(str(uid), {}) as Dictionary).get("fix", 0)) - game.now())


## What `o` and its sizes cost: its price (at least `wear.least_price`), the coins of its sizes so far, and their
## materials (a repair is a share of these: owner, 19 Nov, "not more than 40% of the building cost").
func _worth(o: Dictionary) -> Dictionary:
	var def := game.building_def(str(o["id"]))
	var coins := maxi(int(game.item_data(str(o["id"])).get("cost", 0)), Balance.i("wear.least_price"))
	var materials := {}
	for n in range(2, game.level_of(o) + 1):
		var s := def.size(n)
		coins += int(s.get("coins", 0))
		var m: Dictionary = s.get("materials", {})
		for part: String in m:
			materials[part] = int(materials.get(part, 0)) + int(m[part])
	return {"coins": coins, "materials": materials}


## How many times a repair's coins are for how far the farm has grown (its level), so upkeep keeps pace with what
## a bigger farm earns (owner, 19 Nov).
func grown() -> float:
	return 1.0 + Balance.f("wear.level_scale") * game.level() * game.level()


## The coins, materials and seconds a repair takes now ({} when there is nothing to repair).
func repair_cost(uid: int) -> Dictionary:
	var o := game.object_by_uid(uid)
	var at := level_of(o) if not o.is_empty() else 0
	if at <= 0:
		return {}
	var share := float(Balance.a("wear.repair_share")[at - 1])
	var worth := _worth(o)
	var materials := {}
	for part: String in worth["materials"]:
		var n := ceili(float(worth["materials"][part]) * share)
		if n > 0:
			materials[part] = n
	return {"coins": roundi(float(worth["coins"]) * share * grown()), "materials": materials,
		"seconds": int(Balance.a("wear.repair_seconds")[at - 1])}


func can_repair(uid: int) -> bool:
	var cost := repair_cost(uid)
	return not cost.is_empty() and not repairing(uid) and game.coins >= int(cost["coins"]) \
		and game.buildings.missing(cost["materials"]).is_empty()


## Starts the repair: coins and materials are paid now; it comes out like new when the time is up (until then
## it works as worn as it is).
func repair(uid: int) -> bool:
	if not can_repair(uid):
		return false
	var cost := repair_cost(uid)
	if not game.spend(int(cost["coins"])):
		return false
	for part: String in cost["materials"]:
		game.parts[part] = int(game.parts[part]) - int(cost["materials"][part])
	var key := str(uid)
	_bank(key)
	buildings[key]["fix"] = game.now() + int(cost["seconds"])
	game.message.emit(tr("RUST_REPAIR_STARTED") % game.name_of(str(game.object_by_uid(uid)["id"])))
	game.record("repair", str(game.object_by_uid(uid)["id"]))
	game.inventory_changed.emit()
	game.objects_updated(uid)
	game.queue_save()
	return true


## What a repair of `uid` would need that the farm hasn't got, said for the player ("" when nothing).
func repair_short(uid: int) -> String:
	var cost := repair_cost(uid)
	if cost.is_empty():
		return ""
	var short := game.buildings.missing(cost["materials"])
	if game.coins < int(cost["coins"]):
		return tr("RUST_REPAIR_NO_COINS")
	return tr("MATERIALS_SHORT") % BuildingSystem.describe(short) if not short.is_empty() else ""


## The worst-worn building that wants a repair, as a key for the signs ("" when none).
static func key_of(uid: int) -> String:
	return KEY + str(uid)


static func uid_of(key: String) -> int:
	return int(key.substr(KEY.length())) if key.begins_with(KEY) else -1


## What spoils in worn storage since this was last worked out: from `wear.spoil_from`, `wear.spoil_share` of what
## the Barn holds of feed and the Garden Shed of bunches, a day. Returns how many things spoiled.
func spoil() -> int:
	var days := float(game.now() - spoil_t) / DAY
	spoil_t = game.now()
	if not is_on() or days <= 0.0:
		return 0
	var lost := 0
	for o in game.objects:
		var at := level_of(o)
		if kind_of(o) != "storage" or at < Balance.i("wear.spoil_from") or repairing(int(o["uid"])):
			continue
		var key := str(o["uid"])
		var held := _spoilable(o)
		var due := float(_spoil_carry.get(key, 0.0)) + held * Balance.f("wear.spoil_share") * days
		var n := mini(floori(due), held)
		_spoil_carry[key] = due - n
		if n > 0:
			_take_spoiled(o, n)
			lost += n
	if lost > 0:
		game.message.emit(tr("WEAR_SPOILED") % lost)
		game.inventory_changed.emit()
		game.queue_save()
	return lost


func _spoilable(o: Dictionary) -> int:
	if game.special_of(o) == "garden_shed":
		return game.shed.bunches.size()
	var n := 0
	for feed: String in game.feeds.stock:
		n += int(game.feeds.stock[feed])
	return n


## Takes `n` spoiled things out of storage `o`, from its biggest heaps first.
func _take_spoiled(o: Dictionary, n: int) -> void:
	if game.special_of(o) == "garden_shed":
		for k in mini(n, game.shed.bunches.size()):
			game.shed.bunches.pop_back()
		return
	var stock: Dictionary = game.feeds.stock
	for k in n:
		var most := ""
		for feed: String in stock:
			if most == "" or int(stock[feed]) > int(stock[most]):
				most = feed
		if most == "":
			return
		stock[most] = int(stock[most]) - 1
		if int(stock[most]) <= 0:
			stock.erase(most)


func _repaired(key: String) -> bool:
	var fix := int((buildings.get(key, {}) as Dictionary).get("fix", 0))
	return fix > 0 and game.now() >= fix


func _bank(key: String) -> void:
	var b: Dictionary = buildings[key]
	b["w"] = gathered(int(key))
	b["t"] = game.now()
	if _repaired(key):
		b["fix"] = 0
		b["p"] = _pace(game.object_by_uid(int(key)))
