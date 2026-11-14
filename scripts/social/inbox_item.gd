class_name InboxItem
## What passes between you and your neighbours: one small dictionary shape for everything in the inbox (mail
## from neighbours) and the outbox (your own requests and shares), like a placed object. Keeping it a plain
## dictionary means it saves as it is; `clean` mends a damaged one the way SaveCheck mends a save.
##
## Kinds: GIFT is free to claim; ANSWER is a neighbour's reply to something of yours (free); SHARE is free to
## claim (a copy is minted for you, the sharer keeps theirs) unless `collab`, where claiming helps it grow;
## REQUEST is a neighbour's ask: claiming it helps them, for a reward.

const GIFT := "gift"
const ANSWER := "answer"
const SHARE := "share"
const REQUEST := "request"
const KINDS := [GIFT, ANSWER, SHARE, REQUEST]
const ME := -1                       # `from` of your own posts

# What a `give` can hand over.
const PART := "part"
const SUPPLY := "supply"
const COINS := "coins"
const FUEL := "fuel"
const YOUNG := "young"
const WATER := "water"               # one watering of a shared young one (`uid` says which)
const WHATS := [PART, SUPPLY, COINS, FUEL, YOUNG, WATER]


## A new item. `give` is what it hands over (or asks for, in a request); `extra` adds fields (collab, ref...).
static func make(id: int, kind: String, from: int, t: int, give: Dictionary, extra := {}) -> Dictionary:
	var item := {"id": id, "kind": kind, "from": from, "t": t, "give": give.duplicate()}
	item.merge(extra, true)
	return item


## Free to claim, with no cost to you and no daily limit: gifts, answers and pure shares.
static func is_free(item: Dictionary) -> bool:
	var kind := str(item.get("kind", ""))
	return kind == GIFT or kind == ANSWER or (kind == SHARE and not bool(item.get("collab", false)))


## Claiming helps the sender (a request, or a seedling to water): it counts against the day's helps.
static func is_help(item: Dictionary) -> bool:
	return not is_free(item) and KINDS.has(str(item.get("kind", "")))


## A whole, well-formed copy of a saved item, or {} when it can't be mended (unknown kind or give).
static func clean(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var d: Dictionary = raw
	var kind := str(d.get("kind", ""))
	var give := clean_give(d.get("give", {}))
	if not KINDS.has(kind) or give.is_empty():
		return {}
	var out := make(int(d.get("id", 0)), kind, int(d.get("from", ME)), int(d.get("t", 0)), give)
	out["collab"] = bool(d.get("collab", false))
	out["ref"] = int(d.get("ref", 0))
	out["need"] = int(d.get("need", 0))
	out["to"] = int(d.get("to", ME))
	var answers: Array = []
	var saved: Variant = d.get("answers", [])
	if saved is Array:
		for a: Variant in saved:
			var g := clean_give((a as Dictionary).get("give", {})) if a is Dictionary else {}
			if not g.is_empty():
				answers.append({"by": int((a as Dictionary).get("by", 0)), "due": int((a as Dictionary).get("due", 0)),
					"give": g})
	out["answers"] = answers
	return out


## A whole `give`, or {} when its `what` is unknown or its amount is not positive.
static func clean_give(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var d: Dictionary = raw
	var what := str(d.get("what", ""))
	if not WHATS.has(what) or int(d.get("n", 0)) <= 0:
		return {}
	return {"what": what, "id": str(d.get("id", "")), "n": int(d.get("n", 0)), "uid": int(d.get("uid", 0))}
