class_name FarmPiece
extends Node2D
## One thing on the farm, drawn as its own node: a plowed or planted plot, or an object (animal, tree,
## building, decoration, vehicle). The object layer orders pieces by depth with z_index; each piece only
## redraws when what it shows changes (see state_key).

var grid: FarmGrid
var plot := -1   # plot index, for a plot piece
var uid := -1    # object uid, for an object piece
var _key := ""   # what was drawn last


func _draw() -> void:
	if plot >= 0:
		grid.draw_plot_on(self, plot)
	else:
		var o := Game.object_by_uid(uid)
		if not o.is_empty():
			grid.draw_object_on(self, o)


## Redraws only if something that changes the picture has changed.
func refresh() -> void:
	var k := state_key()
	if k != _key:
		_key = k
		queue_redraw()


func force_redraw() -> void:
	_key = ""
	refresh()


func state_key() -> String:
	if plot >= 0:
		var ph := Game.phase(plot)
		var art := Game.crop_art_for(plot) if ph != GameState.Phase.PLOWED else ""
		# Code-drawn crops grow smoothly: redraw them in tenths of their growth.
		var growth := int(Game.growth(plot) * 10.0) if ph == GameState.Phase.GROWING and art == "" else 0
		return "%d|%s|%s|%s|%d" % [ph, Game.crop_at(plot), art, Game.is_fertilized(plot), growth]
	var o := Game.object_by_uid(uid)
	if o.is_empty():
		return ""
	var ready := Game.is_ready(o) or (Game.is_crafting(o) and Game.crafts_done(o) > 0)
	var inside := Game.inside_total(o) if Game.is_building(o) else 0
	return "%s|%d|%d|%s|%s|%s|%s|%d|%s|%s" % [o["id"], int(o["row"]), int(o["col"]), int(o.get("level", 1)), ready,
		o.get("flip", false), o.get("broken", false), inside, Game.under_construction(o), Game.art_for(o)]


func is_ready() -> bool:
	if plot >= 0:
		return Game.phase(plot) == GameState.Phase.RIPE
	var o := Game.object_by_uid(uid)
	return not o.is_empty() and (Game.is_ready(o) or (Game.is_crafting(o) and Game.crafts_done(o) > 0))
