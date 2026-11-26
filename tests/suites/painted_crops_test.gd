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


func test_653_a_flower_is_a_painted_picture_in_bud_open_or_dry_by_the_clock() -> void:
	var g := _farm()
	for id: String in Game.item_order:
		if str(Game.items[id].get("kind", "")) != "bloom":
			continue
		var flower := PaintedBloom.create(id, Game.footprint(id))
		add_child(flower)
		_eq(flower.heads, 3 if id.contains("full") else 1, "%s: a full bloom is three heads" % id)
		for look: String in [PaintedBloom.BUD, PaintedBloom.OPEN]:
			_check(PaintedCrops.paint_at(PaintedBloom.ART % ("%s_%d_%s" % [flower.kind, flower.heads, look])) != null,
				"%s is painted %s from its recipe" % [id, look])
		var now := float(Game.now())
		flower.set_cycle(now + 100.0, now + 200.0)
		_eq(flower.shown(), PaintedBloom.BUD, "in bud until it is ready")
		flower.set_cycle(now - 1.0, now + 200.0)
		_eq(flower.shown(), PaintedBloom.OPEN, "open while it stands ready")
		flower.set_cycle(now - 1.0, PaintedBloom.NEVER)
		_eq(flower.shown(), PaintedBloom.OPEN, "and one that never withers stays open")
		flower.set_cycle(now - 300.0, now - 1.0)
		_eq(flower.shown(), PaintedBloom.DRY, "and dry once it has withered")
		var card := flower.get_child(0) as MeshInstance3D
		var dried: float = (card.material_override as ShaderMaterial).get_shader_parameter("dried")
		_eq(dried, 1.0, "the dry look is the open picture gone dry")
		var foot := card.position.y - PaintedCrops.facing().y.y * (card.mesh as QuadMesh).size.y * 0.5
		_check(foot > -0.01, "its card is not sunk in the grass (%.3f)" % foot)
		_check((card.mesh as QuadMesh).size.x < 1.0, "and its picture is narrower than its tile")
		flower.free()
	_done(g)


func test_654_a_painted_crops_market_picture_and_harvest_pop() -> void:
	var g := _farm()
	var towards := Basis.from_euler(Vector3(ItemIcons.PITCH, ItemIcons.YAW, 0.0))
	for crop_id: String in Game.crops:
		var card := PaintedCrops.harvest_card(crop_id, towards)
		_check(card != null, "%s has a picture of what it gives, gathered" % crop_id)
		if card != null:
			card.free()
	var shown := ItemIcons._model("wheat")
	_check(shown != null and shown.find_children("*", "MultiMeshInstance3D", true, false).is_empty(),
		"a crop's Market picture is its painted harvest, not its model")
	shown.free()
	var flower := ItemIcons._model("rose_bloom")
	_check(flower is PaintedBloom and (flower as PaintedBloom).shown() == PaintedBloom.OPEN,
		"a flower's Market picture is it painted, open")
	flower.free()
	# A harvested plot's card springs up and is gone.
	var layer := PaintedCrops.new()
	add_child(layer)
	var i := Game.index_of(2, 2)
	var ripe_for := int(Game.crops["wheat"]["grow_seconds"]) + 1
	Game.plots[i] = {"state": "planted", "crop": "wheat", "planted_at": Game.now() - ripe_for}
	PaintedCrops.picture("wheat_ripe")
	layer.update([i])
	var before := layer.get_child_count()
	layer.pop(i, "wheat")
	_eq(layer.get_child_count(), before + 1, "a harvest pops the plot's card")
	layer.free()
	_done(g)

