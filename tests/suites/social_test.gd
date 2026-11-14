extends TestSuite
## Neighbours: the inbox and outbox rules, the simulated neighbours, and the way requests, shares and Help All
## play out over time. Time is driven by `debug_time_offset`; the neighbours are seeded, so every run is the same.

const HOUR := 3600


func _later(g: GameState, seconds: int) -> void:
	g.debug_time_offset += seconds


func _gift(g: GameState, what: String, id: String, n: int, from := 0) -> int:
	var item := InboxItem.make(g.social.next_id, InboxItem.GIFT, from, g.now(), {"what": what, "id": id, "n": n})
	g.social.next_id += 1
	g.social.inbox.append(item)
	return int(item["id"])


func test_01_a_gift_is_claimed_once_and_gives_its_payload() -> void:
	var g := _farm()
	var id := _gift(g, InboxItem.PART, "bricks", 2)
	_check(g.social.claim(id), "claimed")
	_eq(int(g.parts.get("bricks", 0)), 2, "two bricks arrived")
	_check(not g.social.claim(id), "it is gone: no second claim")
	_eq(g.social.inbox.size(), 0, "the inbox is empty")
	_done(g)


func test_02_every_kind_of_give_lands_where_it_belongs() -> void:
	var g := _farm()
	var coins := g.coins
	g.social.grant({"what": InboxItem.COINS, "n": 40})
	_eq(g.coins, coins + 40, "coins")
	g.social.grant({"what": InboxItem.SUPPLY, "id": "watering_can", "n": 2})
	_eq(g.nurture.has_supply("watering_can"), 2, "supplies")
	g.social.grant({"what": InboxItem.FUEL, "n": 5})
	_check(g.vehicles.fuel_unlocked, "fuel opens the tank")
	var before := g.objects.size() + g.storage.stored.size()
	g.social.grant({"what": InboxItem.YOUNG, "id": "mystery_baby", "n": 1})
	_eq(g.objects.size() + g.storage.stored.size(), before + 1, "a young one arrived, on the farm or in the Barn")
	_done(g)


func test_03_a_pure_share_mints_a_copy_and_a_neighbour_collab_share_is_help() -> void:
	var g := _farm()
	var pure := InboxItem.make(1, InboxItem.SHARE, 0, g.now(), {"what": InboxItem.COINS, "n": 100}, {"collab": false})
	var collab := InboxItem.make(2, InboxItem.SHARE, 0, g.now(), {"what": InboxItem.YOUNG, "id": "mystery_seedling",
		"n": 1}, {"collab": true})
	_check(InboxItem.is_free(pure) and not InboxItem.is_help(pure), "a pure share is free")
	_check(InboxItem.is_help(collab) and not InboxItem.is_free(collab), "a collab share is a help")
	g.social.inbox.append(pure)
	var coins := g.coins
	_check(g.social.claim(1), "claimed")
	_eq(g.coins, coins + 100, "a copy of the 100 coins")
	_eq(g.social.helps_today, 0, "claiming a free share uses no help")
	_done(g)


func test_04_helping_pays_and_is_limited_each_day() -> void:
	var g := _farm()
	Balance.override("social.helps_per_day", 2)
	for i in 3:
		g.social.inbox.append(InboxItem.make(10 + i, InboxItem.REQUEST, i, g.now(), {"what": InboxItem.PART,
			"id": "nails", "n": 1}))
	var coins := g.coins
	_check(g.social.claim(10) and g.social.claim(11), "two helps")
	_eq(g.coins, coins + 2 * Balance.i("social.help_coins"), "each pays coins")
	_check(not g.social.claim(12), "the third is refused")
	_eq(g.social.helps_left(), 0, "no helps left")
	_eq(int(g.parts.get("nails", 0)), 0, "helping costs you nothing and gives no parts")
	_later(g, 86400)
	_eq(g.social.helps_left(), 2, "the limit comes back with the day")
	_check(g.social.claim(12), "so it can be helped tomorrow")
	Balance.reload()
	_done(g)


func test_05_help_all_clears_a_mixed_inbox_within_the_limit() -> void:
	var g := _farm()
	Balance.override("social.helps_per_day", 2)
	_gift(g, InboxItem.PART, "boards", 1)
	_gift(g, InboxItem.COINS, "", 10)
	for i in 3:
		g.social.inbox.append(InboxItem.make(20 + i, InboxItem.REQUEST, 0, g.now(), {"what": InboxItem.PART,
			"id": "bricks", "n": 1}))
	var tally := g.social.help_all()
	_eq(tally["claimed"], 2, "both gifts claimed")
	_eq(tally["helped"], 2, "two requests helped")
	_eq(tally["left"], 1, "one held back by the day's limit")
	_eq(g.social.inbox.size(), 1, "only the held-back request is left")
	Balance.reload()
	_done(g)


