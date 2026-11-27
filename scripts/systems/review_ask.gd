class_name ReviewAsk
extends Node
## Google Play's in-app review (the InappReview plugin, MIT; Android only): the rating card asked for after a happy
## moment, a level-up to one of Balance review.levels, never before the player's review.least_sessions-th session
## and at most once in review.gap_days. Google decides whether the card shows (it keeps its own quota), so asking
## costs nothing when it doesn't; the game never asks again in its own words or rewards a rating (Play's policy).

const PLUGIN := "InappReviewPlugin"   # not-ui (the Android singleton's name)
const SCRIPT := "res://addons/InappReviewPlugin/InappReview.gd"   # not-ui
const SETTINGS := ["privacy", "review_asked"]   # not-ui (the unix day of the last ask, kept on the phone)
const DAY := 86400

var _review: Node


## Made once by the game, on Android with the plugin only.
static func begin(game: GameState) -> void:
	if not Engine.has_singleton(PLUGIN):
		return
	var r := ReviewAsk.new()
	r.name = "ReviewAsk"   # not-ui (a node name)
	r._review = (load(SCRIPT) as GDScript).new()
	r.add_child(r._review)
	r._review.connect("review_info_generated", func() -> void: r._review.call("launch_review_flow"))
	game.add_child(r)
	game.leveled_up.connect(r._on_level)


## Whether to ask now: a listed level, enough sessions, and long enough since the last ask (`last_day` 0: never).
static func wanted(level: int, sessions: int, today: int, last_day: int) -> bool:
	var listed := Balance.a("review.levels").any(func(l: Variant) -> bool: return int(l) == level)
	return listed and sessions >= Balance.i("review.least_sessions") \
		and (last_day <= 0 or today - last_day >= Balance.i("review.gap_days"))


func _on_level(level: int) -> void:
	var today := int(Time.get_unix_time_from_system() / DAY)
	var sessions := int(PlayerSettings.value(Analytics.SETTINGS[0], "sessions", 0))
	if not wanted(level, sessions, today, int(PlayerSettings.value(SETTINGS[0], SETTINGS[1], 0))):
		return
	PlayerSettings.keep(SETTINGS[0], {SETTINGS[1]: today})
	_review.call("generate_review_info")   # (the card shows once Google has it ready: review_info_generated)
