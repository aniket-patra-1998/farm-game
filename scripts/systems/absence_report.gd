class_name AbsenceReport
extends RefCounted
## "While you were away": what ripened, what withered and what is ready to collect between the save and now, in one
## line the player sees when the farm opens. Worked out from the saved timers (nothing is stored for it), so it is
## right however long the player was gone. The bees' own note (BeehiveSystem.apply_absence) is joined to it.


## The report for the time from `from_t` to `to_t` (unix seconds), or "" when there is nothing to say or the player
## was only away a moment (Balance absence.min_seconds).
static func build(game: GameState, from_t: int, to_t: int) -> String:
	if to_t - from_t < Balance.i("absence.min_seconds"):
		return ""
	var ripened := 0
	var withered := 0
	for i in game.plots.size():
		var p: Dictionary = game.plots[i]
		if p.get("state") != "planted" or not game.crops.has(p.get("crop", "")):
			continue
		var crop: Dictionary = game.crops[p["crop"]]
		var ripe_at := int(p["planted_at"]) + int(crop["grow_seconds"])
		var wither_at := ripe_at + game.field.ripe_window(crop) \
			* (Balance.i("economy.pollinated_ripe_mult") if p.get("pol", false) else 1)
		if ripe_at > from_t and ripe_at <= to_t and wither_at > to_t:
			ripened += 1
		if wither_at > from_t and wither_at <= to_t:
			withered += 1
	var ready := 0
	for o in game.objects:
		if game.is_ready(o) and int(o["t"]) + game.cycle_of(o) > from_t:
			ready += 1
	var parts: Array[String] = []
	if ripened > 0:
		parts.append(TranslationServer.translate("ABSENT_RIPE") % ripened)
	if withered > 0:
		parts.append(TranslationServer.translate("ABSENT_WITHERED") % withered)
	if ready > 0:
		parts.append(TranslationServer.translate("ABSENT_READY") % ready)
	return "" if parts.is_empty() else TranslationServer.translate("ABSENT_HEAD") % ", ".join(PackedStringArray(parts))