func test_06_a_request_is_answered_over_time_and_the_answers_are_claimed() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	g.buy_and_place("horse_stable", 8, 8)
	var uid := int(g.object_at(g.index_of(8, 8))["uid"])
	var sent := g.social.post_frame_request(uid)
	_check(sent >= 1, "the frame asked for what it lacks (%d)" % sent)
	_eq(g.social.post_frame_request(uid), 0, "asking again while open does nothing")
	_eq(g.social.inbox.size(), 0, "no answer yet")
	_later(g, 2 * 86400)
	g.social.settle()
	var answers := g.social.inbox.filter(func(i: Dictionary) -> bool: return i["kind"] == InboxItem.ANSWER)
	_check(not answers.is_empty(), "neighbours answered")
	var bricks := int(g.parts.get("bricks", 0))
	g.social.help_all()
	_check(int(g.parts.get("bricks", 0)) > bricks or int(g.parts.get("nails", 0)) + int(g.parts.get("boards", 0)) > 0,
		"the answers brought materials")
	_check(g.social.outbox.is_empty(), "the answered post is closed")
	_done(g)


func test_07_a_shared_seedling_is_watered_by_neighbours_and_grows() -> void:
	var g := _farm()
	g.nurture._found("mystery_seedling", "apple_tree")
	var seed: Dictionary = {}
	for o in g.objects:
		if o["id"] == "mystery_seedling":
			seed = o
	if seed.is_empty():
		seed = g.storage.stored[0]
		seed["row"] = 3
		seed["col"] = 3
		g.storage.stored.clear()
		g.add_object(seed)
	var uid := int(seed["uid"])
	_check(g.social.post_seedling_share(uid), "shared")
	_check(not g.social.post_seedling_share(uid), "only once while open")
	_later(g, 2 * 86400)
	g.social.settle()
	g.social.help_all()
	var after := g.object_by_uid(uid)
	var grown := after.is_empty() or int(after.get("fed", 0)) > 0
	_check(grown, "neighbours watered it (it grew or is growing)")
	_done(g)


func test_08_a_gift_goes_out_once_a_day_per_neighbour() -> void:
	var g := _farm()
	var give := {"what": InboxItem.PART, "id": "bricks", "n": 1}
	_check(g.social.send_gift(0, give), "sent")
	_check(not g.social.send_gift(0, give), "not twice a day to one neighbour")
	_check(g.social.send_gift(1, give), "another neighbour is fine")
	_eq(g.parts.get("bricks", 0), 0, "gifting costs the sender nothing")
	_later(g, 86400)
	_check(g.social.send_gift(0, give), "tomorrow again")
	_check(not g.social.send_gift(99, give), "no such neighbour")
	_done(g)


func test_09_the_neighbours_are_the_same_however_the_time_is_cut_up() -> void:
	var t := SimulatedNeighbours.new()
	var whole := t.incoming(1000000, 1000000 + 20 * HOUR)
	var halves := t.incoming(1000000, 1000000 + 7 * HOUR) + t.incoming(1000000 + 7 * HOUR, 1000000 + 20 * HOUR)
	_eq(whole.size(), halves.size(), "same amount of mail")
	_check(whole.size() > 0, "some mail arrives in 20 hours (%d)" % whole.size())
	for i in mini(whole.size(), halves.size()):
		_eq(whole[i], halves[i], "mail %d is the same" % i)
	_eq(t.roster().size(), 6, "six neighbours")


func test_10_catching_up_after_being_away_is_capped() -> void:
	var g := _farm()
	g.social.last_settled = g.now()
	_later(g, 400 * 86400)
	g.social.settle()
	_check(g.social.inbox.size() <= Balance.i("social.inbox_limit"), "never past the inbox limit")
	_check(g.social.inbox.size() > 0, "some mail came")
	for item in g.social.inbox:
		_check(g.now() - int(item["t"]) <= Balance.i("social.catchup_hours") * HOUR + Balance.i("social.slot_seconds"),
			"nothing older than the catch-up window")
	_done(g)


