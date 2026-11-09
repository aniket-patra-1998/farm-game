class_name GameSystem
extends RefCounted
## Base of the game's subsystems (crafting, vehicles, the beehive...). GameState owns one of each and
## calls them through the same lifecycle: load_data() once at start, then reset() for a new game, or
## load_from() with a save; save_to() adds the system's fields to the save.
##
## A system owns its own state and rules. Shared state (coins, plots, placed objects, signals) lives on
## `game`, and other systems are reached as `game.<name>`, for example `game.vehicles.add_fuel(10)`.

var game: GameState


func _init(owner: GameState) -> void:
	game = owner


## Reads the system's data files. Called once, before any game is started or loaded.
func load_data() -> void:
	pass


## Starts the system's state for a brand-new farm.
func reset() -> void:
	pass


## Adds the system's fields to a save. Keys share one flat dictionary, so they must be unique.
func save_to(_data: Dictionary) -> void:
	pass


## Restores the system's state from a save; older saves may lack any field, so every read has a default.
func load_from(_data: Dictionary) -> void:
	pass


## A saved map with its values read back as ints (JSON numbers load as floats).
static func int_map(d: Variant) -> Dictionary:
	var out := {}
	if typeof(d) == TYPE_DICTIONARY:
		for k in d:
			out[str(k)] = int(d[k])
	return out
