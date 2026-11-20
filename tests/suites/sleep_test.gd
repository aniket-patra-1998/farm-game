extends TestSuite
## How the animals sleep (docs/ANIMAL_SLEEP.md; owner, 20 Nov): each family in its own way, from its file's
## `sleep` move, never with a water bird's head down in the water, and a little "z z z" at each sleeper's nose.

const FAMILIES := ["cow", "ox", "horse", "donkey", "pig", "sheep", "goat", "llama", "alpaca", "chicken", "turkey",
	"duck", "swan", "goose", "rabbit", "turtle", "calf", "galaxy_cow", "rainbow_duck"]


func test_610_an_animal_sleeps_its_familys_way_not_with_its_head_hung() -> void:
	var was := AnimalBehaviour.night
	AnimalBehaviour.night = true
	var mind := AnimalBehaviour.new(AnimalRig.of(Game.item_data("cow")), 7, Vector2(14, 7))
	mind.lies = true
	mind.pose.head = 1.0   # (it was grazing)
	mind.call("_enter", AnimalBehaviour.State.SLEEP)
	for step in 30:
		mind.call("_ease_body", 0.1)
		mind.call("_idle_motions", 0.1)
	_eq(mind.pose.sleep, 1.0, "asleep, it is in its sleeping pose")
	_eq(mind.pose.head, 0.0, "which places its head: it is not hung low as well")
	_eq(mind.pose.blink, 1.0, "its eyes shut")
	# It settles in under a second, and is up as quickly.
	var fresh := AnimalBehaviour.new(AnimalRig.of(Game.item_data("cow")), 7, Vector2(14, 7))
	fresh.lies = true
	fresh.call("_enter", AnimalBehaviour.State.SLEEP)
	fresh.call("_ease_body", 0.2)
	_check(fresh.pose.sleep > 0.3 and fresh.pose.sleep < 0.7, "it lies down over about half a second")
	mind.call("_enter", AnimalBehaviour.State.IDLE)
	for step in 5:
		mind.call("_ease_body", 0.1)
	_eq(mind.pose.sleep, 0.0, "awake, it is up")
	# An animal with no sleeping pose of its own (one built by code) hangs its head, as it always did.
	var plain := AnimalBehaviour.new(AnimalRig.of(Game.item_data("cow")), 7, Vector2(14, 7))
	plain.call("_enter", AnimalBehaviour.State.SLEEP)
	for step in 30:
		plain.call("_ease_body", 0.1)
	_eq(plain.pose.sleep, 0.0, "no pose of its own: none taken")
	_check(absf(plain.pose.head - AnimalBehaviour.SLEEP_HEAD) < 0.01, "its head hangs")
	AnimalBehaviour.night = was


func test_611_every_family_has_its_sleeping_pose_and_its_nose() -> void:
	var noses: Dictionary = DataFile.read(Animal3D.NOSES)["noses"]
	# Every animal with a file has where its nose is asleep, written with the file (a bee has no sleeping pose).
	var filed := 0
	for id: String in Game.item_order:
		if Game.kind_of({"id": id}) != "animal" or not AssetRegistry.has_model(id) or id == "bee":
			continue
		filed += 1
		_check(noses.has(id) and (noses[id] as Array).size() == 3, "%s's sleeping nose is known" % id)
	_check(filed >= 140, "every animal made as a file (%d)" % filed)
	_check(not noses.has("bee"), "a bee has none")
	for id: String in FAMILIES:
		var mind := AnimalBehaviour.new(AnimalRig.of(Game.item_data(id)), 7, Vector2(14, 7))
		var a := Animal3D.create(Game.item_data(id), mind, Vector3.ZERO)
		add_child(a)
		_check(a.sleeps_its_own_way() and mind.lies, "%s's file has its sleeping pose, and its mind knows" % id)
		var nose := a.nose_asleep()
		_check(nose.is_finite() and nose.y > 0.0 and nose.length() < 2.0, "%s's nose asleep is by it: %s" % [id, nose])
		a.free()
	# A water bird's bill is on its back, well clear of the water it floats on.
	for id: String in ["duck", "swan", "goose"]:
		var at: Array = noses[id]
		_check(float(at[1]) > 0.18 and float(at[0]) < 0.12,
			"%s sleeps with its bill tucked back, high and dry: %s" % [id, at])
	var bee := Animal3D.create(Game.item_data("bee"), AnimalBehaviour.new(AnimalRig.of(Game.item_data("bee")), 7,
		Vector2(14, 7)), Vector3.ZERO)
	_check(not bee.sleeps_its_own_way() and not bee.nose_asleep().is_finite(), "a bee has no sleeping pose")
	bee.free()


func test_612_a_sleeper_has_a_small_zzz_at_its_nose() -> void:
	var was := AnimalBehaviour.night
	AnimalBehaviour.night = true
	Animal3D.sleepers.clear()
	var marks := SleepMarks.new()
	add_child(marks)
	var minds: Array[AnimalBehaviour] = []
	var animals: Array[Animal3D] = []
	for id: String in ["cow", "duck", "bee"]:
		var mind := AnimalBehaviour.new(AnimalRig.of(Game.item_data(id)), 7, Vector2(14, 7))
		var a := Animal3D.create(Game.item_data(id), mind, Vector3(animals.size() * 2.0, 0, 0))
		add_child(a)
		minds.append(mind)
		animals.append(a)
	_eq(marks.show_over(Animal3D.sleepers), 0, "nobody asleep: no z")
	for mind in minds:
		mind.call("_enter", AnimalBehaviour.State.SLEEP)
	for step in 20:
		for k in animals.size():
			minds[k].call("_ease_body", 0.1)
			animals[k].update(0.1)
	_eq(Animal3D.sleepers.size(), 2, "the cow and the duck are asleep in their poses (a bee has none)")
	_eq(marks.show_over(Animal3D.sleepers), 2, "each has its z z z")
	_check(marks.visible and marks.multimesh.visible_instance_count == 2, "drawn as one batch")
	var nose := animals[0].nose_asleep()
	_check(marks.where(0).distance_to(marks.to_local(nose)) < 0.001, "at its nose")
	# It wakes: its z goes. It leaves the farm asleep: so does its z.
	minds[0].call("_enter", AnimalBehaviour.State.IDLE)
	for step in 10:
		minds[0].call("_ease_body", 0.1)
		animals[0].update(0.1)
	_eq(marks.show_over(Animal3D.sleepers), 1, "awake: no z")
	animals[1].free()
	_eq(Animal3D.sleepers.size(), 0, "gone from the farm: not a sleeper")
	_eq(marks.show_over(Animal3D.sleepers), 0, "and no z")
	animals[0].free()
	animals[2].free()
	marks.free()
	AnimalBehaviour.night = was
