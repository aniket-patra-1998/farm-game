class_name CropClock
extends Node
## The farm's growing clock, and what a plot's crop looks like by it. The clock is the `crop_clock` shader global
## (seconds since the farm opened), set here every frame: what grows on its own reads it (a tree's ripening fruit,
## Objects3D.ripen). A crop has four looks (PaintedCrops): seeds under the soil, sprouts, part grown, ripe; then
## withered.

const SPROUT_FROM := 0.2    # of the growing time: the seeds have sprouted
const YOUNG_FROM := 0.45    # and the sprouts are young plants, until the crop is ripe

## The clock's zero (Game.now seconds): what a time is counted from for the `crop_clock` shader global.
static var clock_base := 0.0

var _base := 0.0


func _ready() -> void:
	_base = floorf(now())
	clock_base = _base


func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set(&"crop_clock", now() - _base)  # every frame: see ShaderGlobals


## The game's time as a float (whole seconds are too coarse for a fruit to swell by).
static func now() -> float:
	return Time.get_unix_time_from_system() + Game.debug_time_offset


## The look of plot `i`'s crop: "seeds", "sprout", "young", "ripe" or "withered"; "" for none.
static func stage_of(i: int) -> String:
	match Game.field.phase(i):
		GameState.Phase.RIPE:
			return "ripe"
		GameState.Phase.WITHERED:
			return "withered"
		GameState.Phase.GROWING:
			var g := Game.field.growth(i)
			return "seeds" if g < SPROUT_FROM else ("sprout" if g < YOUNG_FROM else "young")
	return ""


## When plot `i`'s crop next changes look on its own (Game.now), or -1: a growing crop's next look, a ripe one's
## withering.
static func next_change(i: int) -> int:
	if Game.field.phase(i) == GameState.Phase.GROWING:
		var plot: Dictionary = Game.plots[i]
		var grow := float(Game.crops[plot["crop"]]["grow_seconds"])
		for share: float in [SPROUT_FROM, YOUNG_FROM]:
			var t := int(plot["planted_at"]) + ceili(share * grow)
			if t > Game.now():
				return t
	return Game.field.next_phase_at(i)


## How far a crop is mastered, 0..1 (its stars of all it can earn): its plots take a golden cast in the field.
static func mastered(crop_id: String) -> float:
	var most := Game.mastery.thresholds(crop_id).size()
	return float(Game.mastery.stars(crop_id)) / most if most > 0 else 0.0


## Every plot of the farm, by index.
static func all_plots() -> Array:
	var out := []
	var n := Game.farm_size
	for r in n:
		for c in n:
			out.append(Game.index_of(r, c))
	return out
