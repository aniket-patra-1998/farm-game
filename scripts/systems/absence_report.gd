class_name AbsenceReport
extends RefCounted
## "While you were away": what ripened, what withered and what is ready to collect between the save and now, in one
## line the player sees when the farm opens. Worked out from the saved timers (nothing is stored for it), so it is
## right however long the player was gone. The bees' own note (BeehiveSystem.apply_absence) is joined to it.


const WORDS := {"ripe": "ABSENT_RIPE", "withered": "ABSENT_WITHERED", "ready": "ABSENT_READY",
	"hungry": "AWAY_HUNGRY", "stray": "AWAY_STRAY"}   # each row's words, as keys in locale/strings.csv
const LINE_KINDS := ["ripe", "withered", "ready"]   # the rows the one-line report says


## The report for the time from `from_t` to `to_t` (unix seconds) in one line, or "" when there is nothing to say
## or the player was only away a moment (Balance absence.min_seconds).
static func build(game: GameState, from_t: int, to_t: int) -> String:
	return line(items(game, from_t, to_t))


## The same report as rows, [{kind, count}], for the away card (each row goes to one of its things): "ripe",
## "withered" and "ready" as the line has them, and "hungry" for what waits to be fed now.
static func items(game: GameState, from_t: int, to_t: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if to_t - from_t < Balance.i("absence.min_seconds"):
		return out
	var ripened := 0
	var withered := 0
	for i in game.plots.size():
		var p: Dictionary = game.plots[i]
		if p.get("state") != "planted" or not game.crops.has(p.get("crop", "")):
			continue
		var crop: Dictionary = game.crops[p["crop"]]
		var ripe_at := int(p["planted_at"]) + int(crop["grow_seconds"])
		var wither_at := game.field.withers_at(i, ripe_at, crop)
		if ripe_at > from_t and ripe_at <= to_t and wither_at > to_t:
			ripened += 1
		if wither_at > from_t and wither_at <= to_t:
			withered += 1
	var ready := 0
	for o in game.objects:
		if game.is_ready(o) and int(o["t"]) + game.cycle_of(o) > from_t:
			ready += 1
	var hungry := 0
	if game.feeds.enabled():
		for o in game.objects:
			if game.feeds.is_hungry(o):
				hungry += 1
	for row: Array in [["ripe", ripened], ["withered", withered], ["ready", ready], ["hungry", hungry]]:
		if int(row[1]) > 0:
			out.append({"kind": row[0], "count": int(row[1])})
	return out


## A row's words ("12 crops ripened").
static func words(item: Dictionary) -> String:
	var text := TranslationServer.translate(str(WORDS.get(item["kind"], "")))
	return text % int(item["count"]) if text.contains("%d") else text


## The one line of a report's rows (what ripened, withered and is ready: hunger is the card's alone).
static func line(rows: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for item: Dictionary in rows:
		if LINE_KINDS.has(item["kind"]):
			parts.append(words(item))
	return "" if parts.is_empty() else TranslationServer.translate("ABSENT_HEAD") % ", ".join(PackedStringArray(parts))
