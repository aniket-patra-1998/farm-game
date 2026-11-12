extends TestSuite
## Vehicles: how big and heavy each kind is, the road it drives over a field, how its weight shows in the way it
## drives (VehicleMotion), the dust it throws, and a whole run from pop-in to leaving.


func _spins(node: Node, out: Array) -> Array:
	for c in node.get_children():
		if c.has_meta(VehicleModel.SPIN):
			out.append(float(c.get_meta(VehicleModel.SPIN)))
		_spins(c, out)
	return out


func test_155_a_combine_is_bigger_and_heavier_than_a_tractor() -> void:
	var order := ["tractor", "harvester", "combine"]
	for k in range(1, order.size()):
		var small := Game.item_data(order[k - 1])
		var big := Game.item_data(order[k])
		_check(VehicleModel.scale_of(big) > VehicleModel.scale_of(small), "%s is modelled larger" % order[k])
		_check(VehicleModel.width_of(big) > VehicleModel.width_of(small), "%s stands wider" % order[k])
		_check(float(big["weight"]) > float(small["weight"]), "%s is heavier" % order[k])
	var combine_width := VehicleModel.width_of(Game.item_data("combine"))
	_check(
		combine_width > VehicleModel.width_of(Game.item_data("tractor")) * 1.8,
		"the Combine is almost twice as wide"
	)
	for id in ["tractor", "harvester", "seeder", "combine"]:
		var it := Game.item_data(id)
		_check(VehicleModel.EXHAUST.has(id), "%s has a stack for smoke" % id)
		_check(float(it["weight"]) >= 0.0 and float(it["weight"]) <= 1.0, "%s weight is 0 to 1" % id)


func test_156_a_rigged_model_keeps_its_wheels_and_reels_turnable() -> void:
	var counts := {"tractor": [4, 0], "seeder": [6, 0], "harvester": [4, 1], "combine": [4, 1]}
	for id: String in counts:
		var rig := VehicleModel.build(Game.item_data(id), false, true)
		var radii := _spins(rig, [])
		var wheels := radii.filter(func(r: float) -> bool: return r > 0.0)
		var reels := radii.filter(func(r: float) -> bool: return r < 0.0)
		_eq(wheels.size(), counts[id][0], "%s keeps its wheels whole" % id)
		_eq(reels.size(), counts[id][1], "%s keeps its reel whole" % id)
		rig.free()
		var still := VehicleModel.build(Game.item_data(id))
		_eq(_spins(still, []).size(), 0, "%s parked is merged into a few draws" % id)
		still.free()


func test_157_the_road_covers_every_lane_and_turns_outside_the_field() -> void:
	for area: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 3), Vector2i(4, 4)]:
		var plan := VehicleRoute.plan(5, 7, area)
		var pts: PackedVector2Array = plan["points"]
		var lanes: PackedInt32Array = plan["lane_of"]
		_eq(lanes.size(), pts.size(), "a lane tag for every point")
		_eq(VehicleRoute.lane_xs(7, area.x).size(), maxi(ceili(area.x / VehicleRoute.LANE), 1), "lanes of %s" % area)
		var seen := {}
		for k in pts.size():
			_check(pts[k].x >= 7.0 - 0.01 and pts[k].x <= 7.0 + area.x + 0.01, "point %d is across the area" % k)
			if lanes[k] >= 0:
				seen[lanes[k]] = true
				_check(pts[k].y <= 5.0 or pts[k].y >= 5.0 + area.y, "a lane's ends are past the plots")
		_eq(seen.size(), VehicleRoute.lane_xs(7, area.x).size(), "every lane is driven (%s)" % area)
		_check(pts[0].y < 5.0 - VehicleRoute.MARGIN or pts[0].y > 5.0 + area.y + VehicleRoute.MARGIN,
			"it starts outside the field")
		_check(VehicleRoute.length_of(pts) > area.y * seen.size(), "the road is longer than the lanes")
		var end: Dictionary = VehicleRoute.at(pts, 1.0e9)
		_check((end["pos"] as Vector2).is_equal_approx(pts[pts.size() - 1]), "past the end it stays at the end")
		_check(absf((end["dir"] as Vector2).length() - 1.0) < 0.001, "and faces a unit direction")


func _drive_profile(w: float) -> Dictionary:
	var m := VehicleMotion.new(w)
	var t := 0.0
	while m.speed < 0.95 * float(m.feel["speed"]) and t < 30.0:
		m.step(0.016, float(m.feel["speed"]), 0.0)
		t += 0.016
	var up := t
	var d0 := m.distance
	t = 0.0
	while m.speed > 0.0 and t < 30.0:
		m.step(0.016, 0.0, 0.0)
		t += 0.016
	var stop := t
	var stop_d := m.distance - d0
	# A kick: the same push on the springs, how deep it sinks and how long it takes to settle.
	var k := VehicleMotion.new(w)
	k.bob_speed = 0.2
	var peak := 0.0
	var settle := 0.0
	var clock := 0.0
	while clock < 10.0:
		k.step(0.016, 0.0, 0.0)
		clock += 0.016
		peak = maxf(peak, absf(k.bob))
		if absf(k.bob) > 0.002 or absf(k.bob_speed) > 0.01:
			settle = clock
	return {"up": up, "stop": stop, "stop_d": stop_d, "peak": peak, "settle": settle, "speed": m.feel["speed"]}


