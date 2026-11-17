class_name VipSystem
extends GameSystem
## VIP (our own addition, docs/VIP.md): a paid layer on top of the game as it stands. A VIP level (1 to 15) is
## reached with points, from the daily gift's login streak or bought with gems, and is kept for good. Its
## bonuses work only while VIP is active: three days come with each new level, more days cost gems. Active
## VIP multiplies what buildings give (boosts, layout bonuses, the chances on a collection), from 1 at no VIP
## to 2 at the top level; it gates nothing. The Barn shows the level (BarnDef.look_level, Objects3D.state_of).
## Part of the game state: reached as `Game.vip`. Numbers: Balance `vip.*`. Switch: Release "vip".

const DAY := 86400

var points := 0:   # VIP points gathered so far (never fewer)
	set(value):
		points = value
		_level = level_for(value)
var until := 0    # when active VIP runs out (0: never been active)
var _level := 0    # the level those points make (kept: every bonus and chance a building gives asks for it)


func reset() -> void:
	points = 0
	until = 0


func save_to(data: Dictionary) -> void:
	data["vip_points"] = points
	data["vip_until"] = until


func load_from(data: Dictionary) -> void:
	points = maxi(0, int(data.get("vip_points", 0)))
	until = maxi(0, int(data.get("vip_until", 0)))


## The showcase's Barn is the farm's hero at its best: the top VIP level, active (its look, badge and yard).
func showcase() -> void:
	points = int(Balance.a("vip.level_points")[max_level() - 1])
	until = game.now() + Balance.i("vip.week_days") * DAY


## Whether VIP is part of this release at all.
func is_on() -> bool:
	return Release.on("vip")


## The most levels there are.
func max_level() -> int:
	return Balance.a("vip.level_points").size()


## The VIP level `with_points` reaches: 0 before the first, then 1 up to the top.
func level_for(with_points: int) -> int:
	var at := 0
	for need: float in Balance.a("vip.level_points"):
		if with_points < int(need):
			break
		at += 1
	return at


## The VIP level now (0: none yet).
func level() -> int:
	return _level if is_on() else 0


## The points the next level takes in all, or -1 at the top level.
func next_level_points() -> int:
	var at := level()
	return -1 if at >= max_level() else int(Balance.a("vip.level_points")[at])


## Whether VIP's bonuses work right now.
func active() -> bool:
	return is_on() and level() > 0 and game.now() < until


## Seconds of active VIP left (0 when it has lapsed).
func seconds_left() -> int:
	return maxi(0, until - game.now()) if is_on() and level() > 0 else 0


## What everything buildings give is multiplied by: 1 with no active VIP, rising by the same step each level to
## Balance `vip.top_boost` at the top level.
func boost() -> float:
	if _level <= 0 or not active():   # (most farms most of the time: nothing more to work out)
		return 1.0
	return lerpf(1.0, Balance.f("vip.top_boost"), float(_level) / maxi(max_level(), 1))


## A chance as active VIP makes it: multiplied by the boost, never over certain.
func chance(base: float) -> float:
	return minf(1.0, base * boost())


## The points a day of the login streak gives: more each day in a row, up to a cap.
func streak_points(day: int) -> int:
	return clampi(day, 1, Balance.i("vip.streak_days")) * Balance.i("vip.streak_points")


## Points arrive (the daily gift, or bought). Each new level reached adds its free days of active VIP.
func add_points(n: int) -> void:
	if n <= 0 or not is_on():
		return
	var before := level()
	points += n
	var after := level()
	if after > before:
		_add_days((after - before) * Balance.i("vip.level_days"))
		game.message.emit(tr("VIP_LEVEL_REACHED") % [after, Balance.i("vip.level_days")])
		game.vip_level_reached.emit(after)
		_barn_changed()
	game.queue_save()


## Gems for a number of VIP points, and the points a number of gems buys.
func gems_for_points(n: int) -> int:
	return ceili(n / float(Balance.i("vip.points_per_gem")))


## Buys VIP points with `gems` gems. False when there are not enough gems.
func buy_points(gems: int) -> bool:
	if gems <= 0 or not is_on() or not game.spend_gems(gems):
		return false
	add_points(gems * Balance.i("vip.points_per_gem"))
	return true


## Gems to reach the next level from here (0 at the top level).
func gems_to_next_level() -> int:
	var next := next_level_points()
	return 0 if next < 0 else gems_for_points(next - points)


## Gems for a week of active VIP at this level: more at each level.
func week_cost() -> int:
	return Balance.i("vip.week_gems") + Balance.i("vip.week_gems_per_level") * level()


## Buys a week of active VIP, added to whatever time is left. False with no VIP level yet or too few gems.
func buy_week() -> bool:
	if level() <= 0 or not game.spend_gems(week_cost()):
		return false
	_add_days(Balance.i("vip.week_days"))
	_barn_changed()
	game.queue_save()
	return true


func _add_days(days: int) -> void:
	until = maxi(until, game.now()) + days * DAY


## The Barn shows the level and whether VIP is active: it is told to look again.
func _barn_changed() -> void:
	for o in game.objects:
		if game.catalog.get_def(str(o["id"])) is BarnDef:
			game.objects_updated(int(o["uid"]))