func test_11_the_inbox_and_outbox_survive_a_save() -> void:
	var g := _farm()
	_gift(g, InboxItem.PART, "boards", 3)
	g.social.post_request({"what": InboxItem.PART, "id": "bricks", "n": 2})
	g.social.send_gift(2, {"what": InboxItem.COINS, "n": 10})
	var saved := {}
	g.social.save_to(saved)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var h := _farm()
	h.social.load_from(parsed)
	_eq(h.social.inbox.size(), g.social.inbox.size(), "inbox")
	_eq(h.social.outbox.size(), g.social.outbox.size(), "outbox")
	_eq(h.social.outbox[0]["answers"].size(), g.social.outbox[0]["answers"].size(), "the planned answers too")
	_check(h.social.gifted_today(2), "today's gift is remembered")
	_check(h.social.next_id > 3, "ids carry on")
	_check(h.social.claim(int(h.social.inbox[0]["id"])), "a loaded item can be claimed")
	_done(g)
	_done(h)


func test_12_damaged_items_are_mended_or_dropped() -> void:
	var g := _farm()
	var data := {SocialSystem.SAVED_INBOX: [
		5, "x", {"kind": "gift"}, {"kind": "nonsense", "give": {"what": "coins", "n": 5}},
		{"kind": "gift", "give": {"what": "coins", "n": -3}},
		{"kind": "gift", "id": 4.0, "from": 1.0, "t": 9.0, "give": {"what": "coins", "n": 7.0}},
	], SocialSystem.SAVED_OUTBOX: "junk"}
	g.social.load_from(data)
	_eq(g.social.inbox.size(), 1, "only the whole one is kept")
	_eq(typeof(g.social.inbox[0]["id"]), TYPE_INT, "whole numbers")
	_eq(g.social.outbox.size(), 0, "a junk outbox is empty")
	_check(g.social.next_id > 4, "ids stay above the kept ones")
	_done(g)


func test_13_switched_off_nothing_happens() -> void:
	var g := _farm()
	var id := _gift(g, InboxItem.PART, "bricks", 1)
	Balance.override("social.enabled", 0)
	_check(not g.social.claim(id), "no claim")
	_check(not g.social.send_gift(0, {"what": "coins", "n": 1}), "no gift")
	_eq(g.social.settle(), "", "no catching up")
	_eq(g.social.help_all()["claimed"], 0, "no help all")
	Balance.reload()
	_done(g)


func test_14_every_pool_entry_is_a_real_thing() -> void:
	var g := _farm()
	var t := SimulatedNeighbours.new()
	for pool: String in t.pools:
		_check(not (t.pools[pool] as Array).is_empty(), "%s has entries" % pool)
		for e: Dictionary in t.pools[pool]:
			var give := InboxItem.clean_give(e["give"])
			_check(not give.is_empty(), "%s: %s is a well-formed give" % [pool, str(e["give"])])
			match give.get("what", ""):
				InboxItem.PART:
					_check(GameState.part_names.has(give["id"]), "%s is a part" % give["id"])
				InboxItem.SUPPLY:
					_check(NurtureSystem.SUPPLIES.has(give["id"]), "%s is a supply" % give["id"])
				InboxItem.YOUNG:
					_check(g.items.has(give["id"]), "%s is an item" % give["id"])
	_done(g)


func test_15_a_mystery_from_a_neighbour_is_a_real_mystery() -> void:
	var g := _farm()
	var kinds := {}
	for i in 40:
		g.nurture.give_young("mystery_seedling")
	for o in g.objects + g.storage.stored:
		if o["id"] == "mystery_seedling":
			kinds[str(o.get("becomes", ""))] = true
	_check(kinds.size() > 3, "forty seedlings turn into many kinds of tree (%d)" % kinds.size())
	_done(g)


func test_16_setting_the_clock_back_never_delivers_mail_twice() -> void:
	var g := _farm()
	g.social.last_settled = g.now()
	_later(g, 2 * 86400)
	g.social.settle()
	var had := g.social.inbox.size()
	_later(g, -86400)
	g.social.settle()
	_later(g, 86400)
	g.social.settle()
	_eq(g.social.inbox.size(), had, "going back a day and forward again brings nothing new")
	_done(g)


func test_17_asking_for_fuel_brings_one_neighbour_s_fuel() -> void:
	var g := _farm()
	g.vehicles.add_fuel(1)
	_check(g.social.post_fuel_request(), "asked")
	var post: Dictionary = g.social.outbox[0]
	var total := 0
	for a: Dictionary in post["answers"]:
		total += int(a["give"]["n"])
	_eq(total, Balance.i("social.fuel_per_answer"), "one neighbour's worth of fuel")
	_done(g)


func test_18_a_gift_is_thanked_by_the_neighbour_it_went_to() -> void:
	var g := _farm()
	Balance.override("social.thanks_chance", 1.0)
	_check(g.social.send_gift(3, {"what": InboxItem.COINS, "n": 1}), "sent")
	for a: Dictionary in g.social.outbox[0]["answers"]:
		_eq(int(a["by"]), 3, "the thanks comes from neighbour 3")
	Balance.reload()
	_done(g)