func test_158_weight_shows_in_how_a_vehicle_drives() -> void:
	var light := _drive_profile(0.0)
	var heavy := _drive_profile(1.0)
	_check(heavy["speed"] < light["speed"], "a heavy one cruises slower")
	_check(
		heavy["up"] > light["up"] * 1.8,
		"and takes much longer to get going (%.2f vs %.2f s)" % [heavy["up"], light["up"]]
	)
	_check(heavy["stop"] > light["stop"] * 1.4, "and to stop (%.2f vs %.2f s)" % [heavy["stop"], light["stop"]])
	_check(heavy["peak"] > light["peak"] * 1.5, "it sinks deeper on the same bump")
	_check(heavy["settle"] > light["settle"] * 1.2, "and wallows longer before it settles")
	var a := VehicleMotion.new(0.4)
	var b := VehicleMotion.new(0.4)
	for k in 600:
		var target := 2.0 if (k / 150) % 2 == 0 else 0.0
		a.step(0.016, target, sin(k * 0.02))
		b.step(0.016, target, sin(k * 0.02))
	_check(a.bob == b.bob and a.pitch == b.pitch and a.yaw == b.yaw, "the same drive gives the same motion")
	_check(absf(a.bob) < 0.2 and absf(a.pitch) < 1.0 and absf(a.roll) < 1.0, "and it stays steady")
	var long := VehicleMotion.new(0.7)
	long.step(1.0, 2.0, 0.0)   # one slow frame is split into steady steps
	_check(is_finite(long.bob) and is_finite(long.pitch) and long.speed > 0.0, "a very long frame does no harm")


func test_159_dust_puffs_rise_fade_and_the_ring_never_grows() -> void:
	var d := DustPuffs.new()
	_eq(d.live(), 0, "no dust to start with")
	for k in DustPuffs.CAPACITY + 20:
		d.emit(Vector3(k * 0.1, 0, 0), Vector3(0, 0.3, 0), 0.2, 1.0, Color(0.5, 0.4, 0.3, 0.5))
	_eq(d.live(), DustPuffs.CAPACITY, "a full ring replaces its oldest puffs")
	d.advance(0.5)
	_eq(d.live(), DustPuffs.CAPACITY, "half way through their life they are all still there")
	d.advance(0.6)
	_eq(d.live(), 0, "past their life they are gone")
	_check(not d.is_processing(), "and with none left it sleeps")
	d.free()


func test_160_a_vehicle_drives_the_field_throwing_dust_and_leaving_tracks() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var puffs := DustPuffs.new()
	var trails := Trails.new()
	var done := [false]
	var run := VehicleRun.create(Game.item_data("combine"), 4, 6, Vector2i(4, 4), puffs, trails)
	add_child(run)
	run.finished.connect(func() -> void: done[0] = true)
	_eq(run.wheels(), 4, "four wheels turn")
	_eq(run.reels(), 1, "and the header's reel")
	var peak_dust := 0
	var t := 0.0
	var start := run.position
	while not done[0] and t < 90.0:
		run.advance(0.05)
		t += 0.05
		peak_dust = maxi(peak_dust, puffs.live())
	_check(done[0], "it finishes and leaves (took %.1f s)" % t)
	_check(t > 4.0 and t < 40.0, "in a believable time for something that heavy (%.1f s)" % t)
	_check(peak_dust > 5, "it threw up dust (%d puffs at most)" % peak_dust)
	_check(trails.live() >= 4, "and laid wheel tracks (%d marks)" % trails.live())
	_check(run.motion.distance > VehicleRoute.length_of(run.route) * 0.95, "the wheels covered the whole road")
	_check(start.y < 4.0, "it came in from outside the field")
	puffs.free()
	trails.free()


func test_161_a_garage_doorway_holds_two_vehicles_side_by_side_at_their_own_sizes() -> void:
	var widths := 0.0
	for id in ["combine", "tractor"]:
		widths += VehicleModel.width_of(Game.item_data(id))
	var door := BuildingStock.DOOR_SHARE * 3.0
	var fit := minf(BuildingStock.VEHICLE_SCALE, door * BuildingStock.DOOR_FILL / widths)
	_check(widths * fit <= door, "a Combine and a Tractor fit a three tile door (%.2f of %.2f)" % [widths * fit, door])
	_check(fit > 0.5, "without shrinking to nothing (%.2f)" % fit)
