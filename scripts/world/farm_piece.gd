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
var flip := 1.0         # the object's own flip (rotate tool)
var redraw_wait := 0.0  # an idle animal's seconds until its next redraw (ObjectLayer)
var animal: AnimalBehaviour  # an animal's mind and pose: where it walks, what its legs, head and tail do
## Squash and stretch, and a lift off the ground, for drop-ins, bounces and pops. Animated pieces
## (animals) fold these into their own motion each frame; still ones apply them right away.
var squash := Vector2.ONE: set = _set_squash
var lift := 0.0: set = _set_lift
var _key := ""
var _phase_drawn := -1
var _tween: Tween


func _set_squash(v: Vector2) -> void:
	squash = v
	_apply_pose()


func _set_lift(v: float) -> void:
	lift = v
	_apply_pose()


func is_animal() -> bool:
	return motion == "animal" or motion == "bird"


func _apply_pose() -> void:
	if is_animal():
		return  # ObjectLayer poses animals every frame
	scale = Vector2(flip, 1.0) * squash
	position = base - Vector2(0, lift)


func _restart_tween() -> Tween:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	return _tween


## Arrives on the farm: drops in from above, lands with a squash and a puff of dust.
func drop_in() -> void:
	lift = 70.0
	squash = Vector2(0.86, 1.16)
	modulate.a = 0.0
	var tw := _restart_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.12)
	tw.tween_property(self, "lift", 0.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		if grid != null and grid.world_fx != null:
			grid.world_fx.burst("dust", base))
	tw.chain().tween_property(
		self,
		"squash",
		Vector2(1.16, 0.84),
		0.07
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "squash", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A freshly plowed bed rises out of the grass.
func rise() -> void:
	squash = Vector2(1.0, 0.25)
	var tw := _restart_tween()
	tw.tween_property(self, "squash", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Tapped: a quick squash and spring back.
func bounce() -> void:
	var tw := _restart_tween()
	tw.tween_property(self, "squash", Vector2(1.12, 0.88), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "squash", Vector2(0.95, 1.07), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "squash", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Seedlings grow in after planting.
func grow_in() -> void:
	if plants == null:
		return
	plants.scale = Vector2(0.15, 0.15)
	var tw := plants.create_tween()
	tw.tween_property(plants, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	draw_set_transform(-base)
	if plot >= 0:
		grid.draw_bed_on(self, plot)
	else:
		var o := Game.object_by_uid(uid)
		if not o.is_empty():
			if animal != null and Game.art_for(o) == "":
				# Drawn from its rig in this frame's pose: legs, head, tail and all (with its own shadow).
				AnimalArt.draw(self, base, Game.item_data(o["id"]), is_ready(), animal.pose)
			else:
				grid.draw_object_on(self, o, false)


## Redraws only if something that changes the picture has changed.
func refresh() -> void:
	var k := state_key()
	if k != _key:
		_key = k
		queue_redraw()
		if plants != null:
			plants.queue_redraw()
			# Just planted (it was bare soil a moment ago): the seedlings grow in.
			var ph := Game.phase(plot)
			if _phase_drawn == GameState.Phase.PLOWED and ph == GameState.Phase.GROWING:
				grow_in()
			_phase_drawn = ph


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
	var ready := Game.is_ready(o) or (Game.crafting.is_crafting(o) and Game.crafting.crafts_done(o) > 0)
	var inside := Game.inside_total(o) if Game.is_building(o) else 0
	return "%s|%d|%d|%s|%s|%s|%s|%d|%s|%s" % [o["id"], int(o["row"]), int(o["col"]), int(o.get("level", 1)), ready,
		o.get("flip", false), o.get("broken", false), inside, Game.under_construction(o), Game.art_for(o)]


func is_ready() -> bool:
	if plot >= 0:
		return Game.phase(plot) == GameState.Phase.RIPE
	var o := Game.object_by_uid(uid)
	return not o.is_empty() and (
		Game.is_ready(o) or (Game.crafting.is_crafting(o) and Game.crafting.crafts_done(o) > 0)
	)
