class_name SimulatedNeighbours
extends NeighbourTransport
## Single-player neighbours: a fixed cast (data/social.json) that sends you things and answers your posts,
## worked out from a seed so the same stretch of time always gives the same mail, however often or late it is
## asked for. Nothing runs between asks: time is simulated in slots when the game catches up (on load, and
## on a slow timer), so being away for a day costs the same as being away for a minute.

const DATA := "res://data/social.json"

var cast: Array = []       # [{name, speed, kind}]
var pools := {}            # "gifts", "requests", "shares" -> [{w, give, collab?}]


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	cast = data.get("neighbours", [])
	for pool: String in ["gifts", "requests", "shares"]:
		pools[pool] = data.get(pool, [])


func roster() -> Array[String]:
	var names: Array[String] = []
	for n: Dictionary in cast:
		names.append(str(n.get("name", "")))
	return names


func incoming(from_t: int, to_t: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var slot_len := maxi(Balance.i("social.slot_seconds"), 1)
	for slot in range(from_t / slot_len + 1, to_t / slot_len + 1):
		for idx in cast.size():
			var rng := _rng([idx, slot])
			var kindness := float((cast[idx] as Dictionary).get("kind", 0.5))
			if rng.randf() >= Balance.f("social.slot_chance") * kindness * 2.0:
				continue
			var item := _mail(rng, idx, slot * slot_len)
			if not item.is_empty():
				out.append(item)
	return out


func answers_for(post: Dictionary, now: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if cast.is_empty():
		return out
	var rng := _rng([int(post.get("id", 0)), int(post.get("t", 0))])
	var order := range(cast.size())
	_shuffle(order, rng)
	var kind := str(post.get("kind", ""))
	var give: Dictionary = post.get("give", {})
	if kind == InboxItem.GIFT and rng.randf() >= Balance.f("social.thanks_chance"):
		return out
	for idx: int in order:
		if out.size() >= _wanted(post):
			break
		var who: Dictionary = cast[idx]
		var willing := rng.randf() < float(who.get("kind", 0.5)) + 0.25
		if not willing and not (out.is_empty() and idx == order[order.size() - 1]):
			continue
		var wait := rng.randf_range(Balance.f("social.answer_min_seconds"), Balance.f("social.answer_max_seconds"))
		out.append({"by": idx, "due": now + int(wait * float(who.get("speed", 1.0))), "give": _reply(kind, give, post)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["due"]) < int(b["due"]))
	return out


## How many neighbours a post can hope to hear from.
func _wanted(post: Dictionary) -> int:
	match str(post.get("kind", "")):
		InboxItem.REQUEST:
			return clampi(int(post.get("need", 1)), 1, cast.size())
		InboxItem.SHARE:
			return mini(Balance.i("social.seedling_waters"), cast.size()) if bool(post.get("collab", false)) else 2
	return 1


## What an answer hands over: the asked-for thing, a watering, or thanks in coins.
func _reply(kind: String, give: Dictionary, post: Dictionary) -> Dictionary:
	if kind == InboxItem.REQUEST:
		var one := give.duplicate()
		one["n"] = Balance.i("social.fuel_per_answer") if give.get("what") == InboxItem.FUEL else 1
		return one
	if kind == InboxItem.SHARE and bool(post.get("collab", false)):
		return {"what": InboxItem.WATER, "id": "", "n": 1, "uid": int(post.get("ref", 0))}
	return {"what": InboxItem.COINS, "id": "", "n": Balance.i("social.thanks_coins"), "uid": 0}


## One piece of mail from neighbour `idx`, drawn from the pools by weight.
func _mail(rng: RandomNumberGenerator, idx: int, t: int) -> Dictionary:
	var kinds := {
		InboxItem.GIFT: Balance.i("social.kind_gift"),
		InboxItem.REQUEST: Balance.i("social.kind_request"),
		InboxItem.SHARE: Balance.i("social.kind_share"),
	}
	var kind := str(_weighted_key(kinds, rng))
	var pool: Array = pools[{InboxItem.GIFT: "gifts", InboxItem.REQUEST: "requests", InboxItem.SHARE: "shares"}[kind]]
	var entry := _weighted(pool, rng)
	if entry.is_empty():
		return {}
	return InboxItem.make(0, kind, idx, t, entry["give"], {"collab": bool(entry.get("collab", false))})


func _weighted(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for e: Dictionary in pool:
		total += int(e.get("w", 1))
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	for e: Dictionary in pool:
		roll -= int(e.get("w", 1))
		if roll <= 0:
			return e
	return {}


func _weighted_key(weights: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var total := 0
	for k: Variant in weights:
		total += int(weights[k])
	var roll := rng.randi_range(1, maxi(total, 1))
	for k: Variant in weights:
		roll -= int(weights[k])
		if roll <= 0:
			return k
	return weights.keys()[0]


## A random stream that depends only on `key`, so the same moment always rolls the same.
func _rng(key: Array) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	return rng


func _shuffle(order: Array, rng: RandomNumberGenerator) -> void:
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = order[i]
		order[i] = order[j]
		order[j] = tmp
