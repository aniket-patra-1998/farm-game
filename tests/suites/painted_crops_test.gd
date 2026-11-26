extends TestSuite
## Crops as painted pictures (PaintedCrops; tools/paint_plants.py): a flat card to a plot, facing the camera, its
## picture made on the device from a recipe of shapes.


func test_652_a_plot_shows_its_crops_painted_picture_for_each_look() -> void:
	# (owner, 26 Nov: crops painted as the classic farm games' are, four looks to a crop)
	var g := _farm()
	for crop_id: String in Game.crops:
		for look: String in ["_young", "_ripe"]:
			_check(PaintedCrops.picture(crop_id + look) != null, "%s%s is painted from its recipe" % [crop_id, look])
	_check(PaintedCrops.picture(PaintedCrops.SPROUT) != null, "and every crop shares the sprouts")
	var layer := PaintedCrops.new()
	add_child(layer)
	var crop: Dictionary = Game.crops["wheat"]
	var grow := float(crop["grow_seconds"])
	var long_ago := grow + Game.field.ripe_window(crop) + 60.0
	var ages: Array = [0.05 * grow, 0.3 * grow, 0.6 * grow, grow + 1.0, long_ago]
	var plots: Array[int] = []
	for k in ages.size():
		plots.append(Game.index_of(2, 2 + k))
		Game.plots[plots[k]] = {"state": "planted", "crop": "wheat", "planted_at": Game.now() - int(ages[k])}
	layer.update()
	_eq(layer.shown(plots[0]), "", "seeds lie under the soil: no picture")
	_eq(layer.shown(plots[1]), PaintedCrops.SPROUT, "then the sprouts")
	_eq(layer.shown(plots[2]), "wheat_young", "then the crop part grown")
	_eq(layer.shown(plots[3]), "wheat_ripe", "then ripe")
	_eq(layer.shown(plots[4]), "wheat_ripe", "and withered is the ripe picture..")
	_eq((layer._shown[plots[4]][1] as Color).r, 1.0, "..gone dry")
	_eq((layer._shown[plots[3]][1] as Color).r, 0.0, "while a ripe plot is not")
	var ripe: Dictionary = layer._members["wheat_ripe"]
	_check(ripe.has(plots[3]) and ripe.has(plots[4]), "plots showing one picture are one draw")
	_eq((layer._layers["wheat_ripe"] as MultiMeshInstance3D).multimesh.instance_count, ripe.size(), "a card to each")
	# A card faces the camera, and stands on its bed's nearest corner: over the bed, never sunk under the grass.
	var facing := PaintedCrops.facing()
	_check(facing.z.is_equal_approx(-IsoProjection.forward()), "a card faces the farm's camera")
	var card := PaintedCrops.PICTURE * PaintedCrops.tiles_per_pixel()
	var foot := PaintedCrops.place_of(plots[3]) - facing.y * card.y * 0.5
	_check(foot.y > -0.05 and foot.y < Plots3D.HEIGHT + 0.01, "its foot is on the bed (%.3f)" % foot.y)
	Game.plots[plots[3]] = {"state": "plowed"}
	layer.update([plots[3]])
	_eq(layer.shown(plots[3]), "", "a harvested plot's card goes")
	layer.free()
	_done(g)
