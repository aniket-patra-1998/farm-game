class_name FarmPiece
extends Node2D
## One thing on the farm, drawn as its own node: a plowed or planted plot, or an object (animal, tree,
## building, decoration, vehicle). The object layer orders pieces by depth with z_index and animates them;
## each piece only redraws when what it shows changes (see state_key).
##
## A piece sits at its ground point ("base": a plot's centre, an object's footprint centre) and draws in
## farm coordinates shifted back by that point, so the node's own scale, skew and offset animate it around
## its base: plants sway from the stem, animals breathe and wander, trees lean in the wind.

var grid: FarmGrid
var plot := -1          # plot index, for a plot piece
var uid := -1           # object uid, for an object piece
var base := Vector2.ZERO
var motion := ""        # "", "animal", "bird", "tree": how ObjectLayer animates it
var phase := 0.0        # each piece moves on its own beat
var plants: CropPlants  # a plot's plants, drawn and swayed separately from its soil
var facing := 1.0       # an animal's direction (1 or -1), times the object's own flip
var flip := 1.0         # the object's own flip (rotate tool)
var wander := Vector2.ZERO        # an animal's offset from its tile centre
var wander_to := Vector2.ZERO
var next_move := 0.0              # seconds until the animal picks a new spot
var _key := ""


func _draw() -> void:
	draw_set_transform(-base)
	if plot >= 0:
		grid.draw_bed_on(self, plot)
	else:
		var o := Game.object_by_uid(uid)
		if not o.is_empty():
			if motion == "animal" or motion == "bird":
				# A small shadow that walks with the animal.
				var r := 0.32 if motion == "animal" else 0.2
				PlaceholderArt.draw_ellipse_at(self, base + Vector2(0, 2), FarmGrid.TILE_W * r, FarmGrid.TILE_H * r, Color(0.05, 0.09, 0.03, 0.22))
			grid.draw_object_on(self, o, false)


## Redraws only if something that changes the picture has changed.
func refresh() -> void:
	var k := state_key()
	if k != _key:
		_key = k
		queue_redraw()
		if plants != null:
			plants.queue_redraw()


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
