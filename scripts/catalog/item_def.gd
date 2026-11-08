class_name ItemDef
extends RefCounted
## Base of every catalog entry. Fields and defaults come from data/catalog/schema.json; this class
## and its subclasses add the rules that use them. Subclasses override validate() for checks that
## go beyond types, and the behaviour methods where their kind works differently.

var id: String
var name: String
var kind: String
var unlock_level: int
var data: Dictionary  ## every field with defaults applied; what the rest of the game reads


func setup(d: Dictionary) -> void:
	data = d
	id = str(d.get("id", ""))
	name = str(d.get("name", ""))
	kind = str(d.get("kind", ""))
	unlock_level = int(d.get("unlock_level", 1))


## Problems the schema's type checks can't see (references, consistency). catalog = Catalog.
func validate(_catalog) -> Array[String]:
	return []


## Shown in the Market: unlocked by level, not earned-only.
func in_market() -> bool:
	return unlock_level < Catalog.NEVER_IN_MARKET


func coin_cost() -> int:
	return int(data.get("cost", 0))


func gem_cost() -> int:
	return int(data.get("gem_cost", 0))


## FarmVille: 1 XP per 100 coins spent. Gem buys give none.
func buy_xp() -> int:
	if gem_cost() > 0:
		return 0
	return int(coin_cost() / 100.0)


func _err(msg: String) -> String:
	return "%s: %s" % [id, msg]


## Lifecycle stages this item shows, from its class in schema.json.
func art_stages(lifecycle: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for s in lifecycle.get("stages", []):
		out.append(str(s))
	return out


## Art id for one stage, from the class's pattern.
func art_id(lifecycle: Dictionary, stage: String) -> String:
	return str(lifecycle.get("pattern", "{id}")).replace("{id}", id).replace("{stage}", stage).replace("{n}", stage)


## Every art id this item needs.
func art_ids(lifecycle: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for s in art_stages(lifecycle):
		out.append(art_id(lifecycle, s))
	return out
